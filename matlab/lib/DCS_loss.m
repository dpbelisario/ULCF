function loss = DCS_loss(M)
%DCS_LOSS  Insertion loss of an M x M delivery-and-coupling (DC) switch in dB.
%
%   loss = DCS_loss(M)
%
%   Inputs
%     M     : number of input ports (= number of output ports) of the DC switch
%             integer >= 1; scalar or array
%   Outputs
%     loss  : insertion loss from an input port to an output port [dB], same size as M
%
%   Legacy: DCS_loss.m (same name, same argument).
%   Legacy used 4*log2(M) without rounding; the result is the same if M is a power of 2.
%   Note: an M x M DC switch has one 1 x M selector at every input port
%         and one M x 1 coupler at every output port.
%   Note: a signal passes one selector (delivery part) and one coupler (coupling part).
%   Note: loss = selector_loss(M) + coupler_loss(M) = 4*ceil(log2(M)) dB.
%   Note: that is 0.5 dB + 3.5 dB = 4 dB for every factor of 2 in M.
%   Example: DCS_loss(2) = 4 dB, DCS_loss(8) = 12 dB, DCS_loss(32) = 20 dB.
%   Note: if M is not a power of 2 it is rounded up, with the same rule as coupler_loss.
%   Example: DCS_loss(12) = DCS_loss(16) = 16 dB.
%   Note: the main scripts call M dcs_input_port_num.

if any(M(:) < 1) || any(M(:) ~= round(M(:)))
    error('DCS_loss: M is a number of ports and must be an integer >= 1.');
end

loss = selector_loss(M) + coupler_loss(M);  % delivery part + coupling part [dB]
end
