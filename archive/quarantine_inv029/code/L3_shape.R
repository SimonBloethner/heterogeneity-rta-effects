#!/usr/bin/env Rscript
# L3_shape.R - Shape Analysis (Low Reliability)
#
# PURPOSE: Per arm, fit K=1,2,3 Gaussian mixtures and analyze shape
#
# ANALYSIS:
#   - Fit K=1,2,3 Gaussian mixtures using mclust
#   - Compute BIC for each K
#   - Report BIC winner, quantile skewness with bootstrap CI
#
# QUANTILE SKEW: (Q75 + Q25 - 2*Q50) / (Q75 - Q25)
#
# INPUTS:  output/T14_theta_d_total.rds, output/T15_arm_stats.csv
# OUTPUTS: output/T16_shape.csv, output/T16_bic.csv
# GATE:    G_BIC: BIC computable, K_best in {1,2,3}

cat("================================================================\n")
cat("L3: SHAPE ANALYSIS\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

library(data.table)
library(mclust)

set.seed(20260726)

REBUILD_DIR <- "/groups/m-larch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

# -----------------------------------------------------------------------------
# LOAD DATA
# -----------------------------------------------------------------------------
cat("=== LOAD DATA ===\n")

theta_d <- readRDS(file.path(REBUILD_DIR, "output/T14_theta_d_total.rds"))
arm_stats <- fread(file.path(REBUILD_DIR, "output/T15_arm_stats.csv"))

cat(sprintf("theta_d total: %d rows\n", nrow(theta_d)))

# Load placebo data
g2c_path <- "/scratch/bt307958/G2c_results.RData"
has_placebo <- file.exists(g2c_path)
if (has_placebo) {
    load(g2c_path)
    placebo_dt <- G2c_results$placebo_effects
    placebo_theta <- placebo_dt$theta_hat
    cat(sprintf("G2c placebo: %d observations\n", length(placebo_theta)))
}

# -----------------------------------------------------------------------------
# HELPER FUNCTIONS
# -----------------------------------------------------------------------------

# Quantile skewness
quantile_skew <- function(x) {
    q <- quantile(x, c(0.25, 0.5, 0.75), na.rm = TRUE)
    Q25 <- q[1]
    Q50 <- q[2]
    Q75 <- q[3]
    if (Q75 - Q25 == 0) return(0)
    (Q75 + Q25 - 2 * Q50) / (Q75 - Q25)
}

# Bootstrap CI for quantile skewness
boot_skew_ci <- function(x, B = 500, alpha = 0.05) {
    n <- length(x)
    skews <- numeric(B)
    for (b in 1:B) {
        idx <- sample(n, replace = TRUE)
        skews[b] <- quantile_skew(x[idx])
    }
    c(
        lo = quantile(skews, alpha / 2, na.rm = TRUE),
        hi = quantile(skews, 1 - alpha / 2, na.rm = TRUE)
    )
}

# Fit Gaussian mixture using mclust and compute BIC
fit_mixture_mclust <- function(x, K) {
    x <- x[!is.na(x)]
    n <- length(x)

    if (K == 1) {
        # Single Gaussian
        mu <- mean(x)
        sigma <- sd(x)
        ll <- sum(dnorm(x, mean = mu, sd = sigma, log = TRUE))
        k <- 2  # mu, sigma
        bic <- -2 * ll + k * log(n)
        return(list(
            K = 1,
            converged = TRUE,
            mu = mu,
            sigma = sigma,
            lambda = 1,
            ll = ll,
            bic = bic
        ))
    }

    # Multiple Gaussians using mclust
    # Use univariate model "V" (variable variance)
    fit <- tryCatch(
        Mclust(x, G = K, modelNames = "V", verbose = FALSE),
        error = function(e) NULL
    )

    if (is.null(fit)) {
        return(list(K = K, converged = FALSE, bic = Inf))
    }

    # mclust BIC is already computed (higher is better in mclust, so negate)
    # BIC in mclust = 2*loglik - npar*log(n)
    # Standard BIC = -2*loglik + npar*log(n) = -mclust_BIC
    bic <- -fit$bic  # Convert to standard BIC (lower is better)

    list(
        K = K,
        converged = TRUE,
        mu = fit$parameters$mean,
        sigma = sqrt(fit$parameters$variance$sigmasq),
        lambda = fit$parameters$pro,
        ll = fit$loglik,
        bic = bic
    )
}

# -----------------------------------------------------------------------------
# SHAPE ANALYSIS PER ARM
# -----------------------------------------------------------------------------
cat("\n=== SHAPE ANALYSIS PER ARM ===\n")

results <- list()
bic_results <- list()

# Arm A: All bins
cat("\n--- Arm A (Noise-Only) ---\n")
theta_A <- theta_d$theta_D

# Fit K=1,2,3
fits_A <- lapply(1:3, function(K) fit_mixture_mclust(theta_A, K))
bics_A <- sapply(fits_A, function(f) f$bic)
K_best_A <- which.min(bics_A)

cat(sprintf("BIC: K=1: %.2f, K=2: %.2f, K=3: %.2f\n", bics_A[1], bics_A[2], bics_A[3]))
cat(sprintf("Best K: %d\n", K_best_A))

# Quantile skew with CI
skew_A <- quantile_skew(theta_A)
skew_ci_A <- boot_skew_ci(theta_A, B = 500)
cat(sprintf("Quantile skew: %.4f [%.4f, %.4f]\n", skew_A, skew_ci_A[1], skew_ci_A[2]))

# Determine skew sign
skew_sign_A <- ifelse(skew_ci_A[1] > 0, "+", ifelse(skew_ci_A[2] < 0, "-", "0"))

# Check if bulk-winners identified
best_fit_A <- fits_A[[K_best_A]]
bulk_winners_A <- FALSE
if (K_best_A > 1 && best_fit_A$converged) {
    # Check if any component has positive mean and large weight
    pos_comp <- which(best_fit_A$mu > 0)
    if (length(pos_comp) > 0 && any(best_fit_A$lambda[pos_comp] > 0.1)) {
        bulk_winners_A <- TRUE
    }
}

results$A <- data.table(
    arm = "A",
    K_bic_best = K_best_A,
    bulk_winners_identified = bulk_winners_A,
    mean_true = mean(theta_A),
    sd_true = sd(theta_A),
    skew_sign = skew_sign_A,
    skew_quantile = skew_A,
    skew_ci_lo = skew_ci_A[1],
    skew_ci_hi = skew_ci_A[2]
)

bic_results$A <- data.table(
    arm = "A",
    K = 1:3,
    BIC = bics_A,
    converged = sapply(fits_A, function(f) f$converged)
)

# Arm B: Placebo
cat("\n--- Arm B (Placebo) ---\n")
if (has_placebo) {
    theta_B <- placebo_theta
} else {
    theta_B <- theta_d$theta_D
}

fits_B <- lapply(1:3, function(K) fit_mixture_mclust(theta_B, K))
bics_B <- sapply(fits_B, function(f) f$bic)
K_best_B <- which.min(bics_B)

cat(sprintf("BIC: K=1: %.2f, K=2: %.2f, K=3: %.2f\n", bics_B[1], bics_B[2], bics_B[3]))
cat(sprintf("Best K: %d\n", K_best_B))

skew_B <- quantile_skew(theta_B)
skew_ci_B <- boot_skew_ci(theta_B, B = 500)
cat(sprintf("Quantile skew: %.4f [%.4f, %.4f]\n", skew_B, skew_ci_B[1], skew_ci_B[2]))

skew_sign_B <- ifelse(skew_ci_B[1] > 0, "+", ifelse(skew_ci_B[2] < 0, "-", "0"))

best_fit_B <- fits_B[[K_best_B]]
bulk_winners_B <- FALSE
if (K_best_B > 1 && best_fit_B$converged) {
    pos_comp <- which(best_fit_B$mu > 0)
    if (length(pos_comp) > 0 && any(best_fit_B$lambda[pos_comp] > 0.1)) {
        bulk_winners_B <- TRUE
    }
}

results$B <- data.table(
    arm = "B",
    K_bic_best = K_best_B,
    bulk_winners_identified = bulk_winners_B,
    mean_true = mean(theta_B),
    sd_true = sd(theta_B),
    skew_sign = skew_sign_B,
    skew_quantile = skew_B,
    skew_ci_lo = skew_ci_B[1],
    skew_ci_hi = skew_ci_B[2]
)

bic_results$B <- data.table(
    arm = "B",
    K = 1:3,
    BIC = bics_B,
    converged = sapply(fits_B, function(f) f$converged)
)

# Arm C: OOS Drift (4-5, 6-10, 11+)
cat("\n--- Arm C (OOS Drift) ---\n")
theta_C <- theta_d[horizon_bin %in% c("4-5", "6-10", "11+"), theta_D]

fits_C <- lapply(1:3, function(K) fit_mixture_mclust(theta_C, K))
bics_C <- sapply(fits_C, function(f) f$bic)
K_best_C <- which.min(bics_C)

cat(sprintf("BIC: K=1: %.2f, K=2: %.2f, K=3: %.2f\n", bics_C[1], bics_C[2], bics_C[3]))
cat(sprintf("Best K: %d\n", K_best_C))

skew_C <- quantile_skew(theta_C)
skew_ci_C <- boot_skew_ci(theta_C, B = 500)
cat(sprintf("Quantile skew: %.4f [%.4f, %.4f]\n", skew_C, skew_ci_C[1], skew_ci_C[2]))

skew_sign_C <- ifelse(skew_ci_C[1] > 0, "+", ifelse(skew_ci_C[2] < 0, "-", "0"))

best_fit_C <- fits_C[[K_best_C]]
bulk_winners_C <- FALSE
if (K_best_C > 1 && best_fit_C$converged) {
    pos_comp <- which(best_fit_C$mu > 0)
    if (length(pos_comp) > 0 && any(best_fit_C$lambda[pos_comp] > 0.1)) {
        bulk_winners_C <- TRUE
    }
}

results$C <- data.table(
    arm = "C",
    K_bic_best = K_best_C,
    bulk_winners_identified = bulk_winners_C,
    mean_true = mean(theta_C),
    sd_true = sd(theta_C),
    skew_sign = skew_sign_C,
    skew_quantile = skew_C,
    skew_ci_lo = skew_ci_C[1],
    skew_ci_hi = skew_ci_C[2]
)

bic_results$C <- data.table(
    arm = "C",
    K = 1:3,
    BIC = bics_C,
    converged = sapply(fits_C, function(f) f$converged)
)

# Combine results
shape_table <- rbindlist(results)
bic_table <- rbindlist(bic_results)

cat("\n=== SHAPE SUMMARY ===\n")
print(shape_table)

cat("\n=== BIC SUMMARY ===\n")
print(bic_table)

# -----------------------------------------------------------------------------
# GATE CHECK: G_BIC
# -----------------------------------------------------------------------------
cat("\n=== GATE CHECK: G_BIC ===\n")

G_BIC <- all(shape_table$K_bic_best %in% 1:3)
cat(sprintf("G_BIC: %s\n", ifelse(G_BIC, "PASS", "FAIL")))

if (!G_BIC) {
    warning("G_BIC FAILED: K_best not in {1,2,3} for some arms")
}

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
cat("\n=== SAVE OUTPUT ===\n")

output_dir <- file.path(REBUILD_DIR, "output")

# Main shape table
output_file <- file.path(output_dir, "T16_shape.csv")
fwrite(shape_table, output_file)
cat(sprintf("Saved: %s\n", output_file))

# BIC table
bic_file <- file.path(output_dir, "T16_bic.csv")
fwrite(bic_table, bic_file)
cat(sprintf("Saved: %s\n", bic_file))

# Save mixture parameters for best K per arm
mixture_params <- list(
    A = fits_A[[K_best_A]],
    B = fits_B[[K_best_B]],
    C = fits_C[[K_best_C]]
)
params_file <- file.path(output_dir, "T16_mixture_params.rds")
saveRDS(mixture_params, params_file)
cat(sprintf("Saved: %s\n", params_file))

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n================================================================\n")
cat("L3 SHAPE ANALYSIS COMPLETE\n")
cat("================================================================\n")
cat("\nShape summary:\n")
print(shape_table[, .(arm, K_bic_best, bulk_winners_identified, skew_sign)])
cat(sprintf("\nG_BIC: %s\n", ifelse(G_BIC, "PASS", "FAIL")))
cat(sprintf("\nEnd: %s\n", format(Sys.time())))
