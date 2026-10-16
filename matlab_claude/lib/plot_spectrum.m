function plot_spectrum(x, Fs)
%PLOT_SPECTRUM  Plot the power spectrum of a signal in a new figure.
%
%   plot_spectrum(x, Fs)
%
%   Inputs
%     x   : signal, one signal per column [sqrt(W)] (one curve per column)
%     Fs  : sampling frequency [Hz]
%   Outputs
%     none (a new figure is opened)
%
%   Legacy: myfft.m (rewritten).
%   Legacy axis labels were fixed numbers; this version uses the real frequency axis.
%   Note: horizontal axis = frequency of each FFT bin [GHz] (freq_axis).
%   Note: 0 GHz is the center of the simulated band.
%   Note: vertical axis = power of each FFT bin [dB]; 0 dB = strongest bin of all columns.
%   Note: the vertical axis shows -80 dB to +5 dB; call ylim afterwards to change it.
%   Note: the spectrum of random data is not smooth; each bin varies by several dB.

if size(x, 1) == 1 && size(x, 2) > 1
    error('plot_spectrum: x is a row vector. Signals must be column vectors.');
end

N = size(x, 1);  % number of samples
f = freq_axis(N, Fs);  % exact FFT bin frequencies [Hz], N x 1

X = fftshift(fft(x, [], 1), 1);  % spectrum of every column, 0 Hz in the middle
P = abs(X).^2;  % power of every bin (arbitrary unit)
Pmax = max(P(:));  % strongest bin of all columns
if Pmax == 0
    error('plot_spectrum: x is all zero, there is no spectrum to plot.');
end
P_dB = 10*log10(P / Pmax);  % 0 dB = strongest bin

figure;
plot(f/1e9, P_dB);
grid on;
xlim([-Fs/2, Fs/2]/1e9);
ylim([-80, 5]);
xlabel('Frequency [GHz]');
ylabel('Power spectrum [dB, relative to the maximum]');
title('Power spectrum');
end
