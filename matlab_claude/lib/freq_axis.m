function f = freq_axis(N, Fs)
%FREQ_AXIS  Frequency of every FFT bin, in the order of fftshift(fft(x)).
%
%   f = freq_axis(N, Fs)
%
%   Inputs
%     N   : number of samples of the signal (positive integer)
%     Fs  : sampling frequency [Hz]
%   Outputs
%     f   : frequency of each bin of fftshift(fft(x)) [Hz], N x 1
%           even N: from -Fs/2 to +Fs/2 - Fs/N in steps of Fs/N
%           odd N : from -(Fs/2 - Fs/(2*N)) to +(Fs/2 - Fs/(2*N)) in steps of Fs/N
%
%   Legacy: none (new function).
%   Legacy filters built their own axis with the step Fs/(N-1); the true step is Fs/N.
%   Note: 0 Hz is element number floor(N/2) + 1.
%   Note: rcosfilter, nyquistfilter, gaussfilter and plot_spectrum use this axis.

if N < 1 || N ~= round(N)
    error('freq_axis: N must be a positive integer (number of samples).');
end

% bin number of each element; 0 = center of the simulated band
k = (-floor(N/2) : ceil(N/2)-1).';

% Multiply first, divide last.
% k*Fs is an exact number, so a bin on a band edge (for example Br/2) is exact.
% With k*(Fs/N) the rounding of Fs/N can push such a bin across the edge.
f = k * Fs / N;
end
