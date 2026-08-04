#!/usr/bin/env Rscript
# L5_11plus_gate.R - Arm C Residual Hardening (11+ Horizon Gate)
#
# PURPOSE: Determine whether to DROP or SCALE the 11+ bin for Arm C
#
# DECISION GATE (one of two outcomes):
#   Option A: SCALE - Apply transportability correction
#     - Formalize cohort variance ratio with CI
#     - Extrapolate to 11+ via log-linear fit on n_post
#   Option B: DROP - Truncate horizon weights
#     - Remove 11+ bin from horizon weighting
#     - Renormalize remaining weights
#
# GATE LOGIC:
#   if (ratio_11plus_ci includes 1.0 OR ratio_11plus_ci_width > 0.5) {
#     decision <- "DROP"
#   } else {
#     decision <- "SCALE"
#   }
#
# INPUTS:  output/T14_variance_by_bin.csv, output/T14_theta_d_total.rds
# OUTPUTS: output/T18_11plus_gate.csv
# GATE:    G_11PLUS: decision in {DROP, SCALE}

cat("================================================================\n")
cat("L5: 11+ HORIZON GATE\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

library(data.table)

set.seed(20260726)

REBUILD_DIR <- "/groups/m-larch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

# -----------------------------------------------------------------------------
# LOAD L1 OUTPUT
# -----------------------------------------------------------------------------
cat("=== LOAD DATA ===\n")

var_by_bin <- fread(file.path(REBUILD_DIR, "output/T14_variance_by_bin.csv"))
theta_d <- readRDS(file.path(REBUILD_DIR, "output/T14_theta_d_total.rds"))

cat("Variance by bin from L1:\n")
print(var_by_bin)
cat(sprintf("\ntheta_d total: %d rows\n", nrow(theta_d)))

# -----------------------------------------------------------------------------
# COMPUTE VARIANCE RATIOS
# -----------------------------------------------------------------------------
cat("\n=== VARIANCE RATIOS ===\n")

# Reference variance (6-10 bin)
ref_var <- var_by_bin[horizon_bin == "6-10", var_theta_D]
cat(sprintf("Reference variance (6-10 bin): %.6f\n", ref_var))

# Compute ratios for all bins
var_by_bin[, ratio := var_theta_D / ref_var]

cat("\nVariance ratios (relative to 6-10):\n")
print(var_by_bin[, .(horizon_bin, n, var_theta_D, ratio)])

# -----------------------------------------------------------------------------
# LOG-LINEAR FIT FOR EXTRAPOLATION
# -----------------------------------------------------------------------------
cat("\n=== LOG-LINEAR FIT ===\n")

# Assign representative n_post for each bin (midpoint)
bin_midpoints <- data.table(
    horizon_bin = c("2-3", "4-5", "6-10", "11+"),
    n_post_mid = c(2.5, 4.5, 8, 15)  # 11+ uses 15 as representative
)

fit_data <- merge(var_by_bin, bin_midpoints, by = "horizon_bin")

# Exclude 11+ for fitting, then extrapolate
fit_data_train <- fit_data[horizon_bin != "11+"]

# Log-linear: log(ratio) ~ log(n_post_mid)
# This models power-law decay: ratio = a * n_post^b
fit_data_train[, log_ratio := log(ratio)]
fit_data_train[, log_n := log(n_post_mid)]

lm_fit <- lm(log_ratio ~ log_n, data = fit_data_train)
cat("Log-linear fit (excluding 11+):\n")
print(summary(lm_fit))

# Extrapolate to 11+ (n_post_mid = 15)
pred_11plus <- predict(lm_fit, newdata = data.table(log_n = log(15)))
ratio_11plus_point <- exp(pred_11plus)
cat(sprintf("\nExtrapolated ratio for 11+ (n_post=15): %.6f\n", ratio_11plus_point))

# Actual ratio from data
actual_ratio_11plus <- fit_data[horizon_bin == "11+", ratio]
cat(sprintf("Actual ratio for 11+: %.6f\n", actual_ratio_11plus))

# -----------------------------------------------------------------------------
# BOOTSTRAP CI FOR EXTRAPOLATED RATIO
# -----------------------------------------------------------------------------
cat("\n=== BOOTSTRAP CI ===\n")

B <- 500  # Number of bootstrap samples

bootstrap_ratios <- numeric(B)

for (b in 1:B) {
    # Resample theta_d within each bin
    boot_data <- theta_d[, {
        idx <- sample(.N, replace = TRUE)
        .SD[idx]
    }, by = horizon_bin]

    # Compute variance by bin
    boot_var <- boot_data[!is.na(theta_D), .(
        var_theta_D = var(theta_D)
    ), by = horizon_bin]

    boot_var <- merge(boot_var, bin_midpoints, by = "horizon_bin", all.x = TRUE)

    # Reference (6-10)
    ref_var_b <- boot_var[horizon_bin == "6-10", var_theta_D]
    if (is.na(ref_var_b) || ref_var_b <= 0) {
        bootstrap_ratios[b] <- NA
        next
    }

    boot_var[, ratio := var_theta_D / ref_var_b]

    # Fit on training bins
    boot_train <- boot_var[horizon_bin %in% c("2-3", "4-5", "6-10") & ratio > 0]
    boot_train[, log_ratio := log(ratio)]
    boot_train[, log_n := log(n_post_mid)]

    if (nrow(boot_train) < 2) {
        bootstrap_ratios[b] <- NA
        next
    }

    lm_b <- tryCatch(
        lm(log_ratio ~ log_n, data = boot_train),
        error = function(e) NULL
    )

    if (is.null(lm_b)) {
        bootstrap_ratios[b] <- NA
        next
    }

    pred_b <- predict(lm_b, newdata = data.table(log_n = log(15)))
    bootstrap_ratios[b] <- exp(pred_b)
}

# Remove NAs
bootstrap_ratios <- bootstrap_ratios[!is.na(bootstrap_ratios)]
cat(sprintf("Valid bootstrap samples: %d/%d\n", length(bootstrap_ratios), B))

# CI
ratio_11plus_ci_lo <- quantile(bootstrap_ratios, 0.025, na.rm = TRUE)
ratio_11plus_ci_hi <- quantile(bootstrap_ratios, 0.975, na.rm = TRUE)
ratio_11plus_ci_width <- ratio_11plus_ci_hi - ratio_11plus_ci_lo

cat(sprintf("\nExtrapolated ratio 11+: %.4f [%.4f, %.4f]\n",
    ratio_11plus_point, ratio_11plus_ci_lo, ratio_11plus_ci_hi))
cat(sprintf("CI width: %.4f\n", ratio_11plus_ci_width))

# -----------------------------------------------------------------------------
# DECISION GATE
# -----------------------------------------------------------------------------
cat("\n=== DECISION GATE ===\n")

# Gate logic:
# DROP if: ratio_11plus_ci includes 1.0 OR ratio_11plus_ci_width > 0.5
ci_includes_1 <- (ratio_11plus_ci_lo <= 1.0) && (ratio_11plus_ci_hi >= 1.0)
ci_too_wide <- ratio_11plus_ci_width > 0.5

cat(sprintf("CI includes 1.0: %s\n", ci_includes_1))
cat(sprintf("CI width > 0.5: %s\n", ci_too_wide))

if (ci_includes_1 || ci_too_wide) {
    decision <- "DROP"
    decision_reason <- ifelse(ci_includes_1,
        "CI includes 1.0 (no clear scaling needed)",
        "CI too wide (unreliable extrapolation)")
} else {
    decision <- "SCALE"
    decision_reason <- "Clear scaling factor identified"
}

cat(sprintf("\nDECISION: %s\n", decision))
cat(sprintf("REASON: %s\n", decision_reason))

# -----------------------------------------------------------------------------
# COMPUTE SCALED/TRUNCATED WEIGHTS
# -----------------------------------------------------------------------------
cat("\n=== WEIGHT ADJUSTMENT ===\n")

# Horizon weights based on bin sizes
horizon_weights <- var_by_bin[, .(horizon_bin, n)]
horizon_weights[, weight := n / sum(n)]

cat("Original horizon weights:\n")
print(horizon_weights)

if (decision == "DROP") {
    # Truncate: remove 11+ and renormalize
    truncated <- horizon_weights[horizon_bin != "11+"]
    truncated[, weight_truncated := n / sum(n)]

    cat("\nTruncated weights (11+ excluded):\n")
    print(truncated)

    # Renormalization factor
    weight_11plus <- horizon_weights[horizon_bin == "11+", weight]
    renorm_factor <- 1 / (1 - weight_11plus)
    cat(sprintf("\n11+ weight excluded: %.4f\n", weight_11plus))
    cat(sprintf("Renormalization factor: %.4f\n", renorm_factor))

} else {
    # SCALE: apply variance scaling to 11+
    var_11plus_raw <- var_by_bin[horizon_bin == "11+", var_theta_D]
    var_11plus_scaled <- var_11plus_raw * ratio_11plus_point

    cat(sprintf("\n11+ variance (raw): %.6f\n", var_11plus_raw))
    cat(sprintf("11+ variance (scaled): %.6f\n", var_11plus_scaled))
    cat(sprintf("Scaling factor: %.4f\n", ratio_11plus_point))
}

# -----------------------------------------------------------------------------
# ARM DEFINITIONS
# -----------------------------------------------------------------------------
cat("\n=== ARM DEFINITIONS ===\n")

# Arm A: Noise-only (all bins, raw variance)
arm_A_bins <- c("2-3", "4-5", "6-10", "11+")
arm_A_n <- var_by_bin[horizon_bin %in% arm_A_bins, sum(n)]
arm_A_var <- var_by_bin[horizon_bin %in% arm_A_bins, weighted.mean(var_theta_D, n)]

cat(sprintf("Arm A (Noise-Only): n=%d, var=%.4f\n", arm_A_n, arm_A_var))

# Arm B: Placebo (synthetic null comparison)
# This uses external placebo data - will be filled from G2c results
arm_B_note <- "Arm B uses G2c_results placebo effects"
cat(sprintf("Arm B (Placebo): %s\n", arm_B_note))

# Arm C: OOS Drift (depends on decision)
if (decision == "DROP") {
    arm_C_bins <- c("4-5", "6-10")  # Exclude 2-3 (no support) and 11+ (dropped)
    arm_C_n <- var_by_bin[horizon_bin %in% arm_C_bins, sum(n)]
    arm_C_var <- var_by_bin[horizon_bin %in% arm_C_bins, weighted.mean(var_theta_D, n)]
    arm_C_def <- "Testable horizons only (4-5, 6-10)"
} else {
    arm_C_bins <- c("4-5", "6-10", "11+")
    arm_C_n <- var_by_bin[horizon_bin %in% arm_C_bins, sum(n)]
    # Apply scaling to 11+ contribution
    var_scaled <- var_by_bin[horizon_bin %in% arm_C_bins]
    var_scaled[horizon_bin == "11+", var_theta_D := var_theta_D * ratio_11plus_point]
    arm_C_var <- var_scaled[, weighted.mean(var_theta_D, n)]
    arm_C_def <- sprintf("Scaled 11+ (factor=%.4f)", ratio_11plus_point)
}

cat(sprintf("Arm C (OOS Drift): n=%d, var=%.4f, def=%s\n", arm_C_n, arm_C_var, arm_C_def))

# -----------------------------------------------------------------------------
# BUILD OUTPUT TABLE
# -----------------------------------------------------------------------------
cat("\n=== BUILD OUTPUT TABLE ===\n")

output_table <- data.table(
    quantity = c(
        "decision",
        "decision_reason",
        "ratio_11plus_point",
        "ratio_11plus_ci_lo",
        "ratio_11plus_ci_hi",
        "ratio_11plus_ci_width",
        "ci_includes_1",
        "ci_too_wide",
        "arm_A_bins",
        "arm_A_n",
        "arm_A_var",
        "arm_C_bins",
        "arm_C_n",
        "arm_C_var",
        "arm_C_definition"
    ),
    value = c(
        decision,
        decision_reason,
        sprintf("%.6f", ratio_11plus_point),
        sprintf("%.6f", ratio_11plus_ci_lo),
        sprintf("%.6f", ratio_11plus_ci_hi),
        sprintf("%.6f", ratio_11plus_ci_width),
        as.character(ci_includes_1),
        as.character(ci_too_wide),
        paste(arm_A_bins, collapse = ","),
        as.character(arm_A_n),
        sprintf("%.6f", arm_A_var),
        paste(arm_C_bins, collapse = ","),
        as.character(arm_C_n),
        sprintf("%.6f", arm_C_var),
        arm_C_def
    )
)

cat("Output table:\n")
print(output_table)

# -----------------------------------------------------------------------------
# GATE CHECK: G_11PLUS
# -----------------------------------------------------------------------------
cat("\n=== GATE CHECK: G_11PLUS ===\n")

G_11PLUS <- decision %in% c("DROP", "SCALE")

cat(sprintf("G_11PLUS: %s (decision=%s)\n",
    ifelse(G_11PLUS, "PASS", "FAIL"), decision))

if (!G_11PLUS) {
    stop("G_11PLUS FAILED: Invalid decision")
}

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
cat("\n=== SAVE OUTPUT ===\n")

output_dir <- file.path(REBUILD_DIR, "output")

# Main output
output_file <- file.path(output_dir, "T18_11plus_gate.csv")
fwrite(output_table, output_file)
cat(sprintf("Saved: %s\n", output_file))

# Also save arm definitions for downstream use
arm_defs <- data.table(
    arm = c("A", "B", "C"),
    description = c("Noise-Only", "Placebo", "OOS Drift"),
    bins = c(
        paste(arm_A_bins, collapse = ","),
        "placebo",
        paste(arm_C_bins, collapse = ",")
    ),
    n = c(arm_A_n, NA, arm_C_n),
    var_theta_D = c(arm_A_var, NA, arm_C_var),
    note = c(
        "All bins, raw variance",
        arm_B_note,
        arm_C_def
    )
)

arm_file <- file.path(output_dir, "T18_arm_definitions.csv")
fwrite(arm_defs, arm_file)
cat(sprintf("Saved: %s\n", arm_file))

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n================================================================\n")
cat("L5 11+ GATE COMPLETE\n")
cat("================================================================\n")
cat(sprintf("Decision: %s\n", decision))
cat(sprintf("Reason: %s\n", decision_reason))
cat(sprintf("Extrapolated ratio: %.4f [%.4f, %.4f]\n",
    ratio_11plus_point, ratio_11plus_ci_lo, ratio_11plus_ci_hi))
cat(sprintf("\nG_11PLUS: %s\n", ifelse(G_11PLUS, "PASS", "FAIL")))
cat(sprintf("\nEnd: %s\n", format(Sys.time())))
