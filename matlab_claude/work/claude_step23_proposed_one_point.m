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
