# Canonical Facts Ledger

Generated: 2026-07-27 (SYNC-6)
Amended: 2026-07-29 (SYNC-7: gradient producer + Definition-B gradient, TW_MEAN rounding, anchor-table correction)
Amended: 2026-07-29 (SYNC-8: V1c moved onto the Arm 1' pair-level decomposition; INV-037 CLOSED)
Amended: 2026-07-30 (SYNC-9: SPEC_SPREAD ledgered; INV-038 opened and closed)
Amended: 2026-07-30 (SYNC-10: INV-033 CLOSED; Arm C reproduced end to end)
Status: CLOSED. No open investigations.

## Population

| ID | Quantity | Value | Producer |
|----|----------|-------|----------|
| N | Sample size | 4182 | code/S6R_population.R -> data/S6R_population.rds (census: output/TD1R_population_census.csv) |

## Effect Distribution

| ID | Quantity | Value | SE | Producer |
|----|----------|-------|-----|----------|
| MEAN_THETA_D | Mean theta_D | 0.2473 | 0.0241 | data/S5R_bhat.rds$baseline (n=4182) |
| SD_THETA_TRUE | SD(theta_true) | [0.74, 1.48] | - | INV-027 |
| RAW_SHARE | Share theta_D <= 0 | 0.4211 | - | data/S5R_bhat.rds$baseline (n=4182) |
| TW_MEAN | Trade-weighted mean theta_D | 0.0898 | - | code/S24_arms_canonical.R -> output/T21_arms.csv |

Note: TW_MEAN raw value is 0.0897566731583432 (T21_arms.csv, row TW_MEAN); 0.0898 is that value at 4 d.p. The earlier ledger entry 0.0897 was a truncation, not a rounding, and is superseded.

Note: TW_MEAN uses pre_trade weights (INV-034). total_trade weights yield 0.304; retired pack yielded 0.141. pre_trade is canonical because total_trade is endogenous to the effect.

## P(theta <= 0) Bracket

| ID | Quantity | Value | Producer |
|----|----------|-------|----------|
| P_THETA_LEQ_0 | P(theta_true <= 0) | [0.370, 0.421] | code/S22_ladder_closed_form.R -> output/T19_pleq0_bracket.csv |
| P_LO | C_hardened | 0.370 | Phi(-0.2473/0.7423), normal form |
| P_HI | A_noise_only | 0.421 | Capped at RAW_SHARE (normal form 0.433 exceeds empirical share) |

## GE Propagation (Arm-Indexed)

| Arm | SD_true | q50 | RANGE_1090 | Producer |
|-----|---------|-----|------------|----------|
| C_hardened | 0.740 | 28.2% | 6.64 | code/S23_ge_bracket.R -> output/T20_ge_bracket.csv |
| A_noise_only | 1.475 | 23.5% | 44.44 | code/S23_ge_bracket.R -> output/T20_ge_bracket.csv |

## Gradient

| ID | Quantity | Value | SE | Producer |
|----|----------|-------|-----|----------|
| GRADIENT | Q1-Q5 spread, Definition D | 0.9137 | 0.0809 | code/S28_gradient_B.R -> output/T27_gradient_B_spread.csv |
| GRADIENT_Q1 | Mean theta_D, quintile 1 (smallest pre-trade) | 0.8554 | 0.0760 | code/S28_gradient_B.R -> output/T27_gradient_B.csv |
| GRADIENT_Q5 | Mean theta_D, quintile 5 (largest pre-trade) | -0.0583 | 0.0277 | code/S28_gradient_B.R -> output/T27_gradient_B.csv |
| GRADIENT_B | Q1-Q5 spread, Definition B (pre-correction) | 0.6827 | 0.0821 | code/S28_gradient_B.R -> output/T27_gradient_B_spread.csv |
| GRADIENT_B_SHARE | GRADIENT_B / GRADIENT | 0.7472 | NA | code/S28_gradient_B.R -> output/T27_gradient_B_spread.csv |

Note (producer): the previous entry cited gates/X5_size_cohort.R -> gates/T3_gradient_cohorts.csv. No gates/ directory exists in this tree; the path was dangling. The value was also obtainable from output/T12_N4_gradient.csv, but that file is ANCHOR in FILE_REGISTRY.csv and a BUILT ledger entry must not cite it as a source. T27_gradient_B.csv reproduces every T12_N4_gradient column byte-identically under gates G3-G5 and is BUILT; it is the canonical producer for all five IDs above.

Note (partition): quintiles are as.integer(cut(rank(pre_trade), breaks = 5, labels = FALSE)); n = 837/836/836/836/837. Per-quintile SE is sd/sqrt(n); spread SE is sqrt(se_Q1^2 + se_Q5^2), the convention that reproduces T10R_reconciliation.csv Q1_Q5_spread se_fixed exactly (gate G7). GRADIENT_B_SHARE carries no SE: it is a ratio of two spreads and its sampling distribution is not established.

Note (shape - binding on prose): the profile is NOT monotone. Q4 = -0.0664 (SE 0.0369) lies below Q5 = -0.0583 (SE 0.0277); the Q4-Q5 difference is -0.0081 (SE 0.0462, t = -0.18). Q5 differs from zero at the 5 percent level (t = -2.11); Q4 does not (t = -1.80). Prose must state fall-then-floor, not monotone decline, and must not describe the largest pairs as statistically indistinguishable from zero. This is the shape Prop (iii) of the theory section predicts; a smoothly monotone negative profile would falsify it.

## Specification Spread

| ID | Quantity | Value | Producer |
|----|----------|-------|----------|
| SPEC_SPREAD | Published four specification estimates | [1.402, 0.922, 0.411, 0.095] | code/S9R_spec_spread.R -> output/T1R_spec_spread.csv |

Note: the four are, in order, (B) bilateral only, (C) country fixed effects, (CY) country-year fixed effects, (FULL) country-year plus pair fixed effects. T1R_spec_spread.csv reproduces all four to within 3e-4 of the published values and carries their standard errors (0.0596, 0.0553, 0.0536, 0.0299). Specifications (B) and (C) omit multilateral resistance and their deviation is bias; the substantive contrast is (CY) 0.411 against (FULL) 0.095. Section 5 cites this ID for the spread it resolves. Before SYNC-9 the four numbers were cited directly from T1R_spec_spread.csv with no ledger row, which put them outside the dependency closure computed on 2026-07-29.

## Reliability

| ID | Quantity | Value | n | Definition | Producer |
|----|----------|-------|---|------------|----------|
| SPLITHALF_A_R | Split-half Pearson r (treated) | 0.9243 | 4120 | A (mean of log gaps) | code/S24_reliability.R -> output/T22_reliability.csv |
| SPLITHALF_A_RELIABILITY | Spearman-Brown reliability (treated) | 0.9607 | 4120 | A (mean of log gaps) | code/S24_reliability.R -> output/T22_reliability.csv |
| THETA_A_MEAN | Mean theta_A (treated) | -0.2548 | 4120 | A (mean of log gaps) | code/S24_reliability.R -> output/T22_reliability.csv |
| THETA_A_SD | SD theta_A (treated) | 1.6318 | 4120 | A (mean of log gaps) | code/S24_reliability.R -> output/T22_reliability.csv |
| PLACEBO_A_MEAN | Mean theta_A (placebo) | -0.6821 | 15683 | A (mean of log gaps) | code/S24_reliability.R -> output/T22_reliability.csv |
| PLACEBO_A_SD | SD theta_A (placebo) | 1.0814 | 15683 | A (mean of log gaps) | code/S24_reliability.R -> output/T22_reliability.csv |
| PLACEBO_A_R | Split-half Pearson r (placebo) | 0.7463 | 15683 | A (mean of log gaps) | code/S24_reliability.R -> output/T22_reliability.csv |
| PLACEBO_A_RELIABILITY | Spearman-Brown reliability (placebo) | 0.8547 | 15683 | A (mean of log gaps) | code/S24_reliability.R -> output/T22_reliability.csv |

Note: Split rule is odd/even post-years (1st,3rd,5th->H1; 2nd,4th,6th->H2), >=2 cells per half required.

Note: per-pair theta_A for both populations is committed at output/T22_theta_A_treated.csv (n=4182) and output/T22_theta_A_placebo.csv (n=17200), each carrying a `qualifies` column recording the >=2-per-half rule. S24b_anchor_table.R and S26_jensen_params.R consume these files. They were declared as S24_reliability.R outputs from the start but were not committed until 2026-07-29; see INV-037.

## Jensen/Reliability Parameters (SYNC-6)

Derived from Proposition 1 using placebo moments. SYNC-6 correction: E[sigma^2] = -2*PLACEBO_A_MEAN (Prop 1a), NOT PLACEBO_A_SD^2.

| ID | Quantity | Value | Formula | Producer |
|----|----------|-------|---------|----------|
| ESIGMA2 | E[sigma^2] | 1.3642 | -2 * PLACEBO_A_MEAN | code/S26_prop_verification.R -> output/T25_prop_verification.csv |
| SIGMA | sigma | 1.1680 | sqrt(ESIGMA2) | code/S26_prop_verification.R |
| VAR_SIGMA2 | Var(sigma^2) | 4.0210 | 4*(Var(theta_A) - ESIGMA2*E[1/T_post,i]) | code/S29b_v1c_arm1p.R -> output/T28b_v1c_arm1p.csv |
| T_H_PLACEBO | Mean half-length (placebo) | 5.46 | Measured from split-half | code/S24_reliability.R (PLACEBO_TH) |
| R_PRED | Predicted reliability | 0.7539 | (V/4)/((V/4) + ESIGMA2*E[1/T_h,i]) | code/S29b_v1c_arm1p.R -> output/T28b_v1c_arm1p.csv |
| R_GAP | R_pred - R_observed | 0.0076 | R_PRED - PLACEBO_A_R | code/S29b_v1c_arm1p.R -> output/T28b_v1c_arm1p.csv |
| DRIFT_WEDGE | mean(sigma2_hat_i) / ESIGMA2 | 1.3460 | within-window variance vs Prop 1a quantity | code/S29_v1c_pairlevel.R -> output/T28_v1c_pairlevel.csv |
| VAR_ETA | Var(eta) | 2.9126 | exp(ESIGMA2) - 1 | code/S26_prop_verification.R |

Note: V1c is evaluated pair-wise (Arm 1'). The noise terms are E[sigma^2_i/T_h,i] and E[sigma^2_i/T_post,i], not ESIGMA2 divided by a mean window length: post windows vary across pairs, 1/T is convex, and the reciprocal of the mean understates the mean of the reciprocals. Values match article/prop_constants.tex (\PropRpred, \PropRgap, \PropVsigmasq); the plug-in values are retained in T25 as PROP_R_PRED_PLUGIN = 0.8068, PROP_V_SIGMA2_PLUGIN = 4.1773, PROP_CV_SIGMA2_PLUGIN = 1.4982. Superseded: 0.7862 / 0.0398 / 3.6772 (SYNC-6, stale) and 0.8068 / 0.0605 / 4.1773 (plug-in, SYNC-7).

Note: V1c consistency check: |R_GAP| = 0.0076 < 0.05. PASS. The 0.05 bound was NEVER RESTATED; the earlier miss (0.0605) was an estimator defect, not a tolerance problem, and removing it improved the prediction by a factor of eight in the direction convexity requires. Arms recorded in T28/T28b: Arm 0 (plug-in) +0.0605; Arm 1 (Jensen on 1/T_h only, internally inconsistent, DO NOT CITE) -0.0063; Arm 1' (canonical, ESIGMA2 throughout) +0.0076; Arm 2 (within-window sigma2_hat throughout) -0.0810.

Note: Arm 2 is rejected on wrong-object grounds, not on its gap. sigma2_hat_i is the within-post-window sample variance of the log gaps; under Prop 2 that variance converges to sigma^2_i + delta_i^2 Var(t | post) and so absorbs drift. ESIGMA2 is the quantity Prop 1(a) identifies, and is what the proposition's own formula refers to.

Note: DRIFT_WEDGE = 1.3460 is the excess of mean(sigma2_hat_i) over ESIGMA2. It has the sign and rough magnitude Prop 2 predicts, but it is NOT separately identified from departures from A2 (non-lognormal gaps, E[eta] != 1). Do not describe it as a measurement of the drift term. Related: mean(sigma2_hat_i/T_post,i) exceeds ESIGMA2*E[1/T_post,i] by 1.432 against a ratio of means of 1.346, implying positive covariance between sigma2_hat_i and 1/T_post,i.

## Placebo (Definition B, Uncorrected)

theta_B is seed-invariant on the fixed S5R$placebo set (n=17200). SYNC-6 correction: removed fabricated per-seed rows.

| ID | Quantity | Value | n | Definition | Producer |
|----|----------|-------|---|------------|----------|
| PLACEBO_B_UNCORR_OVERALL | Mean theta_B (uncorrected placebo) | -0.2072 | 17200 | B (uncorrected) | code/S25_placebo_uncorrected.R -> output/T24_placebo_uncorr.csv |
| PLACEBO_B_UNCORR_SD | SD theta_B (uncorrected placebo) | 0.8244 | 17200 | B (uncorrected) | code/S25_placebo_uncorrected.R -> output/T24_placebo_uncorr.csv |
| PLACEBO_B_UNCORR_DECILE1 | Mean theta_B decile 1 | -0.2063 | 37 | B (uncorrected) | code/S25_placebo_uncorrected.R -> output/T24_placebo_uncorr.csv |
| PLACEBO_B_UNCORR_DECILE5 | Mean theta_B decile 5 (peak) | -0.3647 | 2030 | B (uncorrected) | code/S25_placebo_uncorrected.R -> output/T24_placebo_uncorr.csv |
| PLACEBO_B_UNCORR_DECILE10 | Mean theta_B decile 10 | -0.0570 | 2407 | B (uncorrected) | code/S25_placebo_uncorrected.R -> output/T24_placebo_uncorr.csv |

Note: Gate G2 |mean|>0.05 FAILS (bias documented, not a validity failure). Decile pattern is hump-shaped (peak at D5), not monotone.

## Anchor Table (D2)

| Definition | Treated Mean | Treated n | Placebo Mean | Placebo n | Producer |
|------------|--------------|-----------|--------------|-----------|----------|
| A | -0.2837 | 4182 | -0.6880 | 17200 | code/S24b_anchor_table.R v2 -> output/T23_anchor.csv |
| B | 0.0758 | 4182 | -0.2072 | 17200 | code/S24b_anchor_table.R v2 -> output/T23_anchor.csv |
| D | 0.2473 | 4182 | NA | NA | code/S24b_anchor_table.R v2 -> output/T23_anchor.csv |

Note: this table reports what output/T23_anchor.csv contains, which is Definition-A placebo over the full S5R$placebo set (n=17200). PLACEBO_A_MEAN in the Reliability section is the same estimator over the 15683 split-half qualifying subset. Both are correct for their stated population; INV-037 verified the nesting directly.

Note: Definition B placebo from S5R$placebo (fixed pseudo year, n=17200).

## Superseded Entries

| Old Entry | Old Value | Cause | INV |
|-----------|-----------|-------|-----|
| "41% share theta_D <= 0" | 0.41 | wrong-object | INV-028 |
| "12.5x GE range" | 12.5 | un-indexed by arm | INV-028 |
| "27.25x GE range" | 27.25 | un-indexed by arm | INV-028 |
| P_HI = 0.433 | 0.433 | normal form exceeds raw share | INV-029 |

## QUARANTINED (INV-029)

T14, T15, T16, T17, T18 outputs.

## AUDIT

| File | Cause |
|------|-------|
| T7_placebo_validity.csv | Partial run, retired inputs, extrapolated seed; superseded by T24_placebo_uncorr.csv |

## RETIRED (INV-021)

- W1_pop_canon.rds
- S6_population.rds (use S6R_population.rds)

## Investigation Log

### INV-023: Arm preference (CLOSED)
Preference among arms A/B/C for headline reporting suspended pending INV-027a resolution.

Resolution: INV-027a closed. No arm preference established; SD_true reported as interval [0.74, 1.48].

Status: CLOSED. This remains the governing entry on arm preference. INV-033's closure establishes that the C endpoint is reproducible, not that it is preferred.

### INV-027: SD_true identified set (PARTIAL)
The true-effect SD is identified only up to an interval [0.74, 1.48], indexed by noise-subtraction arm.

**Arm definitions:**
| Arm | Name | Var_null | SD_true | Producer |
|-----|------|----------|---------|----------|
| A | Noise-only | 0.261 | 1.475 | code/N1_oos_null.R (horizon-matched) |
| B | Placebo | 0.680 | 1.326 | code/N2_placebo_benchmark.R (in-sample) |
| C | OOS drift | 1.887 | 0.742 | code/S24_arms_canonical.R (N1b variances x symmetric weights) |

**Var(theta_D) = 2.438** (canonical, from S5R_bhat.rds$baseline)
**SD_true = sqrt(Var(theta_D) - Var_null)**

Arm C is reproduced bin by bin in INV-033.

**Sub-item INV-027a (CLOSED): V4 vs S18 null for 11+ bin**

**Not a defect.** V4/S18 measure the in-sample pseudo null (S18 reuses S1R$y_hat_0, fitted on the late-pre cells); N1b measures the out-of-sample null (refits PPML excluding LATE cells, gate G2).

- V4_split_length.R (in-sample): 0.159 for 11+ bin
- N1b_oos_null.R (out-of-sample): 1.230 for 11+ bin

Arm C correctly uses N1b's out-of-sample variances with symmetric-window treated weights per INV-026:
- Var_null_C = sum over b of (weight_b x var_N1b_b) = 1.8868

The label `var_11plus_S18` in V4_split_length.csv was mislabelled; that value is from N1b, not S18. Corrected to `var_11plus_N1b`.

T26_null_stack.csv contains the in-sample pseudo null (0.389) and must not be cited as Arm C.

Status: CLOSED.

### INV-009: Split-half convention identified (CLOSED)
The superseded value 0.9244 (G2c) is reproduced by the R-chain at 0.924345 under Definition A with an odd/even post-year split. This identifies the split convention: G2c used odd/even; SPLITHALF_A_FRESH = 0.9720 used a different rule.

Both values are high; the reliability paradox rests on the within-run contrast between treated 0.9243 and placebo 0.7463, computed identically under the same split rule, not on either value's comparison to the retired chain.

Status: CLOSED.

### INV-029: Shape unidentified (CLOSED)
K=3 mixture returned duplicate components at the SD floor (k=2 mean 0.190 sd 0.100; k=3 mean 0.213 sd 0.100). Shape is not identified at the canonical signal share of 0.37. No mixture-based P(theta<=0) is reported.

Resolution: P_HI capped at empirical share of non-positive estimates (0.421), which requires no distributional assumption. Normal form at noise-only arm (0.433) exceeds that share and is not used as an endpoint.

### INV-030: theta_D location error (CLOSED)
Cause: theta_D does not exist in data/S6R_population.rds; raw-share computations pointed there were reading a stray W1 copy. Canonical raw share is 0.4211 from S5R_bhat.rds$baseline (n=4182).

Reconciliation with N4: N4 reported 0.421, which matches RAW_SHARE = 0.4211. RECONCILED.

Status: CLOSED.

### INV-032: Wrong-object class instance 7 (CLOSED)
During a provenance fix, the retired pack value 0.2138 was written over the R-chain value 0.2473. Cause: a stray W1 copy carrying the S6R filename was read in place of the committed artifact. The SE moved 0.0235 -> 0.0092, a factor of 2.6, which no re-sourcing of the same 4,182 pairs can produce.

Stray file renamed: data/STRAY_W1_COPY_DO_NOT_USE.rds

This is the substitution that motivates enforce.R check (a). See CAV-004 in SUPERSEDED.md for that check's current coverage limits.

Status: CLOSED.

### INV-033: Pseudo-population census (CLOSED)
Three counts had been recorded as competing definitions of "the" pseudo-population, with the concern that Arm C's null variance depends on which is used: 5,169 / 4,244 / 3,387. The premise is false. They are three different objects with three different roles, and Arm C depends on exactly one of them.

**Arm C reproduced end to end (2026-07-30).** Var_null_C is the sum over horizon bins of N1b's out-of-sample pseudo variance times the treated pairs' symmetric-window share. Variances from output/T12_N1b_horizon.csv, weights from output/T12_N1_oos_null.csv rows weight_2-3 ... weight_11+:

| bin | N1b var_pseudo | symmetric weight | contribution |
|-----|----------------|------------------|--------------|
| 2-3 | 4.41864153922999 | 0.0148254423720708 | 0.065508 |
| 4-5 | 2.83206266645286 | 0.20492587278814 | 0.580363 |
| 6-10 | 2.05298265088461 | 0.341702534672406 | 0.701509 |
| 11+ | 1.22990583720527 | 0.438546150167384 | 0.539370 |
| | | sum = 1.0000000000 | **1.8867510746** |

Agreement with the ledgered 1.8868 is 5e-5. Gate G4 in S24_arms_canonical.R asserts this to three decimals.

**Adjudication of the three counts:**
- **4,244** is N1b's MATCHED pseudo set, the sole pseudo-population entering Arm C. INV-026 R1 already declared it correct.
- **4,182** is the treated population supplying the weights. n_treated in T12_N1b_horizon.csv sums to exactly 4182 across the four bins, which is the canonical population N. The weights are therefore not a pseudo quantity at all.
- **5,169** is N1's raw pseudo count, before horizon matching. It belongs to Arm A. It appears in the Arm C code path only because T12_N1_oos_null.csv also stores the treated weights, and it contributes nothing to Var_null_C. N1's own matched variance is 0.389, the in-sample figure that must never be cited as Arm C.
- **3,387** is not a definition. It is the H1/H2 defect, baseline-only filtering of the pseudo sample, identified and corrected by INV-026.

**Consequence.** The lower endpoint of SD_THETA_TRUE is pinned. SD_true_C = sqrt(2.4379 - 1.8868) = 0.7424, ledgered as 0.7423; the fourth-decimal difference is the rounding of Var_null to 1.887 in T21_arms.csv and does not propagate to the reported interval, which is quoted to two decimals. The identified set [0.74, 1.48] stands on both endpoints, and both remain indexed by their noise-subtraction assumption. No arm preference is established or implied by this closure -- what is settled is that the C endpoint is reproducible, not that it is preferred.

Sections reporting the interval or the GE bracket must continue to report both endpoints with assumptions labelled. INV-023 remains the governing entry on arm preference.

Closes by the same logic as INV-036, which reconciled six placebo counts to filtering rules and superseded the placebo portion of this entry.

Status: CLOSED.

### INV-034: Trade-weighted mean reconciliation (CLOSED)
TW_MEAN values diverge by weighting scheme:
- pre_trade weights: 0.0898 (canonical, C4 adjudication; raw 0.0897566731583432)
- total_trade weights: 0.304 (T10R)
- retired pack: 0.141 (unknown weights)

Resolution: pre_trade is canonical because total_trade is endogenous to the effect (larger effects mechanically produce larger post-trade). C4 adjudication confirms pre_trade weighting for all trade-weighted quantities.

Status: CLOSED.

### INV-036: Placebo census (CLOSED)
Six placebo counts encountered in R-chain:
1. S5R$placebo: 17200 (canonical full placebo set)
2. T7 decile_only: 6339 (partial run, demoted to audit/)
3. T22 qualifying: 15683 (split-half >=2 per half filter)
4. N2_placebo.rds: 17200 (matches S5R$placebo)
5. T12_N2: 17200 (N2 output)
6. Retired pack: unknown (not reconcilable)

Resolution: S5R$placebo (n=17200) is the single canonical placebo population. Other counts arise from filtering rules (decile matching, split-half qualification). See T23_anchor.csv sidecar.

Supersedes placebo portion of INV-033; the remainder of INV-033 is closed by the same census logic.

Status: CLOSED.

### INV-037: T23 vs T22 Definition-A placebo, dual producer (CLOSED)
Two committed producers report Definition-A placebo moments on two different populations:
- T23_anchor.csv: n=17200, mean -0.68798, SD 1.11867 (full S5R$placebo)
- T22_reliability.csv: n=15683, mean -0.6821, SD 1.0814 (split-half qualifying subset)

RESOLVED (2026-07-29, S24-PROV). W2 was already implemented: S24b_anchor_table.R v2 consumes T22's per-pair files rather than recomputing. Those two files (output/T22_theta_A_treated.csv, output/T22_theta_A_placebo.csv) were declared as S24_reliability.R outputs but had never been committed; three scripts depended on artifacts absent from the tree. They are now committed.

Discriminating test, both gates PASS on the regenerated per-pair file:
- mean over all 17200 placebo pairs = -0.68798424523333 (T23_anchor.csv)
- mean over the 15683 qualifying subset = -0.68210567525916 (T22 / PLACEBO_A_MEAN)

One estimator, nested populations. No producer disagreement, no recomputation of T23 warranted, no article edit required.

Status: CLOSED.

### INV-038: Check (d) never fired; SUPERSEDED carried two meanings (CLOSED)
enforce.R check (d) enforces "no BUILT output may depend on a QUARANTINE, SUPERSEDED or RETIRED input". It subset FILE_REGISTRY.csv on a column named `file`. That column does not exist; the column is `file_path`. The check therefore compared every output against an empty set of forbidden inputs and reported zero violations from the day it was written until 2026-07-29.

Two further defects in the same instrument were found the same day:
- enforce.R hardcoded setwd() into /groups/m-larch/bt307958/REBUILD_V2, a stale partial mirror. Every enforce result ever produced described that directory, not the repository.
- Check (b) resolved sidecar producers with file.path("code", producer). 50 sidecars write "code/X.R" and 13 write "X.R", so the 50 resolved to code/code/X.R and were reported missing though the files existed. This inflated the violation count by 46.

Root cause of all three: no check had ever been tested. None had a known-pass and known-fail case. A fixture suite now exists under tests/fixtures/ and all ten checks provably discriminate.

Underlying conceptual defect: the single `status` column carried two incompatible claims -- "do not cite this as the source of a number" and "nothing depends on this". Files were marked SUPERSEDED under the first meaning while check (d) was written to enforce the second. Because check (d) could not fire, the contradiction stayed invisible: at the time it was found, fifteen SUPERSEDED files were live dependencies of numbers in the paper. The vocabulary is now three-valued -- BUILT (live, citable), ANCHOR (live dependency, not citable), ARCHIVED (dead, moved to archive/) -- and check (d) tests the second meaning only.

Also corrected: README.md and MANIFEST.txt published "Expected: only L* QUARANTINE violations" as the enforce baseline. That figure had never been measured on the repository. The pass condition is now zero violations and no expected-violation list exists.

No number in the paper was affected. All 55 sidecars carrying a FILE and SHA256 field were verified against file bytes at commit bb8d9e86: 54 matched and one was a known orphan (T26_null_stack.csv). Every defect was in the verification layer.

Residual coverage limit recorded separately as CAV-004 in SUPERSEDED.md.

Status: CLOSED.

### INV-035: Placebo reliability reported under wrong definition (CLOSED)
S24_reliability.R v1 reported placebo mean -0.2072, SD 0.8244, which match T12_N2 exactly. These are Definition D values (theta_B from S5R$placebo), not Definition A as specified.

Definition A: theta_A(pair) = mean over post cells of [log(trade) - log(y_hat_0)]
Definition D: theta_D = theta_B - b_hat (bias-corrected)

Corrected values under Definition A (S24_reliability.R v2):
- Treated: mean=-0.2548, SD=1.6318, r=0.9243 (n=4120 qualifying)
- Placebo: mean=-0.6821, SD=1.0814, r=0.7463 (n=15683 qualifying)

Wrong-object class, instance 8.

Status: CLOSED.
