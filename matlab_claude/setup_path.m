%% setup_path - Put the folders of this package on the MATLAB path
% Run this script once after every start of MATLAB, before any other script:
%   1. In MATLAB, make the folder of this file (the folder "matlab") the current folder.
%   2. Type setup_path in the Command Window and press Enter.
% The script adds the folders lib, demos, main, work and tests to the search path.
% The folder results is not added: it only holds output files.
% The path is not saved: run setup_path again after a restart of MATLAB.
% Your variables stay: this script does not use clear.
% It removes only its own variables (their names start with setup_) at the end.
%
% Why the check in section 3 is needed
% This package exists two times: an English tree (en) and a Japanese tree (ja).
% Both trees hold functions with the same names, and the older code of the
% laboratory uses these names too. MATLAB takes the first file that it finds.
% Use ONE tree at a time. The script stops with an error message
% if MATLAB would take the function attenuation from another place than this tree.

%% 1. Find the folder of this file
setup_root = fileparts(mfilename('fullpath'));  % folder that contains setup_path.m
setup_lib = fullfile(setup_root, 'lib');  % library folder of this tree
if isempty(setup_root) || exist(setup_lib, 'dir') ~= 7
    error(['setup_path: the folder lib was not found next to setup_path.m. ' ...
        'Run the whole file (type setup_path); do not run a part of it.']);
end

%% 2. Add the folders of this tree to the search path
% addpath puts a folder at the TOP of the path, so the folder added last wins.
addpath(fullfile(setup_root, 'tests'));  % self-tests of the library
addpath(fullfile(setup_root, 'work'));  % your own work
addpath(fullfile(setup_root, 'main'));  % baseline simulations
addpath(fullfile(setup_root, 'demos'));  % demo scripts of the lecture pages
addpath(setup_lib);  % library functions

%% 3. Check that MATLAB takes the library of THIS tree
setup_expected = fullfile(setup_lib, 'attenuation.m');  % the file that must be used
setup_found = which('attenuation');  % the file that MATLAB would use
if ~strcmpi(setup_found, setup_expected)
    % A file in the current folder wins over the path, and so does a variable.
    fprintf('expected: %s\n', setup_expected);
    fprintf('found   : %s\n', setup_found);
    error(['setup_path: MATLAB does not take attenuation from this tree (see the two ' ...
        'lines above). Make the folder of setup_path.m the current folder (cd), ' ...
        'clear a variable named attenuation if there is one, and run setup_path again.']);
end

%% 4. Report
fprintf('MATLAB version : %s (this package needs R2020b or later)\n', version);
fprintf('Package folder : %s\n', setup_root);
fprintf('Path is set (lib, demos, main, work, tests).\n');

% Copies of attenuation.m lower on the path are not used by MATLAB.
% They are reported, because they show that a second tree is on the path too.
setup_all = which('attenuation', '-all');  % every copy that MATLAB can see
for setup_k = 1:numel(setup_all)
    if ~strcmpi(setup_all{setup_k}, setup_expected)
        fprintf('Note: a second copy of attenuation.m is lower on the path (not used):\n');
        fprintf('      %s\n', setup_all{setup_k});
        fprintf('      Restart MATLAB if you want to use only one tree.\n');
    end
end

%% 5. Draw figures with a light background
% MATLAB R2025a and later can draw figures with a dark background (dark theme).
% The scripts of this package draw black lines, which are invisible on a dark figure.
% The next line makes every new figure of this MATLAB session light.
% It is not saved: after a restart of MATLAB the setting is gone.
% Older versions have no function theme; nothing is done there.
if exist('theme', 'file') == 2
    set(groot, 'defaultFigureCreateFcn', @(fig, ~) theme(fig, 'light'));
end

clear setup_root setup_lib setup_expected setup_found setup_all setup_k
