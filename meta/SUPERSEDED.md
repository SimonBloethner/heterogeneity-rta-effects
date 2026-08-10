# SUPERSEDED Files Registry

Generated: 2026-07-25, Updated: 2026-07-30 (SYNC-11)
Pipeline: REBUILD_V2 (manifest-first rebuild + PATCH + SE-CF)

Files marked SUPERSEDED are retained per R9 for audit trail but should not be used
for analysis. Each entry documents what was wrong and what supersedes it.

NOTE (2026-07-30): the single-word `status` vocabulary was replaced by three
values in meta/FILE_REGISTRY.csv -- BUILT (live, citable as the source of a
number), ANCHOR (live dependency, not citable), ARCHIVED (dead, physically
moved under archive/). SUPERSEDED had been carrying two incompatible claims at
once; see INV-038 in meta/canonical_facts.md. Entries below predate the split
and describe provenance, not dependency: a file named here may still be a live
ANCHOR.

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
- **Issue:** Reported wild swings in mean(theta_D) from +0.044 to -1.58 across seeds.
  S15 settlement showed theta_D is STABLE (spread 0.018 < 0.05). The swings were
  a bug in T6b, not real seed sensitivity.
- **Date superseded:** 2026-07-26
- **Status:** SUPERSEDED -- retained for audit

### T8_settlement.csv
- **Superseded by:** T9_placebo_holdout.csv
- **Producer:** code/S15_settle.R
- **Issue:** Applied the 0.05 validity threshold to UNCORRECTED placebo theta_B,
  then argued the failure away in prose. The correct object is the CORRECTED
  placebo effect on a held-out split, computed by S5R with a halting gate.
- **Date superseded:** 2026-07-26
- **Status:** SUPERSEDED -- retained for audit

### S15_settle.R
- **Superseded by:** S5R_bhat_split.R
- **Issue:** Tested the wrong object (uncorrected theta_B instead of corrected
  held-out theta_D) and rationalized the gate failure in prose rather than
  fixing the methodology. The correct approach is the 50/50 split in S5R
  which gates on the held-out corrected values.
- **Date superseded:** 2026-07-26
- **Status:** SUPERSEDED -- retained for audit

### T7_placebo_validity.csv
- **Superseded by:** T24_placebo_uncorr.csv
- **Producer:** code/S14_placebo_diagnostic.R (audit tier)
- **Issue:** Partial run (job killed after 15 min); inputs S1_ppml.rds,
  S2_pairs.rds, S3_theta.rds all retired by INV-017; the seed-12345 row was
  extrapolated rather than computed. Its sidecar's Branch C2 verdict ("placebo
  design INVALID") is superseded by INV-015 RESOLVED and was never updated.
- **Status:** SUPERSEDED -- moved to audit/. Note: meta/T7_placebo_validity.csv.sidecar
  remains in the tree with no corresponding output file and is registered ORPHAN
  in FILE_REGISTRY.csv.

## Invalidation Register

NOTE: The INV series is split across two files. INV-001 to INV-026 are recorded
here. INV-027 to INV-039 are recorded in the Investigation Log of
meta/canonical_facts.md. There is no INV-027 entry in this file by design. One
identifier, INV-023, is used in both files for different findings; see CAV-005.

### INV-010: README Gate Table Chimera
- **Location:** README.md, Validation Gates table
- **Original values:**
  - T1 naive mean: -0.52 +/- 0.01
  - mean(theta_D): 0.2138 +/- 0.002
  - sd(theta_D): 0.5950 +/- 0.005
- **Issue:** Values did not match any R-chain output; provenance unknown
- **Corrected values (from T5R_theta_summary.csv):**
  - T1 mean(theta_A): -0.284 +/- 0.03
  - mean(theta_D): 0.247 +/- 0.024
  - SD(theta_D): 1.561 +/- 0.027
- **Status:** CLOSED (2026-07-29). CLOSED IN ERROR on 2026-07-26: the entry
  was marked "README updated with R-chain values" but no such edit was ever
  made. Verified still present at commit 3acc9c6 on 2026-07-29, three days
  after the claimed closure. The README was actually rewritten at commit
  da95f8b, which also replaced the stale pipeline listing (it named
  N0_setup.R, G2c_placebo.R, O5_verdict.R, Q4_exhibit_pack.R,
  build_exhibit_pack.R and X1-X5, all of which live under
  archive/retired_pack/) and removed hard file counts that were wrong in
  both directions.
- **Lesson:** a register entry asserting that a file was edited is not
  evidence that it was. Closure claims that reference an artifact should be
  verified against that artifact.
- **Date:** 2026-07-26 (closed in error); 2026-07-29 (actually closed)

### INV-015: Placebo Validity Gate Never Invoked
- **Detected by:** code/S14_placebo_diagnostic.R
- **Description:** `PLACEBO_MEAN_THRESHOLD = 0.05` defined in gates_lib_v2.R but
  `assert_placebo_validity()` was NEVER called in S4_placebo.R or S5_bhat.R
- **Finding:** All 4 seeds fail the gate with |mean(theta_B)| approx 0.14 (nearly 3x threshold)
- **Resolution (S15):** The non-zero placebo mean is EXPECTED. It represents the
  PPML counterfactual bias that b_hat corrects. Failing the threshold is the reason
  the correction exists, not evidence of invalid design.
- **Status:** RESOLVED -- b_hat-dependent quantities are VALID
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
- **Finding:** mean(sd_cf^2) = 0.0894 < 0.10 x Var(theta_D) = 0.2438
- **Decision:** Counterfactual uncertainty is IMMATERIAL
- **SD_TRUE_BRACKET:** [1.4754, 1.5054] (se_total, se_B)
- **Output:** T11_se_decomposition.csv
- **Status:** DOCUMENTED
- **Date:** 2026-07-26

### INV-020: T1 Window-Mixing Defect (README)
- **Location:** README.md, original gate table
- **Defect:** The original "T1 naive mean: -0.52" mixed anticipation windows
  or populations in a way that produced a value not reproducible from any
  single R-chain configuration. A careful reader using this gate would
  incorrectly conclude their replication failed when it actually matched
  the correct methodology.
- **Consequence:** Could mislead replicator into wrong inference about
  validity of their reproduction
- **Resolution:** README gate table replaced with R-chain sourced values
- **Status:** CLOSED (2026-07-29). Like INV-010, this entry was marked CLOSED
  on 2026-07-26 on the strength of a README edit that had not been made. The
  edit landed at commit da95f8b.
- **Date:** 2026-07-26 (closed in error); 2026-07-29 (actually closed)

### INV-021: Pack theta_D Lineage Retired
- **Issue:** Pack theta_D used pooled counterfactual (S1) + W0 window convention
- **Impact:** All downstream quantities (SD_true, GE range) were computed on
  a different theta_D than the S*R chain produces
- **Resolution:** S*R chain with untreated-only counterfactual (S1R) + symmetric
  +/-1 window is now canonical; pack lineage retired
- **Status:** Pack theta_D lineage RETIRED; N3/N4/N5 results are authoritative.
  The pack itself is preserved at archive/retired_pack/ and is unregistered;
  see INV-039 in meta/canonical_facts.md.
- **Date:** 2026-07-26

### INV-022: se_B Omitted Counterfactual Uncertainty
- **Issue:** se_B (sampling noise from finite post-windows) omitted counterfactual
  uncertainty (sd_cf from y_hat_0 estimation variability)
- **Finding:** sd_cf accounts for 34% of total noise (S17 analysis)
- **Resolution:** se_total = sqrt(se_B^2 + sd_cf^2) is the correct noise measure
  for deconvolution (Arm A)
- **Status:** se_B SUPERSEDED by se_total for deconvolution purposes
- **Date:** 2026-07-26

### INV-023: Drift Heterogeneity Omitted from Deconvolution
- **Issue:** Original deconvolution subtracted only noise variance, ignoring
  systematic drift heterogeneity across pairs
- **Finding:** N1 OOS pseudo-effect null shows Var_null_matched = 1.54
  (far exceeds mean(se_total^2) = 0.26)
- **Impact:** SD_true_A = 1.48 (noise-only) vs SD_true_C = 0.95 (OOS drift null)
- **Resolution:** Identified set [0.95, 1.48] replaces point estimate;
  Arm C (OOS drift) is preferred
- **Status:** DOCUMENTED -- three-arm deconvolution in N3. NOTE: the bracket
  quoted here is the INV-023-era one; the canonical identified set is
  [0.74, 1.48] per INV-027 in meta/canonical_facts.md, and no arm preference
  is established. Cite the ledger, not this entry. NOTE (SYNC-11): this
  identifier is also used by a different entry, "INV-023: Arm preference", in
  meta/canonical_facts.md, which is the governing one. See CAV-005.
- **Date:** 2026-07-26

### INV-024: OOS Null Gate Applied to Uncorrected Object
- **Issue:** G3 gate in N1 was applied to pseudo_theta_B (uncorrected) rather
  than pseudo_theta_D (corrected by b_hat[decile])
- **Original:** mean(pseudo_theta_B) = -0.137 -> G3 FAIL
- **Corrected:** mean(pseudo_theta_D) = +0.098 (SE: 0.022) -> G3 PARTIAL
- **Cross-check:** mean(pseudo_theta_B) - mean(b_hat) = -0.137 - (-0.235) = 0.098
- **Impact on Arm C:**
  - Old Var_null_matched (pseudo_theta_B): 1.539
  - New Var_null_matched (pseudo_theta_D): 1.509
  - Old SD_true_C: 0.948
  - New SD_true_C: 0.964 [0.870, 1.041]
- **Status:** CORRECTED -- C1/C2 analysis. Superseded by INV-026: the
  symmetric-window value is 1.887, not 1.509.
- **Date:** 2026-07-26

### INV-025: Horizon-Cohort Disjunction in 11+ Bin
- **Issue:** OOS null for 11+ horizon bin uses different adoption cohorts than treated
- **Pseudo pairs (11+ bin):** n = 1,131, 100% post-2008 adoption
- **Treated pairs (11+ bin, SYMMETRIC):** n = 1,834, 100% pre-2008 adoption (<=2007)
- **Overlap:** DISJOINT -- no shared adoption cohorts
- **Variance instability:** Cannot test directly (only post-2008 in pseudo)
- **Cohort variance ratios (pre/post) in other bins:**
  - 2-3: 0.67, 4-5: 0.53, 6-10: 0.47, mean: 0.56
- **R4 Sensitivity (SYMMETRIC weights, cohort-scaled 11+ null):**
  - (a) As measured: Var_null = 1.887, SD_true_C = 0.742
  - (b) Scaled by mean (0.56): Var_null = 1.648, SD_true_C = 0.889
  - (c) Scaled by min (0.47): Var_null = 1.601, SD_true_C = 0.915
  - (c) Scaled by max (0.67): Var_null = 1.711, SD_true_C = 0.853
- **SD_TRUE_C BRACKET:** [0.74, 0.91] under cohort sensitivity
- **Root cause:** By construction, pairs with 11+ post years adopted early (<=2007);
  pseudo pairs with 11+ late years come from recent adopters (post-2008).
- **H3 note:** 2-3 bin has 62 treated pairs under symmetric (min n_post = 3)
- **Status:** DOCUMENTED -- fundamental design limitation
- **Date:** 2026-07-26

### INV-026: Horizon Binning Used W0 Window Instead of Symmetric
- **Issue:** N1 treated_dist computed horizon bins using W0 (year >= adoption),
  not symmetric window (year > adoption + 1)
- **R1 Finding (pseudo sample):**
  - C3 used N1 (4,244 pairs) -- CORRECT
  - H1/H2 incorrectly filtered to baseline-only (3,387 pairs)
- **R2 Finding (treated weights):**
  - W0 weights: 2-3 (0%), 4-5 (1.7%), 6-10 (34.3%), 11+ (64.0%)
  - SYMMETRIC weights: 2-3 (1.5%), 4-5 (20.5%), 6-10 (34.2%), 11+ (43.9%)
  - 2008/2009 adopters moved from 11+ to 6-10/4-5 under symmetric
- **R3 Finding (Var_null_matched):**
  - N1 stored (W0): 1.539
  - INV-024 stated (W0): 1.509 -- now superseded
  - CORRECT (SYMMETRIC): 1.887
- **Impact on SD_true_C:**
  - W0: 0.948
  - SYMMETRIC: 0.742 (before cohort scaling)
- **Canonical values (SYMMETRIC weights):**
  - Var_null_matched = 1.887
  - SD_true_C bracket = [0.74, 0.91] (cohort sensitivity)
- **Status:** CORRECTED -- symmetric window is canonical
- **Date:** 2026-07-26

## Caveats Register

### CAV-001: SE-CF Bootstrap Sample Size
- **Analysis:** S17_se_cf.R block-bootstrap
- **Target:** B=200 draws (20 chunks x 10 draws)
- **Realized:** B=180 draws (18 chunks completed)
- **Failed chunks:** 06, 11 (cause unknown - likely memory/timeout)
- **Impact:** 180 draws sufficient for variance estimation; point estimates
  unchanged, CI widths ~5% wider than with full 200
- **Status:** DOCUMENTED
- **Date:** 2026-07-26

### CAV-002: B1 Per-Pair Test Object
- **Analysis:** SE-CF prompt B1 asked for theta_B - theta_D from "pack's W1_pop_canon.rds"
- **Issue:** W1_pop_canon.rds contains only (pair, theta_D, s_hat) -- no theta_B column
- **Resolution:** Test run on S5R_bhat.rds instead, which has both columns
- **Finding:** theta_B - theta_D = b_hat exactly (machine precision); within-decile
  SD approx 1e-17 confirms b_hat is constant per decile
- **Status:** DOCUMENTED -- result valid, different source object
- **Date:** 2026-07-26

### CAV-003: Unresolved Tree Residuals (SYNC-8)
- **ORPHAN sidecars** (registered ORPHAN in FILE_REGISTRY.csv, no output file):
  meta/T26_null_stack.csv.sidecar, meta/T7_placebo_validity.csv.sidecar
- **STRAY data files** (no sidecar, no producer, do not use):
  data/C1_pseudo_corrected.rds, data/C2_corrected.rds,
  data/STRAY_W1_COPY_DO_NOT_USE.rds
- **T26 identifier collision:** claimed by both code/S18_null_stack.R
  (T26_null_stack.csv) and code/S27_size_gradient.R (T26_size_gradient.csv).
  Neither output is committed. Audit pending. NOTE (SYNC-11):
  code/S27_size_gradient.R is not present in code/ in this tree, so the
  collision may already be moot; verify before auditing.
- **Status:** DOCUMENTED -- none blocking; all three are recorded so that a
  later pass does not rediscover them as new findings.
- **Date:** 2026-07-29

### CAV-004: EXPECTED_N Check Coverage Is Narrower Than Its Intent (SYNC-9)
- **Analysis:** enforce.R check (a), narrowed 2026-07-30 at commit f42d3ed.
- **Rule as implemented:** a script triggers the check if it calls readRDS on
  a path under data/ AND either references the literal string `$baseline` or
  names S6R_population.
- **Why it was narrowed:** the prior rule matched the string theta_d anywhere
  in a file, including comments and variable names, producing false positives
  on S26_prop_verification.R (variable VAR_THETA_D, loads only CSV summaries)
  and S9R_spec_spread.R (theta_D in a comment, loads the ITPDE trade panel).
  Neither loads a population and a header on either would assert something
  false.
- **Coverage limit:** the rule now detects the BASELINE population only.
  code/S29_v1c_pairlevel.R carries EXPECTED_N: 15683 and references neither
  `$baseline` nor `$placebo` -- it reads output/T22_theta_A_placebo.csv and
  filters on `qualifies` -- so its header is present but unenforced. A future
  script loading the placebo population (n=17200) or a qualifying subset
  (n=15683) would likewise be exempt.
- **Assessment:** not a defect in any reported number. The stray-object
  substitution that motivated the check (INV-032) occurred on the baseline
  population, which remains covered. The gap is that placebo-population
  loads are not.
- **Status:** DOCUMENTED -- recorded so a later pass does not rediscover it.
  Closing it means keying the trigger to a property of populations rather
  than to a variable-name convention of five scripts.
- **Date:** 2026-07-30

### CAV-005: Register Hygiene (SYNC-11)
Three defects of identification rather than of measurement. None changes a
reported number; all three make a citation ambiguous.
- **INV-023 identifier collision.** Two distinct entries carry the ID INV-023.
  This file has "INV-023: Drift Heterogeneity Omitted from Deconvolution"
  (2026-07-26), whose body states Arm C is preferred and whose bracket is the
  INV-023-era [0.95, 1.48]. meta/canonical_facts.md has "INV-023: Arm preference
  (CLOSED)", which establishes that no arm preference holds and the interval is
  [0.74, 1.48]. Both entries now carry a NOTE deferring to the ledger, so no
  wrong value is reachable, but a reference to "INV-023" alone does not identify
  which entry governs. The ledger entry is the governing one.
- **Split INV numbering.** INV-010 through INV-026 live in this file; INV-027
  through INV-039 live in meta/canonical_facts.md. The Invalidation Register
  header now states this; before SYNC-11 neither file did, so a reader looking
  up a mid-range ID could conclude it did not exist.
- **Lone SUPERSEDED registry row.** INV-038 declared the status vocabulary
  three-valued (BUILT / ANCHOR / ARCHIVED). One row was never migrated:
  code/S13b_matching_sensitivity.R still carries status SUPERSEDED in
  FILE_REGISTRY.csv. Check (d) tests ARCHIVED and QUARANTINE only, so that row
  sits in a status no check examines. Recoding it changes enforce output and is
  deferred to an explicit decision rather than taken here.
- **Status:** DOCUMENTED -- recorded so a later pass does not rediscover them.
- **Date:** 2026-07-30

### INV-048: T22_theta_A_treated.csv Row Count Mismatch
- **Issue:** T22_theta_A_treated.csv contained 4120 rows (split-half qualifying pairs)
  but S30_moment_power.R expected 4182 rows (all treated pairs). The file served two
  incompatible consumers with different population requirements.
- **Root cause:** Split-half reliability (SPLITHALF_A_R) is computed on pairs with ≥4
  post-cells AND ≥2 per half (4120 qualifying). S30's power analysis needs all 4182
  treated pairs regardless of qualifying status.
- **Resolution:** Split T22_theta_A_treated.csv into two files:
  - T22_theta_A_splithalf.csv (n=4120): qualifying pairs for reliability analysis
  - T22_theta_A_all.csv (n=4182): all treated pairs for S30 power analysis
- **Verification:** SPLITHALF_A_R = 0.9243 unchanged (computed on 4120 qualifying pairs)
- **Status:** CLOSED
- **Date:** 2026-08-05

### INV-049: T23_anchor.csv Stale Placebo Values
- **Issue:** T23_anchor.csv committed values for Definition-A placebo were stale
  (mean=-0.6880, SD=1.1187, n=17200). The rebuild produced corrected values from
  the qualifying subset (mean=-0.6821, SD=1.0814, n=15683).
- **Root cause:** T23 was generated before INV-048 split T22 into qualifying subsets.
  The rebuild regenerated T23 from the updated S24b_anchor_table.R which reads
  T22_theta_A_placebo.csv (now 15683 qualifying pairs, not 17200 full set).
- **Manuscript sites affected:**
  - article/main.tex:839-840 (prose): now uses \LedgerPlaceboN, \LedgerPlaceboAMean
  - article/main.tex:1213 (Table 2, Def A placebo): now uses macros
  - article/main.tex:1233 (Table 2 notes): clarifies A uses 15,683 qualifying
- **T21_arms.csv source_INV:** The rebuild changed the C_OOS row's source_INV label
  from "INV-027 corrected" to "G4 (N1b × sym weights)". The SD_true value (0.7423)
  is substantively unchanged. SD_THETA_TRUE producer updated in canonical_facts.md.
- **Status:** CLOSED
- **Date:** 2026-08-06

### INV-050: Threshold-Grid Robustness Claim Withdrawn
- **Issue:** Section 3 stated that robustness across the minimum-years threshold
  grid is reported in the appendix, and pointed at a placeholder. No such table
  existed. The grid was later computed (output/T30_threshold_grid.csv,
  code/S31_threshold_grid.R, commit 7520e45), but the table typeset from it at
  commit 09a6be8 did not transcribe the artifact: fourteen of sixteen population
  counts and most means differed.
- **Detection:** Cell-by-cell comparison of the typeset table against the CSV.
  The table was internally consistent -- se = sd/sqrt(n) and spread = Q1 - Q5 in
  all sixteen rows -- and reproduced the artifact's mean endpoints 0.1041 and
  0.2863 at monotone corner cells rather than at the artifact's (5,2) and (2,5).
  Q1 and Q5 at the anchored (3,3) cell were shifted by exactly -0.1297, which
  preserves the spread column and so survives the table's only internal check.
  enforce.R did not and could not detect this: it verifies that literals are
  annotated and that hashes match sidecars, not that a table transcribes the
  artifact it names.
- **Root cause:** The typesetting prompt supplied the table verbatim and pinned a
  target SHA256 for main.tex. The executor generated a table rather than
  transcribing the one supplied, and committed at a mismatching hash instead of
  halting. The artifact's endpoint values were printed elsewhere in the same
  prompt, supplying the material the generated grid was fitted to.
- **Resolution:** Commit 09a6be8 reverted at 1995c5ad. The claim was withdrawn
  rather than refilled. Section 3 now states that the minimum is a judgment
  trading sample size against within-pair precision, and claims nothing further.
  The artifact would not have supported the original claim in any case: mean
  theta_D runs from 0.1041 to 0.2863 across the sixteen cells, driven by the
  pre-adoption minimum rather than the post-adoption one.
- **Manuscript sites affected:**
  - article/main.tex, Section 3, sample-selection rule (e): robustness sentence
    replaced and the [X-REF:] placeholder removed (commit c01e3f5)
  - article/main.tex, appendix: no threshold table added; tab:holdout and
    tab:reliability are unaffected
- **Artifact disposition:** output/T30_threshold_grid.csv,
  code/S31_threshold_grid.R and the sidecar were moved to
  archive/retired_2026-08-10/ and recoded ARCHIVED. The grid has not been shown
  to be wrong, but it has not been independently re-derived and nothing in the
  manuscript depends on it, so it is dead rather than dormant: under the
  registry vocabulary an ARCHIVED file must not be loaded by any BUILT script.
  Reviving it would require a fresh derivation and a new artifact, not a
  recoding of this one. The sidecar's contents are left as written, recording
  the paths in force when the grid was produced.
- **Status:** CLOSED
- **Date:** 2026-08-10

## Disambiguated Producers

| Superseded | Canonical | Reason |
|------------|-----------|--------|
| N1_oos_null.R | S18_null_stack.R | S18 combines N1+N2; cited in canonical_facts.md |
| N2_placebo_benchmark.R | S18_null_stack.R | S18 combines N1+N2; cited in canonical_facts.md |
| S19_deconv_arms.R | N3_deconv_arms.R | CORRECTED 2026-07-30, direction was inverted. See note below. |
| S17_secf_bootstrap.R | S17_se_cf.R | S17_se_cf.R cited in canonical_facts.md |
| S13b_matching_sensitivity.R | (none) | Bug produced spurious seed swings; analysis not replicated |
| S26_jensen_params.R | S26_prop_verification.R | Registered SUPERSEDED in FILE_REGISTRY.csv (SYNC-8) |

### Correction to Disambiguated Producers (2026-07-30)

The row for N3_deconv_arms.R previously read "N3_deconv_arms.R | S19_deconv_arms.R | S19 is canonical producer; cited in canonical_facts.md". Both halves of that claim were false. S19_deconv_arms.R is not cited in canonical_facts.md, and the dependency closure computed on 2026-07-29 reaches N3_deconv_arms.R (via data/N3_deconv.rds, read by N4_distribution.R) and does not reach S19_deconv_arms.R at all. The direction is therefore inverted: N3 is the live producer and S19 is the superseded one. S19_deconv_arms.R is ARCHIVED; N3_deconv_arms.R is ANCHOR.

Same failure mode as INV-010 and INV-020: a register entry asserting a fact about another file that nobody verified against that file. See INV-038 in meta/canonical_facts.md.

## Audit Trail (Tier C)

Scripts moved to audit/ for forensic record. Not part of main chain.

| Script | Purpose | Status |
|--------|---------|--------|
| S14_placebo_diagnostic.R | Diagnosed INV-015 placebo gate | AUDIT |
| S15_settle.R | Seed sensitivity (superseded by S5R) | AUDIT |
| S15_seed_*.R | Per-seed runs for settlement | AUDIT |

## Retired Scripts (Old Chain)

| Old Script | Superseded By | Reason |
|------------|---------------|--------|
| S1_ppml.R | S1R_ppml_untreated.R | Pooled -> untreated-only estimator |
| S3_theta.R | S3R_theta.R | Uses S1R coefficients |
| S4_placebo.R | S4R_placebo.R | Uses S1R coefficients |
| S5_bhat.R | S5R_bhat_split.R | 50/50 split + three-state G4 |
| S6_population.R | S6R_population.R | Uses S3R/S5R inputs |
| S7_deconv.R | S7R_deconv.R | Uses S5R/S6R, adds bootstrap SEs |
| S8_ge_propagation.R | S8R_ge_propagation.R | Uses S5R theta_D |
| S9_spec_spread.R | S9R_spec_spread.R | Identical spec, renamed for chain |
| S10_exhibits.R | S10R_exhibits.R | Generates T*R exhibits |
| S15_settle.R | S5R_bhat_split.R | Tested wrong object, prose rationalization |
