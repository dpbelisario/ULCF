%% my_step23_proposed - proposed three-stage switch, one operating point (start: copy of step22)

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['my_step23_proposed: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters
datasize = 3e4;
PTx = 4;
sw_size = 64;
stage3_coupler_flag = 1;
mod_flag = 4;
up = 2;
baudrate = 32e9;
pol_flag = 1;
fiber_flag = 0;
Fan_in_loss = 1.5;
Fan_out_loss = 1.5;
N = 96;
signal_interval = 50e9;
NF = 6;
edfa_sat1 = 20;
edfa_sat2 = 10;
NF2 = 4;
rolloff = 0;
sel_ex_ratio = 35;
xt_wave_max = Inf;
AWG_loss = 6;
FWHM_AWG = 50e9;
AWG_XT = 32;
Morder = 16;
seed = 1;
BER_limit = 1e-2;
K = 12;
assert(mod(N,K) == 0);
pattern = 'dispersed';

%% 2. Values that follow from the parameters
Mary = 2^mod_flag;
Fs = up*baudrate;
Hrcos = rcosfilter(datasize*up, baudrate, Fs, rolloff);
assert(xt_wave_max >= 1, 'xt_wave_max must be 1 or more (Inf = one waveform per leak)');

%% 3. Transmission chain
rng(seed);
stage_power = zeros(1, 9);

% [1] Transmitter of the target signal
pin = PTx - 3*pol_flag;
[signal, data, data_mod] = TL_QAM(datasize, up, Hrcos, pin, mod_flag);
stage_power(1) = calc_signal_power(signal);

% [2] Fan-in and fan-out of the multicore fiber
fiber_loss = 0;
if fiber_flag == 1
    fiber_loss = Fan_in_loss + Fan_out_loss;
end
signal = attenuation(signal, fiber_loss);
stage_power(2) = calc_signal_power(signal);

% [3] Stage-1 space switch, selector + selector
sw1_loss = 2*selector_loss(sw_size);
sw1_xt_att = 2*sel_ex_ratio;
num_xt = sw_size - 1;
num_xt_wave = min(num_xt, floor(xt_wave_max));
xt_boost = 10*log10(num_xt/num_xt_wave);
xt_power = pin - fiber_loss + xt_boost;
crosstalk = zeros(datasize*up, 1);
for k = 1:num_xt_wave
    [xt, ~, ~] = TL_QAM(datasize, up, Hrcos, xt_power, mod_flag);
    crosstalk = crosstalk + xt;
end
signal = signal + attenuation(crosstalk, sw1_xt_att);
signal = attenuation(signal, sw1_loss);
stage_power(3) = calc_signal_power(signal);

% [4] Aggregation coupler
N_agg = N/K;
agg_coupler_loss = coupler_loss(N_agg);
signal = attenuation(signal, agg_coupler_loss);
stage_power(4) = calc_signal_power(signal);

% [5] EDFA of the wavelength-routing switch
sat1 = edfa_sat1 - 3*pol_flag;
edfaGain = sat1 - 10*log10(N_agg) - calc_signal_power(signal);
[signal, aseNoise] = amplified_by_EDFA3(signal, Fs, edfaGain, NF, sat1, N_agg, ...
    signal_interval);
stage_power(5) = calc_signal_power(signal);

% [6] AWG
shift = 0;
if K > 1
    AWG_loss = 9;
    AWG_loss = AWG_loss + coupler_loss(2);
    FWHM_AWG = 66.6e9;
    shift = ULCF_dev_freq(K);
end

signal = awg(signal, AWG_loss, shift, Fs, FWHM_AWG, AWG_XT, 1);
stage_power(6) = calc_signal_power(signal);

% [7] In-band crosstalk of the ULCF AWG (legacy lines 172-183)
Hband = nyquistfilter(datasize*up, 0, Fs, baudrate*(1+rolloff));
if K > 1
    AWG_crosstalk = zeros(datasize*up, K - 1);
    sigpw = calc_signal_power(apply_filter(signal, Hband, 1));
    for k = 1:(K-1)
        [AWG_crosstalk(:, k), ~, ~] = ...
            TL_QAM(datasize, up, Hrcos, sigpw, mod_flag);
    end
    AWG_crosstalk = attenuation(AWG_crosstalk, AWG_XT);
    AWG_crosstalk = sum(AWG_crosstalk, 2);
    signal = signal + AWG_crosstalk;
end
stage_power(7) = calc_signal_power(signal);

% [8] Stage-3 space switch
if stage3_coupler_flag == 1
    sw3_loss = selector_loss(sw_size) + coupler_loss(sw_size);
    sw3_xt_att = sel_ex_ratio;
else
    sw3_loss = 2*selector_loss(sw_size);
    sw3_xt_att = 2*sel_ex_ratio;
end
Hband = nyquistfilter(datasize*up, 0, Fs, baudrate*(1+rolloff));
num_xt3 = my_inband_leaks(sw_size, K, pattern);
sigpw = calc_signal_power(apply_filter(signal, Hband, 1));
crosstalk = zeros(datasize*up, 1);
if num_xt3 > 0
    num_xt3_wave = min(num_xt3, floor(xt_wave_max));
    xt3_boost = 10*log10(num_xt3/num_xt3_wave);
    xt_power = sigpw + xt3_boost;
    for k = 1:num_xt3_wave
        [xt, ~, ~] = TL_QAM(datasize, up, Hrcos, xt_power, mod_flag);
        crosstalk = crosstalk + xt;
    end
end
signal = signal + attenuation(crosstalk, sw3_xt_att);
signal = attenuation(signal, sw3_loss);
stage_power(8) = calc_signal_power(signal);

% [9] Fan-in and fan-out of the multicore fiber again
signal = attenuation(signal, fiber_loss);
stage_power(9) = calc_signal_power(signal);

% [10] Pre-amplifier of the receiver
sat2 = edfa_sat2 - 3*pol_flag;
edfaGain = sat2 - calc_signal_power(signal);
[signal, aseNoise2] = amplified_by_EDFA3(signal, Fs, edfaGain, NF2, sat2, 1, ...
    signal_interval);
stage_power(10) = calc_signal_power(signal);

% [11] Coherent receiver and BER
H = nyquistfilter(length(signal), 0, Fs, baudrate*(1+rolloff));
signal = apply_filter(signal, H, 1);
training_num = floor(datasize/3);
signal = adequalizet(signal, Mary, Morder, 1/256, ...
    data_mod(1:training_num), up);
BER = measure_BER_QAM(signal(training_num+1:end), ...
    data(mod_flag*training_num+1:end), mod_flag);

%% 4. Result of the simulation
num_bits = mod_flag*(datasize - training_num);
fprintf('Operating point : PTx = %.1f dBm, space switches %d x %d, Scheme A%d\n', ...
    PTx, sw_size, sw_size, stage3_coupler_flag + 1);
fprintf('Switch size     : %d x %d ports (M*N = %d*%d)\n', sw_size*N, sw_size*N, ...
    sw_size, N);
fprintf('BER             : %.3e (%d errors in %d bits), FEC limit %.0e\n', BER, ...
    round(BER*num_bits), num_bits, BER_limit);

rx_sym = signal(training_num+1:end);
tx_sym = data_mod(training_num+1:end);
g = sum(conj(tx_sym).*rx_sym)/sum(abs(tx_sym).^2);
err_sym = rx_sym - g*tx_sym;
SNR_sim = 10*log10(abs(g)^2*mean(abs(tx_sym).^2)/mean(abs(err_sym).^2));

%% 5. Closed-form power budget
h_planck = 6.62607004e-34;
f_opt = 299792458/1550e-9;
budget_target = zeros(1, 10);
budget_total = zeros(1, 10);

% [1] to [4]
xt_sw1 = num_xt*10^(-sw1_xt_att/10);
budget_target(1) = pin;
budget_total(1) = pin;
budget_target(2) = budget_target(1) - fiber_loss;
budget_total(2) = budget_target(2);
budget_target(3) = budget_target(2) - sw1_loss;
budget_total(3) = budget_target(3) + 10*log10(1 + xt_sw1);
budget_target(4) = budget_target(3) - agg_coupler_loss;
budget_total(4) = budget_total(3) - agg_coupler_loss;

% [5] EDFA
limit1 = sat1 - 10*log10(N_agg);
G1 = 10^((limit1 - budget_total(4))/10);
F1 = 10^(NF/10);
ase1_mW = (G1*F1 - 1)*h_planck*f_opt*Fs/2*1e3;
ase1_ref_mW = ase1_mW*signal_interval/Fs;
scale1 = 10^(limit1/10)/(10^(limit1/10) + ase1_ref_mW);
budget_target(5) = budget_target(4) + 10*log10(G1*scale1);
budget_total(5) = 10*log10((10^(limit1/10) + ase1_mW)*scale1);
budget_ase1 = 10*log10(ase1_mW*scale1);

% [6] AWG
Hawg = gaussfilter(datasize*up, shift, Fs, FWHM_AWG, AWG_XT, 1);
w_sig = Hrcos.^2/sum(Hrcos.^2);
T_sig = sum(w_sig.*Hawg.^2);
T_ase = mean(Hawg.^2);
T_inband = mean(Hband.^2.*Hawg.^2);
budget_target(6) = budget_target(5) - AWG_loss + 10*log10(T_sig);
sig6_mW = 10^(budget_target(6)/10)*(1 + xt_sw1);
ase6_mW = ase1_mW*scale1*10^(-AWG_loss/10);
budget_total(6) = 10*log10(sig6_mW + ase6_mW*T_ase);

% [7] AWG crosstalk
budget_sigpw = 10*log10(sig6_mW + ase6_mW*T_inband);
xt_awg_mW = 0;
if K > 1
    xt_awg_mW = (K - 1)*10^((budget_sigpw - AWG_XT)/10);
end
budget_target(7) = budget_target(6);
budget_total(7) = 10*log10(10^(budget_total(6)/10) + xt_awg_mW);

% [8] Stage-3 switch
budget_sigpw = 10*log10(sig6_mW + ase6_mW*T_inband + xt_awg_mW);
xt_sw3_mW = num_xt3*10^((budget_sigpw - sw3_xt_att)/10);
budget_target(8) = budget_target(7) - sw3_loss;
budget_total(8) = 10*log10(10^(budget_total(7)/10) + xt_sw3_mW) - sw3_loss;

% [9] fan-in and fan-out
budget_target(9) = budget_target(8) - fiber_loss;
budget_total(9) = budget_total(8) - fiber_loss;

% [10] Pre-amplifier
limit2 = sat2;
G2 = 10^((limit2 - budget_total(9))/10);
F2 = 10^(NF2/10);
ase2_mW = (G2*F2 - 1)*h_planck*f_opt*Fs/2*1e3;
ase2_ref_mW = ase2_mW*signal_interval/Fs;
scale2 = 10^(limit2/10)/(10^(limit2/10) + ase2_ref_mW);
budget_target(10) = budget_target(9) + 10*log10(G2*scale2);
budget_total(10) = 10*log10((10^(limit2/10) + ase2_mW)*scale2);
budget_ase2 = 10*log10(ase2_mW*scale2);

%% 6. Closed-form SNR budget
eq_penalty = T_sig*sum(w_sig./Hawg.^2);
nsr_ase1 = (ase1_mW*baudrate/Fs)/(G1*10^(budget_target(4)/10));
nsr_xt_sw1 = xt_sw1;
nsr_xt_sw3 = xt_sw3_mW/10^(budget_target(6)/10)*eq_penalty;
nsr_ase2 = (ase2_mW*baudrate/Fs)/(G2*10^(budget_target(8)/10))*eq_penalty;
SNR_budget = -10*log10(nsr_ase1 + nsr_xt_sw1 + nsr_xt_sw3 + nsr_ase2);

BER_gauss = NaN;
if mod_flag ~= 5
    BER_gauss = 2/mod_flag*(1 - 1/sqrt(Mary)) ...
        *erfc(sqrt(3*10^(SNR_budget/10)/(2*(Mary - 1))));
end

%% 7. Tables
stage_names = {'Tx', 'Fan-in/out', 'Switch 1', 'Coupler', 'EDFA', 'AWG', ...
    'Switch 3', 'Fan-in/out', 'Pre-amp'};
fprintf('\nPower after every block [dBm] (one polarization, inside the band Fs)\n');
fprintf('  %-18s %11s %11s %11s\n', 'block', 'simulation', 'budget', 'budget');
fprintf('  %-18s %11s %11s %11s\n', '', '(total)', '(total)', '(target)');
for k = 1:9
    fprintf('  [%d] %-14s %11.3f %11.3f %11.3f\n', k, stage_names{k}, ...
        stage_power(k), budget_total(k), budget_target(k));
end
ase1_sim = calc_signal_power(aseNoise);
ase2_sim = calc_signal_power(aseNoise2);
fprintf('  %-18s %11.3f %11.3f\n', 'ASE of EDFA', ase1_sim, budget_ase1);
fprintf('  %-18s %11.3f %11.3f\n', 'ASE of pre-amp', ase2_sim, budget_ase2);
fprintf('  %-18s %11.3f %11.3f\n', 'sigpw (block [7])', sigpw, budget_sigpw);

fprintf('\nSNR contributions in the signal bandwidth [dB]\n');
fprintf('  ASE of the EDFA                 %7.2f\n', -10*log10(nsr_ase1));
fprintf('  crosstalk of the stage-1 switch %7.2f\n', -10*log10(nsr_xt_sw1));
fprintf('  crosstalk of the stage-3 switch %7.2f\n', -10*log10(nsr_xt_sw3));
fprintf('  ASE of the pre-amplifier        %7.2f\n', -10*log10(nsr_ase2));
fprintf('  all together (budget)           %7.2f\n', SNR_budget);
fprintf('  simulation                      %7.2f\n', SNR_sim);
fprintf('  (noise gain of the equalizer behind the AWG: %.2f dB)\n', ...
    10*log10(eq_penalty));
fprintf('BER of Gaussian noise with the SNR of the budget: %.3e\n', BER_gauss);

%% 8. Self-checks
diff_power = max(abs(stage_power - budget_total));
assert(diff_power < 0.1, ...
    'the power after a block differs from the closed-form budget by 0.1 dB or more');
assert(abs(ase1_sim - budget_ase1) < 0.1, ...
    'the ASE power of the EDFA differs from (G*F - 1)*h*f*Fs/2 by 0.1 dB or more');
assert(abs(ase2_sim - budget_ase2) < 0.1, ...
    'the ASE power of the pre-amplifier differs from the formula by 0.1 dB or more');
assert(abs(sigpw - budget_sigpw) < 0.1, ...
    'the reference power of the stage-3 crosstalk differs from the budget');
fprintf('\nSelf-check 1 passed: power after every block = budget within 0.1 dB ');
fprintf('(largest difference %.3f dB)\n', diff_power);

if rolloff == 0
    assert(abs(SNR_sim - SNR_budget) < 0.7, ...
        'the SNR of the received symbols differs from the SNR budget by 0.7 dB or more');
    fprintf('Self-check 2 passed: simulated SNR = SNR budget within 0.7 dB ');
    fprintf('(difference %+.2f dB)\n', SNR_sim - SNR_budget);
else
    fprintf('Self-check 2 skipped: the SNR budget is valid for rolloff = 0 only.\n');
end

%% 9. Figures

plot_level_diagram(stage_names, stage_power);
if isprop(gcf, 'Theme')
    set(gcf, 'Theme', 'light');
end
hold on;
plot(1:9, budget_total, 'k-');
legend('simulation (total power)', 'closed-form budget', 'Location', 'southwest');
title(sprintf('Level diagram: PTx = %.1f dBm, M = %d, Scheme A%d', PTx, sw_size, ...
    stage3_coupler_flag + 1));

ideal_sym = my_qammod((0:Mary-1).', Mary);
figure;
if isprop(gcf, 'Theme')
    set(gcf, 'Theme', 'light');
end
plot(real(rx_sym), imag(rx_sym), '.', 'MarkerSize', 4);
hold on;
plot(real(ideal_sym), imag(ideal_sym), 'k+', 'MarkerSize', 8, 'LineWidth', 1.2);
grid on;
axis equal;
xlabel('In-phase component');
ylabel('Quadrature component');
title(sprintf('Received symbols: SNR = %.1f dB, BER = %.2e', SNR_sim, BER));
legend('received symbols', 'ideal points', 'Location', 'northeastoutside');
