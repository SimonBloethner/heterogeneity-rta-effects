# Replication Package: Heterogeneity in RTA Trade Effects

## Overview
This package contains all code and data needed to replicate the analysis of heterogeneous regional trade agreement effects.

## Directory Structure

- README.md - This file
- MANIFEST.txt - SHA256 checksums of all files
- code/ - R scripts (17 files)
- data/ - Input and intermediate data (11 files)
- output/ - Final exhibits (33 files)
- docs/ - Documentation

### Code Directory
- N0_setup.R - PPML gravity model estimation (creates N0_data.rds)
- gates_lib_v2.R - Shared utility functions
- G2c_placebo.R - Placebo test (Gate G2c)
- O5_verdict.R - Deconvolution verdict
- P4_injection.R - Injection test for volatility
- Q4_exhibit_pack.R - Build exhibit tables
- S1_population_reconciliation.R - Population reconciliation
- T3_variance_identity.R - Variance identity check
- N2_deconv.R - Deconvolution estimator
- W4_ge_propagation.R - GE propagation analysis
- X1_corrected_LN_anchor_v2.R - Corrected LN anchor
- X2_residual_tail_v5.R - Residual tail analysis
- X3_peryear_ratio.R - Per-year ratio analysis
- X5_size_cohort.R - Size cohort analysis
- PROP_NUM_v3.R - Proposition numerical verification
- PROP_derivations_v4.R - Proposition derivations
- build_exhibit_pack.R - Final exhibit generation

### Data Directory
- ITPDE_total.rds - Raw trade panel data (16 MB) - PRIMARY INPUT
- N0_data.rds - PPML gravity output (142 MB)
- N0_pair_trade.rds - Pair-level trade data
- N0_rta_pairs.rds - RTA pair identifiers
- filtered_trade.rds - Filtered trade flows
- W1_pop_canon.rds - Canonical population (4182 pairs)
- G2c_results.RData - Placebo test results
- O5_verdict.rds - Deconvolution results
- X1_results.rds - Specification results
- Q4_exhibits.rds - Pre-built exhibits
- P4_results.rds - Volatility test results

### Output Directory
Contains the frozen exhibit pack:
- canonical_facts.md - Headline statistics with ledger IDs
- T1-T7 CSV tables with .meta.txt sidecars
- A1-A5 CSV appendix tables with .meta.txt sidecars
- F1-F3 figures (PDF + PNG at 300 DPI)
- invalidation_register.md
- MANIFEST.txt with SHA256 checksums

## Requirements

- R >= 4.3.0 (tested with R 4.5.3)
- Required packages: fixest (0.13.2+), ggplot2, dplyr, tidyr, MASS

## Quick Replication

To regenerate exhibits from intermediate data:

```bash
module load R
cd replication_package
Rscript code/build_exhibit_pack.R
```

To verify outputs:

```bash
cd output
sha256sum -c MANIFEST.txt
```

## Full Replication

Execute scripts in order:

```bash
# Stage 0: Gravity estimation (from raw trade data)
Rscript code/N0_setup.R   # Creates N0_data.rds from ITPDE_total.rds

# Stage 1: Core estimation
Rscript code/G2c_placebo.R
Rscript code/S1_population_reconciliation.R

# Stage 2: Validation gates
Rscript code/O5_verdict.R
Rscript code/P4_injection.R
Rscript code/PROP_NUM_v3.R

# Stage 3: Sensitivity analysis
Rscript code/X1_corrected_LN_anchor_v2.R
Rscript code/X2_residual_tail_v5.R
Rscript code/X3_peryear_ratio.R
Rscript code/X5_size_cohort.R

# Stage 4: Generate exhibits
Rscript code/Q4_exhibit_pack.R
Rscript code/build_exhibit_pack.R
```

## Validation Gates

All gates must pass for valid replication:

| Gate | Criterion | Expected Value |
|------|-----------|----------------|
| Anchor | n pairs | 4182 |
| Anchor | mean(theta_D) | 0.2138 +/- 0.002 |
| Anchor | sd(theta_D) | 0.5950 +/- 0.005 |
| T1 | naive mean | -0.52 +/- 0.01 |
| T1 | placebo mean | -0.71 +/- 0.01 |
| T4 | unweighted row | [1.402, 0.922, 0.411, 0.095] +/- 0.005 |
| T5 | injection row | contains (0.40, 0.06) |
| T6 | exp(IQR) | in [1.30, 1.42] |

## Expected Runtime

On a standard compute node:
- Quick replication (from intermediate data): ~5 minutes
- Full replication (from gravity output): ~50 minutes
- Complete replication (from raw trade data): ~60 minutes

## Contact

For questions about this replication package, contact the authors.
