%% main_three_stage_proposed - required transmitter power of the proposed switch

clear; close all;
if exist('attenuation', 'file') ~= 2
    error(['main_three_stage_proposed: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters
pin_ary = -25:1:10;
K_list = [1 2 4 8 12];
list_stage3_coupler_flag = [0 1];
pattern_list = {'dispersed', 'concentrated'};
list_sw_size = [16 32 64 128];

p = my_params();
N = p.N;
BER_limit = p.BER_limit;

work_folder = fileparts(mfilename('fullpath'));
if isempty(work_folder)
    error(['main_three_stage_proposed: run the whole file (F5 or type its name). ' ...
        'The folder of this file is not known when a single section is run.']);
end
results_folder = fullfile(fileparts(work_folder), 'results');

%% 2. Values that follow from the parameters
pin_ary = sort(pin_ary);
[~, order_sw] = sort(list_sw_size);
num_K = length(K_list);
num_scheme = length(list_stage3_coupler_flag);
num_pattern = length(pattern_list);
num_sw = length(list_sw_size);
num_pin = length(pin_ary);

required_PTx = NaN(num_K, num_scheme, num_pattern, num_sw);
BER_ary = NaN(num_K, num_scheme, num_pattern, num_sw, num_pin);
num_point = 0;

%% 3. Search for the required transmitter power
timer_search = tic;
fprintf('Search: %d symbols per point, %d powers from %.1f to %.1f dBm\n', p.datasize, ...
    num_pin, pin_ary(1), pin_ary(end));
for ite_K = 1:num_K
    p.K = K_list(ite_K);
    for ite_scheme = 1:num_scheme
        p.stage3_coupler_flag = list_stage3_coupler_flag(ite_scheme);
        for ite_pattern = 1:num_pattern
            p.pattern = pattern_list{ite_pattern};
            index_start = 1;
            for ite_sw = 1:num_sw
                index_sw_size = order_sw(ite_sw);
                p.sw_size = list_sw_size(index_sw_size);
                flag_calc = 1;
                index_PTx = index_start;
                while flag_calc == 1 && index_PTx <= num_pin
                    p.PTx = pin_ary(index_PTx);
                    r = my_chain(p);
                    BER_ary(ite_K, ite_scheme, ite_pattern, index_sw_size, index_PTx) = r.BER;
                    num_point = num_point + 1;
                    if r.BER <= BER_limit
                        required_PTx(ite_K, ite_scheme, ite_pattern, index_sw_size) = p.PTx;
                        flag_calc = 0;
                    else
                        index_PTx = index_PTx + 1;
                    end
                end
                index_start = index_PTx;
                fprintf('  K = %2d, A%d, %-12s, M = %3d (%5d ports): required PTx = %5.1f dBm\n', ...
                    p.K, p.stage3_coupler_flag + 1, p.pattern, p.sw_size, p.sw_size*N, ...
                    required_PTx(ite_K, ite_scheme, ite_pattern, index_sw_size));
            end
        end
    end
end
elapsed_time = toc(timer_search);
fprintf('%d operating points in %.1f s (%.2f s per point)\n', num_point, ...
    elapsed_time, elapsed_time/num_point);

%% 4. Port count versus transmitter power
port_count = zeros(num_K, num_scheme, num_pattern, num_pin);
for ite_K = 1:num_K
    for ite_scheme = 1:num_scheme
        for ite_pattern = 1:num_pattern
            for index_PTx = 1:num_pin
                for index_sw_size = 1:num_sw
                    if required_PTx(ite_K, ite_scheme, ite_pattern, index_sw_size) ...
                            <= pin_ary(index_PTx)
                        port_count(ite_K, ite_scheme, ite_pattern, index_PTx) = max( ...
                            port_count(ite_K, ite_scheme, ite_pattern, index_PTx), ...
                            list_sw_size(index_sw_size)*N);
                    end
                end
            end
        end
    end
end

%% 5. Tables
for ite_scheme = 1:num_scheme
    for ite_pattern = 1:num_pattern
        fprintf('\nScheme A%d, %s traffic: required PTx [dBm] (NaN = not reached up to %.1f dBm)\n', ...
            list_stage3_coupler_flag(ite_scheme) + 1, pattern_list{ite_pattern}, pin_ary(end));
        fprintf('  %-4s', 'K');
        for index_sw_size = order_sw
            fprintf(' %7s', sprintf('M=%d', list_sw_size(index_sw_size)));
        end
        fprintf('\n');
        for ite_K = 1:num_K
            fprintf('  %-4d', K_list(ite_K));
            fprintf(' %7.1f', squeeze(required_PTx(ite_K, ite_scheme, ite_pattern, order_sw)));
            fprintf('\n');
        end
    end
end

%% 6. Figure: port count versus transmitter power
fig = figure('Position', [100 100 1000 700]);
if isprop(fig, 'Theme')
    set(fig, 'Theme', 'light');
end
tiledlayout(num_scheme, num_pattern, 'TileSpacing', 'compact');
for ite_scheme = 1:num_scheme
    for ite_pattern = 1:num_pattern
        nexttile;
        hold on;
        for ite_K = 1:num_K
            pc = squeeze(port_count(ite_K, ite_scheme, ite_pattern, :));
            pc(pc == 0) = NaN;
            stairs(pin_ary, pc, 'o-', 'LineWidth', 1.2, 'MarkerSize', 4, ...
                'DisplayName', sprintf('K = %d', K_list(ite_K)));
        end
        grid on;
        set(gca, 'YScale', 'log');
        set(gca, 'YTick', unique(list_sw_size)*N);
        set(gca, 'YMinorTick', 'off');
        set(gca, 'YMinorGrid', 'off');
        ylim([min(list_sw_size)*N/1.5, max(list_sw_size)*N*1.5]);
        xlim([pin_ary(1), pin_ary(end)]);
        xlabel('Transmitter power PTx [dBm]');
        ylabel('Port count M*N');
        title(sprintf('Scheme A%d, %s', list_stage3_coupler_flag(ite_scheme) + 1, ...
            pattern_list{ite_pattern}));
        legend('Location', 'southeast');
    end
end

%% 7. Save the results
if exist(results_folder, 'dir') ~= 7
    mkdir(results_folder);
end
time_stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
file_base = fullfile(results_folder, ['three_stage_proposed_' time_stamp]);
matlab_version = version;

save([file_base '.mat'], 'pin_ary', 'K_list', 'list_stage3_coupler_flag', ...
    'pattern_list', 'list_sw_size', 'p', 'required_PTx', 'BER_ary', 'port_count', ...
    'num_point', 'elapsed_time', 'time_stamp', 'matlab_version');

fid = fopen([file_base '_required_PTx.csv'], 'w');
fprintf(fid, 'K,stage3_coupler_flag,pattern');
fprintf(fid, ',M%d', list_sw_size);
fprintf(fid, '\n');
for ite_K = 1:num_K
    for ite_scheme = 1:num_scheme
        for ite_pattern = 1:num_pattern
            fprintf(fid, '%d,%d,%s', K_list(ite_K), list_stage3_coupler_flag(ite_scheme), ...
                pattern_list{ite_pattern});
            fprintf(fid, ',%.1f', squeeze(required_PTx(ite_K, ite_scheme, ite_pattern, :)));
            fprintf(fid, '\n');
        end
    end
end
fclose(fid);

saveas(fig, [file_base '.png']);

fprintf('\nSaved in %s\n', results_folder);
fprintf('  three_stage_proposed_%s.mat\n', time_stamp);
fprintf('  three_stage_proposed_%s_required_PTx.csv\n', time_stamp);
fprintf('  three_stage_proposed_%s.png\n', time_stamp);
