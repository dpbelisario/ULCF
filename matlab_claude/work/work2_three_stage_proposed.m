%% work2_three_stage_proposed - Proposed three-stage switch: transmission simulation
% YOUR WORK, part 2 of 3. This file holds the task, not a solution.
% Below this header there is no code yet: the code is yours. Do work1 first.
%
% Goal
%   Simulate the proposed switch in the way step22_three_stage_one_point simulates
%   the conventional switch: one target signal through the whole switch, then the BER.
%   The proposed switch is the three-stage switch with a new middle stage: its
%   wavelength-routing switches use interleaved ULCF AWGs, with K small couplers
%   and K EDFAs in place of one large coupler and one EDFA.
%   Two things are different for the target signal:
%     - its path through the middle stage (losses, amplifier, AWG);
%     - the leaks in the third-stage switch: some of them are on another
%       wavelength (your result of work1), and a coherent receiver can reject them.
%   Find out how much transmitter power, or how many ports, the proposed switch
%   gains, and how much of the gain comes from each of the two differences.
%
% What is given
%   main/step22_three_stage_one_point.m    skeleton of a three-stage switch,
%                                          with power budget and SNR budget
%   main/step21_two_stage_one_point.m      middle stage with ULCF AWGs, with budgets
%   main/main_three_stage_conventional.m   search for the required transmitter power
%   lib/freqoff.m                          moves a signal to another frequency
%   lib/awg_channel.m and your work1       wavelength channel of every signal
%   docs/17_awg_wavelength_routing.html, docs/22_three_stage_conventional.html,
%   docs/23_three_stage_proposal.html      background, baseline model, open questions
%   Leave the given files as they are. Your own scripts belong in the folder "work".
%
% What to produce
%   1. One operating point of the proposed switch: BER, power after every block
%      and SNR contributions, from the simulation and from a budget of your own.
%   2. The required transmitter power for several sizes of the space switches and
%      several K, for both types of the third stage and both traffic patterns.
%   Save every result together with its parameters and its seed.
%
% Consistency conditions (your result must pass all of them)
%   - K = 1 (one input group) with the AWG of step22 gives the result of
%     step22_three_stage_one_point again.
%   - Concentrated traffic removes the crosstalk advantage of the proposed switch.
%   - The simulated SNR agrees with your hand budget, and so does the power after
%     every block (step21 and step22 show how, and which difference they accept).
%
% Questions to think about
%   - Which blocks of step22 stay, which change, and which are new?
%   - What does the receiver of this simulation do with a leak on another
%     wavelength? Is the leak rejected because you assume it, or because your
%     simulation shows it?
%   - Is the simulated band Fs = up*baudrate wide enough for a signal on another
%     wavelength channel? With the oversampling rate up = 2 and 32 GBd the band is
%     from -32 to +32 GHz. Read the notes in lib/freqoff.m before you choose up.
%   - The ULCF AWG adds crosstalk of its own (step21, block [7]). Keep it apart
%     from the leaks of the third-stage switch. Which of the two limits the switch?
%   - What is left of the advantage when the traffic is concentrated?
%   - step21 and step22 use different parameters (symbol rate, modulation format,
%     noise figure, AWG, fiber). Which values do you use, and why? (See work3.)
%   - Close to the FEC limit one run with one seed does not decide. What do you do?

clear; close all; rng(1);

% ---- your code starts here ----
