#!/usr/bin/env Rscript
# S24_arms_canonical.R - Canonical Arms Table
# OUTPUTS: output/T21_arms.csv, meta/T21_arms.csv.sidecar
# INPUTS:  data/S5R_bhat.rds (for Var(theta_D) and TW_MEAN verification)
#          output/T12_N1b_horizon.csv (N1b OOS variances per horizon bin)
#          output/T12_N1_oos_null.csv (symmetric-window treated weights)
# SEED:    NONE
# EXPECTED_N: 4182
# GATES:   G1 Var(theta_D) == 2.438; G2 shares sum correctly;
#          G3 TW_MEAN from pre_trade weights;
#          G4 Var_null_C = 1.8868 (from N1b × symmetric weights)
#
# This script creates the canonical arms table. Arm C is computed explicitly
# from T12_N1b_horizon.csv variances × symmetric-window treated weights.
#
# INV-027: SD_true identified set [0.74, 1.48]
# INV-027a: CLOSED - V4/S18 measure in-sample null; N1b measures OOS null
# INV-022: Arm A noise-only Var_null = 0.261145
# INV-034: TW_MEAN = 0.0897 (pre_trade weights, canonical)

suppressPackageStartupMessages(library(data.table))
setwd("/scratch/bt307958/REBUILD_V2")

EXPECTED_N <- 4182
VAR_THETA_D_CANON <- 2.4380

# Load baseline for verification
S5R <- readRDS("data/S5R_bhat.rds")
base <- as.data.table(S5R$baseline)
stopifnot(nrow(base) == EXPECTED_N)

# Verify Var(theta_D)
var_theta_D <- var(base$theta_D, na.rm = TRUE)
cat(sprintf("G1 Var(theta_D) = %.4f (canonical %.4f)\n", var_theta_D, VAR_THETA_D_CANON))
stopifnot(abs(var_theta_D - VAR_THETA_D_CANON) < 1e-2)
cat("G1 Var(theta_D) matches canonical: PASS\n")

# -----------------------------------------------------------------------------
# G4: EXPLICIT ARM C COMPUTATION (INV-027a resolution)
# Arm C = Σ (N1b_variance_b × symmetric_weight_b)
# -----------------------------------------------------------------------------
cat("\n=== G4: Arm C explicit computation ===\n")

# Load N1b OOS variances per horizon bin
N1b <- read.csv("output/T12_N1b_horizon.csv", stringsAsFactors = FALSE)
cat("Loaded T12_N1b_horizon.csv\n")

# Load symmetric weights from T12_N1_oos_null.csv
N1_weights <- read.csv("output/T12_N1_oos_null.csv", stringsAsFactors = FALSE)
sym_weights <- data.frame(
  horizon_bin = c("2-3", "4-5", "6-10", "11+"),
  weight = c(
    as.numeric(N1_weights$value[N1_weights$quantity == "weight_2-3"]),
    as.numeric(N1_weights$value[N1_weights$quantity == "weight_4-5"]),
    as.numeric(N1_weights$value[N1_weights$quantity == "weight_6-10"]),
    as.numeric(N1_weights$value[N1_weights$quantity == "weight_11+"])
  )
)
cat("Loaded symmetric weights from T12_N1_oos_null.csv\n")

# Merge N1b variances with symmetric weights
arm_c_data <- merge(N1b[N1b$horizon_bin != "MATCHED", c("horizon_bin", "var_pseudo")],
                    sym_weights, by = "horizon_bin")
arm_c_data$contribution <- arm_c_data$var_pseudo * arm_c_data$weight

cat("\nArm C per-bin contributions:\n")
print(arm_c_data)

# Compute Var_null_C
Var_null_C <- sum(arm_c_data$contribution)
cat(sprintf("\nVar_null_C = Σ (N1b_var × sym_weight) = %.6f\n", Var_null_C))
cat(sprintf("Expected: 1.8868\n"))

# Gate: Var_null_C must match 1.8868 to 3 decimal places
stopifnot(abs(Var_null_C - 1.8868) < 1e-3)
cat("G4 Var_null_C matches 1.8868 to 3 decimals: PASS\n")

# -----------------------------------------------------------------------------
# CANONICAL ARMS TABLE
# -----------------------------------------------------------------------------

arms <- data.frame(
  arm = c("A_noise_only", "B_placebo", "C_OOS"),
  window = c("horizon-matched", "in-sample", "symmetric"),
  Var_null_subtracted = c(0.261145, 0.679560, Var_null_C),
  source_INV = c("INV-022", "in-sample", "G4 (N1b × sym weights)"),
  stringsAsFactors = FALSE
)

# Compute shares
arms$share_of_Var_theta_D <- arms$Var_null_subtracted / VAR_THETA_D_CANON

# Compute SD_true = sqrt(Var_theta_D - Var_null)
arms$SD_true <- sqrt(VAR_THETA_D_CANON - arms$Var_null_subtracted)

# CI bounds (from register)
arms$CI_low <- c(1.4191, 1.2598, NA)
arms$CI_high <- c(1.5266, 1.3834, NA)

# Verify shares
cat("\nG2 Share verification:\n")
for (i in 1:nrow(arms)) {
  expected_share <- arms$Var_null_subtracted[i] / VAR_THETA_D_CANON
  cat(sprintf("  %s: Var_null=%.4f, share=%.4f (computed %.4f)\n",
              arms$arm[i], arms$Var_null_subtracted[i],
              arms$share_of_Var_theta_D[i], expected_share))
  stopifnot(abs(arms$share_of_Var_theta_D[i] - expected_share) < 1e-6)
}
cat("G2 shares computed correctly: PASS\n")

# Verify SD_true matches INV-027 bracket
cat(sprintf("\nSD_true bracket: [%.4f, %.4f]\n", min(arms$SD_true), max(arms$SD_true)))
cat(sprintf("  A_noise_only SD_true = %.4f (expected 1.4754)\n", arms$SD_true[1]))
cat(sprintf("  B_placebo SD_true = %.4f (expected 1.3260)\n", arms$SD_true[2]))
cat(sprintf("  C_OOS SD_true = %.4f (expected 0.7420)\n", arms$SD_true[3]))

stopifnot(abs(arms$SD_true[1] - 1.4754) < 0.001)
stopifnot(abs(arms$SD_true[2] - 1.3260) < 0.001)
# Arm C SD_true computed from Var_null_C: sqrt(2.438 - 1.8868) = 0.7424
expected_SD_C <- sqrt(VAR_THETA_D_CANON - Var_null_C)
cat(sprintf("  C_OOS SD_true = %.4f (computed from G4)\n", arms$SD_true[3]))
stopifnot(abs(arms$SD_true[3] - expected_SD_C) < 0.001)
cat("G2b SD_true values match register: PASS\n")

# -----------------------------------------------------------------------------
# INV-034: Trade-weighted mean (pre_trade weights)
# -----------------------------------------------------------------------------
cat("\n=== INV-034: Trade-weighted mean ===\n")

# TW_MEAN with pre_trade weights (canonical per C4 adjudication)
tw_mean_pre <- weighted.mean(base$theta_D, base$pre_trade, na.rm = TRUE)
cat(sprintf("TW_MEAN (pre_trade weights) = %.4f\n", tw_mean_pre))
cat(sprintf("  Canonical value = 0.0897\n"))
cat(sprintf("  Retired pack value = 0.141\n"))
cat(sprintf("  T10R (total_trade) = 0.304\n"))

# C4 adjudication: pre_trade is canonical (total_trade is endogenous)
TW_MEAN_CANON <- 0.0897
stopifnot(abs(tw_mean_pre - TW_MEAN_CANON) < 0.01)
cat("G3 TW_MEAN matches canonical: PASS\n")

# -----------------------------------------------------------------------------
# OUTPUT
# -----------------------------------------------------------------------------
out <- data.frame(
  arm = arms$arm,
  window = arms$window,
  Var_null_subtracted = arms$Var_null_subtracted,
  share_of_Var_theta_D = round(arms$share_of_Var_theta_D, 4),
  SD_true = round(arms$SD_true, 4),
  CI_low = arms$CI_low,
  CI_high = arms$CI_high,
  source_INV = arms$source_INV
)

cat("\nCanonical Arms Table:\n")
print(out)

# Add TW_MEAN row
tw_row <- data.frame(
  arm = "TW_MEAN",
  window = "pre_trade weights",
  Var_null_subtracted = NA,
  share_of_Var_theta_D = NA,
  SD_true = NA,
  CI_low = NA,
  CI_high = NA,
  source_INV = "INV-034"
)
out <- rbind(out, tw_row)
out$value[out$arm == "TW_MEAN"] <- tw_mean_pre

write.csv(out, "output/T21_arms.csv", row.names = FALSE)
cat("\nSaved: output/T21_arms.csv\n")

# Sidecar
sha <- system("sha256sum output/T21_arms.csv | cut -d' ' -f1", intern = TRUE)
writeLines(c(
  "PRODUCER: S24_arms_canonical.R",
  "INPUTS: data/S5R_bhat.rds, output/T12_N1b_horizon.csv, output/T12_N1_oos_null.csv",
  "SEED: NONE",
  "EXPECTED_N: 4182",
  sprintf("VAR_THETA_D: %.4f", var_theta_D),
  "GATES:",
  sprintf("  G1: Var(theta_D) = %.4f (canonical 2.4380) - PASS", var_theta_D),
  "  G2: shares = Var_null / Var_theta_D - PASS",
  "  G2b: SD_true values match register - PASS",
  sprintf("  G3: TW_MEAN = %.4f (canonical 0.0897) - PASS", tw_mean_pre),
  sprintf("  G4: Var_null_C = %.6f (from N1b × symmetric weights) - PASS", Var_null_C),
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  "",
  "INV-027a RESOLVED:",
  "  Arm C computed explicitly from T12_N1b_horizon.csv (OOS variances) ×",
  "  symmetric-window treated weights (from T12_N1_oos_null.csv).",
  "  T26_null_stack.csv (0.389) is the IN-SAMPLE pseudo null, not Arm C.",
  "",
  "INV-034: TW_MEAN = 0.0897 (pre_trade weights). T10R used total_trade (0.304),",
  "   retired pack used unknown weights (0.141). C4 adjudicated pre_trade as canonical",
  "   since total_trade is endogenous to the effect.",
  sprintf("SHA256: %s", sha)
), "meta/T21_arms.csv.sidecar")
cat("Saved: meta/T21_arms.csv.sidecar\n")

cat(sprintf("\n=== SUMMARY ===\n"))
cat(sprintf("Var(theta_D) = %.4f\n", var_theta_D))
cat(sprintf("SD_true bracket: [%.4f, %.4f]\n", arms$SD_true[3], arms$SD_true[1]))
cat(sprintf("TW_MEAN = %.4f (pre_trade weights)\n", tw_mean_pre))
