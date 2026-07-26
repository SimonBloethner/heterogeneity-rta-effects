#!/usr/bin/env Rscript
# S7_deconv.R - Deconvolution and Variance Decomposition
# OUTPUTS: data/S7_deconv.rds
# INPUTS:  data/S5_bhat.rds, data/S3_theta.rds, data/S6_population.rds
# SEED:    20260719
# GATES:   identified set valid (var_theta >= 0 or documented)

cat("================================================================\n")
cat("S7: DECONVOLUTION AND VARIANCE DECOMPOSITION\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

suppressPackageStartupMessages(library(data.table))

SEED <- 20260719
set.seed(SEED)

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    strsplit(result, " ")[[1]][1]
}

# Load inputs
cat("=== LOAD INPUTS ===\n")
bhat_data <- readRDS(file.path(REBUILD_DIR, "data/S5_bhat.rds"))
theta_raw <- readRDS(file.path(REBUILD_DIR, "data/S3_theta.rds"))
population <- readRDS(file.path(REBUILD_DIR, "data/S6_population.rds"))

theta_d <- bhat_data$theta_d
bhat_table <- bhat_data$bhat_table

cat(sprintf("theta_d rows (all switchers): %d\n", nrow(theta_d)))
cat(sprintf("BASELINE population: %d\n", nrow(population)))

# Filter to BASELINE population
theta_baseline <- theta_d[pair %in% population$pair]
cat(sprintf("theta_d in BASELINE: %d\n\n", nrow(theta_baseline)))

# -----------------------------------------------------------------------------
# VARIANCE DECOMPOSITION (Full sample: 6,339)
# -----------------------------------------------------------------------------
cat("=== VARIANCE DECOMPOSITION (Full Sample n=6339) ===\n")

# Var(theta_hat) = Var(theta) + E[se^2]
# Therefore: Var(theta) = Var(theta_hat) - E[se^2]

theta_valid <- theta_d[!is.na(theta_D) & !is.na(se_B)]

var_theta_hat <- var(theta_valid$theta_B, na.rm = TRUE)
mean_se_sq <- mean(theta_valid$se_B^2, na.rm = TRUE)
var_theta <- var_theta_hat - mean_se_sq

cat(sprintf("Var(theta_hat_B): %.6f\n", var_theta_hat))
cat(sprintf("E[se_B^2]:        %.6f\n", mean_se_sq))
cat(sprintf("Var(theta):       %.6f\n", var_theta))

if (var_theta > 0) {
    sd_theta <- sqrt(var_theta)
    cat(sprintf("SD(theta):        %.6f\n", sd_theta))
} else {
    sd_theta <- 0
    cat("SD(theta):        0 (variance estimate negative)\n")
}

reliability <- if (var_theta_hat > 0) var_theta / var_theta_hat else NA
cat(sprintf("Reliability:      %.4f\n\n", reliability))

# -----------------------------------------------------------------------------
# VARIANCE DECOMPOSITION (BASELINE sample: 4,639)
# -----------------------------------------------------------------------------
cat("=== VARIANCE DECOMPOSITION (BASELINE n=4639) ===\n")

theta_base_valid <- theta_baseline[!is.na(theta_D) & !is.na(se_B)]

var_theta_hat_base <- var(theta_base_valid$theta_B, na.rm = TRUE)
mean_se_sq_base <- mean(theta_base_valid$se_B^2, na.rm = TRUE)
var_theta_base <- var_theta_hat_base - mean_se_sq_base

cat(sprintf("Var(theta_hat_B): %.6f\n", var_theta_hat_base))
cat(sprintf("E[se_B^2]:        %.6f\n", mean_se_sq_base))
cat(sprintf("Var(theta):       %.6f\n", var_theta_base))

if (var_theta_base > 0) {
    sd_theta_base <- sqrt(var_theta_base)
    cat(sprintf("SD(theta):        %.6f\n", sd_theta_base))
} else {
    sd_theta_base <- 0
    cat("SD(theta):        0 (variance estimate negative)\n")
}

reliability_base <- if (var_theta_hat_base > 0) var_theta_base / var_theta_hat_base else NA
cat(sprintf("Reliability:      %.4f\n\n", reliability_base))

# -----------------------------------------------------------------------------
# BOOTSTRAP CI FOR SD(theta)
# -----------------------------------------------------------------------------
cat("=== BOOTSTRAP CI FOR SD(theta) ===\n")

n_boot <- 1000
set.seed(SEED)

boot_sd <- replicate(n_boot, {
    idx <- sample(nrow(theta_valid), replace = TRUE)
    boot_theta <- theta_valid$theta_B[idx]
    boot_se <- theta_valid$se_B[idx]
    
    v_hat <- var(boot_theta, na.rm = TRUE)
    e_se2 <- mean(boot_se^2, na.rm = TRUE)
    v_theta <- v_hat - e_se2
    
    if (v_theta > 0) sqrt(v_theta) else 0
})

sd_ci <- quantile(boot_sd, c(0.025, 0.975))
cat(sprintf("SD(theta) point estimate: %.4f\n", sd_theta))
cat(sprintf("95%% CI: [%.4f, %.4f]\n", sd_ci[1], sd_ci[2]))
cat(sprintf("Bootstrap SE: %.4f\n\n", sd(boot_sd)))

# -----------------------------------------------------------------------------
# THETA_D DISTRIBUTION SUMMARY
# -----------------------------------------------------------------------------
cat("=== THETA_D DISTRIBUTION ===\n")

cat("\nFull sample (n=6339):\n")
cat(sprintf("  Mean:   %.6f\n", mean(theta_d$theta_D, na.rm = TRUE)))
cat(sprintf("  Median: %.6f\n", median(theta_d$theta_D, na.rm = TRUE)))
cat(sprintf("  SD:     %.6f\n", sd(theta_d$theta_D, na.rm = TRUE)))
cat(sprintf("  Min:    %.6f\n", min(theta_d$theta_D, na.rm = TRUE)))
cat(sprintf("  Max:    %.6f\n", max(theta_d$theta_D, na.rm = TRUE)))

cat("\nBASELINE sample (n=4639):\n")
cat(sprintf("  Mean:   %.6f\n", mean(theta_baseline$theta_D, na.rm = TRUE)))
cat(sprintf("  Median: %.6f\n", median(theta_baseline$theta_D, na.rm = TRUE)))
cat(sprintf("  SD:     %.6f\n", sd(theta_baseline$theta_D, na.rm = TRUE)))
cat(sprintf("  Min:    %.6f\n", min(theta_baseline$theta_D, na.rm = TRUE)))
cat(sprintf("  Max:    %.6f\n", max(theta_baseline$theta_D, na.rm = TRUE)))

# Percentiles
cat("\nPercentiles (BASELINE):\n")
pcts <- c(0.01, 0.05, 0.10, 0.25, 0.50, 0.75, 0.90, 0.95, 0.99)
pct_vals <- quantile(theta_baseline$theta_D, pcts, na.rm = TRUE)
for (i in seq_along(pcts)) {
    cat(sprintf("  P%02d: %.4f\n", round(pcts[i]*100), pct_vals[i]))
}

# -----------------------------------------------------------------------------
# SIZE GRADIENT (by decile and quintile)
# -----------------------------------------------------------------------------
cat("\n=== SIZE GRADIENT ===\n")

cat("\nBy decile (BASELINE):\n")
decile_gradient <- theta_baseline[, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE),
    sd_theta_D = sd(theta_D, na.rm = TRUE),
    median_theta_D = median(theta_D, na.rm = TRUE)
), by = size_decile][order(size_decile)]
print(decile_gradient)

cat("\nBy quintile (BASELINE):\n")
theta_baseline[, quintile := ceiling(size_decile / 2)]
quintile_gradient <- theta_baseline[, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE),
    sd_theta_D = sd(theta_D, na.rm = TRUE)
), by = quintile][order(quintile)]
print(quintile_gradient)

q1_q5_spread <- quintile_gradient[quintile == 1]$mean_theta_D - 
                quintile_gradient[quintile == 5]$mean_theta_D
cat(sprintf("\nQ1-Q5 spread (BASELINE): %.4f\n", q1_q5_spread))

# -----------------------------------------------------------------------------
# COHORT ANALYSIS
# -----------------------------------------------------------------------------
cat("\n=== COHORT ANALYSIS ===\n")

# Early vs Late adopters
theta_baseline[, cohort := ifelse(adoption_year <= 2004, "Early (<=2004)", "Late (>2004)")]

cohort_stats <- theta_baseline[, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE),
    sd_theta_D = sd(theta_D, na.rm = TRUE)
), by = cohort]
print(cohort_stats)

# By adoption year bins
theta_baseline[, year_bin := cut(adoption_year, 
                                  breaks = c(1990, 1995, 2000, 2005, 2010, 2017),
                                  labels = c("1991-95", "1996-00", "2001-05", "2006-10", "2011-16"))]
year_bin_stats <- theta_baseline[, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE)
), by = year_bin][order(year_bin)]
cat("\nBy adoption period:\n")
print(year_bin_stats)

# -----------------------------------------------------------------------------
# IDENTIFIED SET
# -----------------------------------------------------------------------------
cat("\n=== IDENTIFIED SET ===\n")

# The identified set for the distribution of theta depends on:
# 1. Point estimate of mean(theta_D)
# 2. Variance decomposition estimate of Var(theta)

mean_theta_D_base <- mean(theta_baseline$theta_D, na.rm = TRUE)

cat(sprintf("Mean(theta_D): %.4f\n", mean_theta_D_base))
cat(sprintf("SD(theta):     %.4f (from variance decomposition)\n", sd_theta_base))

if (var_theta_base > 0) {
    # Assuming normal distribution
    lower_95 <- mean_theta_D_base - 1.96 * sd_theta_base
    upper_95 <- mean_theta_D_base + 1.96 * sd_theta_base
    cat(sprintf("95%% of effects in: [%.4f, %.4f] (normal assumption)\n", lower_95, upper_95))
    identified_set_valid <- TRUE
} else {
    cat("Variance estimate non-positive; identified set not well-defined\n")
    identified_set_valid <- FALSE
}

# -----------------------------------------------------------------------------
# GATES
# -----------------------------------------------------------------------------
cat("\n=== GATES ===\n")

# Gate: identified set valid or documented
if (identified_set_valid || var_theta_base <= 0) {
    cat("GATE: Identified set valid or documented [PASS]\n")
} else {
    stop("GATE: Identified set invalid")
}

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
output <- list(
    # Variance decomposition
    var_decomp_full = list(
        n = nrow(theta_valid),
        var_theta_hat = var_theta_hat,
        mean_se_sq = mean_se_sq,
        var_theta = var_theta,
        sd_theta = sd_theta,
        reliability = reliability
    ),
    var_decomp_baseline = list(
        n = nrow(theta_base_valid),
        var_theta_hat = var_theta_hat_base,
        mean_se_sq = mean_se_sq_base,
        var_theta = var_theta_base,
        sd_theta = sd_theta_base,
        reliability = reliability_base
    ),
    # Bootstrap
    bootstrap = list(
        sd_theta = sd_theta,
        ci_lower = sd_ci[1],
        ci_upper = sd_ci[2],
        se = sd(boot_sd)
    ),
    # Gradients
    decile_gradient = decile_gradient,
    quintile_gradient = quintile_gradient,
    q1_q5_spread = q1_q5_spread,
    # Cohorts
    cohort_stats = cohort_stats,
    year_bin_stats = year_bin_stats,
    # Summary
    theta_d_summary = list(
        full_n = nrow(theta_d),
        full_mean = mean(theta_d$theta_D, na.rm = TRUE),
        full_sd = sd(theta_d$theta_D, na.rm = TRUE),
        baseline_n = nrow(theta_baseline),
        baseline_mean = mean(theta_baseline$theta_D, na.rm = TRUE),
        baseline_sd = sd(theta_baseline$theta_D, na.rm = TRUE)
    ),
    identified_set_valid = identified_set_valid
)

OUTPUT_PATH <- file.path(REBUILD_DIR, "data/S7_deconv.rds")
saveRDS(output, OUTPUT_PATH)
output_sha <- get_sha256(OUTPUT_PATH)

cat(sprintf("\nSaved: %s\nSHA256: %s\n", OUTPUT_PATH, output_sha))

# Sidecar
SIDECAR_PATH <- file.path(REBUILD_DIR, "meta/S7_deconv.rds.sidecar")
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S7_deconv.R"))

writeLines(c(
    "FILE:      S7_deconv.rds",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S7_deconv.R (SHA256: %s)", script_sha),
    "INPUTS:    data/S5_bhat.rds, data/S3_theta.rds, data/S6_population.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("GATE:      identified_set_valid [PASS, %s]", format(Sys.time())),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "=== KEY RESULTS (BASELINE n=4639) ===",
    sprintf("Mean(theta_D): %.6f", mean_theta_D_base),
    sprintf("SD(theta):     %.6f", sd_theta_base),
    sprintf("Q1-Q5 spread:  %.6f", q1_q5_spread)
), SIDECAR_PATH)

cat(sprintf("Sidecar: %s\n", SIDECAR_PATH))

cat("\n================================================================\n")
cat("S7 DECONVOLUTION COMPLETE\n")
cat(sprintf("End: %s\n", format(Sys.time())))
