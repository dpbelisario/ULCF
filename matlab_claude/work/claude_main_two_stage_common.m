%% claude_main_two_stage_common - Two-stage ULCF switch on the COMMON parameter set
% Claude's script for work3. main_two_stage_ULCF uses the parameters of the earlier
% two-stage study (32QAM, 24 GBd, NF 5, ER 36, multicore fiber, quasi-Nyquist grid).
% A fair comparison with the three-stage switches needs the common set of work3:
% 16QAM at 32 GBd on the 50-GHz grid, NF 6, ER 35, single-core fiber, carrier on
% the passband centre (plus the ULCF deviation), the AWG of step22 for K = 1 and
% the ULCF pair + 1 x 2 splitter for K > 1. Everything else is the chain of
% step21_two_stage_one_point / main_two_stage_ULCF, unchanged.
%
% Result arrays: required_PTx(a, b), BER_ary(a, b, c) with a = position in
% ULCF_deg_ary, b = position in list_dcs_input_port_num, c = position in pin_ary.
clear; close all; rng(1);

%% 1. Parameters
quick_flag = 1;
if quick_flag == 1
    datasize = 3e4;
    pin_ary = -20:1:15;
else
    datasize = 1.5e5;
    pin_ary = -20:0.5:15;
end
list_dcs_input_port_num = [2 4 8 16 32 64 128];  % M of the DC switch
ULCF_deg_ary = [1 2 4 8 12];  % K
% --- common set (= step22) ---
mod_flag = 4; up = 2; baudrate = 32e9; pol_flag = 1; fiber_flag = 0;
Fan_in_loss = 1.5; Fan_out_loss = 1.5; N = 96; signal_interval = 50e9;
NF = 6; edfa_sat1 = 20; edfa_sat2 = 10; NF2 = 4; rolloff = 0;
dcs_ex_ratio = 35;  % the same extinction ratio as the selectors of the three-stage switch
Morder = 16; seed = 1; BER_limit = 1e-2;
flg_NWDM = 0;
% --- AWG of each type ---
AWG_loss_conv = 6; FWHM_conv = 50e9;  % K = 1: AWG of step22
AWG_loss_ulcf = 9; FWHM_ulcf = 66.6e9; splitter_loss = coupler_loss(2);  % K > 1
AWG_XT = 32;

work_folder = fileparts(mfilename('fullpath'));
if isempty(work_folder), error('run the whole file'); end
results_folder = fullfile(fileparts(work_folder), 'results');
if exist(results_folder, 'dir') ~= 7, mkdir(results_folder); end

%% 2. Derived values
Mary = 2^mod_flag; Fs = up*baudrate; L = datasize*up;
Hrcos = rcosfilter(L, baudrate, Fs, rolloff);
Hband = nyquistfilter(L, 0, Fs, baudrate*(1 + rolloff));
pin_ary = sort(pin_ary);
[~, order_dcs] = sort(list_dcs_input_port_num);
num_deg = numel(ULCF_deg_ary); num_dcs = numel(list_dcs_input_port_num); num_pin = numel(pin_ary);
required_PTx = NaN(num_deg, num_dcs);
BER_ary = NaN(num_deg, num_dcs, num_pin);
num_point = 0;

%% 3. Search
timer_search = tic;
fprintf('Search: %d symbols per point, %d powers from %.1f to %.1f dBm\n', datasize, num_pin, ...
    pin_ary(1), pin_ary(end));
for a = 1:num_deg
    ULCF_deg = ULCF_deg_ary(a);
    assert(mod(N, ULCF_deg) == 0, 'K must divide N');
    index_start = 1;
    for ite_dcs = 1:num_dcs
        b = order_dcs(ite_dcs);
        dcs_input_port_num = list_dcs_input_port_num(b);
        flag_calc = 1;
        index_PTx = index_start;
        while flag_calc == 1 && index_PTx <= num_pin
            PTx = pin_ary(index_PTx);
            rng(seed);
            % ---- chain begin (step21, common parameters) ----
            % [1] transmitters: one per DC input, the middle one is the target
            pin = PTx - 3*pol_flag;
            target_port = ceil(dcs_input_port_num/2);
            signal = zeros(L, dcs_input_port_num);
            for k = 1:dcs_input_port_num
                if k == target_port
                    [signal(:, k), data, data_mod] = TL_QAM(datasize, up, Hrcos, pin, mod_flag);
                else
                    [signal(:, k), ~, ~] = TL_QAM(datasize, up, Hrcos, pin, mod_flag);
                end
            end
            % [2] fan-in/out
            fiber_loss = 0;
            if fiber_flag == 1, fiber_loss = Fan_in_loss + Fan_out_loss; end
            signal = attenuation(signal, fiber_loss);
            % [3] DC switch: loss for all, extinction ratio for the others, then sum
            dcs_loss = DCS_loss(dcs_input_port_num);
            signal = attenuation(signal, dcs_loss);
            for k = 1:dcs_input_port_num
                if k ~= target_port
                    signal(:, k) = attenuation(signal(:, k), dcs_ex_ratio);
                end
            end
            signal = sum(signal, 2);
            % [4] aggregation coupler of N/K wavelengths
            N_agg = N/ULCF_deg;
            signal = attenuation(signal, coupler_loss(N_agg));
            % [5] EDFA shared by N_agg wavelengths
            sat1 = edfa_sat1 - 3*pol_flag;
            edfaGain = sat1 - 10*log10(N_agg) - calc_signal_power(signal);
            [signal, ~] = amplified_by_EDFA3(signal, Fs, edfaGain, NF, sat1, N_agg, signal_interval);
            % [6] AWG: step22 AWG for K = 1, splitter + ULCF pair for K > 1
            if ULCF_deg == 1
                AWG_loss_tot = AWG_loss_conv; FWHM = FWHM_conv; shift = 0;
            else
                AWG_loss_tot = AWG_loss_ulcf + splitter_loss; FWHM = FWHM_ulcf;
                shift = ULCF_dev_freq(ULCF_deg) + 12.5e9*(flg_NWDM ~= 0);
            end
            signal = awg(signal, AWG_loss_tot, shift, Fs, FWHM, AWG_XT, 1);
            % [7] in-band crosstalk of the ULCF AWG (K > 1)
            if ULCF_deg > 1
                sigpw = calc_signal_power(apply_filter(signal, Hband, 1));
                AWG_crosstalk = zeros(L, ULCF_deg - 1);
                for k = 1:ULCF_deg-1
                    [AWG_crosstalk(:, k), ~, ~] = TL_QAM(datasize, up, Hrcos, sigpw, mod_flag);
                end
                signal = signal + sum(attenuation(AWG_crosstalk, AWG_XT), 2);
            end
            % [8] fan-in/out
            signal = attenuation(signal, fiber_loss);
            % [9] pre-amplifier
            sat2 = edfa_sat2 - 3*pol_flag;
            edfaGain = sat2 - calc_signal_power(signal);
            [signal, ~] = amplified_by_EDFA3(signal, Fs, edfaGain, NF2, sat2, 1, signal_interval);
            % [10] receiver
            H = nyquistfilter(length(signal), 0, Fs, baudrate*(1 + rolloff));
            signal = apply_filter(signal, H, 1);
            training_num = floor(datasize/3);
            signal = adequalizet(signal, Mary, Morder, 1/256, data_mod(1:training_num), up);
            BER = measure_BER_QAM(signal(training_num+1:end), data(mod_flag*training_num+1:end), mod_flag);
            % ---- chain end ----
            BER_ary(a, b, index_PTx) = BER;
            num_point = num_point + 1;
            fprintf('    K = %2d, M = %3d, PTx = %5.1f dBm: BER = %.3e\n', ULCF_deg, ...
                dcs_input_port_num, PTx, BER);
            if BER <= BER_limit
                required_PTx(a, b) = PTx;
                flag_calc = 0;
            else
                index_PTx = index_PTx + 1;
            end
        end
        index_start = index_PTx;
        fprintf('  K = %2d, M = %3d (%5d ports): required PTx = %5.1f dBm\n', ULCF_deg, ...
            dcs_input_port_num, dcs_input_port_num*N, required_PTx(a, b));
    end
end
elapsed_time = toc(timer_search);
fprintf('%d operating points in %.1f s (%.2f s per point)\n', num_point, elapsed_time, ...
    elapsed_time/max(num_point, 1));

%% 4. Port count versus transmitter power
data_PC = zeros(num_pin, num_deg + 1);
data_PC(:, 1) = pin_ary.';
for a = 1:num_deg
    for e = 1:num_pin
        for b = 1:num_dcs
            if required_PTx(a, b) <= pin_ary(e)
                data_PC(e, a + 1) = max(data_PC(e, a + 1), list_dcs_input_port_num(b)*N);
            end
        end
    end
end
fprintf('\nRequired transmitter power [dBm], rows K, columns M = %s\n', mat2str(list_dcs_input_port_num));
for a = 1:num_deg
    fprintf('  K = %2d :', ULCF_deg_ary(a)); fprintf('%7.1f', required_PTx(a, :)); fprintf('\n');
end

%% 5. Figure
fig = figure('Position', [100 100 800 480]);
if isprop(fig, 'Theme'), set(fig, 'Theme', 'light'); end
cols = lines(num_deg); hold on;
for a = 1:num_deg
    y = data_PC(:, a + 1); y(y == 0) = NaN;
    stairs(pin_ary, y, '-o', 'Color', cols(a, :), 'DisplayName', sprintf('K = %d', ULCF_deg_ary(a)));
end
grid on; set(gca, 'YScale', 'log'); set(gca, 'YTick', list_dcs_input_port_num*N);
ylim([min(list_dcs_input_port_num)*N/1.5, max(list_dcs_input_port_num)*N*1.5]);
xlim([pin_ary(1), pin_ary(end)]);
xlabel('Transmitter power PTx [dBm]'); ylabel('Port count M*N');
title(sprintf('Two-stage ULCF switch, common set: %d bits/symbol, %.0f GBd, N = %d', mod_flag, baudrate/1e9, N));
legend('Location', 'southeast');

%% 6. Save
time_stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
file_base = fullfile(results_folder, ['claude_two_stage_common_' time_stamp]);
matlab_version = version;
save([file_base '.mat'], 'quick_flag', 'datasize', 'pin_ary', 'list_dcs_input_port_num', 'ULCF_deg_ary', ...
    'mod_flag', 'up', 'baudrate', 'pol_flag', 'fiber_flag', 'N', 'signal_interval', 'NF', 'edfa_sat1', ...
    'edfa_sat2', 'NF2', 'rolloff', 'dcs_ex_ratio', 'flg_NWDM', 'AWG_loss_conv', 'FWHM_conv', ...
    'AWG_loss_ulcf', 'FWHM_ulcf', 'splitter_loss', 'AWG_XT', 'Morder', 'seed', 'BER_limit', ...
    'required_PTx', 'BER_ary', 'data_PC', 'num_point', 'elapsed_time', 'time_stamp', 'matlab_version');
fid = fopen([file_base '_required_PTx.csv'], 'w');
fprintf(fid, 'ULCF_deg'); fprintf(fid, ',M%d', list_dcs_input_port_num); fprintf(fid, '\n');
for a = 1:num_deg
    fprintf(fid, '%d', ULCF_deg_ary(a)); fprintf(fid, ',%.1f', required_PTx(a, :)); fprintf(fid, '\n');
end
fclose(fid);
fid = fopen([file_base '_portcount.csv'], 'w');
fprintf(fid, 'PTx_dBm'); fprintf(fid, ',K%d', ULCF_deg_ary); fprintf(fid, '\n');
for e = 1:num_pin
    fprintf(fid, '%.1f', data_PC(e, 1)); fprintf(fid, ',%d', data_PC(e, 2:end)); fprintf(fid, '\n');
end
fclose(fid);
saveas(fig, [file_base '.png']);
fprintf('\nSaved in %s: claude_two_stage_common_%s.{mat,_required_PTx.csv,_portcount.csv,png}\n', ...
    results_folder, time_stamp);
