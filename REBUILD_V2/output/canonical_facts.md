# REBUILD_V2 Canonical Facts Ledger

Generated: 2026-07-25
Pipeline: S1-S9 (manifest-first rebuild)

## Headline Statistics

| ID | Quantity | REBUILD Value | Canonical Value | Source |
|----|----------|---------------|-----------------|--------|
| RTA_FULL | RTA coefficient (FULL spec) | 0.0947 | 0.095 | S1_ppml.rds |
| N_PAIRS | Single-switcher pairs | 6,339 | 4,182 | S2_pairs.rds |
| N_BASELINE | BASELINE population | 4,639 | 4,182 | S6_population.rds |
| MEAN_THETA_D | Mean θ_D (BASELINE) | 0.044 | 0.214 | S5_bhat.rds |
| SD_THETA_D | SD θ_D (BASELINE) | 0.677 | 0.595 | S5_bhat.rds |
| SD_THETA_TRUE | Deconvolved SD(θ) | 0.539 | [0.39, 0.46] | S7_deconv.rds |
| Q1_Q5_SPREAD | Quintile gradient | -0.435 | -0.50 | S7_deconv.rds |
| COHORT_EARLY | Mean θ_D (early adopters) | +0.181 | +0.29 | S7_deconv.rds |
| COHORT_LATE | Mean θ_D (late adopters) | -0.033 | +0.15 | S7_deconv.rds |

## Specification Spread

| Specification | FEs | REBUILD | Published |
|---------------|-----|---------|-----------|
| (B) Bilateral | pair | 1.4020 | 1.402 |
| (C) Country | exp+imp | 0.9222 | 0.922 |
| (CY) Country-Year | exp×yr+imp×yr | 0.4108 | 0.411 |
| (FULL) Full | pair+exp×yr+imp×yr | 0.0947 | 0.095 |

Spread (B - FULL): 1.31 (93% reduction from adding FEs)

## GE Propagation (σ=5)

| Quantity | REBUILD | Canonical | Note |
|----------|---------|-----------|------|
| q10 | -0.388 | +0.112 | |
| q50 | +0.193 | +0.221 | |
| q90 | +0.650 | +0.510 | |
| Range (1+q90)/(1+q10) | **2.70** | **1.36** | Higher variance → wider range |

Note: REBUILD uses raw θ_D distribution (SD=0.66), canonical used deconvolved K=3 mixture (SD=0.31).

## Variance Decomposition

| Population | Var(θ̂) | E[se²] | Var(θ) | SD(θ) | Reliability |
|------------|--------|--------|--------|-------|-------------|
| Full (6,109) | 0.501 | 0.229 | 0.272 | 0.521 | 0.54 |
| BASELINE (4,639) | 0.478 | 0.188 | 0.290 | 0.539 | 0.61 |

## Size Gradient (BASELINE, by quintile)

| Quintile | N | Mean θ_D | SD θ_D |
|----------|---|----------|--------|
| Q1 (smallest) | 34 | -0.329 | 1.03 |
| Q2 | 284 | -0.145 | 0.94 |
| Q3 | 844 | -0.036 | 1.03 |
| Q4 | 1,406 | +0.048 | 0.71 |
| Q5 (largest) | 2,071 | +0.106 | 0.33 |

Q1-Q5 spread: -0.435 (smaller pairs have lower effects)

## Cohort Analysis

| Cohort | N | Mean θ_D | SD θ_D |
|--------|---|----------|--------|
| Early (≤2004) | 1,663 | +0.181 | 0.24 |
| Late (>2004) | 2,976 | -0.033 | 0.82 |

Early adopters show higher, more homogeneous effects.

## Key Differences from Canonical

1. **Population definition**: REBUILD includes pairs with 3+ pre/post years (4,639), 
   canonical W1 has 4,182 (different selection criteria)

2. **Mean θ_D**: REBUILD +0.044 vs canonical +0.214 — difference likely in b̂ correction method

3. **GE range**: REBUILD 2.70 vs canonical 1.36 — REBUILD uses raw θ_D, 
   canonical used deconvolved mixture which has lower variance

4. **Cohort effect**: Both show early > late, but REBUILD finds late adopters slightly negative

## File Registry

| Stage | File | SHA256 (first 8) |
|-------|------|------------------|
| S1 | S1_ppml.rds | ... |
| S2 | S2_pairs.rds | ... |
| S3 | S3_theta.rds | ... |
| S4 | S4_placebo.rds | ... |
| S5 | S5_bhat.rds | ... |
| S6 | S6_population.rds | ... |
| S7 | S7_deconv.rds | ... |
| S8 | S8_ge.rds | fe28f6c2 |
| S9 | S9_spec.rds | 4585ede8 |

