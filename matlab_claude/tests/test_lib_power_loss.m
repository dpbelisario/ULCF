%% test_lib_power_loss - Self-test of the power and loss functions of the library
% Tested functions: attenuation, calc_signal_power, set_signal_power,
% selector_loss, coupler_loss, DCS_loss, awg_channel, ULCF_dev_freq, plot_level_diagram.
%
% How to run: run setup_path once, then type test_lib_power_loss.
% Every check is an assert. If a check fails, MATLAB stops and prints the reason.
% If the line "test_lib_power_loss: all passed" appears at the end, every check passed.

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['test_lib_power_loss: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

tol = 1e-9;  % allowed rounding error of a power or of a loss [dB]

%% 1. attenuation
x = (randn(1000, 1) + 1i*randn(1000, 1)) * sqrt(1e-3/2);  % random field, about 0 dBm
P_x = mean(abs(x).^2);  % power of x [W]

[y, att] = attenuation(x, 3);
assert(abs(att - 10^(-3/20)) < 1e-15, ...
    'attenuation: a loss of 3 dB must multiply the field by 10^(-3/20)');
assert(abs(mean(abs(y).^2)/P_x - 10^(-3/10)) < 1e-12, ...
    'attenuation: a loss of 3 dB must multiply the power by 10^(-3/10)');

y = attenuation(x, 10*log10(2));
assert(abs(mean(abs(y).^2)/P_x - 0.5) < 1e-12, ...
    'attenuation: a loss of 10*log10(2) = 3.01 dB must halve the power');

y = attenuation(x, 20);
assert(max(abs(y - 0.1*x)) < 1e-15, ...
    'attenuation: a loss of 20 dB must multiply the field by 0.1');

y = attenuation(x, 0);
assert(isequal(y, x), 'attenuation: a loss of 0 dB must not change the field');

y = attenuation(attenuation(x, 7), -7);
assert(max(abs(y - x)) < 1e-15, ...
    'attenuation: a negative loss is a gain; 7 dB loss then 7 dB gain must give x again');

y = attenuation(x, 12.5);
assert(max(abs(angle(y ./ x))) < 1e-12, 'attenuation: the phase must not change');

X = [x, x, x];  % three signals, one per column
Y = attenuation(X, [0, 10, 20]);  % one loss per column
P_Y = mean(abs(Y).^2, 1);  % power of each column [W]
assert(max(abs(10*log10(P_Y/P_x) - [0, -10, -20])) < tol, ...
    'attenuation: a row vector of losses must act column by column');
fprintf('Check 1 passed: attenuation\n');

%% 2. calc_signal_power
assert(abs(calc_signal_power(sqrt(1e-3)*ones(100, 1)) - 0) < tol, ...
    'calc_signal_power: a field of constant power 1 mW must be 0 dBm');
assert(abs(calc_signal_power(sqrt(1e-6)*ones(100, 1)) - (-30)) < tol, ...
    'calc_signal_power: a field of constant power 1 uW must be -30 dBm');
assert(abs(calc_signal_power(ones(100, 1)) - 30) < tol, ...
    'calc_signal_power: a field of constant power 1 W must be +30 dBm');

phase = 2*pi*rand(100, 1);  % any phase [rad]
assert(abs(calc_signal_power(sqrt(2e-3)*exp(1i*phase)) - 10*log10(2)) < tol, ...
    'calc_signal_power: the phase must not matter; 2 mW must be 3.01 dBm');

P_two = calc_signal_power([sqrt(1e-3)*ones(50, 1), sqrt(1e-2)*ones(50, 1)]);
assert(isequal(size(P_two), [1, 2]), ...
    'calc_signal_power: a matrix with 2 columns must give a 1 x 2 row vector');
assert(max(abs(P_two - [0, 10])) < tol, ...
    'calc_signal_power: columns of 1 mW and 10 mW must give 0 dBm and 10 dBm');

assert(calc_signal_power(zeros(10, 1)) == -Inf, ...
    'calc_signal_power: a signal without power must give -Inf dBm');

msg = '';
try
    calc_signal_power(x.');
catch err
    msg = err.message;
end
assert(startsWith(msg, 'calc_signal_power:'), ...
    'calc_signal_power: a row vector must be an error');
fprintf('Check 2 passed: calc_signal_power\n');

%% 3. set_signal_power
s = set_signal_power(x, -3);
assert(abs(calc_signal_power(s) - (-3)) < tol, ...
    'set_signal_power: after the call the power must be the wanted -3 dBm');
ratio = s ./ x;  % must be one real positive number for all samples
assert(max(abs(ratio - ratio(1))) < 1e-12 && abs(imag(ratio(1))) < 1e-12 ...
    && real(ratio(1)) > 0, 'set_signal_power: only the amplitude may change');

X = [x, 5*x, 0.01*x];  % three signals with very different powers
S = set_signal_power(X, 2);
assert(max(abs(calc_signal_power(S) - 2)) < tol, ...
    'set_signal_power: a scalar power must be given to every column');
S = set_signal_power(X, [-10, 0, 7.5]);
assert(max(abs(calc_signal_power(S) - [-10, 0, 7.5])) < tol, ...
    'set_signal_power: a row vector of powers must act column by column');

msg = '';
try
    set_signal_power(zeros(10, 1), 0);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'set_signal_power:'), ...
    'set_signal_power: an all-zero signal must be an error');

% a row vector must not be scaled sample by sample (that would destroy the waveform)
msg = '';
try
    set_signal_power(x.', 0);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'set_signal_power: signal_data is a row vector'), ...
    'set_signal_power: a row vector must be an error');
fprintf('Check 3 passed: set_signal_power\n');

%% 4. Loss rules: selector_loss, coupler_loss, DCS_loss
ports = [1, 2, 4, 8, 16, 32, 64, 128];  % powers of 2: 2^0 to 2^7
assert(isequal(selector_loss(ports), 0.5*(0:7)), ...
    'selector_loss: 0.5 dB per factor of 2 (1 port = 0 dB, 128 ports = 3.5 dB)');
assert(isequal(coupler_loss(ports), 3.5*(0:7)), ...
    'coupler_loss: 3.5 dB per factor of 2 (1 port = 0 dB, 128 ports = 24.5 dB)');
assert(isequal(DCS_loss(ports), 4*(0:7)), ...
    'DCS_loss: 4 dB per factor of 2 (1 port = 0 dB, 128 ports = 28 dB)');
assert(isequal(DCS_loss([2, 4, 8, 16, 32]), 4*log2([2, 4, 8, 16, 32])), ...
    'DCS_loss: for powers of 2 the result must be the legacy value 4*log2(M)');

% the round-up to the next power of 2 is kept on purpose
assert(coupler_loss(96) == 24.5, 'coupler_loss: 96 ports must cost 24.5 dB (7 stages)');
assert(coupler_loss(96) == coupler_loss(128), ...
    'coupler_loss: 96 ports must cost the same as 128 ports');
assert(coupler_loss(64) == 21 && coupler_loss(65) == 24.5, ...
    'coupler_loss: the loss must step from 21 dB (64 ports) to 24.5 dB (65 ports)');
assert(selector_loss(96) == 3.5, 'selector_loss: 96 ports must cost 3.5 dB (7 stages)');
assert(DCS_loss(12) == 16 && DCS_loss(16) == 16, ...
    'DCS_loss: 12 ports must cost the same as 16 ports (16 dB)');

% aggregation coupler of a switch with N = 96 wavelengths and a ULCF AWG of degree K
K = [1, 2, 4, 6, 8, 12, 16];  % number of AWG input ports
assert(isequal(coupler_loss(96 ./ K), [24.5, 21, 17.5, 14, 14, 10.5, 10.5]), ...
    'coupler_loss: wrong loss of the (96/K) x 1 aggregation coupler');
assert(coupler_loss(96) - coupler_loss(96/12) == 14, ...
    'coupler_loss: a ULCF AWG with 12 input ports must save 14 dB of coupler loss');

M = 1:300;  % every port count, not only powers of 2
assert(isequal(coupler_loss(M), 3.5*nextpow2(M)), ...
    'coupler_loss: must be equal to the legacy formula 3.5*log2(2^nextpow2(N))');
assert(isequal(DCS_loss(M), selector_loss(M) + coupler_loss(M)), ...
    'DCS_loss: must be selector_loss + coupler_loss for every port count');
assert(isequal(DCS_loss(M), 4*ceil(log2(M))), 'DCS_loss: must be 4*ceil(log2(M))');
assert(all(diff(coupler_loss(M)) >= 0), 'coupler_loss: more ports never cost less');

k = 0:20;  % exact powers of 2 must not be rounded up by a rounding error of log2
assert(isequal(coupler_loss(2.^k), 3.5*k), 'coupler_loss: 2^k ports must cost 3.5*k dB');
assert(isequal(coupler_loss(2.^k + 1), 3.5*(k + 1)), ...
    'coupler_loss: 2^k + 1 ports must cost 3.5*(k+1) dB');

assert(isequal(size(coupler_loss([2, 4; 8, 16])), [2, 2]), ...
    'coupler_loss: the output must have the same size as the input');

msg = '';
try
    coupler_loss(0);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'coupler_loss:'), 'coupler_loss: 0 ports must be an error');

msg = '';
try
    coupler_loss(2.5);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'coupler_loss:'), 'coupler_loss: 2.5 ports must be an error');

msg = '';
try
    selector_loss(-4);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'selector_loss:'), 'selector_loss: -4 ports must be an error');

msg = '';
try
    DCS_loss(0);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'DCS_loss:'), 'DCS_loss: 0 ports must be an error');
fprintf('Check 4 passed: selector_loss, coupler_loss, DCS_loss (96 ports -> 24.5 dB)\n');

%% 5. A small power budget: the loss functions together with a field
pin = 0;  % power at the input of the DC switch [dBm]
signal = set_signal_power(x, pin);
signal = attenuation(signal, DCS_loss(8));  % 8 x 8 DC switch: 12 dB
signal = attenuation(signal, coupler_loss(96/12));  % 8 x 1 aggregation coupler: 10.5 dB
assert(abs(calc_signal_power(signal) - (pin - 12 - 10.5)) < tol, ...
    'power budget: 0 dBm - 12 dB - 10.5 dB must be -22.5 dBm');
fprintf('Check 5 passed: power budget %.1f dBm\n', calc_signal_power(signal));

%% 6. awg_channel
N = 96;  % number of wavelength channels
assert(isequal(awg_channel(1, 1:N, N), 1:N), ...
    'awg_channel: from input port 1, output port j must receive channel j');
assert(awg_channel(3, 5, N) == 7, ...
    'awg_channel: input port 3 (shift 2), output port 5 must be channel 7');
assert(awg_channel(3, 96, N) == 2, ...
    'awg_channel: channel 98 must wrap around to channel 2');
assert(isequal(awg_channel((1:4).', 1:4, 4), [1 2 3 4; 2 3 4 1; 3 4 1 2; 4 1 2 3]), ...
    'awg_channel: wrong routing table of a 4 x 4 cyclic AWG');

K = 12;  % number of input ports of the ULCF AWG
table_ch = awg_channel((1:K).', 1:N, N);  % K x N table: row = input, column = output
assert(isequal(size(table_ch), [K, N]), ...
    'awg_channel: a column of inputs and a row of outputs must give a K x N table');
assert(all(table_ch(:) >= 1) && all(table_ch(:) <= N) ...
    && all(table_ch(:) == round(table_ch(:))), ...
    'awg_channel: every channel number must be an integer from 1 to N');
for a = 0:K-1
    % rule of the paper: input port a + 1, output port j -> channel j + a (mod N)
    expected = (1:N) + a;
    expected(expected > N) = expected(expected > N) - N;
    assert(isequal(table_ch(a + 1, :), expected), ...
        'awg_channel: the rule "channel = j + a (mod N)" is not fulfilled');
    assert(isequal(sort(table_ch(a + 1, :)), 1:N), ...
        'awg_channel: from one input port every output must have a different channel');
end
for j = 1:N
    assert(numel(unique(table_ch(:, j))) == K, ...
        'awg_channel: at one output port every input must have a different channel');
end

in_port = (1:K).' * ones(1, N);  % input port of every table entry
out_back = mod(table_ch - in_port, N) + 1;  % the rule read backwards
assert(isequal(out_back, ones(K, 1) * (1:N)), ...
    'awg_channel: out_port = mod(ch - in_port, N) + 1 must give the output port back');

msg = '';
try
    awg_channel(0, 1, N);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'awg_channel:'), 'awg_channel: input port 0 must be an error');

msg = '';
try
    awg_channel(1, N + 1, N);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'awg_channel:'), 'awg_channel: output port N + 1 must be an error');

msg = '';
try
    awg_channel(1.5, 1, N);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'awg_channel:'), 'awg_channel: input port 1.5 must be an error');
fprintf('Check 6 passed: awg_channel\n');

%% 7. ULCF_dev_freq
deg = [1, 2, 4, 6, 8, 12, 16];  % degrees that are in the table
dev_expected = [5, 5, 8, 11, 12.5, 16, 17] * 1e9;  % legacy values [Hz]
for k = 1:numel(deg)
    assert(ULCF_dev_freq(deg(k)) == dev_expected(k), ...
        'ULCF_dev_freq: a value of the table is not the legacy value');
end

msg = '';
try
    ULCF_dev_freq(3);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'ULCF_dev_freq:'), ...
    'ULCF_dev_freq: degree 3 is not in the table and must be an error');
fprintf('Check 7 passed: ULCF_dev_freq\n');

%% 8. plot_level_diagram
stage_names = {'Tx', 'DC switch', 'Coupler', 'EDFA'};
power_dBm = [0, -12, -22.5, 8];
plot_level_diagram(stage_names, power_dBm);
assert(isscalar(findobj('Type', 'figure')), ...
    'plot_level_diagram: exactly one new figure must be opened');
curve = findobj(gca, 'Type', 'line');  % the plotted curve
assert(isequal(get(curve, 'YData'), power_dBm), ...
    'plot_level_diagram: the curve must show the given powers');
close all;

msg = '';
try
    plot_level_diagram({'Tx', 'EDFA'}, [0, -12, 3]);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'plot_level_diagram:'), ...
    'plot_level_diagram: 2 names for 3 powers must be an error');
assert(isempty(findobj('Type', 'figure')), ...
    'plot_level_diagram: no figure may be opened when the inputs are wrong');
fprintf('Check 8 passed: plot_level_diagram\n');

fprintf('test_lib_power_loss: all passed\n');
