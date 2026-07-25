#!/usr/bin/env Rscript
# X5: Size Link and Cohort Analysis
# Canonical population, Definition D only

cat("========================================================================\n")
cat("X5: SIZE LINK AND COHORT ANALYSIS\n")
cat("Start:", format(Sys.time()), "\n")
cat("========================================================================\n\n")

suppressPackageStartupMessages({
    library(data.table)
    library(digest)  # E3: portable SHA256
})

# -----------------------------------------------------------------------------
# J4(a): TOOLCHAIN VERSION CHECK
# -----------------------------------------------------------------------------
REQUIRED_R_VERSION <- "4.4.1"
REQUIRED_DT_VERSION <- "1.16.4"

running_R <- paste0(R.version$major, ".", R.version$minor)
running_DT <- as.character(packageVersion("data.table"))

cat("TOOLCHAIN:\n")
cat("  R version:         ", running_R, "\n")
cat("  data.table version:", running_DT, "\n")
cat("  Required R:        ", REQUIRED_R_VERSION, "\n")
cat("  Required data.table:", REQUIRED_DT_VERSION, "\n")

if (running_R != REQUIRED_R_VERSION) {
    cat("  WARNING: R version mismatch! H3 gate may fail due to RNG differences.\n")
}
if (running_DT != REQUIRED_DT_VERSION) {
    cat("  WARNING: data.table version mismatch! Results may differ.\n")
}
cat("\n")

# -----------------------------------------------------------------------------
# PATH CONSTANTS
# -----------------------------------------------------------------------------
OUTPUT_PATH <- "/scratch/bt307958/X5_results.rds"
# F1: Correct path determined from N0_setup.R line 118: copies to /groups/m-larch/bt307958/gates/
REPO_DATA_PATH <- "/groups/m-larch/bt307958/gates/X5_results.rds"

# -----------------------------------------------------------------------------
# J1: Reference path resolution - RELATIVE TO SCRIPT LOCATION
# Default: ../data/X5_rng_reference.rds relative to this script
# Override: X5_RNG_REFERENCE_PATH env var
# K2(a): No getwd() fallback - HALT if script location unknown
# -----------------------------------------------------------------------------
# Get script directory
script_args <- commandArgs(trailingOnly = FALSE)
script_path_arg <- grep("--file=", script_args, value = TRUE)
if (length(script_path_arg) > 0) {
    SCRIPT_PATH <- normalizePath(sub("--file=", "", script_path_arg[1]))
    SCRIPT_DIR <- dirname(SCRIPT_PATH)
} else {
    # K2(a): No fallback - interactive/source() cannot reliably detect script location
    SCRIPT_DIR <- NULL
}

REFERENCE_PATH_OVERRIDE <- Sys.getenv("X5_RNG_REFERENCE_PATH", unset = "")

if (nzchar(REFERENCE_PATH_OVERRIDE)) {
    REFERENCE_PATH <- REFERENCE_PATH_OVERRIDE
    REFERENCE_SOURCE <- "env:X5_RNG_REFERENCE_PATH"
} else if (!is.null(SCRIPT_DIR)) {
    REFERENCE_PATH <- file.path(SCRIPT_DIR, "..", "data", "X5_rng_reference.rds")
    REFERENCE_SOURCE <- "default (relative to script: ../data/)"
} else {
    stop("FATAL: Cannot determine script location for relative path resolution.\n",
         "When running interactively or via source(), set:\n",
         "  export X5_RNG_REFERENCE_PATH=/path/to/data/X5_rng_reference.rds")
}

# K2(b): Normalize path for clean logging
REFERENCE_PATH <- normalizePath(REFERENCE_PATH, mustWork = FALSE)

cat("PATHS:\n")
if (!is.null(SCRIPT_DIR)) {
    cat("  SCRIPT_DIR:    ", SCRIPT_DIR, "\n")
}
cat("  REFERENCE_PATH:", REFERENCE_PATH, "\n")
cat("  (resolved from:", REFERENCE_SOURCE, ")\n")
cat("  OUTPUT_PATH:   ", OUTPUT_PATH, "\n")
cat("  REPO_DATA_PATH:", REPO_DATA_PATH, "\n\n")

# -----------------------------------------------------------------------------
# E3: VERIFY DIGEST PACKAGE BEFORE EXPENSIVE WORK
# -----------------------------------------------------------------------------
if (!requireNamespace("digest", quietly = TRUE)) {
    stop("FATAL: digest package not available. Required for portable SHA256.")
}
cat("DIGEST PACKAGE: available: PASS\n")

# -----------------------------------------------------------------------------
# PATH GUARDS
# -----------------------------------------------------------------------------
# Literal check (original D1(d))
if (REFERENCE_PATH == OUTPUT_PATH) {
    stop("FATAL: REFERENCE_PATH and OUTPUT_PATH are identical. This is structurally forbidden.")
}
cat("PATH GUARD (literal): REFERENCE_PATH != OUTPUT_PATH: PASS\n")

# Guard: reference file must exist
if (!file.exists(REFERENCE_PATH)) {
    stop("FATAL: Reference file does not exist: ", REFERENCE_PATH,
         "\nEither:\n",
         "  1. Run X5_freeze_reference.R to create it, or\n",
         "  2. Set X5_RNG_REFERENCE_PATH env var to an existing reference file.")
}
cat("REFERENCE GUARD:", REFERENCE_PATH, "exists: PASS\n")

# E5: normalizePath check after both files exist (catches symlinks, relative paths)
# OUTPUT_PATH may not exist yet, so use mustWork=FALSE
ref_norm <- normalizePath(REFERENCE_PATH, mustWork = TRUE)
out_norm <- normalizePath(OUTPUT_PATH, mustWork = FALSE)
if (ref_norm == out_norm) {
    stop("FATAL: REFERENCE_PATH and OUTPUT_PATH resolve to same path after normalization.\n",
         "  REFERENCE_PATH: ", REFERENCE_PATH, " -> ", ref_norm, "\n",
         "  OUTPUT_PATH:    ", OUTPUT_PATH, " -> ", out_norm)
}
cat("PATH GUARD (normalized): paths differ: PASS\n\n")

# Load reference for later comparison
rng_reference <- readRDS(REFERENCE_PATH)

# H2: Print provenance stamp from reference
cat("REFERENCE PROVENANCE:\n")
if (!is.null(rng_reference$provenance)) {
    cat("  source_sha:      ", rng_reference$provenance$source_sha, "\n")
    cat("  created:         ", format(rng_reference$provenance$created), "\n")
    cat("  R_version:       ", rng_reference$provenance$R_version, "\n")
    cat("  data.table_version:", rng_reference$provenance$data_table_version, "\n")
    cat("  seed:            ", rng_reference$provenance$seed, "\n")

    # J4(a): Warn if toolchain differs from reference
    ref_R <- rng_reference$provenance$R_version
    ref_DT <- rng_reference$provenance$data_table_version
    # Extract version number from ref_R (e.g., "R version 4.4.1 (2024-06-14)" -> "4.4.1")
    ref_R_num <- if (!is.null(ref_R)) gsub("R version ([0-9.]+).*", "\\1", ref_R) else NULL
    if (!is.null(ref_R_num) && ref_R_num != running_R) {
        cat("\n  *** WARNING: R VERSION MISMATCH ***\n")
        cat("  Reference was created with:", ref_R, "\n")
        cat("  Currently running:         R version", running_R, "\n")
        cat("  H3 gate may fail due to RNG stream differences!\n")
    }
    if (!is.null(ref_DT) && nzchar(ref_DT) && ref_DT != running_DT) {
        cat("\n  *** WARNING: data.table VERSION MISMATCH ***\n")
        cat("  Reference was created with:", ref_DT, "\n")
        cat("  Currently running:        ", running_DT, "\n")
    }
} else {
    cat("  (no provenance stamp - legacy reference)\n")
}
cat("\n")

set.seed(20260721)

# -----------------------------------------------------------------------------
# STEP 0: Load data
# -----------------------------------------------------------------------------
cat("STEP 0: Loading data...\n")

# Canonical population
w1 <- as.data.table(readRDS("/scratch/bt307958/W1_pop_canon.rds"))
cat("  W1 canonical pairs:", nrow(w1), "\n")
stopifnot(nrow(w1) == 4182)

# O1 for theta_D and adoption_year
o1 <- as.data.table(readRDS("/scratch/bt307958/O1_switcher_theta.rds"))

# Merge
merged <- merge(w1[, .(pair, s_hat)], o1[, .(pair, theta_D, adoption_year, size_decile)],
                by = "pair", all.x = TRUE)
merged <- merged[!is.na(theta_D)]
cat("  Merged pairs:", nrow(merged), "\n")

# Load raw trade data to compute pre-adoption mean trade
raw_data <- as.data.table(readRDS("/scratch/bt307958/N0_data.rds"))
cat("  Raw data loaded:", nrow(raw_data), "\n")

# Pair trade for weights
pair_trade <- as.data.table(readRDS("/scratch/bt307958/N0_pair_trade.rds"))

# Merge trade weights
merged <- merge(merged, pair_trade[, .(pair, total_trade)], by = "pair", all.x = TRUE)
merged[is.na(total_trade), total_trade := 0]
merged[, trade_weight := total_trade / sum(total_trade)]

# -----------------------------------------------------------------------------
# Compute pre-adoption mean and sum trade for each pair
# -----------------------------------------------------------------------------
cat("\nComputing pre-adoption trade statistics...\n")

merged[, pre_mean_trade := NA_real_]
merged[, pre_sum_trade := NA_real_]
for (i in 1:nrow(merged)) {
    p <- merged$pair[i]
    ay <- merged$adoption_year[i]
    pre_data <- raw_data[pair == p & year < ay, trade]
    if (length(pre_data) > 0) {
        merged$pre_mean_trade[i] <- mean(pre_data, na.rm = TRUE)
        merged$pre_sum_trade[i] <- sum(pre_data, na.rm = TRUE)
    }
}

n_valid_pre <- sum(!is.na(merged$pre_mean_trade) & merged$pre_mean_trade > 0)
cat("  Pairs with valid pre-adoption trade:", n_valid_pre, "\n")

# Log pre-adoption mean
merged[, log_pre_mean := log(pre_mean_trade)]
merged_valid <- merged[!is.na(log_pre_mean) & is.finite(log_pre_mean)]
cat("  Pairs with finite log pre-mean:", nrow(merged_valid), "\n\n")

# -----------------------------------------------------------------------------
# Global assertions
# -----------------------------------------------------------------------------
cat("GLOBAL ASSERTIONS:\n")
global_mean <- mean(merged$theta_D, na.rm = TRUE)
global_tw_mean <- sum(merged$theta_D * merged$trade_weight, na.rm = TRUE)

cat(sprintf("  Mean theta_D = %.4f (target: 0.2138 ± 0.002)\n", global_mean))
stopifnot(abs(global_mean - 0.2138) <= 0.002)
cat("    PASS\n")

cat(sprintf("  TW Mean theta_D = %.4f (target: 0.1412 ± 0.003)\n", global_tw_mean))
stopifnot(abs(global_tw_mean - 0.1412) <= 0.003)
cat("    PASS\n\n")

# -----------------------------------------------------------------------------
# (a) SIZE LINK
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("(a) SIZE LINK: Correlation(theta_D, log pre-adoption mean trade)\n")
cat("========================================================================\n\n")

# Point estimates
pearson_r <- cor(merged_valid$theta_D, merged_valid$log_pre_mean, method = "pearson")
spearman_r <- cor(merged_valid$theta_D, merged_valid$log_pre_mean, method = "spearman")

cat(sprintf("Point estimates (n=%d):\n", nrow(merged_valid)))
cat(sprintf("  Pearson r: %.4f\n", pearson_r))
cat(sprintf("  Spearman rho: %.4f\n", spearman_r))

# Bootstrap CIs
n_boot <- 500
boot_pearson <- numeric(n_boot)
boot_spearman <- numeric(n_boot)

cat("\nBootstrapping 500 reps...\n")
for (b in 1:n_boot) {
    idx <- sample(nrow(merged_valid), replace = TRUE)
    boot_pearson[b] <- cor(merged_valid$theta_D[idx], merged_valid$log_pre_mean[idx], method = "pearson")
    boot_spearman[b] <- cor(merged_valid$theta_D[idx], merged_valid$log_pre_mean[idx], method = "spearman")
}

pearson_ci <- quantile(boot_pearson, c(0.025, 0.975))
spearman_ci <- quantile(boot_spearman, c(0.025, 0.975))

cat(sprintf("  Pearson 95%% CI: [%.4f, %.4f]\n", pearson_ci[1], pearson_ci[2]))
cat(sprintf("  Spearman 95%% CI: [%.4f, %.4f]\n", spearman_ci[1], spearman_ci[2]))

# Quintile analysis
cat("\nMean theta_D by pre-adoption size quintile:\n")
merged_valid[, size_quintile := cut(log_pre_mean,
                                     breaks = quantile(log_pre_mean, probs = seq(0, 1, 0.2)),
                                     labels = 1:5, include.lowest = TRUE)]

quintile_stats <- merged_valid[, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE)
), by = size_quintile][order(size_quintile)]

# Bootstrap CIs for quintile means
cat("Computing quintile bootstrap CIs...\n")
quintile_boot <- matrix(NA, n_boot, 5)
for (b in 1:n_boot) {
    idx <- sample(nrow(merged_valid), replace = TRUE)
    boot_data <- merged_valid[idx]
    boot_data[, size_quintile := cut(log_pre_mean,
                                      breaks = quantile(merged_valid$log_pre_mean, probs = seq(0, 1, 0.2)),
                                      labels = 1:5, include.lowest = TRUE)]
    boot_means <- boot_data[, mean(theta_D, na.rm = TRUE), by = size_quintile][order(size_quintile)]
    for (q in 1:5) {
        if (q <= nrow(boot_means)) {
            quintile_boot[b, q] <- boot_means$V1[q]
        }
    }
}

quintile_ci_low <- apply(quintile_boot, 2, quantile, probs = 0.025, na.rm = TRUE)
quintile_ci_high <- apply(quintile_boot, 2, quantile, probs = 0.975, na.rm = TRUE)

# -----------------------------------------------------------------------------
# H3 VERIFICATION: RNG stream preservation (moved here per D1)
# Compares against frozen reference, NOT against own output
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("H3 VERIFICATION: RNG stream preservation\n")
cat("========================================================================\n")
cat("Reference file:", REFERENCE_PATH, "\n\n")

h3_pass <- TRUE

# Check pearson_ci
if (!identical(as.numeric(pearson_ci), as.numeric(rng_reference$pearson_ci))) {
    cat("FAIL: pearson_ci mismatch\n")
    cat("  Computed:", format(as.numeric(pearson_ci), digits = 17), "\n")
    cat("  Reference:", format(as.numeric(rng_reference$pearson_ci), digits = 17), "\n")
    h3_pass <- FALSE
} else {
    cat("PASS: pearson_ci matches reference\n")
}

# Check spearman_ci
if (!identical(as.numeric(spearman_ci), as.numeric(rng_reference$spearman_ci))) {
    cat("FAIL: spearman_ci mismatch\n")
    cat("  Computed:", format(as.numeric(spearman_ci), digits = 17), "\n")
    cat("  Reference:", format(as.numeric(rng_reference$spearman_ci), digits = 17), "\n")
    h3_pass <- FALSE
} else {
    cat("PASS: spearman_ci matches reference\n")
}

# Check quintile_ci_low
if (!identical(as.numeric(quintile_ci_low), as.numeric(rng_reference$quintile_ci_low))) {
    cat("FAIL: quintile_ci_low mismatch\n")
    cat("  Computed:", format(as.numeric(quintile_ci_low), digits = 17), "\n")
    cat("  Reference:", format(as.numeric(rng_reference$quintile_ci_low), digits = 17), "\n")
    h3_pass <- FALSE
} else {
    cat("PASS: quintile_ci_low matches reference\n")
}

# Check quintile_ci_high
if (!identical(as.numeric(quintile_ci_high), as.numeric(rng_reference$quintile_ci_high))) {
    cat("FAIL: quintile_ci_high mismatch\n")
    cat("  Computed:", format(as.numeric(quintile_ci_high), digits = 17), "\n")
    cat("  Reference:", format(as.numeric(rng_reference$quintile_ci_high), digits = 17), "\n")
    h3_pass <- FALSE
} else {
    cat("PASS: quintile_ci_high matches reference\n")
}

stopifnot(h3_pass)
cat("\nH3 VERIFICATION: ALL PASS\n")

# -----------------------------------------------------------------------------
# OUTPUT: X5-1
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("X5-1: SIZE LINK TABLE\n")
cat("========================================================================\n\n")

cat("Correlations (n =", nrow(merged_valid), "):\n")
cat(sprintf("  %-12s %10s %20s\n", "Measure", "Estimate", "95% Bootstrap CI"))
cat(paste(rep("-", 45), collapse = ""), "\n")
cat(sprintf("  %-12s %10.4f [%7.4f, %7.4f]\n", "Pearson", pearson_r, pearson_ci[1], pearson_ci[2]))
cat(sprintf("  %-12s %10.4f [%7.4f, %7.4f]\n", "Spearman", spearman_r, spearman_ci[1], spearman_ci[2]))

cat("\nMean theta_D by pre-adoption size quintile:\n")
cat(sprintf("  %-10s %6s %12s %20s\n", "Quintile", "n", "Mean_theta_D", "95% Bootstrap CI"))
cat(paste(rep("-", 52), collapse = ""), "\n")
for (i in 1:nrow(quintile_stats)) {
    cat(sprintf("  %-10s %6d %12.4f [%7.4f, %7.4f]\n",
                paste0("Q", quintile_stats$size_quintile[i]),
                quintile_stats$n[i],
                quintile_stats$mean_theta_D[i],
                quintile_ci_low[i],
                quintile_ci_high[i]))
}

# -----------------------------------------------------------------------------
# PRE-PERIOD WEIGHTINGS (CHANGE 1 & 2)
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("PRE-PERIOD WEIGHTING ANALYSIS\n")
cat("========================================================================\n\n")

# Identify valid subset for pre-period weights
merged_valid_pre <- merged[!is.na(pre_sum_trade) & pre_sum_trade > 0]

# -----------------------------------------------------------------------------
# D3: POPULATION EQUIVALENCE ASSERTION
# -----------------------------------------------------------------------------
# merged_valid: pairs with finite log(pre_mean_trade), i.e., pre_mean_trade > 0
# merged_valid_pre: pairs with pre_sum_trade > 0
# These should be identical because trade > 0 filter in N0_setup.R ensures
# pre_sum > 0 iff pre_mean > 0. Assert this equivalence explicitly.
cat("D3 POPULATION EQUIVALENCE CHECK:\n")
cat(sprintf("  merged_valid rows:     %d\n", nrow(merged_valid)))
cat(sprintf("  merged_valid_pre rows: %d\n", nrow(merged_valid_pre)))
stopifnot(nrow(merged_valid_pre) == nrow(merged_valid))
cat("  Row count match: PASS\n")
stopifnot(setequal(merged_valid_pre$pair, merged_valid$pair))
cat("  Pair set equivalence: PASS\n\n")

n_full <- nrow(merged)
n_valid <- nrow(merged_valid_pre)

cat(sprintf("Population sizes:\n"))
cat(sprintf("  Full population (merged):       n = %d\n", n_full))
cat(sprintf("  Pre-period valid (merged_valid_pre): n = %d\n", n_valid))
cat(sprintf("  Difference:                     %d pairs excluded\n\n", n_full - n_valid))

# Build three weight vectors
# W_total: total_trade (existing, outcome-inclusive)
W_total_full <- merged$trade_weight  # already normalized to sum to 1
W_total_valid <- merged_valid_pre$total_trade / sum(merged_valid_pre$total_trade)

# W_presum: pre_sum_trade (pre-period only, sum aggregation)
W_presum <- merged_valid_pre$pre_sum_trade / sum(merged_valid_pre$pre_sum_trade)

# W_premean: pre_mean_trade (pre-period only, mean aggregation)
W_premean <- merged_valid_pre$pre_mean_trade / sum(merged_valid_pre$pre_mean_trade)

# Compute weighted means
tw_mean_total_full <- sum(merged$theta_D * W_total_full, na.rm = TRUE)
tw_mean_total_valid <- sum(merged_valid_pre$theta_D * W_total_valid, na.rm = TRUE)
tw_mean_presum <- sum(merged_valid_pre$theta_D * W_presum, na.rm = TRUE)
tw_mean_premean <- sum(merged_valid_pre$theta_D * W_premean, na.rm = TRUE)

# Unweighted means
unweighted_full <- mean(merged$theta_D, na.rm = TRUE)
unweighted_valid <- mean(merged_valid_pre$theta_D, na.rm = TRUE)

# Print comparison table
cat("WEIGHTING COMPARISON TABLE:\n")
cat(sprintf("  %-40s %8s %12s\n", "Quantity", "n", "Value"))
cat(paste(rep("-", 64), collapse = ""), "\n")
cat(sprintf("  %-40s %8d %12.4f\n", "Unweighted mean, full population", n_full, unweighted_full))
cat(sprintf("  %-40s %8d %12.4f\n", "Unweighted mean, merged_valid_pre", n_valid, unweighted_valid))
cat(sprintf("  %-40s %8d %12.4f\n", "TW mean (total_trade), full population", n_full, tw_mean_total_full))
cat(sprintf("  %-40s %8d %12.4f\n", "TW mean (total_trade), merged_valid_pre", n_valid, tw_mean_total_valid))
cat(sprintf("  %-40s %8d %12.4f\n", "TW mean (pre_sum_trade), merged_valid_pre", n_valid, tw_mean_presum))
cat(sprintf("  %-40s %8d %12.4f\n", "TW mean (pre_mean_trade), merged_valid_pre", n_valid, tw_mean_premean))
cat(paste(rep("-", 64), collapse = ""), "\n")

cat("\nNOTE: The 'TW mean (total_trade), merged_valid_pre' row isolates the\n")
cat("      sample-restriction effect from the reweighting effect.\n")

# -----------------------------------------------------------------------------
# BOOTSTRAP NEW MEANS (CHANGE 3) - uses local seed to preserve H3
# -----------------------------------------------------------------------------
cat("\nBootstrapping pre-period weighted means (local RNG)...\n")

# Save current RNG state
rng_state <- .Random.seed

# Use local seed for new bootstrap
set.seed(20260725)
n_boot_new <- 500
boot_presum <- numeric(n_boot_new)
boot_premean <- numeric(n_boot_new)

for (b in 1:n_boot_new) {
    idx <- sample(nrow(merged_valid_pre), replace = TRUE)
    boot_data <- merged_valid_pre[idx]
    w_presum_b <- boot_data$pre_sum_trade / sum(boot_data$pre_sum_trade)
    w_premean_b <- boot_data$pre_mean_trade / sum(boot_data$pre_mean_trade)
    boot_presum[b] <- sum(boot_data$theta_D * w_presum_b, na.rm = TRUE)
    boot_premean[b] <- sum(boot_data$theta_D * w_premean_b, na.rm = TRUE)
}

presum_ci <- quantile(boot_presum, c(0.025, 0.975))
premean_ci <- quantile(boot_premean, c(0.025, 0.975))

# Restore RNG state
.Random.seed <- rng_state

cat(sprintf("  TW mean (pre_sum_trade)  95%% CI: [%.4f, %.4f]\n", presum_ci[1], presum_ci[2]))
cat(sprintf("  TW mean (pre_mean_trade) 95%% CI: [%.4f, %.4f]\n", premean_ci[1], premean_ci[2]))

# -----------------------------------------------------------------------------
# (b) COHORTS
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("(b) COHORTS: Adoption cohort analysis\n")
cat("========================================================================\n\n")

# Pre-2008 vs 2008+
merged[, cohort := ifelse(adoption_year < 2008, "pre-2008", "2008+")]

# Correct tw_mean calculation (need global weights) - renamed to tw_contribution
cohort_stats_tw <- merged[, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE),
    tw_contribution = sum(theta_D * trade_weight, na.rm = TRUE),
    sd_theta_D = sd(theta_D, na.rm = TRUE)
), by = cohort][order(cohort)]

# Assert cohort contributions sum to global TW mean
cohort_tw_sum <- sum(cohort_stats_tw$tw_contribution)
stopifnot(abs(cohort_tw_sum - global_tw_mean) < 1e-6)
cat("ASSERTION: Cohort TW contributions sum to global TW mean: PASS\n")
cat(sprintf("  Sum of contributions: %.6f, Global TW mean: %.6f\n\n", cohort_tw_sum, global_tw_mean))

# By year (1991-2016)
year_stats <- merged[adoption_year >= 1991 & adoption_year <= 2016, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE),
    tw_contribution = sum(theta_D * trade_weight, na.rm = TRUE),
    sd_theta_D = sd(theta_D, na.rm = TRUE)
), by = adoption_year][order(adoption_year)]

# D4: global_row removed (was unused; confirmed no sampling calls - only data.table() and arithmetic)

# -----------------------------------------------------------------------------
# OUTPUT: X5-2
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("X5-2: COHORT TABLES\n")
cat("========================================================================\n\n")

cat("Pre-2008 vs 2008+ cohorts:\n")
cat(sprintf("  %-10s %6s %12s %12s %12s\n", "Cohort", "n", "Mean", "TW_Contrib", "SD"))
cat(paste(rep("-", 56), collapse = ""), "\n")
for (i in 1:nrow(cohort_stats_tw)) {
    cat(sprintf("  %-10s %6d %12.4f %12.4f %12.4f\n",
                cohort_stats_tw$cohort[i],
                cohort_stats_tw$n[i],
                cohort_stats_tw$mean_theta_D[i],
                cohort_stats_tw$tw_contribution[i],
                cohort_stats_tw$sd_theta_D[i]))
}
cat(sprintf("  %-10s %6d %12.4f %12.4f %12.4f\n",
            "GLOBAL", nrow(merged), global_mean, global_tw_mean, sd(merged$theta_D)))

cat("\nBy adoption year (1991-2016):\n")
cat(sprintf("  %-6s %6s %12s %12s %12s\n", "Year", "n", "Mean", "TW_Contrib", "SD"))
cat(paste(rep("-", 52), collapse = ""), "\n")
for (i in 1:nrow(year_stats)) {
    cat(sprintf("  %-6d %6d %12.4f %12.4f %12.4f\n",
                year_stats$adoption_year[i],
                year_stats$n[i],
                year_stats$mean_theta_D[i],
                year_stats$tw_contribution[i],
                year_stats$sd_theta_D[i]))
}

# -----------------------------------------------------------------------------
# LEDGER
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("LEDGER ENTRIES\n")
cat("========================================================================\n")

cat(sprintf("SIZE_THETA_CORR = Pearson %.4f [%.4f, %.4f], Spearman %.4f [%.4f, %.4f]\n",
            pearson_r, pearson_ci[1], pearson_ci[2],
            spearman_r, spearman_ci[1], spearman_ci[2]))

cat(sprintf("COHORT_MEANS = pre2008 %.4f (n=%d), 2008+ %.4f (n=%d)\n",
            cohort_stats_tw[cohort == "pre-2008", mean_theta_D],
            cohort_stats_tw[cohort == "pre-2008", n],
            cohort_stats_tw[cohort == "2008+", mean_theta_D],
            cohort_stats_tw[cohort == "2008+", n]))

# -----------------------------------------------------------------------------
# SAVE RESULTS (H3 already verified above, before any saveRDS)
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("SAVING RESULTS\n")
cat("========================================================================\n")

results <- list(
    correlations = list(
        pearson = pearson_r,
        pearson_ci = pearson_ci,
        spearman = spearman_r,
        spearman_ci = spearman_ci
    ),
    quintile_stats = quintile_stats,
    quintile_ci = list(low = quintile_ci_low, high = quintile_ci_high),
    cohort_stats = cohort_stats_tw,
    year_stats = year_stats,
    global = list(mean = global_mean, tw_mean = global_tw_mean),
    weighting = list(
        tw_mean_total_full = tw_mean_total_full,
        tw_mean_total_valid = tw_mean_total_valid,
        tw_mean_presum = tw_mean_presum,
        tw_mean_premean = tw_mean_premean,
        presum_ci = presum_ci,
        premean_ci = premean_ci,
        unweighted_full = unweighted_full,
        unweighted_valid = unweighted_valid,
        n_full = n_full,
        n_valid = n_valid
    )
)

saveRDS(results, OUTPUT_PATH)
cat("Saved:", OUTPUT_PATH, "\n")

# -----------------------------------------------------------------------------
# F1: COPY TO GATES DIRECTORY (provenance)
# -----------------------------------------------------------------------------
# Pattern from N0_setup.R line 118: copies to /groups/m-larch/bt307958/gates/
# REPO_DATA_PATH defined at top

# F1: Guard that destination directory EXISTS - do NOT create it
# A copy step that manufactures its own destination cannot detect a wrong path
if (!dir.exists(dirname(REPO_DATA_PATH))) {
    stop("FATAL: Destination directory does not exist: ", dirname(REPO_DATA_PATH),
         "\nThis suggests REPO_DATA_PATH is misconfigured. Halting.")
}
cat("REPO_DATA_PATH directory exists: PASS\n")

copy_success <- file.copy(OUTPUT_PATH, REPO_DATA_PATH, overwrite = TRUE)
if (!copy_success) {
    stop("FATAL: Failed to copy to REPO_DATA_PATH: ", REPO_DATA_PATH)
}
cat("Copied to:", REPO_DATA_PATH, "\n")

# E3: Print SHA256 using digest (portable, verified available at top)
sha_output <- digest(file = OUTPUT_PATH, algo = "sha256")
sha_repo <- digest(file = REPO_DATA_PATH, algo = "sha256")
cat("SHA256 (OUTPUT_PATH):   ", sha_output, "\n")
cat("SHA256 (REPO_DATA_PATH):", sha_repo, "\n")
stopifnot(sha_output == sha_repo)
cat("Copy integrity: PASS\n")

# -----------------------------------------------------------------------------
# R4: PRINT WEIGHTING BLOCK VALUES FOR CROSS-CHECK
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("R4: WEIGHTING BLOCK VALUES (for cross-check)\n")
cat("========================================================================\n")
cat(sprintf("unweighted_full     = %.10f\n", unweighted_full))
cat(sprintf("unweighted_valid    = %.10f\n", unweighted_valid))
cat(sprintf("tw_mean_total_full  = %.10f\n", tw_mean_total_full))
cat(sprintf("tw_mean_total_valid = %.10f\n", tw_mean_total_valid))
cat(sprintf("tw_mean_presum      = %.10f\n", tw_mean_presum))
cat(sprintf("tw_mean_premean     = %.10f\n", tw_mean_premean))
cat(sprintf("n_full              = %d\n", n_full))
cat(sprintf("n_valid             = %d\n", n_valid))
cat(sprintf("presum_ci           = [%.10f, %.10f]\n", presum_ci[1], presum_ci[2]))
cat(sprintf("premean_ci          = [%.10f, %.10f]\n", premean_ci[1], premean_ci[2]))

cat("\nX5 COMPLETE:", format(Sys.time()), "\n")
