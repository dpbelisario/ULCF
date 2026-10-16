function loss = coupler_loss(N)
%COUPLER_LOSS  Insertion loss of an N x 1 optical coupler in dB.
%
%   loss = coupler_loss(N)
%
%   Inputs
%     N     : number of input ports of the coupler
%             integer >= 1; scalar or array
%   Outputs
%     loss  : insertion loss from one input port to the output port [dB], same size as N
%
%   Legacy: coupler_loss.m (same name, same argument).
%   Legacy wrote 3.5*log2(2^nextpow2(N)); this is the same number as 3.5*ceil(log2(N)).
%   Legacy accepted 0, negative and non-integer N; now they are errors.
%   Note: a coupler is passive: it adds the light of all N inputs into one output.
%   Note: an N x 1 coupler is a tree of 2 x 1 couplers with ceil(log2(N)) stages.
%   Note: a 2 x 1 coupler loses half of the power (3 dB); 0.5 dB more is excess loss.
%   Note: rule: 3.5 dB per stage, so loss = 3.5*ceil(log2(N)) dB.
%   Example: coupler_loss(2) = 3.5 dB, coupler_loss(8) = 10.5 dB, coupler_loss(1) = 0 dB.
%   Note: if N is not a power of 2 the number of stages is rounded UP, on purpose.
%   Note: a tree for 96 inputs needs 7 stages, the same as a tree for 128 inputs.
%   Example: coupler_loss(96) = coupler_loss(128) = 24.5 dB.
%   Note: the loss is therefore a staircase: 65 to 128 inputs all cost 24.5 dB.
%   Note: this loss is the reason for the ULCF AWG with K input ports:
%         each coupler then has only N/K inputs, which saves 3.5 dB per factor of 2.
%   Example: coupler_loss(96) - coupler_loss(96/12) = 24.5 - 10.5 = 14 dB.

if any(N(:) < 1) || any(N(:) ~= round(N(:)))
    error('coupler_loss: N is a number of ports and must be an integer >= 1.');
end

stages = ceil(log2(N));  % number of 2 x 1 couplers that the light passes
loss = 3.5 * stages;  % 3.5 dB per stage [dB]
end
