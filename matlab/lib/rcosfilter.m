function Hc = rcosfilter(N, Br, fsam, rolloff)
%RCOSFILTER  Raised-cosine (Nyquist) amplitude mask for pulse shaping.
%
%   Hc = rcosfilter(N, Br, fsam, rolloff)
%
%   Inputs
%     N        : number of samples of the signal (= number of symbols * up,
%                up = oversampling rate)
%     Br       : symbol rate (baud rate) [Hz]
%     fsam     : sampling frequency [Hz] (= up * Br)
%     rolloff  : roll-off factor, 0 to 1 (0 = rectangular spectrum of width Br)
%   Outputs
%     Hc       : amplitude mask in the order of fftshift(fft(x)), N x 1, values 0 to 1
%                Use it with apply_filter.
%
%   Legacy: rcosfilter.m (same name, same arguments).
%   Legacy used the rule abs(f) < Br/2 on a frequency axis with the step fsam/(N-1).
%   For rolloff = 0 and an even number of symbols it passed the same bins as this version.
%   For an odd number of symbols and an even up it lost one bin; this version does not.
%   Note: this is the FULL raised cosine, not the root raised cosine.
%   Note: the receiver is a brick-wall filter of width Br*(1+rolloff) (nyquistfilter).
%   Note: transmit mask and receive filter are a matched pair only for rolloff = 0.
%   Note: for rolloff > 0 there is still no inter-symbol interference,
%         but the receiver passes more noise than a matched filter would.
%   Note: keep rolloff = 0 unless you study the roll-off itself.
%   Note: rolloff = 0 is a brick wall with the half-open rule -Br/2 <= f < Br/2.
%   Note: then exactly one bin per symbol passes; nyquistfilter uses the same rule.
%   Note: the frequency axis is freq_axis(N, fsam) (the exact FFT bins).

if rolloff < 0 || rolloff > 1
    error('rcosfilter: rolloff must be between 0 and 1.');
end

f = freq_axis(N, fsam);  % exact FFT bin frequencies [Hz], N x 1
Hc = zeros(N, 1);  % start with 0 (stop) everywhere

if rolloff == 0
    % Brick wall of width Br.
    % The bins at -Br/2 and +Br/2 are Br apart: they carry the same symbol information.
    % Exactly one of them must pass: -Br/2 passes, +Br/2 does not.
    % tol keeps a bin that lies on an edge on the correct side despite rounding.
    tol = 1e-6 * fsam / N;  % one millionth of the bin spacing [Hz]
    Hc(f >= -Br/2 - tol & f < Br/2 - tol) = 1;
else
    fa = abs(f);  % the mask is symmetric around 0 Hz
    f_flat = (1 - rolloff) * Br/2;  % end of the flat top [Hz]
    f_stop = (1 + rolloff) * Br/2;  % end of the cosine slope [Hz]
    Hc(fa < f_flat) = 1;  % flat top
    slope = (fa >= f_flat) & (fa <= f_stop);  % bins on the cosine slope
    Hc(slope) = 0.5*(1 - sin(pi/(2*rolloff)*(2*fa(slope)/Br - 1)));
end
end
