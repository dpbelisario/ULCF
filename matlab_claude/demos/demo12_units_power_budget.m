%% demo12_units_power_budget - Watt, dBm, dB and the power budget of a switch
% Demo script of the page docs/12_units_power_budget.html.
%   section 2: convert a power between W and dBm; add powers in W, never in dBm
%   section 3: what a loss in dB does to the field and to the power
%   section 4: the loss rules of a selector, a coupler and a DC switch
%   section 5: power budget from the transmitter to the EDFA input, for two coupler sizes
%   section 6: the two budgets in one level diagram
% How to run: run setup_path once (in the folder "matlab"), then run this file (F5).
% Every self-check must print "passed".

clear; close all; rng(1);
if exist('attenuation', 'file') ~= 2
    error(['demo12_units_power_budget: the library is not on the MATLAB path. ' ...
        'Run setup_path first.']);
end

%% 1. Parameters
PTx = 0;  % transmitter power of one wavelength channel [dBm]
loss_dB = 3;  % loss that section 3 applies to the field [dB]
dcs_input_port_num = 16;  % size M of the M x M DC switch
N = 96;  % number of wavelength channels = inputs of the large aggregation coupler
N_agg = 8;  % inputs of the small aggregation coupler
edfa_sat1 = 20;  % output power of the EDFA, all channels together [dBm]
size_list = [2 4 8 16 32 64 96 128];  % numbers of ports D for the table of section 4
num_samples = 1000;  % number of samples of the test field

%% 2. Watt and dBm
% dBm compares a power with 1 mW: P_dBm = 10*log10(P_W/1e-3).
P_dBm = [-30 -10 0 3 10 20];  % some powers [dBm]
P_W = 1e-3*10.^(P_dBm/10);  % dBm -> W
P_back = 10*log10(P_W*1e3);  % W -> dBm
fprintf('Power in dBm and in mW\n');
for k = 1:numel(P_dBm)
    fprintf('  %6.1f dBm = %9.4f mW\n', P_dBm(k), P_W(k)*1e3);
end

% The EDFA gives its output power edfa_sat1 to N channels in equal parts.
ch_dBm = edfa_sat1 - 10*log10(N);  % one channel: the ratio N in dB is subtracted [dBm]
ch_W = 1e-3*10^(ch_dBm/10);  % the same power [W]
total_W = N*ch_W;  % powers are added in W, never in dBm [W]
total_dBm = 10*log10(total_W*1e3);  % the sum, converted back [dBm]
fprintf('%d channels of %.2f dBm (%.3f mW) each: total %.1f mW = %.2f dBm\n', N, ...
    ch_dBm, ch_W*1e3, total_W*1e3, total_dBm);

assert(max(abs(P_back - P_dBm)) < 1e-9, 'dBm -> W -> dBm must give the same number again');
assert(abs(total_dBm - edfa_sat1) < 1e-9, 'the N channel powers must add up to edfa_sat1');
fprintf('Self-check 1 passed: W <-> dBm; %d channels add up to %.0f dBm\n', N, edfa_sat1);

%% 3. Field and power
% A signal is a column vector of complex field samples [sqrt(W)].
% mean(abs(x).^2) is its power [W]. A power loss of L dB multiplies the field by 10^(-L/20).
x = randn(num_samples, 1) + 1i*randn(num_samples, 1);  % a random field with any power
x = set_signal_power(x, PTx);  % scale it to the power PTx
[y, att] = attenuation(x, loss_dB);  % y = field after the loss, att = amplitude factor
P_x = calc_signal_power(x);  % power before the loss [dBm]
P_y = calc_signal_power(y);  % power after the loss [dBm]
fprintf('\nx (set to %.1f dBm) : mean(abs(x).^2) = %.4f mW\n', PTx, mean(abs(x).^2)*1e3);
fprintf('y (x after %.1f dB) : mean(abs(y).^2) = %.4f mW = %.3f dBm\n', loss_dB, ...
    mean(abs(y).^2)*1e3, P_y);
fprintf('Amplitude factor %.4f = 10^(-%.1f/20), power factor %.4f = 10^(-%.1f/10)\n', ...
    att, loss_dB, att^2, loss_dB);

assert(abs(P_x - PTx) < 1e-9, 'set_signal_power must give the wanted power');
assert(abs(P_y - (PTx - loss_dB)) < 1e-9, 'the power in dBm must fall by loss_dB');
assert(max(abs(y - x*10^(-loss_dB/20))) < 1e-12, 'the field must be x*10^(-loss_dB/20)');
fprintf('Self-check 2 passed: a loss of %.1f dB = field times %.4f\n', loss_dB, att);

%% 4. Loss rules of a selector, a coupler and a DC switch
sel = selector_loss(size_list);  % 1 x D selector: 0.5 dB per stage [dB]
cpl = coupler_loss(size_list);  % D x 1 coupler: 3.5 dB per stage [dB]
dcs = DCS_loss(size_list);  % D x D DC switch: selector + coupler [dB]
fprintf('\nLoss [dB] for D ports (number of stages = ceil(log2(D)))\n');
fprintf('  %5s %8s %10s %10s %11s\n', 'D', 'stages', 'selector', 'coupler', 'DC switch');
for k = 1:numel(size_list)
    fprintf('  %5d %8d %10.1f %10.1f %11.1f\n', size_list(k), ceil(log2(size_list(k))), ...
        sel(k), cpl(k), dcs(k));
end

assert(isequal(dcs, sel + cpl), 'a DC switch must cost selector + coupler');
assert(isequal(cpl, 3.5*ceil(log2(size_list))), 'a coupler must cost 3.5 dB per stage');
assert(coupler_loss(96) == coupler_loss(128), '96 inputs must cost the same as 128');
fprintf('Self-check 3 passed: loss rules; coupler_loss(96) = %.1f dB\n', coupler_loss(96));

%% 5. Power budget from the transmitter to the input of the EDFA
% Path: Tx -> 1 x M selector -> M x 1 coupler -> aggregation coupler -> EDFA input.
% The selector and the coupler are the two parts of the DC switch.
% Column 1 = large aggregation coupler (N x 1), column 2 = small one (N_agg x 1).
stage_names = {'Tx', 'Selector', 'Coupler', 'Agg. coupler'};
loss_sel = selector_loss(dcs_input_port_num);  % 1 x M selector [dB]
loss_cpl = coupler_loss(dcs_input_port_num);  % M x 1 coupler [dB]
stage_loss = [0, 0; loss_sel, loss_sel; loss_cpl, loss_cpl; ...
    coupler_loss(N), coupler_loss(N_agg)];  % loss of every stage [dB]

level = [PTx, PTx];  % (a) budget in dB: it starts at the transmitter power [dBm]
signal = [x, x];  % (b) field: two copies of x, one signal per column [sqrt(W)]
budget = zeros(4, 2);  % (a) power after every stage, from the budget [dBm]
stage_power = zeros(4, 2);  % (b) power after every stage, measured on the field [dBm]
for k = 1:4
    level = level - stage_loss(k, :);  % (a) subtract the loss in dB
    budget(k, :) = level;
    signal = attenuation(signal, stage_loss(k, :));  % (b) attenuate the field
    stage_power(k, :) = calc_signal_power(signal);  % (b) then measure its power
end

diff_dB = budget(4, 2) - budget(4, 1);  % how much higher the EDFA input is [dB]
name_big = sprintf('agg. coupler %d x 1', N);  % name of column 1
name_small = sprintf('agg. coupler %d x 1', N_agg);  % name of column 2
fprintf('\nPower after every stage [dBm] (PTx = %.1f dBm, %d x %d DC switch)\n', PTx, ...
    dcs_input_port_num, dcs_input_port_num);
fprintf('  %-14s %20s %20s\n', 'stage', name_big, name_small);
for k = 1:4
    fprintf('  %-14s %20.1f %20.1f\n', stage_names{k}, budget(k, 1), budget(k, 2));
end
fprintf('EDFA input with the small coupler: %.1f dB higher\n', diff_dB);

assert(max(abs(stage_power(:) - budget(:))) < 1e-9, ...
    'the power measured on the field must be the budget in dB');
fprintf('Self-check 4 passed: field power = budget in dB at every stage (both cases)\n');

%% 6. Level diagram
plot_level_diagram(stage_names, budget(:, 1));  % staircase with the large coupler
set(findobj(gca, 'Type', 'text'), 'HorizontalAlignment', 'left');  % numbers right of marker
hold on;
plot(1:4, budget(:, 2), 's-');  % staircase with the small coupler
text(4.08, budget(4, 2), sprintf('%.1f', budget(4, 2)));  % its value at the EDFA input
xlim([0.5, 5.2]);  % free space on the right for the next two lines
plot([4.5 4.5], [budget(4, 1), budget(4, 2)], 'k.-');  % bar: difference at the EDFA input
text(4.57, (budget(4, 1) + budget(4, 2))/2, sprintf('+%.1f dB', diff_dB));
legend(name_big, name_small, 'Location', 'southwest');
title(sprintf('Level diagram up to the EDFA input (PTx = %.0f dBm)', PTx));
