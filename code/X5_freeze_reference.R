#!/usr/bin/env Rscript
# X5_freeze_reference.R: Create write-once RNG reference for H3 gate
# This script must be run ONCE before X5_size_cohort.R can execute.
# It extracts bootstrap CI values and freezes them as the H3 reference.

cat("========================================================================\n")
cat("X5_FREEZE_REFERENCE: Creating H3 RNG reference\n")
cat("========================================================================\n\n")

suppressPackageStartupMessages({
    library(digest)
})

# -----------------------------------------------------------------------------
# PATHS
# -----------------------------------------------------------------------------
SOURCE_PATH <- "/scratch/bt307958/X5_results.rds"
REFERENCE_PATH <- "/scratch/bt307958/X5_rng_reference.rds"

cat("Source:    ", SOURCE_PATH, "\n")
cat("Reference: ", REFERENCE_PATH, "\n\n")

# -----------------------------------------------------------------------------
# WRITE-ONCE GUARD: If reference exists, print SHA256 and exit cleanly
# -----------------------------------------------------------------------------
if (file.exists(REFERENCE_PATH)) {
    cat("Reference file already exists. Write-once policy: NOT overwriting.\n\n")
    existing_sha <- digest(file = REFERENCE_PATH, algo = "sha256")
    cat("Existing reference SHA256:", existing_sha, "\n")
    cat("\nTo regenerate, manually delete:", REFERENCE_PATH, "\n")
    cat("Exiting with status 0.\n")
    quit(status = 0)
}

# -----------------------------------------------------------------------------
# SOURCE FILE GUARD
# -----------------------------------------------------------------------------
if (!file.exists(SOURCE_PATH)) {
    stop("FATAL: Source file does not exist: ", SOURCE_PATH,
         "\nRun X5_size_cohort.R first to generate it (with H3 gate disabled).")
}

# -----------------------------------------------------------------------------
# EXTRACT CI VALUES
# -----------------------------------------------------------------------------
cat("Reading source file...\n")
x5 <- readRDS(SOURCE_PATH)

# Extract with the structure X5_results.rds uses
pearson_ci <- x5$correlations$pearson_ci
spearman_ci <- x5$correlations$spearman_ci
quintile_ci_low <- x5$quintile_ci$low
quintile_ci_high <- x5$quintile_ci$high

cat("Extracted values:\n")
cat("  pearson_ci:      ", as.numeric(pearson_ci), "\n")
cat("  spearman_ci:     ", as.numeric(spearman_ci), "\n")
cat("  quintile_ci_low: ", as.numeric(quintile_ci_low), "\n")
cat("  quintile_ci_high:", as.numeric(quintile_ci_high), "\n\n")

# -----------------------------------------------------------------------------
# BUILD REFERENCE WITH FLAT NAMES (as X5 expects)
# -----------------------------------------------------------------------------
reference <- list(
    pearson_ci = pearson_ci,
    spearman_ci = spearman_ci,
    quintile_ci_low = quintile_ci_low,
    quintile_ci_high = quintile_ci_high
)

# -----------------------------------------------------------------------------
# WRITE REFERENCE
# -----------------------------------------------------------------------------
cat("Writing reference file...\n")
saveRDS(reference, REFERENCE_PATH)

# -----------------------------------------------------------------------------
# VERIFY: Assert names match what X5 reads
# -----------------------------------------------------------------------------
cat("Verifying written reference...\n")
written <- readRDS(REFERENCE_PATH)
expected_names <- c("pearson_ci", "spearman_ci", "quintile_ci_low", "quintile_ci_high")
actual_names <- names(written)

if (!setequal(actual_names, expected_names)) {
    stop("FATAL: Reference names mismatch!\n",
         "  Expected: ", paste(expected_names, collapse = ", "), "\n",
         "  Actual:   ", paste(actual_names, collapse = ", "))
}
cat("  Names match expected: PASS\n")

# Verify values round-trip correctly
stopifnot(identical(written$pearson_ci, pearson_ci))
stopifnot(identical(written$spearman_ci, spearman_ci))
stopifnot(identical(written$quintile_ci_low, quintile_ci_low))
stopifnot(identical(written$quintile_ci_high, quintile_ci_high))
cat("  Values round-trip:    PASS\n\n")

# -----------------------------------------------------------------------------
# PRINT SHA256
# -----------------------------------------------------------------------------
ref_sha <- digest(file = REFERENCE_PATH, algo = "sha256")
cat("========================================================================\n")
cat("REFERENCE CREATED SUCCESSFULLY\n")
cat("========================================================================\n")
cat("Path:   ", REFERENCE_PATH, "\n")
cat("SHA256: ", ref_sha, "\n")
cat("\nThis file is now frozen. X5_size_cohort.R can execute.\n")
