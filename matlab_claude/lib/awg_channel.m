function ch = awg_channel(in_port, out_port, N)
%AWG_CHANNEL  Wavelength channel that an AWG routes from an input port to an output port.
%
%   ch = awg_channel(in_port, out_port, N)
%
%   Inputs
%     in_port   : input port number of the AWG, integer 1 to N (scalar or array)
%     out_port  : output port number of the AWG, integer 1 to N (scalar or array)
%     N         : number of wavelength channels (= number of output ports), integer >= 1
%   Outputs
%     ch        : number of the wavelength channel, integer 1 to N
%                 Light that enters at in_port leaves at out_port only on this channel.
%
%   Legacy: none (new function).
%   Note: rule of a cyclic AWG: ch = mod(out_port + in_port - 2, N) + 1.
%   Note: from input port 1, output port j receives channel j.
%   Note: from input port a + 1, output port j receives channel j + a.
%   Note: a channel number above N wraps around to 1 (this is the word "cyclic").
%   Example: N = 96: awg_channel(1, 5, 96) = 5, awg_channel(3, 5, 96) = 7,
%            awg_channel(3, 96, 96) = 2.
%   Note: this is the rule of the ULCF AWG in JOCN 2018, Fig. 4 (input port a + 1).
%   Note: a ULCF AWG with K input ports uses in_port = 1 to K only.
%   Note: a transmitter reaches an output port by tuning its laser to channel ch.
%   Note: seen from one input port, every output port has a different channel.
%   Note: seen from one output port, every input port has a different channel.
%   Note: so two signals of the same channel from different input ports
%         never leave at the same output port.
%   Note: the rule read backwards: out_port = mod(ch - in_port, N) + 1.
%   Note: in_port and out_port can be arrays of the same size.
%   Note: a column of input ports and a row of output ports give the whole table:
%         awg_channel((1:K).', 1:N, N) is K x N.

if numel(N) ~= 1 || N < 1 || N ~= round(N)
    error('awg_channel: N is a number of channels and must be one integer >= 1.');
end
if any(in_port(:) < 1) || any(in_port(:) > N) || any(in_port(:) ~= round(in_port(:)))
    error('awg_channel: in_port must be an integer from 1 to N.');
end
if any(out_port(:) < 1) || any(out_port(:) > N) || any(out_port(:) ~= round(out_port(:)))
    error('awg_channel: out_port must be an integer from 1 to N.');
end

% (in_port - 1) is the shift a of the rule; the two "- 1" make the numbers start at 0,
% mod wraps them into 0 to N-1, and "+ 1" brings them back to 1 to N.
ch = mod(out_port + in_port - 2, N) + 1;
end
