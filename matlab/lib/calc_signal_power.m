function signal_power_dB = calc_signal_power(signal_w)
%CALC_SIGNAL_POWER  Mean power of an optical field in dBm.
%
%   signal_power_dB = calc_signal_power(signal_w)
%
%   Inputs
%     signal_w         : optical field, one signal per column [sqrt(W)]
%   Outputs
%     signal_power_dB  : mean power of each column [dBm], 1 x (number of columns)
%
%   Legacy: calc_signal_power.m (same name, same argument).
%   Legacy used bandpower and pow2db (toolbox functions); this version does not.
%   Note: the unit is dBm (dB relative to 1 mW), although the name says dB.
%   Note: 0 dBm = 1 mW, -30 dBm = 1 uW.
%   Note: the power is the mean of abs(signal_w).^2 along each column.
%   Note: a row vector is an error (the legacy code read it as one signal).
%   Note: keep every signal as a column vector.
%   Note: an all-zero column gives -Inf.

if size(signal_w, 1) == 1 && size(signal_w, 2) > 1
    error('calc_signal_power: signal_w is a row vector. Signals must be column vectors.');
end

power_W = mean(abs(signal_w).^2, 1);  % mean power of each column [W]
signal_power_dB = 10*log10(power_W*1e3);  % W -> mW -> dBm
end
