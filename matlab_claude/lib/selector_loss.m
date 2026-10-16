function loss = selector_loss(M)
%SELECTOR_LOSS  Insertion loss of a 1 x M (or M x 1) optical selector in dB.
%
%   loss = selector_loss(M)
%
%   Inputs
%     M     : number of ports on the many-port side of the selector
%             integer >= 1; scalar or array
%   Outputs
%     loss  : insertion loss [dB], same size as M
%
%   Legacy: none (new function).
%   Legacy had only the sum for a DC switch: DCS_loss, 4 dB per stage = 0.5 dB + 3.5 dB.
%   Note: a selector is a switch: it connects its single port to ONE of the M ports.
%   Note: a 1 x M selector is a tree of 1 x 2 switch elements.
%   Note: the light passes ceil(log2(M)) elements, one per stage of the tree.
%   Note: rule: 0.5 dB per stage, so loss = 0.5*ceil(log2(M)) dB.
%   Example: selector_loss(2) = 0.5 dB, selector_loss(64) = 3 dB, selector_loss(1) = 0 dB.
%   Note: if M is not a power of 2 the tree is as deep as for the next power of 2.
%   Example: selector_loss(96) = selector_loss(128) = 3.5 dB.
%   Note: compare with coupler_loss: a coupler costs 3.5 dB per stage, a selector 0.5 dB.
%   Note: the price of the low loss is hardware: M - 1 switch elements and their control.
%   Note: a real selector also leaks a little light from the ports that are switched off.
%   Note: this leak is NOT made here; the main scripts add it with an extinction ratio.

if any(M(:) < 1) || any(M(:) ~= round(M(:)))
    error('selector_loss: M is a number of ports and must be an integer >= 1.');
end

stages = ceil(log2(M));  % number of 1 x 2 elements that the light passes
loss = 0.5 * stages;  % 0.5 dB per stage [dB]
end
