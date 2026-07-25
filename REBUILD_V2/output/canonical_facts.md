# REBUILD_V2 Canonical Facts Ledger

Generated: 2026-07-25
Pipeline: S1-S14 (manifest-first rebuild + PATCH P1-P3, F1-F5, S14)

## PATCH APPLIED (2026-07-25)

**Corrections:**
- P1: Fixed BASELINE definition (4,875 → 4,639) using anticipation exclusion
- P2: Fixed fake quintiles → real equal quintiles
- P3: Matching sensitivity tested (8 configs) — **MATCHING CELL NOT YET SELECTED**
- F2: T6 superseded by T6b with corrected quintiles (gate verified)
- S14: **PLACEBO VALIDITY GATE FAILED** — all b̂-dependent quantities marked PROVISIONAL

## PLACEBO VALIDITY (T7_placebo_validity.csv)

**INV-015**: Placebo validity gate (`PLACEBO_MEAN_THRESHOLD = 0.05`) defined in `gates_lib_v2.R`
but **NEVER INVOKED** in S4_placebo.R or S5_bhat.R pipeline.

### Part A: Validity Gate Results

| Seed | Matching Cell | n | mean(θ_B) | |mean| | Threshold | Result |
|------|---------------|---|-----------|-------|-----------|--------|
| 20260719 | decile_only | 6,339 | -0.1405 | 0.1405 | 0.05 | **FAIL** |
| 42 | decile_only | 6,339 | -0.1417 | 0.1417 | 0.05 | **FAIL** |
| 999 | decile_only | 6,339 | -0.1436 | 0.1436 | 0.05 | **FAIL** |
| 12345 | decile_only | 6,339 | ~-0.14 | ~0.14 | 0.05 | **FAIL** |

**Configurations passing: 0 of 4**

### Part B: Mechanism

The placebo mean θ_B ≈ -0.14 is **systematic**, not seed-dependent. All seeds produce
nearly identical means (within 0.003 of each other). This indicates a fundamental bias
in the placebo construction, not sampling variation.

The mechanism: placebos drawn from never-treated pairs have systematically lower
θ_B than the treated population, violating the assumption that E[θ_B|placebo] = 0.

### Branch Taken: C2

**The placebo design is INVALID. b̂ cannot be reliably estimated.**

All b̂-dependent quantities below are marked **PROVISIONAL**.

## Headline Statistics

| ID | Quantity | REBUILD Value | Canonical Value | Source | Status |
|----|----------|---------------|-----------------|--------|--------|
| RTA_FULL | RTA coefficient (FULL spec) | 0.0947 | 0.095 | S1_ppml.rds | |
| N_PAIRS | Single-switcher pairs | 6,339 | 4,182 | S2_pairs.rds | |
| N_BASELINE | BASELINE population | 4,639 | 4,182 | S6_population.rds | |
| MEAN_THETA_D | Mean θ_D (BASELINE) | +0.044 | 0.214 | T5b_theta_summary.csv | **PROVISIONAL** |
| SD_THETA_D | SD θ_D (BASELINE) | 0.677 | 0.595 | T5b_theta_summary.csv | **PROVISIONAL** |
| SD_THETA_TRUE | Deconvolved SD(θ) | 0.539 | [0.39, 0.46] | S7_deconv.rds | **PROVISIONAL** |
| Q1_Q5_SPREAD | Quintile gradient (θ_D) | +0.105 | +0.465 | T3b_size_gradient_fixed.csv | **PROVISIONAL** |
| COHORT_EARLY | Mean θ_D (early adopters) | +0.181 | +0.29 | S7_deconv.rds | **PROVISIONAL** |
| COHORT_LATE | Mean θ_D (late adopters) | -0.033 | +0.15 | S7_deconv.rds | **PROVISIONAL** |

## Uncorrected Results (θ_B only, no bias correction)

Since b̂ cannot be reliably estimated, report uncorrected θ_B:

| Quantity | Value | Note |
|----------|-------|------|
| BASELINE n | 4,639 | |
| mean(θ_B) | -0.110 | Raw, uncorrected |
| SD(θ_B) | 0.70 | |
| Q1-Q5 spread (θ_B) | -0.091 | Negative: large pairs have higher raw effects |

## Specification Spread

| Specification | FEs | REBUILD | Published |
|---------------|-----|---------|-----------|
| (B) Bilateral | pair | 1.4020 | 1.402 |
| (C) Country | exp+imp | 0.9222 | 0.922 |
| (CY) Country-Year | exp×yr+imp×yr | 0.4108 | 0.411 |
| (FULL) Full | pair+exp×yr+imp×yr | 0.0947 | 0.095 |

Spread (B - FULL): 1.31 (93% reduction from adding FEs)

## GE Propagation (σ=5) — PROVISIONAL

| Quantity | REBUILD | Canonical | Note | Status |
|----------|---------|-----------|------|--------|
| q10 | -0.388 | +0.112 | | **PROVISIONAL** |
| q50 | +0.193 | +0.221 | | **PROVISIONAL** |
| q90 | +0.650 | +0.510 | | **PROVISIONAL** |
| Range (1+q90)/(1+q10) | 2.70 | 1.36 | | **PROVISIONAL** |

Note: GE propagation depends on θ_D distribution, which depends on b̂.

## Variance Decomposition

| Population | Var(θ̂) | E[se²] | Var(θ) | SD(θ) | Reliability |
|------------|--------|--------|--------|-------|-------------|
| Full (6,339) | 0.501 | 0.229 | 0.272 | 0.521 | 0.54 |
| BASELINE (4,639) | 0.478 | 0.188 | 0.290 | 0.539 | 0.61 |

## Size Gradient — PROVISIONAL

| Quintile | N | Mean θ_D | Mean θ_B | Mean b̂ | SD θ_D | Status |
|----------|---|----------|----------|--------|--------|--------|
| Q1 (smallest) | 927 | +0.136 | -0.116 | -0.251 | 0.77 | **PROVISIONAL** |
| Q2 | 928 | +0.054 | -0.159 | -0.213 | 0.82 | **PROVISIONAL** |
| Q3 | 928 | +0.013 | -0.128 | -0.140 | 0.68 | **PROVISIONAL** |
| Q4 | 928 | -0.014 | -0.123 | -0.109 | 0.61 | **PROVISIONAL** |
| Q5 (largest) | 928 | +0.031 | -0.025 | -0.056 | 0.41 | **PROVISIONAL** |

**θ_B gradient (uncorrected): Q1-Q5 = -0.091** (large pairs have higher raw effects)

The positive θ_D gradient (+0.105) comes entirely from the b̂ correction, which
is itself PROVISIONAL due to placebo invalidity.

## Cohort Analysis — PROVISIONAL

| Cohort | N | Mean θ_D | SD θ_D | Status |
|--------|---|----------|--------|--------|
| Early (≤2004) | 1,663 | +0.181 | 0.24 | **PROVISIONAL** |
| Late (>2004) | 2,976 | -0.033 | 0.82 | **PROVISIONAL** |

## Key Differences from Canonical

1. **Population definition**: REBUILD includes pairs with 3+ pre/post years (4,639),
   canonical W1 has 4,182 (different selection criteria)

2. **Placebo validity**: REBUILD finds placebo mean θ_B = -0.14, far exceeding
   the validity threshold of 0.05. This invalidates the b̂ correction.

3. **Size gradient (θ_B)**: REBUILD -0.091 shows large pairs have higher raw effects.
   The corrected θ_D gradient (+0.105) depends on invalid b̂.

4. **GE range**: All GE quantities are PROVISIONAL pending valid bias correction.

## What Could Not Be Established

1. Valid bias correction (b̂) — placebo validity gate fails
2. Bias-corrected θ_D distribution — depends on b̂
3. Deconvolved true effect distribution — depends on θ_D
4. GE propagation welfare effects — depends on θ_D distribution
5. Sign of size gradient in bias-corrected effects — depends on b̂

## Invalidation Register

| ID | Description | Detected | Impact |
|----|-------------|----------|--------|
| INV-015 | Placebo validity gate defined but never invoked | S14 | All b̂-dependent quantities PROVISIONAL |

## File Registry (Post-S14)

| Stage | File | Status |
|-------|------|--------|
| S1-S10 | Original pipeline | BUILT |
| S11 | T5b_theta_summary.csv | BUILT (supersedes T5) |
| S12 | T3b_size_gradient_fixed.csv | BUILT (supersedes T3) |
| S13b | T6b_matching_sensitivity.csv | BUILT (supersedes T6) |
| S14 | T7_placebo_validity.csv | BUILT |

### Superseded Files (retained per R9)
- T5_theta_summary.csv (used n=4,875, wrong BASELINE)
- T3_size_gradient.csv (used fake quintiles)
- T6_matching_sensitivity.csv (used wrong quintiles)
