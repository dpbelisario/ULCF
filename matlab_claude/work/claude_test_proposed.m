function claude_test_proposed()
%CLAUDE_TEST_PROPOSED  Consistency tests of the proposed-switch chain and budget.
%
%   1. K = 1 (step22 AWG, step22 parameters) reproduces step22_three_stage_one_point
%      bit for bit: same BER, same power after every block, same SNR.
%   2. The pattern does not matter for K = 1.
%   3. Budget self-checks (0.1 dB power, 0.7 dB SNR) at several points:
%      K = 12 dispersed/concentrated, A1/A2, ULCF with K = 1, oob_flag = 1 with up = 5.
%   4. oob_flag = 1 (leaks of the neighbouring groups at +-50 GHz, up = 5) gives
%      the same BER as oob_flag = 0 with up = 5 within the statistical error: the
%      simulated receiver rejects them (not an assumption).
%   Written by Claude for work2. Run after setup_path.

fprintf('=== claude_test_proposed ===\n');
% --- 1. step22 reference, run in the base workspace ---
evalin('base', 'step22_three_stage_one_point');
BER22 = evalin('base', 'BER');
sp22 = evalin('base', 'stage_power');
SNR22 = evalin('base', 'SNR_sim');
close all;
p = claude_params_proposed();
p.K = 1;  p.xt_wave_max = Inf;  p.oob_flag = 0;
r = claude_chain_proposed(p);
% block numbers: step22 [1..9] = proposed [1 2 3 4 5 6 8 9 10] (no AWG crosstalk block)
map = [1 2 3 4 5 6 8 9 10];
assert(r.BER == BER22, 'K = 1: BER differs from step22 (%.4e vs %.4e)', r.BER, BER22);
assert(max(abs(r.stage_power(map) - sp22)) < 1e-9, 'K = 1: stage powers differ from step22');
assert(abs(r.SNR_sim - SNR22) < 1e-9, 'K = 1: SNR differs from step22');
fprintf('Test 1 passed: K = 1 reproduces step22 (BER %.3e, SNR %.2f dB), bit for bit.\n', ...
    r.BER, r.SNR_sim);

% --- 2. pattern does not matter for K = 1 ---
p.pattern = 'concentrated';
r2 = claude_chain_proposed(p);
assert(r2.BER == r.BER, 'K = 1: the pattern changed the result');
fprintf('Test 2 passed: for K = 1 both traffic patterns give the same result.\n');

% --- 3. budget self-checks at several points ---
cases = {
    struct('K', 12, 'pattern', 'dispersed',    'stage3_coupler_flag', 1, 'PTx', 4,  'up', 2, 'oob_flag', 0, 'awg_type', 'auto')
    struct('K', 12, 'pattern', 'concentrated', 'stage3_coupler_flag', 1, 'PTx', 4,  'up', 2, 'oob_flag', 0, 'awg_type', 'auto')
    struct('K', 12, 'pattern', 'dispersed',    'stage3_coupler_flag', 0, 'PTx', -4, 'up', 2, 'oob_flag', 0, 'awg_type', 'auto')
    struct('K', 4,  'pattern', 'dispersed',    'stage3_coupler_flag', 1, 'PTx', 2,  'up', 2, 'oob_flag', 0, 'awg_type', 'auto')
    struct('K', 1,  'pattern', 'dispersed',    'stage3_coupler_flag', 1, 'PTx', 4,  'up', 2, 'oob_flag', 0, 'awg_type', 'ulcf')
    struct('K', 12, 'pattern', 'dispersed',    'stage3_coupler_flag', 1, 'PTx', 4,  'up', 5, 'oob_flag', 1, 'awg_type', 'auto')
    };
for c = 1:numel(cases)
    p = claude_params_proposed();
    f = fieldnames(cases{c});
    for k = 1:numel(f), p.(f{k}) = cases{c}.(f{k}); end
    r = claude_chain_proposed(p);
    b = claude_budget_proposed(p, r);
    dP = max(abs(r.stage_power - b.budget_total));
    dS = r.SNR_sim - b.SNR_budget;
    assert(dP < 0.1, 'case %d: power differs from the budget by %.3f dB', c, dP);
    assert(abs(r.ase1_sim - b.budget_ase1) < 0.1 && abs(r.ase2_sim - b.budget_ase2) < 0.1, ...
        'case %d: ASE power differs from the budget', c);
    assert(abs(r.sigpw - b.budget_sigpw) < 0.1, 'case %d: sigpw differs from the budget', c);
    assert(abs(dS) < 0.7, 'case %d: SNR differs from the budget by %.2f dB', c, dS);
    fprintf(['Test 3.%d passed: K = %2d %-12s A%d PTx = %+3.0f up = %d oob = %d awg = %s: ' ...
        'BER %.3e, SNR sim %.2f / budget %.2f dB, power diff %.3f dB\n'], c, p.K, p.pattern, ...
        p.stage3_coupler_flag + 1, p.PTx, p.up, p.oob_flag, r.awg_type, r.BER, r.SNR_sim, ...
        b.SNR_budget, dP);
end

% --- 4. out-of-band leaks are rejected by the simulated receiver ---
% near the FEC limit (BER about 1e-2), where a change of the BER can be seen
p = claude_params_proposed();
p.K = 12; p.up = 5; p.PTx = -7; p.stage3_coupler_flag = 1;
p.oob_flag = 0; r0 = claude_chain_proposed(p);
p.oob_flag = 1; r1 = claude_chain_proposed(p);
fprintf('Test 4: up = 5, K = 12, A2, PTx = %g dBm: without / with %d leaks at +-50 GHz:\n', ...
    p.PTx, r1.num_oob);
fprintf('        BER %.3e / %.3e, SNR %.2f / %.2f dB\n', r0.BER, r1.BER, r0.SNR_sim, r1.SNR_sim);
fprintf('        (different random numbers after block [8]; the difference must be within the\n');
fprintf('         statistical error, about 4 percent of the BER near 1e-2)\n');
assert(abs(r1.SNR_sim - r0.SNR_sim) < 0.2, 'the out-of-band leaks changed the SNR by %.2f dB', ...
    r1.SNR_sim - r0.SNR_sim);
assert(abs(r1.BER - r0.BER)/max(r0.BER, 1e-3) < 0.15, ...
    'the out-of-band leaks changed the BER by more than 15 percent');
% the same leaks ON the wavelength of the target (as if concentrated) must hurt
p.oob_flag = 0; p.pattern = 'concentrated'; r3 = claude_chain_proposed(p);
fprintf('        for comparison, the same number of leaks IN band (concentrated): BER %.3e, SNR %.2f dB\n', ...
    r3.BER, r3.SNR_sim);
assert(r3.SNR_sim < r0.SNR_sim - 1, 'in-band leaks should lower the SNR clearly');
fprintf('Test 4 passed: leaks on other wavelengths do not change the BER; in-band leaks do.\n');
fprintf('All claude_test_proposed tests passed.\n');
end
