%% demo15_edfa_ase - EDFA and ASE noise: a loss before the amplifier is expensive
% Page: docs/15_edfa_ase.html
% An optical amplifier (EDFA) adds noise: amplified spontaneous emission (ASE).
%   section 3: ONE EDFA. Its ASE power is (G*F - 1)*h*f*Fs/2 in one polarization.
%              The SNR behind it is P_in/(F*h*f*baudrate): the INPUT power decides it.
%   sections 4, 5: chain transmitter -> EDFA -> pre-amplifier -> receiver, ONE loss.
%              BEFORE the EDFA the loss lowers the SNR by the same number of dB.
%              AFTER the EDFA it costs little, until the pre-amplifier gets too little.
% How to run: run setup_path once (in the folder "matlab"), then run this file (F5).

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['demo15_edfa_ase: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters (amplifier values of step22_three_stage_one_point)
datasize = 3e4;  % number of symbols
mod_flag = 4;  % bits per symbol: 4 = 16QAM
up = 2;  % oversampling rate (samples per symbol)
baudrate = 32e9;  % symbol rate [Hz]
signal_interval = 50e9;  % channel spacing [Hz]
P_in = -20;  % power of the channel before any loss, both polarizations [dBm]
gain_dB = 20;  % section 3: gain of the single EDFA [dB]
NF = 6;  % noise figure of the EDFA [dB]
edfa_sat1 = 20;  % saturation power of the EDFA: all channels, both pol. [dBm]
N = 96;  % number of wavelength channels that the EDFA carries
NF2 = 4;  % noise figure of the pre-amplifier [dB]
edfa_sat2 = 10;  % saturation power of the pre-amplifier, both polarizations [dBm]
loss_ary = 0:5:30;  % section 4: loss that is put before or after the EDFA [dB]
h = 6.62607004e-34;  % Planck constant [J s] (the value in amplified_by_EDFA3)
f = 299792458/1550e-9;  % optical frequency at the wavelength 1550 nm [Hz]

%% 2. Test signal and receive filter
% ONE polarization of a polarization-multiplexed channel is simulated, as in step22.
Fs = up*baudrate;  % sampling frequency = width of the simulated band [Hz]
Hrcos = rcosfilter(datasize*up, baudrate, Fs, 0);  % transmit mask (Nyquist)
pin = P_in - 3;  % the simulated polarization carries half of P_in [dBm]
[signal_tx, ~, data_mod] = TL_QAM(datasize, up, Hrcos, pin, mod_flag);
H = nyquistfilter(datasize*up, 0, Fs, baudrate);  % receive filter: the signal band
hfB = 10*log10(h*f*baudrate*1e3);  % the power h*f*baudrate, W -> dBm [dBm]

%% 3. One EDFA with a fixed gain: ASE power and SNR
% sat = Inf: no output power limit. N = 1: the amplifier carries only this signal.
% The last input (signal_interval) belongs to the output power limit: see section 4.
[signal, aseNoise] = amplified_by_EDFA3(signal_tx, Fs, gain_dB, NF, Inf, 1, ...
    signal_interval);
G = 10^(gain_dB/10);  % gain, dB -> linear
F = 10^(NF/10);  % noise figure, dB -> linear
ase_sim = calc_signal_power(aseNoise);  % ASE in the whole band Fs [dBm]
ase_theory = 10*log10((G*F - 1)*h*f*Fs/2*1e3);  % one polarization, W -> dBm
% signal - aseNoise is the amplified signal without noise. H keeps the signal band.
sig_band = calc_signal_power(apply_filter(signal - aseNoise, H, 1));  % [dBm]
ase_band = calc_signal_power(apply_filter(aseNoise, H, 1));  % [dBm]
SNR_one = sig_band - ase_band;  % SNR in the signal band [dB]
SNR_rule = P_in - hfB - NF;  % rule: SNR = P_in/(F*h*f*baudrate) [dB]
fprintf('One EDFA (P_in = %.2f dBm, gain %.0f dB, NF = %.1f dB)\n', P_in, gain_dB, NF);
fprintf('  ASE power in the band Fs: %.2f dBm (formula %.2f dBm)\n', ase_sim, ase_theory);
fprintf('  SNR in the signal band  : %.2f dB (rule P_in + %.2f - NF = %.2f dB)\n', ...
    SNR_one, -hfB, SNR_rule);

%% 4. Chain with two amplifiers: the loss before or after the EDFA (simulation)
% One row per loss value. Column 1: the loss is before the EDFA. Column 2: after it.
% Both amplifiers work at their output power limit, sat - 10*log10(number of channels).
% The limit holds for the signal plus the ASE inside one channel spacing (signal_interval).
num_loss = numel(loss_ary);  % number of loss values
loss_before = [loss_ary.', zeros(num_loss, 1)];  % transmitter -> EDFA [dB]
loss_after = [zeros(num_loss, 1), loss_ary.'];  % EDFA -> pre-amplifier [dB]
sat1 = edfa_sat1 - 3;  % EDFA: output power of one polarization [dBm]
sat2 = edfa_sat2 - 3;  % pre-amplifier: output power of one polarization [dBm]
SNR_sim = zeros(num_loss, 2);  % SNR of the received symbols [dB]
for k = 1:num_loss
    for place = 1:2
        signal = attenuation(signal_tx, loss_before(k, place));
        % EDFA of the wavelength-routing switch: N channels share its output power
        edfaGain = sat1 - 10*log10(N) - calc_signal_power(signal);
        signal = amplified_by_EDFA3(signal, Fs, edfaGain, NF, sat1, N, signal_interval);
        signal = attenuation(signal, loss_after(k, place));
        % pre-amplifier of the receiver: it carries one channel
        edfaGain = sat2 - calc_signal_power(signal);
        signal = amplified_by_EDFA3(signal, Fs, edfaGain, NF2, sat2, 1, signal_interval);
        % receiver: filter, one sample per symbol, compare with the sent symbols
        signal = apply_filter(signal, H, 1);
        rx_sym = signal(1:up:end);  % samples at the symbol instants
        g = sum(conj(data_mod).*rx_sym)/sum(abs(data_mod).^2);  % gain of the symbols
        err_sym = rx_sym - g*data_mod;  % everything that is not the sent symbol
        SNR_sim(k, place) = 10*log10(abs(g)^2*mean(abs(data_mod).^2) ...
            /mean(abs(err_sym).^2));
    end
end

%% 5. Chain with two amplifiers: theory
% Rule for every amplifier: SNR = (power at ITS input, both pol.)/(F*h*f*baudrate).
% The noise powers of the two amplifiers add: 1/SNR = 1/SNR_edfa + 1/SNR_pre.
P_edfa_out = edfa_sat1 - 10*log10(N);  % one channel after the EDFA, both pol. [dBm]
SNR_edfa = (P_in - loss_before) - hfB - NF;  % EDFA alone [dB]
SNR_pre = (P_edfa_out - loss_after) - hfB - NF2;  % pre-amplifier alone [dB]
SNR_theory = -10*log10(10.^(-SNR_edfa/10) + 10.^(-SNR_pre/10));  % both [dB]
fprintf('\nSNR in the signal band [dB] for a loss in the chain\n');
fprintf('   loss    loss before the EDFA     loss after the EDFA\n');
fprintf('   [dB]  simulation      theory  simulation      theory\n');
for k = 1:num_loss
    fprintf('  %5.0f %11.2f %11.2f %11.2f %11.2f\n', loss_ary(k), SNR_sim(k, 1), ...
        SNR_theory(k, 1), SNR_sim(k, 2), SNR_theory(k, 2));
end

%% 6. Self-checks
assert(abs(ase_sim - ase_theory) < 0.1, 'the ASE power is not (G*F - 1)*h*f*Fs/2');
assert(abs(SNR_one - SNR_rule) < 0.2, 'the SNR is not P_in/(F*h*f*baudrate)');
fprintf('\nSelf-check 1 passed: ASE power and SNR of one EDFA follow the formulas\n');
diff_SNR = max(max(abs(SNR_sim - SNR_theory)));  % largest difference in the table [dB]
assert(diff_SNR < 0.5, 'an SNR of the chain differs from the theory by 0.5 dB or more');
fprintf('Self-check 2 passed: SNR of the chain = theory within 0.5 dB ');
fprintf('(largest difference %.2f dB)\n', diff_SNR);
loss_step = loss_ary(3) - loss_ary(1);  % rows 1 and 3 of the table: 10 dB by default
cost_before = SNR_sim(1, 1) - SNR_sim(3, 1);  % SNR lost with the loss before the EDFA
cost_after = SNR_sim(1, 2) - SNR_sim(3, 2);  % SNR lost with the loss after the EDFA
assert(abs(cost_before - loss_step) < 0.3, ...
    'a loss before the EDFA must lower the SNR by the same number of dB');
assert(cost_after < cost_before/2, 'a loss after the EDFA must cost much less SNR');
fprintf('Self-check 3 passed: a loss of %.0f dB lowers the SNR by ', loss_step);
fprintf('%.2f dB before the EDFA, by %.2f dB after it\n', cost_before, cost_after);

%% 7. Figure: black lines = theory, markers = simulation
figure;
plot(loss_ary, SNR_theory(:, 1), 'k-');
hold on;
plot(loss_ary, SNR_sim(:, 1), 'bo', loss_ary, SNR_sim(:, 2), 'rs', 'LineWidth', 1.5);
plot(loss_ary, SNR_theory(:, 2), 'k-');
grid on;
xlabel('Loss put into the chain [dB]');
ylabel('SNR in the signal bandwidth [dB]');
title(sprintf('Where a loss is expensive (P_{in} = %.0f dBm, NF = %.0f dB)', P_in, NF));
legend('theory', 'simulation: loss before the EDFA', ...
    'simulation: loss after the EDFA', 'Location', 'southwest');
