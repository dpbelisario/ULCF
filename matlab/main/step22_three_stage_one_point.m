%% step22_three_stage_one_point - Conventional three-stage switch, ONE operating point
% This script sends one signal through the three-stage switch and counts the bit errors.
% One run = one operating point = one transmitter power, one size of the space
% switches and one type of the third stage.
% The search over many operating points is the script main_three_stage_conventional.
%
% The switch ("Scheme A" of JLT 2025 = Mitsuya et al., J. Lightw. Technol. 43(2), 2025)
%   stage 1 : N space switches (M x M), each made of 1 x M selectors and M x 1 selectors
%   stage 2 : M wavelength-routing switches (N x N): N x 1 coupler -> EDFA -> 1 x N AWG
%   stage 3 : N space switches (M x M)
%             stage3_coupler_flag = 0 : selectors + selectors (Scheme A1)
%             stage3_coupler_flag = 1 : selectors + couplers  (Scheme A2, less hardware)
%   Port count = M*N. The paper writes M; this script writes sw_size, because the
%   laboratory code already uses the letter M for the order of the equalizer.
%
% Path of the target signal (the numbers are the blocks of section 3)
%   [1] transmitter -> [2] fan-in/fan-out (only with multicore fibers)
%   -> [3] stage-1 space switch -> [4] aggregation coupler -> [5] EDFA -> [6] AWG
%   -> [7] stage-3 space switch -> [8] fan-in/fan-out (only with multicore fibers)
%   -> [9] pre-amplifier -> [10] coherent receiver, BER
% The blocks have the same numbers as in step21_two_stage_one_point:
% [3] is the DC switch there, and [7] is the crosstalk of the ULCF AWG there.
%
% What is simulated
%   ONE polarization of ONE wavelength channel (complex field, unit sqrt(W)).
%   Other signals appear only as crosstalk on the same wavelength:
%     - stage 1: the other sw_size-1 inputs of the space switch leak to the output;
%     - stage 3: the other sw_size-1 inputs of the space switch leak to the output.
%       Their signals ALWAYS have the wavelength of the target: output j of every
%       AWG carries wavelength j, and stage-3 switch j collects output j of all AWGs.
%       (This crosstalk is what the proposed switch attacks: see the folder "work".)
%   Noise: ASE of the EDFA and ASE of the pre-amplifier.
%   Not simulated: the neighboring wavelength channels, the fiber, laser phase noise.
%
% How to use this file
%   1. Run setup_path once (in the folder "matlab"). Then run this file (F5).
%   2. Read the two printed tables: power after every stage, SNR contributions.
%   3. Change ONE parameter of section 1 (PTx, sw_size or stage3_coupler_flag).
%      Predict how the tables change. Then run again and compare.
%
% Letters and names used here
%   N       = number of wavelength channels
%   M       = size of the space switches = sw_size (the port count is M*N)
%   Mary    = number of constellation points = 2^mod_flag (mod_flag = bits per symbol)
%   Morder  = order of the equalizer
%   up      = oversampling rate = number of samples per symbol
%   PTx     = transmitter power of one channel, both polarizations together [dBm]
%   pin     = power of the ONE simulated polarization = PTx - 3 dB [dBm]
%   In the help text of the library the letters N and M can mean other things
%   (number of samples, number of ports, filter order): read the "Inputs" list there.
%
% Legacy: there is no legacy script for this switch. The chain has the order and the
% variable names of TL_switch_coherent_search_Nyquist_07.m, lines 84-229.
% Where the values come from
%   paper = JLT 2025, section IV (simulation conditions of its Fig. 6 and Table V)
%   lab   = not written in the paper; value of the laboratory code

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['step22_three_stage_one_point: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters
datasize = 3e4;  % number of symbols (3e4 runs in a few seconds)
PTx = 4;  % transmitter power of one channel, both polarizations together [dBm]
sw_size = 64;  % size M of the M x M space switches (64*96 = 6144 ports)
stage3_coupler_flag = 1;  % stage 3: 0 = selectors (Scheme A1), 1 = couplers (Scheme A2)
mod_flag = 4;  % bits per symbol: 2 = QPSK, 4 = 16QAM, 5 = 32QAM, 6 = 64QAM (paper: 4)
up = 2;  % oversampling rate = samples per symbol (see the note below)
baudrate = 32e9;  % symbol rate [Hz] (paper: 200-Gbps DP-16QAM)
pol_flag = 1;  % 0 = one polarization, 1 = polarization multiplexing (paper: 1)
fiber_flag = 0;  % 0 = single-core fiber (paper), 1 = multicore fiber
Fan_in_loss = 1.5;  % loss of the fan-in device of the multicore fiber [dB]
Fan_out_loss = 1.5;  % loss of the fan-out device of the multicore fiber [dB]
N = 96;  % number of wavelength channels, on the 50-GHz grid (paper)
signal_interval = 50e9;  % channel spacing [Hz] (paper)
NF = 6;  % noise figure of the EDFA [dB] (paper)
edfa_sat1 = 20;  % saturation power of the EDFA: all channels, both pol. [dBm] (paper)
edfa_sat2 = 10;  % saturation power of the pre-amplifier, both polarizations [dBm] (lab)
NF2 = 4;  % noise figure of the pre-amplifier [dB] (lab)
rolloff = 0;  % roll-off factor of the Nyquist pulse (0 = rectangular spectrum)
sel_ex_ratio = 35;  % extinction ratio of one selector [dB] (paper)
xt_wave_max = Inf;  % crosstalk waveforms per switch: Inf = one per leak (see the note)
AWG_loss = 6;  % loss of the AWG at the center of its passband [dB] (paper)
FWHM_AWG = 50e9;  % 3-dB width of the AWG passband, Gaussian shape [Hz] (lab)
AWG_XT = 32;  % floor of the AWG passband shape [dB] (lab; it lies outside the band Fs)
Morder = 16;  % order of the adaptive equalizer (it has Morder + 1 taps)
seed = 1;  % seed of the random numbers (data and noise)
BER_limit = 1e-2;  % FEC limit: a BER below it is error free after error correction

% Note on up
% up is the oversampling rate: the number of samples per symbol.
% Fs = up*baudrate is the width of the simulated band: 64 GHz, from -32 to +32 GHz.
% The signal needs -16 to +16 GHz. Why up = 2 is enough in this script:
%   - Every signal of this chain is on the wavelength of the target. No signal
%     on another wavelength channel has to fit into the band.
%   - The equalizer works with 2 samples per symbol.
%   - The amplifier model does not depend on up: its output limit counts the ASE
%     in the bandwidth signal_interval, not the ASE in Fs (see amplified_by_EDFA3).
%     The target after the EDFA has the same power for every up.
%   - The AWG passband (50 GHz wide at -3 dB) has tails outside the band. The ASE
%     in these tails is not simulated. It could not reach the receiver (the
%     receive filter passes only the signal band). It is missing only in the
%     power that sets the gain of the pre-amplifier: with Scheme A1, sw_size = 64
%     and PTx = -3 dBm the target after the pre-amplifier has 6.76 / 6.72 /
%     6.72 dBm for up = 2 / 4 / 8. The SNR does not change by that.
% Test (Scheme A1, sw_size = 16, 1.5e5 symbols, six powers near the FEC limit,
% mean BER of 12 seeds): up = 2 and up = 4 give the same BER within 0.7 percent.
% The statistical error of this comparison is about 0.9 percent.
% Use a larger up
%   - for a signal on another wavelength channel, f_off away from the target:
%     Fs/2 must be at least f_off + baudrate*(1+rolloff)/2;
%   - for a finer waveform in a plot.
% The run time grows with up.

% Note on rolloff
% Keep rolloff = 0 unless you study the roll-off itself. With rolloff > 0:
%   - self-check 2 is skipped (the SNR budget assumes a rectangular spectrum);
%   - the signal band is wider: baudrate*(1+rolloff). It must fit into the band
%     Fs. With up = 2 it does, up to rolloff = 1;
%   - the BER depends on the length of the equalizer in symbols, Morder/up
%     (default: 8 symbols). With rolloff = 0.2, Scheme A1, sw_size = 64 and
%     PTx = -3 dBm it is 1.04e-2 / 9.2e-3 / 8.5e-3 for 4 / 8 / 16 symbols, for
%     up = 2 and for up = 4. So if you change up, change Morder by the same
%     factor. (For rolloff = 0 the length has no effect on the BER.)
%   - the transmit mask Hrcos is not flat any more. Block [7] therefore does not
%     use it for the reference power sigpw of the stage-3 crosstalk. It uses
%     Hband, a rectangular mask with the width of the signal band. So sigpw is
%     the power inside the signal band for every rolloff.
%     (The legacy script measures the reference power of its AWG crosstalk
%     through Hrcos. For rolloff = 0 that is the same. For rolloff > 0 it reads
%     too low: here by 0.08 / 0.16 / 0.47 / 1.23 dB for rolloff = 0.1 / 0.2 /
%     0.5 / 1, with the other parameters as they are above.)

% Note on xt_wave_max
% Inf: every leak of a space switch is one waveform with its own random data.
% A number: at most that many waveforms are made, with the same total power.
% Use a whole number, 1 or more (a fraction is rounded down).
% Test (Scheme A2, 1.5e5 symbols, PTx close to the FEC limit, mean BER of 32 seeds):
%   sw_size    8 waveforms    16 waveforms    every leak (Inf)
%      32       1.040e-2        1.041e-2        1.043e-2
%      64       1.030e-2        1.040e-2        1.041e-2
%     128       3.670e-2        3.665e-2        3.660e-2      (at PTx = 10 dBm)
% The statistical error of each number is about 0.3 percent of the number.
% With 16 waveforms the BER is the same as with every leak. With 8 waveforms it
% is 1.1 percent too low at sw_size = 64: the sum of few signals has fewer large
% peaks than the sum of many. The search of main_three_stage_conventional finds
% the same required powers with xt_wave_max = 16 and is about 2.5 times faster.

%% 2. Values that follow from the parameters (legacy lines 55-70)
Mary = 2^mod_flag;  % number of constellation points (16 for 16QAM)
Fs = up*baudrate;  % sampling frequency = width of the simulated band [Hz]
Hrcos = rcosfilter(datasize*up, baudrate, Fs, rolloff);  % transmit mask (Nyquist)
assert(xt_wave_max >= 1, 'xt_wave_max must be 1 or more (Inf = one waveform per leak)');

%% 3. Transmission chain (order of legacy lines 84-229)
% The lines from "chain begin" to "chain end" are the same in
% main_three_stage_conventional. That script sets the same seed before every
% operating point. So this script repeats any point of its search:
% same parameters, same BER.
rng(seed);
% ---- chain begin ----
% stage_power(k) = total power after block [k] of the chain [dBm].
% step22_three_stage_one_point compares it with a budget and plots it.
stage_power = zeros(1, 9);

% [1] Transmitter of the target signal (legacy lines 84-99)
pin = PTx - 3*pol_flag;  % power of the simulated polarization [dBm]
[signal, data, data_mod] = TL_QAM(datasize, up, Hrcos, pin, mod_flag);
stage_power(1) = calc_signal_power(signal);

% [2] Fan-in and fan-out of the multicore fiber (legacy lines 101-107)
fiber_loss = 0;  % single-core fiber: no fan-in and no fan-out [dB]
if fiber_flag == 1
    fiber_loss = Fan_in_loss + Fan_out_loss;
end
signal = attenuation(signal, fiber_loss);
stage_power(2) = calc_signal_power(signal);

% [3] Stage-1 space switch, selector + selector (legacy lines 109-119)
% The other sw_size-1 inputs carry signals with the power of the target.
% Worst case: all of them have the wavelength of the target.
% A selector that is switched off still passes a little light: each of these
% signals leaks to the output of the target through TWO selectors.
sw1_loss = 2*selector_loss(sw_size);  % the target passes two selectors [dB]
sw1_xt_att = 2*sel_ex_ratio;  % a leak is blocked by two selectors [dB]
% The receiver is disturbed by the SUM of the leaks. The leaks are independent
% signals of equal power: every leak is one waveform with its own random data.
% xt_wave_max = Inf makes every leak. For a large switch this takes most of
% the run time (2 x 127 waveforms for sw_size = 128).
% A smaller xt_wave_max is faster: only xt_wave_max waveforms are made, and
% their power is raised so that the TOTAL power stays that of sw_size-1 leaks.
% The sum of 16 independent QAM signals is already close to Gaussian noise,
% like the sum of 127. The note on xt_wave_max in section 1 of
% step22_three_stage_one_point gives the size of the error.
num_xt = sw_size - 1;  % number of leaks
num_xt_wave = min(num_xt, floor(xt_wave_max));  % number of waveforms made
xt_boost = 10*log10(num_xt/num_xt_wave);  % extra power of one waveform [dB]
xt_power = pin - fiber_loss + xt_boost;  % power of one waveform [dBm]
crosstalk = zeros(datasize*up, 1);
for k = 1:num_xt_wave
    [xt, ~, ~] = TL_QAM(datasize, up, Hrcos, xt_power, mod_flag);
    crosstalk = crosstalk + xt;  % independent data in every waveform
end
signal = signal + attenuation(crosstalk, sw1_xt_att);  % target + leaks
signal = attenuation(signal, sw1_loss);
stage_power(3) = calc_signal_power(signal);

% [4] Aggregation coupler (legacy lines 123-132)
% One coupler and one EDFA carry all N wavelengths (no ULCF AWG here).
agg_coupler_loss = coupler_loss(N);
signal = attenuation(signal, agg_coupler_loss);
stage_power(4) = calc_signal_power(signal);

% [5] EDFA of the wavelength-routing switch (legacy lines 139-141)
% edfa_sat1 is shared by N wavelengths and by the polarizations.
% The gain lifts the signal to the share of the simulated field.
% The ASE in one channel spacing (signal_interval) belongs to this share too.
sat1 = edfa_sat1 - 3*pol_flag;  % output power of one polarization [dBm]
edfaGain = sat1 - 10*log10(N) - calc_signal_power(signal);
[signal, aseNoise] = amplified_by_EDFA3(signal, Fs, edfaGain, NF, sat1, N, ...
    signal_interval);
stage_power(5) = calc_signal_power(signal);

% [6] AWG (legacy lines 143-151)
% The carrier is on the center of the passband (shift = 0). The AWG has ONE
% input port, so it adds no crosstalk on the wavelength of the target.
signal = awg(signal, AWG_loss, 0, Fs, FWHM_AWG, AWG_XT, 1);
stage_power(6) = calc_signal_power(signal);

% [7] Stage-3 space switch (crosstalk made like legacy lines 172-183)
% The other sw_size-1 inputs come from the other wavelength-routing switches.
% They carry the SAME wavelength as the target, with the same power.
% sigpw is that power after the AWG filter: the power inside the signal band.
% It is measured through Hband, a rectangular mask with the width of the signal
% band (the same mask as the receive filter of block [10]).
% The legacy lines use the transmit mask Hrcos: the same for rolloff = 0.
if stage3_coupler_flag == 1
    % Scheme A2: selector + coupler. A coupler cannot block anything.
    sw3_loss = selector_loss(sw_size) + coupler_loss(sw_size);
    sw3_xt_att = sel_ex_ratio;  % a leak is blocked by ONE selector [dB]
else
    % Scheme A1: selector + selector, like stage 1.
    sw3_loss = 2*selector_loss(sw_size);
    sw3_xt_att = 2*sel_ex_ratio;  % a leak is blocked by two selectors [dB]
end
Hband = nyquistfilter(datasize*up, 0, Fs, baudrate*(1+rolloff));
sigpw = calc_signal_power(apply_filter(signal, Hband, 1));
xt_power = sigpw + xt_boost;  % power of one waveform [dBm]
crosstalk = zeros(datasize*up, 1);
for k = 1:num_xt_wave
    [xt, ~, ~] = TL_QAM(datasize, up, Hrcos, xt_power, mod_flag);
    crosstalk = crosstalk + xt;
end
signal = signal + attenuation(crosstalk, sw3_xt_att);  % target + leaks
signal = attenuation(signal, sw3_loss);
stage_power(7) = calc_signal_power(signal);

% [8] Fan-in and fan-out of the multicore fiber again (legacy lines 185-188)
signal = attenuation(signal, fiber_loss);
stage_power(8) = calc_signal_power(signal);

% [9] Pre-amplifier of the receiver (legacy lines 190-195)
% It carries one wavelength: only the polarizations share its output power.
sat2 = edfa_sat2 - 3*pol_flag;  % output power of one polarization [dBm]
edfaGain = sat2 - calc_signal_power(signal);
[signal, aseNoise2] = amplified_by_EDFA3(signal, Fs, edfaGain, NF2, sat2, 1, ...
    signal_interval);
stage_power(9) = calc_signal_power(signal);

% [10] Coherent receiver and BER (legacy lines 218-229)
% receive filter: brick wall with the width of the signal
H = nyquistfilter(length(signal), 0, Fs, baudrate*(1+rolloff));
signal = apply_filter(signal, H, 1);
% equalizer: trained with the first third of the symbols, then the taps stay
% (adequalizet does not use its fourth argument; 1/256 is the legacy value)
training_num = floor(datasize/3);
signal = adequalizet(signal, Mary, Morder, 1/256, ...
    data_mod(1:training_num), up);
% BER of the symbols after the training (mod_flag bits per symbol)
BER = measure_BER_QAM(signal(training_num+1:end), ...
    data(mod_flag*training_num+1:end), mod_flag);
% ---- chain end ----

%% 4. Result of the simulation
num_bits = mod_flag*(datasize - training_num);  % number of bits that were compared
fprintf('Operating point : PTx = %.1f dBm, space switches %d x %d, Scheme A%d\n', ...
    PTx, sw_size, sw_size, stage3_coupler_flag + 1);
fprintf('Switch size     : %d x %d ports (M*N = %d*%d)\n', sw_size*N, sw_size*N, ...
    sw_size, N);
fprintf('BER             : %.3e (%d errors in %d bits), FEC limit %.0e\n', BER, ...
    round(BER*num_bits), num_bits, BER_limit);

% SNR of the equalized symbols, measured against the transmitted symbols.
% Model: rx_sym = g*tx_sym + error. g is the complex gain of the wanted symbols.
rx_sym = signal(training_num+1:end);  % equalized symbols after the training
tx_sym = data_mod(training_num+1:end);  % transmitted symbols at the same instants
g = sum(conj(tx_sym).*rx_sym)/sum(abs(tx_sym).^2);  % least-squares estimate of g
err_sym = rx_sym - g*tx_sym;  % everything that is not the wanted symbol
SNR_sim = 10*log10(abs(g)^2*mean(abs(tx_sym).^2)/mean(abs(err_sym).^2));  % [dB]

%% 5. Closed-form power budget (formulas only, no random numbers)
% budget_target(k) = power of the TARGET after block [k] [dBm]
% budget_total(k)  = TOTAL power after block [k] [dBm]
%                    = target + crosstalk + ASE inside the simulated band Fs
% The simulation measures the total (stage_power), like a power meter does.
h_planck = 6.62607004e-34;  % Planck constant [J s]
f_opt = 299792458/1550e-9;  % optical frequency at the wavelength 1550 nm [Hz]
budget_target = zeros(1, 9);
budget_total = zeros(1, 9);

% [1] to [4]: losses in dB are subtracted
xt_sw1 = num_xt*10^(-sw1_xt_att/10);  % stage-1 crosstalk / target
budget_target(1) = pin;
budget_total(1) = pin;
budget_target(2) = budget_target(1) - fiber_loss;
budget_total(2) = budget_target(2);
budget_target(3) = budget_target(2) - sw1_loss;
budget_total(3) = budget_target(3) + 10*log10(1 + xt_sw1);
budget_target(4) = budget_target(3) - agg_coupler_loss;
budget_total(4) = budget_total(3) - agg_coupler_loss;

% [5] EDFA: the gain lifts the input to limit1. Then ASE is added.
% The output limit counts the signal and the ASE in the bandwidth signal_interval:
% both are scaled so that these two together have limit1 (see amplified_by_EDFA3).
% The total in Fs is close to limit1 (equal to it only for Fs = signal_interval).
limit1 = sat1 - 10*log10(N);  % output power of the simulated field [dBm]
G1 = 10^((limit1 - budget_total(4))/10);  % gain (linear)
F1 = 10^(NF/10);  % noise figure (linear)
ase1_mW = (G1*F1 - 1)*h_planck*f_opt*Fs/2*1e3;  % ASE, one polarization, in Fs [mW]
ase1_ref_mW = ase1_mW*signal_interval/Fs;  % ASE in the bandwidth signal_interval [mW]
scale1 = 10^(limit1/10)/(10^(limit1/10) + ase1_ref_mW);  % scaling to the output limit
budget_target(5) = budget_target(4) + 10*log10(G1*scale1);
budget_total(5) = 10*log10((10^(limit1/10) + ase1_mW)*scale1);
budget_ase1 = 10*log10(ase1_mW*scale1);  % ASE at the EDFA output, in Fs [dBm]

% [6] AWG: flat loss and the shape of the passband.
% The Gaussian passband removes a little power at the edges of the signal band.
% T_sig, T_ase, T_inband = mean power transmission of the passband shape.
Hawg = gaussfilter(datasize*up, 0, Fs, FWHM_AWG, AWG_XT, 1);  % amplitude mask
w_sig = Hrcos.^2/sum(Hrcos.^2);  % share of the signal power in every FFT bin
T_sig = sum(w_sig.*Hawg.^2);  % for the signal (weighted with its spectrum)
T_ase = mean(Hawg.^2);  % for white noise over the whole band Fs
T_inband = mean(Hband.^2.*Hawg.^2);  % white noise: the part inside the signal band
budget_target(6) = budget_target(5) - AWG_loss + 10*log10(T_sig);
sig6_mW = 10^(budget_target(6)/10)*(1 + xt_sw1);  % target + stage-1 crosstalk [mW]
ase6_mW = ase1_mW*scale1*10^(-AWG_loss/10);  % ASE after the flat loss only [mW]
budget_total(6) = 10*log10(sig6_mW + ase6_mW*T_ase);

% [7] Stage-3 switch: sw_size-1 leaks, each sw3_xt_att dB below sigpw.
% sigpw is everything inside the signal band after the AWG (mask Hband): the
% target, the stage-1 crosstalk and the part of the ASE that lies in this band.
% So a leak brings the noise of its own path with it.
% The target and the stage-1 crosstalk lie completely inside the signal band.
budget_sigpw = 10*log10(sig6_mW + ase6_mW*T_inband);  % [dBm]
xt_sw3_mW = num_xt*10^((budget_sigpw - sw3_xt_att)/10);  % at the switch input [mW]
budget_target(7) = budget_target(6) - sw3_loss;
budget_total(7) = 10*log10(10^(budget_total(6)/10) + xt_sw3_mW) - sw3_loss;

% [8] fan-in and fan-out
budget_target(8) = budget_target(7) - fiber_loss;
budget_total(8) = budget_total(7) - fiber_loss;

% [9] pre-amplifier: the same rules as the EDFA, for one wavelength
limit2 = sat2;  % output power of the simulated field [dBm]
G2 = 10^((limit2 - budget_total(8))/10);  % gain (linear)
F2 = 10^(NF2/10);  % noise figure (linear)
ase2_mW = (G2*F2 - 1)*h_planck*f_opt*Fs/2*1e3;  % ASE, one polarization, in Fs [mW]
ase2_ref_mW = ase2_mW*signal_interval/Fs;  % ASE in the bandwidth signal_interval [mW]
scale2 = 10^(limit2/10)/(10^(limit2/10) + ase2_ref_mW);  % scaling to the output limit
budget_target(9) = budget_target(8) + 10*log10(G2*scale2);
budget_total(9) = 10*log10((10^(limit2/10) + ase2_mW)*scale2);
budget_ase2 = 10*log10(ase2_mW*scale2);  % ASE at the pre-amplifier output [dBm]

%% 6. Closed-form SNR budget
% nsr_x = (power of disturbance x) / (power of the target), both inside the
% bandwidth of the signal (baudrate) and after the equalizer.
% The disturbances are independent, so their powers add:
%   1/SNR = nsr_ase1 + nsr_xt_sw1 + nsr_xt_sw3 + nsr_ase2
% Rule of thumb for an amplifier (see amplified_by_EDFA3):
%   SNR = P_in/(F*h*f*baudrate), P_in = input power of the channel, both pol.
%
% The passband of the AWG rounds the spectrum of the target. The equalizer makes
% it flat again. A disturbance that was added BEFORE the AWG (ASE of the EDFA,
% stage-1 crosstalk) is filtered and equalized together with the target: no change
% of SNR. A disturbance that is added AFTER the AWG (stage-3 crosstalk, ASE of the
% pre-amplifier) has a flat spectrum. The equalizer lifts it where it lifts the target.
% eq_penalty is this growth of the noise: mean(T)*mean(1/T) over the signal band.
% (It is small here, because the passband is centered on the signal.)
eq_penalty = T_sig*sum(w_sig./Hawg.^2);  % >= 1; equal to 1 for a flat passband
nsr_ase1 = (ase1_mW*baudrate/Fs)/(G1*10^(budget_target(4)/10));
nsr_xt_sw1 = xt_sw1;
nsr_xt_sw3 = xt_sw3_mW/10^(budget_target(6)/10)*eq_penalty;
nsr_ase2 = (ase2_mW*baudrate/Fs)/(G2*10^(budget_target(8)/10))*eq_penalty;
SNR_budget = -10*log10(nsr_ase1 + nsr_xt_sw1 + nsr_xt_sw3 + nsr_ase2);  % [dB]

% BER that white Gaussian noise with the SNR of the budget would give.
% The formula holds for a square constellation with Gray mapping (not for 32QAM).
% Expect the simulated BER a few percent ABOVE this value (about 6 percent for
% 16QAM near BER = 1e-2), plus the random error of the run: the equalizer output
% is a little smaller than the ideal constellation (see the notes in adequalizet).
BER_gauss = NaN;
if mod_flag ~= 5
    BER_gauss = 2/mod_flag*(1 - 1/sqrt(Mary)) ...
        *erfc(sqrt(3*10^(SNR_budget/10)/(2*(Mary - 1))));
end

%% 7. Tables
stage_names = {'Tx', 'Fan-in/out', 'Switch 1', 'Coupler', 'EDFA', 'AWG', ...
    'Switch 3', 'Fan-in/out', 'Pre-amp'};
fprintf('\nPower after every block [dBm] (one polarization, inside the band Fs)\n');
fprintf('  %-18s %11s %11s %11s\n', 'block', 'simulation', 'budget', 'budget');
fprintf('  %-18s %11s %11s %11s\n', '', '(total)', '(total)', '(target)');
for k = 1:9
    fprintf('  [%d] %-14s %11.3f %11.3f %11.3f\n', k, stage_names{k}, ...
        stage_power(k), budget_total(k), budget_target(k));
end
ase1_sim = calc_signal_power(aseNoise);  % ASE at the EDFA output, in Fs [dBm]
ase2_sim = calc_signal_power(aseNoise2);  % ASE at the pre-amplifier output [dBm]
fprintf('  %-18s %11.3f %11.3f\n', 'ASE of EDFA', ase1_sim, budget_ase1);
fprintf('  %-18s %11.3f %11.3f\n', 'ASE of pre-amp', ase2_sim, budget_ase2);
fprintf('  %-18s %11.3f %11.3f\n', 'sigpw (block [7])', sigpw, budget_sigpw);

fprintf('\nSNR contributions in the signal bandwidth [dB]\n');
fprintf('  ASE of the EDFA                 %7.2f\n', -10*log10(nsr_ase1));
fprintf('  crosstalk of the stage-1 switch %7.2f\n', -10*log10(nsr_xt_sw1));
fprintf('  crosstalk of the stage-3 switch %7.2f\n', -10*log10(nsr_xt_sw3));
fprintf('  ASE of the pre-amplifier        %7.2f\n', -10*log10(nsr_ase2));
fprintf('  all together (budget)           %7.2f\n', SNR_budget);
fprintf('  simulation                      %7.2f\n', SNR_sim);
fprintf('  (noise gain of the equalizer behind the AWG: %.2f dB)\n', ...
    10*log10(eq_penalty));
fprintf('BER of Gaussian noise with the SNR of the budget: %.3e\n', BER_gauss);

%% 8. Self-checks
% --- Self-check 1: the power after every block follows the budget ---
diff_power = max(abs(stage_power - budget_total));  % largest difference [dB]
assert(diff_power < 0.1, ...
    'the power after a block differs from the closed-form budget by 0.1 dB or more');
assert(abs(ase1_sim - budget_ase1) < 0.1, ...
    'the ASE power of the EDFA differs from (G*F - 1)*h*f*Fs/2 by 0.1 dB or more');
assert(abs(ase2_sim - budget_ase2) < 0.1, ...
    'the ASE power of the pre-amplifier differs from the formula by 0.1 dB or more');
assert(abs(sigpw - budget_sigpw) < 0.1, ...
    'the reference power of the stage-3 crosstalk differs from the budget');
fprintf('\nSelf-check 1 passed: power after every block = budget within 0.1 dB ');
fprintf('(largest difference %.3f dB)\n', diff_power);

% --- Self-check 2: the SNR of the received symbols follows the SNR budget ---
if rolloff == 0
    assert(abs(SNR_sim - SNR_budget) < 0.7, ...
        'the SNR of the received symbols differs from the SNR budget by 0.7 dB or more');
    fprintf('Self-check 2 passed: simulated SNR = SNR budget within 0.7 dB ');
    fprintf('(difference %+.2f dB)\n', SNR_sim - SNR_budget);
else
    % The SNR budget assumes a rectangular spectrum and a matched receive filter.
    fprintf('Self-check 2 skipped: the SNR budget is valid for rolloff = 0 only.\n');
end

%% 9. Figures
% MATLAB R2025a and later can draw figures with a dark background (dark theme).
% Black lines cannot be seen there, so both figures ask for the light theme.
% Older versions have no property Theme; isprop is then false and nothing is done.

% Figure 1: level diagram. Markers = simulation, black line = closed-form budget.
plot_level_diagram(stage_names, stage_power);
if isprop(gcf, 'Theme')
    set(gcf, 'Theme', 'light');
end
hold on;
plot(1:9, budget_total, 'k-');
legend('simulation (total power)', 'closed-form budget', 'Location', 'southwest');
title(sprintf('Level diagram: PTx = %.1f dBm, M = %d, Scheme A%d', PTx, sw_size, ...
    stage3_coupler_flag + 1));

% Figure 2: received symbols after the equalizer (constellation diagram)
ideal_sym = my_qammod((0:Mary-1).', Mary);  % the Mary ideal constellation points
figure;
if isprop(gcf, 'Theme')
    set(gcf, 'Theme', 'light');
end
plot(real(rx_sym), imag(rx_sym), '.', 'MarkerSize', 4);
hold on;
plot(real(ideal_sym), imag(ideal_sym), 'k+', 'MarkerSize', 8, 'LineWidth', 1.2);
grid on;
axis equal;
xlabel('In-phase component');
ylabel('Quadrature component');
title(sprintf('Received symbols: SNR = %.1f dB, BER = %.2e', SNR_sim, BER));
legend('received symbols', 'ideal points', 'Location', 'northeastoutside');
