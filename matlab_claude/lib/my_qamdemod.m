function sym_num = my_qamdemod(sym, M)
%MY_QAMDEMOD  Decide which QAM constellation point is closest to each received sample.
%
%   sym_num = my_qamdemod(sym, M)
%
%   Inputs
%     sym      : received samples (complex), one sample per symbol (any size)
%                They must have the scale of my_qammod (points on the odd integers).
%     M        : number of constellation points: 4, 16, 32 or 64
%   Outputs
%     sym_num  : decided symbol numbers, integers from 0 to M-1, same size as sym
%
%   Legacy: my_qamdemod.m (same name, same arguments).
%   Legacy called qamdemod (Communications Toolbox); this version makes the same
%   decisions, except for a sample exactly on a decision boundary (the same distance
%   to two points): there this version takes the point with the smaller symbol number.
%   Legacy symbol_decision.m (the decision inside the legacy equalizer) is dropped;
%   my_qammod(my_qamdemod(y, M), M) gives the decided constellation point.
%   Note: hard decision = choose the constellation point with the smallest distance.
%   Note: the scale of sym matters. A signal with another scale gives wrong decisions.
%   Note: adequalizet returns its output on this scale. With noise its output is a
%         little smaller (factor SNR/(SNR + 1)); see the notes in adequalizet.
%   Note: the constellation comes from my_qammod, so mapper and demapper always agree.
%   Note: my_qamdemod(my_qammod(k, M), M) returns k.
%   Note: the loop runs over the M points, not over the samples, so it is fast.

if any(isnan(sym(:)))
    error('my_qamdemod: sym contains NaN (not a number).');
end

constellation = my_qammod((0:M-1).', M);  % all M points, M x 1 (this also checks M)

sym_num = zeros(size(sym));  % decision so far (start: symbol number 0)
best_dist = inf(size(sym));  % distance to the closest point found so far
for k = 1:M
    dist = abs(sym - constellation(k));  % distance of every sample to point k
    closer = dist < best_dist;  % samples for which point k is the closest so far
    sym_num(closer) = k - 1;  % symbol numbers start at 0, indices at 1
    best_dist(closer) = dist(closer);
end
end
