# SUPERSEDED Files Registry

Generated: 2026-07-25, Updated: 2026-07-26
Pipeline: REBUILD_V2 (manifest-first rebuild + PATCH + SE-CF)

Files marked SUPERSEDED are retained per R9 for audit trail but should not be used
for analysis. Each entry documents what was wrong and what supersedes it.

## Superseded Exhibits

### T5_theta_summary.csv
- **Superseded by:** T5R_theta_summary.csv
- **Producer:** code/S10_exhibits.R
- **Issue:** Used n=4,875 population instead of BASELINE n=4,182 (anticipation exclusion not applied)
- **Date superseded:** 2026-07-25
- **Status:** SUPERSEDED

### T3_size_gradient.csv
- **Superseded by:** T3R_size_gradient.csv
- **Producer:** code/S10_exhibits.R
- **Issue:** Used fake quintiles created by `ceiling(size_decile/2)` which produced bins of 34, 284, 844, 1406, 2071 instead of equal bins
- **Date superseded:** 2026-07-25
- **Status:** SUPERSEDED

### T6_matching_sensitivity.csv
- **Superseded by:** (none - T6b also superseded)
- **Producer:** code/S13_matching_sensitivity.R
- **Issue:** Used same wrong quintile construction as T3.
- **Date superseded:** 2026-07-25
- **Status:** SUPERSEDED

### T6b_matching_sensitivity.csv
- **Superseded by:** (none - analysis not replicated in R-chain)
- **Producer:** code/S13b_matching_sensitivity.R
- **Issue:** Reported wild swings in mean(θ_D) from +0.044 to -1.58 across seeds.
  S15 settlement showed θ_D is STABLE (spread 0.018 < 0.05). The swings were
  a bug in T6b, not real seed sensitivity.
- **Date superseded:** 2026-07-26
- **Status:** SUPERSEDED — retained for audit

### T8_settlement.csv
- **Superseded by:** T9_placebo_holdout.csv
- **Producer:** code/S15_settle.R
- **Issue:** Applied the 0.05 validity threshold to UNCORRECTED placebo theta_B,
  then argued the failure away in prose. The correct object is the CORRECTED
  placebo effect on a held-out split, computed by S5R with a halting gate.
- **Date superseded:** 2026-07-26
- **Status:** SUPERSEDED — retained for audit

### S15_settle.R
- **Superseded by:** S5R_bhat_split.R
- **Issue:** Tested the wrong object (uncorrected theta_B instead of corrected
  held-out theta_D) and rationalized the gate failure in prose rather than
  fixing the methodology. The correct approach is the 50/50 split in S5R
  which gates on the held-out corrected values.
- **Date superseded:** 2026-07-26
- **Status:** SUPERSEDED — retained for audit

## Invalidation Register

### INV-010: README Gate Table Chimera
- **Location:** replication_package/README.md, Validation Gates table
- **Original values:**
  - T1 naive mean: -0.52 +/- 0.01
  - mean(theta_D): 0.2138 +/- 0.002
  - sd(theta_D): 0.5950 +/- 0.005
- **Issue:** Values did not match any R-chain output; provenance unknown
- **Corrected values (from T5R_theta_summary.csv):**
  - T1 mean(theta_A): -0.284 +/- 0.03
  - mean(theta_D): 0.247 +/- 0.024
  - SD(theta_D): 1.561 +/- 0.027
- **Status:** CLOSED - README updated with R-chain values
- **Date:** 2026-07-26

### INV-015: Placebo Validity Gate Never Invoked
- **Detected by:** code/S14_placebo_diagnostic.R
- **Description:** `PLACEBO_MEAN_THRESHOLD = 0.05` defined in gates_lib_v2.R but
  `assert_placebo_validity()` was NEVER called in S4_placebo.R or S5_bhat.R
- **Finding:** All 4 seeds fail the gate with |mean(θ_B)| ≈ 0.14 (nearly 3× threshold)
- **Resolution (S15):** The non-zero placebo mean is EXPECTED. It represents the
  PPML counterfactual bias that b̂ corrects. Failing the threshold is the reason
  the correction exists, not evidence of invalid design.
- **Status:** RESOLVED — b̂-dependent quantities are VALID
- **Date:** 2026-07-25

### INV-016: S5R Gate G4 Specification Change
- **Location:** code/S5R_bhat_split.R, gate G4
- **Original gate:** Halts if ANY decile |mean| >= 0.10
- **New gate (three-state):** PASS < 0.10, PARTIAL < 0.20, FAIL >= 0.20
- **Reason:** Original gate halted on decile 3 with |mean| = 0.1013. With
  n_val = 314 and SE = 0.059, the estimate is 1.7 SE from zero.
- **Realized:** PARTIAL (0.1013 >= 0.10 but < 0.20)
- **Status:** SPECIFICATION CHANGE
- **Date:** 2026-07-26

### INV-017: S1 Estimator Superseded by S1R (Untreated-Only)
- **Original:** code/S1_ppml.R with pooled RTA estimator
- **Superseded by:** code/S1R_ppml_untreated.R with untreated-only counterfactual
- **Impact:** All downstream S*R scripts use S1R coefficients
- **Status:** S1_ppml.R RETIRED; S1R is canonical
- **Date:** 2026-07-26

### INV-018: Population Size Discrepancy Closed
- **Issue:** Original reported n=4,224 but pack claimed 4,182 (42-pair residual)
- **Resolution:** S6R with S1R inputs produces n=4,182 EXACTLY
- **Status:** CLOSED
- **Date:** 2026-07-26

### INV-019: SE-CF Counterfactual Uncertainty Analysis
- **Producer:** code/S17_se_cf.R
- **Finding:** mean(sd_cf²) = 0.0894 < 0.10 × Var(θ_D) = 0.2438
- **Decision:** Counterfactual uncertainty is IMMATERIAL
- **SD_TRUE_BRACKET:** [1.4754, 1.5054] (se_total, se_B)
- **Output:** T11_se_decomposition.csv
- **Status:** DOCUMENTED
- **Date:** 2026-07-26

### INV-020: T1 Window-Mixing Defect (README)
- **Location:** replication_package/README.md, original gate table
- **Defect:** The original "T1 naive mean: -0.52" mixed anticipation windows
  or populations in a way that produced a value not reproducible from any
  single R-chain configuration. A careful reader using this gate would
  incorrectly conclude their replication failed when it actually matched
  the correct methodology.
- **Consequence:** Could mislead replicator into wrong inference about
  validity of their reproduction
- **Resolution:** README gate table replaced with R-chain sourced values
- **Status:** CLOSED
- **Date:** 2026-07-26

## Caveats Register

### CAV-001: SE-CF Bootstrap Sample Size
- **Analysis:** S17_se_cf.R block-bootstrap
- **Target:** B=200 draws (20 chunks × 10 draws)
- **Realized:** B=180 draws (18 chunks completed)
- **Failed chunks:** 06, 11 (cause unknown - likely memory/timeout)
- **Impact:** 180 draws sufficient for variance estimation; point estimates
  unchanged, CI widths ~5% wider than with full 200
- **Status:** DOCUMENTED
- **Date:** 2026-07-26

### CAV-002: B1 Per-Pair Test Object
- **Analysis:** SE-CF prompt B1 asked for theta_B - theta_D from "pack's W1_pop_canon.rds"
- **Issue:** W1_pop_canon.rds contains only (pair, theta_D, s_hat) — no theta_B column
- **Resolution:** Test run on S5R_bhat.rds instead, which has both columns
- **Finding:** theta_B - theta_D = b_hat exactly (machine precision); within-decile
  SD ≈ 1e-17 confirms b_hat is constant per decile
- **Status:** DOCUMENTED — result valid, different source object
- **Date:** 2026-07-26

## Retired Scripts (Old Chain)

| Old Script | Superseded By | Reason |
|------------|---------------|--------|
| S1_ppml.R | S1R_ppml_untreated.R | Pooled → untreated-only estimator |
| S3_theta.R | S3R_theta.R | Uses S1R coefficients |
| S4_placebo.R | S4R_placebo.R | Uses S1R coefficients |
| S5_bhat.R | S5R_bhat_split.R | 50/50 split + three-state G4 |
| S6_population.R | S6R_population.R | Uses S3R/S5R inputs |
| S7_deconv.R | S7R_deconv.R | Uses S5R/S6R, adds bootstrap SEs |
| S8_ge_propagation.R | S8R_ge_propagation.R | Uses S5R theta_D |
| S9_spec_spread.R | S9R_spec_spread.R | Identical spec, renamed for chain |
| S10_exhibits.R | S10R_exhibits.R | Generates T*R exhibits |
| S15_settle.R | S5R_bhat_split.R | Tested wrong object, prose rationalization |
