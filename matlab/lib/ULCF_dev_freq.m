function dev_freq = ULCF_dev_freq(ULCF_deg)
%ULCF_DEV_FREQ  Center-frequency deviation of the worst input port of a ULCF AWG.
%
%   dev_freq = ULCF_dev_freq(ULCF_deg)
%
%   Inputs
%     ULCF_deg  : number of input ports of the ULCF AWG: 1, 2, 4, 6, 8, 12 or 16
%   Outputs
%     dev_freq  : deviation of the passband center for the worst input port [Hz]
%
%   Source of the table: the specification values of the ULCF AWG device in the laboratory.
%   Legacy: if-chain in TL_switch_coherent_search_Nyquist_07.m, lines 153-167.
%   Legacy values are kept: 1->5e9, 2->5e9, 4->8e9, 6->11e9, 8->12.5e9, 12->16e9, 16->17e9.
%   Legacy silently kept the previous value for any other number; now it is an error.
%   Note: ULCF AWG = uniform-loss and cyclic-frequency AWG with several input ports.
%   Note: from an outer input port the passband center is off the channel frequency.
%   Note: this difference is the center-frequency deviation.
%   Note: the table holds the worst input port for each number of input ports.
%   Note: the JOCN 2018 paper reports the same worst value, 16e9, for its 12 x 48 prototype.
%   Note: the main scripts use shift = 12.5e9 + ULCF_dev_freq(ULCF_deg) in awg.

if ULCF_deg == 1
    dev_freq = 5e9;
elseif ULCF_deg == 2
    dev_freq = 5e9;
elseif ULCF_deg == 4
    dev_freq = 8e9;
elseif ULCF_deg == 6
    dev_freq = 11e9;
elseif ULCF_deg == 8
    dev_freq = 12.5e9;
elseif ULCF_deg == 12
    dev_freq = 16e9;
elseif ULCF_deg == 16
    dev_freq = 17e9;
else
    error('ULCF_dev_freq: ULCF_deg must be 1, 2, 4, 6, 8, 12 or 16.');
end
end
