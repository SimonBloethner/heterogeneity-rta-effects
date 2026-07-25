#!/usr/bin/env Rscript
# X5_freeze_reference.R: Create write-once RNG reference for H3 gate
# This script must be run ONCE before X5_size_cohort.R can execute.
# It extracts bootstrap CI values and freezes them as the H3 reference.
#
# WRITE-ONCE POLICY: If reference exists, this script REFUSES to overwrite.
# To regenerate, you MUST use --force="<reason>" and the reason is logged.
#
# K1 NOTE: source_sha 5027a655...cfc46 is the pre-patch X5_results.rds,
# byte-identical across runs (saveRDS zeroes gzip mtime). Reference is valid.

cat("========================================================================\n")
cat("X5_FREEZE_REFERENCE: Creating H3 RNG reference\n")
cat("========================================================================\n\n")

suppressPackageStartupMessages({
    library(digest)
    library(data.table)  # J4(a): Need version for provenance
})

# -----------------------------------------------------------------------------
# J2: PARSE --force FLAG
# -----------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
force_arg <- grep("^--force=", args, value = TRUE)

FORCE_MODE <- FALSE
FORCE_REASON <- NULL

if (length(force_arg) > 0) {
    FORCE_REASON <- sub("^--force=", "", force_arg[1])
    if (nzchar(FORCE_REASON)) {
        FORCE_MODE <- TRUE
        cat("*** FORCE MODE ENABLED ***\n")
        cat("Reason:", FORCE_REASON, "\n\n")
    } else {
        stop("FATAL: --force requires a reason. Usage: --force=\"reason for regeneration\"")
    }
}

# -----------------------------------------------------------------------------
# PATHS
# -----------------------------------------------------------------------------
SOURCE_PATH <- "/scratch/bt307958/X5_results.rds"
# Output to BOTH scratch (for immediate use) and gates/ (for assembly into repo)
REFERENCE_PATH_SCRATCH <- "/scratch/bt307958/X5_rng_reference.rds"
REFERENCE_PATH_GATES <- "/groups/m-larch/bt307958/gates/X5_rng_reference.rds"

cat("Source:          ", SOURCE_PATH, "\n")
cat("Reference (scratch):", REFERENCE_PATH_SCRATCH, "\n")
cat("Reference (gates):  ", REFERENCE_PATH_GATES, "\n\n")

# -----------------------------------------------------------------------------
# WRITE-ONCE GUARD: If reference exists, REFUSE unless --force
# -----------------------------------------------------------------------------
existing_scratch <- file.exists(REFERENCE_PATH_SCRATCH)
existing_gates <- file.exists(REFERENCE_PATH_GATES)

if (existing_scratch || existing_gates) {
    cat("========================================================================\n")
    cat("WRITE-ONCE GUARD TRIGGERED\n")
    cat("========================================================================\n\n")

    if (existing_scratch) {
        existing_sha <- digest(file = REFERENCE_PATH_SCRATCH, algo = "sha256")
        cat("Reference exists at scratch:\n")
        cat("  Path:  ", REFERENCE_PATH_SCRATCH, "\n")
        cat("  SHA256:", existing_sha, "\n\n")
    }
    if (existing_gates) {
        existing_sha <- digest(file = REFERENCE_PATH_GATES, algo = "sha256")
        cat("Reference exists at gates:\n")
        cat("  Path:  ", REFERENCE_PATH_GATES, "\n")
        cat("  SHA256:", existing_sha, "\n\n")
    }

    if (!FORCE_MODE) {
        cat("REFUSING TO OVERWRITE. Write-once policy in effect.\n\n")
        cat("To regenerate the reference, you must:\n")
        cat("  1. Provide --force=\"<reason>\" argument\n")
        cat("  2. The reason will be logged in the provenance stamp\n\n")
        cat("Example:\n")
        cat("  Rscript X5_freeze_reference.R --force=\"RNG algorithm changed in R 4.5\"\n\n")
        stop("HALTING: Use --force to override write-once guard.")
    } else {
        cat("FORCE MODE: Proceeding with overwrite.\n")
        cat("Reason logged:", FORCE_REASON, "\n\n")
    }
}

# -----------------------------------------------------------------------------
# SOURCE FILE GUARD
# -----------------------------------------------------------------------------
if (!file.exists(SOURCE_PATH)) {
    stop("FATAL: Source file does not exist: ", SOURCE_PATH,
         "\nX5_results.rds must exist from a prior run.")
}

# -----------------------------------------------------------------------------
# EXTRACT CI VALUES
# -----------------------------------------------------------------------------
cat("Reading source file...\n")
x5 <- readRDS(SOURCE_PATH)
source_sha <- digest(file = SOURCE_PATH, algo = "sha256")

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
# BUILD REFERENCE WITH PROVENANCE (J4a: includes data.table version)
# -----------------------------------------------------------------------------
reference <- list(
    # CI values
    pearson_ci = pearson_ci,
    spearman_ci = spearman_ci,
    quintile_ci_low = quintile_ci_low,
    quintile_ci_high = quintile_ci_high,
    # Provenance stamp (J4a: includes toolchain versions)
    provenance = list(
        source_sha = source_sha,
        created = Sys.time(),
        R_version = R.version.string,
        data_table_version = as.character(packageVersion("data.table")),
        seed = 20260721L,
        force_reason = FORCE_REASON  # NULL if not forced
    )
)

cat("Provenance stamp:\n")
cat("  source_sha:        ", source_sha, "\n")
cat("  created:           ", format(reference$provenance$created), "\n")
cat("  R_version:         ", reference$provenance$R_version, "\n")
cat("  data_table_version:", reference$provenance$data_table_version, "\n")
cat("  seed:              ", reference$provenance$seed, "\n")
if (!is.null(FORCE_REASON)) {
    cat("  force_reason:      ", FORCE_REASON, "\n")
}
cat("\n")

# -----------------------------------------------------------------------------
# WRITE REFERENCE TO BOTH LOCATIONS
# -----------------------------------------------------------------------------
cat("Writing reference files...\n")
saveRDS(reference, REFERENCE_PATH_SCRATCH)
cat("  Written:", REFERENCE_PATH_SCRATCH, "\n")

# Ensure gates directory exists (it should - this is a sanity check)
if (!dir.exists(dirname(REFERENCE_PATH_GATES))) {
    stop("FATAL: Gates directory does not exist: ", dirname(REFERENCE_PATH_GATES))
}
saveRDS(reference, REFERENCE_PATH_GATES)
cat("  Written:", REFERENCE_PATH_GATES, "\n\n")

# -----------------------------------------------------------------------------
# VERIFY: Assert names match what X5 reads
# -----------------------------------------------------------------------------
cat("Verifying written reference...\n")
written <- readRDS(REFERENCE_PATH_SCRATCH)
expected_ci_names <- c("pearson_ci", "spearman_ci", "quintile_ci_low", "quintile_ci_high")

for (nm in expected_ci_names) {
    if (is.null(written[[nm]])) {
        stop("FATAL: Missing CI field: ", nm)
    }
}
cat("  All CI fields present: PASS\n")

if (is.null(written$provenance)) {
    stop("FATAL: Missing provenance stamp")
}
cat("  Provenance stamp present: PASS\n")

# Verify values round-trip correctly
stopifnot(identical(written$pearson_ci, pearson_ci))
stopifnot(identical(written$spearman_ci, spearman_ci))
stopifnot(identical(written$quintile_ci_low, quintile_ci_low))
stopifnot(identical(written$quintile_ci_high, quintile_ci_high))
cat("  Values round-trip: PASS\n\n")

# Verify both files match
sha_scratch <- digest(file = REFERENCE_PATH_SCRATCH, algo = "sha256")
sha_gates <- digest(file = REFERENCE_PATH_GATES, algo = "sha256")
stopifnot(sha_scratch == sha_gates)
cat("  Both files identical: PASS\n\n")

# -----------------------------------------------------------------------------
# PRINT SHA256
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("REFERENCE CREATED SUCCESSFULLY\n")
cat("========================================================================\n")
cat("SHA256:", sha_scratch, "\n")
cat("\nPaths:\n")
cat("  ", REFERENCE_PATH_SCRATCH, "\n")
cat("  ", REFERENCE_PATH_GATES, "\n")
cat("\nThis file is now frozen. X5_size_cohort.R can execute.\n")
if (!is.null(FORCE_REASON)) {
    cat("\n*** NOTE: This reference was created with --force ***\n")
    cat("Reason:", FORCE_REASON, "\n")
}
