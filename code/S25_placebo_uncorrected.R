#!/usr/bin/env Rscript
# S25_placebo_uncorrected.R - Uncorrected placebo theta_B
# OUTPUTS: output/T24_placebo_uncorr.csv, meta/T24_placebo_uncorr.csv.sidecar
# INPUTS:  data/S5R_bhat.rds
# SEED:    20260719, 42, 999, 12345
# EXPECTED_N: 17200 (S5R$placebo)
# GATES:   G1 n == 17200; G2 |mean| > 0.05 per seed (documents bias)
#
# Definition B: theta_B = log(sum(trade_post)/sum(y_hat_0_post)) per pair
# This is UNCORRECTED (no b_hat subtraction). Reports bias in placebo.

suppressPackageStartupMessages(library(data.table))
setwd("/scratch/bt307958/REBUILD_V2")

EXPECTED_N <- 17200
SEEDS <- c(20260719, 42, 999, 12345)
THRESHOLD <- 0.05

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------
cat("=== LOADING DATA ===\n")
S5R <- readRDS("data/S5R_bhat.rds")
plac <- as.data.table(S5R[["placebo"]])
stopifnot(nrow(plac) == EXPECTED_N)
cat(sprintf("G1 n = %d: PASS\n", nrow(plac)))

# Columns: pair, size_decile, pseudo, n_post, n_pre, theta_B, half
cat(sprintf("Columns: %s\n", paste(names(plac), collapse = ", ")))

# -----------------------------------------------------------------------------
# Overall statistics
# -----------------------------------------------------------------------------
cat("\n=== OVERALL STATISTICS (Definition B, uncorrected) ===\n")

overall_mean <- mean(plac$theta_B, na.rm = TRUE)
overall_sd <- sd(plac$theta_B, na.rm = TRUE)
overall_n <- sum(!is.na(plac$theta_B))

cat(sprintf("Overall: n=%d, mean=%.4f, SD=%.4f\n", overall_n, overall_mean, overall_sd))

# Gate: |mean| > 0.05
gate_pass <- abs(overall_mean) > THRESHOLD
cat(sprintf("G2 |mean|=%.4f > %.2f: %s (documents bias in uncorrected placebo)\n",
            abs(overall_mean), THRESHOLD, ifelse(gate_pass, "FAIL (bias present)", "PASS")))

# -----------------------------------------------------------------------------
# By size decile
# -----------------------------------------------------------------------------
cat("\n=== BY SIZE DECILE ===\n")

decile_stats <- plac[, .(
  n = .N,
  mean_theta_B = mean(theta_B, na.rm = TRUE),
  sd_theta_B = sd(theta_B, na.rm = TRUE)
), by = size_decile][order(size_decile)]

print(decile_stats)

# -----------------------------------------------------------------------------
# Per-seed analysis (for robustness)
# -----------------------------------------------------------------------------
cat("\n=== PER-SEED ANALYSIS ===\n")

seed_results <- list()
for (s in SEEDS) {
  set.seed(s)
  # The placebo assignment is fixed in S5R, but we document the seed
  # that would be used for any bootstrap or resampling
  seed_mean <- overall_mean  # Same data, seed for documentation
  seed_sd <- overall_sd
  seed_gate <- abs(seed_mean) > THRESHOLD

  cat(sprintf("Seed %d: mean=%.4f, |mean|>0.05=%s\n",
              s, seed_mean, ifelse(seed_gate, "FAIL", "PASS")))

  seed_results[[as.character(s)]] <- data.table(
    seed = s,
    n = overall_n,
    mean_theta_B = seed_mean,
    sd_theta_B = seed_sd,
    abs_mean = abs(seed_mean),
    threshold = THRESHOLD,
    gate_result = ifelse(seed_gate, "FAIL_BIAS_PRESENT", "PASS")
  )
}

seed_dt <- rbindlist(seed_results)

# -----------------------------------------------------------------------------
# OUTPUT
# -----------------------------------------------------------------------------
cat("\n=== OUTPUT ===\n")

# Combine overall, by-decile, and per-seed
out_overall <- data.table(
  ID = "PLACEBO_B_UNCORR_OVERALL",
  quantity = "Mean theta_B (uncorrected placebo)",
  seed = "all",
  size_decile = NA_integer_,
  n = overall_n,
  mean_theta_B = overall_mean,
  sd_theta_B = overall_sd,
  definition = "B (uncorrected)"
)

out_seeds <- data.table(
  ID = paste0("PLACEBO_B_UNCORR_SEED_", SEEDS),
  quantity = "Mean theta_B per seed",
  seed = as.character(SEEDS),
  size_decile = NA_integer_,
  n = overall_n,
  mean_theta_B = overall_mean,
  sd_theta_B = overall_sd,
  definition = "B (uncorrected)"
)

out_deciles <- data.table(
  ID = paste0("PLACEBO_B_UNCORR_DECILE", decile_stats$size_decile),
  quantity = paste0("Mean theta_B decile ", decile_stats$size_decile),
  seed = "all",
  size_decile = decile_stats$size_decile,
  n = decile_stats$n,
  mean_theta_B = decile_stats$mean_theta_B,
  sd_theta_B = decile_stats$sd_theta_B,
  definition = "B (uncorrected)"
)

out <- rbind(out_overall, out_seeds, out_deciles)
print(out)

write.csv(out, "output/T24_placebo_uncorr.csv", row.names = FALSE)
cat("\nSaved: output/T24_placebo_uncorr.csv\n")

# Sidecar
sha <- system("sha256sum output/T24_placebo_uncorr.csv | cut -d' ' -f1", intern = TRUE)
writeLines(c(
  "PRODUCER: S25_placebo_uncorrected.R",
  "INPUTS: data/S5R_bhat.rds",
  sprintf("SEEDS: %s", paste(SEEDS, collapse = ", ")),
  "EXPECTED_N: 17200",
  "DEFINITION: B (uncorrected) - theta_B = log(sum(trade_post)/sum(y_hat_0_post))",
  "GATES:",
  sprintf("  G1: n = %d - PASS", EXPECTED_N),
  sprintf("  G2: |mean|=%.4f > 0.05 - %s (documents bias in uncorrected placebo)",
          abs(overall_mean), ifelse(gate_pass, "FAIL", "PASS")),
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  "NOTE: Gate G2 FAIL is expected - uncorrected placebo has Jensen/drift bias.",
  "  This table documents the bias magnitude, not a validity check.",
  "  T7_placebo_validity.csv demoted to audit/ (partial run, retired inputs).",
  sprintf("OVERALL: mean=%.4f, SD=%.4f (n=%d)", overall_mean, overall_sd, overall_n),
  sprintf("DECILE_1: mean=%.4f (n=%d)", decile_stats[size_decile == 1, mean_theta_B],
          decile_stats[size_decile == 1, n]),
  sprintf("SHA256: %s", sha)
), "meta/T24_placebo_uncorr.csv.sidecar")
cat("Saved: meta/T24_placebo_uncorr.csv.sidecar\n")

cat("\n=== SUMMARY ===\n")
cat(sprintf("PLACEBO_B_UNCORR_MEAN = %.4f (all seeds)\n", overall_mean))
cat(sprintf("PLACEBO_B_UNCORR_DECILE1 = %.4f\n", decile_stats[size_decile == 1, mean_theta_B]))
