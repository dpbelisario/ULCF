function [y, offset] = freqoff(x, foff, fsam)
%FREQOFF  Shift the spectrum of a signal by a frequency offset.
%
%   [y, offset] = freqoff(x, foff, fsam)
%
%   Inputs
%     x       : optical field, one signal per column, L x M [sqrt(W)]
%     foff    : frequency offset [Hz]; positive = towards higher frequency
%               foff must be a multiple of the bin spacing fsam/L
%               abs(foff) must be smaller than fsam/2
%     fsam    : sampling frequency [Hz]
%   Outputs
%     y       : shifted field, L x M [sqrt(W)] (same power as x)
%     offset  : phase that was added to each sample [rad], L x 1
%
%   Legacy: freqoff.m (same name, same arguments).
%   Legacy returned a row vector unchanged, without a warning; now it is an error.
%   Note: y(k) = x(k) * exp(1i*2*pi*foff*(k-1)/fsam).
%   Note: the spectrum moves by foff*L/fsam bins.
%   Note: use it to put an interfering signal on another wavelength channel.
%   Note: the filters use the FFT, so the block of L samples is periodic.
%   Note: if foff is not a multiple of fsam/L, the phase jumps where the block repeats.
%   Note: that jump spreads power over all frequencies, so it is an error here.
%   Note: a valid value near foff is round(foff*L/fsam)*fsam/L.
%   Note: the simulated band is only from -fsam/2 to +fsam/2.
%   Note: the caller must check abs(foff) + (signal bandwidth)/2 <= fsam/2.
%   Note: a part that leaves the band on one side comes back on the other side.

L = size(x, 1);  % number of samples

if L == 1 && size(x, 2) > 1
    error('freqoff: x is a row vector. Signals must be column vectors.');
end
if abs(foff) >= fsam/2
    error('freqoff: abs(foff) must be smaller than fsam/2 (edge of the simulated band).');
end
shift_bins = foff * L / fsam;  % offset counted in FFT bins
if abs(shift_bins - round(shift_bins)) > 1e-6
    error(['freqoff: foff must be a multiple of the bin spacing fsam/L = ' ...
        num2str(fsam/L) ' Hz. Use round(foff*L/fsam)*fsam/L.']);
end

% phase of each sample [rad], L x 1 (same order of operations as the legacy code)
offset = ((0:L-1).' * foff * 2*pi) / fsam;
y = x .* exp(1i*offset);  % the same phase ramp for every column
end
