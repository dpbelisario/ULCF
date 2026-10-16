%% work1_wavelength_rule - Proposed switch: which wavelength does a connection use?
% YOUR WORK, part 1 of 3. This file holds the task, not a solution.
% Below this header there is no code yet: the code is yours.
% Think on paper first and show your plan to your supervisor. Then write the code.
%
% Goal
%   Conventional three-stage switch: the output port of the AWG fixes the wavelength.
%   All signals that meet in one third-stage switch then have the same wavelength,
%   and every leak inside that switch disturbs the target signal.
%   Proposed switch: the middle stage uses interleaved ULCF AWGs with K input ports.
%   The first-stage switches are divided into K input groups, one group for each
%   input port of the AWG. The wavelength of a connection now depends on the input
%   group of its first-stage switch too.
%   Find the wavelength of every connection. Then count the leaks in a third-stage
%   switch that have the wavelength of the target signal.
%   This task needs whole numbers only: no waveform, no noise, no BER.
%
% What is given
%   docs/17_awg_wavelength_routing.html    AWG with several input ports, ULCF AWG
%   docs/22_three_stage_conventional.html  wiring and wavelengths, conventional switch
%   docs/23_three_stage_proposal.html      idea of the proposed switch, open questions
%   lib/awg_channel.m                      wavelength channel between one input port
%                                          and one output port of an AWG
%   main/step21_two_stage_one_point.m      ULCF AWG with K couplers and K EDFAs
%   main/step22_three_stage_one_point.m    conventional three-stage switch
%   Design rule of the proposal: all wavelength-routing switches of the middle
%   stage use the same input groups. A first-stage switch is connected to the same
%   AWG input port in every one of them.
%
% What to produce
%   1. The wavelength rule: the wavelength channel of a connection from first-stage
%      switch i to third-stage switch j. Your division into input groups is a part
%      of the rule. Show the rule for a small example that you can check by hand.
%   2. Two traffic patterns, "dispersed" and "concentrated". A pattern tells where
%      the signals that pass one third-stage switch come from: roughly, from many
%      input groups or from one input group. Make both definitions exact.
%   3. For both patterns: the number of leaks on the wavelength of the target
%      signal in one third-stage switch, for several K and M (a table or a figure).
%
% Consistency conditions (your result must pass all of them)
%   - K = 1 gives the conventional switch again (see step22, block [7]).
%   - The wavelength of a connection does not depend on the wavelength-routing
%     switch that carries it. A rearrangement then never changes the wavelength
%     of a transmitter.
%   - Concentrated traffic removes the crosstalk advantage of the proposed switch.
%   - An aggregation coupler never carries two signals of the same wavelength.
%
% Questions to think about
%   - Which of these change the wavelength of a connection: its first-stage switch,
%     its wavelength-routing switch, its third-stage switch?
%   - How do you divide the first-stage switches into K groups? Does it matter?
%   - Which traffic is likely in a data center? Which pattern is the worst case?
%   - How far from the target signal, in channels, is a leak on another wavelength?
%   - Does the new rule change the leaks inside the FIRST-stage switch?
%   - The signals at one receiver can now have different wavelengths. What must
%     the receiver do when a new connection is set up?

clear; close all; rng(1);

% ---- your code starts here ----
