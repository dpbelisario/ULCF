%% work3_comparison - Three switches compared on one common parameter set
% YOUR WORK, part 3 of 3. This file holds the task, not a solution.
% Below this header there is no code yet: the code is yours. Do work1 and work2 first.
%
% Goal
%   Compare three switches in a fair way:
%     (1) two-stage ULCF switch             main_two_stage_ULCF
%     (2) conventional three-stage switch   main_three_stage_conventional
%     (3) proposed three-stage switch       your work2
%   Compare the port count, the throughput and the number of hardware elements.
%   The two given scripts use the parameters of two different earlier studies
%   (compare section 1 of step21 with section 1 of step22). A fair comparison needs
%   ONE common parameter set for all three switches. You choose it and give reasons.
%   The figures and tables of this task are the main results of your paper.
%
% What is given
%   main/main_two_stage_ULCF.m             port count versus power of switch (1)
%   main/main_three_stage_conventional.m   port count versus power of switch (2)
%   your work1 and work2                   switch (3)
%   ref_data/jlt2025_three_stage_ref.csv   switch (2) in JLT 2025, Table V: required
%                                          power and 1 x 2 selectors per port
%   docs/21_two_stage_ulcf_switch.html, docs/22_three_stage_conventional.html,
%   docs/23_three_stage_proposal.html      the three switches and their elements
%   Leave the given files as they are. Your own scripts belong in the folder "work".
%
% What to produce
%   1. The common parameter set as a table, with the reason for every value.
%   2. Port count versus transmitter power of the three switches in one figure.
%      Proposed switch: several K, both types of the third stage, both traffic patterns.
%   3. Throughput of the three switches (port count times bit rate of one port).
%   4. Number of hardware elements per port of the three switches: selectors,
%      couplers, EDFAs, AWGs and 1 x 2 splitters.
%   5. Your conclusion in five to ten sentences: when is the proposed switch the
%      best choice, what does it cost, and when is its advantage gone?
%
% Consistency conditions (your result must pass all of them)
%   - All curves of one figure use the same common parameter set.
%   - The proposed switch with K = 1 and the AWG of step22 gives the curve of the
%     conventional three-stage switch again.
%   - Concentrated traffic removes the crosstalk advantage of the proposed switch.
%   - Every point of a curve comes from a chain that agrees with a hand budget,
%     and it can be repeated (its parameters and its seed are saved).
%   - Your number of selectors per port of switch (2) agrees with the file
%     ref_data/jlt2025_three_stage_ref.csv.
%
% Questions to think about
%   - Which parameters must be common, and which belong to one switch only?
%   - The proposed switch can use its advantage for more ports, for less
%     transmitter power, for a higher bit rate or for a simpler third stage
%     (couplers in place of selectors). Which comparison shows this best?
%   - The proposed switch needs more EDFAs. How do you weigh EDFAs against selectors?
%   - Which traffic pattern is your main result? How do you show the other one?
%   - How large is the random error of a required power? Is a difference of
%     0.5 dB between two switches a real difference?

clear; close all; rng(1);

% ---- your code starts here ----
