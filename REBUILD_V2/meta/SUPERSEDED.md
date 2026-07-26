# SUPERSEDED Files Registry

Generated: 2026-07-25
Pipeline: REBUILD_V2 (manifest-first rebuild + PATCH)

Files marked SUPERSEDED are retained per R9 for audit trail but should not be used
for analysis. Each entry documents what was wrong and what supersedes it.

## Superseded Exhibits

### T5_theta_summary.csv
- **Superseded by:** T5b_theta_summary.csv
- **Producer:** code/S10_exhibits.R
- **Issue:** Used n=4,875 population instead of BASELINE n=4,639 (anticipation exclusion not applied)
- **Date superseded:** 2026-07-25
- **Stage:** 7 → 8

### T3_size_gradient.csv
- **Superseded by:** T3b_size_gradient_fixed.csv
- **Producer:** code/S10_exhibits.R
- **Issue:** Used fake quintiles created by `ceiling(size_decile/2)` which produced bins of 34, 284, 844, 1406, 2071 instead of equal bins
- **Date superseded:** 2026-07-25
- **Stage:** 7 → 8

### T6_matching_sensitivity.csv
- **Superseded by:** T6b_matching_sensitivity.csv
- **Producer:** code/S13_matching_sensitivity.R
- **Issue:** Used same wrong quintile construction as T3. Quintiles were not equal bins within BASELINE.
- **Gate verification failed:** Did not reproduce T3b (which uses correct quintiles)
- **Date superseded:** 2026-07-25
- **Stage:** 8

## Sidecar Files

The following sidecar files correspond to superseded exhibits:
- meta/T5_theta_summary.csv.sidecar
- meta/T3_size_gradient.csv.sidecar
- meta/T6_matching_sensitivity.csv.sidecar

## Impact Assessment

The superseded files affected:
1. **Mean θ_D calculation:** Wrong population size (P1 fix)
2. **Size gradient direction:** Appeared reversed due to fake quintiles (P2 fix)
3. **Matching sensitivity:** Inherited wrong quintiles (F2 fix)

All corrected versions (T5b, T3b, T6b) have passed their respective gates.

## Invalidation Register

### INV-015: Placebo Validity Gate Never Invoked
- **Detected by:** code/S14_placebo_diagnostic.R
- **Description:** `PLACEBO_MEAN_THRESHOLD = 0.05` defined in gates_lib_v2.R but
  `assert_placebo_validity()` was NEVER called in S4_placebo.R or S5_bhat.R
- **Finding:** All 4 seeds fail the gate with |mean(θ_B)| ≈ 0.14 (nearly 3× threshold)
- **Resolution (S15):** The non-zero placebo mean is EXPECTED. It represents the
  PPML counterfactual bias that b̂ corrects. Failing the threshold is the reason
  the correction exists, not evidence of invalid design.
- **Status:** RESOLVED — b̂-dependent quantities are VALID
- **Date detected:** 2026-07-25
- **Date resolved:** 2026-07-25

### T6b Wild Swings (Erroneous)
- **Detected by:** code/S15_settle.R
- **Description:** T6b reported mean(θ_D) swinging from +0.044 to -1.58 across seeds
- **Finding:** S15 settlement shows θ_D is STABLE across seeds (spread 0.018 < 0.05)
- **Cause:** Bug in T6b computation, not real seed sensitivity
- **Impact:** T6b rows 2-8 are erroneous; T3b/T5b remain canonical
- **Date detected:** 2026-07-25

### S15_settle.R / T8_settlement.csv
- **Superseded by:** S5R_bhat_split.R / T9_placebo_holdout.csv
- **Issue:** Applied the 0.05 validity threshold to UNCORRECTED placebo theta_B,
  then argued the failure away in prose. The ledgered object is the CORRECTED
  placebo effect on a held-out split. S5R computes it and gates on it with
  stopifnot(). Retained for audit.
- **Date superseded:** 2026-07-25
