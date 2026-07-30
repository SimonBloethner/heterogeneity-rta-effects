# SYNC-6 Recomputation Table (D5)

Generated: 2026-07-26

## R1: E[sigma^2] Derivation

| Item | Old Value | New Value | Formula | Ledger IDs |
|------|-----------|-----------|---------|------------|
| E[sigma^2] | 1.17 | 1.3642 | -2 * PLACEBO_A_MEAN | ESIGMA2_PLACEBO |
| sigma | 1.08 | 1.1680 | sqrt(ESIGMA2_PLACEBO) | SIGMA_PLACEBO |
| Var(eta) | 3.1 | 2.9126 | exp(ESIGMA2_PLACEBO) - 1 | VAR_ETA |
| Var(R) at T=10 | 0.31 | 0.2913 | VAR_ETA / 10 | VAR_R_T10 |
| -Var(R)/2 at T=10 | -0.156 | -0.1456 | -VAR_R_T10 / 2 | NEG_VAR_R_HALF_T10 |

**Note:** The old values (1.17, 1.08, 3.1, 0.31, -0.156) were computed at E[sigma^2]=1.42 (superseded) and then erroneously annotated as PLACEBO_A_SD^2. The correct derivation is E[sigma^2] = -2 * PLACEBO_A_MEAN per Proposition 1(a).

## R2: [V1c] Reliability Prediction

| Item | Old Value | New Value | Formula | Ledger IDs |
|------|-----------|-----------|---------|------------|
| T_h (half-length) | 10 (assumed) | 5.22 (measured) | mean over qualifying placebo | T_H_MEAN |
| Var(sigma^2) | 1.85 (fitted) | 3.6317 (derived) | 4*(PLACEBO_A_SD^2 - ESIGMA2_PLACEBO/T_H_MEAN) | VAR_SIGMA2_PLACEBO |
| Scan range | [0.47, 0.73] | DELETED | n/a | n/a |
| r observed | 0.75 | 0.7463 | Measured | PLACEBO_A_R |
| r predicted | not reported | 0.7764 | (V/4)/((V/4) + ESIGMA2/T_h) | R_PRED |
| Gap | not reported | +0.030 | R_PRED - PLACEBO_A_R | R_GAP |

**Finding:** The proposition predicts the observed placebo reliability to within 3 hundredths with no fitted parameter. The scan is replaced by this parameter-free test.

## R3: [0.39, 0.46] Removal

| Item | Old Value | New Value | Source |
|------|-----------|-----------|--------|
| 0.39 | "signal share" | DELETED | Was SD_THETA_IDSET lower bound from retired pack |
| 0.46 | "signal share" | DELETED | Was SD_THETA_IDSET upper bound from retired pack |
| Arm C Var_null | not stated | 1.887 | T21_arms.csv |
| Arm C SD_true | not stated | 0.7423 | T21_arms.csv |
| Arm A Var_null | not stated | 0.261 | T21_arms.csv |
| Arm A SD_true | not stated | 1.4754 | T21_arms.csv |

**Note:** The remark now cites arm-indexed values from T21_arms.csv. The 0.39/0.46 constants had no valid derivation under the current arm structure.

## R5: T2R Column Names

| Old Column | Issue | New Column |
|------------|-------|------------|
| Var_theta_hat | Ambiguous (was Var(theta_B), not Var(theta_D)) | Var_theta_B |
| Mean_SE_sq | Ambiguous (was se_B only, not se_total) | Mean_se_B_sq |
| Var_theta_hat_less_SE | Ambiguous | Var_theta_B_less_seB |
| (none) | Missing | SD_theta_D |

**Note:** T2R sidecar warning was licensing direction wrong. Regenerate with unambiguous names.

## R8: INV-027a Wording

| Old Statement | New Statement |
|---------------|---------------|
| "if V4 null is correct, the weighted Var_null for Arm C increases substantially" | "if V4 null is correct (0.159 instead of 1.230), the weighted Var_null for Arm C decreases: 1.887 - 0.439*1.230 + 0.439*0.159 = 1.417, and sqrt(2.438 - 1.417) = 1.011" |

## Cross-Check Results

| R-item | Prompt's Cross-Check | Computed Value | Status |
|--------|---------------------|----------------|--------|
| R1 E[sigma^2] | ~1.364 | 1.3642 | MATCH |
| R1 sigma | ~1.168 | 1.1680 | MATCH |
| R2 R_PRED at T_h=5 | ~0.767 | 0.7764 (at T_h=5.22) | MATCH |
| R2 gap at T_h=5 | ~+0.020 | +0.030 | CLOSE |

## Producer Scripts Created

| Script | Output | Purpose |
|--------|--------|---------|
| S26_jensen_params.R | T25_jensen_params.csv | R1/R2: E[sigma^2], Var(sigma^2), R_PRED, derived quantities |
| S27_size_gradient.R | T26_size_gradient.csv | R6: Size gradient regression and correlations |
