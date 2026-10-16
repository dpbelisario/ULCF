function [signal, data, data_mod] = TL_QAM(datasize, up, H, Pin, bitsPerSymbol)
%TL_QAM  Transmitter: random bits -> QAM symbols -> pulse shaping -> optical power.
%
%   [signal, data, data_mod] = TL_QAM(datasize, up, H, Pin, bitsPerSymbol)
%
%   Inputs
%     datasize       : number of symbols
%     up             : oversampling rate = samples per symbol
%                      (sampling frequency Fs = up * symbol rate)
%     H              : pulse-shaping mask made by rcosfilter, (datasize*up) x 1
%     Pin            : mean optical power of the output signal [dBm]
%     bitsPerSymbol  : bits per symbol: 2 (QPSK), 4 (16QAM), 5 (32QAM) or 6 (64QAM)
%   Outputs
%     signal         : optical field of one polarization, (datasize*up) x 1 [sqrt(W)]
%     data           : transmitted bits (0 or 1), (datasize*bitsPerSymbol) x 1
%                      The first bit of each symbol is the most significant bit (MSB).
%     data_mod       : transmitted QAM symbols on the grid of my_qammod, datasize x 1
%
%   Legacy: TL_QAM.m (same name; the first four arguments are the same).
%   Legacy used its second argument for two things: samples per symbol AND bits per symbol.
%   The fifth argument bitsPerSymbol is new; now up can be chosen freely.
%   Legacy called qammod(data, M, 'InputType', 'bit'); the mapping here is the same.
%   Legacy returned symbol numbers instead of bits for 8QAM; 8QAM is not supported here.
%   Note: TL = tunable laser.
%   Note: the function stands for the laser and the IQ modulator of one polarization
%         of one wavelength channel.
%   Note: the bits come from randi. Call rng(seed) before, and a run can be repeated.
%   Note: every call makes new, independent data.
%   Note: call it once for the target signal and once for every interfering signal.
%   Note: keep data and data_mod of the target signal for the receiver:
%         data_mod trains the equalizer (adequalizet), data is for measure_BER_QAM.

if nargin < 5
    error('TL_QAM: five inputs are needed: datasize, up, H, Pin, bitsPerSymbol.');
end
if bitsPerSymbol ~= 2 && bitsPerSymbol ~= 4 && bitsPerSymbol ~= 5 && bitsPerSymbol ~= 6
    error('TL_QAM: bitsPerSymbol must be 2, 4, 5 or 6 (QPSK, 16QAM, 32QAM, 64QAM).');
end
if datasize < 1 || datasize ~= round(datasize)
    error('TL_QAM: datasize must be a positive integer (number of symbols).');
end

% random bits; the bitsPerSymbol bits of one symbol follow each other
data = randi([0 1], datasize*bitsPerSymbol, 1);

% bits -> symbol numbers 0 ... M-1; the first bit of each symbol is the MSB
% Example for bitsPerSymbol = 4: bits 0 1 1 0 -> 0*8 + 1*4 + 1*2 + 0*1 = symbol number 6.
bits = reshape(data, bitsPerSymbol, datasize);  % one symbol per column, one bit per row
sym_num = zeros(datasize, 1);
for b = 1:bitsPerSymbol
    weight = 2^(bitsPerSymbol - b);  % value of bit b (8, 4, 2, 1 for 4 bits)
    sym_num = sym_num + weight * bits(b, :).';
end

data_mod = my_qammod(sym_num, 2^bitsPerSymbol);  % symbol numbers -> QAM points
signal = apply_filter(data_mod, H, up);  % zero insertion and pulse shaping
signal = set_signal_power(signal, Pin);  % scale to the wanted mean power [dBm]
end
