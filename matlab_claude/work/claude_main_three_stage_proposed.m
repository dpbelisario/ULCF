%% claude_main_three_stage_proposed - Proposed switch: required transmitter power
% Claude's solution of work2, part 2. The search of main_three_stage_conventional
% applied to the chain claude_chain_proposed, for several K, both third-stage
% types, both traffic patterns and several sizes M.
% K = 1 uses the AWG of step22 (awg_type 'auto'), so its curve must equal the
% curve of main_three_stage_conventional (work3 checks it).
%
% Result arrays, index order (a, b, c, d[, e]):
%   a = position in K_list, b = position in list_stage3_coupler_flag,
%   c = position in pattern_list, d = position in list_sw_size, e = position in pin_ary
clear; close all; rng(1);

%% 1. Parameters
quick_flag = 1;
if quick_flag == 1
    datasize = 3e4;
    pin_ary = -25:1:10;
else
    datasize = 1.5e5;
    pin_ary = -25:0.5:10;
end
K_list = [1 2 4 8 12];
list_stage3_coupler_flag = [0 1];
pattern_list = {'dispersed', 'concentrated'};
list_sw_size = [16 32 64 128];
xt_wave_max = Inf;  % every leak its own waveform: K = 1 then equals main_three_stage_conventional bit for bit
seed = 1;
oob_flag = 0;  % leaks on other wavelengths left out (claude_test_proposed shows they do nothing)
up = 2;
tag = '';  % extra text in the file name, e.g. '_seed2'
% batch runs: the environment variable CLAUDE_SEED overrides the seed (and sets the tag)
env_seed = getenv('CLAUDE_SEED');
if ~isempty(env_seed), seed = str2double(env_seed); tag = sprintf('_seed%d', seed); end

p0 = claude_params_proposed();
p0.datasize = datasize; p0.xt_wave_max = xt_wave_max; p0.seed = seed;
p0.oob_flag = oob_flag; p0.up = up;
N = p0.N; BER_limit = p0.BER_limit;

work_folder = fileparts(mfilename('fullpath'));
if isempty(work_folder), error('run the whole file'); end
results_folder = fullfile(fileparts(work_folder), 'results');
if exist(results_folder, 'dir') ~= 7, mkdir(results_folder); end

%% 2. Derived values
pin_ary = sort(pin_ary);
[~, order_sw] = sort(list_sw_size);
nK = numel(K_list); nS = numel(list_stage3_coupler_flag); nP = numel(pattern_list);
nM = numel(list_sw_size); num_pin = numel(pin_ary);
required_PTx = NaN(nK, nS, nP, nM);
BER_ary = NaN(nK, nS, nP, nM, num_pin);
SNR_budget_ary = NaN(nK, nS, nP, nM, num_pin);
num_point = 0;

%% 3. Search (upward scan with warm start, as main_three_stage_conventional)
timer_search = tic;
fprintf('Search: %d symbols per point, %d powers from %.1f to %.1f dBm, xt_wave_max = %g\n', ...
    datasize, num_pin, pin_ary(1), pin_ary(end), xt_wave_max);
for a = 1:nK
    for bb = 1:nS
        for c = 1:nP
            if K_list(a) == 1 && c > 1
                % the pattern does not matter for K = 1: copy
                required_PTx(a, bb, c, :) = required_PTx(a, bb, 1, :);
                BER_ary(a, bb, c, :, :) = BER_ary(a, bb, 1, :, :);
                SNR_budget_ary(a, bb, c, :, :) = SNR_budget_ary(a, bb, 1, :, :);
                continue;
            end
            index_start = 1;
            for ite_sw = 1:nM
                d = order_sw(ite_sw);
                p = p0;
                p.K = K_list(a); p.stage3_coupler_flag = list_stage3_coupler_flag(bb);
                p.pattern = pattern_list{c}; p.sw_size = list_sw_size(d);
                flag_calc = 1;
                index_PTx = index_start;
                while flag_calc == 1 && index_PTx <= num_pin
                    p.PTx = pin_ary(index_PTx);
                    r = claude_chain_proposed(p);
                    b = claude_budget_proposed(p, r);
                    BER_ary(a, bb, c, d, index_PTx) = r.BER;
                    SNR_budget_ary(a, bb, c, d, index_PTx) = b.SNR_budget;
                    num_point = num_point + 1;
                    fprintf('    K = %2d, A%d, %-12s M = %3d, PTx = %5.1f dBm: BER = %.3e (budget SNR %.2f dB)\n', ...
                        p.K, p.stage3_coupler_flag + 1, p.pattern, p.sw_size, p.PTx, r.BER, b.SNR_budget);
                    if r.BER <= BER_limit
                        required_PTx(a, bb, c, d) = p.PTx;
                        flag_calc = 0;
                    else
                        index_PTx = index_PTx + 1;
                    end
                end
                index_start = index_PTx;
                fprintf('  K = %2d, A%d, %-12s M = %3d (%5d ports): required PTx = %5.1f dBm\n', ...
                    p.K, p.stage3_coupler_flag + 1, p.pattern, p.sw_size, p.sw_size*N, ...
                    required_PTx(a, bb, c, d));
            end
        end
    end
end
elapsed_time = toc(timer_search);
fprintf('%d operating points in %.1f s (%.2f s per point)\n', num_point, elapsed_time, ...
    elapsed_time/max(num_point, 1));

%% 4. Port count versus transmitter power
% data_PC(e, idx) with idx over all (a, bb, c) combinations in that nesting order
num_curve = nK*nS*nP;
data_PC = zeros(num_pin, num_curve);
curve_name = cell(1, num_curve);
idx = 0;
for a = 1:nK
    for bb = 1:nS
        for c = 1:nP
            idx = idx + 1;
            curve_name{idx} = sprintf('K%d_A%d_%s', K_list(a), list_stage3_coupler_flag(bb) + 1, ...
                pattern_list{c});
            for e = 1:num_pin
                for d = 1:nM
                    if required_PTx(a, bb, c, d) <= pin_ary(e)
                        data_PC(e, idx) = max(data_PC(e, idx), list_sw_size(d)*N);
                    end
                end
            end
        end
    end
end

%% 5. Table
fprintf('\nRequired transmitter power [dBm] (NaN = not reached up to %.1f dBm), columns M = %s\n', ...
    pin_ary(end), mat2str(list_sw_size));
for bb = 1:nS
    for c = 1:nP
        fprintf('Scheme A%d, %s traffic\n', list_stage3_coupler_flag(bb) + 1, pattern_list{c});
        for a = 1:nK
            fprintf('  K = %2d :', K_list(a)); fprintf('%7.1f', squeeze(required_PTx(a, bb, c, :))); fprintf('\n');
        end
    end
end

%% 6. Figure
fig = figure('Position', [100 100 900 520]);
if isprop(fig, 'Theme'), set(fig, 'Theme', 'light'); end
cols = lines(nK);
hold on;
for a = 1:nK
    for bb = 1:nS
        for c = 1:nP
            idx = (a - 1)*nS*nP + (bb - 1)*nP + c;
            y = data_PC(:, idx); y(y == 0) = NaN;
            if list_stage3_coupler_flag(bb) == 0, ls = '-'; else, ls = '--'; end
            if c == 1, mk = 'o'; else, mk = 'x'; end
            stairs(pin_ary, y, 'LineStyle', ls, 'Marker', mk, 'Color', cols(a, :), ...
                'DisplayName', strrep(curve_name{idx}, '_', ' '));
        end
    end
end
grid on; set(gca, 'YScale', 'log'); set(gca, 'YTick', list_sw_size*N);
ylim([min(list_sw_size)*N/1.5, max(list_sw_size)*N*1.5]); xlim([pin_ary(1), pin_ary(end)]);
xlabel('Transmitter power PTx [dBm]'); ylabel('Port count M*N');
title(sprintf('Proposed three-stage switch: %d bits/symbol, %.0f GBd, N = %d (solid A1, dashed A2; o dispersed, x concentrated)', ...
    p0.mod_flag, p0.baudrate/1e9, N));
legend('Location', 'eastoutside', 'NumColumns', 2);

%% 7. Save
time_stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
file_base = fullfile(results_folder, ['claude_three_stage_proposed' tag '_' time_stamp]);
matlab_version = version;
save([file_base '.mat'], 'quick_flag', 'datasize', 'pin_ary', 'K_list', 'list_stage3_coupler_flag', ...
    'pattern_list', 'list_sw_size', 'xt_wave_max', 'seed', 'oob_flag', 'up', 'p0', 'N', 'BER_limit', ...
    'required_PTx', 'BER_ary', 'SNR_budget_ary', 'data_PC', 'curve_name', 'num_point', ...
    'elapsed_time', 'time_stamp', 'matlab_version');
fid = fopen([file_base '_required_PTx.csv'], 'w');
fprintf(fid, 'K,stage3_coupler_flag,pattern'); fprintf(fid, ',M%d', list_sw_size); fprintf(fid, '\n');
for a = 1:nK
    for bb = 1:nS
        for c = 1:nP
            fprintf(fid, '%d,%d,%s', K_list(a), list_stage3_coupler_flag(bb), pattern_list{c});
            fprintf(fid, ',%.1f', squeeze(required_PTx(a, bb, c, :))); fprintf(fid, '\n');
        end
    end
end
fclose(fid);
fid = fopen([file_base '_portcount.csv'], 'w');
fprintf(fid, 'PTx_dBm'); fprintf(fid, ',%s', curve_name{:}); fprintf(fid, '\n');
for e = 1:num_pin
    fprintf(fid, '%.1f', pin_ary(e)); fprintf(fid, ',%d', data_PC(e, :)); fprintf(fid, '\n');
end
fclose(fid);
saveas(fig, [file_base '.png']);
fprintf('\nSaved in %s: claude_three_stage_proposed%s_%s.{mat,_required_PTx.csv,_portcount.csv,png}\n', ...
    results_folder, tag, time_stamp);
