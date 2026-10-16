function H = nyquistfilter(data_length, center_fleq, Fs, width)
%NYQUISTFILTER  Ideal rectangular (brick-wall) band-pass mask.
%
%   H = nyquistfilter(data_length, center_fleq, Fs, width)
%
%   Inputs
%     data_length  : number of samples of the signal
%     center_fleq  : center frequency of the passband [Hz] (0 = signal center)
%                    (the legacy spelling of this name is kept)
%     Fs           : sampling frequency [Hz]
%     width        : full width of the passband [Hz]
%   Outputs
%     H            : mask in the order of fftshift(fft(x)), data_length x 1
%                    1 = pass, 0 = stop. Use it with apply_filter.
%
%   Legacy: nyquistfilter.m (same name, same arguments).
%   Legacy returned a logical vector; this version returns double.
%   Legacy used the rule abs(f) < width/2 on a frequency axis with the step Fs/(N-1),
%   N = data_length. With width = symbol rate and an even number of symbols it passed
%   the same bins as this version. For an odd number of symbols and an even oversampling
%   rate (samples per symbol) it lost one bin; this version does not.
%   Note: this is the receive filter of the ideal coherent receiver.
%   Example: H = nyquistfilter(length(signal), 0, Fs, baudrate*(1+rolloff));
%   Note: half-open rule, measured from the passband center: -width/2 <= f < width/2.
%   Note: nyquistfilter(N, 0, Fs, Br) is equal to rcosfilter(N, Br, Fs, 0).
%   Note: the frequency axis is freq_axis(data_length, Fs) (the exact FFT bins).

f = freq_axis(data_length, Fs);  % exact FFT bin frequencies [Hz]
fc = f - center_fleq;  % frequency measured from the passband center [Hz]

% tol keeps a bin that lies on an edge on the correct side despite rounding.
tol = 1e-6 * Fs / data_length;  % one millionth of the bin spacing [Hz]
H = double(fc >= -width/2 - tol & fc < width/2 - tol);
end
