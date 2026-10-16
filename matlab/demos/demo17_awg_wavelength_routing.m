%% demo17_awg_wavelength_routing - AWG passband, cyclic routing and coupler loss
% Page: docs/17_awg_wavelength_routing.html
% Three properties of a wavelength-routing switch whose AWG has K input ports:
%   1. The passband center of the AWG deviates from the signal. The deviation grows
%      with K, and the signal loses power on the slope of the passband.
%   2. The AWG routes cyclically: channel = out + in - 1 (awg_channel).
%   3. K couplers with N/K inputs replace one coupler with N inputs. Every coupler
%      stage that is saved removes 3.5 dB of loss before the EDFA.
% How to run: run setup_path once (in the folder "matlab"), then run this file (F5).

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['demo17_awg_wavelength_routing: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters (signal and AWG values of step21_two_stage_one_point)
datasize = 3e4;  % number of symbols
mod_flag = 5;  % bits per symbol: 2 = QPSK, 4 = 16QAM, 5 = 32QAM, 6 = 64QAM
up = 2;  % oversampling rate (samples per symbol)
baudrate = 24e9;  % symbol rate [Hz]
FWHM_AWG = 66.6e9;  % 3-dB width of the AWG passband [Hz]
AWG_XT = 32;  % floor of the passband shape [dB]
grid_offset = 0;  % extra offset of the passband center [Hz] (step21: 12.5e9)
N = 96;  % number of wavelength channels
K_ary = [1 2 4 8 12];  % numbers K of input ports of the AWG
N_small = 8;  % small example for the routing table: number of channels
K_small = 4;  % small example for the routing table: number of input ports
in_target = 2;  % example connection in the small AWG: input port
out_target = 5;  % example connection in the small AWG: output port
nb = 1500;  % number of FFT bins that are averaged into one point of the figure
f_plot = 48e9;  % the figure shows the passband from -f_plot to +f_plot [Hz]

%% 2. Passband of the AWG: loss of the signal versus K
Fs = up*baudrate;  % sampling frequency = width of the simulated band [Hz]
Ns = datasize*up;  % number of samples
f = freq_axis(Ns, Fs);  % frequency of every FFT bin [Hz]; 0 Hz = carrier of the signal
Hrcos = rcosfilter(Ns, baudrate, Fs, 0);  % transmit mask: rectangular spectrum
signal = TL_QAM(datasize, up, Hrcos, 0, mod_flag);  % one signal with 0 dBm
num_K = length(K_ary);  % number of AWG types
dev_freq = zeros(1, num_K);  % deviation of the passband center [Hz]
loss_sim = zeros(1, num_K);  % loss measured on the signal [dB]
loss_theory = zeros(1, num_K);  % loss calculated from the Gaussian formula [dB]
% f covers only the simulated band Fs (48 GHz for up = 2). The passband (FWHM 66.6 GHz)
% is wider. The simulation needs it only inside Fs, where the signal is. For the figure
% the passband is also calculated on a wider frequency axis, f_line.
f_line = (-f_plot:0.1e9:f_plot).';  % frequency axis of the lines in the figure [Hz]
T_line = zeros(length(f_line), num_K);  % passband on f_line, one column per K
% ULCF_dev_freq gives the deviation for each K. Its table holds the specification
% values of the ULCF AWG device in the laboratory.
for k = 1:num_K
    dev_freq(k) = ULCF_dev_freq(K_ary(k));  % worst input port of this AWG [Hz]
    shift = grid_offset + dev_freq(k);  % passband center seen from the carrier [Hz]
    % simulation: insertion loss 0 dB, so that only the shape of the passband acts
    signal_out = awg(signal, 0, shift, Fs, FWHM_AWG, AWG_XT, 1);
    loss_sim(k) = calc_signal_power(signal) - calc_signal_power(signal_out);
    % theory: Gaussian power response, averaged over the bins that carry the signal
    T = 2.^(-(2*(f - shift)/FWHM_AWG).^2);  % power response of the passband on f
    loss_theory(k) = -10*log10(sum(Hrcos.^2.*T)/sum(Hrcos.^2));
    T_line(:, k) = 2.^(-(2*(f_line - shift)/FWHM_AWG).^2);  % the same formula on f_line
end
fprintf('Loss of a %.0f-GBd signal in the AWG passband (FWHM %.1f GHz)\n', ...
    baudrate/1e9, FWHM_AWG/1e9);
fprintf('    K   deviation [GHz]   loss, simulation [dB]   loss, theory [dB]\n');
for k = 1:num_K
    fprintf('  %3d   %15.1f   %21.3f   %17.3f\n', K_ary(k), dev_freq(k)/1e9, ...
        loss_sim(k), loss_theory(k));
end

% --- Self-check 1: the loss made by awg follows the Gaussian formula ---
assert(max(abs(loss_sim - loss_theory)) < 0.05, ...
    'the simulated passband loss differs from the Gaussian formula by 0.05 dB or more');
fprintf('Self-check 1 passed: simulated loss = Gaussian formula within 0.05 dB\n');

%% 3. Cyclic routing table of a small AWG
table_ch = awg_channel((1:K_small).', 1:N_small, N_small);  % K_small x N_small
fprintf('\nRouting table: N = %d channels, K = %d input ports\n', N_small, K_small);
fprintf('(row = input port, column = output port, entry = channel)\n');
disp(table_ch);
ch_target = awg_channel(in_target, out_target, N_small);  % channel of the example
fprintf('Example: input port %d -> output port %d uses channel %d\n', in_target, ...
    out_target, ch_target);
for a = 1:K_small
    out_same = find(table_ch(a, :) == ch_target);  % where this channel leaves
    fprintf('  channel %d from input port %d leaves at output port %d\n', ch_target, ...
        a, out_same);
end

% --- Self-check 2: the two properties of the routing table ---
for a = 1:K_small  % one input port: every channel exactly once
    assert(isequal(sort(table_ch(a, :)), 1:N_small), ...
        'a row of the routing table does not hold every channel exactly once');
end
for j = 1:N_small  % one output port: K different channels from the K input ports
    assert(length(unique(table_ch(:, j))) == K_small, ...
        'two input ports reach one output port on the same channel');
end
fprintf('Self-check 2 passed: each channel once per row, at most once per column\n');

%% 4. Loss of the aggregation coupler before the EDFA versus K
N_agg = N./K_ary;  % inputs of one coupler = wavelengths on one EDFA
agg_coupler_loss = coupler_loss(N_agg);  % loss of one coupler [dB]
saving = coupler_loss(N) - agg_coupler_loss;  % less loss than one N x 1 coupler [dB]
fprintf('\nAggregation coupler before the EDFA (N = %d wavelength channels)\n', N);
fprintf('    K    coupler   loss [dB]   saving [dB]   EDFAs\n');
for k = 1:num_K
    fprintf('  %3d   %3d x 1   %9.1f   %11.1f   %5d\n', K_ary(k), N_agg(k), ...
        agg_coupler_loss(k), saving(k), K_ary(k));
end

% --- Self-check 3: the saving is 3.5 dB for every coupler stage that is saved ---
saving_rule = 3.5*(ceil(log2(N)) - ceil(log2(N./K_ary)));  % [dB]
assert(max(abs(saving - saving_rule)) < 1e-9, ...
    'the saving of coupler loss is not 3.5 dB per saved stage');
fprintf('Self-check 3 passed: saving = 3.5 dB x (number of saved coupler stages)\n');

%% 5. Figure: passband (theory, lines) and signal spectrum (simulation, markers)
% The markers exist only inside Fs. The lines use the wider axis f_line of section 2.
% A single FFT bin of random data is noisy: nb bins are averaged into one point.
% signal_out is the signal after the AWG with the last K of K_ary (last pass of the loop).
assert(mod(datasize/2, nb) == 0, 'datasize/2 must be a multiple of nb');
P_in = mean(reshape(abs(fftshift(fft(signal))).^2, nb, Ns/nb), 1);
P_out = mean(reshape(abs(fftshift(fft(signal_out))).^2, nb, Ns/nb), 1);
f_avg = mean(reshape(f, nb, Ns/nb), 1);  % center frequency of every group of bins [Hz]
P_ref = sum(abs(fft(signal)).^2)/sum(Hrcos.^2);  % mean power of one signal bin = 0 dB
figure;
plot(f_avg/1e9, 10*log10(P_in/P_ref), 'o', 'LineWidth', 1.2);
hold on;
plot(f_avg/1e9, 10*log10(P_out/P_ref), 's', 'LineWidth', 1.2);
plot(f_line/1e9, 10*log10(T_line(:, 1)), 'k-');
plot(f_line/1e9, 10*log10(T_line(:, num_K)), 'k--');
grid on;
ylim([-12, 1]);
xlabel('Frequency from the carrier of the signal [GHz]');
ylabel('Relative power [dB]');
title(sprintf('AWG passband (FWHM %.1f GHz) and signal spectrum', FWHM_AWG/1e9));
legend('signal before the AWG', sprintf('signal after the AWG, K = %d', K_ary(num_K)), ...
    sprintf('passband for K = %d (theory)', K_ary(1)), ...
    sprintf('passband for K = %d (theory)', K_ary(num_K)), 'Location', 'south');
