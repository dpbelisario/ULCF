function p = claude_params_proposed()
%CLAUDE_PARAMS_PROPOSED  Default parameters of the proposed three-stage switch.
%
%   p = claude_params_proposed()
%
%   Returns a struct with the COMMON parameter set of this project (work3): the
%   values of step22_three_stage_one_point (JLT 2025, 200-Gbps DP-16QAM at 32 GBd
%   on the 50-GHz grid), plus the fields that only the proposed switch has.
%   Change fields after the call, e.g. p.K = 12; p.PTx = 0.
%
%   Fields that the proposed switch adds to step22
%     K          : number of input groups = input ports of the ULCF AWG pair
%                  (1, 2, 4, 6, 8, 12 or 16: the values that ULCF_dev_freq knows)
%     pattern    : 'dispersed' or 'concentrated' (claude_inband_leaks)
%     awg_type   : 'auto' = conventional AWG of step22 for K = 1, ULCF pair for K > 1
%                  'conv' or 'ulcf' force one type (e.g. ULCF with K = 1)
%     oob_flag   : 0 = leaks on other wavelengths are left out (ideal receive filter)
%                  1 = the leaks of the two neighbouring groups are added at +-50 GHz
%                      with freqoff (needs up >= 5 at 32 GBd)
%     AWG_loss_conv, FWHM_conv   : step22 AWG (6 dB, 50 GHz)
%     AWG_loss_ulcf, FWHM_ulcf   : ULCF AWG (9 dB, 66.6 GHz), plus splitter_loss
%     AWG_XT     : crosstalk of the ULCF AWG, one leak per other input port [dB]
%     flg_NWDM   : 0 on the 50-GHz grid (carrier on the passband centre + deviation)
%
%   Written by Claude for work2.
p = struct();
% --- operating point ---
p.datasize = 3e4;  % symbols
p.PTx = 4;  % transmitter power, both polarizations [dBm]
p.sw_size = 64;  % M
p.stage3_coupler_flag = 1;  % 0 = A1 (selectors), 1 = A2 (couplers)
p.K = 12;  % input groups
p.pattern = 'dispersed';
p.awg_type = 'auto';
p.oob_flag = 0;
% --- common set (= step22) ---
p.mod_flag = 4;
p.up = 2;
p.baudrate = 32e9;
p.pol_flag = 1;
p.fiber_flag = 0;
p.Fan_in_loss = 1.5;
p.Fan_out_loss = 1.5;
p.N = 96;
p.signal_interval = 50e9;
p.NF = 6;
p.edfa_sat1 = 20;
p.edfa_sat2 = 10;
p.NF2 = 4;
p.rolloff = 0;
p.sel_ex_ratio = 35;
p.xt_wave_max = Inf;
p.Morder = 16;
p.seed = 1;
p.BER_limit = 1e-2;
% --- AWG of each type ---
p.AWG_loss_conv = 6;
p.FWHM_conv = 50e9;
p.AWG_loss_ulcf = 9;
p.splitter_loss = coupler_loss(2);  % 3.5 dB
p.FWHM_ulcf = 66.6e9;
p.AWG_XT = 32;
p.flg_NWDM = 0;
end
