%% main_three_stage_conventional - Port count of the three-stage switch versus power
% This script answers the question of JLT 2025, Fig. 6 and Table V: how many ports
% can the conventional three-stage switch (Schemes A1 and A2) have for a given
% transmitter power, if the BER must stay below the FEC limit?
% (JLT 2025 = Mitsuya et al., J. Lightw. Technol. 43(2), 2025.)
%
% Method
%   The switch has M*N ports: N space switches (M x M) in stage 1, M wavelength-
%   routing switches (N x N) in stage 2 and N space switches (M x M) in stage 3.
%   A larger space switch has more loss and more crosstalk, so it needs more
%   transmitter power.
%   For both types of the third stage (list_stage3_coupler_flag) and every size of
%   the space switches (list_sw_size) the script looks for the lowest transmitter
%   power of pin_ary with BER <= BER_limit. This power is required_PTx.
%   Port count at a power P = the largest M*N whose required_PTx is <= P.
%
% How the search saves time
%   The sizes are visited from small to large. A larger switch never needs less
%   power, so its search starts at the required power of the size before.
%   If a size fails at every power, all larger sizes fail too and are skipped.
%   The result does not depend on the order of list_sw_size.
%   Self-checks 1 and 2 of section 6 test this assumption with the simulated BER.
%
% Edges of pin_ary
%   NaN = the BER limit is not reached with any power of pin_ary.
%   A required power equal to the LOWEST power of pin_ary means: the limit is met
%   there already, the true value is lower. The script prints a note; extend
%   pin_ary downwards and run again.
%
% Letters and names used here
%   N      = number of wavelength channels
%   M      = size of the space switches = sw_size (the port count is M*N)
%   Mary   = number of constellation points = 2^mod_flag (mod_flag = bits per symbol)
%   Morder = order of the equalizer
%   up     = oversampling rate = number of samples per symbol
%   PTx    = transmitter power of one channel, both polarizations together [dBm]
%   pin    = power of the ONE simulated polarization = PTx - 3 dB [dBm]
%   pin_ary is a legacy name: its values are PTx values, not pin values.
%   In the help text of the library the letters N and M can mean other things
%   (number of samples, number of ports, filter order): read the "Inputs" list there.
%
% One operating point
%   The lines from "chain begin" to "chain end" are the transmission chain of
%   step22_three_stage_one_point, line by line. Read that script first.
%   The seed is set before every operating point. So step22_three_stage_one_point
%   repeats any point of this search: set the same PTx, sw_size,
%   stage3_coupler_flag, datasize and seed there, and it prints the same BER.
%
% How to use this file
%   1. Run setup_path once (in the folder "matlab"). Then run this file (F5).
%      Run the whole file, not single sections (the folder for the results is
%      found from the place of this file).
%   2. quick_flag = 1 is a short run (less than one minute). Use it first.
%      quick_flag = 0 is the full size (1.5e5 symbols, 0.5-dB steps, a few minutes;
%      xt_wave_max = 16 makes it about 2.5 times faster with the same result).
%   3. The results are saved in the folder matlab/results (figure on the screen,
%      one .mat file, two .csv files and one .png file; the file names carry the
%      time of the run).
%
% How close this model comes to Table V of JLT 2025 (quick_flag = 0, the
% parameters as they are below; nothing was tuned to get closer)
%   required PTx [dBm]     M = 16     32     64    128
%   Scheme A1, this script   -5.0   -4.0   -3.0   -2.0
%   Scheme A1, paper         -4.5   -3.5   -2.5   -1.5
%   Scheme A2, this script   -4.5   -2.0    3.5    NaN   (NaN: not up to 10 dBm)
%   Scheme A2, paper         -4.0   -2.0    4.0    infeasible (above 5 dBm)
%   This script needs 0.5 dB less power than the paper, or the same power.
%   Scheme A2, M = 64 reacts weakly to the power: its BER falls by only 7 percent
%   per 0.5 dB. It is 1.04e-2 at 3.0 dBm and 9.6e-3 at 3.5 dBm: 4 percent above
%   and 4 percent below the limit. The random error of one BER value is about
%   1.5 percent here. So 3.5 dBm is the usual result (seeds 1 to 8 with up = 2;
%   seeds 1 and 5 with up = 4 and with up = 8), but not the only possible one:
%   one test run (up = 8, xt_wave_max = 16) had a BER of 9.995e-3 at 3.0 dBm.
%   What is known about the difference:
%   - The paper does not give the receiver model, the noise figure of the
%     pre-amplifier (here NF2 = 4 dB) and the width of the AWG passband (here 50 GHz).
%   - Scheme A1 is limited by the ASE of the EDFA only. NF2 and FWHM_AWG do not
%     change its numbers. The receiver here needs an SNR of 14.0 dB for BER = 1e-2.
%     (The formula for Gaussian noise gives 13.9 dB; see the notes in adequalizet.)
%   - Scheme A2 with M = 64 is very sensitive: the crosstalk of stage 3 alone gives
%     an SNR of 17 dB. With NF2 = 5 dB its required PTx is 5.0 dBm, with
%     NF2 = 6 dB it is 8.5 to 9.0 dBm. With FWHM_AWG = 40 GHz it is 4.0 dBm.
%
% Legacy: there is no legacy script for this switch. The loops and the names
% follow TL_switch_coherent_search_Nyquist_07.m, with these differences on purpose:
%   - Search: start at the required power of the size before (legacy: start at
%     the lowest power for every size); the order of the list does not matter.
%   - Random numbers: fixed seed, set before every operating point.
%   - Results: every run writes new files; all parameters are saved with them.

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['main_three_stage_conventional: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters
% "paper" = JLT 2025, section IV. "lab" = not in the paper, value of the laboratory code.
quick_flag = 1;  % 1 = short run (small datasize, 1-dB steps), 0 = full size
% pin_ary is the legacy name; its values are PTx (both polarizations), not pin.
if quick_flag == 1
    datasize = 3e4;  % number of symbols of one operating point
    pin_ary = -10:1:10;  % transmitter powers PTx that are tried [dBm]
else
    datasize = 1.5e5;  % number of symbols of one operating point (legacy value)
    pin_ary = -10:0.5:10;  % transmitter powers PTx that are tried [dBm]
end
list_sw_size = [16 32 64 128];  % sizes M of the M x M space switches
list_stage3_coupler_flag = [0 1];  % stage 3: 0 = Scheme A1, 1 = Scheme A2
mod_flag = 4;  % bits per symbol: 2 = QPSK, 4 = 16QAM, 5 = 32QAM, 6 = 64QAM (paper: 4)
up = 2;  % oversampling rate (see the note on up in step22_three_stage_one_point)
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
xt_wave_max = Inf;  % crosstalk waveforms per switch: Inf = one per leak, 16 = faster
AWG_loss = 6;  % loss of the AWG at the center of its passband [dB] (paper)
FWHM_AWG = 50e9;  % 3-dB width of the AWG passband, Gaussian shape [Hz] (lab)
AWG_XT = 32;  % floor of the AWG passband shape [dB] (lab; it lies outside the band Fs)
Morder = 16;  % order of the adaptive equalizer (it has Morder + 1 taps)
seed = 1;  % seed of the random numbers, set before every operating point
BER_limit = 1e-2;  % FEC limit: a BER below it is error free after error correction

% Note on rolloff: keep rolloff = 0 unless you study the roll-off itself. The
% search runs with rolloff > 0 too, but the SNR budget of
% step22_three_stage_one_point cannot check such a point (see the note there).

% Folder for the results: matlab/results, next to the folder of this file.
main_folder = fileparts(mfilename('fullpath'));  % folder of this file (matlab/main)
if isempty(main_folder)
    error(['main_three_stage_conventional: run the whole file (F5 or type its name). ' ...
        'The folder of this file is not known when a single section is run.']);
end
matlab_folder = fileparts(main_folder);  % the folder "matlab"
results_folder = fullfile(matlab_folder, 'results');

%% 2. Values that follow from the parameters (legacy lines 55-70)
Mary = 2^mod_flag;  % number of constellation points (16 for 16QAM)
Fs = up*baudrate;  % sampling frequency = width of the simulated band [Hz]
Hrcos = rcosfilter(datasize*up, baudrate, Fs, rolloff);  % transmit mask (Nyquist)
assert(xt_wave_max >= 1, 'xt_wave_max must be 1 or more (Inf = one waveform per leak)');

pin_ary = sort(pin_ary);  % the search needs the powers in rising order
[~, order_sw] = sort(list_sw_size);  % positions of the sizes, small first
num_scheme = length(list_stage3_coupler_flag);  % number of third-stage types
num_sw = length(list_sw_size);  % number of space-switch sizes
num_pin = length(pin_ary);  % number of transmitter powers

% Index order of the result arrays: always (a, b) or (a, b, c), with
%   a = position in list_stage3_coupler_flag, b = position in list_sw_size,
%   c = position in pin_ary
% required_PTx(a, b) = lowest power with BER <= BER_limit [dBm]
%   NaN = the BER limit is not reached with any power of pin_ary
required_PTx = NaN(num_scheme, num_sw);
% BER_ary(a, b, c) = BER of every simulated point
%   NaN = this point was not simulated
BER_ary = NaN(num_scheme, num_sw, num_pin);
num_point = 0;  % number of simulated operating points

%% 3. Search for the required transmitter power (legacy lines 71-239)
% Skeleton of this section (the chain of one operating point is in the middle):
%   for every type of the third stage (Scheme A1, Scheme A2)
%       for every space-switch size, from small to large
%           while the required power is not found and a power of pin_ary is left
%               PTx = next power
%               chain begin ... chain end: one operating point, the result is BER
%               BER <= BER_limit: store PTx in required_PTx, stop the while loop
%               otherwise       : go to the next power
%           the next, larger size starts at the power where this size stopped
timer_search = tic;
fprintf('Search: %d symbols per point, %d powers from %.1f to %.1f dBm\n', datasize, ...
    num_pin, pin_ary(1), pin_ary(end));
for ite_scheme = 1:num_scheme
    stage3_coupler_flag = list_stage3_coupler_flag(ite_scheme);
    index_start = 1;  % the smallest space switch starts at the lowest power
    for ite_sw = 1:num_sw
        index_sw_size = order_sw(ite_sw);
        sw_size = list_sw_size(index_sw_size);
        flag_calc = 1;  % 1 = the required power of this size is not found yet
        index_PTx = index_start;
        while flag_calc == 1 && index_PTx <= num_pin
            PTx = pin_ary(index_PTx);
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
            % back in the search: store the BER, then decide (found, or next power)
            BER_ary(ite_scheme, index_sw_size, index_PTx) = BER;
            num_point = num_point + 1;
            fprintf('    A%d, M = %3d, PTx = %5.1f dBm: BER = %.3e\n', ...
                stage3_coupler_flag + 1, sw_size, PTx, BER);
            if BER <= BER_limit
                required_PTx(ite_scheme, index_sw_size) = PTx;
                flag_calc = 0;  % found: stop the search for this size
            else
                index_PTx = index_PTx + 1;  % not enough power: try the next one
            end
        end
        index_start = index_PTx;  % the next, larger size starts from here
        fprintf('  Scheme A%d, M = %3d (%5d ports): required PTx = %5.1f dBm\n', ...
            stage3_coupler_flag + 1, sw_size, sw_size*N, ...
            required_PTx(ite_scheme, index_sw_size));
        if flag_calc == 0 && index_PTx == 1
            fprintf('    Note: the BER limit is already met at the lowest power of ');
            fprintf('pin_ary.\n');
            fprintf('    The true required power is lower: extend pin_ary downwards.\n');
        end
    end
end
elapsed_time = toc(timer_search);  % time of the search [s]
fprintf('%d operating points in %.1f s (%.2f s per point)\n', num_point, ...
    elapsed_time, elapsed_time/num_point);

%% 4. Port count versus transmitter power (legacy lines 231-240)
% data_PC: column 1 = transmitter power [dBm],
%          column a+1 = port count for the third-stage type number a
%                       (0 = no size of the list works at this power)
data_PC = zeros(num_pin, num_scheme + 1);
data_PC(:, 1) = pin_ary.';
for ite_scheme = 1:num_scheme
    for index_PTx = 1:num_pin
        for index_sw_size = 1:num_sw
            % a size counts if its required power is not above this power
            % (a comparison with NaN is false: such a size never counts)
            if required_PTx(ite_scheme, index_sw_size) <= pin_ary(index_PTx)
                port_num = list_sw_size(index_sw_size)*N;
                data_PC(index_PTx, ite_scheme+1) = ...
                    max(data_PC(index_PTx, ite_scheme+1), port_num);
            end
        end
    end
end

%% 5. Comparison with Table V of JLT 2025
% Reference file: ref_data/jlt2025_three_stage_ref.csv, one row per scheme and size
%   line 1  : the header
%   column 1: stage3_coupler_flag (0 = Scheme A1, 1 = Scheme A2)
%   column 2: sw_size (size M of the space switches)
%   column 3: port_count (M*96)
%   column 4: PTx_dBm = required transmitter power of the paper [dBm]
%             (NaN = "infeasible" in the paper: more than 5 dBm would be needed)
%   column 5: selectors_per_port (number of 1 x 2 selectors per port)
% The paper used a 200-Gbps DP-16QAM signal and N = 96, as this script does by default.
% The file is not needed: without it the columns of the paper show NaN.
ref_file = fullfile(matlab_folder, 'ref_data', 'jlt2025_three_stage_ref.csv');
ref_PTx = NaN(num_scheme, num_sw);  % required power of the paper, same layout [dBm]
if exist(ref_file, 'file') ~= 2
    fprintf('Note: jlt2025_three_stage_ref.csv was not found. No reference points.\n');
else
    ref_data = readmatrix(ref_file, 'NumHeaderLines', 1);
    for ite_scheme = 1:num_scheme
        for index_sw_size = 1:num_sw
            % the row of the file that belongs to this scheme and this size
            ref_row = find(ref_data(:, 1) == list_stage3_coupler_flag(ite_scheme) ...
                & ref_data(:, 2) == list_sw_size(index_sw_size));
            if isscalar(ref_row)
                ref_PTx(ite_scheme, index_sw_size) = ref_data(ref_row, 4);
            end
        end
    end
end
diff_PTx = required_PTx - ref_PTx;  % this run - paper [dB] (NaN if one of them is NaN)

fprintf('\nRequired transmitter power [dBm] (NaN = not reached up to %.1f dBm)\n', ...
    pin_ary(end));
fprintf('  %-7s %5s %7s %10s %10s %11s\n', 'scheme', 'M', 'ports', 'this run', ...
    'JLT 2025', 'difference');
for ite_scheme = 1:num_scheme
    for ite_sw = 1:num_sw
        index_sw_size = order_sw(ite_sw);
        fprintf('  A%-6d %5d %7d %10.1f %10.1f %+11.1f\n', ...
            list_stage3_coupler_flag(ite_scheme) + 1, list_sw_size(index_sw_size), ...
            list_sw_size(index_sw_size)*N, required_PTx(ite_scheme, index_sw_size), ...
            ref_PTx(ite_scheme, index_sw_size), diff_PTx(ite_scheme, index_sw_size));
    end
end
fprintf('(JLT 2025 = Table V of the paper; NaN there = infeasible, above 5 dBm)\n');
if any(required_PTx(:) == pin_ary(1))
    fprintf('Note: %.1f dBm is the lowest power of pin_ary. The true required power\n', ...
        pin_ary(1));
    fprintf('      of these entries is lower: extend pin_ary downwards.\n');
end

%% 6. Self-checks
% The search of section 3 assumes that a larger space switch never needs less
% power. Self-checks 1 and 2 test this with the BER values that were simulated.
% They can fail: a wrong loss or a wrong crosstalk in the chain breaks them.
% A BER value has a random error (about 4 percent for 700 counted bit errors).
tol_BER = 0.8;  % a BER may be up to 20 percent below the BER it is compared with

% --- Self-check 1: at the same power a larger space switch has the higher BER ---
% The power is the required power of the smaller size. The search for the next
% larger size starts at this power, so both BER values were simulated.
num_pair = 0;  % number of pairs of sizes that were compared
for ite_scheme = 1:num_scheme
    for ite_sw = 1:num_sw-1
        index_small = order_sw(ite_sw);  % position of the smaller size
        index_large = order_sw(ite_sw+1);  % position of the next larger size
        index_PTx = find(pin_ary == required_PTx(ite_scheme, index_small), 1);
        if ~isempty(index_PTx)
            BER_small = BER_ary(ite_scheme, index_small, index_PTx);
            BER_large = BER_ary(ite_scheme, index_large, index_PTx);
            if ~isnan(BER_large)
                assert(BER_large >= tol_BER*BER_small, ...
                    'a larger switch has a lower BER than a smaller one (same power)');
                num_pair = num_pair + 1;
            end
        end
    end
end
fprintf('\nSelf-check 1 passed: a larger space switch has the higher BER at the same ');
fprintf('power (%d pairs of sizes)\n', num_pair);

% --- Self-check 2: the BER falls when the transmitter power rises ---
num_step = 0;  % number of power steps that were compared
for ite_scheme = 1:num_scheme
    for index_sw_size = 1:num_sw
        for index_PTx = 1:num_pin-1
            BER_low = BER_ary(ite_scheme, index_sw_size, index_PTx);
            BER_high = BER_ary(ite_scheme, index_sw_size, index_PTx+1);
            if ~isnan(BER_low) && ~isnan(BER_high)
                assert(tol_BER*BER_high <= BER_low, ...
                    'the BER rises when the transmitter power rises');
                num_step = num_step + 1;
            end
        end
    end
end
fprintf('Self-check 2 passed: the BER falls when the power rises ');
fprintf('(%d power steps)\n', num_step);

% --- Bookkeeping check: required_PTx and data_PC fit together ---
% These properties follow from the way the search and section 4 are written.
% The check cannot find an error of the chain. It protects the loops against a
% later edit.
for ite_scheme = 1:num_scheme
    sorted_PTx = required_PTx(ite_scheme, order_sw);  % sizes from small to large
    found_PTx = sorted_PTx(~isnan(sorted_PTx));  % the sizes that reach the limit
    assert(all(diff(found_PTx) >= 0), ...
        'a larger space switch has a lower required power than a smaller one');
    assert(all(isnan(sorted_PTx(numel(found_PTx)+1:end))), ...
        'a larger space switch reaches the BER limit, but a smaller one does not');
end
assert(all(all(diff(data_PC(:, 2:end), 1, 1) >= 0)), ...
    'the port count falls when the transmitter power rises');
fprintf('Bookkeeping check passed: required power and port count fit together\n');

%% 7. Figure: port count versus transmitter power (JLT 2025, Fig. 6)
% Small circles and solid lines = this run. Large crosses = Table V of the paper:
% the lowest power at which the paper reaches each port count (same color as the
% curve of the scheme; an infeasible size has no cross).
fig = figure;
if isprop(fig, 'Theme')
    % MATLAB R2025a and later: ask for the light theme (white background), so that
    % the figure and the saved .png look the same on every computer
    set(fig, 'Theme', 'light');
end
hold on;
for ite_scheme = 1:num_scheme
    scheme_number = list_stage3_coupler_flag(ite_scheme) + 1;  % 1 = A1, 2 = A2
    port_count = data_PC(:, ite_scheme+1);
    port_count(port_count == 0) = NaN;  % 0 ports cannot be drawn on a log axis
    curve = stairs(pin_ary, port_count, 'o-', 'LineWidth', 1.2, 'MarkerSize', 5);
    set(curve, 'DisplayName', sprintf('Scheme A%d', scheme_number));
    if any(~isnan(ref_PTx(ite_scheme, :)))
        ref_point = plot(ref_PTx(ite_scheme, :), list_sw_size*N, 'x', ...
            'MarkerSize', 14, 'LineWidth', 2.5);
        set(ref_point, 'Color', get(curve, 'Color'));
        set(ref_point, 'DisplayName', sprintf('Scheme A%d (JLT 2025, Table V)', ...
            scheme_number));
    end
end
grid on;
set(gca, 'YScale', 'log');  % the port count doubles from size to size
set(gca, 'YTick', unique(list_sw_size)*N);
set(gca, 'YMinorTick', 'off');
set(gca, 'YMinorGrid', 'off');
ylim([min(list_sw_size)*N/1.5, max(list_sw_size)*N*1.5]);
xlim([pin_ary(1), pin_ary(end)]);
xlabel('Transmitter power PTx [dBm]');
ylabel('Port count M*N');
title(sprintf('Conventional three-stage switch: %d bits per symbol, %.0f Gbaud, N = %d', ...
    mod_flag, baudrate/1e9, N));
legend('Location', 'southeast');

%% 8. Save the results
if exist(results_folder, 'dir') ~= 7
    mkdir(results_folder);
end
time_stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));  % time of this run
file_base = fullfile(results_folder, ['three_stage_conventional_' time_stamp]);
matlab_version = version;  % MATLAB version of this run

% .mat file: all parameters, the seed and all results
% (index order: required_PTx(a, b), BER_ary(a, b, c), ref_PTx(a, b), diff_PTx(a, b);
%  a = type of the third stage, b = size, c = power; data_PC has one row per power)
save([file_base '.mat'], 'quick_flag', 'datasize', 'pin_ary', 'list_sw_size', ...
    'list_stage3_coupler_flag', 'mod_flag', 'up', 'baudrate', 'pol_flag', ...
    'fiber_flag', 'Fan_in_loss', 'Fan_out_loss', 'N', 'signal_interval', 'NF', ...
    'edfa_sat1', 'edfa_sat2', 'NF2', 'rolloff', 'sel_ex_ratio', 'xt_wave_max', ...
    'AWG_loss', 'FWHM_AWG', 'AWG_XT', 'Morder', 'seed', 'BER_limit', ...
    'required_PTx', 'BER_ary', 'data_PC', 'ref_PTx', 'diff_PTx', 'num_point', ...
    'elapsed_time', 'time_stamp', 'matlab_version');

% .csv file 1: port count versus transmitter power, one column per scheme
fid = fopen([file_base '_portcount.csv'], 'w');
fprintf(fid, 'PTx_dBm');
fprintf(fid, ',A%d', list_stage3_coupler_flag + 1);
fprintf(fid, '\n');
for index_PTx = 1:num_pin
    fprintf(fid, '%.1f', data_PC(index_PTx, 1));
    fprintf(fid, ',%d', data_PC(index_PTx, 2:end));
    fprintf(fid, '\n');
end
fclose(fid);

% .csv file 2: required transmitter power [dBm], one row per third-stage type
fid = fopen([file_base '_required_PTx.csv'], 'w');
fprintf(fid, 'stage3_coupler_flag');
fprintf(fid, ',M%d', list_sw_size);
fprintf(fid, '\n');
for ite_scheme = 1:num_scheme
    fprintf(fid, '%d', list_stage3_coupler_flag(ite_scheme));
    fprintf(fid, ',%.1f', required_PTx(ite_scheme, :));
    fprintf(fid, '\n');
end
fclose(fid);

% .png file: the figure of section 7
saveas(fig, [file_base '.png']);

fprintf('\nSaved in %s\n', results_folder);
fprintf('  three_stage_conventional_%s.mat\n', time_stamp);
fprintf('  three_stage_conventional_%s_portcount.csv\n', time_stamp);
fprintf('  three_stage_conventional_%s_required_PTx.csv\n', time_stamp);
fprintf('  three_stage_conventional_%s.png\n', time_stamp);
