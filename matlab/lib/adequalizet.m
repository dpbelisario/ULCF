function y = adequalizet(x, m, M, astep, d, up)
%ADEQUALIZET  Adaptive equalizer trained with known symbols (data-aided NLMS).
%
%   y = adequalizet(x, m, M, astep, d, up)
%
%   Inputs
%     x      : received signal after the receive filter, column vector (any scale)
%              up samples per symbol; samples 1, 1+up, 1+2*up, ... are the symbol instants
%     m      : number of constellation points: 4, 16, 32 or 64
%     M      : filter order, an even number; the filter has M+1 taps (16 is enough here)
%     astep  : NOT USED. It is kept so that the legacy argument order stays the same.
%              The step size follows the fixed schedule that is written below.
%     d      : known transmitted symbols for the training, Nt x 1
%              (the first Nt elements of data_mod from TL_QAM)
%     up     : oversampling rate = samples per symbol of x (positive integer)
%   Outputs
%     y      : equalized symbols, one sample per symbol, N x 1 with N = floor(length(x)/up)
%              on the scale of my_qammod (ready for measure_BER_QAM); see the last notes
%
%   Legacy: adequalizet.m (same name, same arguments, same algorithm).
%   Legacy took the reference power from a table without 64QAM;
%   this version computes it from the constellation of my_qammod.
%   Legacy normalized x by mean(abs(x)); this version uses the RMS value.
%   This changes only the starting point of the training.
%   Legacy kept the taps of every symbol in memory (1.2 GB for M = 512 and 1.5e5 symbols);
%   this version keeps only the current taps.
%   Legacy ran a decision-directed part after the training, but with step size 0.
%   It never changed the taps, so it was removed (symbol_decision.m is not needed).
%   Note: the equalizer is a filter with M+1 taps c. Output y(n) = sum of c .* samples.
%   Note: start = center tap 1, all other taps 0 (the signal passes unchanged).
%   Note: training (symbols 1 ... Nt-1): e = d(n) - y(n) is the error of the output.
%   Note: the taps move against the error: c = c + pstep * e * conj(uu) / (power of uu).
%   Note: dividing by the power of uu makes it the NORMALISED least-mean-square method.
%   Note: pstep = 1/2, 1/4, 1/8, 1/16, 1/32, 1/64, 1/128 as the training goes on.
%   Note: after the training the taps are frozen. This is correct for a channel
%         that does not change in time.
%   Note: the first Nt outputs were made while the taps were still moving.
%   Note: count the BER only on y(Nt+1:end).
%   Note: without noise y lies exactly on the points of my_qammod.
%   Note: with noise the trained taps minimize the mean square error e. Then y is
%         SMALLER than the points of my_qammod by the factor SNR/(SNR + 1)
%         (SNR as a linear number; the factor is 0.96 for an SNR of 14 dB).
%   Note: the decision of my_qamdemod is made on this smaller constellation. So the BER
%         is a few percent above the formula for Gaussian noise at the same SNR
%         (16QAM near BER = 1e-2: about 6 percent, like 0.1 dB less SNR).
%         The legacy code behaves in the same way.
%   Note: the letters m and M are the legacy names: m = constellation points, M = order.

if size(x, 2) ~= 1
    error('adequalizet: x must be a column vector.');
end
if m ~= 4 && m ~= 16 && m ~= 32 && m ~= 64
    error('adequalizet: m (number of constellation points) must be 4, 16, 32 or 64.');
end
if M < 0 || mod(M, 2) ~= 0
    error('adequalizet: the filter order M must be an even number (0, 2, 4, ...).');
end
if up < 1 || up ~= round(up)
    error('adequalizet: up must be a positive integer (samples per symbol).');
end

N = floor(length(x)/up);  % number of symbols in x = number of outputs
Nt = length(d);  % number of training symbols

% mean power of the constellation: 2, 10, 20, 42 for m = 4, 16, 32, 64
aveqam = mean(abs(my_qammod((0:m-1).', m)).^2);

% scale x so that its mean power is the mean power of the constellation
x_rms = sqrt(mean(abs(x).^2));  % root-mean-square amplitude of x
if x_rms == 0
    error('adequalizet: x is all zero.');
end
x = x*sqrt(aveqam)/x_rms;

% M/2 zeros before and after, so that the window of M+1 samples always fits
x = [zeros(M/2, 1); x; zeros(M/2, 1)];

% initialization
c = zeros(M+1, 1);  % current taps (filter coefficients)
c(M/2+1) = 1;  % center tap 1: at the start the filter changes nothing
y = zeros(N, 1);

% filter
for n = 1:N

    % window: the M+1 samples around symbol instant n (the symbol sample is in the center)
    uu = x(1+up*(n-1):1+up*(n-1)+M);

    y(n) = c.'*uu;  % filter output = equalized symbol n

    % step size: large at first (fast), then smaller and smaller (accurate)
    if n < Nt/16
        pstep = 1/2^1;
    elseif n < Nt/8
        pstep = 1/2^2;
    elseif n < Nt/4
        pstep = 1/2^3;
    elseif n < Nt*3/8
        pstep = 1/2^4;
    elseif n < Nt/2
        pstep = 1/2^5;
    elseif n < Nt*3/4
        pstep = 1/2^6;
    elseif n < Nt
        pstep = 1/2^7;
    else
        pstep = 0;  % the training is over: the taps stay as they are
    end

    if pstep > 0
        e = d(n) - y(n);  % error against the known symbol
        nom = sum(uu.*conj(uu)) + 0.001;  % power in the window (0.001 avoids 0/0)
        c = c + pstep/nom*e*conj(uu);  % move the taps against the error
    end

end
end
