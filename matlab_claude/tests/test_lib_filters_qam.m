%% test_lib_filters_qam - Self-test of the filter, QAM and receiver functions of the library
% Tested functions: freq_axis, rcosfilter, nyquistfilter, apply_filter, gaussfilter, awg,
% freqoff, plot_spectrum, my_qammod, my_qamdemod, TL_QAM, measure_BER_QAM, adequalizet.
%
% How to run: run setup_path once, then type test_lib_filters_qam.
% Every check is an assert. If a check fails, MATLAB stops and prints the reason.
% If the line "test_lib_filters_qam: all passed" appears at the end, every check passed.

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['test_lib_filters_qam: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

baudrate = 24e9;  % symbol rate used in the checks [Hz]

%% 1. freq_axis: element k must be the frequency of bin k of fftshift(fft(x))
Fs = 96e9;  % sampling frequency [Hz]
for N = [16, 15]
    % 16 is an even number of samples, 15 is an odd number of samples
    f = freq_axis(N, Fs);
    assert(isequal(size(f), [N, 1]), 'freq_axis: the output must be an N x 1 column');
    assert(f(floor(N/2) + 1) == 0, 'freq_axis: element floor(N/2) + 1 must be 0 Hz');
    assert(max(abs(diff(f) - Fs/N)) < 1e-3, 'freq_axis: the step must be Fs/N');
    t = (0:N-1).' / Fs;  % time of every sample [s]
    for k = 1:N
        tone = exp(1i*2*pi*f(k)*t);  % wave with the frequency of element k
        spectrum = abs(fftshift(fft(tone)));  % must be N in bin k and 0 in all other bins
        assert(abs(spectrum(k) - N) < 1e-9 && sum(spectrum) - spectrum(k) < 1e-9, ...
            'freq_axis: a wave of frequency f(k) must fall into bin k of fftshift(fft(x))');
    end
end
f = freq_axis(16, Fs);
assert(f(1) == -Fs/2 && f(end) == Fs/2 - Fs/16, ...
    'freq_axis: for even N the axis must go from -Fs/2 to +Fs/2 - Fs/N');
f = freq_axis(15, Fs);
assert(abs(f(1) + f(end)) < 1e-3 && abs(f(end) - (Fs/2 - Fs/30)) < 1e-3, ...
    'freq_axis: for odd N the axis must be symmetric and end at Fs/2 - Fs/(2*N)');

msg = '';
try
    freq_axis(2.5, Fs);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'freq_axis:'), 'freq_axis: 2.5 samples must be an error');
fprintf('Check 1 passed: freq_axis (even and odd N)\n');

%% 2. rcosfilter and nyquistfilter: width and edges of the masks
nsym = 1000;  % number of symbols
up = 2;  % oversampling rate (samples per symbol)
Fs = up*baudrate;  % sampling frequency [Hz]
N = nsym*up;  % number of samples; the bin spacing Fs/N is 24 MHz
k0 = N/2 + 1;  % index of the 0 Hz bin (N is even)

% rolloff 0: brick wall of width baudrate = nsym bins
Hc = rcosfilter(N, baudrate, Fs, 0);
assert(isequal(size(Hc), [N, 1]), 'rcosfilter: the mask must be an N x 1 column');
assert(all(Hc == 0 | Hc == 1), 'rcosfilter: with rolloff 0 the mask must be 0 or 1');
assert(sum(Hc) == nsym, 'rcosfilter: with rolloff 0 exactly one bin per symbol must pass');
assert(all(Hc(k0 - nsym/2 : k0 + nsym/2 - 1) == 1), ...
    'rcosfilter: the bins from -baudrate/2 up to the bin before +baudrate/2 must pass');
assert(Hc(k0 - nsym/2) == 1 && Hc(k0 + nsym/2) == 0, ...
    'rcosfilter: the bin at -baudrate/2 must pass, the bin at +baudrate/2 must not');

% one bin per symbol also for odd numbers of symbols and other oversampling rates
for nsym_k = [1000, 999, 1001]
    for up_k = [2, 3, 4, 5]
        Hk = rcosfilter(nsym_k*up_k, baudrate, up_k*baudrate, 0);
        assert(sum(Hk) == nsym_k, ...
            'rcosfilter: with rolloff 0 one bin per symbol must pass for every length');
    end
end

% rolloff 0.2: flat top up to 9.6 GHz (400 bins), 1/2 at 12 GHz (500), 0 from 14.4 GHz (600)
rolloff = 0.2;
Hr = rcosfilter(N, baudrate, Fs, rolloff);
assert(all(Hr >= 0 & Hr <= 1), 'rcosfilter: the mask must stay between 0 and 1');
assert(max(abs(Hr(k0 - 400 : k0 + 400) - 1)) < 1e-12, ...
    'rcosfilter: the mask must be 1 up to (1 - rolloff)*baudrate/2');
assert(abs(Hr(k0 + 500) - 0.5) < 1e-12 && abs(Hr(k0 - 500) - 0.5) < 1e-12, ...
    'rcosfilter: the mask must be 1/2 at +baudrate/2 and at -baudrate/2');
assert(max(abs(Hr(k0 + 600 : N))) < 1e-12 && max(abs(Hr(1 : k0 - 600))) < 1e-12, ...
    'rcosfilter: the mask must be 0 from (1 + rolloff)*baudrate/2');
% Nyquist criterion: the mask plus its copy moved by baudrate (nsym bins) is flat.
% This is the reason why the symbols do not disturb each other.
edge = k0 + (400:600);  % bins on the upper slope
assert(max(abs(Hr(edge) + Hr(edge - nsym) - 1)) < 1e-12, ...
    'rcosfilter: the mask and its copy shifted by baudrate must add up to 1');

msg = '';
try
    rcosfilter(N, baudrate, Fs, 1.5);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'rcosfilter:'), 'rcosfilter: rolloff 1.5 must be an error');

% nyquistfilter: the receive brick wall
H = nyquistfilter(N, 0, Fs, baudrate);
assert(isequal(H, Hc), ...
    'nyquistfilter: width baudrate, center 0 must give the rcosfilter mask of rolloff 0');
H = nyquistfilter(N, 0, Fs, baudrate*(1 + rolloff));
assert(sum(H) == 1200, 'nyquistfilter: a width of 28.8 GHz must pass 1200 bins');
assert(all(H(Hr > 1e-12) == 1), ...
    'nyquistfilter: width baudrate*(1 + rolloff) must pass the whole raised cosine');
H = nyquistfilter(N, 12e9, Fs, baudrate);  % passband center moved by 12 GHz = 500 bins
assert(isequal(H, circshift(Hc, 500)), ...
    'nyquistfilter: a center frequency of +12 GHz must move the passband up by 500 bins');
fprintf('Check 2 passed: rcosfilter, nyquistfilter (one bin per symbol, edges)\n');

%% 3. apply_filter: zero insertion and filtering
d = (1:5).' + 1i*(5:-1:1).';  % five test samples
expanded = apply_filter(d, ones(15, 1), 3);  % a mask of ones: only the zero insertion acts
assert(isequal(size(expanded), [15, 1]), ...
    'apply_filter: 5 samples and up = 3 must give 15 samples');
assert(max(abs(expanded(1:3:end) - d)) < 1e-12, ...
    'apply_filter: input sample k must go to output row 1 + (k-1)*up');
assert(max(abs(expanded(2:3:end))) < 1e-12 && max(abs(expanded(3:3:end))) < 1e-12, ...
    'apply_filter: the rows between the input samples must be zero');

% a wave inside the passband passes unchanged, a wave outside is removed
t = (0:N-1).' / Fs;  % time of every sample [s]
tone_in = exp(1i*2*pi*6e9*t);  % 6 GHz: inside the band from -12 GHz to +12 GHz
tone_out = exp(1i*2*pi*18e9*t);  % 18 GHz: outside
y = apply_filter(tone_in + tone_out, Hc, 1);
assert(max(abs(y - tone_in)) < 1e-9, ...
    'apply_filter: the brick wall must pass the 6 GHz wave and remove the 18 GHz wave');

x = randn(N, 1) + 1i*randn(N, 1);  % white test signal
y = apply_filter(x, Hc, 1);
assert(max(abs(apply_filter(y, Hc, 1) - y)) < 1e-9, ...
    'apply_filter: filtering two times with a 0/1 mask must be the same as one time');
Y = apply_filter([x, 2*x], Hc, 1);  % two signals, one per column
assert(max(abs(Y(:, 1) - y)) < 1e-12 && max(abs(Y(:, 2) - 2*y)) < 1e-12, ...
    'apply_filter: every column must be filtered in the same way');

msg = '';
try
    apply_filter(x, ones(N + 1, 1), 1);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'apply_filter:'), ...
    'apply_filter: a mask of wrong length must be an error');
fprintf('Check 3 passed: apply_filter\n');

%% 4. gaussfilter and awg: 3-dB width, floor, center shift
N = 4000;  % number of samples
Fs = 400e9;  % a wide band, so that the floor of the filter is inside [Hz]
FWHM = 66.6e9;  % 3-dB width of the AWG passband [Hz]
er_dB = 32;  % extinction ratio [dB]
k0 = N/2 + 1;  % index of the 0 Hz bin
half = 333;  % FWHM/2 = 33.3 GHz = 333 bins (the bin spacing Fs/N is 0.1 GHz)

H = gaussfilter(N, 0, Fs, FWHM, er_dB, 1);
assert(isequal(size(H), [N, 1]), 'gaussfilter: the mask must be an N x 1 column');
assert(H(k0) == 1 && max(H) == 1, 'gaussfilter: the mask must be 1 at the passband center');
assert(abs(H(k0 + half)^2 - 0.5) < 1e-9 && abs(H(k0 - half)^2 - 0.5) < 1e-9, ...
    'gaussfilter: the power response must be 1/2 at FWHM/2 on both sides of the center');
assert(abs(20*log10(min(H)) + er_dB) < 1e-9 && abs(20*log10(H(1)) + er_dB) < 1e-9, ...
    'gaussfilter: far from the center the mask must stay er_dB below the peak');
H_inf = gaussfilter(N, 0, Fs, FWHM, Inf, 1);
assert(20*log10(min(H_inf)) < -100, 'gaussfilter: er_dB = Inf must give no floor');

shift = 28.5e9;  % 12.5 GHz + 16 GHz = 285 bins: the largest shift of the two-stage switch
Hs = gaussfilter(N, shift, Fs, FWHM, er_dB, 1);
[~, k_peak] = max(Hs);
assert(k_peak == k0 + 285, 'gaussfilter: the passband center must be at +shift');
assert(abs(Hs(k_peak + half)^2 - 0.5) < 1e-9 && abs(Hs(k_peak - half)^2 - 0.5) < 1e-9, ...
    'gaussfilter: a shifted passband must keep its 3-dB width');

H2 = gaussfilter(N, 0, Fs, FWHM, er_dB, 2);  % order 2: super-Gaussian
assert(abs(H2(k0 + half)^2 - 0.5) < 1e-9, 'gaussfilter: order 2 must keep the 3-dB width');
assert(H2(k0 + 100) > H(k0 + 100) && H2(k0 + 600) < H(k0 + 600), ...
    'gaussfilter: order 2 must have a flatter top and steeper edges than order 1');

msg = '';
try
    gaussfilter(N, 0, Fs, FWHM, -1, 1);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'gaussfilter:'), 'gaussfilter: a negative er_dB must be an error');

% awg = this mask and a flat loss. Test it with waves of one frequency and 0 dBm.
loss = 9;  % insertion loss of the AWG [dB]
t = (0:N-1).' / Fs;  % time of every sample [s]
tone = set_signal_power(exp(1i*2*pi*shift*t), 0);  % wave at the passband center
out = awg(tone, loss, shift, Fs, FWHM, er_dB, 1);
assert(abs(calc_signal_power(out) - (0 - loss)) < 1e-9, ...
    'awg: at the passband center the loss must be the insertion loss');
tone = set_signal_power(exp(1i*2*pi*(shift + FWHM/2)*t), 0);  % wave at the 3-dB point
out = awg(tone, loss, shift, Fs, FWHM, er_dB, 1);
assert(abs(calc_signal_power(out) - (0 - loss - 10*log10(2))) < 1e-9, ...
    'awg: at FWHM/2 from the center the loss must be 3.01 dB more');
tone = set_signal_power(exp(1i*2*pi*(shift - 150e9)*t), 0);  % wave far from the passband
out = awg(tone, loss, shift, Fs, FWHM, er_dB, 1);
assert(abs(calc_signal_power(out) - (0 - loss - er_dB)) < 1e-9, ...
    'awg: far from the passband the loss must be insertion loss + er_dB');
fprintf('Check 4 passed: gaussfilter, awg (3-dB width, floor %d dB, shift)\n', er_dB);

%% 5. freqoff: the spectrum must move by a whole number of bins
N = 64;  % number of samples
Fs = 64e9;  % sampling frequency [Hz]; the bin spacing Fs/N is 1 GHz
x = randn(N, 1) + 1i*randn(N, 1);  % any complex test signal

[y, offset] = freqoff(x, 5e9, Fs);  % +5 GHz = 5 bins towards higher frequency
assert(max(abs(fft(y) - circshift(fft(x), 5))) < 1e-9, ...
    'freqoff: +5 GHz must move the spectrum by 5 bins towards higher frequency');
assert(isequal(size(offset), [N, 1]) && offset(1) == 0, ...
    'freqoff: the phase ramp must be an N x 1 column that starts at 0');
assert(abs(mean(abs(y).^2) - mean(abs(x).^2)) < 1e-12, ...
    'freqoff: the power must not change');

y = freqoff(x, -3e9, Fs);
assert(max(abs(fft(y) - circshift(fft(x), -3))) < 1e-9, ...
    'freqoff: -3 GHz must move the spectrum by 3 bins towards lower frequency');
y = freqoff(freqoff(x, 5e9, Fs), -5e9, Fs);
assert(max(abs(y - x)) < 1e-12, 'freqoff: +5 GHz and then -5 GHz must give x again');
Y = freqoff([x, 2*x], 5e9, Fs);
assert(max(abs(Y(:, 2) - 2*Y(:, 1))) < 1e-12, ...
    'freqoff: every column must get the same shift');

msg = '';
try
    freqoff(x.', 5e9, Fs);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'freqoff:'), 'freqoff: a row vector must be an error');

msg = '';
try
    freqoff(x, Fs/2, Fs);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'freqoff:'), 'freqoff: an offset of Fs/2 must be an error');

msg = '';
try
    freqoff(x, 0.5e9, Fs);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'freqoff:'), 'freqoff: an offset of half a bin must be an error');
fprintf('Check 5 passed: freqoff (bin shift, errors)\n');

%% 6. plot_spectrum: one new figure, strongest bin at 0 dB
plot_spectrum(x, Fs);
assert(numel(findobj('Type', 'figure')) == 1, ...
    'plot_spectrum: exactly one new figure must be opened');
curve = findobj(gca, 'Type', 'line');  % the plotted curve
assert(abs(max(get(curve, 'YData'))) < 1e-9, ...
    'plot_spectrum: the strongest bin must be at 0 dB');
assert(max(abs(get(curve, 'XData').' - freq_axis(N, Fs)/1e9)) < 1e-9, ...
    'plot_spectrum: the horizontal axis must be freq_axis in GHz');
close all;
fprintf('Check 6 passed: plot_spectrum\n');

%% 7. my_qammod and my_qamdemod: constellations and decisions
M_list = [4, 16, 32, 64];  % supported numbers of constellation points
power_list = [2, 10, 20, 42];  % mean power of the points of each constellation
% mark = sum of (symbol number x point). It changes if two symbol numbers are exchanged.
% The four values were computed once with qammod of the Communications Toolbox.
mark_list = [4 - 2i, 128 - 32i, 704 - 88i, 4096 - 512i];
for q = 1:4
    Mary = M_list(q);
    sym_num = (0:Mary-1).';  % every symbol number
    c = my_qammod(sym_num, Mary);  % every constellation point
    assert(isequal(size(c), [Mary, 1]), ...
        'my_qammod: the output must have the size of the input');
    assert(all(mod(real(c), 2) == 1) && all(mod(imag(c), 2) == 1), ...
        'my_qammod: all points must lie on the grid of odd integers');
    assert(numel(unique(c)) == Mary, 'my_qammod: the points must all be different');
    assert(abs(mean(abs(c).^2) - power_list(q)) < 1e-12, ...
        'my_qammod: wrong mean power of the constellation');
    assert(sum(sym_num .* c) == mark_list(q), ...
        'my_qammod: the numbering of the points is not the numbering of qammod');
    assert(isequal(my_qamdemod(c, Mary), sym_num), ...
        'my_qamdemod(my_qammod(k, M), M) must return k for every symbol number');
    % a move shorter than 1 (half the distance between two points) keeps the decision
    moved = c + 0.9*exp(1i*2*pi*rand(Mary, 1));
    assert(isequal(my_qamdemod(moved, Mary), sym_num), ...
        'my_qamdemod: a sample closer than 1 to a point must be decided as this point');
end

% some points written out (the same values as qammod)
assert(my_qammod(0, 4) == -1 + 1i && my_qammod(3, 4) == 1 - 1i, ...
    'my_qammod: wrong QPSK point');
assert(my_qammod(0, 16) == -3 + 3i && my_qammod(10, 16) == 3 - 3i, ...
    'my_qammod: wrong 16QAM point');
assert(my_qammod(0, 32) == -3 + 5i && my_qammod(23, 32) == 5 - 1i, ...
    'my_qammod: wrong 32QAM point');
assert(my_qammod(0, 64) == -7 + 7i && my_qammod(63, 64) == 3 - 3i, ...
    'my_qammod: wrong 64QAM point');

% Gray mapping of the square constellations:
% two points at the smallest distance (2) must differ in exactly one bit.
% (32QAM is a cross constellation; a perfect Gray mapping does not exist for it.)
for Mary = [4, 16, 64]
    c = my_qammod((0:Mary-1).', Mary);
    for a = 0:Mary-2
        for b = a+1:Mary-1
            if abs(c(a+1) - c(b+1)) < 2.001
                n_diff = sum(dec2bin(bitxor(a, b)) == '1');  % number of bits that differ
                assert(n_diff == 1, ...
                    'my_qammod: neighboring points must differ in exactly one bit');
            end
        end
    end
end

% samples outside the constellation go to the closest point
assert(my_qamdemod(100 + 100i, 16) == my_qamdemod(3 + 3i, 16), ...
    'my_qamdemod: a sample far outside must be decided as the closest corner point');
% 32QAM has no point at 5 + 5i: the closest point is 5 + 3i or 3 + 5i
assert(my_qammod(my_qamdemod(5.2 + 4.8i, 32), 32) == 5 + 3i, ...
    'my_qamdemod: 5.2 + 4.8i must be decided as the 32QAM point 5 + 3i');
assert(my_qammod(my_qamdemod(4.8 + 5.2i, 32), 32) == 3 + 5i, ...
    'my_qamdemod: 4.8 + 5.2i must be decided as the 32QAM point 3 + 5i');

assert(isequal(size(my_qammod(0:15, 16)), [1, 16]), ...
    'my_qammod: a row of symbol numbers must give a row of points');
assert(isequal(size(my_qamdemod(ones(3, 2), 16)), [3, 2]), ...
    'my_qamdemod: the output must have the size of the input');

msg = '';
try
    my_qammod(0, 8);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'my_qammod:'), 'my_qammod: M = 8 must be an error');

msg = '';
try
    my_qammod(16, 16);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'my_qammod:'), ...
    'my_qammod: symbol number 16 of 16QAM must be an error');

msg = '';
try
    my_qamdemod(NaN, 16);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'my_qamdemod:'), 'my_qamdemod: NaN must be an error');
fprintf('Check 7 passed: my_qammod, my_qamdemod (4, 16, 32, 64 points)\n');

%% 8. TL_QAM and the ideal receiver without noise: the symbols must come back
bits_list = [2, 4, 5, 6];  % bits per symbol: QPSK, 16QAM, 32QAM, 64QAM
up_list = [2, 3, 4, 5];  % oversampling rate used with each format (four values on purpose)
nsym_list = [1000, 999, 1001, 1000];  % number of symbols (even and odd)
pin = -3;  % transmitter power of one polarization [dBm]
for q = 1:4
    bitsPerSymbol = bits_list(q);
    up = up_list(q);
    nsym = nsym_list(q);
    Fs = up*baudrate;  % sampling frequency [Hz]
    Hrcos = rcosfilter(nsym*up, baudrate, Fs, 0);  % transmit mask
    [signal, data, data_mod] = TL_QAM(nsym, up, Hrcos, pin, bitsPerSymbol);
    assert(isequal(size(signal), [nsym*up, 1]), 'TL_QAM: wrong size of signal');
    assert(isequal(size(data), [nsym*bitsPerSymbol, 1]), 'TL_QAM: wrong size of data');
    assert(isequal(size(data_mod), [nsym, 1]), 'TL_QAM: wrong size of data_mod');
    assert(all(data == 0 | data == 1), 'TL_QAM: data must contain only 0 and 1');
    assert(abs(calc_signal_power(signal) - pin) < 1e-9, ...
        'TL_QAM: the power of signal must be Pin');

    % bits -> symbol numbers: the first bit of each symbol is the most significant bit
    sym_num = zeros(nsym, 1);
    for b = 1:bitsPerSymbol
        sym_num = 2*sym_num + data(b:bitsPerSymbol:end);  % append bit b of every symbol
    end
    assert(isequal(data_mod, my_qammod(sym_num, 2^bitsPerSymbol)), ...
        'TL_QAM: data_mod must be my_qammod of the bits, most significant bit first');

    % ideal receiver: brick-wall filter, then one sample per symbol
    H = nyquistfilter(nsym*up, 0, Fs, baudrate);  % receive filter
    rx = apply_filter(signal, H, 1);
    rx_sym = rx(1:up:end);  % samples at the symbol instants

    % compare the shapes: scale both to the mean power 1, then take the difference
    rx_unit = rx_sym / sqrt(mean(abs(rx_sym).^2));
    ref_unit = data_mod / sqrt(mean(abs(data_mod).^2));
    % EVM = error vector magnitude; 0.01 means an error of 1 percent
    EVM = sqrt(mean(abs(rx_unit - ref_unit).^2));
    assert(EVM < 1e-10, ...
        'TL_QAM and receive filter: every up-th sample must be a transmitted symbol');

    % back to the grid of my_qammod, then count the bit errors
    rx_grid = rx_unit * sqrt(mean(abs(data_mod).^2));
    assert(measure_BER_QAM(rx_grid, data, bitsPerSymbol) == 0, ...
        'measure_BER_QAM: without noise the BER must be 0');
end

% the same with a raised-cosine spectrum (rolloff 0.2) and the wider receive filter
nsym = 1000;
up = 2;
Fs = up*baudrate;
Hrcos = rcosfilter(nsym*up, baudrate, Fs, rolloff);
[signal, ~, data_mod] = TL_QAM(nsym, up, Hrcos, pin, 4);
H = nyquistfilter(nsym*up, 0, Fs, baudrate*(1 + rolloff));
rx = apply_filter(signal, H, 1);
rx_sym = rx(1:up:end);
rx_unit = rx_sym / sqrt(mean(abs(rx_sym).^2));
ref_unit = data_mod / sqrt(mean(abs(data_mod).^2));
EVM = sqrt(mean(abs(rx_unit - ref_unit).^2));
assert(EVM < 1e-10, 'TL_QAM: with rolloff 0.2 the symbols must come back as well');

% the same seed gives the same signal; a second call gives new data
rng(5);
[signal_1, data_1] = TL_QAM(nsym, up, Hrcos, pin, 4);
rng(5);
[signal_2, data_2] = TL_QAM(nsym, up, Hrcos, pin, 4);
[~, data_3] = TL_QAM(nsym, up, Hrcos, pin, 4);  % no new seed: other random bits
assert(isequal(signal_1, signal_2) && isequal(data_1, data_2), ...
    'TL_QAM: the same seed must give the same signal and the same data');
assert(~isequal(data_1, data_3), 'TL_QAM: a second call must give new data');

msg = '';
try
    TL_QAM(nsym, up, Hrcos, pin);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'TL_QAM:'), 'TL_QAM: a call without bitsPerSymbol must be an error');

msg = '';
try
    TL_QAM(nsym, up, Hrcos, pin, 3);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'TL_QAM:'), 'TL_QAM: bitsPerSymbol = 3 must be an error');
fprintf('Check 8 passed: TL_QAM and ideal receiver (EVM below 1e-10, BER 0)\n');

%% 9. measure_BER_QAM: counting of bit errors
[~, data, data_mod] = TL_QAM(nsym, up, Hrcos, pin, 4);  % 16QAM: bits and symbols
n_bits = numel(data);  % number of bits
assert(measure_BER_QAM(data_mod, data, 4) == 0, ...
    'measure_BER_QAM: the transmitted symbols themselves must give BER 0');

data_wrong = data;
data_wrong(10:10:70) = 1 - data_wrong(10:10:70);  % invert 7 bits
assert(abs(measure_BER_QAM(data_mod, data_wrong, 4) - 7/n_bits) < 1e-15, ...
    'measure_BER_QAM: 7 wrong bits must give BER = 7 / number of bits');
assert(measure_BER_QAM(data_mod, 1 - data, 4) == 1, ...
    'measure_BER_QAM: if every bit is inverted, the BER must be 1');

% move symbol 5 to its neighbor on the real axis: exactly one wrong bit (Gray mapping)
sym_wrong = data_mod;
sym_wrong(5) = sym_wrong(5) - 2*sign(real(sym_wrong(5)));
assert(abs(measure_BER_QAM(sym_wrong, data, 4) - 1/n_bits) < 1e-15, ...
    'measure_BER_QAM: a decision for a neighboring point must give one wrong bit');

% symbols that have nothing to do with the bits: about half of the bits are wrong
[~, ~, other_mod] = TL_QAM(nsym, up, Hrcos, pin, 4);
assert(abs(measure_BER_QAM(other_mod, data, 4) - 0.5) < 0.05, ...
    'measure_BER_QAM: unrelated symbols must give a BER near 0.5');

msg = '';
try
    measure_BER_QAM(data_mod, data(1:end-1), 4);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'measure_BER_QAM:'), ...
    'measure_BER_QAM: a wrong number of bits must be an error');

msg = '';
try
    measure_BER_QAM(data_mod.', data, 4);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'measure_BER_QAM:'), ...
    'measure_BER_QAM: a row vector of symbols must be an error');
fprintf('Check 9 passed: measure_BER_QAM (0, 7 and 1 wrong bits, all bits wrong)\n');

%% 10. adequalizet without noise: a known distortion must be removed
% Distortion: a gain error and the passband of an AWG that is 28.5 GHz away from the
% signal center (the largest shift in the two-stage switch). The passband is sloped
% over the signal band, so the symbols disturb each other.
% With the equalizer the symbols must be back on their places and the BER must be 0.
rng(10);  % own seed: the numbers of this section do not depend on the sections before
Morder = 16;  % filter order of the equalizer (17 taps)
nsym = 6000;  % number of symbols
up = 2;  % oversampling rate (samples per symbol)
Fs = up*baudrate;  % sampling frequency [Hz]
training_num = nsym/3;  % the first third of the symbols trains the equalizer
Hrcos = rcosfilter(nsym*up, baudrate, Fs, 0);  % transmit mask
H = nyquistfilter(nsym*up, 0, Fs, baudrate);  % receive filter
for q = 1:4
    bitsPerSymbol = bits_list(q);
    Mary = 2^bitsPerSymbol;  % number of constellation points
    [signal, data, data_mod] = TL_QAM(nsym, up, Hrcos, pin, bitsPerSymbol);
    signal = awg(signal, 9, 28.5e9, Fs, 66.6e9, 32, 1);  % sloped passband, 9 dB loss
    signal = 0.3 * signal;  % gain error
    signal = apply_filter(signal, H, 1);  % receive filter

    tx_bits = data(bitsPerSymbol*training_num+1 : end);  % bits after the training part
    tx_sym = data_mod(training_num+1 : end);  % symbols after the training part

    % without equalizer: symbol instants, scaled to the mean power of the constellation
    rx_sym = signal(1:up:end);
    rx_sym = rx_sym * sqrt(mean(abs(data_mod).^2) / mean(abs(rx_sym).^2));
    rx_sym = rx_sym(training_num+1 : end);
    err_without = sqrt(mean(abs(rx_sym - tx_sym).^2) / mean(abs(tx_sym).^2));
    BER_without = measure_BER_QAM(rx_sym, tx_bits, bitsPerSymbol);
    assert(err_without > 0.1, ...
        'adequalizet test: the distortion is too small to test the equalizer');

    % with equalizer
    y = adequalizet(signal, Mary, Morder, 0, data_mod(1:training_num), up);
    assert(isequal(size(y), [nsym, 1]), ...
        'adequalizet: the output must be a column with one sample per symbol');
    y = y(training_num+1 : end);  % the training part is not counted
    BER = measure_BER_QAM(y, tx_bits, bitsPerSymbol);
    assert(BER == 0, 'adequalizet: without noise the BER after the equalizer must be 0');
    err_with = sqrt(mean(abs(y - tx_sym).^2) / mean(abs(tx_sym).^2));
    assert(err_with < 0.01, ...
        'adequalizet: the RMS error of the equalized symbols must be below 1 percent');
    % printed as: value without equalizer -> value with equalizer
    fprintf('  %2dQAM: RMS error %.3f -> %.4f, BER %.1e -> %g\n', ...
        Mary, err_without, err_with, BER_without, BER);
end

% a phase rotation is removed as well (16QAM, rotation by 0.5 rad)
[signal, data, data_mod] = TL_QAM(nsym, up, Hrcos, pin, 4);
signal = apply_filter(exp(1i*0.5) * signal, H, 1);
tx_bits = data(4*training_num+1 : end);  % bits after the training part
rx_sym = signal(1:up:end);
rx_sym = rx_sym * sqrt(mean(abs(data_mod).^2) / mean(abs(rx_sym).^2));
BER_without = measure_BER_QAM(rx_sym(training_num+1 : end), tx_bits, 4);
y = adequalizet(signal, 16, Morder, 0, data_mod(1:training_num), up);
BER = measure_BER_QAM(y(training_num+1 : end), tx_bits, 4);
assert(BER_without > 0.1, 'adequalizet test: a rotation by 0.5 rad must cause bit errors');
assert(BER == 0, 'adequalizet: a phase rotation must be removed by the equalizer');

% astep is not used: any value gives the same output
y_other = adequalizet(signal, 16, Morder, 123, data_mod(1:training_num), up);
assert(isequal(y, y_other), 'adequalizet: the argument astep must not change the output');

msg = '';
try
    adequalizet(signal, 16, 15, 0, data_mod(1:training_num), up);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'adequalizet:'), ...
    'adequalizet: an odd filter order must be an error');

msg = '';
try
    adequalizet(signal.', 16, Morder, 0, data_mod(1:training_num), up);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'adequalizet:'), 'adequalizet: a row vector must be an error');

% m is the number of constellation points (M is the filter order): 8 is not allowed
msg = '';
try
    adequalizet(signal, 8, Morder, 0, data_mod(1:training_num), up);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'adequalizet: m '), ...
    'adequalizet: m = 8 constellation points must be an error of adequalizet itself');
fprintf('Check 10 passed: adequalizet without noise (BER 0 for 4, 16, 32, 64QAM)\n');

%% 11. BER in white Gaussian noise against the theory (QPSK, 16QAM, 64QAM)
% Theory for square QAM with Gray mapping (SNR = Es/N0 as a linear number, k = log2(M)):
%   BER = (2/k) * (1 - 1/sqrt(M)) * erfc(sqrt(3*SNR / (2*(M - 1))))
% 32QAM is not square, so this formula does not hold for it.
% The noise is added over the whole simulated band Fs. The receive filter of width
% baudrate keeps the fraction 1/up of it, so the noise power in Fs is P_signal*up/SNR.
rng(11);  % own seed: the numbers of this section do not depend on the sections before
nsym = 1.2e5;  % number of symbols
up = 2;  % oversampling rate (samples per symbol)
Fs = up*baudrate;  % sampling frequency [Hz]
training_num = nsym/3;  % the first third of the symbols trains the equalizer
Hrcos = rcosfilter(nsym*up, baudrate, Fs, 0);  % transmit mask
H = nyquistfilter(nsym*up, 0, Fs, baudrate);  % receive filter
bits_awgn = [2, 4, 6];  % bits per symbol of the three square formats
snr_dB_awgn = [7, 14, 20];  % SNR that gives a BER near 1e-2 for each format [dB]
for q = 1:3
    k = bits_awgn(q);  % bits per symbol
    Mary = 2^k;  % number of constellation points
    snr = 10^(snr_dB_awgn(q)/10);  % SNR as a linear number
    BER_th = (2/k) * (1 - 1/sqrt(Mary)) * erfc(sqrt(3*snr / (2*(Mary - 1))));

    [signal, data, data_mod] = TL_QAM(nsym, up, Hrcos, pin, k);
    P_signal = mean(abs(signal).^2);  % signal power [W]
    P_noise = P_signal * up / snr;  % noise power in the whole band Fs [W]
    noise = sqrt(P_noise/2) * (randn(nsym*up, 1) + 1i*randn(nsym*up, 1));
    rx = apply_filter(signal + noise, H, 1);  % receive filter

    tx_bits = data(k*training_num+1 : end);  % bits after the training part
    tx_sym = data_mod(training_num+1 : end);  % symbols after the training part

    % (a) ideal receiver without equalizer: the gain of the path is known
    rx_clean = apply_filter(signal, H, 1);  % the same path without noise
    gain = rx_clean(1) / data_mod(1);  % received symbol / transmitted symbol
    rx_sym = rx(1:up:end) / gain;  % symbol instants on the grid of my_qammod
    BER_a = measure_BER_QAM(rx_sym(training_num+1 : end), tx_bits, k);
    assert(abs(log10(BER_a/BER_th)) < 0.05, ...
        'AWGN test: BER of the ideal receiver is not within 0.05 decades of the theory');

    % (b) receiver of the main scripts: equalizer with 17 taps
    % With noise the equalizer output is a little smaller than the ideal constellation,
    % because it minimizes the mean square error. This costs a few percent of BER.
    y = adequalizet(rx, Mary, 16, 0, data_mod(1:training_num), up);
    BER_b = measure_BER_QAM(y(training_num+1 : end), tx_bits, k);
    assert(abs(log10(BER_b/BER_th)) < 0.1, ...
        'AWGN test: BER after adequalizet is not within 0.1 decades of the theory');

    % SNR measured on the equalized symbols: signal power / power of the error.
    % For the reason given above this ratio is SNR + 1, not SNR (as linear numbers).
    snr_meas = mean(abs(tx_sym).^2) / mean(abs(y(training_num+1 : end) - tx_sym).^2);
    assert(abs(10*log10(snr_meas) - 10*log10(snr + 1)) < 0.15, ...
        'AWGN test: SNR of the equalized symbols is not within 0.15 dB of SNR + 1');

    fprintf('  %2dQAM, SNR %2d dB: BER theory %.3e, ideal rx %.3e, equalizer %.3e\n', ...
        Mary, snr_dB_awgn(q), BER_th, BER_a, BER_b);
    fprintf('         SNR of the equalized symbols %.2f dB (SNR + 1 = %.2f dB)\n', ...
        10*log10(snr_meas), 10*log10(snr + 1));
end
fprintf('Check 11 passed: BER in white Gaussian noise agrees with the theory\n');

fprintf('test_lib_filters_qam: all passed\n');
