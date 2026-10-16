# Plan: solve the Clos-ULCF research problem (Claude, 2026-10-16)

## Context
The package asks for a three-stage optical circuit switch whose middle stage uses
interleaved ULCF AWGs with K input ports (K small couplers + K EDFAs per WR switch)
instead of one 96x1 coupler and one EDFA. Three work tasks are open:
work1 (wavelength rule + leak count), work2 (transmission simulation of the proposed
switch), work3 (fair comparison of the three switches). Everything runs in the clone
`matlab_claude/`; the original `matlab/` is untouched. All new files carry the prefix
`claude_` and live in `matlab_claude/work/` or `matlab_claude/claude_runs/`.

## Baseline (done)
- All 6 demos pass their self-checks (`claude_runs/demos_out/`).
- `run_all_tests` passes; step21 BER 7.630e-03, step22 BER 8.700e-03 (= docs).
- Both main sweeps reproduce the docs tables exactly (`results/`).

## Phase A: work1, wavelength rule (integers only)
File: `work/claude_work1_wavelength_rule.m` + helper `work/claude_group_of.m`,
`work/claude_wavelength_of.m`, `work/claude_inband_leaks.m`.
- Rule: group g(i) = ceil(i / (N/K)) (consecutive blocks); channel of a connection
  first-stage i -> third-stage j is `awg_channel(g(i), j, N)`; independent of WR switch k.
- Verify by brute force over all (i, j, k): wavelength never depends on k; K = 1 gives
  channel j; no coupler carries two equal channels under any legal traffic.
- Traffic patterns, exact: dispersed = the M sources of one third-stage switch are
  spread as evenly as possible over the K groups, target in a largest group
  -> in-band leaks = ceil(M/K) - 1 (worst case) and (M-1)/K on average for random
  sources; concentrated = all M sources in the target's group -> M - 1 leaks.
- Output: table of in-band leaks for K in {1 2 4 6 8 12 16}, M in {16 32 64 128},
  both patterns, plus SXR_3 and a small hand-checkable example (N = 8, K = 4, M = 3).
  Save CSV + MAT + PNG to `results/claude_work1_*`.

## Phase B: work2, proposed switch simulation
File: `work/claude_step23_proposed_one_point.m` (chain copied from step22, blocks changed):
- [4] coupler_loss(N/K); [5] EDFA shares power over N/K channels;
- [6] AWG: K = 1 -> AWG of step22 (6 dB, 50 GHz, shift 0); K > 1 -> ULCF pair +
  splitter (9 + 3.5 dB, 66.6 GHz, shift = ULCF_dev_freq(K));
- [7] new: K-1 AWG crosstalk leaks at AWG_XT (from step21 block [7]);
- [8] stage-3 switch: num_xt3 in-band leaks from the traffic pattern (work1);
  out-of-band leaks optionally added with freqoff at +-50 GHz (needs up >= 5).
- Budget and SNR budget extended with the same terms; self-checks as step22.
- Consistency: K = 1, dispersed/concentrated, xt_wave_max = Inf must reproduce step22
  bit for bit (same random draw order).
Sweep: `work/claude_main_three_stage_proposed.m` (search loop of main_three_stage_conventional)
over K in {1 2 4 8 12}, stage3 in {A1 A2}, pattern in {dispersed concentrated},
M in {16 32 64 128}; quick grid first (-10:1:10 dBm, 3e4 symbols, xt_wave_max = 16),
then a second seed for the main cases. Save MAT/CSV/PNG per run.

## Phase C: work3, common parameter set and comparison
- Common set = step22 values (16QAM, 32 GBd, 50-GHz grid, NF 6, ER 35, single-core fiber,
  N 96, 20/10 dBm EDFAs, seed 1, 3e4 symbols). Architecture-only rows stay separate.
- `work/claude_main_two_stage_common.m`: main_two_stage_ULCF re-run with the common set,
  M in {2 4 8 16 32 64 128}, K = 1 uses the step22 AWG.
- `work/claude_work3_comparison.m`: loads the latest result files, draws port count vs PTx
  (three switches, several K, both stage-3 types, both patterns), computes throughput and
  elements per port (selectors, couplers, EDFAs, AWGs, splitters), checks selectors/port
  against `ref_data/jlt2025_three_stage_ref.csv`, writes tables.

## Phase D: explainer
`claude_runs/REPORT.md`: the answers to the eight open questions of page 23, the tables and
figures, and the 5-10 sentence conclusion. Also lists every file produced.

## Verification
- `run_all_tests` still passes in the clone.
- K = 1 proposed == step22 at the default point (BER 8.700e-03) and == conventional curve.
- Every step script's self-checks (power 0.1 dB, SNR 0.7 dB) pass for the proposed chain.
- Concentrated-traffic curves coincide with conventional ones up to the middle-stage gain.
