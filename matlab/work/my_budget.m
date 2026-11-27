function b = my_budget(p, r)

datasize = p.datasize;
up = p.up;
baudrate = p.baudrate;
mod_flag = p.mod_flag;
signal_interval = p.signal_interval;
NF = p.NF;
NF2 = p.NF2;
AWG_XT = p.AWG_XT;
K = p.K;
Mary = p.Mary;
Fs = p.Fs;
Hrcos = p.Hrcos;
pin = r.pin;
fiber_loss = r.fiber_loss;
sw1_loss = r.sw1_loss;
sw1_xt_att = r.sw1_xt_att;
num_xt = r.num_xt;
agg_coupler_loss = r.agg_coupler_loss;
N_agg = r.N_agg;
sat1 = r.sat1;
AWG_loss = r.AWG_loss;
FWHM_AWG = r.FWHM_AWG;
shift = r.shift;
Hband = r.Hband;
sw3_loss = r.sw3_loss;
sw3_xt_att = r.sw3_xt_att;
num_xt3 = r.num_xt3;
sat2 = r.sat2;

h_planck = 6.62607004e-34;
f_opt = 299792458/1550e-9;
budget_target = zeros(1, 10);
budget_total = zeros(1, 10);

% [1] to [4]
xt_sw1 = num_xt*10^(-sw1_xt_att/10);
budget_target(1) = pin;
budget_total(1) = pin;
budget_target(2) = budget_target(1) - fiber_loss;
budget_total(2) = budget_target(2);
budget_target(3) = budget_target(2) - sw1_loss;
budget_total(3) = budget_target(3) + 10*log10(1 + xt_sw1);
budget_target(4) = budget_target(3) - agg_coupler_loss;
budget_total(4) = budget_total(3) - agg_coupler_loss;

% [5] EDFA
limit1 = sat1 - 10*log10(N_agg);
G1 = 10^((limit1 - budget_total(4))/10);
F1 = 10^(NF/10);
ase1_mW = (G1*F1 - 1)*h_planck*f_opt*Fs/2*1e3;
ase1_ref_mW = ase1_mW*signal_interval/Fs;
scale1 = 10^(limit1/10)/(10^(limit1/10) + ase1_ref_mW);
budget_target(5) = budget_target(4) + 10*log10(G1*scale1);
budget_total(5) = 10*log10((10^(limit1/10) + ase1_mW)*scale1);
budget_ase1 = 10*log10(ase1_mW*scale1);

% [6] AWG
Hawg = gaussfilter(datasize*up, shift, Fs, FWHM_AWG, AWG_XT, 1);
w_sig = Hrcos.^2/sum(Hrcos.^2);
T_sig = sum(w_sig.*Hawg.^2);
T_ase = mean(Hawg.^2);
T_inband = mean(Hband.^2.*Hawg.^2);
budget_target(6) = budget_target(5) - AWG_loss + 10*log10(T_sig);
sig6_mW = 10^(budget_target(6)/10)*(1 + xt_sw1);
ase6_mW = ase1_mW*scale1*10^(-AWG_loss/10);
budget_total(6) = 10*log10(sig6_mW + ase6_mW*T_ase);

% [7] AWG crosstalk
budget_sigpw = 10*log10(sig6_mW + ase6_mW*T_inband);
xt_awg_mW = 0;
if K > 1
    xt_awg_mW = (K - 1)*10^((budget_sigpw - AWG_XT)/10);
end
budget_target(7) = budget_target(6);
budget_total(7) = 10*log10(10^(budget_total(6)/10) + xt_awg_mW);

% [8] Stage-3 switch
budget_sigpw = 10*log10(sig6_mW + ase6_mW*T_inband + xt_awg_mW);
xt_sw3_mW = num_xt3*10^((budget_sigpw - sw3_xt_att)/10);
budget_target(8) = budget_target(7) - sw3_loss;
budget_total(8) = 10*log10(10^(budget_total(7)/10) + xt_sw3_mW) - sw3_loss;

% [9] fan-in and fan-out
budget_target(9) = budget_target(8) - fiber_loss;
budget_total(9) = budget_total(8) - fiber_loss;

% [10] Pre-amplifier
limit2 = sat2;
G2 = 10^((limit2 - budget_total(9))/10);
F2 = 10^(NF2/10);
ase2_mW = (G2*F2 - 1)*h_planck*f_opt*Fs/2*1e3;
ase2_ref_mW = ase2_mW*signal_interval/Fs;
scale2 = 10^(limit2/10)/(10^(limit2/10) + ase2_ref_mW);
budget_target(10) = budget_target(9) + 10*log10(G2*scale2);
budget_total(10) = 10*log10((10^(limit2/10) + ase2_mW)*scale2);
budget_ase2 = 10*log10(ase2_mW*scale2);

% Closed-form SNR budget
eq_penalty = T_sig*sum(w_sig./Hawg.^2);
nsr_ase1 = (ase1_mW*baudrate/Fs)/(G1*10^(budget_target(4)/10));
nsr_xt_sw1 = xt_sw1;
nsr_xt_awg = xt_awg_mW/10^(budget_target(7)/10)*eq_penalty;
nsr_xt_sw3 = xt_sw3_mW/10^(budget_target(7)/10)*eq_penalty;
nsr_ase2 = (ase2_mW*baudrate/Fs)/(G2*10^(budget_target(9)/10))*eq_penalty;
SNR_budget = -10*log10(nsr_ase1 + nsr_xt_sw1 + nsr_xt_awg + nsr_xt_sw3 + nsr_ase2);

BER_gauss = NaN;
if mod_flag ~= 5
    BER_gauss = 2/mod_flag*(1 - 1/sqrt(Mary)) ...
        *erfc(sqrt(3*10^(SNR_budget/10)/(2*(Mary - 1))));
end

b.budget_target = budget_target;
b.budget_total = budget_total;
b.budget_ase1 = budget_ase1;
b.budget_ase2 = budget_ase2;
b.budget_sigpw = budget_sigpw;
b.eq_penalty = eq_penalty;
b.nsr_ase1 = nsr_ase1;
b.nsr_xt_sw1 = nsr_xt_sw1;
b.nsr_xt_awg = nsr_xt_awg;
b.nsr_xt_sw3 = nsr_xt_sw3;
b.nsr_ase2 = nsr_ase2;
b.SNR_budget = SNR_budget;
b.BER_gauss = BER_gauss;

end
