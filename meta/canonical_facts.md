# Canonical Facts Ledger

Generated: 2026-07-27 (SYNC-6)
Amended: 2026-07-29 (SYNC-7: gradient producer + Definition-B gradient, Jensen/reliability refresh, TW_MEAN rounding, anchor-table correction, INV-037 opened)
Status: OPEN (INV-033, INV-037; V1c adjudication pending)

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

Note (producer): the previous entry cited gates/X5_size_cohort.R -> gates/T3_gradient_cohorts.csv. No gates/ directory exists in this tree; the path was dangling. The value was also obtainable from output/T12_N4_gradient.csv, but that file is SUPERSEDED in FILE_REGISTRY.csv (SYNC-4) and a BUILT ledger entry must not depend on it. T27_gradient_B.csv reproduces every T12_N4_gradient column byte-identically under gates G3-G5 and is BUILT; it is the canonical producer for all five IDs above.

Note (partition): quintiles are as.integer(cut(rank(pre_trade), breaks = 5, labels = FALSE)); n = 837/836/836/836/837. Per-quintile SE is sd/sqrt(n); spread SE is sqrt(se_Q1^2 + se_Q5^2), the convention that reproduces T10R_reconciliation.csv Q1_Q5_spread se_fixed exactly (gate G7). GRADIENT_B_SHARE carries no SE: it is a ratio of two spreads and its sampling distribution is not established.

Note (shape - binding on prose): the profile is NOT monotone. Q4 = -0.0664 (SE 0.0369) lies below Q5 = -0.0583 (SE 0.0277); the Q4-Q5 difference is -0.0081 (SE 0.0462, t = -0.18). Q5 differs from zero at the 5 percent level (t = -2.11); Q4 does not (t = -1.80). Prose must state fall-then-floor, not monotone decline, and must not describe the largest pairs as statistically indistinguishable from zero. This is the shape Prop (iii) of the theory section predicts; a smoothly monotone negative profile would falsify it.

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

## Jensen/Reliability Parameters (SYNC-6)

Derived from Proposition 1 using placebo moments. SYNC-6 correction: E[sigma^2] = -2*PLACEBO_A_MEAN (Prop 1a), NOT PLACEBO_A_SD^2.

| ID | Quantity | Value | Formula | Producer |
|----|----------|-------|---------|----------|
| ESIGMA2 | E[sigma^2] | 1.3642 | -2 * PLACEBO_A_MEAN | code/S26_prop_verification.R -> output/T25_prop_verification.csv |
| SIGMA | sigma | 1.1680 | sqrt(ESIGMA2) | code/S26_prop_verification.R |
| VAR_SIGMA2 | Var(sigma^2) | 4.1773 | 4*(Var(theta_A) - ESIGMA2/T_post) | code/S26_prop_verification.R |
| T_H_PLACEBO | Mean half-length (placebo) | 5.46 | Measured from split-half | code/S24_reliability.R (PLACEBO_TH) |
| R_PRED | Predicted reliability | 0.8068 | (V/4)/((V/4) + ESIGMA2/T_h) | code/S26_prop_verification.R |
| R_GAP | R_pred - R_observed | 0.0605 | R_PRED - PLACEBO_A_R | code/S26_prop_verification.R |
| VAR_ETA | Var(eta) | 2.9126 | exp(ESIGMA2) - 1 | code/S26_prop_verification.R |

Note: values above are sourced from output/T25_prop_verification.csv and match article/prop_constants.tex (\PropRpred, \PropRgap, \PropVsigmasq). The earlier entries 0.7862 / 0.0398 / 3.6772 were stale and are superseded; they predate the S26 correction that sources Var(sigma^2) from T_post rather than T_h.

Note: V1c consistency check: |R_GAP| = 0.0605, which EXCEEDS the 0.05 bound recorded in earlier versions of this note. This is recorded as a documented miss, not a pass, and the bound has not been restated. The proposition predicts observed reliability to within six hundredths with no fitted parameter; main.tex section 4 already reports it that way ("predicts a reliability of 0.81 against the 0.75 observed"). ADJUDICATION PENDING (author): either restate the V1c bound with a stated rationale, or carry the miss as reported.

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

Note: this table now reports what output/T23_anchor.csv contains. The previous Definition-A placebo entry (-0.6821, n=15683) is the T22 split-half qualifying figure and was attributed here to T23, which does not contain it. Two producers report Definition-A placebo on two populations: T23 on the full S5R$placebo set (n=17200, mean -0.68798, SD 1.11867) and T22 on the split-half qualifying subset (n=15683, mean -0.6821, SD 1.0814). PLACEBO_A_MEAN in the Reliability section above remains the T22 figure and is unchanged. See INV-037.

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

Status: CLOSED.

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

Status: CLOSED.

### INV-033: Pseudo-population definition unreconciled (OPEN)
Three pseudo-population counts exist: 5,169 / 4,244 / 3,387. Arm C null variance depends on which definition is used. Non-blocking: SD_true is reported as an interval [0.74, 1.48].

Status: OPEN.

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

Supersedes placebo portion of INV-033.

Status: CLOSED.

### INV-037: T23 vs T22 Definition-A placebo, dual producer (OPEN)
Two committed producers report Definition-A placebo moments on two different populations:
- T23_anchor.csv: n=17200, mean -0.68798, SD 1.11867 (full S5R$placebo)
- T22_reliability.csv: n=15683, mean -0.6821, SD 1.0814 (split-half qualifying subset)

Both are correct for their stated population; the defect was that the Anchor Table above quoted the T22 figure under a T23 attribution. That is corrected. What remains open is which population the anchor table should report, and whether T23's placebo cells need a STALE/DO-NOT-CITE header.

Section 4 of main.tex handles this correctly in prose: paragraph 2 uses the T22 figures with n=15683 stated, paragraph 6 and Table tab:correction use the T23 figures with n=17200 stated. No article edit is required by this entry.

Section 5 must not cite T23 placebo columns.

Status: OPEN. Blocked on author decision (recompute T23 placebo from T22's per-pair file, or mark T23 placebo cells stale).

### INV-035: Placebo reliability reported under wrong definition (CLOSED)
S24_reliability.R v1 reported placebo mean -0.2072, SD 0.8244, which match T12_N2 exactly. These are Definition D values (theta_B from S5R$placebo), not Definition A as specified.

Definition A: theta_A(pair) = mean over post cells of [log(trade) - log(y_hat_0)]
Definition D: theta_D = theta_B - b_hat (bias-corrected)

Corrected values under Definition A (S24_reliability.R v2):
- Treated: mean=-0.2548, SD=1.6318, r=0.9243 (n=4120 qualifying)
- Placebo: mean=-0.6821, SD=1.0814, r=0.7463 (n=15683 qualifying)

Wrong-object class, instance 8.

Status: CLOSED.
