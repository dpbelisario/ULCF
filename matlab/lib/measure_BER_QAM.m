function BER = measure_BER_QAM(Rx_signal, original_data, bitsPerSymbol)
%MEASURE_BER_QAM  Bit error ratio of received QAM symbols against the transmitted bits.
%
%   BER = measure_BER_QAM(Rx_signal, original_data, bitsPerSymbol)
%
%   Inputs
%     Rx_signal      : received symbols (complex), one sample per symbol, n x 1
%                      They must have the scale of my_qammod (adequalizet output has it).
%     original_data  : transmitted bits (0 or 1), (n*bitsPerSymbol) x 1
%                      The first bit of each symbol is the most significant bit (MSB).
%     bitsPerSymbol  : bits per symbol: 2 (QPSK), 4 (16QAM), 5 (32QAM) or 6 (64QAM)
%   Outputs
%     BER            : number of wrong bits / number of compared bits (0 to 1)
%
%   Legacy: measure_BER_QAM.m (same name, same argument order).
%   The legacy name of the third argument suggested samples per symbol;
%   it is the number of bits per symbol.
%   Legacy used qamdemod and comm.ErrorRate (toolbox); this version counts the bits itself.
%   Note: steps = hard decision (my_qamdemod), symbol numbers -> bits, compare the bits.
%   Note: original_data is the second output of TL_QAM.
%   Note: do not count the symbols that were used to train the equalizer.
%   Example: Nt training symbols, y = output of adequalizet, data = bits from TL_QAM,
%            k = bitsPerSymbol:
%            BER = measure_BER_QAM(y(Nt+1:end), data(k*Nt+1:end), k);
%   Note: a BER value is reliable only if about 100 or more bit errors were counted.

if bitsPerSymbol ~= 2 && bitsPerSymbol ~= 4 && bitsPerSymbol ~= 5 && bitsPerSymbol ~= 6
    error('measure_BER_QAM: bitsPerSymbol must be 2, 4, 5 or 6.');
end
if size(Rx_signal, 2) ~= 1 || size(Rx_signal, 1) < 1
    error('measure_BER_QAM: Rx_signal must be a column vector (one sample per symbol).');
end

n = size(Rx_signal, 1);  % number of received symbols
if numel(original_data) ~= n * bitsPerSymbol
    error(['measure_BER_QAM: original_data must have ' num2str(n * bitsPerSymbol) ...
        ' bits (number of symbols x bitsPerSymbol), but it has ' ...
        num2str(numel(original_data)) '.']);
end

sym_num = my_qamdemod(Rx_signal, 2^bitsPerSymbol);  % hard decision, n x 1

% symbol numbers -> bits, most significant bit first
% Example for bitsPerSymbol = 4: symbol number 6 = 0*8 + 1*4 + 1*2 + 0*1 -> bits 0 1 1 0.
receivedData = zeros(bitsPerSymbol, n);  % one symbol per column, one bit per row
for b = 1:bitsPerSymbol
    weight = 2^(bitsPerSymbol - b);  % value of bit b (8, 4, 2, 1 for 4 bits)
    receivedData(b, :) = mod(floor(sym_num.' / weight), 2);
end
receivedData = receivedData(:);  % read column by column = symbol after symbol

BER = mean(receivedData ~= original_data(:));  % fraction of bits that differ
end
