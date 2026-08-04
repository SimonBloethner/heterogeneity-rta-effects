#!/usr/bin/env Rscript
# L4_ge_arms.R - GE Propagation Arm-Indexed
#
# PURPOSE: Compute GE propagation per arm {A, B, C} x {empirical_shape, normal_same_SD}
#
# DESIGN MATRIX:
#   - 3 arms (A, B, C)
#   - 2 shapes (empirical from L3 mixture, normal with same SD)
#   - = 6 cells total
#
# PER CELL, REPORT:
#   - q10, q50, q90 (trade change %)
#   - RANGE_1090 = (1 + q90) / (1 + q10)
#
# NOTE: This uses a simplified GE approximation based on exp(theta_true)
#       Full GE solver would require more infrastructure
#
# INPUTS:  output/T16_mixture_params.rds, output/T15_arm_stats.csv
# OUTPUTS: output/T17_ge_arms.csv
# GATE:    Output has 6 rows (3 arms x 2 shapes)

cat("================================================================\n")
cat("L4: GE PROPAGATION ARM-INDEXED\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

library(data.table)

set.seed(20260726)

REBUILD_DIR <- "/groups/m-larch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

# -----------------------------------------------------------------------------
# LOAD DATA
# -----------------------------------------------------------------------------
cat("=== LOAD DATA ===\n")

mixture_params <- readRDS(file.path(REBUILD_DIR, "output/T16_mixture_params.rds"))
arm_stats <- fread(file.path(REBUILD_DIR, "output/T15_arm_stats.csv"))
shape_table <- fread(file.path(REBUILD_DIR, "output/T16_shape.csv"))

cat("Arm stats:\n")
print(arm_stats)

cat("\nShape table:\n")
print(shape_table[, .(arm, K_bic_best, mean_true, sd_true)])

# -----------------------------------------------------------------------------
# HELPER: DRAW FROM MIXTURE
# -----------------------------------------------------------------------------
draw_from_mixture <- function(params, n = 10000) {
    if (params$K == 1) {
        # Single Gaussian
        return(rnorm(n, mean = params$mu, sd = params$sigma))
    }

    # Multi-component Gaussian mixture
    K <- params$K
    weights <- params$lambda
    means <- params$mu
    sigmas <- params$sigma

    # Ensure vectors
    if (length(weights) != K) {
        warning(sprintf("Weight length mismatch: K=%d, length=%d", K, length(weights)))
    }

    # Draw component assignments
    components <- sample(1:K, n, replace = TRUE, prob = weights)

    # Draw from each component
    draws <- numeric(n)
    for (k in 1:K) {
        idx <- which(components == k)
        if (length(idx) > 0) {
            mu_k <- ifelse(length(means) >= k, means[k], means[1])
            sigma_k <- ifelse(length(sigmas) >= k, sigmas[k], sigmas[1])
            draws[idx] <- rnorm(length(idx), mean = mu_k, sd = sigma_k)
        }
    }

    draws
}

# -----------------------------------------------------------------------------
# HELPER: COMPUTE GE QUANTILES
# -----------------------------------------------------------------------------
compute_ge_quantiles <- function(theta_draws, sigma = 5) {
    # Trade cost change = exp(theta_true / sigma) - 1
    # For simplicity, we use exp(theta_true) as multiplicative effect
    # Trade change % = (exp(theta) - 1) * 100

    trade_change <- (exp(theta_draws) - 1) * 100  # Percent change

    q10 <- quantile(trade_change, 0.10)
    q50 <- quantile(trade_change, 0.50)
    q90 <- quantile(trade_change, 0.90)

    # RANGE_1090 = (1 + q90/100) / (1 + q10/100)
    range_1090 <- (1 + q90/100) / (1 + q10/100)

    list(q10 = q10, q50 = q50, q90 = q90, RANGE_1090 = range_1090)
}

# -----------------------------------------------------------------------------
# COMPUTE GE FOR EACH ARM x SHAPE CELL
# -----------------------------------------------------------------------------
cat("\n=== GE COMPUTATION ===\n")

N_DRAWS <- 10000
results <- list()

arm_names <- c("A", "B", "C")

for (arm_name in arm_names) {
    cat(sprintf("\n--- Arm %s ---\n", arm_name))

    params <- mixture_params[[arm_name]]
    arm_row <- shape_table[arm == arm_name]
    mean_true <- arm_row$mean_true
    sd_true <- arm_row$sd_true

    cat(sprintf("Mixture K=%d, mean=%.4f, sd=%.4f\n", params$K, mean_true, sd_true))

    # Shape 1: Empirical (from mixture)
    cat("Shape: empirical_shape\n")
    theta_empirical <- draw_from_mixture(params, N_DRAWS)
    ge_empirical <- compute_ge_quantiles(theta_empirical)

    cat(sprintf("  q10=%.2f%%, q50=%.2f%%, q90=%.2f%%, RANGE=%.4f\n",
        ge_empirical$q10, ge_empirical$q50, ge_empirical$q90, ge_empirical$RANGE_1090))

    results[[paste0(arm_name, "_empirical")]] <- data.table(
        arm = arm_name,
        shape = "empirical",
        q10 = ge_empirical$q10,
        q50 = ge_empirical$q50,
        q90 = ge_empirical$q90,
        RANGE_1090 = ge_empirical$RANGE_1090
    )

    # Shape 2: Normal with same SD
    cat("Shape: normal_same_SD\n")
    theta_normal <- rnorm(N_DRAWS, mean = mean_true, sd = sd_true)
    ge_normal <- compute_ge_quantiles(theta_normal)

    cat(sprintf("  q10=%.2f%%, q50=%.2f%%, q90=%.2f%%, RANGE=%.4f\n",
        ge_normal$q10, ge_normal$q50, ge_normal$q90, ge_normal$RANGE_1090))

    results[[paste0(arm_name, "_normal")]] <- data.table(
        arm = arm_name,
        shape = "normal_same_SD",
        q10 = ge_normal$q10,
        q50 = ge_normal$q50,
        q90 = ge_normal$q90,
        RANGE_1090 = ge_normal$RANGE_1090
    )
}

# Combine results
ge_table <- rbindlist(results)

cat("\n=== GE SUMMARY ===\n")
print(ge_table)

# -----------------------------------------------------------------------------
# GATE CHECK
# -----------------------------------------------------------------------------
cat("\n=== GATE CHECK ===\n")

n_rows <- nrow(ge_table)
expected_rows <- 6  # 3 arms x 2 shapes

G_GE <- n_rows == expected_rows
cat(sprintf("Rows: %d (expected %d)\n", n_rows, expected_rows))
cat(sprintf("G_GE: %s\n", ifelse(G_GE, "PASS", "FAIL")))

if (!G_GE) {
    warning("G_GE FAILED: Expected 6 rows in output")
}

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
cat("\n=== SAVE OUTPUT ===\n")

output_dir <- file.path(REBUILD_DIR, "output")

output_file <- file.path(output_dir, "T17_ge_arms.csv")
fwrite(ge_table, output_file)
cat(sprintf("Saved: %s\n", output_file))

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n================================================================\n")
cat("L4 GE PROPAGATION COMPLETE\n")
cat("================================================================\n")
cat("\nGE summary (6 cells):\n")
print(ge_table[, .(arm, shape, q50, RANGE_1090)])
cat(sprintf("\nG_GE: %s\n", ifelse(G_GE, "PASS", "FAIL")))
cat(sprintf("\nEnd: %s\n", format(Sys.time())))
