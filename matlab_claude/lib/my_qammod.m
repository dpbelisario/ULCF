function sym = my_qammod(sym_num, M)
%MY_QAMMOD  Map symbol numbers 0 ... M-1 to the points of a QAM constellation.
%
%   sym = my_qammod(sym_num, M)
%
%   Inputs
%     sym_num  : symbol numbers, integers from 0 to M-1 (any size, usually n x 1)
%     M        : number of constellation points: 4, 16, 32 or 64
%   Outputs
%     sym      : constellation points (complex), same size as sym_num
%                The points lie on the grid of odd integers: ..., -3, -1, +1, +3, ...
%
%   Legacy: my_qammod.m (same name, same arguments).
%   Legacy called qammod (Communications Toolbox); this version returns the same points.
%   Legacy also had a star 8QAM (M = 8); it is not supported here.
%   Note: the points are NOT normalized.
%   Note: mean power of the points = 2, 10, 20, 42 for M = 4, 16, 32, 64.
%   Note: set the optical power afterwards with set_signal_power (TL_QAM does this).
%   Note: M = 4, 16, 64 are square constellations with Gray mapping.
%   Note: the upper half of the bits of sym_num selects the real part.
%   Note: the lower half of the bits of sym_num selects the imaginary part.
%   Note: Gray mapping = neighboring levels differ in only one bit.
%   Note: then the most likely symbol error causes only one bit error.
%   Note: M = 32 is the cross constellation (a 6 x 6 square without its 4 corners).
%   Note: my_qamdemod and adequalizet take the constellation from this function.

if M ~= 4 && M ~= 16 && M ~= 32 && M ~= 64
    error('my_qammod: M must be 4, 16, 32 or 64.');
end
if any(sym_num(:) < 0) || any(sym_num(:) > M-1) || any(sym_num(:) ~= round(sym_num(:)))
    error('my_qammod: sym_num must contain only integers from 0 to M-1.');
end

% Build the table of all M points: constellation(k+1) is the point of symbol number k.
if M == 32
    % A cross constellation has no short mapping rule, so the 32 points are written out.
    % The order is the one of qammod: column k+1 belongs to symbol number k.
    re = [-3 -1 -3 -1 -5 -5 -5 -5 -1 -1 -1 -1 -3 -3 -3 -3 ...
           3  1  3  1  5  5  5  5  1  1  1  1  3  3  3  3];
    im = [ 5  5 -5 -5  3  1 -3 -1  3  1 -3 -1  3  1 -3 -1 ...
           5  5 -5 -5  3  1 -3 -1  3  1 -3 -1  3  1 -3 -1];
    constellation = re + 1i*im;
else
    % Square constellation: sqrt(M) levels on each axis.
    % level(g+1) is the level that belongs to a group of bits with the value g.
    if M == 4
        level = [-1 1];  % 1 bit per axis: 0, 1
    elseif M == 16
        level = [-3 -1 3 1];  % 2 bits per axis: 00, 01, 10, 11
    else
        level = [-7 -5 -1 -3 7 5 1 3];  % 3 bits per axis: 000, 001, 010, ..., 111
    end
    % Read the 16QAM levels from -3 to +3: 00, 01, 11, 10. Neighbors differ in one bit.
    L = sqrt(M);  % number of levels on each axis
    k = 0:M-1;  % all symbol numbers
    upper = floor(k / L);  % value of the upper half of the bits (0 ... L-1)
    lower = mod(k, L);  % value of the lower half of the bits (0 ... L-1)
    % the imaginary axis counts from the top: lower = 0 is the highest point
    constellation = level(upper+1) - 1i*level(lower+1);
end

% Look up every symbol number in the table (MATLAB indices start at 1, numbers at 0).
sym = reshape(constellation(sym_num + 1), size(sym_num));
end
