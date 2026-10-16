%% step21_two_stage_one_point - ULCF two-stage optical switch, ONE operating point
% This script sends one signal through the two-stage switch and counts the bit errors.
% One run = one operating point = one transmitter power, one size of the DC switch
% and one number of AWG input ports.
% The search over many operating points is the script main_two_stage_ULCF.
%
% The switch (JOCN 2018)
%   N DC switches (M x M) in front, M wavelength-routing switches (N x N) behind them.
%   Port count = M*N. DC = delivery and coupling.
%   A wavelength-routing switch with ULCF AWGs that have K input ports consists of
%   K couplers ((N/K) x 1), K EDFAs, K 1 x 2 splitters and one pair of ULCF AWGs
%   (K x (N/2) each). Every coupler and every EDFA carries N/K wavelengths.
%
% Path of the target signal (the numbers are the blocks of section 3)
%   [1] transmitter -> [2] fan-in/fan-out of the multicore fiber -> [3] DC switch
%   -> [4] aggregation coupler -> [5] EDFA -> [6] 1 x 2 splitter and ULCF AWG
%   -> [7] crosstalk of the AWG is added -> [8] fan-in/fan-out
%   -> [9] pre-amplifier -> [10] coherent receiver, BER
%
% What is simulated
%   ONE polarization of ONE wavelength channel (complex field, unit sqrt(W)).
%   Other signals appear only as crosstalk on the same wavelength:
%     - the other M-1 inputs of the DC switch, each dcs_ex_ratio dB below the target;
%     - the other K-1 inputs of the ULCF AWG, each AWG_XT dB below the signal.
%   Noise: ASE of the EDFA and ASE of the pre-amplifier.
%
% How to use this file
%   1. Run setup_path once (in the folder "matlab"). Then run this file (F5).
%   2. Read the two printed tables: power after every block, SNR contributions.
%   3. Change ONE parameter of section 1 (PTx, dcs_input_port_num or ULCF_deg).
%      Predict how the tables change. Then run again and compare.
%
% Default operating point
%   32QAM, 8 x 8 DC switch, ULCF AWG with 12 input ports (768 x 768 switch),
%   PTx = -4 dBm. The BER is about 7.6e-3: just below the FEC limit 1e-2.
%
% Letters and names used here
%   N      = number of wavelength channels
%   M      = size of the DC switch = dcs_input_port_num (the port count is M*N)
%   K      = number of input ports of the ULCF AWG = ULCF_deg
%   Mary   = number of constellation points = 2^mod_flag (mod_flag = bits per symbol)
%   Morder = order of the equalizer; up = oversampling rate (samples per symbol)
%   PTx    = transmitter power of one channel, both polarizations together [dBm]
%   pin    = power of the ONE simulated polarization = PTx - 3 dB [dBm]
%   In the help text of the library the letters N and M can mean other things
%   (number of samples, number of ports, filter order): read the "Inputs" list there.
%
% Reference data (folder ref_data)
%   legacy_ber_points.csv    : BER of the unchanged legacy code at 8 operating points.
%                              Section 4 prints the legacy BER, if this run is one of them.
%   budget_two_stage_ref.csv : the numbers of the two tables of section 7 for the
%                              default parameters (columns: kind, name, value, unit).
%                              No script reads it: open it and compare by eye.
%
% Legacy: TL_switch_coherent_search_Nyquist_07.m, lines 84-229 (the body of its loops).
% The order of the chain and the variable names are the ones of the legacy script.
% Differences from the legacy script (all on purpose)
%   - The oversampling rate up (samples per symbol) and mod_flag (bits per symbol)
%     are two variables. The legacy script used one number for both.
%   - Output power of the EDFA for one channel: the EDFA carries N/ULCF_deg
%     wavelengths (legacy: N), and with polarization multiplexing the simulated
%     polarization gets half of the channel power (legacy: all of it).
%   - Output limit of the two amplifiers: the signal shares the output power with
%     the ASE inside the channel spacing signal_interval (legacy: with all ASE
%     inside the simulated band Fs; signal_interval was set there but not used).
%   - Pre-amplifier: ASE of one polarization (legacy: ASE of both polarizations).
%     amplified_by_EDFA3 with N = 1 replaces the legacy function amplified_by_EDFA2.
%   - In front of the AWGs there is a 1 x 2 splitter with the loss splitter_loss
%     = coupler_loss(2) = 3.5 dB. The legacy script had a de-interleaver there
%     with IL_loss = 3.5 dB. The loss is the same, so the results are the same.
%   - The reference power sigpw of the AWG crosstalk is measured through the
%     rectangular mask Hband of the signal band (legacy line 176: through the
%     transmit mask Hrcos). For rolloff = 0 the two masks are equal.
%   - The equalizer order Morder = 16 is really used. (The legacy script declared
%     Morder = 16, but its call of adequalizet in line 223 passed 512.)
%   - The "electrical noise" block and the splitter in front of the EDFA (legacy
%     lines 134-137, its loss was always 0 dB) are removed (no effect). The legacy
%     name of that loss, splitter_loss, now belongs to the 1 x 2 splitter.
%   - ULCF_dev_freq replaces the if-chain of the frequency deviation, and awg
%     replaces awg4nyquistWDM (the two legacy functions did the same).
%   - The random numbers have a fixed seed.
%   - One operating point and one modulation format per run (legacy: loops).
%   - Removed, because they had no effect or were never used: edfa_flag and the
%     receiver without pre-amplifier (the pre-amplifier is always there), sw_str,
%     N_all, WDM_coupler_loss, R, the variables before_..._power
%     and before_lastEDFA_loss, the 8QAM branches.
%   - training_num = floor(datasize/3) (legacy: datasize/3): any datasize works.
%   - Fan_in_loss and Fan_out_loss are parameters of section 1 (legacy: set in
%     the chain). BER_limit replaces the number 1e-2 in the code.
%   - New names: up, Hband, target_port, fiber_loss, sat1, sat2, seed, BER_limit,
%     stage_power.

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['step21_two_stage_one_point: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters (legacy lines 3-42)
datasize = 3e4;  % number of symbols (legacy: 1.5e5; 3e4 runs in a few seconds)
PTx = -4;  % transmitter power of one channel, both polarizations together [dBm]
dcs_input_port_num = 8;  % size M of the M x M DC switch
mod_flag = 5;  % bits per symbol: 2 = QPSK, 4 = 16QAM, 5 = 32QAM, 6 = 64QAM
up = 2;  % oversampling rate = samples per symbol (see the note below)
baudrate = 24e9;  % symbol rate [Hz]
pol_flag = 1;  % 0 = one polarization, 1 = polarization multiplexing
fiber_flag = 1;  % 0 = single-core fiber, 1 = multicore fiber
Fan_in_loss = 1.5;  % loss of the fan-in device of the multicore fiber [dB]
Fan_out_loss = 1.5;  % loss of the fan-out device of the multicore fiber [dB]
flg_NWDM = 1;  % 0 = carrier on the center of the AWG passband, 1 = quasi-Nyquist WDM
N = 96;  % number of wavelength channels
NF = 5;  % noise figure of the EDFA [dB]
edfa_sat1 = 20;  % saturation power of the EDFA: all channels, both pol. [dBm]
edfa_sat2 = 10;  % saturation power of the pre-amplifier, both polarizations [dBm]
NF2 = 4;  % noise figure of the pre-amplifier [dB]
rolloff = 0;  % roll-off factor of the Nyquist pulse (0 = rectangular spectrum)
signal_interval = 50e9;  % channel spacing [Hz]
dcs_ex_ratio = 36;  % extinction ratio of the DC switch [dB]
ULCF_flag = 1;  % 0 = conventional AWG with one input port, 1 = ULCF AWG
ULCF_deg = 12;  % number K of input ports of the ULCF AWG: 1, 2, 4, 6, 8, 12 or 16
splitter_loss = coupler_loss(2);  % 1 x 2 splitter in front of the pair of ULCF AWGs [dB]
AWG_loss = 9;  % loss of the AWG at the center of its passband [dB]
FWHM_AWG = 66.6e9;  % 3-dB width of the AWG passband [Hz]
AWG_XT = 32;  % crosstalk of the AWG: one leak is 32 dB below the signal [dB]
Morder = 16;  % order of the adaptive equalizer (it has Morder + 1 taps)
seed = 1;  % seed of the random numbers (data and noise)
BER_limit = 1e-2;  % FEC limit: a BER below it is error free after error correction

% Note on up (oversampling rate)
% Fs = up*baudrate is the width of the simulated band: 48 GHz, from -24 to +24 GHz.
% The signal band is -12 to +12 GHz for rolloff = 0 and at most -24 to +24 GHz
% (rolloff = 1). So up = 2 holds the signal band for every rolloff.
% That is enough for this chain:
%   - Crosstalk and ASE are added on the wavelength of the target, and the receive
%     filter of block [10] keeps only the signal band.
%   - The AWG is a mask on the frequency axis. The center of its passband is 17.5
%     to 29.5 GHz above the carrier (12.5 GHz + frequency deviation). For
%     ULCF_deg = 8, 12 and 16 this is outside the simulated band. That does not
%     matter: the signal sees only the slope of the passband over the signal band,
%     and there the mask has the same values for every up.
%   - The output limit of an amplifier counts the ASE inside signal_interval, not
%     the ASE inside Fs. Here the target after the EDFA has 7.88 dBm for every up.
% BER and SNR for up = 2 and up = 4 agree within the random error of one run.
% What changes with up: the run time (it grows with up), the noise samples and
% the total powers of section 7. They count all ASE inside Fs. The gain of the
% pre-amplifier is set from such a total power, so the target after it moves a
% little too: 6.89 / 6.83 / 6.78 dBm for up = 2 / 4 / 8. The SNR does not change.
% up does not depend on mod_flag.
% Use a larger up
%   - for a signal on another wavelength channel inside the simulated band:
%     Fs/2 must be at least offset + baudrate*(1+rolloff)/2;
%   - for a plot of the waveform (more samples per symbol give a smoother curve).

% Note on rolloff
% Keep rolloff = 0 unless you study the roll-off itself. With rolloff > 0:
%   - self-check 2 is skipped (the SNR budget assumes a rectangular spectrum);
%   - the signal band is baudrate*(1+rolloff) wide. Block [7] measures the
%     reference power sigpw of the AWG crosstalk through the rectangular mask
%     Hband of this band, so sigpw holds all of the signal for every rolloff.
%     (Legacy line 176 used the mask Hrcos, which is not flat for rolloff > 0.
%     It read sigpw too low: by 0.09 / 0.19 / 0.55 / 1.41 dB for rolloff = 0.1 /
%     0.2 / 0.5 / 1. The crosstalk was weaker by that.)

% Note on ULCF_flag = 0 (conventional AWG)
% One coupler and one EDFA carry all N wavelengths. There is no 1 x 2 splitter
% and no AWG crosstalk. ULCF_deg still selects the frequency deviation of block [6]:
% set ULCF_deg = 1 together with ULCF_flag = 0.

%% 2. Values that follow from the parameters (legacy lines 55-70)
Mary = 2^mod_flag;  % number of constellation points (32 for 32QAM)
Fs = up*baudrate;  % sampling frequency = width of the simulated band [Hz]
Hrcos = rcosfilter(datasize*up, baudrate, Fs, rolloff);  % transmit mask (Nyquist)
if ULCF_flag == 1
    % every coupler and every EDFA carries N/ULCF_deg wavelengths: a whole number
    assert(mod(N, ULCF_deg) == 0, 'N must be a multiple of ULCF_deg');
end

%% 3. Transmission chain (legacy lines 84-229)
% The lines from "chain begin" to "chain end" are the same in main_two_stage_ULCF.
% That script sets the same seed before every operating point.
% So this script repeats any point of its search: same parameters, same BER.
rng(seed);
% ---- chain begin ----
% stage_power(k) = total power after block [k] of the chain [dBm].
% step21_two_stage_one_point compares it with a budget and plots it.
stage_power = zeros(1, 9);

% [1] Transmitters (legacy lines 84-99)
% One signal per input port of the DC switch. The middle port is the target.
pin = PTx - 3*pol_flag;  % power of the simulated polarization [dBm]
target_port = ceil(dcs_input_port_num/2);  % input port of the target signal
signal = zeros(datasize*up, dcs_input_port_num);
for k = 1:dcs_input_port_num
    if k == target_port
        [signal(:, k), data, data_mod] = ...
            TL_QAM(datasize, up, Hrcos, pin, mod_flag);
    else
        [signal(:, k), ~, ~] = TL_QAM(datasize, up, Hrcos, pin, mod_flag);
    end
end
stage_power(1) = calc_signal_power(signal(:, target_port));

% [2] Fan-in and fan-out of the multicore fiber (legacy lines 101-107)
fiber_loss = 0;  % single-core fiber: no fan-in and no fan-out [dB]
if fiber_flag == 1
    fiber_loss = Fan_in_loss + Fan_out_loss;
end
signal = attenuation(signal, fiber_loss);
stage_power(2) = calc_signal_power(signal(:, target_port));

% [3] DC switch (legacy lines 109-119)
% Every input has the loss of the switch. An input that is switched off still
% leaks to the output: it arrives dcs_ex_ratio dB weaker and adds to the target.
dcs_loss = DCS_loss(dcs_input_port_num);
signal = attenuation(signal, dcs_loss);
for k = 1:dcs_input_port_num
    if k ~= target_port
        signal(:, k) = attenuation(signal(:, k), dcs_ex_ratio);
    end
end
signal = sum(signal, 2);  % output port of the DC switch: target + leaks
stage_power(3) = calc_signal_power(signal);

% [4] Aggregation coupler (legacy lines 123-132)
% With a ULCF AWG the N wavelengths are shared by ULCF_deg couplers and EDFAs.
N_agg = N;  % number of wavelengths on one coupler and one EDFA
if ULCF_flag == 1
    N_agg = N_agg/ULCF_deg;
end
agg_coupler_loss = coupler_loss(N_agg);
signal = attenuation(signal, agg_coupler_loss);
stage_power(4) = calc_signal_power(signal);

% [5] EDFA of the wavelength-routing switch (legacy lines 139-141)
% edfa_sat1 is shared by N_agg wavelengths and by the polarizations.
% The gain lifts the signal to the share of the simulated field.
% The ASE inside the channel spacing signal_interval counts for this share too:
% the amplifier scales signal and ASE down a little (step 3 of the function).
sat1 = edfa_sat1 - 3*pol_flag;  % output power of one polarization [dBm]
edfaGain = sat1 - 10*log10(N_agg) - calc_signal_power(signal);
[signal, aseNoise] = amplified_by_EDFA3(signal, Fs, edfaGain, NF, sat1, ...
    N_agg, signal_interval);
stage_power(5) = calc_signal_power(signal);

% [6] 1 x 2 splitter and AWG (legacy lines 143-171)
AWG_loss_temp = AWG_loss;
if ULCF_flag == 1
    AWG_loss_temp = AWG_loss_temp + splitter_loss;  % add the 1 x 2 splitter
end
if flg_NWDM == 0
    shift = 0;  % carrier on the center of the AWG passband [Hz]
else
    % quasi-Nyquist WDM grid: the carrier is 12.5 GHz off the passband center.
    % For the worst input port of a ULCF AWG it is dev_freq further away.
    dev_freq = ULCF_dev_freq(ULCF_deg);
    shift = 12.5e9 + dev_freq;
end
signal = awg(signal, AWG_loss_temp, shift, Fs, FWHM_AWG, AWG_XT, 1);
stage_power(6) = calc_signal_power(signal);

% [7] In-band crosstalk of the ULCF AWG (legacy lines 172-183)
% The other ULCF_deg - 1 input ports can carry the same wavelength. Each of them
% leaks to this output, AWG_XT dB below the power of the signal after the AWG.
% sigpw is that power: the power inside the signal band. It is measured through
% Hband, a rectangular mask of the signal band (width baudrate*(1+rolloff)).
% (Legacy line 176 measured through the mask Hrcos. For rolloff = 0 the two
% masks are equal.)
Hband = nyquistfilter(datasize*up, 0, Fs, baudrate*(1+rolloff));
if ULCF_flag == 1
    AWG_crosstalk = zeros(datasize*up, ULCF_deg - 1);
    sigpw = calc_signal_power(apply_filter(signal, Hband, 1));
    for k = 1:ULCF_deg-1
        [AWG_crosstalk(:, k), ~, ~] = ...
            TL_QAM(datasize, up, Hrcos, sigpw, mod_flag);
    end
    AWG_crosstalk = attenuation(AWG_crosstalk, AWG_XT);
    AWG_crosstalk = sum(AWG_crosstalk, 2);
    signal = signal + AWG_crosstalk;
end
stage_power(7) = calc_signal_power(signal);

% [8] Fan-in and fan-out of the multicore fiber again (legacy lines 185-188)
signal = attenuation(signal, fiber_loss);
stage_power(8) = calc_signal_power(signal);

% [9] Pre-amplifier of the receiver (legacy lines 190-195)
% It carries one wavelength: only the polarizations share its output power.
sat2 = edfa_sat2 - 3*pol_flag;  % output power of one polarization [dBm]
edfaGain = sat2 - calc_signal_power(signal);
[signal, aseNoise2] = amplified_by_EDFA3(signal, Fs, edfaGain, NF2, sat2, ...
    1, signal_interval);
stage_power(9) = calc_signal_power(signal);

% [10] Coherent receiver and BER (legacy lines 218-229)
% receive filter: brick wall with the width of the signal
H = nyquistfilter(length(signal), 0, Fs, baudrate*(1+rolloff));
signal = apply_filter(signal, H, 1);
% equalizer: trained with the first third of the symbols, then frozen
% (adequalizet does not use its fourth argument; 1/256 is the legacy value)
training_num = floor(datasize/3);
signal = adequalizet(signal, Mary, Morder, 1/256, ...
    data_mod(1:training_num), up);
% BER of the symbols after the training (mod_flag bits per symbol)
BER = measure_BER_QAM(signal(training_num+1:end), ...
    data(mod_flag*training_num+1:end), mod_flag);
% ---- chain end ----

%% 4. Result of the simulation (new, not in the legacy script)
num_bits = mod_flag*(datasize - training_num);  % number of bits that were compared
fprintf('Operating point : PTx = %.1f dBm, DC switch %d x %d, AWG with %d inputs\n', ...
    PTx, dcs_input_port_num, dcs_input_port_num, ULCF_deg);
fprintf('Switch size     : %d x %d ports (M*N = %d*%d)\n', dcs_input_port_num*N, ...
    dcs_input_port_num*N, dcs_input_port_num, N);
fprintf('BER             : %.3e (%d errors in %d bits), FEC limit %.0e\n', BER, ...
    round(BER*num_bits), num_bits, BER_limit);

% BER of the legacy code at the same operating point, if the reference file has it.
% File ref_data/legacy_ber_points.csv (made with the unchanged legacy code):
%   line 1  : the header
%   column 1: mod_flag, column 2: ULCF_deg, column 3: dcs_input_port_num,
%   column 4: PTx_dBm, column 5: datasize (1.5e5), column 6: seed, column 7: BER
% The legacy run had its own numerical settings (oversampling rate = mod_flag,
% 513 equalizer taps), so its noise samples are not the ones of this script.
% What to expect for the ratio this run / legacy (means of 5 seeds, 1.5e5 symbols):
%   ULCF_deg = 1 : 0.97 to 1.06, about the same BER. (The equalizer of this
%                  script has 17 taps. The 513 taps of the legacy run add a little
%                  noise of their own: 1 to 2 percent of the BER.)
%   ULCF_deg > 1 : 0.92 to 0.97. The BER is lower, because the EDFA of this script
%                  gives one channel the power sat/(N/ULCF_deg) (legacy: sat/N).
%   The default point has 0.92. With datasize = 3e4 the mean of 10 seeds is 0.95
%   there, and seed = 1 gives 0.99.
%   Random error of this run: about 4 percent of the BER for 700 counted bit
%   errors, about 30 percent for 10 counted bit errors.
% The comparison is valid only if all other parameters are the ones of section 1.
% The file is not needed: without it nothing is printed.
main_folder = fileparts(which('step21_two_stage_one_point'));  % the folder matlab/main
legacy_file = fullfile(fileparts(main_folder), 'ref_data', 'legacy_ber_points.csv');
if ULCF_flag == 1 && exist(legacy_file, 'file') == 2
    legacy_points = readmatrix(legacy_file, 'NumHeaderLines', 1);
    % the row of the file that belongs to this operating point
    legacy_row = find(legacy_points(:, 1) == mod_flag ...
        & legacy_points(:, 2) == ULCF_deg ...
        & legacy_points(:, 3) == dcs_input_port_num & legacy_points(:, 4) == PTx);
    if isscalar(legacy_row)
        BER_legacy = legacy_points(legacy_row, 7);  % BER of the legacy code
        fprintf('Legacy code     : %.3e at this point (%d symbols, legacy settings); ', ...
            BER_legacy, legacy_points(legacy_row, 5));
        fprintf('this run / legacy = %.2f\n', BER/BER_legacy);
    else
        fprintf('Legacy code     : this point is not in ref_data/legacy_ber_points.csv\n');
    end
end

% SNR of the equalized symbols, measured against the transmitted symbols.
% Model: rx_sym = g*tx_sym + error. g is the complex gain of the wanted symbols.
rx_sym = signal(training_num+1:end);  % equalized symbols after the training
tx_sym = data_mod(training_num+1:end);  % transmitted symbols at the same instants
g = sum(conj(tx_sym).*rx_sym)/sum(abs(tx_sym).^2);  % least-squares estimate of g
err_sym = rx_sym - g*tx_sym;  % everything that is not the wanted symbol
SNR_sim = 10*log10(abs(g)^2*mean(abs(tx_sym).^2)/mean(abs(err_sym).^2));  % [dB]

%% 5. Closed-form power budget (new, not in the legacy script)
% budget_target(k) = power of the TARGET after block [k] [dBm]
% budget_total(k)  = TOTAL power after block [k] [dBm]
%                    = target + crosstalk + ASE inside the simulated band Fs
% The simulation measures the total (stage_power), like a power meter does.
h_planck = 6.62607004e-34;  % Planck constant [J s]
f_opt = 299792458/1550e-9;  % optical frequency at the wavelength 1550 nm [Hz]
budget_target = zeros(1, 9);
budget_total = zeros(1, 9);

% [1] to [4]: losses in dB are subtracted
xt_dcs = (dcs_input_port_num - 1)*10^(-dcs_ex_ratio/10);  % DC crosstalk / target
budget_target(1) = pin;
budget_total(1) = pin;
budget_target(2) = budget_target(1) - fiber_loss;
budget_total(2) = budget_target(2);
budget_target(3) = budget_target(2) - dcs_loss;
budget_total(3) = budget_target(3) + 10*log10(1 + xt_dcs);
budget_target(4) = budget_target(3) - agg_coupler_loss;
budget_total(4) = budget_total(3) - agg_coupler_loss;

% [5] EDFA: the gain lifts the input to limit1. Then ASE is added.
% The output limit counts the signal and the ASE inside signal_interval:
% both are scaled by scale1, so that these two together have limit1
% (step 3 of amplified_by_EDFA3). The total power counts all ASE inside Fs.
% So it is close to limit1, and equal to limit1 only if Fs = signal_interval.
limit1 = sat1 - 10*log10(N_agg);  % output power of the simulated field [dBm]
G1 = 10^((limit1 - budget_total(4))/10);  % gain (linear)
F1 = 10^(NF/10);  % noise figure (linear)
ase1_mW = (G1*F1 - 1)*h_planck*f_opt*Fs/2*1e3;  % ASE, one polarization, in Fs [mW]
ase1_ref_mW = ase1_mW*signal_interval/Fs;  % ASE in the bandwidth signal_interval [mW]
scale1 = 10^(limit1/10)/(10^(limit1/10) + ase1_ref_mW);  % scaling to the output limit
budget_target(5) = budget_target(4) + 10*log10(G1*scale1);
budget_total(5) = 10*log10((10^(limit1/10) + ase1_mW)*scale1);
budget_ase1 = 10*log10(ase1_mW*scale1);  % ASE at the EDFA output, in Fs [dBm]

% [6] AWG: flat loss and the shape of the passband.
% The passband is not centered on the signal, so it removes a part of the power.
% T_sig, T_ase, T_inband = mean power transmission of the passband shape.
Hawg = gaussfilter(datasize*up, shift, Fs, FWHM_AWG, AWG_XT, 1);  % amplitude mask
w_sig = Hrcos.^2/sum(Hrcos.^2);  % share of the signal power in every FFT bin
T_sig = sum(w_sig.*Hawg.^2);  % for the signal (weighted with its spectrum)
T_ase = mean(Hawg.^2);  % for white noise over the whole band Fs
T_inband = mean(Hband.^2.*Hawg.^2);  % white noise: the part inside the signal band
budget_target(6) = budget_target(5) - AWG_loss_temp + 10*log10(T_sig);
sig6_mW = 10^(budget_target(6)/10)*(1 + xt_dcs);  % target + DC-switch crosstalk [mW]
ase6_mW = ase1_mW*scale1*10^(-AWG_loss_temp/10);  % ASE after the flat loss only [mW]
budget_total(6) = 10*log10(sig6_mW + ase6_mW*T_ase);

% [7] AWG crosstalk: ULCF_deg - 1 leaks, each AWG_XT dB below sigpw.
% The chain measures sigpw through the mask Hband of the signal band. The
% target and the DC-switch crosstalk lie inside this band: they pass completely.
% Of the ASE only the part inside the band passes: factor T_inband.
budget_sigpw = 10*log10(sig6_mW + ase6_mW*T_inband);  % [dBm]
xt_awg_mW = 0;  % no ULCF AWG: no crosstalk from other input ports [mW]
if ULCF_flag == 1
    xt_awg_mW = (ULCF_deg - 1)*10^((budget_sigpw - AWG_XT)/10);
end
budget_target(7) = budget_target(6);
budget_total(7) = 10*log10(10^(budget_total(6)/10) + xt_awg_mW);

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

%% 6. Closed-form SNR budget (new, not in the legacy script)
% nsr_x = (power of disturbance x) / (power of the target), both inside the
% bandwidth of the signal (baudrate) and after the equalizer.
% The disturbances are independent, so their powers add:
%   1/SNR = nsr_ase1 + nsr_xt_dcs + nsr_xt_awg + nsr_ase2
% Rule of thumb for an amplifier (see amplified_by_EDFA3):
%   SNR = P_in/(F*h*f*baudrate), P_in = input power of the channel, both pol.
%
% The passband of the AWG tilts the spectrum of the target. The equalizer removes
% the tilt. A disturbance that was added BEFORE the AWG (ASE of the EDFA, DC-switch
% crosstalk) is tilted and equalized together with the target: no change of SNR.
% A disturbance that is added AFTER the AWG (AWG crosstalk, ASE of the pre-amplifier)
% has a flat spectrum. The equalizer lifts it where it lifts the target.
% eq_penalty is this growth of the noise: mean(T)*mean(1/T) over the signal band.
eq_penalty = T_sig*sum(w_sig./Hawg.^2);  % >= 1; equal to 1 for a flat passband
nsr_ase1 = (ase1_mW*baudrate/Fs)/(G1*10^(budget_target(4)/10));
nsr_xt_dcs = xt_dcs;
nsr_xt_awg = xt_awg_mW/10^(budget_target(7)/10)*eq_penalty;
nsr_ase2 = (ase2_mW*baudrate/Fs)/(G2*10^(budget_target(8)/10))*eq_penalty;
SNR_budget = -10*log10(nsr_ase1 + nsr_xt_dcs + nsr_xt_awg + nsr_ase2);  % [dB]

%% 7. Tables (new, not in the legacy script)
stage_names = {'Tx', 'Fan-in/out', 'DC switch', 'Coupler', 'EDFA', 'AWG', ...
    'AWG crosstalk', 'Fan-in/out', 'Pre-amp'};
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
if ULCF_flag == 1
    fprintf('  %-18s %11.3f %11.3f\n', 'sigpw (block [7])', sigpw, budget_sigpw);
end

fprintf('\nSNR contributions in the signal bandwidth [dB]\n');
fprintf('  ASE of the EDFA            %7.2f\n', -10*log10(nsr_ase1));
fprintf('  crosstalk of the DC switch %7.2f\n', -10*log10(nsr_xt_dcs));
fprintf('  crosstalk of the AWG       %7.2f\n', -10*log10(nsr_xt_awg));
fprintf('  ASE of the pre-amplifier   %7.2f\n', -10*log10(nsr_ase2));
fprintf('  all together (budget)      %7.2f\n', SNR_budget);
fprintf('  simulation                 %7.2f\n', SNR_sim);
fprintf('  (noise gain of the equalizer behind the AWG: %.2f dB)\n', ...
    10*log10(eq_penalty));

%% 8. Self-checks (new, not in the legacy script)
% The simulated values are averages over a finite number of random samples.
% With datasize = 3e4 their random error is about 0.02 dB (power) and 0.05 dB (SNR).
% With a much smaller datasize a check can fail although the code is correct.

% --- Self-check 1: the power after every block follows the budget ---
diff_power = max(abs(stage_power - budget_total));  % largest difference [dB]
assert(diff_power < 0.1, ...
    'the power after a block differs from the closed-form budget by 0.1 dB or more');
assert(abs(ase1_sim - budget_ase1) < 0.1, ...
    'the ASE power of the EDFA differs from (G*F - 1)*h*f*Fs/2 by 0.1 dB or more');
assert(abs(ase2_sim - budget_ase2) < 0.1, ...
    'the ASE power of the pre-amplifier differs from the formula by 0.1 dB or more');
if ULCF_flag == 1
    assert(abs(sigpw - budget_sigpw) < 0.1, ...
        'the reference power of the AWG crosstalk differs from the budget');
end
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

%% 9. Figures (new, not in the legacy script)
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
title(sprintf('Level diagram: PTx = %.1f dBm, M = %d, K = %d', PTx, ...
    dcs_input_port_num, ULCF_deg));

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
