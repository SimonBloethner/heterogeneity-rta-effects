# Canonical Facts Ledger

Generated: 2026-07-27 (SYNC-6)
Amended: 2026-07-29 (SYNC-7: gradient producer + Definition-B gradient, TW_MEAN rounding, anchor-table correction)
Amended: 2026-07-29 (SYNC-8: V1c moved onto the Arm 1' pair-level decomposition; INV-037 CLOSED)
Amended: 2026-07-30 (SYNC-9: SPEC_SPREAD ledgered; INV-038 opened and closed)
Amended: 2026-07-30 (SYNC-10: INV-033 CLOSED; Arm C reproduced end to end)
Amended: 2026-07-30 (SYNC-11: treated-population nesting note; INV-039 opened)
Amended: 2026-07-30 (SYNC-12: S30 ledgered; INV-040 opened -- three S30 IDs superseded)
Amended: 2026-08-02 (SYNC-13: (A2) diagnostics ledgered from S34/S35; INV-041 opened)
Amended: 2026-08-02 (SYNC-14: drift-calibration holdout ledgered; T9 values were cited from output/ with no ledger row)
Amended: 2026-08-03 (SYNC-15: package closure; INV-039, INV-042, INV-043 CLOSED; enforce zero at 1678d7f)
Amended: 2026-08-03 (SYNC-16: INV-040 and INV-041 CLOSED; CAV-005 resolved; register closed)
Status: NO OPEN INVESTIGATIONS. enforce.R reports zero violations on a clean tree at origin/main. See the Closure Register (SYNC-16).

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

Note: Arm 2 is rejected on wrong-object grounds, not on its gap. sigma2_hat_i is the within-post-window sample variance of the log gaps; under Prop 2 that variance converges to sigma^2_i + delta_i^2 Var(t | post) and so absorbs drift. ESIGMA2 is the quantity Prop 1(a) identifies, and is what the proposition's own formula refers to. SYNC-13 note: S34/S35 provide independent support for this rejection on a much larger untreated sample; see INV-041, where the same contamination appears at a factor of 1.937 over windows averaging 21.5 cells.

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

Note (treated nesting, symmetric to the placebo note above): the ledger documented
the nesting on the placebo side only. Definition-A treated moments appear at two
counts, and both are correct. Over the full canonical population (n=4182) the mean
is -0.2837 and the SD 1.6630; these are the values in this table and in
output/T5R_theta_summary.csv (BASELINE row), and they are what Section 4 cites for
the correction path's dispersion. Over the 4120 pairs satisfying the split-half rule
(>=2 cells per half) the mean is -0.2548 and the SD 1.6318, ledgered as THETA_A_MEAN
and THETA_A_SD in the Reliability section, because a reliability statistic must be
computed on the population that supports a split. One estimator, nested populations,
exactly as INV-037 established for the placebo side; the 62-pair difference is the
split-half qualification rule and nothing else. Neither figure supersedes the other,
and no producer disagreement is to be inferred from the gap.

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

Status: CLOSED. This remains the governing entry on arm preference. INV-033's closure establishes that the C endpoint is reproducible, not that it is preferred. Note: a second entry also numbered INV-023 exists in meta/SUPERSEDED.md on a related subject with a superseded bracket; see CAV-005. This entry governs.

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

The treated population nests the same way (4182 vs 4120); see the treated-nesting note under Anchor Table (D2), added at SYNC-11.

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

Residual coverage limit recorded separately as CAV-004 in SUPERSEDED.md. A second, larger coverage limit in the same check is recorded as INV-039.

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

### INV-039: archive/retired_pack/ is outside FILE_REGISTRY.csv (CLOSED)
The directory itself is intentional and documented: README.md describes
archive/retired_pack/ as the retired exhibit pack (INV-021), preserved unmodified
for referee verification, with nothing in it to be cited, and MANIFEST.txt lists it
as frozen. The intent is correct. The defect is that the intent is nowhere
enforced, because the directory was never enrolled in the registry that the
enforcement instrument reads.

archive/retired_pack/ contains code/, data/, docs/ and output/ plus its own
MANIFEST.txt (generated 2026-07-25 by Z0_assemble_package.R). Its output/ directory
holds A0_anchor_table.csv, A1_vuong.csv, A2_residual_tails.csv,
A3_kappa_convergence.csv, A4_per_year_anchor.csv, A5_proposition_verification.csv,
F1-F4 in both formats, T1-T7, the pack's own canonical_facts.md and
invalidation_register.md, gate_report.csv/.rds, and fifteen sidecars.

FILE_REGISTRY.csv contains ZERO rows matching archive/retired_pack. Its only
archive prefix is archive/retired_2026-07-29/ (125 rows).

Consequence, and it is the operative defect. enforce.R check (d) builds its
forbidden-input set from registry rows carrying status ARCHIVED or QUARANTINE.
Files absent from the registry are absent from that set. A live script could
therefore read archive/retired_pack/output/A0_anchor_table.csv, or the pack's own
canonical_facts.md, and check (d) would report nothing. MANIFEST.txt asserted
"every tracked file registered", which was false; that line is corrected in the
same commit as this entry.

This is the INV-038 class: a verification instrument trusted beyond its coverage.
INV-038 fixed a check that could not fire because it read the wrong column. This
entry records a check that cannot fire because the objects it would forbid were
never enrolled.

Two fixes, and they are not alternatives:
1. Enumerate archive/retired_pack/ into FILE_REGISTRY.csv with status ARCHIVED,
   one row per committed file. Mechanical; must be done from a local checkout so
   the enumeration is complete rather than sampled.
2. Make check (d) structural rather than enrolment-dependent: any path under
   archive/ is a forbidden input to a BUILT output, whether or not it appears in
   the registry. This closes the class; (1) closes only the instance. Per the
   standing rule that every check carries a known-pass and known-fail fixture,
   (2) requires a fixture pair before it is merged.

Both are executor tasks and neither is performed by this entry.

Related: the values in archive/retired_pack/output/A5_proposition_verification.csv
are the retired-pack anchors (0.2138, 0.5950, -0.7121, 1.1165) and are forbidden.
That file is also the referent of the "[A5:row]" citation convention used in some
drafting specifications; the live proposition-verification table is
output/T25_prop_verification.csv and A5 must not be cited. A5 contains no two-world
moment match and no KS statistic, so the equivalence verification that convention
was thought to point at does not exist in either the live chain or the pack.

Status: CLOSED. See the Closure Register (SYNC-16).

## Higher-Moment Separation (S30)

Power of a pooled excess-kurtosis statistic to distinguish World T (transitory
effect variation, rho=1, omega^2=w) from World V (treatment-coincident volatility
change, omega^2=0, rho^2=(sigma^2+w)/sigma^2) -- the two parameterizations
Proposition 3(b) proves observationally equivalent under normality. Under
normality the difference is zero by construction and gate G1 confirms it; the
grid therefore measures what non-normality buys.

BINDING NOTE ON THE z COLUMN (SYNC-12). output/T29_moment_power.csv computes
mc_se = sd(delta_vec)/sqrt(reps) and z = |delta|/mc_se. That mc_se is the Monte
Carlo precision of the simulation's estimate of the mean difference. It is NOT
the identification-relevant standard error. An econometrician holds one dataset,
so the operative quantity is the sampling SD of the statistic in a single
dataset, which equals mc_se * sqrt(reps). The tabulated z therefore overstates
the identification-relevant z by exactly sqrt(reps) = 20 at reps = 400.
Correction requires no re-run: z_ident = z_tabulated / sqrt(reps), derivable from
the committed table. Cite the MOMPOW_IDENT_* IDs below. Never cite the T29 z
column in any statement about what these data permit. The defect originated in
the drafting prompt, which asked for "the Monte Carlo standard error of delta";
the script computed exactly what was asked. See INV-040.

| ID | Quantity | Value | Producer |
|----|----------|-------|----------|
| MOMPOW_KAPPA0_DELTA | Mean delta at kappa_u=0, averaged over the four w cells | -0.000485 | code/S30_moment_power.R -> output/T29_moment_power.csv |
| MOMPOW_IDENT_MIN_Z | Identification z, min over kappa_u>0 cells (kappa_u=0.75, w/E=0.10) | 2.96 | code/S30_moment_power.R -> output/T29_moment_power.csv |
| MOMPOW_IDENT_KAPPA1_W50_Z | Identification z at kappa_u=1.0, w/E[sigma^2]=0.50 | 5.83 | code/S30_moment_power.R -> output/T29_moment_power.csv |
| MOMPOW_IDENT_MAX_Z | Identification z, max over grid (kappa_u=3.0, w/E=1.00) | 11.44 | code/S30_moment_power.R -> output/T29_moment_power.csv |
| MOMPOW_IDENT_DEFF10_MAX_Z | Identification z at the max cell, assumed design effect 10 | 3.62 | code/S30_moment_power.R -> output/T29_moment_power.csv |
| MOMPOW_IDENT_DEFF50_MAX_Z | Identification z at the max cell, assumed design effect 50 | 1.62 | code/S30_moment_power.R -> output/T29_moment_power.csv |

Note (calibration): sigma^2 ~ Gamma(shape 0.463, rate 0.339), matched to ESIGMA2
and VAR_SIGMA2. Per-pair post-window length is the empirical distribution from
output/T22_theta_A_treated.csv, column n_post_cells, range [3, 26], median 10 --
not the mean, for the convexity reason recorded in the V1c notes. Seed 20260719,
400 replications per cell. sigma^2 and theta are shared across the two worlds
within a replication; the shocks are drawn independently, so this is a partially
paired design and no variance reduction from common random numbers is claimed.

Note (binding on prose): the finding is conditional and must not be reported as
a clean negative or a clean positive. Under cross-pair independence the
higher-moment route is available: z runs from 2.96 to 11.44 across the grid, so
mild non-normality suffices. Under an assumed design effect of 10 it is marginal
(0.94 to 3.62) and under 50 it is unavailable (0.42 to 1.62). Cross-pair
dependence has never been estimated in this repository. Prose must therefore
state that the route is open under independence and that its status under
dependence is unmeasured. It must not state that the route is closed, which was
the appendix's pre-SYNC-12 claim, and it must not state that it is open
unconditionally.

SYNC-13 note: S34 measures the relevant excess kurtosis at about 1.05 net of its
control, which lies between this grid's kappa_u = 1.0 and 1.5 cells. The
conditional above is therefore no longer hypothetical on the kurtosis axis; it
remains hypothetical on the dependence axis. See the (A2) Diagnostics section.

## Superseded Entries (S30, SYNC-12)

| Old ID | Old Value | Cause | INV |
|--------|-----------|-------|-----|
| MOMPOW_KAPPA1_W50_Z | 116.5 | Monte Carlo precision ledgered as identification z | INV-040 |
| MOMPOW_MAX_Z | 228.89 | Monte Carlo precision ledgered as identification z | INV-040 |
| MOMPOW_DEFF50_MAX_Z | 32.37 | Monte Carlo precision ledgered as identification z | INV-040 |

### INV-040: T29 z column answers the wrong question (CLOSED)
The S30 drafting prompt specified "mc_se = the Monte Carlo standard error of
delta" and "z = |delta| / mc_se". The script implemented that specification
exactly: sd(delta_vec)/sqrt(reps). The specification was wrong. The Monte Carlo
standard error measures how precisely 400 replications pin down the expected
difference between the two worlds. The question the paper asks is whether a
researcher holding one realization of 4,182 pairs can distinguish them, and the
answer to that turns on the sampling SD of the statistic within a single
dataset, which is larger by sqrt(reps).

Consequence: every z in output/T29_moment_power.csv is inflated by a factor of
exactly 20, and three ledger IDs were entered on the inflated definition. The
substantive direction is unchanged -- the higher-moment route is open under
independence -- but the margin is 3 to 11, not 59 to 229, and under a moderate
design effect it becomes marginal rather than overwhelming. The appendix sentence
that this task was commissioned to replace must be replaced by a conditional
statement, not by an unconditional one.

No re-run is required to obtain the corrected figures; the relation is exact
arithmetic on the committed table. A re-run is nonetheless desirable so that the
artifact carries the right column rather than a ledger note, and so that both
definitions appear side by side. S30's only inputs are meta/canonical_facts.md
and output/T22_theta_A_treated.csv, both repository-resident, so the re-run needs
R but not the cluster and not the trade panel.

Closing this entry requires: (1) T29 regenerated with both columns, mc_se_mc and
sd_single_dataset, and z on the second; (2) the sidecar reissued with the
producer script's own SHA256 recorded, which the first issue omitted; (3) this
section's MOMPOW_IDENT_* values re-derived from the regenerated table and
confirmed identical to the arithmetic above.

Class: wrong-object, instance 9. Unlike instances 1-8 the wrong object was
specified rather than substituted, and the executor is not at fault.

Status: CLOSED. See the Closure Register (SYNC-16).

## (A2) Diagnostics (S34 / S35)

Assumption (A2) states log eta_ijt = -sigma^2_ij/2 + u_ijt with u normal, where
eta is observed trade over the fitted counterfactual. Two implications are tested
separately: normality of the within-pair log gaps, and the location identity that
a pair's mean log gap equals minus half its variance. Sample: untreated cells
only, pairs with >= 8 cells, n = 27,782 pairs and 570,791 cells, mean window 21.5
cells.

Every statistic is reported against a normal control matched pair by pair and
passed through identical code. Within-pair centring and scaling on short windows
deforms even exactly normal data, so the control -- not a theoretical normal -- is
the reference. Gate G1 (control rejection rate within 0.02 of 0.05) realized
0.0503 and PASSED, which is what makes the real-panel readings admissible.

| ID | Quantity | Value | Producer |
|----|----------|-------|----------|
| A2_N_PAIRS | Pairs in the (A2) diagnostic | 27782 | code/S34_a2_normality.R -> output/T38_a2_normality.csv |
| A2_REJECT_REAL | Per-pair normality rejection rate, real (Shapiro-Wilk, 5 pct) | 0.3277 | code/S34_a2_normality.R -> output/T38_a2_normality.csv |
| A2_REJECT_CONTROL | Per-pair rejection rate, matched normal control | 0.0503 | code/S34_a2_normality.R -> output/T38_a2_normality.csv |
| A2_SKEW | Pooled skewness of standardized log gaps, real | -0.4755 | code/S34_a2_normality.R -> output/T38_a2_normality.csv |
| A2_EXKURT | Pooled excess kurtosis, real | 0.7840 | code/S34_a2_normality.R -> output/T38_a2_normality.csv |
| A2_EXKURT_CONTROL | Pooled excess kurtosis, control | -0.2693 | code/S34_a2_normality.R -> output/T38_a2_normality.csv |
| A2_TAIL_RATIO_P99 | Upper-tail quantile ratio at p0.99, real/control | 0.9431 | code/S34_a2_normality.R -> output/T38_a2_normality.csv |
| A2_JENSEN_SLOPE | Slope of mean_i on var_i, real | -0.1966 (SE 0.0010) | code/S35_jensen_control.R -> output/T40_jensen_control.csv |
| A2_JENSEN_SLOPE_CTRLC | Same slope, Control C (identity imposed exactly) | -0.3351 (SE 0.0014) | code/S35_jensen_control.R -> output/T40_jensen_control.csv |
| A2_VAR_RELIABILITY | Split-half reliability of var_i as a regressor, real | 0.7575 | code/S35_jensen_control.R -> output/T40_jensen_control.csv |
| A2_VAR_RELIABILITY_CTRLC | Same, Control C | 0.6144 | code/S35_jensen_control.R -> output/T40_jensen_control.csv |

Note (normality is rejected, and in which direction): the real rejection rate
exceeds the control's by 0.2774 (SE 0.0031). The departure is left-skewed and
leptokurtic: excess kurtosis is 0.7840 against the control's -0.2693, a net
departure of about 1.05. The UPPER tail is thinner than the control at p0.95,
p0.99 and p0.995 (ratios 0.899, 0.943, 0.964), matching only at p0.999 (1.020).
Prose must not describe the log gaps as heavy-tailed on the right. The excess
kurtosis is a left-tail phenomenon: occasional collapses of trade far below the
counterfactual, more often than normal allows.

Note (binding on Section 6): the net excess kurtosis of about 1.05 lies inside the
grid of the S30 higher-moment power calculation, between its kappa_u = 1.0 and 1.5
cells. Section 6 must therefore state the equivalence boundary as a measured
conditional rather than a wall. See MOMPOW_IDENT_* and INV-040.

Note (intercept is uninformative in both panels): Control C returns an intercept
of -0.5883 although the location identity is imposed exactly in its generating
parameters, which is further from zero than the real panel's -0.2201. No reading
of the intercept is admissible in either panel.

### INV-041: (A2) normality rejected; location identity survives (CLOSED)
S34 rejects normality of the within-pair log gaps: 32.77 percent of pairs reject
against a matched-control rate of 5.03 percent.

S35 was commissioned to decide whether the accompanying slope departure
(-0.1966 against the -0.5 that (A2) predicts) reflects a failed location identity
or an attenuated estimator. Control C -- same pairs, same counts, each pair's
realized variance, mean fixed at exactly -v_i/2, shape matched to the measured
skewness and excess kurtosis (G1 realized 0.032 and 0.031 against tolerances of
0.10 and 0.15) -- returns -0.3351. Disattenuating by the split-half reliability of
var_i recovers -0.5454 against a true -0.5000, so the correction is validated on a
panel whose answer is known; applied to the real panel it gives -0.2595.

DERIVED, NOT GATED -- the following is arithmetic performed on committed artifacts
during drafting, not the output of a gated script, and is entered here so that it
is not rediscovered. It requires verification in a gated script before any of it
is cited in the article.

Over the same pairs, output/T39_a2_jensen_identity.csv gives E[mean_i] = -0.9229
and E[var_i] = 3.5748. Under (A2) these must satisfy -2*E[mean] = E[var]; they
give 1.8458 against 3.5748, so the variance side exceeds the mean side by a factor
of 1.937. A single multiplicative inflation of var_i by w reconciles both
departures: the level gap implies w = 1.937, and the slope implies
w = 0.5/0.2595 = 1.927, agreeing to 0.5 percent. Predicted slope at w = 1.937 is
-0.2582 against the observed -0.2595.

That inflation is the drift wedge of Proposition 2: the within-window variance
converges to sigma^2_i plus a drift term, so var_i measured over a long window
estimates sigma^2 plus drift rather than sigma^2. DRIFT_WEDGE is already ledgered
at 1.3460 on post windows of roughly ten cells; these untreated windows average
21.5 cells, and a longer window accumulates more drift, so the larger factor has
the direction and rough magnitude the proposition predicts.

Consequence, and it is the reason this entry matters: var_i is the wrong regressor
for the location identity, and it is the same wrong object the ledger already
rejected when Arm 2 was set aside on wrong-object grounds. ESIGMA2 = 1.3642 is
derived as minus twice the placebo mean, which is the drift-immune route. It
stands unqualified and requires no caveat in the article.

The residual finding is therefore narrower than it first appeared: normality
fails, the location identity does not, and the propositions' predictions hold on
data that violates their normality premise -- R_PRED = 0.7539 against
PLACEBO_A_R = 0.7463, a prediction derived exactly under (A2) landing within eight
thousandths where (A2) is rejected at a third of pairs.

Closing this entry requires: (1) the drift-inflation arithmetic above reproduced
in a gated script with the level and slope routes as separate assertions; (2)
sidecars and FILE_REGISTRY.csv rows for code/S34_a2_normality.R,
code/S35_jensen_control.R, output/T38, T39, T40 and output/F5, none of which were
in scope for S34 or S35 and none of which exist; (3) an article passage in the
data or diagnostics section reporting the rejection with its control, since (A2)
is currently maintained without evidence either way.

Superseded by this entry: no ledgered value. Nothing in the article cited any (A2)
diagnostic before SYNC-13, because none existed.

Status: CLOSED. See the Closure Register (SYNC-16).

## Drift-Calibration Holdout (T9)

The size-decile drift correction is estimated on held-out placebo splits and
applied out of sample, so no pair contributes to its own correction. It is then
validated on the held-out half, where the corrected placebo effect should be zero
if the subtraction removed an artifact and nothing else. These are the validation
figures.

Until SYNC-14 the article cited all of them directly from
output/T9_placebo_holdout.csv with no ledger row, which placed them outside the
dependency closure and outside the sole-authority rule. Section 4's calibration
paragraph and Section 6's bounded-tolerances subsection both depend on these
values and must cite the IDs below rather than the CSV.

| ID | Quantity | Value | Producer |
|----|----------|-------|----------|
| HOLDOUT_N | Held-out validation pairs, pooled | 8545 | code/S5R_bhat_split.R -> output/T9_placebo_holdout.csv |
| HOLDOUT_MEAN | Mean corrected placebo effect, pooled | 0.0188 (SE 0.0087) | code/S5R_bhat_split.R -> output/T9_placebo_holdout.csv |
| HOLDOUT_D3_MEAN | Mean corrected placebo effect, size decile 3 | -0.1013 | code/S5R_bhat_split.R -> output/T9_placebo_holdout.csv |
| HOLDOUT_D3_N | Validation pairs, size decile 3 | 314 | code/S5R_bhat_split.R -> output/T9_placebo_holdout.csv |
| HOLDOUT_D3_SE | Standard error, size decile 3 | 0.0591 | code/S5R_bhat_split.R -> output/T9_placebo_holdout.csv |
| HOLDOUT_D1_N | Validation pairs, size decile 1 (thinnest fold) | 19 | code/S5R_bhat_split.R -> output/T9_placebo_holdout.csv |
| HOLDOUT_D2_N | Validation pairs, size decile 2 | 94 | code/S5R_bhat_split.R -> output/T9_placebo_holdout.csv |
| HOLDOUT_D8_N | Validation pairs, size decile 8 (thickest fold) | 1365 | code/S5R_bhat_split.R -> output/T9_placebo_holdout.csv |
| HOLDOUT_MAX_ABS_EX_D3 | Largest absolute decile mean excluding decile 3 | 0.0569 | code/S5R_bhat_split.R -> output/T9_placebo_holdout.csv |

Note (three-state rule): the bounds are PASS below 0.10, PARTIAL below 0.20, FAIL
at or above 0.20, per INV-016 in meta/SUPERSEDED.md. Nine of the ten deciles
clear the first bound, and clear it with room: the largest absolute mean among
those nine is 0.0569, well inside the stricter 0.05-to-0.10 band rather than
sitting against it. Decile 3 returns -0.1013 and registers PARTIAL -- beyond
0.10, well inside 0.20, and 1.72 standard errors from zero. The pooled figure of
0.0188 clears the stricter 0.05 bound as well.

Note (binding on prose): decile 3 is reported as PARTIAL rather than absorbed
into the pooled average that would conceal it. Prose must not describe the
calibration as clearing its bound in all cells, and must not present the pooled
0.0188 without the decile that fails.

Note (resolution limit, binding on Section 6): 0.10 log points is the resolution
of the correction layer, not an incidental tolerance. Claims about size-profile
structure finer than roughly a tenth of a log point are inside the calibration
tolerance and are not supported. The fall-then-floor reading of the gradient does
not require any: GRADIENT = 0.9137 exceeds the tolerance by nearly an order of
magnitude, and the reading asserts nothing about the ordering of the quintiles
that constitute the floor.

Note (why the partition is not refined): the folds are already thin at this
resolution -- 19 validation pairs in the smallest size decile and 94 in the
second, against 1,365 in the eighth. Proposition 2(c) implies a finer partition
would remove more within-cell drift dispersion, but the correction must be
estimated on held-out placebo pairs and validated on them, and a finer partition
buys a smaller residual at the cost of a correction no held-out population is
large enough to certify. The design declines that trade; the residual drift
dispersion is carried forward rather than assumed away.

## Package Closure (SYNC-15)

`enforce.R` reports ZERO violations at commit 1678d7f, measured on a clean tree
at `origin/main` with a dirty count of 0. This is the first zero ever recorded
against the repository rather than against a mirror.

### INV-039: archive/retired_pack/ outside FILE_REGISTRY.csv (CLOSED)
Both fixes were applied, and they were never alternatives.

The instance: 77 rows enumerated from `git ls-files archive/retired_pack/` and
appended with status ARCHIVED, so check (d)'s registry-driven half can now see
the directory.

The class: check (d) was additionally made structural, so any path under
`archive/` is a forbidden input to a BUILT output whether or not it is enrolled.
Fixtures `tests/fixtures/check_d_pass.R` and `check_d_fail.R` prove it
discriminates.

Also closed in passing: `output/canonical_facts.md`, a 288-byte tombstone reading
"superseded by meta/canonical_facts.md", was registered BUILT -- which asserts it
is citable as the source of a number. Moved to
`archive/retired_2026-07-29/canonical_facts.md` and recoded ARCHIVED.

Status: CLOSED.

### INV-042: check (d) matched basenames, not paths (CLOSED)
Closing INV-039 broke check (d), and the breakage is worth recording because it
is the third instance of one pattern.

Check (d) reduced each registry path to `basename()` and grepped script text for
that string. Sound only while no archived file shared a basename with a live one.
Enrolling `archive/retired_pack/` created 77 such collisions at a stroke. The
visible consequence: `ITPDE_total.rds` became "archived" by name, so check (d)
flagged `S1R_ppml_untreated.R` and `S8R_ge_propagation.R` -- the foundation of the
estimation chain -- for loading `data/ITPDE_total.rds`, a live input. Five false
positives, on correct code, from a correct fix to a different defect.

Fixed by comparing full registry paths. Fixtures
`tests/fixtures/check_d_itpde_pass.R` and `check_d_itpde_fail.R` differ only in
path and share a basename, so they discriminate exactly this defect.

Related: `data/ITPDE_total.rds` had no registry row of its own, though seven rows
named it as an input and the only row carrying that basename was the archived
pack copy. Now enrolled as ANCHOR.

The pattern, three times over: INV-038 recorded a check that could not fire
because it read the wrong column; INV-039 a check that could not fire because the
objects it would forbid were never enrolled; INV-042 a check that fired wrongly
because it compared the wrong thing. In each case the instrument reported a
number that did not describe what it claimed to.

Status: CLOSED.

### INV-043: a violation count was published from a stale mirror (CLOSED)
Task S40 ran `enforce.R` in `/groups/m-larch/bt307958/REBUILD_V2` -- 133 dirty
files, several commits behind HEAD -- and wrote the resulting count of 7 into
`README.md` and `MANIFEST.txt`. INV-038 names that same directory as the reason
every enforce result ever produced described a mirror rather than the repository.

Two of those seven were stale-file artifacts: `T39_a2_jensen_identity.csv` at
origin hashes to `7906ff4def77...`, exactly its sidecar value, while the mirror
held a different file. Five were the INV-042 false positives. The true count on a
clean tree was zero once both were resolved.

Fixed structurally rather than by instruction. `enforce.R` now halts before any
check unless `git rev-parse HEAD` equals `git rev-parse origin/main` and the tree
is clean excluding `data/`, printing both SHAs and the dirty count. An explicit
`--allow-dirty` flag overrides it and prints a banner stating the result does not
describe `origin/main` and must not be published.

Status: CLOSED.

### INV-040: T29 z column answers the wrong question (CLOSED)
Item (2) is closed: every sidecar now carries `PRODUCER_SHA256`, a field the
original format lacked, so the producing script's version is pinned. Fourteen
sidecar hashes were independently recomputed from bytes at origin during
drafting; all fourteen matched.

Items (1) and (3) remain: T29 regenerated with both `mc_se_mc` and
`sd_single_dataset` columns, and the MOMPOW_IDENT_* values re-derived from the
regenerated table. Until then the correction is a ledger note rather than a
column, and the T29 z column must never be cited.

Status: CLOSED. See the Closure Register (SYNC-16).

### Appendix constants (Remark 4)
`article/a2_constants.tex` is generated by `code/S42_a2_constants.R`, which parses
`MOMPOW_IDENT_MIN_Z`, `MOMPOW_IDENT_MAX_Z`, `A2_EXKURT` and `A2_EXKURT_CONTROL`
from this ledger at run time and emits four macros. Remark 4 previously stated
those four values as typed literals, which is the body convention; the appendix
convention is generated macros, so that an appendix value cannot go stale when its
ledger row moves. Check (f) caught it.

Note: `meta/a2_constants.tex.sidecar` carries no SHA256 for the file it describes,
because check (e) scans `output/` and `data/` only and a hash there would not be
verified. The producer hash is recorded. This is a known gap, not an oversight;
`article/prop_constants.tex` has no sidecar at all.

### Remaining open items
- INV-040 items (1) and (3): regenerate T29 with both columns.
- INV-041: reproduce the drift-inflation arithmetic in a gated script before any
  of it is cited in the article.
- CAV-005: `code/S13b_matching_sensitivity.R` still carries the pre-INV-038 status
  SUPERSEDED, which no check examines. Making it enforceable means ARCHIVED, and
  under INV-038's own definition that means moving the file under `archive/`.
  Undecided.

None of the three blocks submission. None affects a reported number.
## Closure Register (SYNC-16)

Every investigation opened in this project is closed. `enforce.R` reports zero
violations on a clean tree at `origin/main`, measured with the preflight that
halts on a dirty or behind-origin tree. This section states the final status of
each item and supersedes any heading elsewhere in this file that still reads
otherwise.

### INV-040: T29 z column answers the wrong question (CLOSED)
All three closing conditions are met.

(1) `output/T29_moment_power.csv` now carries both definitions side by side:
`mc_se_mc`, the Monte Carlo precision of the simulation's estimate of the mean
difference, and `sd_single_dataset`, the sampling standard deviation of the
statistic within one realization. The `z` column is computed from the second,
which is the identification-relevant quantity. Gate A1 confirmed cell by cell
that the corrected z equals the previous z divided by sqrt(reps), so nothing
other than the definition changed.

(2) Every sidecar carries `PRODUCER_SHA256`. Fourteen sidecar hashes were
independently recomputed from bytes at origin during drafting and all fourteen
matched.

(3) The regenerated table reproduces the ledgered values exactly: minimum over
kappa_u > 0 cells 2.96, maximum 11.44, the kappa_u = 1.0 / w-share 0.50 cell 5.83,
and design-effect-50 maximum 1.62. Those figures were derived arithmetically
during drafting from the uncorrected table; the gated run confirms them. The
correction is now a column in the artifact rather than a note in the ledger, and
MOMPOW_IDENT_* may be cited without the caveat.

Class: wrong-object, instance 9, and the only instance in which the wrong object
was specified rather than substituted. The executor implemented the specification
exactly.

Status: CLOSED.

### INV-041: (A2) normality rejected; location identity survives (CLOSED)
The drift-inflation reconciliation, entered at SYNC-13 as DERIVED, NOT GATED, is
reproduced in `code/S43_drift_inflation.R` -> `output/T41_drift_inflation.csv`
with three halting gates. Realised values, against the drafting figures:

| Quantity | Gated | Drafting |
|----------|-------|----------|
| E[mean_log_eta] | -0.9229 | -0.9229 |
| E[var_log_eta] | 3.5748 | 3.5748 |
| w_level | 1.9367 | 1.937 |
| w_slope | 1.9265 | 1.927 |
| Control C disattenuated slope | -0.5454 | -0.5454 |
| Predicted slope at w_level | -0.2582 | -0.2582 |
| Observed disattenuated slope | -0.2595 | -0.2595 |

Gates: B1, the two routes agree to 0.53 percent against a 5 percent bound; B2,
Control C's disattenuated slope lies 0.045 from the -0.5 imposed by construction,
against a 0.10 bound; B3, the predicted slope agrees with the observed to 0.0014,
against a 0.01 bound.

B2 is the load-bearing gate. It establishes that the disattenuation recovers a
known answer on a panel where the identity holds by construction, which is what
licenses reading the correction on the real panel at all.

The substantive finding stands as recorded at SYNC-13 and may now be cited:
normality of the within-pair log gaps is rejected, the location identity is not,
and the apparent slope departure is the Proposition 2 drift wedge entering
through a contaminated regressor. ESIGMA2 = 1.3642 is derived by the drift-immune
mean route and requires no caveat.

Status: CLOSED.

### CAV-005: register hygiene (RESOLVED)
`code/S13b_matching_sensitivity.R` carried the pre-INV-038 status SUPERSEDED, a
value check (d) does not examine. INV-038 defines ARCHIVED as dead and moved under
`archive/`, so the file was moved to
`archive/retired_2026-07-29/S13b_matching_sensitivity.R` and its row recoded
ARCHIVED. No row in `meta/FILE_REGISTRY.csv` carries status SUPERSEDED. The file
is retained for audit; its defect is documented in `meta/SUPERSEDED.md`.

The other two CAV-005 items stand as documented: the INV-023 identifier is used by
two entries, of which the one in this file governs, and the INV series is split
across this file (INV-027 onward) and `meta/SUPERSEDED.md` (INV-010 to INV-026).

Status: RESOLVED.

### Article constants
`article/a2_constants.tex` is generated by `code/S42_a2_constants.R`, which parses
seven values from this ledger at run time and emits one macro each:
`\MomPowMinZ`, `\MomPowMaxZ`, `\AtwoExKurt`, `\AtwoExKurtControl`,
`\HoldoutDThreeMean`, `\HoldoutDThreeN`, `\HoldoutMaxAbsExDThree`. Gates assert
that every ID is found, that each emitted value round-trips against the ledger,
and that exactly seven macros are defined.

Four serve Remark 4 in the propositions appendix, where check (f) forbids typed
literals. Three serve Section 6, which is body text and where check (f) does not
apply; macros are used there anyway, because a hardcoded number in the body is the
same defect as one in the appendix and differs only in whether an automated check
happens to look at it.

Any change to one of those seven ledger rows must be followed by re-running the
generator. The article will otherwise carry a stale value that no check reports.

### The pattern worth carrying forward
Four investigations in this project concerned a verification instrument rather
than a number: INV-038, a check that could not fire because it read a column name
that did not exist; INV-039, a check that could not fire because the objects it
would forbid were never enrolled; INV-042, a check that fired wrongly because it
compared basenames rather than paths; INV-043, a check that ran against a stale
mirror and whose result was published as though it described the repository. In
each case the instrument returned a number that did not describe what it claimed
to, and in three of the four the number was reassuring.

No reported quantity was affected by any of them. Every one was found by asking
what an instrument had actually measured rather than what it reported.

### Standing conditions
- The ledger is sole authority. Where it and any file under `output/` disagree,
  the ledger governs and the disagreement is recorded, not reconciled silently.
- `enforce.R` halts unless HEAD equals `origin/main` and the tree is clean apart
  from `data/`. A count obtained under `--allow-dirty` must not be published.
- Work under `/scratch`; `/groups` has produced write failures that were never
  reproduced under diagnosis.
- Every article number carries either a ledger ID in a fact-comment or a generated
  macro. Sections 7 and 8 inherit this and are not exempt.

Status: register closed. Sections 7 and 8 are the remaining work.
