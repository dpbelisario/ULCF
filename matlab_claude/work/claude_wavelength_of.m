function ch = claude_wavelength_of(i, j, N, K)
%CLAUDE_WAVELENGTH_OF  Wavelength rule of the proposed three-stage switch.
%
%   ch = claude_wavelength_of(i, j, N, K)
%
%   Channel of a connection from first-stage switch i to third-stage switch j.
%   It does NOT depend on the wavelength-routing (WR) switch that carries the
%   connection: every WR switch connects group g(i) to its AWG input port g(i),
%   and output port j of every WR switch goes to third-stage switch j. So
%     ch = awg_channel(g(i), j, N) = mod(j + g(i) - 2, N) + 1
%   With K = 1 every switch is in group 1 and ch = j: the conventional switch.
%
%   Inputs
%     i, j : first-stage and third-stage switch numbers, 1 .. N (arrays of the
%            same shape, or one scalar and one array)
%     N, K : number of channels (= switches per stage) and number of input groups
%   Output
%     ch   : wavelength channel number(s), 1 .. N
%
%   Written by Claude for work1.
g = claude_group_of(i, N, K);
ch = awg_channel(g, j, N);
end
