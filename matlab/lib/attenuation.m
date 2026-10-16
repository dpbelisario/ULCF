function [y, att] = attenuation(x, loss)
%ATTENUATION  Apply a power loss given in dB to an optical field.
%
%   [y, att] = attenuation(x, loss)
%
%   Inputs
%     x     : optical field, one signal per column [sqrt(W)]
%     loss  : power loss [dB] (a negative value is a gain)
%             scalar, or a 1 x M row vector with one loss per column of x
%   Outputs
%     y     : attenuated field [sqrt(W)]
%     att   : amplitude factor that was applied (= 10^(-loss/20))
%
%   Legacy: attenuation.m (same name, same arguments).
%   Note: a POWER loss of L dB multiplies the FIELD by 10^(-L/20).
%   Example: a loss of 3 dB halves the power; the field is divided by sqrt(2).

att = 10.^(-loss/20);  % dB (power) -> amplitude factor
y = x .* att;
end
