# Canonical Facts Ledger

Generated: 2026-07-24
Source: build_exhibit_pack.R

## Headline Statistics

| ID | Quantity | Value | Source |
|----|----------|-------|--------|
| MEAN_THETA | Mean theta_D (canonical) | 0.2138 [0.2098, 0.2178] | W1_pop_canon.rds |
| TW_MEAN | Trade-weighted mean theta_D | 0.1412 | X5_results.rds |
| SD_RAW | SD theta_D (raw) | 0.5950 [0.5850, 0.6050] | W1_pop_canon.rds |
| SD_THETA_IDSET | SD theta (identified set) | [0.39, 0.46] | Prop 3 noise attribution endpoints |
| SD_THETA_039_CI | Bootstrap CI of lower endpoint | [0.336, 0.440] | Variance decomposition |
| DECONV_K2 | Deconvolved mixture K=2 | w=[0.135,0.865], m=[0.131,0.220], s=[0.858,0.071], SD=0.324 | W2_results.rds (SHA 72e405aa...) |
| DECONV_K3 | Deconvolved mixture K=3 | w=[0.204,0.031,0.765], m=[0.451,-1.095,0.199], s=[0.369,0.989,0.049], SD=0.306 | W2_results.rds (SHA f9fe84cd...) |
| DECONV_K3_SLIVER | Sliver component | w=0.031, m=-1.10, s=0.989, n_eff=130 | W2_fixes.rds |
| MIX_GMM_OBSERVED | Observed GMM (pre-deconv) | 0.27*N(0.04,1.06) + 0.73*N(0.28,0.22) | 2-component fit |
| QSKEW | Quantile skewness (K=3) | 2.99 [1.73, 4.43] | W2_fixes.rds qskew |
| MSKEW_RAW_OBSERVED | Moment skewness (raw theta_D) | -2.6066 | W1_pop_canon.rds |
| MSKEW_K3 | Moment skewness (K=3 deconv) | -1.97 | W2_fixes.rds; sliver-dominated, do not cite as headline |
| PLEQ0_LADDER | P(theta <= t) at t=-0.5,-0.25,0,0.25 | [0.0686, 0.1043, 0.1719, 0.4907] | W1_pop_canon.rds |
| PLEQ0_LADDER_EST | P(theta <= 0) estimates | raw=0.172, EB=0.099 [0.076,0.120], O5=0.086, K2=0.060, K3=0.050, ex_sliver=0.023 | Ordering: raw > EB > O5 > K2 > K3 > ex_sliver |
| GRADIENT_Q1 | Mean theta_D quintile 1 (smallest trade) | 0.5615 [0.50, 0.62] | X5_results.rds |
| GRADIENT_Q5 | Mean theta_D quintile 5 (largest trade) | 0.0968 [0.06, 0.14] | X5_results.rds |
| SPEARMAN_SIZE | Spearman(log_pre_mean, theta_D) | -0.4998 [-0.5269, -0.4741] | X5_results.rds |
| GE_Q10 | GE trade cost change q10 | 0.1115 | W4_results.rds |
| GE_Q50 | GE trade cost change q50 | 0.2208 [0.20, 0.24] | W4_results.rds |
| GE_Q90 | GE trade cost change q90 | 0.5104 | W4_results.rds |
| RANGE_1090 | (1+q90)/(1+q10) deconvolved | 1.3589 [1.30, 1.42] | W4_results.rds |
| RANGE_NORMAL | (1+q90)/(1+q10) normal | 2.2488 [2.0, 2.3] | W4_results.rds |
| PLOSS_EMPIRICAL | Tail probability loss (empirical vs fitted) | 0.0258 | Empirical vs N(mu,sigma) |
| PLOSS_NORMALARM | Tail probability loss (W3 normal arm) | 0.239 | W3 normal-comparison arm |
| THETA_A_CANONICAL | Definition A (canonical) | mean=-0.2738, SD=1.6641 | G2a_results.RData (r=1.0 vs fresh) |
| THETA_B_CANONICAL | Definition B (canonical) | mean=0.0854, SD=1.5819 | NAIVE_GROUND_TRUTH.rds |
| PLACEBO_A_CANONICAL | Placebo Definition A | mean=-0.7121, SD=1.1165, n=18055 | NAIVE_GROUND_TRUTH.rds (anchors Prop 1) |
| NAIVE_SD_PLACEBO | SD placebo effects | 1.1165 | G2c_results.RData$sd_placebo |
| NAIVE_SD_CANONICAL | SD theta_D (W1 canonical) | 0.5950 | sd(W1$theta_D), n=4182 |
| SPLITHALF_A_FRESH | Split-half r (fresh theta_A) | 0.9720 | NAIVE_GROUND_TRUTH.rds (ledgered convention) |
| SPLITHALF_PLACEBO | Split-half correlation (placebo) | 0.62 | G2c_results.RData |
| RHO_VOL | Volatility ratio rho | 0.83 [0.80, 0.86] | P4_results.rds |
| SNR_VAR_RATIO | Mean signal-to-noise ratio (kappa) | 1.7529 | Var(theta_hat)/E[s^2] |
| SNR_PAIR_RANGE | Pair-level SNR 10-90 percentile | [0.12, 10.73] | W1_pop_canon.rds |
| SPEC_SPREAD | Specification estimates (B,C,CY,FULL) | [1.402, 0.922, 0.411, 0.095] | X1_results.rds |
| KS_MIXTURE_FIT | KS statistic: empirical vs mixture | D=0.1403, n=4182, p<0.001 | Convolved mixture test |
| IDENT_KS_PROP3 | KS statistic: Prop 3 identity | D=0.00111, p=0.919 | Deconvolution identity test |
| N_PAIRS | Canonical pair count | 4182 | W1_pop_canon.rds |


## Pending Verification

| ID | Quantity | Value | Source | Status |
|-----|----------|-------|--------|--------|
| CONS_X_MEAN | Conservative mean exp(theta) | 1.6651 | R3_results.rds$conservative$X_mean | PENDING - This is mean(exp(theta)) in levels, NOT an SD; incomparable to NAIVE_SD values |
| O1_THETA_A | O1 theta_A (former mean_A) | mean=-0.5168, SD=0.9875 | O1_switcher_theta.rds | REGISTER - r=0.667 vs fresh (unidentified lineage) |
| O1_THETA_B | O1 theta_B (former mean_B) | mean=-0.0805, SD=0.5905 | O1_switcher_theta.rds | REGISTER - r=0.677 vs fresh (unidentified lineage) |
| M1_THETA_B | M1 theta_hat_B | mean=0.1019, SD=1.5194 | M1_results.RData | CHECK - r=0.976 vs fresh (between 0.9 and 0.99) |

## Gate Verification

| Gate | Formula | Value | Bound | Status |
|------|---------|-------|-------|--------|
| Anchor_n | nrow(W1) | 4182 | [4182, 4182] | PASS |
| Anchor_mean | mean(theta_D) | 0.2138 | [0.2118, 0.2158] | PASS |
| Anchor_sd | sd(theta_D) | 0.5950 | [0.5900, 0.6000] | PASS |
| T6_q50 | tc_q50[MED,5,A] | 0.2208 | [0.20, 0.24] | PASS |
| T6_RANGE_1090 | (1+q90)/(1+q10) arm A | 1.3589 | [1.30, 1.42] | PASS |
| T6_RANGE_NORMAL | (1+q90)/(1+q10) arm B | 2.2488 | [2.0, 2.3] | PASS |
| T3_Q1 | mean(theta_D\|Q1) | 0.5615 | [0.50, 0.62] | PASS |
| T3_Q5 | mean(theta_D\|Q5) | 0.0968 | [0.06, 0.14] | PASS |
| T3_Spearman | cor(log_pre_mean,theta_D,spearman) | -0.4998 | [-0.56, -0.44] | PASS |
| T1_placebo | mean(placebo_effects) | -0.7121 | [-0.72, -0.70] | PASS |

All 10 gates PASSED.

## Data Coverage Notes

### A4 Adoption Year Coverage
The canonical population (W1, n=4182) contains pairs with RTA adoptions from
1992-2015 only (24 years). The raw trade data (N0) contains 32 adoption years
(1988-2019), but 8 years have zero pairs in W1:

| Years | Pairs in N0 | Pairs in W1 | Reason |
|-------|-------------|-------------|--------|
| 1988-1991 | 1841 | 0 | Insufficient post-adoption observations |
| 2016-2019 | 860 | 0 | Insufficient post-adoption observations |

A4's 24 rows represent COMPLETE coverage of all adoption years present
in the canonical population.

### T3b Cohort Analysis
| Cohort | N | Mean theta_D | SD |
|--------|---|--------------|-----|
| pre_2008 | 1938 | 0.2887 | 0.3401 |
| post_2008 | 2244 | 0.1491 | 0.7423 |

Pre-2008 adoptions show higher mean effect (0.29) with lower variance.
Post-2008 adoptions show lower mean effect (0.15) with higher variance.

### A0 Anchor Table Reference
See A0_anchor_table.csv for year-by-year Step-1 estimates (u, mu, sigma, H, E_S, empirical, omega).
2019 verification: E_S=7011 (target: 7009+/-20), omega=1.058 (target: 1.058+/-0.01).
All omega in [0.948, 1.091] subset of [0.94, 1.10].
