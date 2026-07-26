#!/usr/bin/env Rscript
# =============================================================================
# S19_deconv_arms.R - Three-Arm Deconvolution with Bootstrap CIs
# =============================================================================
# OUTPUT:  output/T12_N3_deconv.csv, data/S19_deconv.rds
# INPUTS:  data/S5R_bhat.rds, data/S18_null_stack.rds
# SEED:    20260719
# METHOD:  Arm A - noise-only (subtract mean(se_total^2))
#          Arm B - placebo (subtract Var(placebo))
#          Arm C - OOS drift (subtract Var_null_matched)
#          Bootstrap CIs (B=500)
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
say("S19: THREE-ARM DECONVOLUTION")
say("Start: %s", format(Sys.time()))
say("B = %d bootstrap iterations", B)
say("================================================================")

# Load data
S5R <- readRDS("data/S5R_bhat.rds")
baseline <- S5R$baseline
S18 <- readRDS("data/S18_null_stack.rds")

say("Baseline pairs: %d", nrow(baseline))

# =============================================================================
# SETUP
# =============================================================================

# Variance of theta_D
Var_theta_D <- var(baseline$theta_D)
say("")
say("Var(theta_D): %.4f", Var_theta_D)

# Arm A: noise-only (se_total = sqrt(se_B^2 + sd_cf^2))
mean_sd_cf_sq <- 0.0894  # From S17
baseline$se_total <- sqrt(baseline$se_B^2 + mean_sd_cf_sq)
mean_se_total_sq <- mean(baseline$se_total^2)

# Arm B: placebo
Var_placebo <- S18$var_placebo

# Arm C: OOS drift (Var_null_matched from S18)
Var_null_matched <- S18$Var_null_matched

say("")
say("Subtraction terms:")
say("  Arm A (noise):   mean(se_total^2) = %.4f", mean_se_total_sq)
say("  Arm B (placebo): Var(placebo) = %.4f", Var_placebo)
say("  Arm C (OOS):     Var_null_matched = %.4f", Var_null_matched)

# =============================================================================
# POINT ESTIMATES
# =============================================================================
say("")
say("=== POINT ESTIMATES ===")

Var_true_A <- max(0, Var_theta_D - mean_se_total_sq)
Var_true_B <- max(0, Var_theta_D - Var_placebo)
Var_true_C <- max(0, Var_theta_D - Var_null_matched)

SD_true_A <- sqrt(Var_true_A)
SD_true_B <- sqrt(Var_true_B)
SD_true_C <- sqrt(Var_true_C)

say("Arm A (noise-only):  SD_true = %.4f", SD_true_A)
say("Arm B (placebo):     SD_true = %.4f", SD_true_B)
say("Arm C (OOS drift):   SD_true = %.4f", SD_true_C)

# =============================================================================
# ACCOUNTING IDENTITY CHECK
# =============================================================================
say("")
say("=== ACCOUNTING IDENTITY ===")
say("Var(theta_D) = Var_true + Var_noise")
say("  Arm A: %.4f = %.4f + %.4f (check: %.4f)",
    Var_theta_D, Var_true_A, mean_se_total_sq, Var_true_A + mean_se_total_sq)
say("  Arm B: %.4f = %.4f + %.4f (check: %.4f)",
    Var_theta_D, Var_true_B, Var_placebo, Var_true_B + Var_placebo)
say("  Arm C: %.4f = %.4f + %.4f (check: %.4f)",
    Var_theta_D, Var_true_C, Var_null_matched, Var_true_C + Var_null_matched)

# =============================================================================
# BOOTSTRAP CONFIDENCE INTERVALS
# =============================================================================
say("")
say("=== BOOTSTRAP CIs (B=%d) ===", B)

boot_SD_A <- numeric(B)
boot_SD_B <- numeric(B)
boot_SD_C <- numeric(B)

n <- nrow(baseline)

for (b in 1:B) {
    # Resample pairs with replacement
    idx <- sample(1:n, n, replace = TRUE)
    theta_b <- baseline$theta_D[idx]
    se_total_b <- baseline$se_total[idx]

    Var_theta_b <- var(theta_b)
    mean_se_sq_b <- mean(se_total_b^2)

    boot_SD_A[b] <- sqrt(max(0, Var_theta_b - mean_se_sq_b))
    boot_SD_B[b] <- sqrt(max(0, Var_theta_b - Var_placebo))
    boot_SD_C[b] <- sqrt(max(0, Var_theta_b - Var_null_matched))
}

CI_A <- quantile(boot_SD_A, c(0.025, 0.975))
CI_B <- quantile(boot_SD_B, c(0.025, 0.975))
CI_C <- quantile(boot_SD_C, c(0.025, 0.975))

say("Arm A: %.4f [%.4f, %.4f]", SD_true_A, CI_A[1], CI_A[2])
say("Arm B: %.4f [%.4f, %.4f]", SD_true_B, CI_B[1], CI_B[2])
say("Arm C: %.4f [%.4f, %.4f]", SD_true_C, CI_C[1], CI_C[2])

# =============================================================================
# PARTIAL IDENTIFICATION BRACKET
# =============================================================================
say("")
say("=== PARTIAL IDENTIFICATION ===")

# Lower bound: Arm C (largest subtraction)
# Upper bound: Arm A (smallest subtraction)
SD_bracket_low <- SD_true_C
SD_bracket_high <- SD_true_A

say("SD_THETA_TRUE bracket: [%.4f, %.4f]", SD_bracket_low, SD_bracket_high)
say("")
say("Interpretation:")
say("  Lower bound (%.3f): Arm C assumes OOS drift captures all systematic variation", SD_bracket_low)
say("  Upper bound (%.3f): Arm A assumes only sampling noise, no systematic drift", SD_bracket_high)

# =============================================================================
# OUTPUT
# =============================================================================
say("")

results <- data.frame(
    arm = c("A_noise", "B_placebo", "C_OOS"),
    description = c("Noise-only (se_total)", "In-sample placebo", "OOS drift"),
    subtraction = c(mean_se_total_sq, Var_placebo, Var_null_matched),
    SD_true = c(SD_true_A, SD_true_B, SD_true_C),
    CI_low = c(CI_A[1], CI_B[1], CI_C[1]),
    CI_high = c(CI_A[2], CI_B[2], CI_C[2])
)

write.csv(results, "output/T12_N3_deconv.csv", row.names = FALSE)

# Save for downstream
saveRDS(list(
    Var_theta_D = Var_theta_D,
    # Arms
    SD_true_A = SD_true_A,
    SD_true_B = SD_true_B,
    SD_true_C = SD_true_C,
    CI_A = CI_A,
    CI_B = CI_B,
    CI_C = CI_C,
    # Subtractions
    mean_se_total_sq = mean_se_total_sq,
    Var_placebo = Var_placebo,
    Var_null_matched = Var_null_matched,
    # Bracket
    SD_bracket = c(SD_bracket_low, SD_bracket_high),
    # Meta
    B = B,
    seed = SEED
), "data/S19_deconv.rds")

# Sidecar
code_sha <- get_sha256("code/S19_deconv_arms.R")
writeLines(c(
    "FILE:      T12_N3_deconv.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N3_deconv.csv")),
    sprintf("PRODUCER:  code/S19_deconv_arms.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S5R_bhat.rds, data/S18_null_stack.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("B:         %d bootstrap iterations", B),
    "",
    "THREE-ARM DECONVOLUTION:",
    sprintf("  Arm A (noise):   SD = %.4f [%.4f, %.4f]", SD_true_A, CI_A[1], CI_A[2]),
    sprintf("  Arm B (placebo): SD = %.4f [%.4f, %.4f]", SD_true_B, CI_B[1], CI_B[2]),
    sprintf("  Arm C (OOS):     SD = %.4f [%.4f, %.4f]", SD_true_C, CI_C[1], CI_C[2]),
    "",
    sprintf("SD_THETA_TRUE BRACKET: [%.4f, %.4f]", SD_bracket_low, SD_bracket_high),
    "",
    "ACCOUNTING IDENTITY: Var(theta_D) = Var_true + Var_noise",
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T12_N3_deconv.csv.sidecar")

say("")
say("Wrote output/T12_N3_deconv.csv")
say("Wrote data/S19_deconv.rds")
say("Done: %s", format(Sys.time()))
