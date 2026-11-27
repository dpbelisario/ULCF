# Clos-ULCF solution: full code in one file

Generated bundle of every script Claude wrote for work1–work3 (read-only copy; the runnable files are in `work/` and `claude_runs/`).
To run everything in one call: `cd matlab_claude; addpath claude_runs; claude_run_oneshot`.
Results and answers: `claude_runs/REPORT.md`.

## Contents
- `claude_runs/claude_run_oneshot.m` (79 lines)
- `work/claude_group_of.m` (27 lines)
- `work/claude_wavelength_of.m` (23 lines)
- `work/claude_inband_leaks.m` (45 lines)
- `work/claude_work1_wavelength_rule.m` (262 lines)
- `work/claude_params_proposed.m` (64 lines)
- `work/claude_chain_proposed.m` (204 lines)
- `work/claude_budget_proposed.m` (106 lines)
- `work/claude_test_proposed.m` (88 lines)
- `work/claude_step23_proposed_one_point.m` (108 lines)
- `work/claude_main_three_stage_proposed.m` (191 lines)
- `work/claude_main_two_stage_common.m` (206 lines)
- `work/claude_work3_comparison.m` (267 lines)
- `claude_runs/claude_run_baseline.m` (34 lines)
- `claude_runs/claude_run_demos.m` (36 lines)

## `claude_runs/claude_run_oneshot.m`

```matlab
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
```

## `work/claude_group_of.m`

```matlab
function g = claude_group_of(i, N, K)
%CLAUDE_GROUP_OF  Input group of first-stage switch i in the proposed switch.
%
%   g = claude_group_of(i, N, K)
%
%   The N first-stage switches are divided into K groups of N/K consecutive
%   switches: group 1 = switches 1 .. N/K, group 2 = N/K+1 .. 2N/K, and so on.
%   Group g enters input port g of the ULCF AWG pair in EVERY wavelength-routing
%   switch (design rule of the proposal, docs/01 paragraph 6 and work1 header).
%
%   Inputs
%     i : first-stage switch number(s), 1 .. N (array allowed)
%     N : number of first-stage switches = number of wavelength channels
%     K : number of input groups = input ports of the ULCF AWG; K must divide N
%   Output
%     g : group number(s), 1 .. K, same shape as i
%
%   Written by Claude for work1. Any other division into K equal groups gives the
%   same leak counts (see claude_work1_wavelength_rule, section 3).
if mod(N, K) ~= 0
    error('claude_group_of: K = %d must divide N = %d.', K, N);
end
if any(i(:) < 1) || any(i(:) > N) || any(i(:) ~= round(i(:)))
    error('claude_group_of: i must be an integer from 1 to N.');
end
g = floor((i - 1)*K/N) + 1;
end
```

## `work/claude_wavelength_of.m`

```matlab
function ch = claude_wavelength_of(i, j, N, K)
%CLAUDE_WAVELENGTH_OF  Wavelength rule of the proposed three-stage switch.
%
%   ch = claude_wavelength_of(i, j, N, K)
%
%   Channel of a connection from first-stage switch i to third-stage switch j.
%   It does NOT depend on the wavelength-routing (WR) switch that carries the
%   connection: every WR switch connects group g(i) to its AWG input port g(i),
%   and output port j of every WR switch goes to third-stage switch j. So
%     ch = awg_channel(g(i), j, N) = mod(j + g(i) - 2, N) + 1
%   With K = 1 every switch is in group 1 and ch = j: the conventional switch.
%
%   Inputs
%     i, j : first-stage and third-stage switch numbers, 1 .. N (arrays of the
%            same shape, or one scalar and one array)
%     N, K : number of channels (= switches per stage) and number of input groups
%   Output
%     ch   : wavelength channel number(s), 1 .. N
%
%   Written by Claude for work1.
g = claude_group_of(i, N, K);
ch = awg_channel(g, j, N);
end
```

## `work/claude_inband_leaks.m`

```matlab
function [n_inband, n_per_group] = claude_inband_leaks(M, K, pattern)
%CLAUDE_INBAND_LEAKS  Leaks on the wavelength of the target in one third-stage switch.
%
%   [n_inband, n_per_group] = claude_inband_leaks(M, K, pattern)
%
%   A third-stage switch has M inputs, one from each WR switch. All M carry a
%   signal (full load, as step22 assumes). Each signal comes from some first-stage
%   switch, and its wavelength is fixed by the input group of that switch (see
%   claude_wavelength_of). A leak is on the target's wavelength (in band) exactly
%   when its source is in the SAME input group as the target's source.
%
%   pattern = 'dispersed'
%     The M sources are spread as evenly as possible over the K groups, and the
%     target is in a group of the largest size: n_inband = ceil(M/K) - 1.
%     This is the worst case of an even spread. (For sources drawn at random
%     with equal probability, the mean is (M-1)/K; see claude_work1 section 4.)
%   pattern = 'concentrated'
%     All M sources are in the target's group: n_inband = M - 1. The wavelengths
%     are all equal, exactly as in the conventional switch.
%   With K = 1 both patterns give M - 1 (the conventional switch, step22 block [7]).
%
%   Outputs
%     n_inband    : number of leaks on the target's wavelength
%     n_per_group : 1 x K vector, number of the M signals in each group, the
%                   target's group first (group order is otherwise arbitrary)
%
%   Written by Claude for work1.
if M < 1 || K < 1 || M ~= round(M) || K ~= round(K)
    error('claude_inband_leaks: M and K must be positive integers.');
end
switch lower(pattern)
    case 'dispersed'
        base = floor(M/K);
        extra = M - base*K;  % the first "extra" groups get one more signal
        n_per_group = base*ones(1, K);
        n_per_group(1:extra) = base + 1;
        n_per_group = sort(n_per_group, 'descend');  % target in a largest group
    case 'concentrated'
        n_per_group = zeros(1, K);
        n_per_group(1) = M;
    otherwise
        error('claude_inband_leaks: pattern must be ''dispersed'' or ''concentrated''.');
end
n_inband = n_per_group(1) - 1;
end
```

## `work/claude_work1_wavelength_rule.m`

```matlab
%% claude_work1_wavelength_rule - Proposed switch: which wavelength does a connection use?
% Claude's solution of work1 (the task is in work1_wavelength_rule.m).
% Whole numbers only: no waveform, no noise, no BER.
%
% Result in one line: the channel of a connection from first-stage switch i to
% third-stage switch j is  ch = awg_channel(g(i), j, N),  g(i) = input group of i.
% It does not depend on the wavelength-routing (WR) switch. A leak in a third-stage
% switch is in band exactly when its source is in the target's input group.
%
% Sections
%   1. Parameters
%   2. The wavelength rule on a small example (checked by hand), and why the
%      design rule of the proposal is needed
%   3. Coupler condition: no aggregation coupler carries two equal wavelengths
%   4. Traffic patterns (exact definitions) and the number of in-band leaks
%   5. Signal-to-crosstalk ratio of the third-stage switch
%   6. Figure, files, answers to the questions of the task
clear; close all; rng(1);

%% 1. Parameters
N = 96;  % wavelength channels = first-stage switches = third-stage switches
K_list = [1 2 4 6 8 12 16];  % input groups (ULCF_dev_freq knows exactly these K)
M_list = [16 32 64 128];  % sizes M of the space switches (port count M*N)
sel_ex_ratio = 35;  % extinction ratio of one selector [dB] (JLT paper)
num_trials = 400;  % random full-load traffic matrices per (K, M) in section 4
% small example that can be checked by hand
Nx = 8; Kx = 4; Mx = 3;  % 8 channels, 4 groups of 2 switches, 3 WR switches

work_folder = fileparts(mfilename('fullpath'));
results_folder = fullfile(fileparts(work_folder), 'results');
if exist(results_folder, 'dir') ~= 7, mkdir(results_folder); end
time_stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
file_base = fullfile(results_folder, ['claude_work1_' time_stamp]);

%% 2. The wavelength rule on the small example
fprintf('=== 2. Wavelength rule, small example: N = %d, K = %d, M = %d ===\n', Nx, Kx, Mx);
fprintf('group of first-stage switch i: g(i) = floor((i-1)*K/N) + 1\n');
fprintf('  i    : '); fprintf('%3d', 1:Nx); fprintf('\n');
fprintf('  g(i) : '); fprintf('%3d', claude_group_of(1:Nx, Nx, Kx)); fprintf('\n');
fprintf('channel of the connection i -> j: ch = awg_channel(g(i), j, N) = mod(j + g(i) - 2, N) + 1\n');
fprintf('rows = first-stage switch i, columns = third-stage switch j\n');
fprintf('  i\\j '); fprintf('%4d', 1:Nx); fprintf('\n');
ch_example = zeros(Nx, Nx);
for i = 1:Nx
    ch_example(i, :) = claude_wavelength_of(i, 1:Nx, Nx, Kx);
    fprintf('  %2d  ', i); fprintf('%4d', ch_example(i, :)); fprintf('\n');
end
fprintf('Hand check: i = 5 is in group 3, so i = 5 -> j = 2 uses channel 2 + 3 - 1 = 4;\n');
fprintf('            i = 7 is in group 4, so i = 7 -> j = 8 uses channel 8 + 4 - 1 = 11 -> 3 (cyclic).\n');
assert(ch_example(5, 2) == 4 && ch_example(7, 8) == 3, 'hand check of the example failed');

% Brute force over every WR switch k: the channel that the connection i -> j
% needs when it passes WR switch k. Design rule: switch i enters input port g(i)
% of the AWG pair in EVERY WR switch, and output j of every WR switch goes to
% third-stage switch j. So the port does not depend on k.
ch_via_k = zeros(Nx, Nx, Mx);
for k = 1:Mx
    port_in = claude_group_of(1:Nx, Nx, Kx);  % the same for every k (design rule)
    for i = 1:Nx
        ch_via_k(i, :, k) = awg_channel(port_in(i), 1:Nx, Nx);
    end
end
assert(all(all(all(ch_via_k == ch_via_k(:, :, 1)))), ...
    'the channel depends on the WR switch: design rule violated');
fprintf('Check: the channel of every connection is the same through all %d WR switches.\n', Mx);
fprintf('       A rearrangement (move to another WR switch) never changes a wavelength.\n');

% Counter-example: a wiring that does NOT follow the design rule (the groups are
% rotated by one from WR switch to WR switch). Then the channel depends on k.
ch_bad = zeros(Nx, Nx, Mx);
for k = 1:Mx
    port_in = mod(claude_group_of(1:Nx, Nx, Kx) + k - 2, Kx) + 1;  % rotated groups
    for i = 1:Nx
        ch_bad(i, :, k) = awg_channel(port_in(i), 1:Nx, Nx);
    end
end
num_bad = nnz(ch_bad(:, :, 2) ~= ch_bad(:, :, 1));
fprintf('Counter-example (groups rotated per WR switch): %d of %d connections would need\n', ...
    num_bad, Nx*Nx);
fprintf('       another wavelength on WR switch 2 than on WR switch 1 -> laser retune on rearrangement.\n');

% K = 1 gives the conventional switch: ch = j
assert(isequal(claude_wavelength_of((1:N).', 1:N, N, 1), repmat(1:N, N, 1)), ...
    'K = 1 does not give ch = j');
fprintf('Check: K = 1 gives ch = j for every connection (conventional switch, page 22 Eq. (1)).\n');

%% 3. Coupler condition: no aggregation coupler carries two equal wavelengths
% In WR switch k, the connections form a partial matching: each first-stage
% switch i sends at most one signal into WR switch k (one fiber), and each
% third-stage switch j receives at most one signal from it (one fiber).
% Coupler (k, g) carries the signals of all i in group g. Their destinations j
% are all different, so awg_channel(g, j, N) are all different.
% Exhaustive on the small example, random full-load matchings on the real sizes.
fprintf('\n=== 3. Coupler condition ===\n');
ok = true;
for g = 1:Kx
    members = find(claude_group_of(1:Nx, Nx, Kx) == g);
    for j1 = 1:Nx
        for j2 = 1:Nx
            if j1 ~= j2
                c1 = claude_wavelength_of(members(1), j1, Nx, Kx);
                c2 = claude_wavelength_of(members(2), j2, Nx, Kx);
                ok = ok && (c1 ~= c2);
            end
        end
    end
end
assert(ok, 'two signals of one group with different destinations share a channel');
fprintf('Small example: any two signals of one group with different destinations differ in channel.\n');
for K = K_list
    for M = M_list
        for t = 1:20
            for k = 1:M
                dest = randperm(N);  % full load: first-stage i -> third-stage dest(i) via WR k
                ch = claude_wavelength_of((1:N).', dest.', N, K);
                g = claude_group_of((1:N).', N, K);
                for gg = 1:K
                    cg = ch(g == gg);  % channels on coupler (k, gg)
                    assert(numel(unique(cg)) == numel(cg), ...
                        'coupler carries two equal channels (K = %d, M = %d)', K, M);
                end
            end
        end
    end
end
fprintf('N = %d: 20 random full-load traffic matrices for every K and M: no coupler ever\n', N);
fprintf('       carries two signals of the same channel. (Two signals of the same channel can\n');
fprintf('       meet only at different input ports of the AWG pair: the ULCF AWG crosstalk.)\n');

%% 4. Traffic patterns and the number of in-band leaks
% Third-stage switch j receives M signals, one from each WR switch k. The signal
% on input k comes from the first-stage switch i_k that is connected to j
% through WR switch k. Its channel is awg_channel(g(i_k), j, N): all signals at
% switch j that come from the SAME group have the SAME channel, and signals from
% different groups differ by (g - g') channels (1 channel = 50 GHz at least).
%
% Exact definitions (the task asks for them):
%   dispersed    : the M sources of one third-stage switch are spread as evenly
%                  as possible over the K groups; the target belongs to a group
%                  of the largest size. In-band leaks = ceil(M/K) - 1.
%   concentrated : all M sources belong to the target's group (one rack group
%                  talks to one destination rack with all M ports).
%                  In-band leaks = M - 1, as in the conventional switch.
%   random       : (for comparison) every source is an independent uniform
%                  draw; in-band leaks ~ Binomial(M-1, 1/K), mean (M-1)/K.
fprintf('\n=== 4. In-band leaks in one third-stage switch (M inputs, full load) ===\n');
leaks_disp = zeros(numel(K_list), numel(M_list));
leaks_conc = zeros(numel(K_list), numel(M_list));
leaks_rand_mean = zeros(numel(K_list), numel(M_list));
leaks_rand_max = zeros(numel(K_list), numel(M_list));
for a = 1:numel(K_list)
    K = K_list(a);
    for b = 1:numel(M_list)
        M = M_list(b);
        leaks_disp(a, b) = claude_inband_leaks(M, K, 'dispersed');
        leaks_conc(a, b) = claude_inband_leaks(M, K, 'concentrated');
        % random full-load traffic: M permutations, one per WR switch
        cnt = zeros(num_trials*N, 1);
        n = 0;
        for t = 1:num_trials
            src_of_j = zeros(N, M);  % src_of_j(j, k) = first-stage switch feeding j via k
            for k = 1:M
                dest = randperm(N);
                src_of_j(dest, k) = (1:N).';
            end
            grp = claude_group_of(src_of_j, N, K);  % N x M groups
            % target = the signal on WR switch 1 (any choice; all are equivalent)
            same = sum(grp == grp(:, 1), 2) - 1;  % per third-stage switch j
            cnt(n+1:n+N) = same;
            n = n + N;
        end
        leaks_rand_mean(a, b) = mean(cnt);
        leaks_rand_max(a, b) = max(cnt);
    end
end
fprintf('dispersed (ceil(M/K) - 1), rows K, columns M = %s\n', mat2str(M_list));
for a = 1:numel(K_list), fprintf('  K = %2d :', K_list(a)); fprintf('%6d', leaks_disp(a, :)); fprintf('\n'); end
fprintf('concentrated (M - 1)\n');
for a = 1:numel(K_list), fprintf('  K = %2d :', K_list(a)); fprintf('%6d', leaks_conc(a, :)); fprintf('\n'); end
fprintf('random uniform traffic, mean over %d matrices (theory (M-1)/K)\n', num_trials);
for a = 1:numel(K_list), fprintf('  K = %2d :', K_list(a)); fprintf('%6.2f', leaks_rand_mean(a, :)); fprintf('\n'); end
fprintf('random uniform traffic, largest value seen\n');
for a = 1:numel(K_list), fprintf('  K = %2d :', K_list(a)); fprintf('%6d', leaks_rand_max(a, :)); fprintf('\n'); end
assert(all(leaks_disp(1, :) == M_list - 1) && all(leaks_conc(1, :) == M_list - 1), ...
    'K = 1 must give M - 1 leaks');
assert(all(all(leaks_conc == repmat(M_list - 1, numel(K_list), 1))), ...
    'concentrated traffic must give M - 1 leaks for every K');
fprintf('Check: K = 1 gives M - 1 leaks (step22 block [7]); concentrated traffic gives M - 1 for every K.\n');
assert(max(abs(leaks_rand_mean - (M_list - 1)./K_list.'), [], 'all') < 0.35, ...
    'random mean differs from (M-1)/K');

%% 5. Signal-to-crosstalk ratio of the third-stage switch (page 22 Eq. (2) with n leaks)
% A1 (selector + selector): SXR = 2*ER - 10*log10(n);  A2 (selector + coupler): ER - 10*log10(n)
sxr = @(n, att) att - 10*log10(max(n, eps));  % very large for n = 0
SXR_A1_disp = sxr(leaks_disp, 2*sel_ex_ratio); SXR_A2_disp = sxr(leaks_disp, sel_ex_ratio);
SXR_A1_conc = sxr(leaks_conc, 2*sel_ex_ratio); SXR_A2_conc = sxr(leaks_conc, sel_ex_ratio);
fprintf('\n=== 5. SXR of the third-stage switch [dB], ER = %d dB ===\n', sel_ex_ratio);
fprintf('Scheme A2 (couplers), dispersed; 16QAM needs about 14 dB in total\n');
for a = 1:numel(K_list), fprintf('  K = %2d :', K_list(a)); fprintf('%7.1f', SXR_A2_disp(a, :)); fprintf('\n'); end
fprintf('Scheme A2 (couplers), concentrated (= conventional)\n');
for a = 1:numel(K_list), fprintf('  K = %2d :', K_list(a)); fprintf('%7.1f', SXR_A2_conc(a, :)); fprintf('\n'); end
fprintf('Scheme A1 (selectors), dispersed\n');
for a = 1:numel(K_list), fprintf('  K = %2d :', K_list(a)); fprintf('%7.1f', SXR_A1_disp(a, :)); fprintf('\n'); end
% the ULCF AWG itself adds up to K-1 in-band leaks at AWG_XT = 32 dB (page 17 Eq. (6)),
% independent of the traffic pattern: keep it apart (work2 does).
AWG_XT = 32;
SXR_awg = sxr(max(K_list - 1, 0), AWG_XT);
fprintf('For comparison, ULCF AWG crosstalk SXR = AWG_XT - 10log10(K-1) [dB]:');
fprintf(' K=%d: %.1f;', [K_list; SXR_awg]); fprintf('\n');

%% 6. Figure, files, answers
fig = figure('Position', [100 100 760 460]);
if isprop(fig, 'Theme'), set(fig, 'Theme', 'light'); end
cols = lines(numel(M_list));
hold on;
for b = 1:numel(M_list)
    plot(K_list, leaks_disp(:, b), '-o', 'Color', cols(b, :), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('dispersed, M = %d', M_list(b)));
    plot(K_list, leaks_conc(:, b), '--', 'Color', cols(b, :), 'LineWidth', 1.2, ...
        'DisplayName', sprintf('concentrated, M = %d', M_list(b)));
end
set(gca, 'YScale', 'log'); grid on;
xlabel('Number of input groups K'); ylabel('In-band leaks in one third-stage switch');
title('Proposed switch: leaks on the wavelength of the target (full load)');
legend('Location', 'eastoutside'); xticks(K_list);
saveas(fig, [file_base '.png']);

fid = fopen([file_base '_inband_leaks.csv'], 'w');
fprintf(fid, 'K,pattern'); fprintf(fid, ',M%d', M_list); fprintf(fid, '\n');
for a = 1:numel(K_list)
    fprintf(fid, '%d,dispersed', K_list(a)); fprintf(fid, ',%d', leaks_disp(a, :)); fprintf(fid, '\n');
    fprintf(fid, '%d,concentrated', K_list(a)); fprintf(fid, ',%d', leaks_conc(a, :)); fprintf(fid, '\n');
    fprintf(fid, '%d,random_mean', K_list(a)); fprintf(fid, ',%.2f', leaks_rand_mean(a, :)); fprintf(fid, '\n');
end
fclose(fid);
fid = fopen([file_base '_example_rule.csv'], 'w');
fprintf(fid, 'i_group'); fprintf(fid, ',j%d', 1:Nx); fprintf(fid, '\n');
for i = 1:Nx
    fprintf(fid, '%d_g%d', i, claude_group_of(i, Nx, Kx)); fprintf(fid, ',%d', ch_example(i, :)); fprintf(fid, '\n');
end
fclose(fid);
save([file_base '.mat'], 'N', 'K_list', 'M_list', 'sel_ex_ratio', 'num_trials', 'Nx', 'Kx', 'Mx', ...
    'ch_example', 'leaks_disp', 'leaks_conc', 'leaks_rand_mean', 'leaks_rand_max', ...
    'SXR_A1_disp', 'SXR_A2_disp', 'SXR_A1_conc', 'SXR_A2_conc', 'SXR_awg', 'time_stamp');

fprintf('\n=== Answers to the questions of the task ===\n');
fprintf('- What changes the wavelength: the first-stage switch (through its group) and the\n');
fprintf('  third-stage switch. The WR switch does not.\n');
fprintf('- Division into groups: any division into K groups of N/K switches works. The rule\n');
fprintf('  and the leak counts only use the group index, so the division does not matter for\n');
fprintf('  the counts; it decides which racks share a wavelength at a given destination.\n');
fprintf('- Likely traffic in a datacenter: dispersed (a rack talks to many racks). Worst case:\n');
fprintf('  concentrated, which gives the conventional count M - 1 again.\n');
fprintf('- A leak on another wavelength is (g2 - g1) channels away: at least 1 channel = 50 GHz.\n');
fprintf('  At 32 GBd the receive band ends at 16 GHz, so the nearest leak is 34 GHz outside it.\n');
fprintf('- First-stage leaks: the M inputs of first-stage switch i are all in group g(i); their\n');
fprintf('  wavelengths differ when their destinations differ, exactly as in the conventional\n');
fprintf('  switch. step22 takes the worst case (all in band) and so does work2: no change.\n');
fprintf('- Receiver: output j can receive K different wavelengths, one per group. A NEW\n');
fprintf('  connection from another group needs the local oscillator of the receiver retuned\n');
fprintf('  (frequency selection, > 100 us). A REARRANGEMENT never does: only selectors switch.\n');
fprintf('\nSaved: %s.{png,mat,_inband_leaks.csv,_example_rule.csv}\n', file_base);
```

## `work/claude_params_proposed.m`

```matlab
function p = claude_params_proposed()
%CLAUDE_PARAMS_PROPOSED  Default parameters of the proposed three-stage switch.
%
%   p = claude_params_proposed()
%
%   Returns a struct with the COMMON parameter set of this project (work3): the
%   values of step22_three_stage_one_point (JLT 2025, 200-Gbps DP-16QAM at 32 GBd
%   on the 50-GHz grid), plus the fields that only the proposed switch has.
%   Change fields after the call, e.g. p.K = 12; p.PTx = 0.
%
%   Fields that the proposed switch adds to step22
%     K          : number of input groups = input ports of the ULCF AWG pair
%                  (1, 2, 4, 6, 8, 12 or 16: the values that ULCF_dev_freq knows)
%     pattern    : 'dispersed' or 'concentrated' (claude_inband_leaks)
%     awg_type   : 'auto' = conventional AWG of step22 for K = 1, ULCF pair for K > 1
%                  'conv' or 'ulcf' force one type (e.g. ULCF with K = 1)
%     oob_flag   : 0 = leaks on other wavelengths are left out (ideal receive filter)
%                  1 = the leaks of the two neighbouring groups are added at +-50 GHz
%                      with freqoff (needs up >= 5 at 32 GBd)
%     AWG_loss_conv, FWHM_conv   : step22 AWG (6 dB, 50 GHz)
%     AWG_loss_ulcf, FWHM_ulcf   : ULCF AWG (9 dB, 66.6 GHz), plus splitter_loss
%     AWG_XT     : crosstalk of the ULCF AWG, one leak per other input port [dB]
%     flg_NWDM   : 0 on the 50-GHz grid (carrier on the passband centre + deviation)
%
%   Written by Claude for work2.
p = struct();
% --- operating point ---
p.datasize = 3e4;  % symbols
p.PTx = 4;  % transmitter power, both polarizations [dBm]
p.sw_size = 64;  % M
p.stage3_coupler_flag = 1;  % 0 = A1 (selectors), 1 = A2 (couplers)
p.K = 12;  % input groups
p.pattern = 'dispersed';
p.awg_type = 'auto';
p.oob_flag = 0;
% --- common set (= step22) ---
p.mod_flag = 4;
p.up = 2;
p.baudrate = 32e9;
p.pol_flag = 1;
p.fiber_flag = 0;
p.Fan_in_loss = 1.5;
p.Fan_out_loss = 1.5;
p.N = 96;
p.signal_interval = 50e9;
p.NF = 6;
p.edfa_sat1 = 20;
p.edfa_sat2 = 10;
p.NF2 = 4;
p.rolloff = 0;
p.sel_ex_ratio = 35;
p.xt_wave_max = Inf;
p.Morder = 16;
p.seed = 1;
p.BER_limit = 1e-2;
% --- AWG of each type ---
p.AWG_loss_conv = 6;
p.FWHM_conv = 50e9;
p.AWG_loss_ulcf = 9;
p.splitter_loss = coupler_loss(2);  % 3.5 dB
p.FWHM_ulcf = 66.6e9;
p.AWG_XT = 32;
p.flg_NWDM = 0;
end
```

## `work/claude_chain_proposed.m`

```matlab
function r = claude_chain_proposed(p)
%CLAUDE_CHAIN_PROPOSED  One operating point of the proposed three-stage switch.
%
%   r = claude_chain_proposed(p)      p = claude_params_proposed() with changes
%
%   The chain of step22_three_stage_one_point with a new middle stage:
%     [1] transmitter -> [2] fan-in/out -> [3] stage-1 switch (selector + selector)
%     -> [4] aggregation coupler, (N/K) x 1          (step22: N x 1)
%     -> [5] EDFA shared by N/K wavelengths           (step22: N)
%     -> [6] AWG: step22 AWG for K = 1, else 1 x 2 splitter + ULCF AWG pair
%     -> [7] in-band crosstalk of the ULCF AWG, K-1 leaks   (new, from step21)
%     -> [8] stage-3 switch: only the leaks of the target's input group are in
%            band (work1); the others are on other wavelengths and are either
%            left out (oob_flag = 0) or added at +-50 GHz (oob_flag = 1)
%     -> [9] fan-in/out -> [10] pre-amplifier -> [11] coherent receiver, BER
%   With K = 1, awg_type 'auto', oob_flag 0 and the step22 parameters, the random
%   numbers are drawn in exactly the order of step22: the result is bit for bit
%   the result of step22_three_stage_one_point (claude_test_proposed checks it).
%
%   Output r (struct): BER, SNR_sim, stage_power (1 x 10), sigpw_awg, sigpw,
%   ase1_sim, ase2_sim, rx_sym, tx_sym, the losses and counts that the budget
%   needs (sw1_loss, sw1_xt_att, num_xt1, agg_coupler_loss, N_agg, AWG_loss_tot,
%   FWHM, shift, num_xt_awg, sw3_loss, sw3_xt_att, num_xt3, num_oob, awg_type),
%   Hrcos, Hband, Fs, Mary, pin, fiber_loss, training_num.
%
%   Written by Claude for work2.

% ---- values that follow from the parameters ----
Mary = 2^p.mod_flag;
Fs = p.up*p.baudrate;
L = p.datasize*p.up;
Hrcos = rcosfilter(L, p.baudrate, Fs, p.rolloff);
assert(p.xt_wave_max >= 1, 'xt_wave_max must be 1 or more');
assert(mod(p.N, p.K) == 0, 'K must divide N');
awg_type = lower(p.awg_type);
if strcmp(awg_type, 'auto')
    if p.K == 1, awg_type = 'conv'; else, awg_type = 'ulcf'; end
end
M = p.sw_size;

rng(p.seed);
stage_power = zeros(1, 10);

% [1] Transmitter of the target signal
pin = p.PTx - 3*p.pol_flag;
[signal, data, data_mod] = TL_QAM(p.datasize, p.up, Hrcos, pin, p.mod_flag);
stage_power(1) = calc_signal_power(signal);

% [2] Fan-in and fan-out of the multicore fiber
fiber_loss = 0;
if p.fiber_flag == 1
    fiber_loss = p.Fan_in_loss + p.Fan_out_loss;
end
signal = attenuation(signal, fiber_loss);
stage_power(2) = calc_signal_power(signal);

% [3] Stage-1 space switch, selector + selector. Worst case as in step22: all
% M-1 other inputs are on the wavelength of the target (work1: the new rule
% does not change the first stage; the worst case is kept).
sw1_loss = 2*selector_loss(M);
sw1_xt_att = 2*p.sel_ex_ratio;
num_xt1 = M - 1;
num_xt1_wave = min(num_xt1, floor(p.xt_wave_max));
xt1_boost = 10*log10(num_xt1/num_xt1_wave);
xt_power = pin - fiber_loss + xt1_boost;
crosstalk = zeros(L, 1);
for k = 1:num_xt1_wave
    [xt, ~, ~] = TL_QAM(p.datasize, p.up, Hrcos, xt_power, p.mod_flag);
    crosstalk = crosstalk + xt;
end
signal = signal + attenuation(crosstalk, sw1_xt_att);
signal = attenuation(signal, sw1_loss);
stage_power(3) = calc_signal_power(signal);

% [4] Aggregation coupler of the target's input group: (N/K) x 1
N_agg = p.N/p.K;
agg_coupler_loss = coupler_loss(N_agg);
signal = attenuation(signal, agg_coupler_loss);
stage_power(4) = calc_signal_power(signal);

% [5] EDFA of the input group: its output power is shared by N/K wavelengths
sat1 = p.edfa_sat1 - 3*p.pol_flag;
edfaGain = sat1 - 10*log10(N_agg) - calc_signal_power(signal);
[signal, aseNoise] = amplified_by_EDFA3(signal, Fs, edfaGain, p.NF, sat1, N_agg, ...
    p.signal_interval);
stage_power(5) = calc_signal_power(signal);

% [6] AWG
if strcmp(awg_type, 'conv')
    AWG_loss_tot = p.AWG_loss_conv;
    FWHM = p.FWHM_conv;
    shift = 0;
    num_xt_awg = 0;
else
    AWG_loss_tot = p.AWG_loss_ulcf + p.splitter_loss;  % 1 x 2 splitter + ULCF AWG
    FWHM = p.FWHM_ulcf;
    shift = ULCF_dev_freq(p.K) + 12.5e9*(p.flg_NWDM ~= 0);  % worst input port
    num_xt_awg = p.K - 1;
end
signal = awg(signal, AWG_loss_tot, shift, Fs, FWHM, p.AWG_XT, 1);
stage_power(6) = calc_signal_power(signal);

% [7] In-band crosstalk of the ULCF AWG: the other K-1 input ports can carry the
% wavelength of the target (always the worst case, as in step21 block [7])
Hband = nyquistfilter(L, 0, Fs, p.baudrate*(1 + p.rolloff));
sigpw_awg = calc_signal_power(apply_filter(signal, Hband, 1));
if num_xt_awg > 0
    AWG_crosstalk = zeros(L, num_xt_awg);
    for k = 1:num_xt_awg
        [AWG_crosstalk(:, k), ~, ~] = TL_QAM(p.datasize, p.up, Hrcos, sigpw_awg, p.mod_flag);
    end
    signal = signal + sum(attenuation(AWG_crosstalk, p.AWG_XT), 2);
end
stage_power(7) = calc_signal_power(signal);

% [8] Stage-3 space switch. The M-1 other inputs come from the other WR switches
% with the power sigpw. Only those from the target's input group have the
% target's wavelength (work1): num_xt3 of them, from the traffic pattern.
if p.stage3_coupler_flag == 1
    sw3_loss = selector_loss(M) + coupler_loss(M);
    sw3_xt_att = p.sel_ex_ratio;
else
    sw3_loss = 2*selector_loss(M);
    sw3_xt_att = 2*p.sel_ex_ratio;
end
[num_xt3, n_per_group] = claude_inband_leaks(M, p.K, p.pattern);
sigpw = calc_signal_power(apply_filter(signal, Hband, 1));
crosstalk = zeros(L, 1);
if num_xt3 > 0
    num_xt3_wave = min(num_xt3, floor(p.xt_wave_max));
    xt3_boost = 10*log10(num_xt3/num_xt3_wave);
    xt_power = sigpw + xt3_boost;
    for k = 1:num_xt3_wave
        [xt, ~, ~] = TL_QAM(p.datasize, p.up, Hrcos, xt_power, p.mod_flag);
        crosstalk = crosstalk + xt;
    end
end
% leaks on other wavelengths: the two groups next to the target's group (the
% largest other groups, one channel = signal_interval away on each side)
num_oob = 0;
if p.oob_flag == 1 && p.K > 1
    n_side = [0 0];
    if p.K >= 2, n_side(1) = n_per_group(2); end
    if p.K >= 3, n_side(2) = n_per_group(3); end
    foff = [p.signal_interval, -p.signal_interval];
    need = p.signal_interval + p.baudrate*(1 + p.rolloff)/2;
    if Fs/2 < need
        error(['claude_chain_proposed: oob_flag = 1 needs Fs/2 >= %.0f GHz; ' ...
            'raise up to at least %d'], need/1e9, ceil(2*need/p.baudrate));
    end
    for s = 1:2
        if n_side(s) > 0
            n_wave = min(n_side(s), floor(p.xt_wave_max));
            boost = 10*log10(n_side(s)/n_wave);
            for k = 1:n_wave
                [xt, ~, ~] = TL_QAM(p.datasize, p.up, Hrcos, sigpw + boost, p.mod_flag);
                crosstalk = crosstalk + freqoff(xt, foff(s), Fs);
            end
            num_oob = num_oob + n_side(s);
        end
    end
end
signal = signal + attenuation(crosstalk, sw3_xt_att);
signal = attenuation(signal, sw3_loss);
stage_power(8) = calc_signal_power(signal);

% [9] Fan-in and fan-out again
signal = attenuation(signal, fiber_loss);
stage_power(9) = calc_signal_power(signal);

% [10] Pre-amplifier of the receiver
sat2 = p.edfa_sat2 - 3*p.pol_flag;
edfaGain = sat2 - calc_signal_power(signal);
[signal, aseNoise2] = amplified_by_EDFA3(signal, Fs, edfaGain, p.NF2, sat2, 1, ...
    p.signal_interval);
stage_power(10) = calc_signal_power(signal);

% [11] Coherent receiver and BER
H = nyquistfilter(length(signal), 0, Fs, p.baudrate*(1 + p.rolloff));
signal = apply_filter(signal, H, 1);
training_num = floor(p.datasize/3);
signal = adequalizet(signal, Mary, p.Morder, 1/256, data_mod(1:training_num), p.up);
BER = measure_BER_QAM(signal(training_num+1:end), ...
    data(p.mod_flag*training_num+1:end), p.mod_flag);

% SNR of the equalized symbols (as step22 section 4)
rx_sym = signal(training_num+1:end);
tx_sym = data_mod(training_num+1:end);
g = sum(conj(tx_sym).*rx_sym)/sum(abs(tx_sym).^2);
err_sym = rx_sym - g*tx_sym;
SNR_sim = 10*log10(abs(g)^2*mean(abs(tx_sym).^2)/mean(abs(err_sym).^2));

% ---- output ----
r = struct('BER', BER, 'SNR_sim', SNR_sim, 'stage_power', stage_power, ...
    'sigpw_awg', sigpw_awg, 'sigpw', sigpw, ...
    'ase1_sim', calc_signal_power(aseNoise), 'ase2_sim', calc_signal_power(aseNoise2), ...
    'rx_sym', rx_sym, 'tx_sym', tx_sym, 'pin', pin, 'fiber_loss', fiber_loss, ...
    'sw1_loss', sw1_loss, 'sw1_xt_att', sw1_xt_att, 'num_xt1', num_xt1, ...
    'agg_coupler_loss', agg_coupler_loss, 'N_agg', N_agg, 'sat1', sat1, 'sat2', sat2, ...
    'AWG_loss_tot', AWG_loss_tot, 'FWHM', FWHM, 'shift', shift, 'num_xt_awg', num_xt_awg, ...
    'sw3_loss', sw3_loss, 'sw3_xt_att', sw3_xt_att, 'num_xt3', num_xt3, 'num_oob', num_oob, ...
    'awg_type', awg_type, 'Hrcos', Hrcos, 'Hband', Hband, 'Fs', Fs, 'Mary', Mary, ...
    'training_num', training_num, 'num_bits', p.mod_flag*(p.datasize - training_num));
end
```

## `work/claude_budget_proposed.m`

```matlab
function b = claude_budget_proposed(p, r)
%CLAUDE_BUDGET_PROPOSED  Closed-form power and SNR budget of the proposed switch.
%
%   b = claude_budget_proposed(p, r)    p = parameters, r = claude_chain_proposed(p)
%
%   The formulas of step22 (sections 5 and 6) with the middle stage of step21:
%   coupler and EDFA of N/K channels, AWG passband off-centre by the deviation of
%   the worst ULCF input port, K-1 AWG leaks at AWG_XT, and num_xt3 in-band leaks
%   in the third-stage switch instead of M-1. No random numbers.
%
%   Output b (struct): budget_target(1:10), budget_total(1:10), budget_ase1,
%   budget_ase2, budget_sigpw_awg, budget_sigpw, nsr_* terms, SNR_budget, BER_gauss,
%   eq_penalty, T_sig, T_ase, T_inband.
%
%   Written by Claude for work2.
h_planck = 6.62607004e-34;
f_opt = 299792458/1550e-9;
Fs = r.Fs;
L = p.datasize*p.up;
budget_target = zeros(1, 10);
budget_total = zeros(1, 10);

% [1] to [4]
xt_sw1 = r.num_xt1*10^(-r.sw1_xt_att/10);
budget_target(1) = r.pin;
budget_total(1) = r.pin;
budget_target(2) = budget_target(1) - r.fiber_loss;
budget_total(2) = budget_target(2);
budget_target(3) = budget_target(2) - r.sw1_loss;
budget_total(3) = budget_target(3) + 10*log10(1 + xt_sw1);
budget_target(4) = budget_target(3) - r.agg_coupler_loss;
budget_total(4) = budget_total(3) - r.agg_coupler_loss;

% [5] EDFA shared by N/K channels
limit1 = r.sat1 - 10*log10(r.N_agg);
G1 = 10^((limit1 - budget_total(4))/10);
F1 = 10^(p.NF/10);
ase1_mW = (G1*F1 - 1)*h_planck*f_opt*Fs/2*1e3;
ase1_ref_mW = ase1_mW*p.signal_interval/Fs;
scale1 = 10^(limit1/10)/(10^(limit1/10) + ase1_ref_mW);
budget_target(5) = budget_target(4) + 10*log10(G1*scale1);
budget_total(5) = 10*log10((10^(limit1/10) + ase1_mW)*scale1);
budget_ase1 = 10*log10(ase1_mW*scale1);

% [6] AWG: flat loss and passband shape (centre "shift" away from the carrier)
Hawg = gaussfilter(L, r.shift, Fs, r.FWHM, p.AWG_XT, 1);
w_sig = r.Hrcos.^2/sum(r.Hrcos.^2);
T_sig = sum(w_sig.*Hawg.^2);
T_ase = mean(Hawg.^2);
T_inband = mean(r.Hband.^2.*Hawg.^2);
budget_target(6) = budget_target(5) - r.AWG_loss_tot + 10*log10(T_sig);
sig6_mW = 10^(budget_target(6)/10)*(1 + xt_sw1);
ase6_mW = ase1_mW*scale1*10^(-r.AWG_loss_tot/10);
budget_total(6) = 10*log10(sig6_mW + ase6_mW*T_ase);

% [7] AWG crosstalk: K-1 leaks, each AWG_XT below the in-band power after the AWG
budget_sigpw_awg = 10*log10(sig6_mW + ase6_mW*T_inband);
xt_awg_mW = r.num_xt_awg*10^((budget_sigpw_awg - p.AWG_XT)/10);
budget_target(7) = budget_target(6);
budget_total(7) = 10*log10(10^(budget_total(6)/10) + xt_awg_mW);

% [8] Stage-3 switch: num_xt3 in-band leaks (+ num_oob out-of-band leaks that
% only add power, not noise in the signal band), each sw3_xt_att below sigpw
budget_sigpw = 10*log10(sig6_mW + ase6_mW*T_inband + xt_awg_mW);
xt_sw3_mW = r.num_xt3*10^((budget_sigpw - r.sw3_xt_att)/10);
oob_mW = r.num_oob*10^((budget_sigpw - r.sw3_xt_att)/10);
budget_target(8) = budget_target(7) - r.sw3_loss;
budget_total(8) = 10*log10(10^(budget_total(7)/10) + xt_sw3_mW + oob_mW) - r.sw3_loss;

% [9] fan-in/out
budget_target(9) = budget_target(8) - r.fiber_loss;
budget_total(9) = budget_total(8) - r.fiber_loss;

% [10] pre-amplifier
limit2 = r.sat2;
G2 = 10^((limit2 - budget_total(9))/10);
F2 = 10^(p.NF2/10);
ase2_mW = (G2*F2 - 1)*h_planck*f_opt*Fs/2*1e3;
ase2_ref_mW = ase2_mW*p.signal_interval/Fs;
scale2 = 10^(limit2/10)/(10^(limit2/10) + ase2_ref_mW);
budget_target(10) = budget_target(9) + 10*log10(G2*scale2);
budget_total(10) = 10*log10((10^(limit2/10) + ase2_mW)*scale2);
budget_ase2 = 10*log10(ase2_mW*scale2);

% SNR budget (step22 section 6 + the AWG crosstalk term of step21)
eq_penalty = T_sig*sum(w_sig./Hawg.^2);
nsr_ase1 = (ase1_mW*p.baudrate/Fs)/(G1*10^(budget_target(4)/10));
nsr_xt_sw1 = xt_sw1;
nsr_xt_awg = xt_awg_mW/10^(budget_target(7)/10)*eq_penalty;
nsr_xt_sw3 = xt_sw3_mW/10^(budget_target(7)/10)*eq_penalty;
nsr_ase2 = (ase2_mW*p.baudrate/Fs)/(G2*10^(budget_target(9)/10))*eq_penalty;
SNR_budget = -10*log10(nsr_ase1 + nsr_xt_sw1 + nsr_xt_awg + nsr_xt_sw3 + nsr_ase2);
BER_gauss = NaN;
if p.mod_flag ~= 5
    BER_gauss = 2/p.mod_flag*(1 - 1/sqrt(r.Mary)) ...
        *erfc(sqrt(3*10^(SNR_budget/10)/(2*(r.Mary - 1))));
end

b = struct('budget_target', budget_target, 'budget_total', budget_total, ...
    'budget_ase1', budget_ase1, 'budget_ase2', budget_ase2, ...
    'budget_sigpw_awg', budget_sigpw_awg, 'budget_sigpw', budget_sigpw, ...
    'nsr_ase1', nsr_ase1, 'nsr_xt_sw1', nsr_xt_sw1, 'nsr_xt_awg', nsr_xt_awg, ...
    'nsr_xt_sw3', nsr_xt_sw3, 'nsr_ase2', nsr_ase2, 'SNR_budget', SNR_budget, ...
    'BER_gauss', BER_gauss, 'eq_penalty', eq_penalty, 'T_sig', T_sig, 'T_ase', T_ase, ...
    'T_inband', T_inband, 'P_edfa_in', budget_target(4));
end
```

## `work/claude_test_proposed.m`

```matlab
function claude_test_proposed()
%CLAUDE_TEST_PROPOSED  Consistency tests of the proposed-switch chain and budget.
%
%   1. K = 1 (step22 AWG, step22 parameters) reproduces step22_three_stage_one_point
%      bit for bit: same BER, same power after every block, same SNR.
%   2. The pattern does not matter for K = 1.
%   3. Budget self-checks (0.1 dB power, 0.7 dB SNR) at several points:
%      K = 12 dispersed/concentrated, A1/A2, ULCF with K = 1, oob_flag = 1 with up = 5.
%   4. oob_flag = 1 (leaks of the neighbouring groups at +-50 GHz, up = 5) gives
%      the same BER as oob_flag = 0 with up = 5 within the statistical error: the
%      simulated receiver rejects them (not an assumption).
%   Written by Claude for work2. Run after setup_path.

fprintf('=== claude_test_proposed ===\n');
% --- 1. step22 reference, run in the base workspace ---
evalin('base', 'step22_three_stage_one_point');
BER22 = evalin('base', 'BER');
sp22 = evalin('base', 'stage_power');
SNR22 = evalin('base', 'SNR_sim');
close all;
p = claude_params_proposed();
p.K = 1;  p.xt_wave_max = Inf;  p.oob_flag = 0;
r = claude_chain_proposed(p);
% block numbers: step22 [1..9] = proposed [1 2 3 4 5 6 8 9 10] (no AWG crosstalk block)
map = [1 2 3 4 5 6 8 9 10];
assert(r.BER == BER22, 'K = 1: BER differs from step22 (%.4e vs %.4e)', r.BER, BER22);
assert(max(abs(r.stage_power(map) - sp22)) < 1e-9, 'K = 1: stage powers differ from step22');
assert(abs(r.SNR_sim - SNR22) < 1e-9, 'K = 1: SNR differs from step22');
fprintf('Test 1 passed: K = 1 reproduces step22 (BER %.3e, SNR %.2f dB), bit for bit.\n', ...
    r.BER, r.SNR_sim);

% --- 2. pattern does not matter for K = 1 ---
p.pattern = 'concentrated';
r2 = claude_chain_proposed(p);
assert(r2.BER == r.BER, 'K = 1: the pattern changed the result');
fprintf('Test 2 passed: for K = 1 both traffic patterns give the same result.\n');

% --- 3. budget self-checks at several points ---
cases = {
    struct('K', 12, 'pattern', 'dispersed',    'stage3_coupler_flag', 1, 'PTx', 4,  'up', 2, 'oob_flag', 0, 'awg_type', 'auto')
    struct('K', 12, 'pattern', 'concentrated', 'stage3_coupler_flag', 1, 'PTx', 4,  'up', 2, 'oob_flag', 0, 'awg_type', 'auto')
    struct('K', 12, 'pattern', 'dispersed',    'stage3_coupler_flag', 0, 'PTx', -4, 'up', 2, 'oob_flag', 0, 'awg_type', 'auto')
    struct('K', 4,  'pattern', 'dispersed',    'stage3_coupler_flag', 1, 'PTx', 2,  'up', 2, 'oob_flag', 0, 'awg_type', 'auto')
    struct('K', 1,  'pattern', 'dispersed',    'stage3_coupler_flag', 1, 'PTx', 4,  'up', 2, 'oob_flag', 0, 'awg_type', 'ulcf')
    struct('K', 12, 'pattern', 'dispersed',    'stage3_coupler_flag', 1, 'PTx', 4,  'up', 5, 'oob_flag', 1, 'awg_type', 'auto')
    };
for c = 1:numel(cases)
    p = claude_params_proposed();
    f = fieldnames(cases{c});
    for k = 1:numel(f), p.(f{k}) = cases{c}.(f{k}); end
    r = claude_chain_proposed(p);
    b = claude_budget_proposed(p, r);
    dP = max(abs(r.stage_power - b.budget_total));
    dS = r.SNR_sim - b.SNR_budget;
    assert(dP < 0.1, 'case %d: power differs from the budget by %.3f dB', c, dP);
    assert(abs(r.ase1_sim - b.budget_ase1) < 0.1 && abs(r.ase2_sim - b.budget_ase2) < 0.1, ...
        'case %d: ASE power differs from the budget', c);
    assert(abs(r.sigpw - b.budget_sigpw) < 0.1, 'case %d: sigpw differs from the budget', c);
    assert(abs(dS) < 0.7, 'case %d: SNR differs from the budget by %.2f dB', c, dS);
    fprintf(['Test 3.%d passed: K = %2d %-12s A%d PTx = %+3.0f up = %d oob = %d awg = %s: ' ...
        'BER %.3e, SNR sim %.2f / budget %.2f dB, power diff %.3f dB\n'], c, p.K, p.pattern, ...
        p.stage3_coupler_flag + 1, p.PTx, p.up, p.oob_flag, r.awg_type, r.BER, r.SNR_sim, ...
        b.SNR_budget, dP);
end

% --- 4. out-of-band leaks are rejected by the simulated receiver ---
% near the FEC limit (BER about 1e-2), where a change of the BER can be seen
p = claude_params_proposed();
p.K = 12; p.up = 5; p.PTx = -7; p.stage3_coupler_flag = 1;
p.oob_flag = 0; r0 = claude_chain_proposed(p);
p.oob_flag = 1; r1 = claude_chain_proposed(p);
fprintf('Test 4: up = 5, K = 12, A2, PTx = %g dBm: without / with %d leaks at +-50 GHz:\n', ...
    p.PTx, r1.num_oob);
fprintf('        BER %.3e / %.3e, SNR %.2f / %.2f dB\n', r0.BER, r1.BER, r0.SNR_sim, r1.SNR_sim);
fprintf('        (different random numbers after block [8]; the difference must be within the\n');
fprintf('         statistical error, about 4 percent of the BER near 1e-2)\n');
assert(abs(r1.SNR_sim - r0.SNR_sim) < 0.2, 'the out-of-band leaks changed the SNR by %.2f dB', ...
    r1.SNR_sim - r0.SNR_sim);
assert(abs(r1.BER - r0.BER)/max(r0.BER, 1e-3) < 0.15, ...
    'the out-of-band leaks changed the BER by more than 15 percent');
% the same leaks ON the wavelength of the target (as if concentrated) must hurt
p.oob_flag = 0; p.pattern = 'concentrated'; r3 = claude_chain_proposed(p);
fprintf('        for comparison, the same number of leaks IN band (concentrated): BER %.3e, SNR %.2f dB\n', ...
    r3.BER, r3.SNR_sim);
assert(r3.SNR_sim < r0.SNR_sim - 1, 'in-band leaks should lower the SNR clearly');
fprintf('Test 4 passed: leaks on other wavelengths do not change the BER; in-band leaks do.\n');
fprintf('All claude_test_proposed tests passed.\n');
end
```

## `work/claude_step23_proposed_one_point.m`

```matlab
%% claude_step23_proposed_one_point - Proposed three-stage switch, ONE operating point
% Claude's solution of work2, part 1 (the task is in work2_three_stage_proposed.m).
% Same role as step22_three_stage_one_point for the conventional switch: one
% transmitter power, one size M, one third-stage type, one K, one traffic pattern.
% The chain is the function claude_chain_proposed; the closed-form budget is
% claude_budget_proposed; the sweep is claude_main_three_stage_proposed.
%
% What is different from step22 (blocks of claude_chain_proposed)
%   [4] coupler of N/K wavelengths, [5] EDFA shared by N/K wavelengths,
%   [6] 1 x 2 splitter + ULCF AWG pair (K > 1), [7] K-1 ULCF AWG leaks (in band),
%   [8] third-stage switch with only the in-band leaks of the traffic pattern.
clear; close all; rng(1);

%% 1. Parameters (common set of work3 = step22; see claude_params_proposed)
p = claude_params_proposed();
p.PTx = 4;  % transmitter power, both polarizations [dBm]
p.sw_size = 64;  % M (64*96 = 6144 ports)
p.stage3_coupler_flag = 1;  % 0 = A1 (selectors), 1 = A2 (couplers)
p.K = 12;  % input groups = input ports of the ULCF AWG pair
p.pattern = 'dispersed';  % 'dispersed' or 'concentrated'
p.awg_type = 'auto';  % K = 1: AWG of step22; K > 1: ULCF pair
p.oob_flag = 0;  % 1 = add the leaks of the neighbouring groups at +-50 GHz (needs up >= 5)
p.up = 2;
p.xt_wave_max = Inf;
p.seed = 1;

work_folder = fileparts(mfilename('fullpath'));
results_folder = fullfile(fileparts(work_folder), 'results');
if exist(results_folder, 'dir') ~= 7, mkdir(results_folder); end

%% 2. Chain and budget
r = claude_chain_proposed(p);
b = claude_budget_proposed(p, r);

%% 3. Tables
fprintf('Operating point : PTx = %.1f dBm, space switches %d x %d, Scheme A%d, K = %d, %s traffic\n', ...
    p.PTx, p.sw_size, p.sw_size, p.stage3_coupler_flag + 1, p.K, p.pattern);
fprintf('Middle stage    : %s AWG, coupler %d x 1 (%.1f dB), EDFA shares %d channels, AWG %.1f dB, passband centre %.1f GHz off\n', ...
    r.awg_type, r.N_agg, r.agg_coupler_loss, r.N_agg, r.AWG_loss_tot, r.shift/1e9);
fprintf('Leaks           : stage 1: %d in band; ULCF AWG: %d; stage 3: %d in band, %d out of band simulated\n', ...
    r.num_xt1, r.num_xt_awg, r.num_xt3, r.num_oob);
fprintf('Switch size     : %d x %d ports (M*N = %d*%d)\n', p.sw_size*p.N, p.sw_size*p.N, p.sw_size, p.N);
fprintf('BER             : %.3e (%d errors in %d bits), FEC limit %.0e\n', r.BER, ...
    round(r.BER*r.num_bits), r.num_bits, p.BER_limit);

stage_names = {'Tx', 'Fan-in/out', 'Switch 1', 'Coupler', 'EDFA', 'AWG', 'AWG crosstalk', ...
    'Switch 3', 'Fan-in/out', 'Pre-amp'};
fprintf('\nPower after every block [dBm] (one polarization, inside the band Fs)\n');
fprintf('  %-18s %11s %11s %11s\n', 'block', 'simulation', 'budget', 'budget');
fprintf('  %-18s %11s %11s %11s\n', '', '(total)', '(total)', '(target)');
for k = 1:10
    fprintf('  [%2d] %-13s %11.3f %11.3f %11.3f\n', k, stage_names{k}, ...
        r.stage_power(k), b.budget_total(k), b.budget_target(k));
end
fprintf('  %-18s %11.3f %11.3f\n', 'ASE of EDFA', r.ase1_sim, b.budget_ase1);
fprintf('  %-18s %11.3f %11.3f\n', 'ASE of pre-amp', r.ase2_sim, b.budget_ase2);
fprintf('  %-18s %11.3f %11.3f\n', 'sigpw (block [8])', r.sigpw, b.budget_sigpw);

fprintf('\nSNR contributions in the signal bandwidth [dB]\n');
fprintf('  ASE of the EDFA                 %7.2f\n', -10*log10(b.nsr_ase1));
fprintf('  crosstalk of the stage-1 switch %7.2f\n', -10*log10(b.nsr_xt_sw1));
fprintf('  crosstalk of the ULCF AWG       %7.2f\n', -10*log10(max(b.nsr_xt_awg, 1e-30)));
fprintf('  crosstalk of the stage-3 switch %7.2f\n', -10*log10(max(b.nsr_xt_sw3, 1e-30)));
fprintf('  ASE of the pre-amplifier        %7.2f\n', -10*log10(b.nsr_ase2));
fprintf('  all together (budget)           %7.2f\n', b.SNR_budget);
fprintf('  simulation                      %7.2f\n', r.SNR_sim);
fprintf('  (noise gain of the equalizer behind the AWG: %.2f dB)\n', 10*log10(b.eq_penalty));
fprintf('BER of Gaussian noise with the SNR of the budget: %.3e\n', b.BER_gauss);

%% 4. Self-checks (same tolerances as step22)
diff_power = max(abs(r.stage_power - b.budget_total));
assert(diff_power < 0.1, 'the power after a block differs from the budget by 0.1 dB or more');
assert(abs(r.ase1_sim - b.budget_ase1) < 0.1, 'ASE of the EDFA differs from the formula');
assert(abs(r.ase2_sim - b.budget_ase2) < 0.1, 'ASE of the pre-amplifier differs from the formula');
assert(abs(r.sigpw - b.budget_sigpw) < 0.1, 'sigpw differs from the budget');
fprintf('\nSelf-check 1 passed: power after every block = budget within 0.1 dB (largest difference %.3f dB)\n', diff_power);
if p.rolloff == 0
    assert(abs(r.SNR_sim - b.SNR_budget) < 0.7, 'SNR differs from the budget by 0.7 dB or more');
    fprintf('Self-check 2 passed: simulated SNR = SNR budget within 0.7 dB (difference %+.2f dB)\n', ...
        r.SNR_sim - b.SNR_budget);
end

%% 5. Figures and files
plot_level_diagram(stage_names, r.stage_power);
if isprop(gcf, 'Theme'), set(gcf, 'Theme', 'light'); end
hold on; plot(1:10, b.budget_total, 'k-');
legend('simulation (total power)', 'closed-form budget', 'Location', 'southwest');
title(sprintf('Proposed switch: PTx = %.1f dBm, M = %d, A%d, K = %d, %s', p.PTx, p.sw_size, ...
    p.stage3_coupler_flag + 1, p.K, p.pattern));
fig1 = gcf;
ideal_sym = my_qammod((0:r.Mary-1).', r.Mary);
fig2 = figure;
if isprop(fig2, 'Theme'), set(fig2, 'Theme', 'light'); end
plot(real(r.rx_sym), imag(r.rx_sym), '.', 'MarkerSize', 4); hold on;
plot(real(ideal_sym), imag(ideal_sym), 'k+', 'MarkerSize', 8, 'LineWidth', 1.2);
grid on; axis equal; xlabel('In-phase component'); ylabel('Quadrature component');
title(sprintf('Received symbols: SNR = %.1f dB, BER = %.2e', r.SNR_sim, r.BER));
legend('received symbols', 'ideal points', 'Location', 'northeastoutside');

time_stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
file_base = fullfile(results_folder, ['claude_step23_' time_stamp]);
BER = r.BER; SNR_sim = r.SNR_sim; stage_power = r.stage_power;
SNR_budget = b.SNR_budget; budget_total = b.budget_total; budget_target = b.budget_target;
save([file_base '.mat'], 'p', 'BER', 'SNR_sim', 'stage_power', 'SNR_budget', 'budget_total', ...
    'budget_target', 'b', 'time_stamp');
saveas(fig1, [file_base '_level.png']);
saveas(fig2, [file_base '_constellation.png']);
fprintf('\nSaved: %s.{mat,_level.png,_constellation.png}\n', file_base);
```

## `work/claude_main_three_stage_proposed.m`

```matlab
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
```

## `work/claude_main_two_stage_common.m`

```matlab
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
```

## `work/claude_work3_comparison.m`

```matlab
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
```

## `claude_runs/claude_run_baseline.m`

```matlab
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
```

## `claude_runs/claude_run_demos.m`

```matlab
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
```
