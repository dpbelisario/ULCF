function signal_output = awg(signal_input, loss, shift, Fs, FWHM, er_dB, m)
%AWG  Pass a signal through one channel of an arrayed-waveguide grating (AWG).
%
%   signal_output = awg(signal_input, loss, shift, Fs, FWHM, er_dB, m)
%
%   Inputs
%     signal_input   : optical field, one signal per column [sqrt(W)]
%     loss           : insertion loss of the AWG at the passband center [dB]
%     shift          : center frequency of the passband on the baseband axis [Hz]
%                      0 = passband centered on the signal
%     Fs             : sampling frequency [Hz]
%     FWHM           : full width at half maximum of the POWER response [Hz]
%     er_dB          : extinction ratio of the passband shape [dB], must be >= 0
%     m              : order of the passband shape (1 = Gaussian)
%   Outputs
%     signal_output  : filtered and attenuated field [sqrt(W)]
%
%   Legacy: awg.m (same name, same arguments) and awg4nyquistWDM.m.
%   Legacy had these two identical files; this function replaces both.
%   Note: model = band-pass filter (gaussfilter) followed by a flat loss (attenuation).
%   Note: if shift is not 0, the signal sits on the slope of the passband.
%   Note: the filter then removes some signal power in addition to loss.
%   Note: er_dB only limits how deep the filter shape goes (see gaussfilter).
%   Note: crosstalk from other input ports is NOT made here.
%   Note: the main scripts add that crosstalk as separate interfering signals.

if size(signal_input, 1) == 1 && size(signal_input, 2) > 1
    error('awg: signal_input is a row vector. Signals must be column vectors.');
end

N = size(signal_input, 1);  % number of samples
H = gaussfilter(N, shift, Fs, FWHM, er_dB, m);  % passband shape, N x 1
signal_output = apply_filter(signal_input, H, 1);  % up = 1: filtering only
signal_output = attenuation(signal_output, loss);  % flat insertion loss
end
