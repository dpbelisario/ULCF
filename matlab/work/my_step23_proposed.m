%% my_step23_proposed - proposed three-stage switch, one operating point (start: copy of step22)

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['my_step23_proposed: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1-2. Parameters
p = my_params();

%% 3. Transmission chain
r = my_chain(p);

%% 4. Result of the simulation
num_bits = p.mod_flag*(p.datasize - r.training_num);
fprintf('Operating point : PTx = %.1f dBm, space switches %d x %d, Scheme A%d\n', ...
    p.PTx, p.sw_size, p.sw_size, p.stage3_coupler_flag + 1);
fprintf('Switch size     : %d x %d ports (M*N = %d*%d)\n', p.sw_size*p.N, p.sw_size*p.N, ...
    p.sw_size, p.N);
fprintf('BER             : %.3e (%d errors in %d bits), FEC limit %.0e\n', r.BER, ...
    round(r.BER*num_bits), num_bits, p.BER_limit);

%% 5-6. Closed-form power budget and SNR budget
b = my_budget(p, r);

%% 7. Tables
stage_names = {'Tx', 'Fan-in/out', 'Switch 1', 'Coupler', 'EDFA', 'AWG', ...
    'AWG crosstalk', 'Switch 3', 'Fan-in/out', 'Pre-amp'};
fprintf('\nPower after every block [dBm] (one polarization, inside the band Fs)\n');
fprintf('  %-18s %11s %11s %11s\n', 'block', 'simulation', 'budget', 'budget');
fprintf('  %-18s %11s %11s %11s\n', '', '(total)', '(total)', '(target)');
for k = 1:10
    fprintf('  [%d] %-14s %11.3f %11.3f %11.3f\n', k, stage_names{k}, ...
        r.stage_power(k), b.budget_total(k), b.budget_target(k));
end
ase1_sim = calc_signal_power(r.aseNoise);
ase2_sim = calc_signal_power(r.aseNoise2);
fprintf('  %-18s %11.3f %11.3f\n', 'ASE of EDFA', ase1_sim, b.budget_ase1);
fprintf('  %-18s %11.3f %11.3f\n', 'ASE of pre-amp', ase2_sim, b.budget_ase2);
fprintf('  %-18s %11.3f %11.3f\n', 'sigpw (block [8])', r.sigpw, b.budget_sigpw);

fprintf('\nSNR contributions in the signal bandwidth [dB]\n');
fprintf('  ASE of the EDFA                 %7.2f\n', -10*log10(b.nsr_ase1));
fprintf('  crosstalk of the stage-1 switch %7.2f\n', -10*log10(b.nsr_xt_sw1));
fprintf('  crosstalk of the ULCF AWG       %7.2f\n', -10*log10(b.nsr_xt_awg));
fprintf('  crosstalk of the stage-3 switch %7.2f\n', -10*log10(b.nsr_xt_sw3));
fprintf('  ASE of the pre-amplifier        %7.2f\n', -10*log10(b.nsr_ase2));
fprintf('  all together (budget)           %7.2f\n', b.SNR_budget);
fprintf('  simulation                      %7.2f\n', r.SNR_sim);
fprintf('  (noise gain of the equalizer behind the AWG: %.2f dB)\n', ...
    10*log10(b.eq_penalty));
fprintf('BER of Gaussian noise with the SNR of the budget: %.3e\n', b.BER_gauss);

%% 8. Self-checks
diff_power = max(abs(r.stage_power - b.budget_total));
assert(diff_power < 0.1, ...
    'the power after a block differs from the closed-form budget by 0.1 dB or more');
assert(abs(ase1_sim - b.budget_ase1) < 0.1, ...
    'the ASE power of the EDFA differs from (G*F - 1)*h*f*Fs/2 by 0.1 dB or more');
assert(abs(ase2_sim - b.budget_ase2) < 0.1, ...
    'the ASE power of the pre-amplifier differs from the formula by 0.1 dB or more');
assert(abs(r.sigpw - b.budget_sigpw) < 0.1, ...
    'the reference power of the stage-3 crosstalk differs from the budget');
fprintf('\nSelf-check 1 passed: power after every block = budget within 0.1 dB ');
fprintf('(largest difference %.3f dB)\n', diff_power);

if p.rolloff == 0
    assert(abs(r.SNR_sim - b.SNR_budget) < 0.7, ...
        'the SNR of the received symbols differs from the SNR budget by 0.7 dB or more');
    fprintf('Self-check 2 passed: simulated SNR = SNR budget within 0.7 dB ');
    fprintf('(difference %+.2f dB)\n', r.SNR_sim - b.SNR_budget);
else
    fprintf('Self-check 2 skipped: the SNR budget is valid for rolloff = 0 only.\n');
end

%% 9. Figures

plot_level_diagram(stage_names, r.stage_power);
if isprop(gcf, 'Theme')
    set(gcf, 'Theme', 'light');
end
hold on;
plot(1:10, b.budget_total, 'k-');
legend('simulation (total power)', 'closed-form budget', 'Location', 'southwest');
title(sprintf('Level diagram: PTx = %.1f dBm, M = %d, Scheme A%d', p.PTx, p.sw_size, ...
    p.stage3_coupler_flag + 1));

ideal_sym = my_qammod((0:p.Mary-1).', p.Mary);
figure;
if isprop(gcf, 'Theme')
    set(gcf, 'Theme', 'light');
end
plot(real(r.rx_sym), imag(r.rx_sym), '.', 'MarkerSize', 4);
hold on;
plot(real(ideal_sym), imag(ideal_sym), 'k+', 'MarkerSize', 8, 'LineWidth', 1.2);
grid on;
axis equal;
xlabel('In-phase component');
ylabel('Quadrature component');
title(sprintf('Received symbols: SNR = %.1f dB, BER = %.2e', r.SNR_sim, r.BER));
legend('received symbols', 'ideal points', 'Location', 'northeastoutside');
