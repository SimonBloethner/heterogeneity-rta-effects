# Gate Verification Documentation

## Purpose

Gates are numerical checkpoints that verify the analysis produces expected results 
within tolerance bounds. All gates must pass for the replication to be considered successful.

## Gate Definitions

### Anchor Gates (Population Verification)

**ANCHOR_N**: n = 4182 pairs
- Source: W1_pop_canon.rds
- Tolerance: exact
- Meaning: Canonical population size after all filters

**ANCHOR_MEAN**: mean(theta_D) = 0.2138
- Source: W1_pop_canon.rds
- Tolerance: +/- 0.002
- Meaning: Average corrected RTA effect

**ANCHOR_SD**: sd(theta_D) = 0.5950
- Source: W1_pop_canon.rds
- Tolerance: +/- 0.005
- Meaning: Standard deviation of effects (before deconvolution)

### T1 Gate (Correction Path)

**T1_NAIVE**: naive mean = -0.52
- Source: X1_results.rds
- Tolerance: +/- 0.01
- Meaning: Pre-correction estimate (MR bias present)

**T1_PLACEBO**: placebo mean = -0.7121
- Source: G2c_results.RData
- Tolerance: +/- 0.01
- Meaning: Mean effect for non-switcher placebo pairs (18,055 pairs)

### T4 Gate (FE Reconciliation)

**T4_UNWEIGHTED**: [1.402, 0.922, 0.411, 0.095]
- Source: X1_results.rds
- Tolerance: +/- 0.005 each element
- Meaning: Unweighted specification row values

### T5 Gate (Injection Test)

**T5_INJECTION**: contains (tau=0.40, SE=0.06) row
- Source: Q4_exhibits.rds / V3c output
- Tolerance: presence check
- Meaning: V3c mis-windowed estimator validation
- Detail: True tau=0.40, Recovered tau=0.35, SE=0.06

### T6 Gate (GE Propagation)

**T6_EXP_IQR**: exp(IQR) in [1.30, 1.42]
- Source: O5_verdict.rds
- Tolerance: range check
- Actual: 1.33
- Meaning: Exponentiated interquartile range of deconvolved distribution
- Calculation: exp(p75 - p25) where p75=0.437, p25=0.148

## Verification Script

```r
# Load data
W1 <- readRDS("data/W1_pop_canon.rds")
load("data/G2c_results.RData")
O5 <- readRDS("data/O5_verdict.rds")

# Check gates
cat("ANCHOR_N:", nrow(W1), "== 4182?", nrow(W1) == 4182, "\n")
cat("ANCHOR_MEAN:", mean(W1$theta_D), "in [0.2118, 0.2158]?\n")
cat("ANCHOR_SD:", sd(W1$theta_D), "in [0.5900, 0.6000]?\n")
cat("T1_PLACEBO:", G2c_results$mean_placebo, "in [-0.72, -0.70]?\n")
cat("T6_EXP_IQR:", exp(O5$percentiles["p75"] - O5$percentiles["p25"]), "in [1.30, 1.42]?\n")
```

## Troubleshooting

If gates fail:
1. Verify input data checksums match MANIFEST.txt
2. Check R version >= 4.3.0
3. Ensure fixest package version >= 0.13.0
4. Re-run from clean intermediate files
