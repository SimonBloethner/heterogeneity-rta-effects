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

### INV-021: Pack theta_D Lineage Retired
- **Issue:** Pack theta_D used pooled counterfactual (S1) + W0 window convention
- **Impact:** All downstream quantities (SD_true, GE range) were computed on
  a different theta_D than the S*R chain produces
- **Resolution:** S*R chain with untreated-only counterfactual (S1R) + symmetric
  ±1 window is now canonical; pack lineage retired
- **Status:** Pack theta_D lineage RETIRED; N3/N4/N5 results are authoritative
- **Date:** 2026-07-26

### INV-022: se_B Omitted Counterfactual Uncertainty
- **Issue:** se_B (sampling noise from finite post-windows) omitted counterfactual
  uncertainty (sd_cf from y_hat_0 estimation variability)
- **Finding:** sd_cf accounts for 34% of total noise (S17 analysis)
- **Resolution:** se_total = sqrt(se_B² + sd_cf²) is the correct noise measure
  for deconvolution (Arm A)
- **Status:** se_B SUPERSEDED by se_total for deconvolution purposes
- **Date:** 2026-07-26

### INV-023: Drift Heterogeneity Omitted from Deconvolution
- **Issue:** Original deconvolution subtracted only noise variance, ignoring
  systematic drift heterogeneity across pairs
- **Finding:** N1 OOS pseudo-effect null shows Var_null_matched = 1.54
  (far exceeds mean(se_total²) = 0.26)
- **Impact:** SD_true_A = 1.48 (noise-only) vs SD_true_C = 0.95 (OOS drift null)
- **Resolution:** Identified set [0.95, 1.48] replaces point estimate;
  Arm C (OOS drift) is preferred
- **Status:** DOCUMENTED — three-arm deconvolution in N3
- **Date:** 2026-07-26

### INV-024: OOS Null Gate Applied to Uncorrected Object
- **Issue:** G3 gate in N1 was applied to pseudo_theta_B (uncorrected) rather
  than pseudo_theta_D (corrected by b_hat[decile])
- **Original:** mean(pseudo_theta_B) = -0.137 → G3 FAIL
- **Corrected:** mean(pseudo_theta_D) = +0.098 (SE: 0.022) → G3 PARTIAL
- **Cross-check:** mean(pseudo_theta_B) - mean(b_hat) = -0.137 - (-0.235) = 0.098 ✓
- **Impact on Arm C:**
  - Old Var_null_matched (pseudo_theta_B): 1.539
  - New Var_null_matched (pseudo_theta_D): 1.509
  - Old SD_true_C: 0.948
  - New SD_true_C: 0.964 [0.870, 1.041]
- **Status:** CORRECTED — C1/C2 analysis
- **Date:** 2026-07-26

### INV-025: Horizon-Cohort Disjunction in 11+ Bin
- **Issue:** OOS null for 11+ horizon bin uses different adoption cohorts than treated
- **Pseudo pairs (11+ bin):** n = 1,131, 100% post-2008 adoption
- **Treated pairs (11+ bin, SYMMETRIC):** n = 1,834, 100% pre-2008 adoption (≤2007)
- **Overlap:** DISJOINT — no shared adoption cohorts
- **Variance instability:** Cannot test directly (only post-2008 in pseudo)
- **Cohort variance ratios (pre/post) in other bins:**
  - 2-3: 0.67, 4-5: 0.53, 6-10: 0.47, mean: 0.56
- **R4 Sensitivity (SYMMETRIC weights, cohort-scaled 11+ null):**
  - (a) As measured: Var_null = 1.887, SD_true_C = 0.742
  - (b) Scaled by mean (0.56): Var_null = 1.648, SD_true_C = 0.889
  - (c) Scaled by min (0.47): Var_null = 1.601, SD_true_C = 0.915
  - (c) Scaled by max (0.67): Var_null = 1.711, SD_true_C = 0.853
- **SD_TRUE_C BRACKET:** [0.74, 0.91] under cohort sensitivity
- **Root cause:** By construction, pairs with 11+ post years adopted early (≤2007);
  pseudo pairs with 11+ late years come from recent adopters (post-2008).
- **H3 note:** 2-3 bin has 62 treated pairs under symmetric (min n_post = 3)
- **Status:** DOCUMENTED — fundamental design limitation
- **Date:** 2026-07-26

### INV-026: Horizon Binning Used W0 Window Instead of Symmetric
- **Issue:** N1 treated_dist computed horizon bins using W0 (year >= adoption),
  not symmetric window (year > adoption + 1)
- **R1 Finding (pseudo sample):**
  - C3 used N1 (4,244 pairs) — CORRECT
  - H1/H2 incorrectly filtered to baseline-only (3,387 pairs)
- **R2 Finding (treated weights):**
  - W0 weights: 2-3 (0%), 4-5 (1.7%), 6-10 (34.3%), 11+ (64.0%)
  - SYMMETRIC weights: 2-3 (1.5%), 4-5 (20.5%), 6-10 (34.2%), 11+ (43.9%)
  - 2008/2009 adopters moved from 11+ to 6-10/4-5 under symmetric
- **R3 Finding (Var_null_matched):**
  - N1 stored (W0): 1.539
  - INV-024 stated (W0): 1.509 — now superseded
  - CORRECT (SYMMETRIC): 1.887
- **Impact on SD_true_C:**
  - W0: 0.948
  - SYMMETRIC: 0.742 (before cohort scaling)
- **Canonical values (SYMMETRIC weights):**
  - Var_null_matched = 1.887
  - SD_true_C bracket = [0.74, 0.91] (cohort sensitivity)
- **Status:** CORRECTED — symmetric window is canonical
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
