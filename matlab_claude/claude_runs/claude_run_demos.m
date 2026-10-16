function claude_run_demos()
% claude_run_demos - run every demo script in batch mode, capture text and figures.
% Written by Claude. Call from the matlab_claude folder after setup_path.
% A function, because the demos start with "clear" and would wipe a script's variables.
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'claude_runs', 'demos_out');
if ~exist(out, 'dir'), mkdir(out); end
demos = {'demo12_units_power_budget', 'demo13_waveform_fft_filter', ...
         'demo14_coherent_rx_dsp_ber', 'demo15_edfa_ase', ...
         'demo16_space_switch_crosstalk', 'demo17_awg_wavelength_routing'};
for d = 1:numel(demos)
    name = demos{d};
    close all;
    logfile = fullfile(out, [name '.txt']);
    if exist(logfile, 'file'), delete(logfile); end
    diary(logfile);
    fprintf('\n==================== %s ====================\n', name);
    t0 = tic;
    try
        evalin('base', name);
        fprintf('\n[claude] %s finished in %.1f s\n', name, toc(t0));
    catch err
        fprintf('\n[claude] %s FAILED after %.1f s: %s\n', name, toc(t0), err.message);
        for k = 1:numel(err.stack)
            fprintf('    at %s line %d\n', err.stack(k).name, err.stack(k).line);
        end
    end
    diary off;
    figs = findall(groot, 'Type', 'figure');
    for k = 1:numel(figs)
        saveas(figs(k), fullfile(out, sprintf('%s_fig%d.png', name, numel(figs)-k+1)));
    end
    close all;
end
fprintf('\n[claude] all demos done\n');
end
