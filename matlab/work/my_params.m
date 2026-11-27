function p = my_params()

p.datasize = 3e4;
p.PTx = 4;
p.sw_size = 64;
p.stage3_coupler_flag = 1;
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
p.AWG_loss = 6;
p.FWHM_AWG = 50e9;
p.AWG_XT = 32;
p.Morder = 16;
p.seed = 1;
p.BER_limit = 1e-2;
p.K = 2;
p.pattern = 'dispersed';

p.Mary = 2^p.mod_flag;
p.Fs = p.up*p.baudrate;
p.Hrcos = rcosfilter(p.datasize*p.up, p.baudrate, p.Fs, p.rolloff);
assert(p.xt_wave_max >= 1, 'xt_wave_max must be 1 or more (Inf = one waveform per leak)');

end
