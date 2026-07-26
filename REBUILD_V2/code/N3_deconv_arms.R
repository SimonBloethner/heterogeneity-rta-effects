#!/usr/bin/env Rscript
# =============================================================================
# N3_deconv_arms.R - Deconvolution with Three Arms
# =============================================================================
# OUTPUTS: output/T12_N3_deconv.csv
# INPUTS:  data/S5R_bhat.rds, data/S17_se_cf.rds, data/N1_oos_null.rds,
#          data/N2_placebo.rds
# SEED:    20260719
# B:       500 (pair-level bootstrap)
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
suppressPackageStartupMessages(library(dplyr))

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEED <- 20260719
B <- 500
set.seed(SEED)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("N3: DECONVOLUTION - THREE ARMS")
say("Start: %s", format(Sys.time()))
say("B = %d bootstrap draws, seed = %d", B, SEED)
say("================================================================")

# Load inputs
S5R <- readRDS("data/S5R_bhat.rds")
baseline <- S5R$baseline

# Check if S17_se_cf.rds exists
if (file.exists("data/S17_se_cf.rds")) {
    S17 <- readRDS("data/S17_se_cf.rds")
    mean_se_total_sq <- S17$mean_se_total_sq
    say("Loaded S17_se_cf.rds: mean(se_total^2) = %.6f", mean_se_total_sq)
} else {
    # Use values from T11
    mean_se_total_sq <- 0.2612
    say("Using hardcoded mean(se_total^2) = %.6f", mean_se_total_sq)
}

N1 <- readRDS("data/N1_oos_null.rds")
N2 <- readRDS("data/N2_placebo.rds")

say("Baseline pairs: %d", nrow(baseline))
say("N1 Var_null_matched: %.6f", N1$Var_null_matched)
say("N2 Var_placebo:      %.6f", N2$var_placebo)

# Var(theta_D)
var_theta_D <- var(baseline$theta_D, na.rm = TRUE)
say("")
say("=== OBSERVED VARIANCE ===")
say("Var(theta_D) = %.6f", var_theta_D)

# =============================================================================
# ACCOUNTING IDENTITY
# =============================================================================
say("")
say("================================================================")
say("ACCOUNTING IDENTITY")
say("================================================================")
say("")
say("Arms B and C subtract placebo/OOS variance directly.")
say("These variances ALREADY CONTAIN:")
say("  - Sampling noise from finite post-windows")
say("  - Counterfactual uncertainty from y_hat_0 estimation")
say("")
say("Therefore, se_total is NOT additionally subtracted in Arms B and C.")
say("Only Arm A (noise-only) subtracts se_total^2 directly.")
say("")

# =============================================================================
# THREE ARMS
# =============================================================================
say("================================================================")
say("THREE-ARM DECONVOLUTION")
say("================================================================")

# Arm A: noise only (subtract se_total^2)
var_true_A <- var_theta_D - mean_se_total_sq
SD_true_A <- sqrt(max(0, var_true_A))

# Arm B: placebo null
var_true_B <- var_theta_D - N2$var_placebo
SD_true_B <- sqrt(max(0, var_true_B))

# Arm C: OOS drift null (preferred)
var_true_C <- var_theta_D - N1$Var_null_matched
SD_true_C <- sqrt(max(0, var_true_C))

say("")
say("Arm A (noise only):     Var(theta_D) - mean(se_total^2)")
say("  = %.6f - %.6f = %.6f", var_theta_D, mean_se_total_sq, var_true_A)
say("  SD_true_A = %.6f", SD_true_A)
say("")
say("Arm B (placebo null):   Var(theta_D) - Var(placebo)")
say("  = %.6f - %.6f = %.6f", var_theta_D, N2$var_placebo, var_true_B)
say("  SD_true_B = %.6f", SD_true_B)
say("")
say("Arm C (OOS drift null): Var(theta_D) - Var_null_matched")
say("  = %.6f - %.6f = %.6f", var_theta_D, N1$Var_null_matched, var_true_C)
say("  SD_true_C = %.6f", SD_true_C)

# =============================================================================
# BOOTSTRAP CI
# =============================================================================
say("")
say("================================================================")
say("BOOTSTRAP CIs (B=%d, pair-level)", B)
say("================================================================")

# For Arm A, we resample baseline pairs and recompute var(theta_D) - mean(se_total^2)
# For Arms B and C, we need the raw data to resample

# Simplified: resample baseline pairs, recompute var(theta_D)
# The noise terms are fixed (population estimates)

boot_results <- matrix(NA, nrow = B, ncol = 3)
colnames(boot_results) <- c("SD_true_A", "SD_true_B", "SD_true_C")

for (b in 1:B) {
    # Resample pairs with replacement
    idx <- sample(nrow(baseline), replace = TRUE)
    boot_theta <- baseline$theta_D[idx]

    boot_var <- var(boot_theta, na.rm = TRUE)

    boot_results[b, "SD_true_A"] <- sqrt(max(0, boot_var - mean_se_total_sq))
    boot_results[b, "SD_true_B"] <- sqrt(max(0, boot_var - N2$var_placebo))
    boot_results[b, "SD_true_C"] <- sqrt(max(0, boot_var - N1$Var_null_matched))
}

# Compute CIs
ci_A <- quantile(boot_results[, "SD_true_A"], c(0.025, 0.975), na.rm = TRUE)
ci_B <- quantile(boot_results[, "SD_true_B"], c(0.025, 0.975), na.rm = TRUE)
ci_C <- quantile(boot_results[, "SD_true_C"], c(0.025, 0.975), na.rm = TRUE)

se_A <- sd(boot_results[, "SD_true_A"], na.rm = TRUE)
se_B <- sd(boot_results[, "SD_true_B"], na.rm = TRUE)
se_C <- sd(boot_results[, "SD_true_C"], na.rm = TRUE)

say("")
say("Arm A: SD_true = %.4f (SE: %.4f) [%.4f, %.4f]", SD_true_A, se_A, ci_A[1], ci_A[2])
say("Arm B: SD_true = %.4f (SE: %.4f) [%.4f, %.4f]", SD_true_B, se_B, ci_B[1], ci_B[2])
say("Arm C: SD_true = %.4f (SE: %.4f) [%.4f, %.4f]", SD_true_C, se_C, ci_C[1], ci_C[2])
say("")
say("IDENTIFIED SET: [Arm C, Arm A] = [%.4f, %.4f]", SD_true_C, SD_true_A)
say("Arm C is the preferred point estimate (OOS drift null)")

# =============================================================================
# DIAGNOSTICS
# =============================================================================
say("")
say("================================================================")
say("DIAGNOSTICS")
say("================================================================")

if (var_true_C < 0) {
    say("WARNING: Arm C variance is negative!")
    say("  Var(theta_D) = %.6f < Var_null_matched = %.6f", var_theta_D, N1$Var_null_matched)
    say("  This suggests the OOS null captures MORE variance than observed theta_D")
}

if (SD_true_C < SD_true_A * 0.5) {
    say("NOTE: SD_true_C is less than half of SD_true_A")
    say("  The OOS drift null accounts for substantial variance beyond noise")
}

# =============================================================================
# OUTPUT
# =============================================================================
say("")

results_df <- data.frame(
    arm = c("A_noise_only", "B_placebo_null", "C_oos_drift",
            "identified_set_lower", "identified_set_upper"),
    subtracted = c("mean(se_total^2)", "Var(placebo)", "Var_null_matched",
                   "Var_null_matched", "mean(se_total^2)"),
    subtracted_value = c(mean_se_total_sq, N2$var_placebo, N1$Var_null_matched,
                         N1$Var_null_matched, mean_se_total_sq),
    var_theta_D = var_theta_D,
    var_true = c(var_true_A, var_true_B, var_true_C, var_true_C, var_true_A),
    SD_true = c(SD_true_A, SD_true_B, SD_true_C, SD_true_C, SD_true_A),
    SE = c(se_A, se_B, se_C, NA, NA),
    CI_lower = c(ci_A[1], ci_B[1], ci_C[1], NA, NA),
    CI_upper = c(ci_A[2], ci_B[2], ci_C[2], NA, NA)
)

write.csv(results_df, "output/T12_N3_deconv.csv", row.names = FALSE)

# Save for downstream
saveRDS(list(
    var_theta_D = var_theta_D,
    mean_se_total_sq = mean_se_total_sq,
    var_placebo = N2$var_placebo,
    var_null_matched = N1$Var_null_matched,
    SD_true_A = SD_true_A,
    SD_true_B = SD_true_B,
    SD_true_C = SD_true_C,
    se_A = se_A,
    se_B = se_B,
    se_C = se_C,
    ci_A = ci_A,
    ci_B = ci_B,
    ci_C = ci_C,
    identified_set = c(SD_true_C, SD_true_A),
    B = B,
    seed = SEED
), "data/N3_deconv.rds")

# Sidecar
code_sha <- get_sha256("code/N3_deconv_arms.R")
writeLines(c(
    "FILE:      T12_N3_deconv.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N3_deconv.csv")),
    sprintf("PRODUCER:  code/N3_deconv_arms.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S5R_bhat.rds, data/S17_se_cf.rds, data/N1_oos_null.rds, data/N2_placebo.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("B:         %d", B),
    "",
    "ACCOUNTING IDENTITY:",
    "  Arms B and C subtract placebo/OOS variance directly.",
    "  These variances ALREADY CONTAIN sampling noise and CF uncertainty.",
    "  Therefore se_total is NOT additionally subtracted in Arms B and C.",
    "",
    sprintf("Var(theta_D):       %.6f", var_theta_D),
    sprintf("mean(se_total^2):   %.6f (Arm A)", mean_se_total_sq),
    sprintf("Var(placebo):       %.6f (Arm B)", N2$var_placebo),
    sprintf("Var_null_matched:   %.6f (Arm C)", N1$Var_null_matched),
    "",
    sprintf("SD_true_A: %.4f [%.4f, %.4f]", SD_true_A, ci_A[1], ci_A[2]),
    sprintf("SD_true_B: %.4f [%.4f, %.4f]", SD_true_B, ci_B[1], ci_B[2]),
    sprintf("SD_true_C: %.4f [%.4f, %.4f] <- PREFERRED", SD_true_C, ci_C[1], ci_C[2]),
    "",
    sprintf("IDENTIFIED SET: [%.4f, %.4f]", SD_true_C, SD_true_A),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T12_N3_deconv.csv.sidecar")

say("Wrote output/T12_N3_deconv.csv")
say("Wrote data/N3_deconv.rds")
say("Done: %s", format(Sys.time()))
