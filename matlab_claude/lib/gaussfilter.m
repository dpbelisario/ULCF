function H = gaussfilter(N, shift, Fs, FWHM, er_dB, m)
%GAUSSFILTER  Amplitude mask of a (super-)Gaussian optical band-pass filter.
%
%   H = gaussfilter(N, shift, Fs, FWHM, er_dB, m)
%
%   Inputs
%     N      : number of samples of the signal
%     shift  : center frequency of the passband on the baseband axis [Hz]
%              0 = passband centered on the signal, +5e9 = center 5 GHz above it
%     Fs     : sampling frequency [Hz]
%     FWHM   : full width at half maximum of the POWER response [Hz] (3-dB width)
%     er_dB  : extinction ratio [dB], must be >= 0
%              The power response never falls below -er_dB. Inf = no floor.
%     m      : order (1 = Gaussian; 2, 3, ... = super-Gaussian with a flatter top)
%   Outputs
%     H      : amplitude mask in the order of fftshift(fft(x)), N x 1
%              1 at the passband center. Use it with apply_filter (or call awg).
%
%   Legacy: gaussfilter.m (same name, same arguments).
%   Note: amplitude response H(f) = exp(-(abs(f - shift)*a)^(2*m)).
%   Note: power response abs(H(f))^2 = exp(-2*(abs(f - shift)*a)^(2*m)).
%   Note: a = 2/FWHM * (log(2)/2)^(1/(2*m)).
%   Note: at abs(f - shift) = FWHM/2 the power response is exactly 1/2.
%   Note: far from the center the mask stays at the floor sqrt(10^(-er_dB/10)).
%   Note: for FWHM = 66.6e9, er_dB = 32, m = 1 the floor starts 108.6 GHz from the center.
%   Note: if the simulated band is narrower than that, er_dB has no effect.
%   Note: a negative er_dB is an error (in the legacy code it made a flat amplifier).
%   Note: the frequency axis is freq_axis(N, Fs) (the exact FFT bins).

if er_dB < 0
    error('gaussfilter: er_dB is an extinction ratio in dB and must be >= 0.');
end

f = freq_axis(N, Fs);  % exact FFT bin frequencies [Hz], N x 1

er = sqrt(10^(-er_dB/10));  % floor of the AMPLITUDE response (power: -er_dB)
a = 2/FWHM * (log(2)/2)^(1/(2*m));  % makes the power response 1/2 at FWHM/2 [1/Hz]

H = exp(-(abs(f - shift)*a).^(2*m));  % (super-)Gaussian amplitude response
H = max(er, H);  % never below the floor
end
