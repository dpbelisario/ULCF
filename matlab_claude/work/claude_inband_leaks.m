function [n_inband, n_per_group] = claude_inband_leaks(M, K, pattern)
%CLAUDE_INBAND_LEAKS  Leaks on the wavelength of the target in one third-stage switch.
%
%   [n_inband, n_per_group] = claude_inband_leaks(M, K, pattern)
%
%   A third-stage switch has M inputs, one from each WR switch. All M carry a
%   signal (full load, as step22 assumes). Each signal comes from some first-stage
%   switch, and its wavelength is fixed by the input group of that switch (see
%   claude_wavelength_of). A leak is on the target's wavelength (in band) exactly
%   when its source is in the SAME input group as the target's source.
%
%   pattern = 'dispersed'
%     The M sources are spread as evenly as possible over the K groups, and the
%     target is in a group of the largest size: n_inband = ceil(M/K) - 1.
%     This is the worst case of an even spread. (For sources drawn at random
%     with equal probability, the mean is (M-1)/K; see claude_work1 section 4.)
%   pattern = 'concentrated'
%     All M sources are in the target's group: n_inband = M - 1. The wavelengths
%     are all equal, exactly as in the conventional switch.
%   With K = 1 both patterns give M - 1 (the conventional switch, step22 block [7]).
%
%   Outputs
%     n_inband    : number of leaks on the target's wavelength
%     n_per_group : 1 x K vector, number of the M signals in each group, the
%                   target's group first (group order is otherwise arbitrary)
%
%   Written by Claude for work1.
if M < 1 || K < 1 || M ~= round(M) || K ~= round(K)
    error('claude_inband_leaks: M and K must be positive integers.');
end
switch lower(pattern)
    case 'dispersed'
        base = floor(M/K);
        extra = M - base*K;  % the first "extra" groups get one more signal
        n_per_group = base*ones(1, K);
        n_per_group(1:extra) = base + 1;
        n_per_group = sort(n_per_group, 'descend');  % target in a largest group
    case 'concentrated'
        n_per_group = zeros(1, K);
        n_per_group(1) = M;
    otherwise
        error('claude_inband_leaks: pattern must be ''dispersed'' or ''concentrated''.');
end
n_inband = n_per_group(1) - 1;
end
