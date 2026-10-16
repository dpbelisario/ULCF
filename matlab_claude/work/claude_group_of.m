function g = claude_group_of(i, N, K)
%CLAUDE_GROUP_OF  Input group of first-stage switch i in the proposed switch.
%
%   g = claude_group_of(i, N, K)
%
%   The N first-stage switches are divided into K groups of N/K consecutive
%   switches: group 1 = switches 1 .. N/K, group 2 = N/K+1 .. 2N/K, and so on.
%   Group g enters input port g of the ULCF AWG pair in EVERY wavelength-routing
%   switch (design rule of the proposal, docs/01 paragraph 6 and work1 header).
%
%   Inputs
%     i : first-stage switch number(s), 1 .. N (array allowed)
%     N : number of first-stage switches = number of wavelength channels
%     K : number of input groups = input ports of the ULCF AWG; K must divide N
%   Output
%     g : group number(s), 1 .. K, same shape as i
%
%   Written by Claude for work1. Any other division into K equal groups gives the
%   same leak counts (see claude_work1_wavelength_rule, section 3).
if mod(N, K) ~= 0
    error('claude_group_of: K = %d must divide N = %d.', K, N);
end
if any(i(:) < 1) || any(i(:) > N) || any(i(:) ~= round(i(:)))
    error('claude_group_of: i must be an integer from 1 to N.');
end
g = floor((i - 1)*K/N) + 1;
end
