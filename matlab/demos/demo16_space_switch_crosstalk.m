%% demo16_space_switch_crosstalk - Leaks of a space switch, in band and out of band
% Page: docs/16_space_switch_crosstalk.html
% A selector + coupler space switch (M x M) adds M-1 leaks to the target signal.
% Each leak passed ONE selector that is switched off: it is sel_ex_ratio dB weaker.
%   Case 1: the leaks have the wavelength of the target (in-band crosstalk).
%           The BER rises with M, as with Gaussian noise of the same power.
%   Case 2: the same leaks are on the next wavelength channel, foff = 50 GHz away.
%           The receive filter removes them: the BER is the one without leaks.
% The loss of the switch is left out: it is the same for the target and the leaks.
% How to run: run setup_path once, then type demo16_space_switch_crosstalk.

clear; close all; rng(1);

%% 1. Parameters
datasize = 3.2e4;  % number of symbols (FFT bin spacing baudrate/datasize = 1 MHz)
mod_flag = 4;  % bits per symbol: 4 = 16QAM
baudrate = 32e9;  % symbol rate [Hz] (as in step22)
up = 5;  % oversampling rate (samples per symbol); the main scripts use 2: see section 2
sigpw = 0;  % power of the target and of every other input signal [dBm]
SNR_noise = 16;  % SNR without leaks, in the signal bandwidth [dB] (amplifier noise)
sel_ex_ratio = 35;  % extinction ratio of one selector [dB] (as in step22)
sw_xt_att = sel_ex_ratio;  % a leak is blocked by ONE selector [dB]
list_sw_size = [16 32 64 128];  % sizes M of the space switch
foff = 50e9;  % case 2: frequency offset of the leaks = channel spacing [Hz]
Morder = 16;  % order of the adaptive equalizer (it has Morder + 1 taps)
BER_limit = 1e-2;  % FEC limit

%% 2. Sampling frequency and filters
Mary = 2^mod_flag;  % number of constellation points (16 for 16QAM)
Fs = up*baudrate;  % sampling frequency = width of the simulated band [Hz]
% Rule: a leak shifted by foff reaches up to foff + baudrate*(1+rolloff)/2. This edge
%   must lie inside the simulated band: Fs/2 >= foff + baudrate*(1+rolloff)/2.
%   Here rolloff = 0: 80 GHz >= 66 GHz. This is why up is 5 here:
%   up = 4 gives Fs/2 = 64 GHz, and up = 2 (the main scripts) only 32 GHz.
assert(Fs/2 >= foff + baudrate/2, 'Fs is too small for foff: use a larger up');
Hrcos = rcosfilter(datasize*up, baudrate, Fs, 0);  % transmit mask (roll-off 0)
H = nyquistfilter(datasize*up, 0, Fs, baudrate);  % receive filter (brick wall)
training_num = floor(datasize/3);  % symbols that train the equalizer
num_bits = mod_flag*(datasize - training_num);  % number of bits that are compared

%% 3. Target signal, noise and the BER without leaks
[signal, data, data_mod] = TL_QAM(datasize, up, Hrcos, sigpw, mod_flag);
% White Gaussian noise over the band Fs. The receive filter keeps the part 1/up.
noise_W = up*10^((sigpw - SNR_noise)/10)*1e-3;  % noise power in the band Fs [W]
noise = sqrt(noise_W/2)*(randn(datasize*up, 1) + 1i*randn(datasize*up, 1));
% receiver: brick-wall filter, equalizer (trained with the first third), BER
rx = apply_filter(signal + noise, H, 1);
rx = adequalizet(rx, Mary, Morder, 1/256, data_mod(1:training_num), up);
BER_ref = measure_BER_QAM(rx(training_num+1:end), ...
    data(mod_flag*training_num+1:end), mod_flag);

%% 4. Leaks on the wavelength of the target (case 1) and foff away (case 2)
SXR_sim = zeros(numel(list_sw_size), 1);  % measured signal-to-crosstalk ratio [dB]
BER_sim = zeros(numel(list_sw_size), 2);  % column 1 = case 1, column 2 = case 2
for i = 1:numel(list_sw_size)
    sw_size = list_sw_size(i);
    % The other sw_size-1 inputs carry independent signals with the power of the
    % target (the same loop as in block [7] of step22_three_stage_one_point).
    crosstalk = zeros(datasize*up, 1);
    for k = 1:sw_size-1
        [xt, ~, ~] = TL_QAM(datasize, up, Hrcos, sigpw, mod_flag);
        crosstalk = crosstalk + xt;  % independent data in every waveform
    end
    leak = attenuation(crosstalk, sw_xt_att);  % sum of the leaks at the output
    SXR_sim(i) = sigpw - calc_signal_power(leak);
    for c = 1:2
        if c == 1
            rx = signal + noise + leak;  % leaks on the wavelength of the target
        else
            rx = signal + noise + freqoff(leak, foff, Fs);  % leaks foff away
        end
        rx = apply_filter(rx, H, 1);
        rx = adequalizet(rx, Mary, Morder, 1/256, data_mod(1:training_num), up);
        BER_sim(i, c) = measure_BER_QAM(rx(training_num+1:end), ...
            data(mod_flag*training_num+1:end), mod_flag);
    end
end

%% 5. Prediction: in-band leaks act like Gaussian noise of the same power
% Element n of the next vectors belongs to n leaks, that is to a switch of size n+1.
num_leak = (1:max(list_sw_size)-1).';
SXR = sw_xt_att - 10*log10(num_leak);  % signal-to-crosstalk ratio [dB]
SNR_total = -10*log10(10^(-SNR_noise/10) + 10.^(-SXR/10));  % noise + leaks [dB]
% BER of square QAM with Gray mapping in Gaussian noise (mod_flag = 2, 4 or 6)
c1 = 2/mod_flag*(1 - 1/sqrt(Mary));  % 3/8 for 16QAM
c2 = 3/(2*(Mary - 1));  % 1/10 for 16QAM
BER_gauss = c1*erfc(sqrt(c2*10.^(SNR_total/10)));  % with n in-band leaks
BER_gauss_ref = c1*erfc(sqrt(c2*10^(SNR_noise/10)));  % without leaks

%% 6. Table
idx = list_sw_size(:) - 1;  % elements of the prediction that belong to list_sw_size
fprintf('Simulated band Fs = %.0f GHz; a leak shifted by %.0f GHz needs %.0f GHz\n', ...
    Fs/1e9, foff/1e9, 2*(foff + baudrate/2)/1e9);
fprintf('BER without leaks: %.3e (%d errors in %d bits), prediction: %.3e\n', ...
    BER_ref, round(BER_ref*num_bits), num_bits, BER_gauss_ref);
fprintf('\n    M  leaks  SXR [dB]  SXR [dB]  SNR [dB]        BER        BER        BER\n');
fprintf('             simulated   formula     total  predicted     case 1     case 2\n');
for i = 1:numel(list_sw_size)
    fprintf('%5d %6d %9.2f %9.2f %9.2f %10.2e %10.2e %10.2e\n', list_sw_size(i), ...
        idx(i), SXR_sim(i), SXR(idx(i)), SNR_total(idx(i)), BER_gauss(idx(i)), ...
        BER_sim(i, 1), BER_sim(i, 2));
end

%% 7. Self-checks
assert(max(abs(SXR_sim - SXR(idx))) < 0.2, ...
    'the measured signal-to-crosstalk ratio differs from sw_xt_att - 10*log10(M-1)');
fprintf('\nSelf-check 1 passed: SXR = sw_xt_att - 10*log10(M-1) within 0.2 dB\n');
ratio = BER_sim(:, 1)./BER_gauss(idx);  % simulation / prediction, case 1
assert(all(abs(log10(ratio)) < 0.1), ...
    'the BER with in-band leaks is not the BER of Gaussian noise of the same power');
fprintf('Self-check 2 passed: BER of case 1 = prediction within 0.1 decades ');
fprintf('(simulation/prediction = %.2f to %.2f)\n', min(ratio), max(ratio));
assert(all(abs(BER_sim(:, 2) - BER_ref) < 0.5/num_bits), ...
    'leaks outside the receive filter changed the BER');
fprintf('Self-check 3 passed: leaks %.0f GHz away do not change the BER\n', foff/1e9);

%% 8. Figure: BER versus the size of the switch
figure;
loglog(num_leak + 1, BER_gauss, 'k-', 'LineWidth', 1.2);
hold on;
loglog(list_sw_size, BER_sim(:, 1), 'ro', 'MarkerSize', 8, 'LineWidth', 1.5);
loglog([2 max(list_sw_size)], [BER_gauss_ref BER_gauss_ref], 'k-.', 'LineWidth', 1.2);
loglog(list_sw_size, BER_sim(:, 2), 'bs', 'MarkerSize', 8, 'LineWidth', 1.5);
loglog([2 max(list_sw_size)], [BER_limit BER_limit], 'k--', 'LineWidth', 1.2);
grid on;
set(gca, 'XTick', 2.^(1:7), 'XLim', [2 180], 'YLim', [1e-3 1e-1]);
xlabel('Size M of the space switch (M - 1 leaks)');
ylabel('BER');
title(sprintf('%dQAM, each leak %d dB below the target', Mary, sw_xt_att));
legend('prediction: leaks act like Gaussian noise', 'simulation, case 1 (in band)', ...
    'prediction without leaks', 'simulation, case 2 (leaks shifted)', 'FEC limit', ...
    'Location', 'northwest');
