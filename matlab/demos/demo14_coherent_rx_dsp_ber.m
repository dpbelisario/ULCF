%% demo14_coherent_rx_dsp_ber - Receiver processing, BER and the FEC limit
% Page: docs/14_coherent_rx_dsp_ber.html
% Sections 3 and 4: 16QAM and 32QAM in white Gaussian noise pass the receiver
%   (receive filter -> equalizer -> decision -> BER). 16QAM is compared with the
%   theory. 32QAM has no such formula: its required SNR is read from the points.
% Section 5: a second signal (interferer) of the same power is added to 16QAM.
%   50 GHz away (the next wavelength channel) the receive filter removes it.
%   At 0 GHz (the same wavelength) it stays: the BER is far above the FEC limit.
% How to run: run setup_path once (in the folder "matlab"), then run this file (F5).

clear; close all; rng(1);

%% 1. Parameters
datasize = 3e4;  % number of symbols (as in step21 and step22)
baudrate = 32e9;  % symbol rate [Hz] (as in step22)
up = 5;  % oversampling rate (samples per symbol); the main scripts use 2: see section 5
mod_flag_ary = [4 5];  % bits per symbol of the two formats: 16QAM, 32QAM
snr_dB_ary = [11:15; 14:18];  % SNR points [dB]: row 1 = 16QAM, row 2 = 32QAM
Morder = 16;  % order of the adaptive equalizer (it has Morder + 1 taps)
BER_limit = 1e-2;  % FEC limit
snr_xt_dB = 14;  % section 5: SNR of the 16QAM target [dB]
xt_ratio_dB = 0;  % section 5: power of the interferer relative to the target [dB]
foff = 50e9;  % section 5: frequency offset of the interferer [Hz]

%% 2. Values that follow from the parameters
Fs = up*baudrate;  % sampling frequency = width of the simulated band [Hz]
Hrcos = rcosfilter(datasize*up, baudrate, Fs, 0);  % transmit mask (roll-off 0)
H = nyquistfilter(datasize*up, 0, Fs, baudrate);  % receive filter (brick wall)
training_num = floor(datasize/3);  % symbols that train the equalizer

%% 3. BER versus SNR in white Gaussian noise
% SNR = signal power / noise power inside the receive filter (width baudrate).
% The noise is white over the whole band Fs. The filter keeps the part 1/up of it.
% Every SNR point gives more than 100 bit errors: with fewer, a BER is not reliable.
BER_sim = zeros(size(snr_dB_ary));  % simulated BER: row 1 = 16QAM, row 2 = 32QAM
for q = 1:2
    mod_flag = mod_flag_ary(q);  % bits per symbol
    Mary = 2^mod_flag;  % number of constellation points
    [signal, data, data_mod] = TL_QAM(datasize, up, Hrcos, 0, mod_flag);  % 0 dBm
    for s = 1:size(snr_dB_ary, 2)
        P_noise = mean(abs(signal).^2)*up/10^(snr_dB_ary(q, s)/10);  % in Fs [W]
        noise = sqrt(P_noise/2)*(randn(datasize*up, 1) + 1i*randn(datasize*up, 1));
        rx = apply_filter(signal + noise, H, 1);  % receive filter
        % equalizer: trained with the first third of the symbols (4th input: not used)
        y = adequalizet(rx, Mary, Morder, 1/256, data_mod(1:training_num), up);
        % decision and bit-error count, only on the symbols after the training
        BER_sim(q, s) = measure_BER_QAM(y(training_num+1:end), ...
            data(mod_flag*training_num+1:end), mod_flag);
    end
end
assert(all(BER_sim(:) > 0), 'a BER of 0 was measured: use more symbols or a lower SNR');

%% 4. Theory and required SNR at the FEC limit
% Square QAM with Gray mapping, k bits per symbol, Mary = 2^k points, SNR linear:
%   BER = (2/k)*(1 - 1/sqrt(Mary))*erfc(sqrt(3*SNR/(2*(Mary - 1))))
snr_th_dB = 10:0.1:16;  % SNR axis of the theory curve [dB]
BER_th_curve = (2/4)*(1 - 1/4)*erfc(sqrt(3*10.^(snr_th_dB/10)/(2*15)));  % 16QAM
BER_th = (2/4)*(1 - 1/4)*erfc(sqrt(3*10.^(snr_dB_ary(1, :)/10)/(2*15)));  % at the points
k_ary = [2 4 6];  % QPSK, 16QAM, 64QAM
snr_req_th = zeros(1, 3);  % SNR at which the theory gives BER_limit [dB]
for q = 1:3
    Mary = 2^k_ary(q);
    x = erfcinv(BER_limit*k_ary(q)/(2*(1 - 1/sqrt(Mary))));  % erfc(x) at the limit
    snr_req_th(q) = 10*log10(2*(Mary - 1)/3*x^2);
end
% simulation: straight line through log10(BER) between the two nearest SNR points
snr_req_sim(1) = interp1(log10(BER_sim(1, :)), snr_dB_ary(1, :), log10(BER_limit));
snr_req_sim(2) = interp1(log10(BER_sim(2, :)), snr_dB_ary(2, :), log10(BER_limit));
fprintf('BER in white Gaussian noise (%d symbols counted)\n', datasize - training_num);
fprintf('  SNR [dB]  16QAM theory  16QAM simulation |  SNR [dB]  32QAM simulation\n');
for s = 1:size(snr_dB_ary, 2)
    fprintf('  %6.1f    %.3e      %.3e     |  %6.1f      %.3e\n', snr_dB_ary(1, s), ...
        BER_th(s), BER_sim(1, s), snr_dB_ary(2, s), BER_sim(2, s));
end
fprintf('Required SNR at the FEC limit %.0e [dB]\n', BER_limit);
fprintf('  theory    : QPSK %.2f, 16QAM %.2f, 64QAM %.2f\n', snr_req_th);
fprintf('  simulation: 16QAM %.2f, 32QAM %.2f\n', snr_req_sim);

%% 5. An interferer: 50 GHz away, and on the same wavelength
% Rule 1: the shifted signal reaches up to foff + baudrate*(1+rolloff)/2. This edge
%   must lie inside the simulated band: Fs/2 >= foff + baudrate*(1+rolloff)/2.
%   Here rolloff = 0: 80 GHz >= 66 GHz. This is why up is 5 here:
%   up = 4 gives Fs/2 = 64 GHz, and up = 2 (the main scripts) only 32 GHz.
% Rule 2: foff must be a multiple of the bin spacing Fs/(datasize*up) (see freqoff).
assert(Fs/2 >= abs(foff) + baudrate/2, 'Fs is too small for foff: use a larger up');
[signal, data, data_mod] = TL_QAM(datasize, up, Hrcos, 0, 4);  % 16QAM target, 0 dBm
[xt, ~, ~] = TL_QAM(datasize, up, Hrcos, xt_ratio_dB, 4);  % interferer: other data
P_noise = mean(abs(signal).^2)*up/10^(snr_xt_dB/10);  % noise power in Fs [W]
noise = sqrt(P_noise/2)*(randn(datasize*up, 1) + 1i*randn(datasize*up, 1));
xt_on = [0 1 1];  % case 1: no interferer, cases 2 and 3: interferer added
xt_foff = [0 foff 0];  % frequency offset of the interferer in each case [Hz]
BER_xt = zeros(1, 3);
for c = 1:3
    rx = signal + noise + xt_on(c)*freqoff(xt, xt_foff(c), Fs);
    rx = apply_filter(rx, H, 1);  % the receive filter keeps -16 GHz to +16 GHz
    y = adequalizet(rx, 16, Morder, 1/256, data_mod(1:training_num), up);
    BER_xt(c) = measure_BER_QAM(y(training_num+1:end), data(4*training_num+1:end), 4);
end
fprintf('16QAM, SNR %.0f dB, interferer/target power %.0f dB\n', snr_xt_dB, xt_ratio_dB);
fprintf('  no interferer          : BER = %.3e\n', BER_xt(1));
fprintf('  interferer at %+3.0f GHz  : BER = %.3e\n', foff/1e9, BER_xt(2));
fprintf('  interferer at   0 GHz  : BER = %.3e\n', BER_xt(3));

%% 6. Self-checks
assert(all(abs(log10(BER_sim(1, :)./BER_th)) < 0.1), ...
    'the simulated BER of 16QAM is not within 0.1 decades of the theory');
fprintf('Self-check 1 passed: BER of 16QAM = theory within 0.1 decades\n');
assert(abs(snr_req_sim(1) - snr_req_th(2)) < 0.3, ...
    'the required SNR of 16QAM differs from the theory by 0.3 dB or more');
fprintf('Self-check 2 passed: required SNR of 16QAM = theory within 0.3 dB\n');
if abs(foff) >= baudrate  % the two spectra (each baudrate wide) do not overlap
    assert(abs(BER_xt(2) - BER_xt(1)) < 0.01*BER_xt(1), ...
        'an interferer outside the receive filter must not change the BER');
    fprintf('Self-check 3 passed: interferer outside the receive filter = same BER\n');
else
    fprintf('Self-check 3 skipped: the interferer overlaps the band of the target\n');
end
assert(BER_xt(3) > BER_xt(1), 'an interferer on the same wavelength must raise the BER');
fprintf('Self-check 4 passed: interferer on the same wavelength = higher BER\n');

%% 7. Figure
figure; semilogy(snr_th_dB, BER_th_curve, 'k-'); hold on;
semilogy(snr_dB_ary(1, :), BER_sim(1, :), 'bo', 'LineWidth', 1.2);
semilogy(snr_dB_ary(2, :), BER_sim(2, :), 'rs', 'LineWidth', 1.2);
semilogy([10 19], [BER_limit BER_limit], 'k--');
semilogy(snr_xt_dB, BER_xt(2), 'mx', 'MarkerSize', 12, 'LineWidth', 1.5);
semilogy(snr_xt_dB, BER_xt(3), 'm^', 'MarkerSize', 8, 'LineWidth', 1.5);
grid on; axis([10 19 1e-3 1]);
xlabel('SNR in the signal bandwidth [dB]'); ylabel('BER');
title('BER of the simulated receiver in white Gaussian noise');
legend('16QAM theory', '16QAM simulation', '32QAM simulation', 'FEC limit', ...
    sprintf('16QAM + interferer at %+.0f GHz', foff/1e9), '16QAM + interferer at 0 GHz');
