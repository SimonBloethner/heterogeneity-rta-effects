# Script Execution Order

## Dependencies

The analysis proceeds in stages. Each stage depends on outputs from previous stages.

### Input Data
- N0_data.rds - Main dataset (provided)
- N0_pair_trade.rds - Pair trade data (provided)
- N0_rta_pairs.rds - RTA identifiers (provided)

### Stage 1: Core Estimation
1. G2c_placebo.R -> G2c_results.RData
2. S1_population_reconciliation.R -> W1_pop_canon.rds
3. N2_deconv.R -> deconvolution estimates

### Stage 2: Validation Gates
4. O5_verdict.R -> O5_verdict.rds
5. P4_injection.R -> P4_results.rds
6. T3_variance_identity.R -> variance check
7. PROP_NUM_v3.R -> proposition verification

### Stage 3: Sensitivity Analysis
8. X1_corrected_LN_anchor_v2.R -> X1_results.rds
9. X2_residual_tail_v5.R -> X2_results.rds
10. X3_peryear_ratio.R -> X3_results.rds
11. X5_size_cohort.R -> X5_results.rds

### Stage 4: Exhibit Generation
12. Q4_exhibit_pack.R -> Q4_exhibits.rds
13. build_exhibit_pack.R -> output/

## Quick Path

If intermediate data files are provided (W1_pop_canon.rds, G2c_results.RData, etc.), 
skip directly to Stage 4:

```bash
Rscript code/build_exhibit_pack.R
```

## SLURM Submission

For cluster execution:

```bash
sbatch --partition=normal --time=01:00:00 --wrap="module load R && Rscript code/build_exhibit_pack.R"
```
