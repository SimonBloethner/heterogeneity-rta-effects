# PROMPT S43 — Close INV-040, INV-041 and CAV-005

## Part A: Amend S30 to Regenerate T29

Amend code/S30_moment_power.R to:
1. Rename `mc_se` to `mc_se_mc` (Monte Carlo precision = sd(delta_vec)/sqrt(reps))
2. Add `sd_single_dataset` column (= sd(delta_vec), sampling SD in one realization)
3. Change z calculation to use `sd_single_dataset` NOT `mc_se_mc`
4. Old z values were inflated by sqrt(reps) = 20

Gate A1: the regenerated z at each grid cell equals the old z divided by sqrt(reps),
to four decimal places. Compare cell by cell.

Regenerate output/T29_moment_power.csv with:
- New columns: mc_se_mc, sd_single_dataset
- Corrected z = |delta| / sd_single_dataset

Verify ledger values match:
- MOMPOW_IDENT_MIN_Z: 2.96
- MOMPOW_IDENT_MAX_Z: 11.44
- MOMPOW_KAPPA1_W50_Z: 5.83
- MOMPOW_DEFF10_MAX_Z: 3.62
- MOMPOW_DEFF50_MAX_Z: 1.62

## Part B: Create S43_drift_inflation.R

Create code/S43_drift_inflation.R that:
1. Reads output/T39_a2_jensen_identity.csv (per-pair mean_log_eta, var_log_eta)
2. Reads output/T40_jensen_control.csv (panel-level slopes and reliability)
3. Computes level-route: w_level = E[var] / (-2 * E[mean])
4. Computes slope-route: w_slope = 0.5 / |disatt_slope_real|
5. Outputs output/T41_drift_inflation.csv

Gates:
- B1: |w_level - w_slope| / w_level < 0.05 (relative agreement)
- B2: |disatt_slope_ctrlc + 0.5| < 0.10 (control recovers -0.5)
- B3: |predicted - observed| < 0.01 (slope prediction)

Expected values:
- w_level = 1.937
- w_slope = 1.927
- disatt_slope_ctrlc = -0.5454

## Part C: Move S13b to archive

Move audit/S13b_matching_sensitivity.R to archive/retired_2026-07-29/S13b_matching_sensitivity.R
using git mv. Update FILE_REGISTRY.csv to change:
- audit/S13b row -> archive/retired_2026-07-29/S13b_matching_sensitivity.R, status ARCHIVED
- Remove code/S13b row (SUPERSEDED status is unenforced)

## Part D: Add registry rows

Add to FILE_REGISTRY.csv:
- code/S43_drift_inflation.R, BUILT
- output/T41_drift_inflation.csv, BUILT
- meta/T41_drift_inflation.csv.sidecar, BUILT

Update T29 sidecar with new hash and INV-040 amendment note.

## Part E: Measure with enforce.R

Run Rscript code/enforce.R from the repository root.
Expected: ZERO violations.

## Closure

This prompt closes:
- INV-040: T29 z column corrected to use identification-relevant SE
- INV-041 (partial): drift-inflation arithmetic gated
- CAV-005: S13b moved from SUPERSEDED to ARCHIVED

Created: 2026-08-03
