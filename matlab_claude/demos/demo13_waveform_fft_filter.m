%% demo13_waveform_fft_filter - From QAM symbols to a waveform that has a spectrum
% Page: docs/13_waveform_fft_filter.html
% In the practice chapters a QAM signal had one sample per symbol. Here it has up
% samples per symbol (up = oversampling rate). It is a waveform, and it has a spectrum.
%
% What this script shows
%   - Fs = up*baudrate is the width of the simulated band.
%   - The spectrum has one value (bin) every Fs/nsamp. nsamp = number of samples.
%   - TL_QAM makes the waveform: bits -> symbols -> pulse shaping -> power.
%   - Pulse shaping = zero insertion, then the spectrum is multiplied by a mask.
%   - The samples at the symbol instants are the transmitted symbols times one factor.
%   - For rolloff = 0 the waveform occupies exactly the bandwidth baudrate.
%
% How to use this file
%   1. Run setup_path once (in the folder "matlab"). Then run this file (F5).
%   2. Change ONE parameter of section 1 (up, mod_flag or rolloff) and run again.

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['demo13_waveform_fft_filter: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters
datasize = 4000;  % number of symbols
mod_flag = 4;  % bits per symbol: 2 = QPSK, 4 = 16QAM, 5 = 32QAM, 6 = 64QAM
up = 4;  % oversampling rate (samples per symbol); the main scripts use 2: see section 7
baudrate = 24e9;  % symbol rate [Hz]
rolloff = 0;  % roll-off factor of the Nyquist pulse (0 = rectangular spectrum)
pin = 0;  % mean optical power of the waveform [dBm]
nshow = 16;  % number of symbols shown in the waveform plot

%% 2. Sampling frequency and frequency axis
Fs = up*baudrate;  % sampling frequency = width of the simulated band [Hz]
nsamp = datasize*up;  % number of samples of the waveform
df = Fs/nsamp;  % spacing of the FFT bins [Hz]
f = freq_axis(nsamp, Fs);  % frequency of every FFT bin [Hz], nsamp x 1
fprintf('Samples         : %d symbols x %d samples per symbol = %d samples\n', ...
    datasize, up, nsamp);
fprintf('Simulated band  : %+.3f GHz to %+.3f GHz (Fs = %.0f GHz)\n', ...
    f(1)/1e9, f(end)/1e9, Fs/1e9);
fprintf('Bin spacing     : Fs/nsamp = %.3f MHz\n', df/1e6);

%% 3. Transmitter of the library: bits -> symbols -> pulse shaping -> power
Hrcos = rcosfilter(nsamp, baudrate, Fs, rolloff);  % transmit mask (Nyquist)
[signal, data, data_mod] = TL_QAM(datasize, up, Hrcos, pin, mod_flag);
fprintf('Transmitter     : %d bits -> %d symbols (%d-QAM) -> %d samples\n', ...
    length(data), length(data_mod), 2^mod_flag, length(signal));
fprintf('First symbol    : bits');
fprintf(' %d', data(1:mod_flag));  % the first mod_flag bits make the first symbol
fprintf(' -> point %+d%+di\n', real(data_mod(1)), imag(data_mod(1)));
fprintf('Mean power      : %.4f mW (pin = %.1f dBm)\n', mean(abs(signal).^2)*1e3, pin);

%% 4. The same pulse shaping by hand: zero insertion, FFT, mask, inverse FFT
expanded = zeros(nsamp, 1);  % nsamp samples, all zero
expanded(1:up:end) = data_mod;  % symbol k goes to sample 1 + (k-1)*up (zero insertion)
X = fftshift(fft(expanded));  % spectrum with 0 Hz in the middle, in the order of f
Y = Hrcos .* X;  % the filter: every bin is multiplied by the mask
shaped = ifft(ifftshift(Y));  % back to the time domain
by_hand = set_signal_power(shaped, pin);  % same mean power as signal [dBm]
err_hand = max(abs(by_hand - signal));  % largest difference [sqrt(W)]
assert(err_hand < 1e-12, 'the pulse shaping by hand differs from the output of TL_QAM');
fprintf('Self-check 1 passed: pulse shaping by hand = TL_QAM (difference %.1e)\n', ...
    err_hand);

%% 5. Samples at the symbol instants
% Symbol k sits on sample 1 + (k-1)*up. The transmitter scaled the waveform to
% the power pin, so a sample there is the symbol times one real factor (scale).
sym_inst = signal(1:up:end);  % samples at the symbol instants [sqrt(W)]
scale = sqrt(mean(abs(sym_inst).^2)/mean(abs(data_mod).^2));  % one grid unit [sqrt(W)]
fprintf('Symbol instants : transmitted symbol -> sample/scale (scale = %.4e)\n', scale);
for k = 1:3
    fprintf('  symbol %d      : %+d%+di -> %+.9f%+.9fi\n', k, real(data_mod(k)), ...
        imag(data_mod(k)), real(sym_inst(k))/scale, imag(sym_inst(k))/scale);
end
err_sym = max(abs(sym_inst/scale - data_mod));  % largest error [grid units]
assert(err_sym < 1e-9, 'the samples at the symbol instants are not the symbols');
fprintf('Self-check 2 passed: samples at the symbol instants = symbols ');
fprintf('(largest error %.1e)\n', err_sym);

%% 6. Occupied bandwidth
S = fftshift(fft(signal));  % spectrum of the waveform, 0 Hz in the middle
P = abs(S).^2;  % power of every FFT bin (arbitrary unit)
occupied = P > 1e-24*max(P);  % true for a bin with power (the rest: rounding errors)
bw_occupied = sum(occupied)*df;  % occupied bandwidth [Hz]
bw_expected = baudrate*(1 + rolloff);  % width of the transmit mask [Hz]
fprintf('Occupied band   : %+.3f GHz to %+.3f GHz\n', min(f(occupied))/1e9, ...
    max(f(occupied))/1e9);
fprintf('Occupied width  : %d bins x %.3f MHz = %.3f GHz\n', sum(occupied), ...
    df/1e6, bw_occupied/1e9);
assert(abs(bw_occupied - bw_expected) <= 2*df, ...
    'the occupied width differs from baudrate*(1 + rolloff) by more than 2 bins');
fprintf('Self-check 3 passed: occupied width = baudrate*(1 + rolloff) = %.3f GHz ', ...
    bw_expected/1e9);
fprintf('(within 2 bins)\n');

%% 7. Figure: spectrum (top) and waveform (bottom)
plot_spectrum([expanded, shaped], Fs);  % new figure; column 1 = before, 2 = after the mask
set(gcf, 'Position', [100, 60, 800, 660]);  % a taller figure for two plots
subplot(2, 1, 1, gca);  % move the axes of plot_spectrum to the upper half
hold on;
plot([-1, -1]*bw_expected/2e9, [-80, 5], 'k--');  % lower edge of the mask
plot([1, 1]*bw_expected/2e9, [-80, 5], 'k--');  % upper edge of the mask
title('Power spectrum before and after the transmit mask');
legend('after zero insertion', 'after the mask (waveform)', 'edges of the mask', ...
    'Location', 'south');

subplot(2, 1, 2);
% This plot is the reason for up = 4: it shows 3 samples between two symbol instants.
% With up = 2 (the main scripts) there is only 1: the shape of the waveform cannot be seen.
t = (0:nsamp-1).'/up;  % time of every sample [symbol periods]; symbol k is at k-1
show = 1:nshow*up;  % samples of the first nshow symbols
plot(t(show), real(signal(show))/scale, '.-');
hold on;
plot(0:nshow-1, real(data_mod(1:nshow)), 'ko');
grid on;
yticks(-9:2:9);  % grid lines on the levels of the constellation
xlabel('Time [symbol periods]');
ylabel('Real part of signal/scale [grid units]');
title('Waveform: the samples at the symbol instants are the symbols');
% The legend goes below the plot, so it cannot cover a part of the waveform.
legend('waveform samples', 'transmitted symbols', 'Location', 'southoutside', ...
    'Orientation', 'horizontal');
