# Canonical Facts: REBUILD_V2 Fixed Chain

Generated: 2026-07-26
Pipeline: S1R → S3R → S4R → S5R → S6R → S7R → S8R → S9R → S10R

## Configuration

| Parameter | Value | Source |
|-----------|-------|--------|
| Estimator | Untreated-only PPML | S1R_ppml_untreated.R |
| Anticipation window | Symmetric ±1 year | adopt-1 to adopt+1 excluded |
| Placebo split | 50/50 train/validate | S5R_bhat_split.R |
| Matching | Size decile | pre_trade deciles |
| Bootstrap draws | 500 | Seed 20260719 |
| GE sigma | 5 | Standard elasticity |

## Population

| Quantity | Value | Notes |
|----------|-------|-------|
| N_pairs (BASELINE) | 4,182 | Matches exhibit pack exactly |
| Total observations | 794,720 | Non-domestic, trade > 0 |
| Unique pairs | 46,803 | All years 1988-2019 |

### Population Rules Applied
- R1: Single switchers (one 0→1 RTA transition)
- R2: Adoption year in [1991, 2016]
- R3: Usable counterfactual for ≥1 post cell
- R4: ≥3 pre years (year < adopt-1, trade > 0)
- R5: ≥3 post years (year > adopt+1, trade > 0)

## Key Quantities with Bootstrap SEs

| Quantity | Estimate | SE | Pack | Deviation/SE |
|----------|----------|-----|------|--------------|
| mean(θ_D) | 0.2473 | 0.0235 | 0.214 | +1.42 |
| SD(θ_D) | 1.5614 | 0.0271 | — | — |
| SD(θ_true) | **[1.4754, 1.5054]** | — | — | — |
| TW_mean | 0.3043 | 0.0920 | — | — |

**SD(θ_true) identified set:** Lower=1.4754 (se_total: includes counterfactual
uncertainty), Upper=1.5054 (se_B only). See INV-019, S17_se_cf.R.
| Q1-Q5 spread | 0.9137 | 0.0809 | 0.465 | +5.55 |
| Spec spread (B-FULL) | 1.3073 | — | 1.307 | +0.0003 |

## Variance Decomposition

```
Var(θ̂_B)  = 2.4961
E[SE²_B]  = 0.1717
─────────────────────
Var(θ)    = 2.3244  (deconvolved)
SD(θ)     = 1.5246  (SE: 0.0279)
```

## Size Gradient (Pre-Trade Quintiles)

| Quintile | N | mean(θ_D) | SE |
|----------|---|-----------|-----|
| Q1 (smallest) | 837 | +0.855 | 0.076 |
| Q2 | 836 | +0.374 | 0.060 |
| Q3 | 836 | +0.131 | 0.049 |
| Q4 | 836 | -0.066 | 0.037 |
| Q5 (largest) | 837 | -0.058 | 0.028 |

**Gradient decomposition:**
- Q1-Q5 spread: 0.914
- From θ_B: 0.683 (75%)
- From b̂: 0.231 (25%)

## Specification Spread

| Spec | Published | REBUILD | Diff |
|------|-----------|---------|------|
| (B) Bilateral | 1.402 | 1.4020 | -0.0000 |
| (C) Country | 0.922 | 0.9222 | +0.0002 |
| (CY) Country-Year | 0.411 | 0.4108 | -0.0002 |
| (FULL) Full | 0.095 | 0.0947 | -0.0003 |

Spread (B - FULL): 1.3073 (pack: 1.307)

## GE Propagation (σ=5)

| Quantile | Trade Change |
|----------|--------------|
| q10 | -73.3% |
| q25 | -37.1% |
| q50 | +24.5% |
| q75 | +164.9% |
| q90 | +626.9% |

Range (1+q90)/(1+q10): 27.25
Normal baseline range: 49.59

## Gate Status

| Gate | Script | Status |
|------|--------|--------|
| G1 monotone census | S6R | PASS |
| G2 no duplicates | S6R | PASS |
| G3 size matches | S6R | PASS |
| G4 per-decile | S5R | PARTIAL (decile 3: 0.101) |
| A plumbing | S8R | PASS |
| B market clearing | S8R | PASS |
| C convergence | S8R | PASS |
| A monotonic | S9R | PASS |

## Reconciliation Assessment

**Matching pack:**
- N_pairs: 4,182 = 4,182 ✓
- Spec spread: 1.3073 ≈ 1.307 ✓

**Deviating from pack:**
- mean(θ_D): 0.247 vs 0.214 (+1.4 SE, not significant at 2 SE)
- Q1-Q5 spread: 0.914 vs 0.465 (+5.5 SE, significant)

The Q1-Q5 spread deviation is the primary finding: the fixed chain shows
a larger size gradient (0.914 vs 0.465), with 75% attributable to the
θ_B component and 25% to the b̂ correction.

## File Provenance

| File | SHA256 |
|------|--------|
| S1R_ppml.rds | (see sidecar) |
| S3R_theta.rds | (see sidecar) |
| S5R_bhat.rds | (see sidecar) |
| S6R_population.rds | eda7571e24d1... |
| S7R_deconv.rds | c1d55117cb7e... |
| S8R_ge.rds | 155d6a0376a4... |
| S9R_spec.rds | d7c6c98a551b... |

## SE-CF Analysis (Counterfactual Uncertainty)

| Component | Value | Share |
|-----------|-------|-------|
| mean(se_B²) | 0.1717 | 65.8% |
| mean(sd_cf²) | 0.0894 | 34.2% |
| mean(se_total²) | 0.2612 | 100% |

**Decision:** mean(sd_cf²) = 0.0894 < 0.10 × Var(θ_D) = 0.2438
→ Counterfactual uncertainty is **IMMATERIAL**

Producer: code/S17_se_cf.R (B=180 draws, seed 20260719)

## Invalidation Register

- INV-016: G4 gate changed to three-state (SPECIFICATION CHANGE)
- INV-017: S1 pooled estimator superseded by S1R untreated-only
- INV-018: 42-pair discrepancy closed (pack matches at 4,182)
- INV-019: SE-CF counterfactual uncertainty documented (IMMATERIAL)
- INV-020: README T1 window-mixing defect closed

## Caveats Register

- CAV-001: SE-CF B=180/200 (chunks 06, 11 failed)
- CAV-002: B1 test used S5R_bhat.rds (W1_pop_canon.rds lacks theta_B)

See meta/SUPERSEDED.md for full register.
