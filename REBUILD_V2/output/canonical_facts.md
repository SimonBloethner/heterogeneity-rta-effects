# REBUILD_V2 Canonical Facts Ledger

Generated: 2026-07-25
Pipeline: S1-S13 (manifest-first rebuild + PATCH P1-P3)

## PATCH APPLIED (2026-07-25)

**Critical corrections:**
- P1: Fixed BASELINE definition (4,875 → 4,639) using anticipation exclusion
- P2: **GRADIENT REVERSED** — fake quintiles replaced with real equal quintiles
- P3: Matching sensitivity tested (8 configs), chosen: `decile_tercile`

## Headline Statistics

| ID | Quantity | REBUILD Value | Canonical Value | Source |
|----|----------|---------------|-----------------|--------|
| RTA_FULL | RTA coefficient (FULL spec) | 0.0947 | 0.095 | S1_ppml.rds |
| N_PAIRS | Single-switcher pairs | 6,339 | 4,182 | S2_pairs.rds |
| N_BASELINE | BASELINE population | 4,639 | 4,182 | S6_population.rds |
| MEAN_THETA_D | Mean θ_D (BASELINE) | +0.044 | 0.214 | T5b_theta_summary.csv |
| SD_THETA_D | SD θ_D (BASELINE) | 0.677 | 0.595 | T5b_theta_summary.csv |
| SD_THETA_TRUE | Deconvolved SD(θ) | 0.539 | [0.39, 0.46] | S7_deconv.rds |
| Q1_Q5_SPREAD | Quintile gradient | **+0.105** | -0.50 | T3b_size_gradient_fixed.csv |
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
| Full (6,339) | 0.501 | 0.229 | 0.272 | 0.521 | 0.54 |
| BASELINE (4,639) | 0.478 | 0.188 | 0.290 | 0.539 | 0.61 |

## Size Gradient — CORRECTED (T3b_size_gradient_fixed.csv)

**CRITICAL: Gradient direction REVERSED from original S10 output**

| Quintile | N | Mean θ_D | Mean θ_B | Mean b̂ | SD θ_D |
|----------|---|----------|----------|--------|--------|
| Q1 (smallest) | 927 | **+0.136** | -0.116 | -0.251 | 0.77 |
| Q2 | 928 | +0.054 | -0.159 | -0.213 | 0.82 |
| Q3 | 928 | +0.013 | -0.128 | -0.140 | 0.68 |
| Q4 | 928 | -0.014 | -0.123 | -0.109 | 0.61 |
| Q5 (largest) | 928 | **+0.031** | -0.025 | -0.056 | 0.41 |

**Q1-Q5 spread: +0.105** (smaller pairs have HIGHER effects)

### Why the gradient reversed:

1. **Old quintiles were fake**: ceiling(size_decile/2) created bins of 34, 284, 844, 1406, 2071
2. **New quintiles are real**: equal bins within BASELINE (927-928 each)
3. **The old "Q1" (N=34) was an extreme tail**, not representative of small pairs

## Matching Sensitivity (T6_matching_sensitivity.csv)

8 configurations tested: 2 matching cells × 4 seeds

| Matching Cell | Q1-Q5 Spread Range | Mean | SD |
|--------------|-------------------|------|-----|
| decile_only | [0.68, 1.42] | 1.11 | 0.32 |
| **decile_tercile** | [0.95, 1.93] | 1.22 | 0.46 |

**Chosen: decile_tercile** (finer matching, author preference)

Note: 1 cell per config has NA due to sparse placebo pool in that (decile, tercile) combination.

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

3. **SIZE GRADIENT DIRECTION**: **REBUILD +0.105 vs canonical -0.50**
   - Original S10 output (-0.435) was WRONG due to fake quintiles
   - Corrected gradient shows small pairs have HIGHER effects
   - This contradicts the canonical paper's finding

4. **GE range**: REBUILD 2.70 vs canonical 1.36 — REBUILD uses raw θ_D,
   canonical used deconvolved mixture which has lower variance

5. **Cohort effect**: Both show early > late, but REBUILD finds late adopters slightly negative

## File Registry (Post-PATCH)

| Stage | File | Status |
|-------|------|--------|
| S1-S10 | Original pipeline | BUILT |
| S11 | T5b_theta_summary.csv | BUILT (supersedes T5) |
| S12 | T3b_size_gradient_fixed.csv | BUILT (supersedes T3) |
| S13 | T6_matching_sensitivity.csv | BUILT |

### Superseded Files (retained per R9)
- T5_theta_summary.csv (used n=4,875, wrong BASELINE)
- T3_size_gradient.csv (used fake quintiles)
