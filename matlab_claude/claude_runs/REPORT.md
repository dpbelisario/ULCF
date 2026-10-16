# Clos-ULCF research: results and preliminary explainer

Written by Claude on 2026-10-16. Everything here was produced by MATLAB R2026a from the
clone `matlab_claude/` (the original `matlab/` is untouched). All new scripts carry the
prefix `claude_` and live in `matlab_claude/work/`; all result files carry the prefix
`claude_` and live in `matlab_claude/results/`. Console logs are in `matlab_claude/claude_runs/`.

## 0. The question in one paragraph

A three-stage Clos optical circuit switch (JLT 2025, "Scheme A") has N = 96 first-stage
space switches of size M x M, M wavelength-routing (WR) switches of size 96 x 96, and 96
third-stage space switches. Its port count is 96 M. Each WR switch merges 96 signals in
one 96 x 1 coupler (24.5 dB loss) in front of one EDFA. The proposal replaces that middle
stage by K small couplers and K EDFAs feeding a pair of ULCF AWGs with K input ports
(JOCN 2018). Two things change for a connection: it loses 14 dB less before its EDFA
(K = 12), and its wavelength now depends on which of the K input groups its first-stage
switch belongs to. The research asks: what is the wavelength rule, how many leaks in a
third-stage switch still share the target's wavelength, how much transmitter power or how
many ports does the proposal gain, what does it cost, and when does the gain disappear.

## 1. Baseline reproduced

| Script | Result | Matches docs |
|---|---|---|
| all 6 demos | every self-check passed | yes |
| `run_all_tests` | 28 checks passed (3.5 s) | yes |
| `step21_two_stage_one_point` | BER 7.630e-03, SNR 17.40 dB | yes |
| `step22_three_stage_one_point` | BER 8.700e-03, SNR 14.19 dB | yes |
| `main_two_stage_ULCF` (quick) | required PTx table | identical to page 21 |
| `main_three_stage_conventional` (quick) | A1: -5 -4 -3 -2; A2: -4 -2 4 NaN dBm | identical to page 22 |

## 2. work1: the wavelength rule (integers only)

Script: `work/claude_work1_wavelength_rule.m`, helpers `claude_group_of`, `claude_wavelength_of`,
`claude_inband_leaks`. Log: `claude_runs/work1_console.txt`.

**Rule.** First-stage switch i belongs to input group g(i) = floor((i-1) K / N) + 1
(K consecutive blocks of N/K switches). It enters AWG input port g(i) in every WR switch.
Output j of every WR switch goes to third-stage switch j. So a connection from first-stage
switch i to third-stage switch j uses the channel

    ch(i, j) = awg_channel(g(i), j, N) = mod(j + g(i) - 2, N) + 1

and the WR switch does not appear. Verified by brute force on the small example N = 8,
K = 4, M = 3 (table in the log, two cells checked by hand) and for N = 96. A counter-example
in the log shows that if the groups were rotated from WR switch to WR switch, every
connection would need a different wavelength on a different WR switch, so a rearrangement
would need a laser retune (> 100 us). K = 1 gives ch = j, the conventional rule.

**Coupler condition.** In one WR switch each first-stage switch sends at most one signal and
each third-stage switch receives at most one. Signals of one group have different
destinations j and therefore different channels. Checked on 20 random full-load traffic
matrices for every K and M: no aggregation coupler ever carries two equal channels. Equal
channels can only meet at different AWG input ports: that is the ULCF AWG crosstalk, K - 1
leaks at 32 dB, which is kept as a separate term.

**Traffic patterns, exact.** A third-stage switch has M inputs, one per WR switch. A leak is
in band exactly when its source first-stage switch is in the target's group.

- Dispersed: the M sources are spread as evenly as possible over the K groups and the
  target sits in a largest group. In-band leaks = ceil(M/K) - 1.
- Concentrated: all M sources are in the target's group. In-band leaks = M - 1, the
  conventional count, for every K.
- Random uniform traffic (for reference): mean (M - 1)/K, confirmed by 400 random
  full-load matrices per (K, M).

In-band leaks, dispersed (rows K, columns M = 16, 32, 64, 128):

| K | 16 | 32 | 64 | 128 |
|---|---|---|---|---|
| 1 | 15 | 31 | 63 | 127 |
| 2 | 7 | 15 | 31 | 63 |
| 4 | 3 | 7 | 15 | 31 |
| 8 | 1 | 3 | 7 | 15 |
| 12 | 1 | 2 | 5 | 10 |
| 16 | 0 | 1 | 3 | 7 |

Third-stage SXR for Scheme A2 (one selector, ER 35 dB), dispersed: K = 1 gives 23.2 / 20.1 /
17.0 / 14.0 dB; K = 12 gives 35.0 / 32.0 / 28.0 / 25.0 dB. At M = 128 the conventional A2
switch is infeasible because 14.0 dB is already the whole SNR a 16QAM signal needs; with
K = 12 that term is 25 dB. For Scheme A1 (two selectors, 70 dB) the term is above 49 dB in
every case and never matters.

**Answers to the questions of the task.** The wavelength depends on the first-stage switch
(through its group) and on the third-stage switch, not on the WR switch. Any division into K
equal groups gives the same counts. Dispersed traffic is the likely datacenter case; concentrated
is the worst case and equals the conventional switch. A leak on another wavelength is at least
one channel (50 GHz) away, i.e. 34 GHz outside the 32-GBd receive band. The new rule does not
change the first-stage leaks (the worst case of step22 is kept). A receiver output can see K
different wavelengths; a new connection from another group needs the local oscillator retuned,
a rearrangement never does.

## 3. work2: transmission simulation of the proposed switch

Files: `work/claude_chain_proposed.m` (the chain), `claude_budget_proposed.m` (closed form),
`claude_params_proposed.m` (common parameter set), `claude_test_proposed.m` (tests),
`claude_step23_proposed_one_point.m` (one point), `claude_main_three_stage_proposed.m` (sweep).

**What changed against step22.** Block [4] coupler of N/K channels; [5] EDFA shared by N/K
channels; [6] for K > 1 the 1 x 2 splitter and ULCF AWG pair (9 + 3.5 dB, 66.6 GHz passband,
centre off by the deviation of the worst input port, 16 GHz at K = 12); [7] new: K - 1 ULCF
AWG leaks at 32 dB; [8] third-stage switch with only the in-band leaks of the traffic pattern.
With K = 1 the chain uses the step22 AWG and draws its random numbers in exactly the order of
step22.

**Tests (`claude_test_proposed`, all passed).**
1. K = 1 reproduces step22 bit for bit: BER 8.700e-03, same power after every block, same SNR.
2. For K = 1 the traffic pattern does not matter.
3. At six operating points (K = 12 dispersed/concentrated, A1/A2, ULCF with K = 1, out-of-band
   leaks with up = 5) the power after every block agrees with the budget within 0.011 dB and
   the SNR within 0.07 dB (limits 0.1 and 0.7 dB, as in step22).
4. Leaks on other wavelengths are rejected by the simulation, not by assumption: at K = 12,
   A2, PTx = -7 dBm with up = 5, adding the 12 leaks of the two neighbouring groups at
   +-50 GHz with `freqoff` changes the SNR from 17.62 to 17.64 dB (BER 2.50e-4 vs 2.63e-4,
   within the statistical error). The same 12 leaks in band (concentrated) give 14.50 dB and
   BER 6.76e-3. The sweeps therefore leave the out-of-band leaks out (`oob_flag = 0`) and use
   up = 2.

**One operating point** (`claude_step23_proposed_one_point`, PTx 4 dBm, M = 64, A2, K = 12,
dispersed; the default point of step22):

| term | conventional (step22) | proposed K = 12 |
|---|---|---|
| power at EDFA input | -29.5 dBm | -15.5 dBm |
| ASE of the EDFA | 21.38 dB | 35.39 dB |
| stage-1 crosstalk | 52.01 dB | 52.01 dB |
| ULCF AWG crosstalk | - | 21.43 dB |
| stage-3 crosstalk | 16.94 dB | 27.82 dB |
| pre-amp ASE | 19.58 dB | 23.34 dB |
| SNR (budget / simulation) | 14.15 / 14.19 dB | 18.61 / 18.54 dB |
| BER | 8.70e-3 | 5.0e-5 |

The limiting term moves from the third-stage crosstalk and the EDFA noise to the ULCF AWG
crosstalk (21.4 dB), exactly as page 21 hints for the two-stage switch.

## 4. work3: the comparison

See section 5 below for the sweep results and the figure (filled in after the sweep).

Common parameter set (reasons in `results/claude_work3_*_common_parameters.csv`): the step22
values, because the port-count reference of the JLT paper uses them: 16QAM, 32 GBd, 50-GHz
grid, N = 96, polarization multiplexing, single-core fiber, NF 6 dB, 20/10 dBm EDFAs,
extinction ratio 35 dB for every selector and the DC switch, carrier on the passband centre.
The AWG of step22 (6 dB, 50 GHz) for every switch with K = 1 and the ULCF pair + splitter
of step21 (12.5 dB, 66.6 GHz, deviation, XT 32 dB) for every switch with K > 1. Rows that
cannot be made equal are the architectures themselves.

**Two-stage switch on the common set** (`claude_main_two_stage_common`, required PTx in dBm,
M of the DC switch = 2, 4, 8, 16, 32, 64, 128):

| K | 2 | 4 | 8 | 16 | 32 | 64 | 128 |
|---|---|---|---|---|---|---|---|
| 1 | -5 | -1 | 3 | 8 | 12 | NaN | NaN |
| 2 | -8 | -4 | 0 | 4 | 9 | 15 | NaN |
| 4 | -12 | -8 | -3 | 1 | 6 | 12 | NaN |
| 8 | -15 | -11 | -6 | -2 | 3 | 9 | NaN |
| 12 | -18 | -14 | -10 | -5 | 0 | 6 | NaN |

With 16QAM (14 dB needed instead of 17 dB for 32QAM) the two-stage switch reaches 384 ports
at -1 dBm with K = 1, as the JLT paper states (384 ports at 0 dBm), and 3072 ports at 0 dBm
with K = 12. 6144 ports need 6 dBm, above the 5-dBm limit of the paper.

## 5. Sweep results

`claude_main_three_stage_proposed`: 487 operating points per seed, 134 s, grid -25 to 10 dBm in
1-dB steps, 3e4 symbols, every leak its own waveform (so K = 1 equals the baseline bit for bit).
Required transmitter power in dBm, seed 1 (columns M = 16, 32, 64, 128 = 1536 to 12288 ports):

Scheme A1 (selectors in the third stage), dispersed = concentrated:

| K | 16 | 32 | 64 | 128 |
|---|---|---|---|---|
| 1 (conventional) | -5 | -4 | -3 | -2 |
| 2 | -8 | -7 | -6 | -5 |
| 4 | -12 | -11 | -10 | -9 |
| 8 | -15 | -14 | -13 | -12 |
| 12 | -18 | -17 | -16 | -15 |

Scheme A2 (couplers in the third stage), dispersed:

| K | 16 | 32 | 64 | 128 |
|---|---|---|---|---|
| 1 (conventional) | -4 | -2 | 4 | NaN |
| 2 | -7 | -5 | 2 | NaN |
| 4 | -11 | -10 | -7 | NaN |
| 8 | -15 | -13 | -12 | -8 |
| 12 | -18 | -17 | -15 | -12 |

Scheme A2, concentrated:

| K | 16 | 32 | 64 | 128 |
|---|---|---|---|---|
| 1 (conventional) | -4 | -2 | 4 | NaN |
| 2 | -7 | -4 | NaN | NaN |
| 4 | -11 | -8 | -1 | NaN |
| 8 | -14 | -12 | -7 | NaN |
| 12 | -17 | -15 | -9 | NaN |

NaN = not reached up to 10 dBm. Seed 2 against seed 1: 63 of 71 entries identical, the other 8
differ by exactly 1 dB (points sitting on the FEC limit). The comparison uses the worse seed.

**Figure.** `results/claude_work3_*_portcount.png`: port count versus PTx, left panel dispersed,
right panel concentrated. Grey dotted: two-stage K = 1 and 12. Black: conventional A1 (solid)
and A2 (dashed). Orange and blue: proposed K = 4 and K = 12. Red dotted line: the 5-dBm limit.

**Where the gain comes from** (`results/claude_work3_*_gain_split.csv`; SNR budget at the
required power of the conventional switch, K = 12; (a) conventional, (b) proposed middle stage
with all leaks in band, (c) proposed with dispersed traffic):

| scheme | M | PTx | SNR (a) | SNR (b) | SNR (c) | middle stage | other wavelengths | limiting term of (c) |
|---|---|---|---|---|---|---|---|---|
| A1 | 16 | -5 | 14.37 | 20.60 | 20.60 | +6.23 | 0.00 | ULCF AWG XT 21.4 dB |
| A1 | 128 | -2 | 14.35 | 20.57 | 20.57 | +6.21 | +0.01 | ULCF AWG XT 21.4 dB |
| A2 | 16 | -4 | 14.48 | 18.52 | 20.26 | +4.05 | +1.73 | ULCF AWG XT 21.4 dB |
| A2 | 32 | -2 | 14.25 | 16.94 | 19.73 | +2.69 | +2.79 | ULCF AWG XT 21.4 dB |
| A2 | 64 | 4 | 14.15 | 14.82 | 18.61 | +0.68 | +3.78 | ULCF AWG XT 21.4 dB |
| A2 | 128 | 5 | 11.21 | 12.14 | 16.49 | +0.93 | +4.35 | pre-amp ASE 19.3 dB |

For A1 the whole gain is the middle stage (the SNR gain of 6.2 dB is capped by the ULCF AWG
crosstalk; in required power it is 13 dB because the EDFA noise term alone moves by 14 dB).
For A2 the middle-stage share shrinks with M, because the EDFA output per channel is fixed and
the ULCF pair adds 6.5 dB of loss in front of the third-stage coupler and the pre-amplifier,
while the out-of-band share grows with M.

**Largest switch below the 5-dBm limit of the paper** (200 Gbit/s per port):

| switch | ports | throughput | required PTx |
|---|---|---|---|
| two-stage, K = 1 | 768 | 153.6 Tbit/s | 3 dBm |
| two-stage, K = 12 | 3072 | 614.4 Tbit/s | 0 dBm |
| conventional A1 | 12288 | 2457.6 Tbit/s | -2 dBm |
| conventional A2 | 6144 | 1228.8 Tbit/s | 4 dBm |
| proposed K = 12, A1, any traffic | 12288 | 2457.6 Tbit/s | -15 dBm |
| proposed K = 12, A2, dispersed | 12288 | 2457.6 Tbit/s | -12 dBm |
| proposed K = 12, A2, concentrated | 6144 | 1228.8 Tbit/s | -9 dBm |
| proposed K = 2, A2, concentrated | 3072 | 614.4 Tbit/s | -4 dBm |

**Hardware per port** (selectors in 1 x 2 elements, couplers in 2 x 1 elements, M = 64):

| switch | selectors | couplers | EDFAs | AWGs | splitters |
|---|---|---|---|---|---|
| two-stage K = 1 | 63 | 63.99 | 0.0104 | 0.0104 | 0 |
| two-stage K = 12 | 63 | 63.88 | 0.125 | 0.0208 | 0.125 |
| conventional A1 | 252 | 0.99 | 0.0104 | 0.0104 | 0 |
| conventional A2 | 189 | 63.99 | 0.0104 | 0.0104 | 0 |
| proposed K = 12, A1 | 252 | 0.88 | 0.125 | 0.0208 | 0.125 |
| proposed K = 12, A2 | 189 | 63.88 | 0.125 | 0.0208 | 0.125 |

Selectors per port of the conventional switch equal `ref_data/jlt2025_three_stage_ref.csv`
(4(M-1) for A1, 3(M-1) for A2). The full table for M = 16 to 128 is in
`results/claude_work3_*_hardware_per_port.csv`.

## 6. Answers to the eight open questions of page 23

1. **Which wavelength does a connection use?** ch = awg_channel(g(i), j, N), g(i) the input group
   of its first-stage switch, j its third-stage switch (section 2).
2. **Does it depend on the middle-stage module?** No, shown by the rule and by brute force; it would
   if the groups were not identical in every module (counter-example in the work1 log).
3. **Which leaks at a third-stage switch are in band?** Those whose source is in the target's group:
   ceil(M/K) - 1 for dispersed, M - 1 for concentrated traffic, (M - 1)/K on average for random
   traffic.
4. **How does this depend on the traffic?** Fully: concentrated traffic gives the conventional count.
   But it only matters for Scheme A2; for A1 the third-stage leaks are negligible either way.
5. **How much is gained, and from which source?** A1: 3 / 7 / 10 / 13 dB of transmitter power for
   K = 2 / 4 / 8 / 12, all from the middle stage. A2 dispersed: 3 to 14 dB, split between the
   middle stage (dominant at small M) and the out-of-band leaks (dominant at large M). The
   ULCF AWG crosstalk is kept as its own term and is the new limit (SXR 21.4 dB at K = 12).
6. **Can it buy a simpler third stage?** Yes: A2 at 12288 ports needs -8 dBm (K = 8) or -12 dBm
   (K = 12) with dispersed traffic, against infeasible for the conventional A2 switch. Not with
   concentrated traffic.
7. **What does it cost?** 0.125 EDFAs per port instead of 0.0104 (K = 12), two AWGs and twelve
   1 x 2 splitters per WR switch; no change in selectors. With A2 it saves 63 to 127 selector
   elements per port against A1.
8. **When does the benefit disappear?** Concentrated traffic with Scheme A2 (gain shrinks with M,
   becomes a loss at K = 2 and M = 64, and 12288 ports stay infeasible); a wiring in which the
   groups differ between WR switches (rearrangement would retune lasers); and, for any K, the
   AWG crosstalk floor of 32 dB.

## 7. Conclusion (5 to 10 sentences, also in `results/claude_work3_*_conclusion.txt`)

With selectors in the third stage (Scheme A1) the proposed switch lowers the required transmitter
power by 3, 7, 10 and 13 dB for K = 2, 4, 8 and 12 at every size, for dispersed and concentrated
traffic alike, because the third-stage leaks pass two selectors and never matter; this whole gain
is the middle stage. With couplers in the third stage (Scheme A2) and dispersed traffic the gain
splits between the middle stage (dominant at small M) and the leaks that are no longer on the
target's wavelength (dominant at large M), and Scheme A2 becomes feasible at 12288 ports at
-8 dBm (K = 8) or -12 dBm (K = 12), where the conventional A2 switch is infeasible: the proposal
can buy the simpler third stage instead of more power. With concentrated traffic the A2 gain
shrinks with M and turns into a loss, because the EDFA output per channel is fixed by its
saturation power and the extra 6.5 dB of the ULCF pair then sits in front of the 24 to 28 dB
third-stage coupler and the pre-amplifier; 12288 ports stay infeasible for every K. The ULCF AWG
crosstalk (21.4 dB at K = 12) is the new limiting term in nearly every case, so a better AWG
crosstalk, not more input ports, is the next lever, and K = 8 already gives most of the gain. The
price is 12 EDFAs, 2 AWGs and 12 splitters per WR switch instead of 1 EDFA and 1 AWG, a small
addition against 252 to 508 selector elements per port. The two-stage switch on the same
parameter set reaches 3072 ports at 0 dBm with K = 12 but needs 6 dBm for 6144, so it does not
compete above about 3000 ports. Required powers have 1-dB resolution and a one-step random
error at the FEC limit; differences of 3 dB and more between curves are real.

## 8. Files produced

Scripts (`matlab_claude/work/`): `claude_group_of.m`, `claude_wavelength_of.m`,
`claude_inband_leaks.m`, `claude_work1_wavelength_rule.m`, `claude_params_proposed.m`,
`claude_chain_proposed.m`, `claude_budget_proposed.m`, `claude_test_proposed.m`,
`claude_step23_proposed_one_point.m`, `claude_main_three_stage_proposed.m`,
`claude_main_two_stage_common.m`, `claude_work3_comparison.m`.
Drivers (`matlab_claude/claude_runs/`): `claude_run_demos.m`, `claude_run_baseline.m`; logs
`*_console.txt`; demo and baseline figures in `demos_out/` and `baseline_out/`.
Results (`matlab_claude/results/`): `claude_work1_*`, `claude_step23_*`,
`claude_three_stage_proposed_seed1_*`, `claude_three_stage_proposed_seed2_*`,
`claude_two_stage_common_*`, `claude_work3_*`, plus the baseline `two_stage_ULCF_*` and
`three_stage_conventional_*`. Every `.mat` holds all parameters and the seed.

To repeat everything: in MATLAB, `cd matlab_claude; setup_path;` then
`claude_work1_wavelength_rule`, `claude_test_proposed`, `claude_step23_proposed_one_point`,
`claude_main_three_stage_proposed` (set `CLAUDE_SEED` to 1 and 2), `claude_main_two_stage_common`,
`claude_work3_comparison`.

## 9. Caveats for the supervisor

- The AWG routing shift (+1 channel per input port, Eq. (4) of page 17) is a convention; the JOCN
  device shifts by -1 or -2. The leak counts do not depend on it, the channel numbers do.
- Dispersed traffic is defined as the worst case of an even spread (ceil(M/K) - 1 in-band
  leaks). Random traffic has a tail (up to 24 same-group signals seen at M = 128, K = 12 in 400
  trials) that lies between the two patterns.
- The out-of-band leaks were simulated only at +-50 GHz (the nearest groups) with up = 5 at one
  point; farther leaks are rejected at least as well. The sweeps leave them out.
- Quick settings: 3e4 symbols, 1-dB grid, seeds 1 and 2. A full run (1.5e5 symbols, 0.5 dB)
  would take about 25 minutes per seed with the same scripts (`quick_flag = 0`).
- The 32-dB AWG crosstalk value comes from the laboratory code, not from the JOCN paper.
