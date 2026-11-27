function claude_run_oneshot(seeds)
% claude_run_oneshot - reproduce the whole Clos-ULCF solution in one call.
% Written by Claude. Runs, in order:
%   1. setup_path + run_all_tests                (library self-tests)
%   2. claude_work1_wavelength_rule              (work1: wavelength rule, leak counts)
%   3. claude_test_proposed                      (work2: chain tests, K = 1 == step22)
%   4. claude_step23_proposed_one_point          (work2: default operating point)
%   5. claude_main_three_stage_proposed per seed (work2: required-PTx sweep)
%   6. claude_main_two_stage_common              (work3: two-stage on the common set)
%   7. claude_work3_comparison                   (work3: figure, tables, conclusion)
% Usage (MATLAB, from anywhere):
%   claude_run_oneshot          % seeds 1 and 2, as in REPORT.md (~5 min quick settings)
%   claude_run_oneshot(1)       % seed 1 only
% Each step's console goes to claude_runs/oneshot_out/<step>.txt and its figures
% to claude_runs/oneshot_out/<step>_fig<n>.png. Result files go to results/ as usual.
% A failing step is reported and the run continues; the summary lists every step.
if nargin < 1, seeds = [1 2]; end
root = fileparts(fileparts(mfilename('fullpath')));
out = fullfile(root, 'claude_runs', 'oneshot_out');
if ~exist(out, 'dir'), mkdir(out); end
old_dir = cd(root);
cleanup = onCleanup(@() cd(old_dir));
evalin('base', 'setup_path');

steps = {'run_all_tests', 'claude_work1_wavelength_rule', 'claude_test_proposed', ...
         'claude_step23_proposed_one_point'};
envs = {'', '', '', ''};
for s = seeds(:)'
    steps{end+1} = 'claude_main_three_stage_proposed'; %#ok<AGROW>
    envs{end+1} = sprintf('%d', s); %#ok<AGROW>
end
steps = [steps, {'claude_main_two_stage_common', 'claude_work3_comparison'}];
envs = [envs, {'', ''}];

status = cell(numel(steps), 1);
times = zeros(numel(steps), 1);
t_all = tic;
for d = 1:numel(steps)
    name = steps{d};
    label = name;
    if ~isempty(envs{d}), label = sprintf('%s_seed%s', name, envs{d}); end
    setenv('CLAUDE_SEED', envs{d});
    close all;
    logfile = fullfile(out, [label '.txt']);
    if exist(logfile, 'file'), delete(logfile); end
    diary(logfile);
    fprintf('\n==================== %s ====================\n', label);
    t0 = tic;
    try
        evalin('base', name);
        status{d} = 'ok';
    catch err
        status{d} = ['FAILED: ' err.message];
        fprintf('\n[oneshot] %s FAILED: %s\n', label, err.message);
        for k = 1:numel(err.stack)
            fprintf('    at %s line %d\n', err.stack(k).name, err.stack(k).line);
        end
    end
    times(d) = toc(t0);
    fprintf('\n[oneshot] %s: %s (%.1f s)\n', label, status{d}, times(d));
    diary off;
    figs = findall(groot, 'Type', 'figure');
    for k = 1:numel(figs)
        saveas(figs(k), fullfile(out, sprintf('%s_fig%d.png', label, numel(figs)-k+1)));
    end
    close all;
    evalin('base', 'setup_path');  % the step scripts call clear; keep the path set
end
setenv('CLAUDE_SEED', '');

fprintf('\n==================== oneshot summary ====================\n');
for d = 1:numel(steps)
    label = steps{d};
    if ~isempty(envs{d}), label = sprintf('%s_seed%s', label, envs{d}); end
    fprintf('%-45s %7.1f s  %s\n', label, times(d), status{d});
end
fprintf('total %.1f s; logs and figures in %s\n', toc(t_all), out);
fprintf('Compare the tables with claude_runs/REPORT.md.\n');
end
