%% test_lib_edfa - Self-test of the optical amplifier amplified_by_EDFA3
% Tested: the ASE power, the gain, the output power limit, the polarization
% convention (SNR = P_in/(F*h*f*B) for a polarization-multiplexed signal),
% the independence of the oversampling rate up, and the errors.
%
% How to run: run setup_path once, then type test_lib_edfa.
% Every check is an assert. If a check fails, MATLAB stops and prints the reason.
% If the line "test_lib_edfa: all passed" appears at the end, every check passed.
%
% Convention that is tested (see the header of amplified_by_EDFA3):
%   - the simulated field is ONE polarization of ONE wavelength channel;
%   - the amplifier adds the ASE of ONE polarization: (G*F - 1)*h*f*Fs/2 [W];
%   - sat is the saturation power for that polarization, N the number of channels;
%   - the output limit counts the signal and the ASE in the bandwidth B_ref:
%     P_total = G*P_in + (G*F - 1)*h*f*B_ref/2 [W].

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error('test_lib_edfa: the library is not on the MATLAB path. Run setup_path first.');
end

h = 6.62607004e-34;  % Planck constant [J s] (the value used in the library)
f = 299792458/1550e-9;  % optical frequency at the wavelength 1550 nm [Hz]
n = 1e6;  % number of samples (1e6 samples: a measured noise power is exact to 0.01 dB)
tol_stat = 0.05;  % allowed error of a measured noise power or SNR [dB]
tol = 1e-9;  % allowed rounding error of a power that has no random part [dB]
B_ref = 50e9;  % bandwidth of the output limit [Hz]; the scripts pass signal_interval
tol_sum = 1e-4;  % allowed error of signal + measured ASE in B_ref [dB] (the ASE is small)

%% 1. ASE power: measured value against (G*F - 1)*h*f*Fs/2
% One row per case: gain [dB], noise figure [dB], sampling frequency [Hz].
% The case with 0 dB gain shows that the "- 1" of the formula is needed.
cases = [20, 5, 120e9; 30, 5, 120e9; 30, 4, 96e9; 25, 6, 160e9; 10, 3, 120e9; 0, 5, 120e9];
no_input = zeros(n, 1);  % no input signal: the output is ASE only
for k = 1:size(cases, 1)
    gain_dB = cases(k, 1);
    NF_dB = cases(k, 2);
    Fs = cases(k, 3);
    [out, aseNoise] = amplified_by_EDFA3(no_input, Fs, gain_dB, NF_dB, Inf, 1, B_ref);
    G = 10^(gain_dB/10);
    F = 10^(NF_dB/10);
    P_ase_theory = 10*log10((G*F - 1)*h*f*Fs/2 * 1e3);  % one polarization [dBm]
    P_ase_meas = calc_signal_power(aseNoise);
    assert(abs(P_ase_meas - P_ase_theory) < tol_stat, ...
        'ASE power: the measured value is not (G*F - 1)*h*f*Fs/2 (one polarization)');
    assert(isequal(out, aseNoise), 'ASE power: without input the output must be ASE only');
    fprintf('  G %2d dB, NF %d dB, Fs %3.0f GHz: ASE %7.3f dBm, theory %7.3f dBm\n', ...
        gain_dB, NF_dB, Fs/1e9, P_ase_meas, P_ase_theory);
end
fprintf('Check 1 passed: ASE power = (G*F - 1)*h*f*Fs/2 within %.2f dB\n', tol_stat);

%% 2. The ASE is complex Gaussian noise that is white over the simulated band
Fs = 120e9;
[~, aseNoise] = amplified_by_EDFA3(no_input, Fs, 30, 5, Inf, 1, B_ref);
P_re = mean(real(aseNoise).^2);  % power of the real part [W]
P_im = mean(imag(aseNoise).^2);  % power of the imaginary part [W]
assert(abs(10*log10(P_re/P_im)) < tol_stat, ...
    'ASE: real part and imaginary part must have the same power');
assert(abs(mean(aseNoise)) < 0.01*sqrt(P_re + P_im), 'ASE: the mean value must be 0');

H_half = nyquistfilter(n, 0, Fs, Fs/2);  % brick wall, half of the simulated band
P_half = calc_signal_power(apply_filter(aseNoise, H_half, 1));
assert(abs(P_half - (calc_signal_power(aseNoise) - 10*log10(2))) < tol_stat, ...
    'ASE: half of the band must hold half of the ASE power (white noise)');
fprintf('Check 2 passed: the ASE is white complex Gaussian noise\n');

%% 3. Gain of the signal
signal_in = set_signal_power(randn(n, 1) + 1i*randn(n, 1), -20);  % test field, -20 dBm
[out, aseNoise] = amplified_by_EDFA3(signal_in, Fs, 23, 5, Inf, 1, B_ref);
signal_out = out - aseNoise;  % the amplified signal without the ASE
assert(abs(calc_signal_power(signal_out) - (-20 + 23)) < tol, ...
    'gain: a gain of 23 dB must lift the signal from -20 dBm to +3 dBm');
assert(max(abs(signal_out - 10^(23/20)*signal_in)) < 1e-12*max(abs(signal_out)), ...
    'gain: the field must be multiplied by 10^(gain_dB/20), without any distortion');
fprintf('Check 3 passed: gain\n');

%% 4. Output power limit
% Step 3 of the function counts the amplified signal and the ASE in the bandwidth B_ref:
%   P_total = G*P_in + (G*F - 1)*h*f*B_ref/2 [W]. It must not be above sat - 10*log10(N).
% 4a. far below the limit nothing changes
rng(11);
out_free = amplified_by_EDFA3(signal_in, Fs, 23, 5, Inf, 1, B_ref);
rng(11);
out_high = amplified_by_EDFA3(signal_in, Fs, 23, 5, 30, 1, B_ref);
assert(isequal(out_free, out_high), ...
    'limit: an output of +3 dBm is below sat = 30 dBm and must not be changed');

% 4b. the wanted gain is too large: the gain is reduced (step 1), then step 3 acts
sat = 13;  % saturation power for the simulated polarization [dBm]
[out, aseNoise] = amplified_by_EDFA3(signal_in, Fs, 40, 5, sat, 1, B_ref);
signal_out = out - aseNoise;
P_signal_out = calc_signal_power(signal_out);  % signal part of the output [dBm]
G = 10^((sat - (-20))/10);  % reduced gain: it lifts -20 dBm to sat
F = 10^(5/10);
P_total = G*1e-5 + (G*F - 1)*h*f*B_ref/2;  % signal + ASE in B_ref [W]; -20 dBm = 1e-5 W
assert(abs(P_signal_out - (sat + 10*log10(G*1e-5/P_total))) < tol, ...
    'limit: the signal part must be sat times G*P_in/P_total (P_total: ASE in B_ref)');
assert(P_signal_out < sat && P_signal_out > sat - 0.05, ...
    'limit: the signal part must be just below sat (the ASE takes a little power)');
assert(max(abs(signal_out - signal_out(1)/signal_in(1)*signal_in)) ...
    < 1e-12*max(abs(signal_out)), ...
    'limit: out - aseNoise must be the input signal times one constant');
% measured: the signal part and the ASE inside a brick wall of width B_ref
H_ref = nyquistfilter(n, 0, Fs, B_ref);  % brick wall of width B_ref
P_ase_ref = calc_signal_power(apply_filter(aseNoise, H_ref, 1));  % ASE in B_ref [dBm]
P_sum = 10*log10(10^(P_signal_out/10) + 10^(P_ase_ref/10));  % signal + ASE in B_ref [dBm]
assert(abs(P_sum - sat) < tol_sum, ...
    'limit: signal + ASE in B_ref must have exactly the power sat');
% the output itself holds all the ASE inside Fs, so its power is a little above sat
P_out = calc_signal_power(out);  % signal + all the ASE inside Fs [dBm]
assert(P_out > sat + 0.003 && P_out < sat + 0.01, ...
    'limit: the output with all the ASE inside Fs = 120 GHz must be 0.006 dB above sat');

% 4c. step 3 does not change the SNR: it is the SNR of the reduced gain
SNR_theory = 10*log10(G*1e-5 / ((G*F - 1)*h*f*Fs/2));  % SNR in the whole band Fs [dB]
SNR_meas = P_signal_out - calc_signal_power(aseNoise);
assert(abs(SNR_meas - SNR_theory) < tol_stat, ...
    'limit: the SNR must be G*P_in / ((G*F - 1)*h*f*Fs/2) with the reduced gain G');

% 4d. N wavelength channels share the output power
N_list = [1, 2, 8, 12, 96];
for k = 1:numel(N_list)
    [out, aseNoise] = amplified_by_EDFA3(signal_in, Fs, 60, 5, 20, N_list(k), B_ref);
    limit = 20 - 10*log10(N_list(k));  % power for one channel [dBm]
    G = 10^((limit - (-20))/10);  % reduced gain: it lifts -20 dBm to limit
    P_total = G*1e-5 + (G*F - 1)*h*f*B_ref/2;  % signal + ASE in B_ref [W]
    P_signal_out = calc_signal_power(out - aseNoise);
    assert(abs(P_signal_out - (limit + 10*log10(G*1e-5/P_total))) < tol, ...
        'limit: signal + ASE in B_ref must have the power sat - 10*log10(N)');
end
rng(12);
out_a = amplified_by_EDFA3(signal_in, Fs, 60, 5, 20, 8, B_ref);
rng(12);
out_b = amplified_by_EDFA3(signal_in, Fs, 60, 5, 20 - 10*log10(8), 1, B_ref);
assert(max(abs(out_a - out_b)) < 1e-12*max(abs(out_a)), ...
    'limit: (sat, N) must give the same output as (sat - 10*log10(N), 1)');

% 4e. polarization multiplexing: the caller passes sat = edfa_sat - 3*pol_flag
edfa_sat1 = 20;  % saturation power of the EDFA, all channels, both polarizations [dBm]
pol_flag = 1;  % 1 = polarization multiplexing
N = 96;  % number of wavelength channels of the switch
ULCF_deg = 12;  % number of AWG input ports = number of EDFAs
sat1 = edfa_sat1 - 3*pol_flag;
edfaGain = sat1 - 10*log10(N/ULCF_deg) - calc_signal_power(signal_in);
[out, aseNoise] = amplified_by_EDFA3(signal_in, Fs, edfaGain, 5, sat1, N/ULCF_deg, B_ref);
P_signal_out = calc_signal_power(out - aseNoise);
P_ase_ref = calc_signal_power(apply_filter(aseNoise, H_ref, 1));  % ASE in B_ref [dBm]
% one polarization of one channel: the signal and the ASE of one channel spacing
P_out = 10*log10(10^(P_signal_out/10) + 10^(P_ase_ref/10));
assert(abs(P_out - (20 - 3 - 10*log10(8))) < tol_sum, ...
    'limit: one polarization of one of 8 channels must get 20 - 3 - 9.03 = 7.97 dBm');
P_all = P_out + 10*log10(N/ULCF_deg) + 3*pol_flag;  % all channels, both polarizations
assert(abs(P_all - edfa_sat1) < tol_sum, ...
    'limit: all channels and both polarizations together must give edfa_sat1');
fprintf('Check 4 passed: output power limit (sat, N, B_ref, polarization multiplexing)\n');

%% 5. Polarization convention: SNR in the simulated band Fs
gain_dB = 30;
NF_dB = 5;
F = 10^(NF_dB/10);
P_in_total = -20;  % TOTAL input power of the channel [dBm]
noise_ref = 10*log10(F*h*f*Fs * 1e3);  % F*h*f*Fs [dBm]

% 5a. polarization multiplexing: the simulated polarization carries half of the power
signal_dp = set_signal_power(signal_in, P_in_total - 3);
[out, aseNoise] = amplified_by_EDFA3(signal_dp, Fs, gain_dB, NF_dB, Inf, 1, B_ref);
SNR_dp = calc_signal_power(out - aseNoise) - calc_signal_power(aseNoise);
assert(abs(SNR_dp - (P_in_total - noise_ref)) < 0.1, ...
    'SNR: polarization multiplexing must give SNR = P_in/(F*h*f*B), P_in = total power');

% 5b. one polarization only: the simulated polarization carries all the power
signal_sp = set_signal_power(signal_in, P_in_total);
[out, aseNoise] = amplified_by_EDFA3(signal_sp, Fs, gain_dB, NF_dB, Inf, 1, B_ref);
SNR_sp = calc_signal_power(out - aseNoise) - calc_signal_power(aseNoise);
assert(abs(SNR_sp - (P_in_total + 10*log10(2) - noise_ref)) < 0.1, ...
    'SNR: a single polarization must give SNR = 2*P_in/(F*h*f*B)');
fprintf('  SNR in Fs: DP %.2f dB (theory %.2f), single pol. %.2f dB (theory %.2f)\n', ...
    SNR_dp, P_in_total - noise_ref, SNR_sp, P_in_total + 10*log10(2) - noise_ref);
fprintf('Check 5 passed: SNR in the band Fs follows the polarization convention\n');

%% 6. Polarization convention: SNR of a Nyquist signal in its own bandwidth
% A 24-Gbaud polarization-multiplexed signal, as in the main scripts (pin = PTx - 3).
baudrate = 24e9;  % symbol rate [Hz]
up = 2;  % oversampling rate (samples per symbol)
Fs = up * baudrate;  % sampling frequency [Hz]
datasize = n / up;  % number of symbols
PTx = -20;  % power of the channel at the amplifier input, both polarizations [dBm]
pol_flag = 1;
pin = PTx - 3*pol_flag;  % power of the simulated polarization [dBm]

symbols = (2*randi([0, 1], datasize, 1) - 1) + 1i*(2*randi([0, 1], datasize, 1) - 1);
Hrcos = rcosfilter(n, baudrate, Fs, 0);  % transmit mask, rolloff 0
signal = set_signal_power(apply_filter(symbols, Hrcos, up), pin);
[out, aseNoise] = amplified_by_EDFA3(signal, Fs, gain_dB, NF_dB, Inf, 1, B_ref);

H = nyquistfilter(n, 0, Fs, baudrate);  % receive brick wall of width baudrate
signal_rx = apply_filter(out - aseNoise, H, 1);  % signal part after the receive filter
noise_rx = apply_filter(aseNoise, H, 1);  % ASE part after the receive filter
SNR_meas = calc_signal_power(signal_rx) - calc_signal_power(noise_rx);
SNR_theory = PTx - 10*log10(F*h*f*baudrate * 1e3);  % P_in/(F*h*f*B), B = baudrate
assert(abs(SNR_meas - SNR_theory) < 0.1, ...
    'SNR: after the receive filter the SNR must be PTx/(F*h*f*baudrate)');

% the same statement as the rule of thumb "SNR in 12.5 GHz = P_in + 58 - NF"
const_58 = -10*log10(h*f*12.5e9 * 1e3);  % 1 mW / (h*f*12.5 GHz) [dB]
assert(abs(const_58 - 58) < 0.1, 'SNR: 1 mW/(h*f*12.5 GHz) must be about 58 dB');
SNR_rule = PTx + const_58 - NF_dB - 10*log10(baudrate/12.5e9);
assert(abs(SNR_meas - SNR_rule) < 0.1, ...
    'SNR: the measured SNR must follow the rule P_in + 58 - NF (scaled to the baud rate)');
fprintf('  SNR in %.0f GHz: measured %.2f dB, theory %.2f dB\n', baudrate/1e9, ...
    SNR_meas, SNR_theory);
fprintf('Check 6 passed: SNR = P_in/(F*h*f*B) for a polarization-multiplexed signal\n');

%% 7. The output limit does not depend on the oversampling rate up
% The 24-Gbaud signal of check 6 is made with up = 2, 4 and 8 (Fs = 48, 96, 192 GHz)
% and amplified by a pre-amplifier up to its output limit.
% A larger Fs holds more ASE (step 2), but step 3 counts only the ASE in B_ref.
% So the signal part of the output and the SNR in the signal band must not change.
sat2 = 10 - 3*pol_flag;  % saturation power of the pre-amplifier for one polarization [dBm]
up_list = [2, 4, 8];  % oversampling rates
P_signal_out = zeros(1, 3);  % signal part of the output for each up [dBm]
SNR_band = zeros(1, 3);  % SNR in the signal band for each up [dB]
for k = 1:3
    up = up_list(k);
    Fs = up * baudrate;  % sampling frequency [Hz]
    datasize = n / up;  % number of symbols
    symbols = (2*randi([0, 1], datasize, 1) - 1) + 1i*(2*randi([0, 1], datasize, 1) - 1);
    Hrcos = rcosfilter(n, baudrate, Fs, 0);  % transmit mask, rolloff 0
    signal = set_signal_power(apply_filter(symbols, Hrcos, up), pin);
    edfaGain = sat2 - calc_signal_power(signal);  % the signal alone reaches the limit
    [out, aseNoise] = amplified_by_EDFA3(signal, Fs, edfaGain, NF_dB, sat2, 1, B_ref);
    P_signal_out(k) = calc_signal_power(out - aseNoise);
    H = nyquistfilter(n, 0, Fs, baudrate);  % receive brick wall of width baudrate
    SNR_band(k) = calc_signal_power(apply_filter(out - aseNoise, H, 1)) ...
        - calc_signal_power(apply_filter(aseNoise, H, 1));
    fprintf('  up %d, Fs %3.0f GHz: signal after the amplifier %.4f dBm, SNR %.2f dB\n', ...
        up, Fs/1e9, P_signal_out(k), SNR_band(k));
end
assert(max(P_signal_out) - min(P_signal_out) < tol, ...
    'limit: the signal power after the amplifier must not depend on Fs');
assert(max(abs(SNR_band - SNR_theory)) < 0.1, ...
    'limit: the SNR in the signal band must be PTx/(F*h*f*baudrate) for every Fs');
fprintf('Check 7 passed: level and SNR after the amplifier do not depend on up\n');

%% 8. Random numbers: same seed, same noise; real part is drawn first
rng(7);
[~, ase_1] = amplified_by_EDFA3(signal, Fs, gain_dB, NF_dB, Inf, 1, B_ref);
rng(7);
[~, ase_2] = amplified_by_EDFA3(signal, Fs, gain_dB, NF_dB, Inf, 1, B_ref);
assert(isequal(ase_1, ase_2), 'random numbers: the same seed must give the same noise');

rng(7);
noise_re = randn(n, 1);  % the function draws the real part first
noise_im = randn(n, 1);  % and then the imaginary part (order of the legacy code)
G = 10^(gain_dB/10);
ase_expected = sqrt((G*F - 1)*h*f*Fs/2) * (noise_re + 1i*noise_im) / sqrt(2);
assert(max(abs(ase_1 - ase_expected)) < 1e-12*max(abs(ase_expected)), ...
    'random numbers: the noise must be sqrt(P_ase)*(randn + 1i*randn)/sqrt(2)');
fprintf('Check 8 passed: random numbers\n');

%% 9. Wrong inputs must be errors
msg = '';
try
    amplified_by_EDFA3(signal, Fs, -6, 5, Inf, 1, B_ref);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'amplified_by_EDFA3: gain*F'), ...
    'errors: gain -6 dB with NF 5 dB gives gain*F < 1 and must be an error');

msg = '';
try
    amplified_by_EDFA3(set_signal_power(signal, 10), Fs, 20, 5, 0, 1, B_ref);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'amplified_by_EDFA3: gain*F'), ...
    'errors: an input 10 dB above the limit (NF 5 dB) must be an error');

msg = '';
try
    amplified_by_EDFA3(signal.', Fs, 20, 5, Inf, 1, B_ref);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'amplified_by_EDFA3: signal'), ...
    'errors: a row vector must be an error');

msg = '';
try
    amplified_by_EDFA3([signal, signal], Fs, 20, 5, Inf, 1, B_ref);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'amplified_by_EDFA3: signal'), ...
    'errors: a matrix (two signals) must be an error');

msg = '';
try
    amplified_by_EDFA3(signal, Fs, 20, 5, 20, 0, B_ref);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'amplified_by_EDFA3: N'), 'errors: N = 0 must be an error');

msg = '';
try
    amplified_by_EDFA3(signal, Fs, 20, 5, 20, 1, 0);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'amplified_by_EDFA3: B_ref'), ...
    'errors: B_ref = 0 must be an error');

msg = '';
try
    amplified_by_EDFA3(signal, Fs, 20, 5, 20, 1, -50e9);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'amplified_by_EDFA3: B_ref'), ...
    'errors: a negative B_ref must be an error');

msg = '';
try
    amplified_by_EDFA3(signal, Fs, 20, 5, 20, 1);
catch err
    msg = err.message;
end
assert(startsWith(msg, 'amplified_by_EDFA3: seven'), ...
    'errors: a call with six inputs (without B_ref) must be an error');
fprintf('Check 9 passed: errors\n');

fprintf('test_lib_edfa: all passed\n');
