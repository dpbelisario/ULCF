function claude_run_baseline()
% claude_run_baseline - run the tests, both step scripts and both main scripts as given.
% Written by Claude. Captures text to claude_runs/baseline_out and saves figures there.
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'claude_runs', 'baseline_out');
if ~exist(out, 'dir'), mkdir(out); end
scripts = {'run_all_tests', 'step21_two_stage_one_point', 'step22_three_stage_one_point', ...
           'main_two_stage_ULCF', 'main_three_stage_conventional'};
for d = 1:numel(scripts)
    name = scripts{d};
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
fprintf('\n[claude] baseline done\n');
end
