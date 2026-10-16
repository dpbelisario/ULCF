%% main_two_stage_ULCF - Port count of the ULCF two-stage switch versus transmitter power
% This script answers the question: how many ports can the two-stage switch have
% for a given transmitter power, if the BER must stay below the FEC limit?
%
% Method
%   The switch has M*N ports: N DC switches (M x M) and M wavelength-routing
%   switches (N x N). A larger DC switch has more loss and more crosstalk,
%   so it needs more transmitter power.
%   For every number of AWG input ports (ULCF_deg_ary) and every size of the DC
%   switch (list_dcs_input_port_num) the script looks for the lowest transmitter
%   power of pin_ary with BER <= BER_limit. This power is required_PTx.
%   Port count at a power P = the largest M*N whose required_PTx is <= P.
%
% How the search saves time
%   The DC-switch sizes are visited from small to large. A larger switch never
%   needs less power, so its search starts at the required power of the size before.
%   The result does not depend on the order of list_dcs_input_port_num.
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
%   M      = size of the DC switch = dcs_input_port_num (the port count is M*N)
%   K      = number of input ports of the ULCF AWG = ULCF_deg
%   Mary   = number of constellation points = 2^mod_flag (mod_flag = bits per symbol)
%   Morder = order of the equalizer; up = oversampling rate (samples per symbol)
%   PTx    = transmitter power of one channel, both polarizations together [dBm]
%   pin    = power of the ONE simulated polarization = PTx - 3 dB [dBm]
%   pin_ary is a legacy name: its values are PTx values, not pin values.
%   In the help text of the library the letters N and M can mean other things
%   (number of samples, number of ports, filter order): read the "Inputs" list there.
%
% One operating point
%   The lines from "chain begin" to "chain end" are the transmission chain of
%   step21_two_stage_one_point, line by line. Read that script first.
%   The seed is set before every operating point. So step21_two_stage_one_point
%   repeats any point of this search: set the same PTx, dcs_input_port_num,
%   ULCF_deg, datasize and seed there, and it prints the same BER.
%
% How to use this file
%   1. Run setup_path once (in the folder "matlab"). Then run this file (F5).
%      Run the whole file, not single sections (the folder for the results is
%      found from the place of this file).
%   2. quick_flag = 1 is a short run (less than 1 minute). Use it first.
%      quick_flag = 0 is the size of the legacy script (about 3 minutes).
%   3. The results are saved in the folder matlab/results (figure on the screen,
%      one .mat file, two .csv files and one .png file; the file names carry the
%      time of the run).
%   4. Section 5 prints the required powers next to the ones of the legacy code.
%
% Legacy: TL_switch_coherent_search_Nyquist_07.m (the whole script).
% The chain and the variable names follow the legacy script.
% Differences from the legacy script (all on purpose)
%   - The differences of the chain are listed in step21_two_stage_one_point.
%   - Search: the legacy script started from the lowest power for every size and
%     gave wrong port counts if the list of sizes was not in rising order.
%   - Port_count of the legacy script is replaced by required_PTx (one power per
%     AWG type and size). data_PC is built from it in section 4.
%   - One modulation format per run. The legacy script had a loop from
%     modOrderStart to modOrderEnd and wrote one Excel sheet per format.
%   - Random numbers: fixed seed, set before every operating point.
%   - Results: every run writes new files; all parameters are saved with them.
%     The legacy script wrote into one Excel file without the parameters,
%     and showed data_PC with disp.

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['main_two_stage_ULCF: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters (legacy lines 3-51)
quick_flag = 1;  % 1 = short run (small datasize, 1-dB steps), 0 = legacy size
% pin_ary is the legacy name; its values are PTx (both polarizations), not pin.
if quick_flag == 1
    datasize = 3e4;  % number of symbols of one operating point
    pin_ary = -20:1:10;  % transmitter powers PTx that are tried [dBm]
else
    datasize = 1.5e5;  % number of symbols of one operating point (legacy value)
    pin_ary = -20:0.5:10;  % transmitter powers PTx that are tried [dBm] (legacy grid)
end
list_dcs_input_port_num = [2 4 8 16 32];  % sizes M of the DC switch
mod_flag = 5;  % bits per symbol: 2 = QPSK, 4 = 16QAM, 5 = 32QAM, 6 = 64QAM
up = 2;  % oversampling rate (see the note on up in step21_two_stage_one_point)
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
ULCF_deg_ary = [1 2 4 8 12];  % numbers K of input ports of the ULCF AWG
splitter_loss = coupler_loss(2);  % 1 x 2 splitter in front of the pair of ULCF AWGs [dB]
AWG_loss = 9;  % loss of the AWG at the center of its passband [dB]
FWHM_AWG = 66.6e9;  % 3-dB width of the AWG passband [Hz]
AWG_XT = 32;  % crosstalk of the AWG: one leak is 32 dB below the signal [dB]
Morder = 16;  % order of the adaptive equalizer (it has Morder + 1 taps)
seed = 1;  % seed of the random numbers, set before every operating point
BER_limit = 1e-2;  % FEC limit: a BER below it is error free after error correction

% Note on rolloff: keep rolloff = 0 unless you study the roll-off itself.
% The legacy values of section 5 are for rolloff = 0 only
% (see the note on rolloff in step21_two_stage_one_point).

% Folder for the results: matlab/results, next to the folder of this file.
main_folder = fileparts(mfilename('fullpath'));  % folder of this file (matlab/main)
if isempty(main_folder)
    error(['main_two_stage_ULCF: run the whole file (F5 or type its name). ' ...
        'The folder of this file is not known when a single section is run.']);
end
matlab_folder = fileparts(main_folder);  % the folder "matlab"
results_folder = fullfile(matlab_folder, 'results');

%% 2. Values that follow from the parameters (legacy lines 55-70)
Mary = 2^mod_flag;  % number of constellation points (32 for 32QAM)
Fs = up*baudrate;  % sampling frequency = width of the simulated band [Hz]
Hrcos = rcosfilter(datasize*up, baudrate, Fs, rolloff);  % transmit mask (Nyquist)
if ULCF_flag == 1
    % every coupler and every EDFA carries N/ULCF_deg wavelengths: a whole number
    assert(all(mod(N, ULCF_deg_ary) == 0), ...
        'N must be a multiple of every number in ULCF_deg_ary');
end

pin_ary = sort(pin_ary);  % the search needs the powers in rising order
[~, order_dcs] = sort(list_dcs_input_port_num);  % positions of the sizes, small first
num_deg = length(ULCF_deg_ary);  % number of AWG types
num_dcs = length(list_dcs_input_port_num);  % number of DC-switch sizes
num_pin = length(pin_ary);  % number of transmitter powers

% Index order of the result arrays: always (a, b) or (a, b, c), with
%   a = position in ULCF_deg_ary, b = position in list_dcs_input_port_num,
%   c = position in pin_ary
% required_PTx(a, b) = lowest power with BER <= BER_limit [dBm]
%   NaN = the BER limit is not reached with any power of pin_ary
required_PTx = NaN(num_deg, num_dcs);
% BER_ary(a, b, c) = BER of every simulated point
%   NaN = this point was not simulated
BER_ary = NaN(num_deg, num_dcs, num_pin);
num_point = 0;  % number of simulated operating points

%% 3. Search for the required transmitter power (legacy lines 71-239)
% Skeleton of this section (the chain of one operating point is in the middle):
%   for every AWG type
%       for every DC-switch size, from small to large
%           while the required power is not found and a power of pin_ary is left
%               PTx = next power
%               chain begin ... chain end: one operating point, the result is BER
%               BER <= BER_limit: store PTx in required_PTx, stop the while loop
%               otherwise       : go to the next power
%           the next, larger size starts at the power where this size stopped
timer_search = tic;
fprintf('Search: %d symbols per point, %d powers from %.1f to %.1f dBm\n', datasize, ...
    num_pin, pin_ary(1), pin_ary(end));
for ite_inputPC = 1:num_deg
    ULCF_deg = ULCF_deg_ary(ite_inputPC);
    index_start = 1;  % the smallest DC switch starts at the lowest power
    for ite_dcs = 1:num_dcs
        index_dcs_input_port_num = order_dcs(ite_dcs);
        dcs_input_port_num = list_dcs_input_port_num(index_dcs_input_port_num);
        flag_calc = 1;  % 1 = the required power of this size is not found yet
        index_PTx = index_start;
        while flag_calc == 1 && index_PTx <= num_pin
            PTx = pin_ary(index_PTx);
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
            % back in the search: store the BER, then decide (found, or next power)
            BER_ary(ite_inputPC, index_dcs_input_port_num, index_PTx) = BER;
            num_point = num_point + 1;
            if BER <= BER_limit
                required_PTx(ite_inputPC, index_dcs_input_port_num) = PTx;
                flag_calc = 0;  % found: stop the search for this size
            else
                index_PTx = index_PTx + 1;  % not enough power: try the next one
            end
        end
        index_start = index_PTx;  % the next, larger size starts from here
        fprintf('  K = %2d, M = %2d (%4d ports): required PTx = %5.1f dBm\n', ...
            ULCF_deg, dcs_input_port_num, dcs_input_port_num*N, ...
            required_PTx(ite_inputPC, index_dcs_input_port_num));
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
%          column a+1 = port count for the AWG type number a (0 = no size works)
data_PC = zeros(num_pin, num_deg + 1);
data_PC(:, 1) = pin_ary.';
for ite_inputPC = 1:num_deg
    for index_PTx = 1:num_pin
        for index_dcs_input_port_num = 1:num_dcs
            % a size counts if its required power is not above this power
            % (a comparison with NaN is false: such a size never counts)
            if required_PTx(ite_inputPC, index_dcs_input_port_num) <= pin_ary(index_PTx)
                port_num = list_dcs_input_port_num(index_dcs_input_port_num)*N;
                data_PC(index_PTx, ite_inputPC+1) = ...
                    max(data_PC(index_PTx, ite_inputPC+1), port_num);
            end
        end
    end
end

fprintf('\nRequired transmitter power [dBm] (NaN = not reached up to %.1f dBm)\n', ...
    pin_ary(end));
fprintf('  %-8s', 'K \ M');
fprintf('%8d', list_dcs_input_port_num);
fprintf('\n');
for ite_inputPC = 1:num_deg
    fprintf('  %-8d', ULCF_deg_ary(ite_inputPC));
    fprintf('%8.1f', required_PTx(ite_inputPC, :));
    fprintf('\n');
end
if any(required_PTx(:) == pin_ary(1))
    fprintf('Note: %.1f dBm is the lowest power of pin_ary. The true required power\n', ...
        pin_ary(1));
    fprintf('      of these entries is lower: extend pin_ary downwards.\n');
end

%% 5. Comparison with the legacy code (new, not in the legacy script)
% Legacy file: ref_data/legacy_portcount_32QAM.csv = result of the legacy script
% for 32QAM (mod_flag = 5), N = 96, datasize 1.5e5 and 0.5-dB steps of the power.
%   line 1   : the header PTx_dBm,K1,K2,K4,K8,K12
%   column 1 : transmitter power [dBm]
%   column Kn: port count of the legacy code for a ULCF AWG with n input ports
% The file is not needed: without it the legacy values are NaN and the figure
% shows only the curves of this run.
legacy_file = fullfile(matlab_folder, 'ref_data', 'legacy_portcount_32QAM.csv');
legacy_sizes = [2 4 8 16 32];  % DC-switch sizes of the legacy run
legacy_flag = 0;  % 1 = the legacy file can be used
if exist(legacy_file, 'file') ~= 2
    fprintf('Note: legacy_portcount_32QAM.csv was not found. No legacy values.\n');
elseif mod_flag ~= 5 || N ~= 96
    fprintf('Note: the legacy file is for 32QAM (mod_flag = 5) and N = 96. ');
    fprintf('No legacy values.\n');
else
    fid = fopen(legacy_file, 'r');
    header_line = fgetl(fid);  % first line of the file = names of the columns
    fclose(fid);
    legacy_data = readmatrix(legacy_file, 'NumHeaderLines', 1);
    if ~ischar(header_line)
        fprintf('Note: legacy_portcount_32QAM.csv is empty. No legacy values.\n');
    else
        legacy_names = strsplit(strtrim(header_line), ',');  % one name per column
        if numel(legacy_names) < 2 || size(legacy_data, 2) ~= numel(legacy_names)
            fprintf('Note: legacy_portcount_32QAM.csv has an unknown layout. ');
            fprintf('No legacy values.\n');
        else
            legacy_flag = 1;
        end
    end
end

% legacy_col_ary(a) = column of the legacy file for the AWG type number a (0 = none)
% legacy_PTx(a, b)  = lowest power at which the legacy port count reaches the size
%                     number b [dBm], in the layout of required_PTx
%                     (NaN = not reached, or this type or size is not in the file)
legacy_col_ary = zeros(1, num_deg);
legacy_PTx = NaN(num_deg, num_dcs);
if legacy_flag == 1
    for ite_inputPC = 1:num_deg
        legacy_col = find(strcmp(legacy_names, sprintf('K%d', ULCF_deg_ary(ite_inputPC))));
        if isscalar(legacy_col)
            legacy_col_ary(ite_inputPC) = legacy_col;
            for index_dcs_input_port_num = 1:num_dcs
                port_num = list_dcs_input_port_num(index_dcs_input_port_num)*N;
                % first row of the file with at least this port count
                legacy_row = find(legacy_data(:, legacy_col) >= port_num, 1);
                if any(port_num == legacy_sizes*N) && ~isempty(legacy_row)
                    legacy_PTx(ite_inputPC, index_dcs_input_port_num) = ...
                        legacy_data(legacy_row, 1);
                end
            end
        else
            fprintf('Note: the legacy file has no column K%d.\n', ...
                ULCF_deg_ary(ite_inputPC));
        end
    end
end
diff_PTx = required_PTx - legacy_PTx;  % this run - legacy [dB] (NaN if one is NaN)

if legacy_flag == 1
    fprintf('\nRequired transmitter power of the legacy code [dBm] ');
    fprintf('(NaN = not reached, or not in the file)\n');
    fprintf('  %-8s', 'K \ M');
    fprintf('%8d', list_dcs_input_port_num);
    fprintf('\n');
    for ite_inputPC = 1:num_deg
        fprintf('  %-8d', ULCF_deg_ary(ite_inputPC));
        fprintf('%8.1f', legacy_PTx(ite_inputPC, :));
        fprintf('\n');
    end
    fprintf('\nDifference: this run - legacy code [dB]\n');
    fprintf('  %-8s', 'K \ M');
    fprintf('%8d', list_dcs_input_port_num);
    fprintf('\n');
    for ite_inputPC = 1:num_deg
        fprintf('  %-8d', ULCF_deg_ary(ite_inputPC));
        fprintf('%+8.1f', diff_PTx(ite_inputPC, :));
        fprintf('\n');
    end
    % What to expect, if all other parameters are the legacy values of section 1:
    %   quick_flag = 0: 0 or -0.5 dB. The BER of this script is a few percent lower
    %     than the legacy BER: for K > 1 its EDFA gives one channel the power
    %     sat/(N/K) (legacy: sat/N), which lowers the BER by 2 to 7 percent, and for
    %     every K its equalizer has 17 taps (legacy: 513), which lowers it by 1 to
    %     2 percent. So a point close to the BER limit can move down by one step.
    %     (The legacy run had no fixed seed: its own values can move by one step too.)
    %   quick_flag = 1: the steps are 1 dB, so 0 to +0.5 dB is added by the grid.
    %     The BER of 3e4 symbols has a random error of about 4 percent. So a point
    %     close to the BER limit can move by one more step of 1 dB, up or down.
    fprintf('Expected with the legacy parameters: 0 or -0.5 dB for quick_flag = 0 ');
    fprintf('(within 1 dB for quick_flag = 1).\n');
end

%% 6. Self-checks (new, not in the legacy script)
% The search of section 3 assumes that a larger DC switch never needs less power.
% Self-checks 1 and 2 test this with the BER values that were simulated. They can
% fail: a wrong loss or a wrong crosstalk in the chain breaks them.
% A BER value has a random error (about 4 percent for 700 counted bit errors).
tol_BER = 0.8;  % a BER may be up to 20 percent below the BER it is compared with

% --- Self-check 1: at the same power a larger DC switch has the higher BER ---
% The power is the required power of the smaller size. The search for the next
% larger size starts at this power, so both BER values were simulated.
num_pair = 0;  % number of pairs of sizes that were compared
for ite_inputPC = 1:num_deg
    for ite_dcs = 1:num_dcs-1
        index_small = order_dcs(ite_dcs);  % position of the smaller size
        index_large = order_dcs(ite_dcs+1);  % position of the next larger size
        index_PTx = find(pin_ary == required_PTx(ite_inputPC, index_small), 1);
        if ~isempty(index_PTx)
            BER_small = BER_ary(ite_inputPC, index_small, index_PTx);
            BER_large = BER_ary(ite_inputPC, index_large, index_PTx);
            if ~isnan(BER_large)
                assert(BER_large >= tol_BER*BER_small, ...
                    'a larger DC switch has a lower BER than a smaller one (same power)');
                num_pair = num_pair + 1;
            end
        end
    end
end
fprintf('\nSelf-check 1 passed: a larger DC switch has the higher BER at the same ');
fprintf('power (%d pairs of sizes)\n', num_pair);

% --- Self-check 2: the BER falls when the transmitter power rises ---
num_step = 0;  % number of power steps that were compared
for ite_inputPC = 1:num_deg
    for index_dcs_input_port_num = 1:num_dcs
        for index_PTx = 1:num_pin-1
            BER_low = BER_ary(ite_inputPC, index_dcs_input_port_num, index_PTx);
            BER_high = BER_ary(ite_inputPC, index_dcs_input_port_num, index_PTx+1);
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
for ite_inputPC = 1:num_deg
    sorted_PTx = required_PTx(ite_inputPC, order_dcs);  % sizes from small to large
    found_PTx = sorted_PTx(~isnan(sorted_PTx));  % the sizes that reach the limit
    assert(all(diff(found_PTx) >= 0), ...
        'a larger DC switch has a lower required power than a smaller one');
    assert(all(isnan(sorted_PTx(numel(found_PTx)+1:end))), ...
        'a larger DC switch reaches the BER limit, but a smaller one does not');
end
assert(all(all(diff(data_PC(:, 2:end), 1, 1) >= 0)), ...
    'the port count falls when the transmitter power rises');
fprintf('Bookkeeping check passed: required power and port count fit together\n');

%% 7. Figure: port count versus transmitter power (new, not in the legacy script)
% Markers and thin solid lines = this run.
% Thick dashed lines = legacy code (file of section 5), in the color of the same K.
% A legacy curve is drawn first, so it stays visible under the curve of this run.
fig = figure;
if isprop(fig, 'Theme')
    % MATLAB R2025a and later: ask for the light theme (white background), so that
    % the figure and the saved .png look the same on every computer
    set(fig, 'Theme', 'light');
end
hold on;
curve_colors = lines(num_deg);  % one color per AWG type: row a = [red green blue]
for ite_inputPC = 1:num_deg
    if legacy_col_ary(ite_inputPC) > 0
        legacy_count = legacy_data(:, legacy_col_ary(ite_inputPC));
        legacy_count(legacy_count == 0) = NaN;  % 0 ports cannot be drawn on a log axis
        legacy_curve = stairs(legacy_data(:, 1), legacy_count, '--', 'LineWidth', 3);
        set(legacy_curve, 'Color', curve_colors(ite_inputPC, :));
        set(legacy_curve, 'DisplayName', ...
            sprintf('K = %d (legacy)', ULCF_deg_ary(ite_inputPC)));
    end
    port_count = data_PC(:, ite_inputPC+1);
    port_count(port_count == 0) = NaN;  % 0 ports cannot be drawn on a log axis
    curve = stairs(pin_ary, port_count, 'o-', 'LineWidth', 1.2, 'MarkerSize', 5);
    set(curve, 'Color', curve_colors(ite_inputPC, :));
    set(curve, 'DisplayName', sprintf('K = %d', ULCF_deg_ary(ite_inputPC)));
end
grid on;
set(gca, 'YScale', 'log');  % the port count doubles from size to size
set(gca, 'YTick', unique(list_dcs_input_port_num)*N);
set(gca, 'YMinorTick', 'off');
set(gca, 'YMinorGrid', 'off');
ylim([min(list_dcs_input_port_num)*N/1.5, max(list_dcs_input_port_num)*N*1.5]);
xlim([pin_ary(1), pin_ary(end)]);
xlabel('Transmitter power PTx [dBm]');
ylabel('Port count M*N');
title(sprintf('ULCF two-stage switch: %d bits per symbol, %.0f Gbaud, N = %d', ...
    mod_flag, baudrate/1e9, N));
legend('Location', 'northwest');

%% 8. Save the results (legacy lines 243-249)
if exist(results_folder, 'dir') ~= 7
    mkdir(results_folder);
end
time_stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));  % time of this run
file_base = fullfile(results_folder, ['two_stage_ULCF_' time_stamp]);
matlab_version = version;  % MATLAB version of this run

% .mat file: all parameters, the seed and all results
% (index order: required_PTx(a, b), BER_ary(a, b, c), legacy_PTx(a, b), diff_PTx(a, b);
%  a = AWG type, b = DC-switch size, c = power; data_PC has one row per power)
save([file_base '.mat'], 'quick_flag', 'datasize', 'pin_ary', ...
    'list_dcs_input_port_num', 'mod_flag', 'up', 'baudrate', 'pol_flag', ...
    'fiber_flag', 'Fan_in_loss', 'Fan_out_loss', 'flg_NWDM', 'N', 'NF', ...
    'edfa_sat1', 'edfa_sat2', 'NF2', 'rolloff', 'signal_interval', ...
    'dcs_ex_ratio', 'ULCF_flag', 'ULCF_deg_ary', 'splitter_loss', 'AWG_loss', ...
    'FWHM_AWG', 'AWG_XT', 'Morder', 'seed', 'BER_limit', 'required_PTx', ...
    'BER_ary', 'data_PC', 'legacy_PTx', 'diff_PTx', 'num_point', ...
    'elapsed_time', 'time_stamp', 'matlab_version');

% .csv file 1: port count versus transmitter power (the layout of the legacy file)
fid = fopen([file_base '_portcount.csv'], 'w');
fprintf(fid, 'PTx_dBm');
fprintf(fid, ',K%d', ULCF_deg_ary);
fprintf(fid, '\n');
for index_PTx = 1:num_pin
    fprintf(fid, '%.1f', data_PC(index_PTx, 1));
    fprintf(fid, ',%d', data_PC(index_PTx, 2:end));
    fprintf(fid, '\n');
end
fclose(fid);

% .csv file 2: required transmitter power [dBm], one row per AWG type
fid = fopen([file_base '_required_PTx.csv'], 'w');
fprintf(fid, 'ULCF_deg');
fprintf(fid, ',M%d', list_dcs_input_port_num);
fprintf(fid, '\n');
for ite_inputPC = 1:num_deg
    fprintf(fid, '%d', ULCF_deg_ary(ite_inputPC));
    fprintf(fid, ',%.1f', required_PTx(ite_inputPC, :));
    fprintf(fid, '\n');
end
fclose(fid);

% .png file: the figure of section 7
saveas(fig, [file_base '.png']);

fprintf('\nSaved in %s\n', results_folder);
fprintf('  two_stage_ULCF_%s.mat\n', time_stamp);
fprintf('  two_stage_ULCF_%s_portcount.csv\n', time_stamp);
fprintf('  two_stage_ULCF_%s_required_PTx.csv\n', time_stamp);
fprintf('  two_stage_ULCF_%s.png\n', time_stamp);
