function signal = apply_filter(dataIn, H, up)
%APPLY_FILTER  Insert zeros between the samples, then filter in the frequency domain.
%
%   signal = apply_filter(dataIn, H, up)
%
%   Inputs
%     dataIn  : samples to be filtered, one signal per column, n x M
%               (QAM symbols for pulse shaping, or an optical field [sqrt(W)])
%     H       : amplitude mask in the order of fftshift(fft(x)), (up*n) x 1
%               (made by rcosfilter, nyquistfilter or gaussfilter)
%     up      : oversampling rate = output samples per input sample
%               (for pulse shaping: the number of samples per symbol)
%               up = 1 means plain filtering without zero insertion.
%   Outputs
%     signal  : filtered signal, (up*n) x M
%
%   Legacy: apply_filter.m (same name, same argument order).
%   Legacy called the second argument "filter", which hides a MATLAB function.
%   Legacy used upsample (toolbox function); this version uses plain indexing.
%   Note: pulse shaping = put up-1 zeros after every symbol, then apply the mask H.
%   Note: the amplitude is NOT re-scaled (as legacy).
%   Note: after a Nyquist mask the samples 1, 1+up, 1+2*up, ... are the symbols / up.
%   Note: set the power afterwards with set_signal_power.
%   Note: the FFT treats the block as periodic, so the filter is circular.

[n, M] = size(dataIn);
N = up * n;  % number of samples after zero insertion

if n == 1 && M > 1
    error('apply_filter: dataIn is a row vector. Signals must be column vectors.');
end
if up < 1 || up ~= round(up)
    error('apply_filter: up must be a positive integer.');
end
if size(H, 1) ~= N || size(H, 2) ~= 1
    error(['apply_filter: H must be a column vector with up*size(dataIn,1) = ' ...
        num2str(N) ' elements, but its size is ' num2str(size(H, 1)) ' x ' ...
        num2str(size(H, 2)) '.']);
end

% zero insertion: sample k of dataIn goes to row 1 + (k-1)*up
expanded = zeros(N, M);
expanded(1:up:end, :) = dataIn;

% multiply the spectrum of every column by the mask
spectrum = fftshift(fft(expanded, [], 1), 1);  % 0 Hz in the middle, like H
spectrum = H .* spectrum;  % H (N x 1) acts on every column
signal = ifft(ifftshift(spectrum, 1), [], 1);  % back to the time domain
end
