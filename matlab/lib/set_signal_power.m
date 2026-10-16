function signal = set_signal_power(signal_data, power_dB)
%SET_SIGNAL_POWER  Scale an optical field to a given mean power in dBm.
%
%   signal = set_signal_power(signal_data, power_dB)
%
%   Inputs
%     signal_data  : waveform, one signal per column (any scale, not all zero)
%     power_dB     : wanted mean power [dBm]
%                    scalar, or a 1 x M row vector with one power per column
%   Outputs
%     signal       : the same waveform scaled to the wanted power [sqrt(W)]
%
%   Legacy: set_signal_power.m (same name, same arguments).
%   Legacy used bandpower and pow2db (toolbox functions); this version does not.
%   Note: the unit is dBm (dB relative to 1 mW), although the name says dB.
%   Note: after the call, calc_signal_power(signal) returns power_dB.
%   Note: every column is scaled separately.
%   Note: only the amplitude changes; the shape and the phase stay the same.
%   Note: an all-zero column is an error (the legacy code returned NaN).
%   Note: a row vector is an error (the legacy code read it as one signal).

if size(signal_data, 1) == 1 && size(signal_data, 2) > 1
    error('set_signal_power: signal_data is a row vector. Signals must be column vectors.');
end

current_dB = calc_signal_power(signal_data);  % power of each column now [dBm]
if any(current_dB == -Inf)
    % log10(0) = -Inf: a signal without power cannot be scaled to a power
    error('set_signal_power: a column of signal_data is all zero.');
end
gain_dB = power_dB - current_dB;  % gain that is still needed [dB]
signal = attenuation(signal_data, -gain_dB);  % a negative loss is a gain
end
