%% run_all_tests - Run every self-test of the library
% How to run: run setup_path once, then type run_all_tests.
% The three test scripts run one after another. Each one prints "... all passed".
% If a check fails, MATLAB stops at this check and prints the reason.
% If the line "All tests passed." appears at the end, the library works on this PC.
%
% Run this script on the first day, and again after every change in the folder lib.
%
% This script keeps no variables of its own:
% every test script starts with "clear", which would delete them.

if exist('attenuation', 'file') ~= 2
    error('run_all_tests: the library is not on the MATLAB path. Run setup_path first.');
end

test_lib_power_loss
test_lib_filters_qam
test_lib_edfa

fprintf('All tests passed.\n');
