function plot_level_diagram(stage_names, power_dBm)
%PLOT_LEVEL_DIAGRAM  Plot the signal power after each stage of a link (level diagram).
%
%   plot_level_diagram(stage_names, power_dBm)
%
%   Inputs
%     stage_names  : names of the stages, cell array of char, one name per stage
%                    for example {'Tx', 'DC switch', 'Coupler', 'EDFA'}
%     power_dBm    : power after each stage [dBm], vector with one value per stage
%   Outputs
%     none (a new figure is opened)
%
%   Legacy: none (new function).
%   Note: a level diagram shows where power is lost and where it is gained.
%   Note: horizontal axis = the stages in the order in which the light passes them.
%   Note: vertical axis = power after that stage [dBm]; the value is written at the marker.
%   Note: the step between two markers is the loss (down) or the gain (up) in dB.
%   Note: get the values in a script with calc_signal_power after every stage.
%   Example: plot_level_diagram({'Tx', 'Switch', 'EDFA'}, [0, -12, 3]);
%   Note: all values must be finite (a power of 0 W is -Inf dBm and cannot be drawn).

n = numel(power_dBm);  % number of stages

if ~iscell(stage_names)
    error('plot_level_diagram: stage_names must be a cell array, like {''Tx'', ''EDFA''}.');
end
if n < 1 || numel(stage_names) ~= n
    error(['plot_level_diagram: stage_names and power_dBm must have the same number ' ...
        'of elements (' num2str(numel(stage_names)) ' names, ' num2str(n) ' powers).']);
end
if any(~isfinite(power_dBm(:)))
    error('plot_level_diagram: power_dBm must hold finite numbers only.');
end

p = power_dBm(:).';  % row vector, so that row and column inputs look the same
y_low = min(p) - 3;  % lower end of the vertical axis: 3 dB of free space [dBm]
y_high = max(p) + 3;  % upper end of the vertical axis: 3 dB of free space [dBm]
gap = 0.015 * (y_high - y_low);  % distance between a marker and its number [dB]

figure;
plot(1:n, p, '-o');
grid on;
for k = 1:n
    % the value of every stage, written just above its marker
    text(k, p(k) + gap, sprintf('%.1f', p(k)), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom');
end
xlim([0.5, n + 0.5]);
ylim([y_low, y_high]);
set(gca, 'XTick', 1:n);
set(gca, 'XTickLabel', stage_names);
set(gca, 'TickLabelInterpreter', 'none');
xtickangle(30);
xlabel('Stage');
ylabel('Power after the stage [dBm]');
title('Level diagram');
end
