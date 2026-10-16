function b = claude_budget_proposed(p, r)
%CLAUDE_BUDGET_PROPOSED  Closed-form power and SNR budget of the proposed switch.
%
%   b = claude_budget_proposed(p, r)    p = parameters, r = claude_chain_proposed(p)
%
%   The formulas of step22 (sections 5 and 6) with the middle stage of step21:
%   coupler and EDFA of N/K channels, AWG passband off-centre by the deviation of
%   the worst ULCF input port, K-1 AWG leaks at AWG_XT, and num_xt3 in-band leaks
%   in the third-stage switch instead of M-1. No random numbers.
%
%   Output b (struct): budget_target(1:10), budget_total(1:10), budget_ase1,
%   budget_ase2, budget_sigpw_awg, budget_sigpw, nsr_* terms, SNR_budget, BER_gauss,
%   eq_penalty, T_sig, T_ase, T_inband.
%
%   Written by Claude for work2.
h_planck = 6.62607004e-34;
f_opt = 299792458/1550e-9;
Fs = r.Fs;
L = p.datasize*p.up;
budget_target = zeros(1, 10);
budget_total = zeros(1, 10);

% [1] to [4]
xt_sw1 = r.num_xt1*10^(-r.sw1_xt_att/10);
budget_target(1) = r.pin;
budget_total(1) = r.pin;
budget_target(2) = budget_target(1) - r.fiber_loss;
budget_total(2) = budget_target(2);
budget_target(3) = budget_target(2) - r.sw1_loss;
budget_total(3) = budget_target(3) + 10*log10(1 + xt_sw1);
budget_target(4) = budget_target(3) - r.agg_coupler_loss;
budget_total(4) = budget_total(3) - r.agg_coupler_loss;

% [5] EDFA shared by N/K channels
limit1 = r.sat1 - 10*log10(r.N_agg);
G1 = 10^((limit1 - budget_total(4))/10);
F1 = 10^(p.NF/10);
ase1_mW = (G1*F1 - 1)*h_planck*f_opt*Fs/2*1e3;
ase1_ref_mW = ase1_mW*p.signal_interval/Fs;
scale1 = 10^(limit1/10)/(10^(limit1/10) + ase1_ref_mW);
budget_target(5) = budget_target(4) + 10*log10(G1*scale1);
budget_total(5) = 10*log10((10^(limit1/10) + ase1_mW)*scale1);
budget_ase1 = 10*log10(ase1_mW*scale1);

% [6] AWG: flat loss and passband shape (centre "shift" away from the carrier)
Hawg = gaussfilter(L, r.shift, Fs, r.FWHM, p.AWG_XT, 1);
w_sig = r.Hrcos.^2/sum(r.Hrcos.^2);
T_sig = sum(w_sig.*Hawg.^2);
T_ase = mean(Hawg.^2);
T_inband = mean(r.Hband.^2.*Hawg.^2);
budget_target(6) = budget_target(5) - r.AWG_loss_tot + 10*log10(T_sig);
sig6_mW = 10^(budget_target(6)/10)*(1 + xt_sw1);
ase6_mW = ase1_mW*scale1*10^(-r.AWG_loss_tot/10);
budget_total(6) = 10*log10(sig6_mW + ase6_mW*T_ase);

% [7] AWG crosstalk: K-1 leaks, each AWG_XT below the in-band power after the AWG
budget_sigpw_awg = 10*log10(sig6_mW + ase6_mW*T_inband);
xt_awg_mW = r.num_xt_awg*10^((budget_sigpw_awg - p.AWG_XT)/10);
budget_target(7) = budget_target(6);
budget_total(7) = 10*log10(10^(budget_total(6)/10) + xt_awg_mW);

% [8] Stage-3 switch: num_xt3 in-band leaks (+ num_oob out-of-band leaks that
% only add power, not noise in the signal band), each sw3_xt_att below sigpw
budget_sigpw = 10*log10(sig6_mW + ase6_mW*T_inband + xt_awg_mW);
xt_sw3_mW = r.num_xt3*10^((budget_sigpw - r.sw3_xt_att)/10);
oob_mW = r.num_oob*10^((budget_sigpw - r.sw3_xt_att)/10);
budget_target(8) = budget_target(7) - r.sw3_loss;
budget_total(8) = 10*log10(10^(budget_total(7)/10) + xt_sw3_mW + oob_mW) - r.sw3_loss;

% [9] fan-in/out
budget_target(9) = budget_target(8) - r.fiber_loss;
budget_total(9) = budget_total(8) - r.fiber_loss;

% [10] pre-amplifier
limit2 = r.sat2;
G2 = 10^((limit2 - budget_total(9))/10);
F2 = 10^(p.NF2/10);
ase2_mW = (G2*F2 - 1)*h_planck*f_opt*Fs/2*1e3;
ase2_ref_mW = ase2_mW*p.signal_interval/Fs;
scale2 = 10^(limit2/10)/(10^(limit2/10) + ase2_ref_mW);
budget_target(10) = budget_target(9) + 10*log10(G2*scale2);
budget_total(10) = 10*log10((10^(limit2/10) + ase2_mW)*scale2);
budget_ase2 = 10*log10(ase2_mW*scale2);

% SNR budget (step22 section 6 + the AWG crosstalk term of step21)
eq_penalty = T_sig*sum(w_sig./Hawg.^2);
nsr_ase1 = (ase1_mW*p.baudrate/Fs)/(G1*10^(budget_target(4)/10));
nsr_xt_sw1 = xt_sw1;
nsr_xt_awg = xt_awg_mW/10^(budget_target(7)/10)*eq_penalty;
nsr_xt_sw3 = xt_sw3_mW/10^(budget_target(7)/10)*eq_penalty;
nsr_ase2 = (ase2_mW*p.baudrate/Fs)/(G2*10^(budget_target(9)/10))*eq_penalty;
SNR_budget = -10*log10(nsr_ase1 + nsr_xt_sw1 + nsr_xt_awg + nsr_xt_sw3 + nsr_ase2);
BER_gauss = NaN;
if p.mod_flag ~= 5
    BER_gauss = 2/p.mod_flag*(1 - 1/sqrt(r.Mary)) ...
        *erfc(sqrt(3*10^(SNR_budget/10)/(2*(r.Mary - 1))));
end

b = struct('budget_target', budget_target, 'budget_total', budget_total, ...
    'budget_ase1', budget_ase1, 'budget_ase2', budget_ase2, ...
    'budget_sigpw_awg', budget_sigpw_awg, 'budget_sigpw', budget_sigpw, ...
    'nsr_ase1', nsr_ase1, 'nsr_xt_sw1', nsr_xt_sw1, 'nsr_xt_awg', nsr_xt_awg, ...
    'nsr_xt_sw3', nsr_xt_sw3, 'nsr_ase2', nsr_ase2, 'SNR_budget', SNR_budget, ...
    'BER_gauss', BER_gauss, 'eq_penalty', eq_penalty, 'T_sig', T_sig, 'T_ase', T_ase, ...
    'T_inband', T_inband, 'P_edfa_in', budget_target(4));
end
