function [amplified_signal, aseNoise] = amplified_by_EDFA3(signal, Fs, gain_dB, NF_dB, ...
    sat, N, B_ref)
%AMPLIFIED_BY_EDFA3  Optical amplifier (EDFA): gain, ASE noise and output power limit.
%
%   [amplified_signal, aseNoise] = ...
%       amplified_by_EDFA3(signal, Fs, gain_dB, NF_dB, sat, N, B_ref)
%
%   Inputs
%     signal   : optical field of ONE polarization of ONE wavelength channel,
%                column vector, n x 1 [sqrt(W)]
%     Fs       : sampling frequency = width of the simulated band [Hz]
%     gain_dB  : wanted power gain [dB]
%     NF_dB    : noise figure of the amplifier [dB]
%     sat      : saturation output power for the simulated polarization [dBm]
%                = the power that the amplifier can give to ALL its wavelength channels
%                  together, counted in the ONE polarization that is simulated
%                Without polarization multiplexing: the saturation power of the EDFA.
%                With polarization multiplexing: the saturation power of the EDFA - 3 dB,
%                because each polarization gets half of the output power.
%                The caller does this subtraction (sat = edfa_sat - 3*pol_flag).
%                Inf = no output limit.
%     N        : number of wavelength channels that THIS amplifier carries (>= 1)
%                The channels share the output power equally.
%                1 = the amplifier carries only this signal (receiver pre-amplifier).
%     B_ref    : optical bandwidth whose ASE shares the output power with the signal [Hz]
%                The scripts pass the channel spacing (signal_interval = 50e9).
%                It is used only in the formula of step 3, so it may be wider than Fs.
%                It does not change the ASE that is added to the field (step 2).
%   Outputs
%     amplified_signal  : amplified field with ASE noise, n x 1 [sqrt(W)]
%     aseNoise          : the ASE noise field that is inside amplified_signal, n x 1
%                         amplified_signal - aseNoise is the amplified signal without noise.
%
%   Legacy: amplified_by_EDFA3.m (same name; the first six arguments are the same)
%   and amplified_by_EDFA2.m.
%   The seventh argument B_ref is new. Legacy step 3 limited the measured power of
%   the output: the signal and ALL the ASE inside the simulated band Fs.
%   For a column vector and the same random seed the output field is the same as legacy
%   as long as the output limit is not reached. When it is reached, the output field
%   is the legacy field times one constant factor.
%   Legacy returned as aseNoise the ASE of both polarizations before the output limit.
%   Legacy treated a matrix input in an inconsistent way; now a matrix is an error.
%   Legacy amplified_by_EDFA2 (pre-amplifier) added the ASE of BOTH polarizations
%   to the one simulated polarization: 3 dB too much noise. It is replaced by this
%   function with N = 1.
%
%   What is simulated
%     The field "signal" is ONE polarization of ONE wavelength channel.
%     With polarization multiplexing the other polarization carries a second signal
%     of the same power. It is not simulated, because it behaves in the same way.
%     So every power in this function is a power in one polarization.
%     Polarization multiplexing changes only two numbers, and the caller sets both:
%     the power of the simulated signal (pin = PTx - 3 dB) and sat (edfa_sat - 3 dB).
%
%   Step 1 - gain
%     limit = sat - 10*log10(N) [dBm] is the output power available to this signal.
%     The signal power is multiplied by G = 10^(gain_dB/10).
%     If the amplified signal would be above limit, G is reduced
%     so that the amplified signal alone has exactly the power limit.
%
%   Step 2 - ASE noise (amplified spontaneous emission)
%     An amplifier with gain G and noise figure F = 10^(NF_dB/10) emits ASE
%     in BOTH polarizations. Its power in a bandwidth B is
%       both polarizations together : (G*F - 1) * h * f * B        [W]
%       ONE polarization            : (G*F - 1) * h * f * B / 2    [W]
%     (h = Planck constant, f = optical frequency, h*f = energy of one photon.)
%     A coherent receiver detects the two polarizations separately.
%     A signal is disturbed only by the ASE in its own polarization.
%     So the noise added to the one simulated polarization is
%       P_ase = (G*F - 1) * h * f * Fs / 2   [W]
%     It is white Gaussian noise over the whole simulated band Fs.
%     The factor 1/2 is used with AND without polarization multiplexing:
%     it only says that the simulated field is one polarization.
%
%   Step 3 - output power limit
%     The output power of the amplifier is shared by the signal AND the ASE.
%     The ASE that is counted for this signal is the ASE in the bandwidth B_ref:
%       P_total = G*P_in + (G*F - 1) * h * f * B_ref / 2   [W]
%     (P_in = input power of the signal [W]; one polarization, like every power here.)
%     P_total is computed from this formula. It is not measured on the samples.
%     If P_total is above limit, signal and ASE are scaled by the power factor
%     limit/P_total. Then the signal and the ASE in B_ref together have exactly limit.
%     Signal and ASE are scaled by the same factor, so the SNR does not change.
%
%   Where the ASE formula comes from
%     ASE power in one polarization: n_sp * (G - 1) * h * f * B,
%     n_sp = spontaneous emission factor of the amplifier (1 or larger).
%     The noise figure is defined as F = 2*n_sp*(G - 1)/G + 1/G.
%     Solve for n_sp: n_sp*(G - 1) = (G*F - 1)/2. This gives the formula of step 2.
%
%   Resulting SNR in a bandwidth B, when G*F is much larger than 1
%     signal in one polarization only, input power P_in:
%       SNR = G*P_in / ((G*F - 1)*h*f*B/2), which is 2*P_in / (F*h*f*B) for large G*F
%     polarization-multiplexed signal, TOTAL input power P_in of both polarizations:
%       each polarization carries P_in/2 and sees the ASE of its own polarization,
%       SNR = G*(P_in/2) / ((G*F - 1)*h*f*B/2), which is P_in / (F*h*f*B) for large G*F
%     In dB, for B = 12.5 GHz (0.1 nm) and a polarization-multiplexed signal:
%       SNR [dB] = P_in [dBm] + 58 - NF_dB     (58 dB = 1 mW / (h*f*12.5 GHz)).
%     The input power of the amplifier and its noise figure decide the SNR.
%     The gain and the output limit do not change it (as long as G*F is large).
%
%   Example 1: EDFA of a wavelength-routing switch. N wavelengths in total,
%   ULCF AWG with ULCF_deg input ports = ULCF_deg EDFAs, each carries N/ULCF_deg channels.
%     signal_interval = 50e9;  (channel spacing [Hz])
%     sat1 = edfa_sat1 - 3*pol_flag;
%     edfaGain = sat1 - 10*log10(N/ULCF_deg) - calc_signal_power(signal);
%     signal = amplified_by_EDFA3(signal, Fs, edfaGain, NF, sat1, N/ULCF_deg, ...
%         signal_interval);
%   Example 2: pre-amplifier in front of the receiver (one wavelength channel).
%     sat2 = edfa_sat2 - 3*pol_flag;
%     edfaGain = sat2 - calc_signal_power(signal);
%     signal = amplified_by_EDFA3(signal, Fs, edfaGain, NF2, sat2, 1, signal_interval);
%
%   Note: in both examples the gain is chosen so that the signal reaches limit.
%   Note: step 3 then removes the small excess caused by the ASE in B_ref.
%   Note: the signal and the ASE in B_ref together then always have the power limit
%         (constant output power operation).
%   Note: why the ASE of ONE channel spacing is counted in step 3:
%         the output power of the amplifier is shared by the signals AND the ASE of
%         the whole amplified band. N channels fill a band of N channel spacings,
%         so one channel spacing of ASE belongs to each channel.
%   Note: the result does not depend on the oversampling rate up (Fs = up*baudrate).
%         A larger up puts more ASE into the simulated band (step 2), but step 3
%         counts only the ASE in B_ref. So the signal power after the amplifier and
%         the SNR in the signal band are the same for every up.
%   Note: calc_signal_power(amplified_signal) counts all the ASE inside Fs. It is
%         close to limit, and equal to limit only if Fs = B_ref.
%   Note: G*F must not be below 1 (gain_dB must be larger than -NF_dB).
%   Note: if G*F is below 1 the ASE power would be negative: the function stops
%         with an error (the legacy code added noise of the power abs(P_ase)).
%   Note: step 1 can cause this, when the input power is more than NF_dB above limit.
%   Note: a real EDFA has a noise figure of about 4 to 6 dB (3 dB is the lowest
%         possible value at high gain, because n_sp cannot be smaller than 1).
%   Note: the random numbers come from randn; fix the seed with rng to repeat a run.

if nargin < 7
    error(['amplified_by_EDFA3: seven inputs are needed: ' ...
        'signal, Fs, gain_dB, NF_dB, sat, N, B_ref.']);
end
if size(signal, 2) ~= 1
    error('amplified_by_EDFA3: signal must be one column vector (n x 1).');
end
if N < 1
    error('amplified_by_EDFA3: N is a number of wavelength channels and must be >= 1.');
end
if ~isscalar(B_ref) || ~(B_ref > 0) || ~isfinite(B_ref)
    error('amplified_by_EDFA3: B_ref is a bandwidth in Hz and must be a positive number.');
end

h = 6.62607004e-34;  % Planck constant [J s] (legacy value)
f = 299792458/1550e-9;  % optical frequency at the wavelength 1550 nm [Hz]
n = size(signal, 1);  % number of samples

% ---- Step 1: gain, reduced if the signal alone would be above the limit ----
limit = sat - 10*log10(N);  % output power available to this signal [dBm]
P_in = calc_signal_power(signal);  % input power of the signal [dBm]
if P_in + gain_dB > limit
    gain_dB = limit - P_in;  % now the amplified signal alone has the power limit
end
gain = 10^(gain_dB/10);  % power gain G, dB -> linear
F = 10^(NF_dB/10);  % noise figure F, dB -> linear

% ---- Step 2: ASE noise of ONE polarization ----
if gain*F < 1
    error(['amplified_by_EDFA3: gain*F is below 1 (gain ' num2str(gain_dB) ' dB, NF ' ...
        num2str(NF_dB) ' dB), so the ASE power would be negative. ' ...
        'Check gain_dB, and check that the input power is not far above the limit.']);
end
P_ase = (gain*F - 1) * h * f * Fs / 2;  % ASE power in one polarization inside Fs [W]
noise_re = randn(n, 1);  % real part first, then the imaginary part (legacy order)
noise_im = randn(n, 1);
% (noise_re + 1i*noise_im)/sqrt(2) has the mean power 1, so aseNoise has P_ase
aseNoise = sqrt(P_ase) * (noise_re + 1i*noise_im) / sqrt(2);
amplified_signal = sqrt(gain) * signal + aseNoise;  % POWER gain G = FIELD factor sqrt(G)

% ---- Step 3: signal + ASE inside B_ref must not be above the limit ----
% P_total comes from the formula, not from the samples: the scale factor is not random.
P_in_W = 10^(P_in/10) * 1e-3;  % input power of the signal, dBm -> W
P_total = gain*P_in_W + (gain*F - 1) * h * f * B_ref / 2;  % signal + ASE in B_ref [W]
P_total_dBm = 10*log10(P_total * 1e3);  % the same power, W -> dBm
if P_total_dBm > limit
    excess = P_total_dBm - limit;  % power above the limit [dB] = P_total/limit in dB
    amplified_signal = attenuation(amplified_signal, excess);
    aseNoise = attenuation(aseNoise, excess);  % the same factor: the SNR is unchanged
end
end
