function r = claude_chain_proposed(p)
%CLAUDE_CHAIN_PROPOSED  One operating point of the proposed three-stage switch.
%
%   r = claude_chain_proposed(p)      p = claude_params_proposed() with changes
%
%   The chain of step22_three_stage_one_point with a new middle stage:
%     [1] transmitter -> [2] fan-in/out -> [3] stage-1 switch (selector + selector)
%     -> [4] aggregation coupler, (N/K) x 1          (step22: N x 1)
%     -> [5] EDFA shared by N/K wavelengths           (step22: N)
%     -> [6] AWG: step22 AWG for K = 1, else 1 x 2 splitter + ULCF AWG pair
%     -> [7] in-band crosstalk of the ULCF AWG, K-1 leaks   (new, from step21)
%     -> [8] stage-3 switch: only the leaks of the target's input group are in
%            band (work1); the others are on other wavelengths and are either
%            left out (oob_flag = 0) or added at +-50 GHz (oob_flag = 1)
%     -> [9] fan-in/out -> [10] pre-amplifier -> [11] coherent receiver, BER
%   With K = 1, awg_type 'auto', oob_flag 0 and the step22 parameters, the random
%   numbers are drawn in exactly the order of step22: the result is bit for bit
%   the result of step22_three_stage_one_point (claude_test_proposed checks it).
%
%   Output r (struct): BER, SNR_sim, stage_power (1 x 10), sigpw_awg, sigpw,
%   ase1_sim, ase2_sim, rx_sym, tx_sym, the losses and counts that the budget
%   needs (sw1_loss, sw1_xt_att, num_xt1, agg_coupler_loss, N_agg, AWG_loss_tot,
%   FWHM, shift, num_xt_awg, sw3_loss, sw3_xt_att, num_xt3, num_oob, awg_type),
%   Hrcos, Hband, Fs, Mary, pin, fiber_loss, training_num.
%
%   Written by Claude for work2.

% ---- values that follow from the parameters ----
Mary = 2^p.mod_flag;
Fs = p.up*p.baudrate;
L = p.datasize*p.up;
Hrcos = rcosfilter(L, p.baudrate, Fs, p.rolloff);
assert(p.xt_wave_max >= 1, 'xt_wave_max must be 1 or more');
assert(mod(p.N, p.K) == 0, 'K must divide N');
awg_type = lower(p.awg_type);
if strcmp(awg_type, 'auto')
    if p.K == 1, awg_type = 'conv'; else, awg_type = 'ulcf'; end
end
M = p.sw_size;

rng(p.seed);
stage_power = zeros(1, 10);

% [1] Transmitter of the target signal
pin = p.PTx - 3*p.pol_flag;
[signal, data, data_mod] = TL_QAM(p.datasize, p.up, Hrcos, pin, p.mod_flag);
stage_power(1) = calc_signal_power(signal);

% [2] Fan-in and fan-out of the multicore fiber
fiber_loss = 0;
if p.fiber_flag == 1
    fiber_loss = p.Fan_in_loss + p.Fan_out_loss;
end
signal = attenuation(signal, fiber_loss);
stage_power(2) = calc_signal_power(signal);

% [3] Stage-1 space switch, selector + selector. Worst case as in step22: all
% M-1 other inputs are on the wavelength of the target (work1: the new rule
% does not change the first stage; the worst case is kept).
sw1_loss = 2*selector_loss(M);
sw1_xt_att = 2*p.sel_ex_ratio;
num_xt1 = M - 1;
num_xt1_wave = min(num_xt1, floor(p.xt_wave_max));
xt1_boost = 10*log10(num_xt1/num_xt1_wave);
xt_power = pin - fiber_loss + xt1_boost;
crosstalk = zeros(L, 1);
for k = 1:num_xt1_wave
    [xt, ~, ~] = TL_QAM(p.datasize, p.up, Hrcos, xt_power, p.mod_flag);
    crosstalk = crosstalk + xt;
end
signal = signal + attenuation(crosstalk, sw1_xt_att);
signal = attenuation(signal, sw1_loss);
stage_power(3) = calc_signal_power(signal);

% [4] Aggregation coupler of the target's input group: (N/K) x 1
N_agg = p.N/p.K;
agg_coupler_loss = coupler_loss(N_agg);
signal = attenuation(signal, agg_coupler_loss);
stage_power(4) = calc_signal_power(signal);

% [5] EDFA of the input group: its output power is shared by N/K wavelengths
sat1 = p.edfa_sat1 - 3*p.pol_flag;
edfaGain = sat1 - 10*log10(N_agg) - calc_signal_power(signal);
[signal, aseNoise] = amplified_by_EDFA3(signal, Fs, edfaGain, p.NF, sat1, N_agg, ...
    p.signal_interval);
stage_power(5) = calc_signal_power(signal);

% [6] AWG
if strcmp(awg_type, 'conv')
    AWG_loss_tot = p.AWG_loss_conv;
    FWHM = p.FWHM_conv;
    shift = 0;
    num_xt_awg = 0;
else
    AWG_loss_tot = p.AWG_loss_ulcf + p.splitter_loss;  % 1 x 2 splitter + ULCF AWG
    FWHM = p.FWHM_ulcf;
    shift = ULCF_dev_freq(p.K) + 12.5e9*(p.flg_NWDM ~= 0);  % worst input port
    num_xt_awg = p.K - 1;
end
signal = awg(signal, AWG_loss_tot, shift, Fs, FWHM, p.AWG_XT, 1);
stage_power(6) = calc_signal_power(signal);

% [7] In-band crosstalk of the ULCF AWG: the other K-1 input ports can carry the
% wavelength of the target (always the worst case, as in step21 block [7])
Hband = nyquistfilter(L, 0, Fs, p.baudrate*(1 + p.rolloff));
sigpw_awg = calc_signal_power(apply_filter(signal, Hband, 1));
if num_xt_awg > 0
    AWG_crosstalk = zeros(L, num_xt_awg);
    for k = 1:num_xt_awg
        [AWG_crosstalk(:, k), ~, ~] = TL_QAM(p.datasize, p.up, Hrcos, sigpw_awg, p.mod_flag);
    end
    signal = signal + sum(attenuation(AWG_crosstalk, p.AWG_XT), 2);
end
stage_power(7) = calc_signal_power(signal);

% [8] Stage-3 space switch. The M-1 other inputs come from the other WR switches
% with the power sigpw. Only those from the target's input group have the
% target's wavelength (work1): num_xt3 of them, from the traffic pattern.
if p.stage3_coupler_flag == 1
    sw3_loss = selector_loss(M) + coupler_loss(M);
    sw3_xt_att = p.sel_ex_ratio;
else
    sw3_loss = 2*selector_loss(M);
    sw3_xt_att = 2*p.sel_ex_ratio;
end
[num_xt3, n_per_group] = claude_inband_leaks(M, p.K, p.pattern);
sigpw = calc_signal_power(apply_filter(signal, Hband, 1));
crosstalk = zeros(L, 1);
if num_xt3 > 0
    num_xt3_wave = min(num_xt3, floor(p.xt_wave_max));
    xt3_boost = 10*log10(num_xt3/num_xt3_wave);
    xt_power = sigpw + xt3_boost;
    for k = 1:num_xt3_wave
        [xt, ~, ~] = TL_QAM(p.datasize, p.up, Hrcos, xt_power, p.mod_flag);
        crosstalk = crosstalk + xt;
    end
end
% leaks on other wavelengths: the two groups next to the target's group (the
% largest other groups, one channel = signal_interval away on each side)
num_oob = 0;
if p.oob_flag == 1 && p.K > 1
    n_side = [0 0];
    if p.K >= 2, n_side(1) = n_per_group(2); end
    if p.K >= 3, n_side(2) = n_per_group(3); end
    foff = [p.signal_interval, -p.signal_interval];
    need = p.signal_interval + p.baudrate*(1 + p.rolloff)/2;
    if Fs/2 < need
        error(['claude_chain_proposed: oob_flag = 1 needs Fs/2 >= %.0f GHz; ' ...
            'raise up to at least %d'], need/1e9, ceil(2*need/p.baudrate));
    end
    for s = 1:2
        if n_side(s) > 0
            n_wave = min(n_side(s), floor(p.xt_wave_max));
            boost = 10*log10(n_side(s)/n_wave);
            for k = 1:n_wave
                [xt, ~, ~] = TL_QAM(p.datasize, p.up, Hrcos, sigpw + boost, p.mod_flag);
                crosstalk = crosstalk + freqoff(xt, foff(s), Fs);
            end
            num_oob = num_oob + n_side(s);
        end
    end
end
signal = signal + attenuation(crosstalk, sw3_xt_att);
signal = attenuation(signal, sw3_loss);
stage_power(8) = calc_signal_power(signal);

% [9] Fan-in and fan-out again
signal = attenuation(signal, fiber_loss);
stage_power(9) = calc_signal_power(signal);

% [10] Pre-amplifier of the receiver
sat2 = p.edfa_sat2 - 3*p.pol_flag;
edfaGain = sat2 - calc_signal_power(signal);
[signal, aseNoise2] = amplified_by_EDFA3(signal, Fs, edfaGain, p.NF2, sat2, 1, ...
    p.signal_interval);
stage_power(10) = calc_signal_power(signal);

% [11] Coherent receiver and BER
H = nyquistfilter(length(signal), 0, Fs, p.baudrate*(1 + p.rolloff));
signal = apply_filter(signal, H, 1);
training_num = floor(p.datasize/3);
signal = adequalizet(signal, Mary, p.Morder, 1/256, data_mod(1:training_num), p.up);
BER = measure_BER_QAM(signal(training_num+1:end), ...
    data(p.mod_flag*training_num+1:end), p.mod_flag);

% SNR of the equalized symbols (as step22 section 4)
rx_sym = signal(training_num+1:end);
tx_sym = data_mod(training_num+1:end);
g = sum(conj(tx_sym).*rx_sym)/sum(abs(tx_sym).^2);
err_sym = rx_sym - g*tx_sym;
SNR_sim = 10*log10(abs(g)^2*mean(abs(tx_sym).^2)/mean(abs(err_sym).^2));

% ---- output ----
r = struct('BER', BER, 'SNR_sim', SNR_sim, 'stage_power', stage_power, ...
    'sigpw_awg', sigpw_awg, 'sigpw', sigpw, ...
    'ase1_sim', calc_signal_power(aseNoise), 'ase2_sim', calc_signal_power(aseNoise2), ...
    'rx_sym', rx_sym, 'tx_sym', tx_sym, 'pin', pin, 'fiber_loss', fiber_loss, ...
    'sw1_loss', sw1_loss, 'sw1_xt_att', sw1_xt_att, 'num_xt1', num_xt1, ...
    'agg_coupler_loss', agg_coupler_loss, 'N_agg', N_agg, 'sat1', sat1, 'sat2', sat2, ...
    'AWG_loss_tot', AWG_loss_tot, 'FWHM', FWHM, 'shift', shift, 'num_xt_awg', num_xt_awg, ...
    'sw3_loss', sw3_loss, 'sw3_xt_att', sw3_xt_att, 'num_xt3', num_xt3, 'num_oob', num_oob, ...
    'awg_type', awg_type, 'Hrcos', Hrcos, 'Hband', Hband, 'Fs', Fs, 'Mary', Mary, ...
    'training_num', training_num, 'num_bits', p.mod_flag*(p.datasize - training_num));
end
