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
