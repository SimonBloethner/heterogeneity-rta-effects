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

## Toolchain Requirements (J4a)

The H3 RNG gate uses bitwise `identical()` on doubles. This is sensitive to:
- R version (RNG algorithm)
- data.table version (row ordering in some operations)

**Required versions:**
- R version: 4.4.1
- data.table version: 1.16.4

**IMPORTANT:** R/4.5.3 does NOT have data.table in the system library on Festus.
Use `module load R/4.4.1` for all X5 operations.

The provenance stamp in `data/X5_rng_reference.rds` records:
- R_version: version string of R used to create reference
- data_table_version: version of data.table package

X5_size_cohort.R prints warnings if running versions differ from reference.

## X5 Bootstrap Path (H3 RNG Gate)

X5_size_cohort.R includes an H3 gate that verifies bootstrap CI values match a
frozen reference, ensuring the RNG stream is unchanged across code modifications.

### Reference Artefact
- `data/X5_rng_reference.rds` is a versioned artefact shipped with the repository
- Contains: pearson_ci, spearman_ci, quintile_ci_low, quintile_ci_high, provenance
- Provenance includes: source_sha, created, R_version, data_table_version, seed
- SHA256: (regenerate after proper reference creation)

### Path Resolution (J1)
X5_size_cohort.R resolves the reference path as follows:
1. If `X5_RNG_REFERENCE_PATH` env var is set, use that path
2. Otherwise, use **relative path**: `../data/X5_rng_reference.rds` from script location

This means X5 can run from ANY clone location without hardcoded cluster paths.

### Bootstrap from Clean Checkout
1. Clone the repository anywhere
2. The reference file `data/X5_rng_reference.rds` is already in the repository
3. Run `Rscript code/X5_size_cohort.R` - it finds `../data/X5_rng_reference.rds`
4. H3 gate verifies against the reference

### Regenerating the Reference (J2)
If the reference must be regenerated (e.g., after intentional RNG changes):
1. Delete existing references (scratch and gates)
2. Run X5_size_cohort.R with H3 gate temporarily disabled to produce X5_results.rds
3. Run X5_freeze_reference.R **with --force="reason"**
   - Example: `Rscript X5_freeze_reference.R --force="Upgraded to R 4.5"`
   - Without --force, the script REFUSES to overwrite
   - The reason is logged in the provenance stamp
4. Run Z0_assemble_package.R to copy to data/
5. Restore H3 gate, verify it passes
6. Commit new reference with updated SHA256

### Stage 4: Exhibit Generation
12. Q4_exhibit_pack.R -> Q4_exhibits.rds
13. build_exhibit_pack.R -> output/

## Quick Path

If intermediate data files are provided (W1_pop_canon.rds, G2c_results.RData, etc.),
skip directly to Stage 4:

```bash
module load R/4.4.1
Rscript code/build_exhibit_pack.R
```

## SLURM Submission

For cluster execution:

```bash
sbatch --partition=normal --time=01:00:00 --wrap="module load R/4.4.1 && Rscript code/build_exhibit_pack.R"
```
