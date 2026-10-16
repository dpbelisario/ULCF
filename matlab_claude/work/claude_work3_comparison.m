%% claude_work3_comparison - Three switches compared on one common parameter set
% Claude's solution of work3 (the task is in work3_comparison.m).
% Loads the newest result files of
%   (1) two-stage ULCF switch on the common set   claude_main_two_stage_common
%   (2) conventional three-stage switch            main_three_stage_conventional (baseline)
%   (3) proposed three-stage switch                claude_main_three_stage_proposed (seed 1, seed 2)
% and produces: the common parameter table, the port-count-versus-power figure,
% throughput, hardware elements per port, the split of the gain into its two
% sources, the random error between two seeds, and the conclusion.
clear; close all; rng(1);

%% 1. Files
work_folder = fileparts(mfilename('fullpath'));
results_folder = fullfile(fileparts(work_folder), 'results');
ref_file = fullfile(fileparts(work_folder), 'ref_data', 'jlt2025_three_stage_ref.csv');
newest = @(pat) local_newest(results_folder, pat);
f_two = newest('claude_two_stage_common_*.mat');
f_conv = newest('three_stage_conventional_*.mat');
f_prop1 = newest('claude_three_stage_proposed_seed1_*.mat');
f_prop2 = newest('claude_three_stage_proposed_seed2_*.mat');
two = load(f_two); conv = load(f_conv); prop = load(f_prop1);
has_seed2 = ~isempty(f_prop2);
if has_seed2, prop2 = load(f_prop2); end
fprintf('Files: %s\n       %s\n       %s\n', f_two, f_conv, f_prop1);
if has_seed2, fprintf('       %s\n', f_prop2); end
time_stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
file_base = fullfile(results_folder, ['claude_work3_' time_stamp]);
N = prop.N; bitrate_per_port = 200e9;  % 200 Gbit/s DP-16QAM at 32 GBd (JLT paper)
PTx_max = 5;  % the JLT paper allows at most 5 dBm

%% 2. Common parameter set
common = {
 'mod_flag',        '4 (16QAM)',     'JLT 2025 signal: 200-Gbps DP-16QAM; the port-count reference of the paper'
 'baudrate',        '32 GBd',        'same reason; 16 GHz half-width fits the 50-GHz grid'
 'signal_interval', '50 GHz',        'the grid of both papers'
 'N',               '96',            'channels in the C band (both papers)'
 'pol_flag',        '1',             'polarization multiplexing in both papers'
 'fiber_flag',      '0 (single-core)', 'JLT paper; the multicore fan-in/out of step21 belongs to that earlier study'
 'NF',              '6 dB',          'JLT paper value of the EDFA'
 'edfa_sat1 / edfa_sat2 / NF2', '20 dBm / 10 dBm / 4 dB', 'identical in step21 and step22'
 'extinction ratio', '35 dB',        'JLT paper; used for the DC switch (dcs_ex_ratio) and for every selector'
 'flg_NWDM',        '0',             'carrier on the AWG passband centre (50-GHz grid); only the ULCF deviation remains'
 'AWG, K = 1',      '6 dB, 50 GHz',  'the single-input AWG of step22 (JLT) for every switch with one input port'
 'AWG, K > 1',      '9 + 3.5 dB, 66.6 GHz, XT 32 dB, deviation ULCF_dev_freq(K)', 'ULCF pair + 1 x 2 splitter of step21 (JOCN) for every switch with K input ports'
 'rolloff / up / Morder', '0 / 2 / 16', 'the given scripts; up = 2 is enough with all leaks in band or left out'
 'datasize / grid', '3e4 symbols / 1 dB', 'quick setting: about 3.5 percent error of the BER, 1 dB resolution'
 'seed',            '1 (and 2)',     'every point repeatable; the second seed measures the random error'
 'BER_limit',       '1e-2',          'FEC limit of both papers'
 'architecture-only', 'DC switch (two-stage) vs selector + selector (three-stage); K couplers/EDFAs', 'these rows cannot be made equal: they ARE the switches'
};
fprintf('\n=== Common parameter set ===\n');
fid = fopen([file_base '_common_parameters.csv'], 'w');
fprintf(fid, 'parameter,value,reason\n');
for k = 1:size(common, 1)
    fprintf('  %-28s %-40s %s\n', common{k, 1}, common{k, 2}, common{k, 3});
    fprintf(fid, '"%s","%s","%s"\n', common{k, 1}, common{k, 2}, common{k, 3});
end
fclose(fid);

%% 3. Consistency: proposed K = 1 equals the conventional curve
iK1 = find(prop.K_list == 1);
iD = find(strcmp(prop.pattern_list, 'dispersed'));
fprintf('\n=== Consistency checks ===\n');
assert(isequal(prop.list_sw_size, conv.list_sw_size) && isequal(prop.list_stage3_coupler_flag, ...
    conv.list_stage3_coupler_flag), 'size or scheme lists differ between proposed and conventional');
for bb = 1:numel(conv.list_stage3_coupler_flag)
    for d = 1:numel(conv.list_sw_size)
        a1 = squeeze(prop.required_PTx(iK1, bb, iD, d));
        a0 = conv.required_PTx(bb, d);
        % the conventional grid starts at -10 dBm: compare where both grids cover the value
        if ~isnan(a0) || ~isnan(a1)
            if isnan(a0) && isnan(a1), ok = true;
            elseif isnan(a0) || isnan(a1), ok = false;
            else, ok = (a1 == a0) || (a1 < conv.pin_ary(1));
            end
            assert(ok, 'proposed K = 1 (A%d, M = %d): %.1f dBm, conventional: %.1f dBm', ...
                conv.list_stage3_coupler_flag(bb) + 1, conv.list_sw_size(d), a1, a0);
        end
    end
end
fprintf('Proposed switch with K = 1 and the step22 AWG = conventional three-stage curve (every size, both schemes).\n');
% concentrated traffic: the stage-3 crosstalk term equals the conventional one
fprintf('Concentrated traffic has M - 1 in-band leaks for every K (work1): only the middle stage differs.\n');
% selectors per port of switch (2) against the JLT file
ref = readmatrix(ref_file, 'NumHeaderLines', 1);
for row = 1:size(ref, 1)
    M = ref(row, 2); flag = ref(row, 1);
    if flag == 0, sel = 4*(M - 1); else, sel = 3*(M - 1); end
    assert(sel == ref(row, 5), 'selectors per port differ from the JLT file at M = %d', M);
end
fprintf('Selectors per port of the conventional switch (4(M-1) for A1, 3(M-1) for A2) = jlt2025_three_stage_ref.csv.\n');

%% 4. Required power tables and random error
M_list = prop.list_sw_size; nM = numel(M_list);
fprintf('\n=== Required transmitter power [dBm], columns M = %s (ports %s) ===\n', mat2str(M_list), mat2str(M_list*N));
fprintf('Two-stage (common set), rows K; M of the DC switch = %s\n', mat2str(two.list_dcs_input_port_num));
for a = 1:numel(two.ULCF_deg_ary)
    fprintf('  K = %2d :', two.ULCF_deg_ary(a)); fprintf('%7.1f', two.required_PTx(a, :)); fprintf('\n');
end
for bb = 1:2
    for c = 1:2
        fprintf('Three-stage A%d, %s (K = 1 is the conventional switch)\n', prop.list_stage3_coupler_flag(bb) + 1, prop.pattern_list{c});
        for a = 1:numel(prop.K_list)
            fprintf('  K = %2d :', prop.K_list(a)); fprintf('%7.1f', squeeze(prop.required_PTx(a, bb, c, :))); fprintf('\n');
        end
    end
end
if has_seed2
    dd = prop2.required_PTx - prop.required_PTx;
    both = ~isnan(prop.required_PTx) & ~isnan(prop2.required_PTx);
    n_same = nnz(dd(both) == 0); n_both = nnz(both);
    fprintf('\nRandom error: seed 2 against seed 1 over %d entries: %d equal, largest difference %.1f dB, NaN mismatches %d\n', ...
        n_both, n_same, max(abs(dd(both))), nnz(isnan(prop.required_PTx) ~= isnan(prop2.required_PTx)));
    fprintf('  (a 1-dB difference at one point = the point sits at the FEC limit; a real difference\n');
    fprintf('   between switches must be larger than this, see the 0.5 dB question of the task)\n');
    req_prop = max(prop.required_PTx, prop2.required_PTx);  % conservative: the worse seed
else
    req_prop = prop.required_PTx;
end

%% 5. Port count versus transmitter power: one figure, two panels
fig = figure('Position', [60 60 1250 520]);
if isprop(fig, 'Theme'), set(fig, 'Theme', 'light'); end
K_show = [4 12];
for c = 1:2
    subplot(1, 2, c); hold on;
    % two-stage K = 1 and K = 12
    for K = [1 12]
        a = find(two.ULCF_deg_ary == K); y = two.data_PC(:, a + 1); y(y == 0) = NaN;
        stairs(two.pin_ary, y, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.0 + 0.8*(K > 1), ...
            'DisplayName', sprintf('two-stage, K = %d', K));
    end
    % conventional = proposed K = 1
    for bb = 1:2
        idx = (iK1 - 1)*4 + (bb - 1)*2 + c;
        y = prop.data_PC(:, idx); y(y == 0) = NaN;
        if bb == 1, ls = '-'; else, ls = '--'; end
        stairs(prop.pin_ary, y, ls, 'Color', 'k', 'LineWidth', 1.6, ...
            'DisplayName', sprintf('conventional A%d', bb));
    end
    cols = [0.85 0.33 0.1; 0 0.45 0.74];
    for kk = 1:numel(K_show)
        a = find(prop.K_list == K_show(kk));
        for bb = 1:2
            idx = (a - 1)*4 + (bb - 1)*2 + c;
            y = prop.data_PC(:, idx); y(y == 0) = NaN;
            if bb == 1, ls = '-'; else, ls = '--'; end
            stairs(prop.pin_ary, y, ls, 'Color', cols(kk, :), 'LineWidth', 1.4, ...
                'DisplayName', sprintf('proposed K = %d, A%d', K_show(kk), bb));
        end
    end
    xline(PTx_max, 'r:', 'HandleVisibility', 'off');
    grid on; set(gca, 'YScale', 'log'); set(gca, 'YTick', [two.list_dcs_input_port_num(1:3)*N, M_list*N]);
    ylim([150, max(M_list)*N*1.5]); xlim([-25 15]);
    xlabel('Transmitter power PTx [dBm]'); ylabel('Port count M*N');
    title(sprintf('%s traffic (16QAM, 32 GBd, N = 96)', prop.pattern_list{c}));
    legend('Location', 'southeast', 'FontSize', 8);
end
saveas(fig, [file_base '_portcount.png']);

%% 6. Throughput and the largest switch below the 5-dBm limit
fprintf('\n=== Largest feasible switch with PTx <= %d dBm (200 Gbit/s per port) ===\n', PTx_max);
fid = fopen([file_base '_throughput.csv'], 'w');
fprintf(fid, 'switch,K,scheme,pattern,max_ports,throughput_Tbps,required_PTx_dBm\n');
rows = {};
for a = 1:numel(two.ULCF_deg_ary)
    ok = find(two.required_PTx(a, :) <= PTx_max, 1, 'last');
    if isempty(ok), ports = 0; need = NaN; else, ports = two.list_dcs_input_port_num(ok)*N; need = two.required_PTx(a, ok); end
    rows(end+1, :) = {'two-stage', two.ULCF_deg_ary(a), '-', '-', ports, ports*bitrate_per_port/1e12, need}; %#ok<SAGROW>
end
for a = 1:numel(prop.K_list)
    for bb = 1:2
        for c = 1:2
            if prop.K_list(a) == 1 && c == 2, continue; end
            r = squeeze(req_prop(a, bb, c, :)).';
            ok = find(r <= PTx_max, 1, 'last');
            if isempty(ok), ports = 0; need = NaN; else, ports = M_list(ok)*N; need = r(ok); end
            if prop.K_list(a) == 1, nm = 'conventional'; pat = '-'; else, nm = 'proposed'; pat = prop.pattern_list{c}; end
            rows(end+1, :) = {nm, prop.K_list(a), sprintf('A%d', bb), pat, ports, ports*bitrate_per_port/1e12, need}; %#ok<SAGROW>
        end
    end
end
fprintf('  %-13s %3s %-3s %-13s %9s %12s %9s\n', 'switch', 'K', 'A', 'pattern', 'ports', 'Tbit/s', 'PTx[dBm]');
for k = 1:size(rows, 1)
    fprintf('  %-13s %3d %-3s %-13s %9d %12.1f %9.1f\n', rows{k, :});
    fprintf(fid, '%s,%d,%s,%s,%d,%.1f,%.1f\n', rows{k, :});
end
fclose(fid);

%% 7. Hardware elements per port
% units: selectors = 1 x 2 switch elements; couplers = 2 x 1 coupler elements;
% EDFAs, AWGs (one ULCF pair = 2 AWGs) and 1 x 2 splitters as whole devices.
fprintf('\n=== Hardware per port (selectors in 1x2 elements, couplers in 2x1 elements) ===\n');
fid = fopen([file_base '_hardware_per_port.csv'], 'w');
fprintf(fid, 'switch,K,scheme,M,ports,selectors,couplers,EDFAs,AWGs,splitters\n');
fprintf('  %-13s %3s %-3s %4s %7s %10s %10s %8s %8s %10s\n', 'switch', 'K', 'A', 'M', 'ports', 'selectors', 'couplers', 'EDFAs', 'AWGs', 'splitters');
hw = @(sel, cpl, K) [sel, cpl, K/N, (1 + (K > 1))/N, (K > 1)*K/N];
for M = M_list
    for K = [1 12]
        agg = K*(N/K - 1)/N;  % aggregation coupler elements per port
        row = hw(M - 1, (M - 1) + agg, K);  % two-stage: DC output couplers + aggregation
        fprintf('  %-13s %3d %-3s %4d %7d %10.2f %10.2f %8.4f %8.4f %10.4f\n', 'two-stage', K, '-', M, M*N, row);
        fprintf(fid, 'two-stage,%d,-,%d,%d,%.2f,%.2f,%.4f,%.4f,%.4f\n', K, M, M*N, row);
        for bb = 1:2
            if bb == 1, sel = 4*(M - 1); cpl = agg; else, sel = 3*(M - 1); cpl = (M - 1) + agg; end
            row = hw(sel, cpl, K);
            if K == 1, nm = 'conventional'; else, nm = 'proposed'; end
            fprintf('  %-13s %3d %-3s %4d %7d %10.2f %10.2f %8.4f %8.4f %10.4f\n', nm, K, sprintf('A%d', bb), M, M*N, row);
            fprintf(fid, '%s,%d,A%d,%d,%d,%.2f,%.2f,%.4f,%.4f,%.4f\n', nm, K, bb, M, M*N, row);
        end
    end
end
fclose(fid);
fprintf('  (K = 12: 12 EDFAs per WR switch = 0.125 EDFA per port instead of 0.0104; 2 AWGs and 12 splitters per WR switch)\n');

%% 8. Where the gain comes from (SNR budget, no random numbers), K = 12
% (a) conventional; (b) proposed middle stage, all M-1 leaks in band (concentrated);
% (c) proposed, dispersed. (b) - (a) = middle-stage path, (c) - (b) = leaks on other wavelengths.
fprintf('\n=== Split of the SNR gain at the required power of the conventional switch, K = 12 ===\n');
fprintf('  %-3s %4s %8s | %7s %7s %7s | %8s %8s | limiting term of (c)\n', 'A', 'M', 'PTx', 'SNR(a)', 'SNR(b)', 'SNR(c)', 'middle', 'oob');
fid = fopen([file_base '_gain_split.csv'], 'w');
fprintf(fid, 'scheme,M,PTx_dBm,SNR_conv,SNR_prop_concentrated,SNR_prop_dispersed,gain_middle_stage_dB,gain_out_of_band_dB,limiting_term\n');
for bb = 1:2
    for d = 1:nM
        PTx = conv.required_PTx(bb, d);
        if isnan(PTx), PTx = 5; end
        p = claude_params_proposed(); p.sw_size = M_list(d); p.stage3_coupler_flag = bb - 1; p.PTx = PTx;
        p.K = 1; r = claude_chain_proposed(p); ba = claude_budget_proposed(p, r);
        p.K = 12; p.pattern = 'concentrated'; r = claude_chain_proposed(p); bc = claude_budget_proposed(p, r);
        p.pattern = 'dispersed'; r = claude_chain_proposed(p); bd = claude_budget_proposed(p, r);
        terms = [bd.nsr_ase1, bd.nsr_xt_sw1, bd.nsr_xt_awg, bd.nsr_xt_sw3, bd.nsr_ase2];
        names = {'EDFA ASE', 'stage-1 XT', 'ULCF AWG XT', 'stage-3 XT', 'pre-amp ASE'};
        [~, im] = max(terms);
        fprintf('  A%d %4d %8.1f | %7.2f %7.2f %7.2f | %+8.2f %+8.2f | %s (%.1f dB)\n', bb, M_list(d), PTx, ...
            ba.SNR_budget, bc.SNR_budget, bd.SNR_budget, bc.SNR_budget - ba.SNR_budget, ...
            bd.SNR_budget - bc.SNR_budget, names{im}, -10*log10(terms(im)));
        fprintf(fid, 'A%d,%d,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%s\n', bb, M_list(d), PTx, ba.SNR_budget, ...
            bc.SNR_budget, bd.SNR_budget, bc.SNR_budget - ba.SNR_budget, bd.SNR_budget - bc.SNR_budget, names{im});
    end
end
fclose(fid);

%% 9. Conclusion
concl = {
 'With selectors in the third stage (Scheme A1) the proposed switch lowers the required transmitter power by 3, 7, 10 and 13 dB for K = 2, 4, 8 and 12 at every size, for dispersed and for concentrated traffic alike: the third-stage leaks pass two selectors (SXR above 49 dB) and never matter, so this whole gain is the middle stage (coupler saving 3.5 to 14 dB, minus 0.5 to 1 dB for the ULCF pair: splitter, passband deviation, AWG crosstalk).'
 'With couplers in the third stage (Scheme A2) and dispersed traffic the gain splits into the two sources the task asks for: at the required power of the conventional switch and K = 12 the middle stage adds 4.1 / 2.7 / 0.7 / 0.9 dB of SNR and the leaks on other wavelengths add 1.7 / 2.8 / 3.8 / 4.4 dB for M = 16 / 32 / 64 / 128; the second source grows with M because the stage-3 crosstalk of the conventional A2 switch grows with M.'
 'The practical consequence is that Scheme A2 (25 percent fewer selector elements) becomes feasible at 12288 ports: -8 dBm with K = 8 and -12 dBm with K = 12, where the conventional A2 switch is infeasible even at 10 dBm; the proposal can buy the simpler third stage instead of more power.'
 'With concentrated traffic the third-stage leaks are all in band again and the gain of Scheme A2 shrinks with M and turns into a loss: at 6144 ports the required power goes from 4 dBm (conventional) to above 10 dBm (K = 2), -1 (K = 4), -7 (K = 8) and -9 dBm (K = 12), and 12288 ports stay infeasible for every K; the reason is that the EDFA output per channel is fixed by its saturation power, so the extra 6.5 dB of the ULCF pair and splitter in front of the 24 to 28 dB third-stage coupler and the pre-amplifier caps the SNR (13.45 dB at K = 2) regardless of transmitter power.'
 'The ULCF AWG crosstalk (K-1 leaks at 32 dB, SXR 21.4 dB at K = 12) is the term that limits the proposed switch with dispersed traffic in every case but A2 at 12288 ports, where the pre-amplifier noise limits; a better AWG crosstalk, not more input ports, is the next lever, and K = 8 already gives most of the gain.'
 'The price is hardware in the middle stage: K EDFAs, two AWGs and K splitters per WR switch instead of one EDFA and one AWG (0.125 instead of 0.0104 EDFAs per port at K = 12), while the selector count per port is unchanged; against 252 to 508 selector elements per port this is a small addition, and with A2 it saves 63 to 127 selector elements per port.'
 'The two-stage switch on the same parameter set reaches 768 ports at 3 dBm with K = 1 (the paper: 384 ports at 0 dBm) and 3072 ports at 0 dBm with K = 12, but 6144 ports need 6 dBm and 12288 are out of reach, so it does not compete with the three-stage switches above about 3000 ports.'
 'The advantage of the proposal is gone when the traffic is concentrated and the third stage uses couplers; with selectors in the third stage the advantage does not depend on the traffic at all. It would also be gone if the wavelength of a connection depended on the middle-stage switch (groups not identical in every WR switch), because then every rearrangement would need a laser retune.'
 'All required powers carry a resolution of 1 dB and a random error of one grid step at points near the FEC limit (seed 2 against seed 1: 63 of 71 entries equal, the rest differ by 1 dB); differences of 1 dB between curves are not significant, differences of 3 dB and more are.'
};
fprintf('\n=== Conclusion ===\n');
fid = fopen([file_base '_conclusion.txt'], 'w');
for k = 1:numel(concl), fprintf('%d. %s\n', k, concl{k}); fprintf(fid, '%d. %s\n', k, concl{k}); end
fclose(fid);
save([file_base '.mat'], 'f_two', 'f_conv', 'f_prop1', 'f_prop2', 'common', 'rows', 'req_prop', 'concl', 'time_stamp');
fprintf('\nSaved: %s_{common_parameters.csv, portcount.png, throughput.csv, hardware_per_port.csv, gain_split.csv, conclusion.txt, .mat}\n', file_base);

function f = local_newest(folder, pat)
d = dir(fullfile(folder, pat));
if isempty(d), f = ''; return; end
[~, order] = sort({d.name});
f = fullfile(folder, d(order(end)).name);
end
