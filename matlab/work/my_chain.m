function r = my_chain(p)

datasize = p.datasize;
PTx = p.PTx;
sw_size = p.sw_size;
stage3_coupler_flag = p.stage3_coupler_flag;
mod_flag = p.mod_flag;
up = p.up;
baudrate = p.baudrate;
pol_flag = p.pol_flag;
fiber_flag = p.fiber_flag;
Fan_in_loss = p.Fan_in_loss;
Fan_out_loss = p.Fan_out_loss;
N = p.N;
signal_interval = p.signal_interval;
NF = p.NF;
edfa_sat1 = p.edfa_sat1;
edfa_sat2 = p.edfa_sat2;
NF2 = p.NF2;
rolloff = p.rolloff;
sel_ex_ratio = p.sel_ex_ratio;
xt_wave_max = p.xt_wave_max;
AWG_loss = p.AWG_loss;
FWHM_AWG = p.FWHM_AWG;
AWG_XT = p.AWG_XT;
Morder = p.Morder;
seed = p.seed;
K = p.K;
pattern = p.pattern;
Mary = p.Mary;
Fs = p.Fs;
Hrcos = p.Hrcos;
assert(mod(N, K) == 0);

rng(seed);
stage_power = zeros(1, 10);

% [1] Transmitter of the target signal
pin = PTx - 3*pol_flag;
[signal, data, data_mod] = TL_QAM(datasize, up, Hrcos, pin, mod_flag);
stage_power(1) = calc_signal_power(signal);

% [2] Fan-in and fan-out of the multicore fiber
fiber_loss = 0;
if fiber_flag == 1
    fiber_loss = Fan_in_loss + Fan_out_loss;
end
signal = attenuation(signal, fiber_loss);
stage_power(2) = calc_signal_power(signal);

% [3] Stage-1 space switch, selector + selector
sw1_loss = 2*selector_loss(sw_size);
sw1_xt_att = 2*sel_ex_ratio;
num_xt = sw_size - 1;
num_xt_wave = min(num_xt, floor(xt_wave_max));
xt_boost = 10*log10(num_xt/num_xt_wave);
xt_power = pin - fiber_loss + xt_boost;
crosstalk = zeros(datasize*up, 1);
for k = 1:num_xt_wave
    [xt, ~, ~] = TL_QAM(datasize, up, Hrcos, xt_power, mod_flag);
    crosstalk = crosstalk + xt;
end
signal = signal + attenuation(crosstalk, sw1_xt_att);
signal = attenuation(signal, sw1_loss);
stage_power(3) = calc_signal_power(signal);

% [4] Aggregation coupler
N_agg = N/K;
agg_coupler_loss = coupler_loss(N_agg);
signal = attenuation(signal, agg_coupler_loss);
stage_power(4) = calc_signal_power(signal);

% [5] EDFA of the wavelength-routing switch
sat1 = edfa_sat1 - 3*pol_flag;
edfaGain = sat1 - 10*log10(N_agg) - calc_signal_power(signal);
[signal, aseNoise] = amplified_by_EDFA3(signal, Fs, edfaGain, NF, sat1, N_agg, ...
    signal_interval);
stage_power(5) = calc_signal_power(signal);

% [6] AWG
shift = 0;
if K > 1
    AWG_loss = 9;
    AWG_loss = AWG_loss + coupler_loss(2);
    FWHM_AWG = 66.6e9;
    shift = ULCF_dev_freq(K);
end

signal = awg(signal, AWG_loss, shift, Fs, FWHM_AWG, AWG_XT, 1);
stage_power(6) = calc_signal_power(signal);

% [7] In-band crosstalk of the ULCF AWG (legacy lines 172-183)
Hband = nyquistfilter(datasize*up, 0, Fs, baudrate*(1+rolloff));
if K > 1
    AWG_crosstalk = zeros(datasize*up, K - 1);
    sigpw = calc_signal_power(apply_filter(signal, Hband, 1));
    for k = 1:(K-1)
        [AWG_crosstalk(:, k), ~, ~] = ...
            TL_QAM(datasize, up, Hrcos, sigpw, mod_flag);
    end
    AWG_crosstalk = attenuation(AWG_crosstalk, AWG_XT);
    AWG_crosstalk = sum(AWG_crosstalk, 2);
    signal = signal + AWG_crosstalk;
end
stage_power(7) = calc_signal_power(signal);

% [8] Stage-3 space switch
if stage3_coupler_flag == 1
    sw3_loss = selector_loss(sw_size) + coupler_loss(sw_size);
    sw3_xt_att = sel_ex_ratio;
else
    sw3_loss = 2*selector_loss(sw_size);
    sw3_xt_att = 2*sel_ex_ratio;
end
Hband = nyquistfilter(datasize*up, 0, Fs, baudrate*(1+rolloff));
num_xt3 = my_inband_leaks(sw_size, K, pattern);
sigpw = calc_signal_power(apply_filter(signal, Hband, 1));
crosstalk = zeros(datasize*up, 1);
if num_xt3 > 0
    num_xt3_wave = min(num_xt3, floor(xt_wave_max));
    xt3_boost = 10*log10(num_xt3/num_xt3_wave);
    xt_power = sigpw + xt3_boost;
    for k = 1:num_xt3_wave
        [xt, ~, ~] = TL_QAM(datasize, up, Hrcos, xt_power, mod_flag);
        crosstalk = crosstalk + xt;
    end
end
signal = signal + attenuation(crosstalk, sw3_xt_att);
signal = attenuation(signal, sw3_loss);
stage_power(8) = calc_signal_power(signal);

% [9] Fan-in and fan-out of the multicore fiber again
signal = attenuation(signal, fiber_loss);
stage_power(9) = calc_signal_power(signal);

% [10] Pre-amplifier of the receiver
sat2 = edfa_sat2 - 3*pol_flag;
edfaGain = sat2 - calc_signal_power(signal);
[signal, aseNoise2] = amplified_by_EDFA3(signal, Fs, edfaGain, NF2, sat2, 1, ...
    signal_interval);
stage_power(10) = calc_signal_power(signal);

% [11] Coherent receiver and BER
H = nyquistfilter(length(signal), 0, Fs, baudrate*(1+rolloff));
signal = apply_filter(signal, H, 1);
training_num = floor(datasize/3);
signal = adequalizet(signal, Mary, Morder, 1/256, ...
    data_mod(1:training_num), up);
BER = measure_BER_QAM(signal(training_num+1:end), ...
    data(mod_flag*training_num+1:end), mod_flag);

rx_sym = signal(training_num+1:end);
tx_sym = data_mod(training_num+1:end);
g = sum(conj(tx_sym).*rx_sym)/sum(abs(tx_sym).^2);
err_sym = rx_sym - g*tx_sym;
SNR_sim = 10*log10(abs(g)^2*mean(abs(tx_sym).^2)/mean(abs(err_sym).^2));

r.BER = BER;
r.SNR_sim = SNR_sim;
r.stage_power = stage_power;
r.rx_sym = rx_sym;
r.training_num = training_num;
r.aseNoise = aseNoise;
r.aseNoise2 = aseNoise2;
r.sigpw = sigpw;
r.Hband = Hband;
r.pin = pin;
r.fiber_loss = fiber_loss;
r.sw1_loss = sw1_loss;
r.sw1_xt_att = sw1_xt_att;
r.num_xt = num_xt;
r.agg_coupler_loss = agg_coupler_loss;
r.N_agg = N_agg;
r.sat1 = sat1;
r.AWG_loss = AWG_loss;
r.FWHM_AWG = FWHM_AWG;
r.shift = shift;
r.sw3_loss = sw3_loss;
r.sw3_xt_att = sw3_xt_att;
r.num_xt3 = num_xt3;
r.sat2 = sat2;

end
