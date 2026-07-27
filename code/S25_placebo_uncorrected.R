#!/usr/bin/env Rscript
# S25_placebo_uncorrected.R - Uncorrected placebo theta_B (Definition B)
# OUTPUTS: output/T24_placebo_uncorr.csv, meta/T24_placebo_uncorr.csv.sidecar
# INPUTS:  data/S5R_bhat.rds
# SEED:    NONE (theta_B is seed-invariant on the fixed placebo set)
# EXPECTED_N: 17200 (S5R$placebo pairs)
# GATES:   G1 n == 17200; G2 |mean| > 0.05 (documents bias, not a validity check)
#
# Definition B: theta_B = log(sum(trade_post) / sum(y_hat_0_post)) per pair
# This table documents the uncorrected placebo bias magnitude.
# theta_B is computed on the fixed S5R$placebo population with their fixed
# pseudo-adoption years; no seed enters this computation.

suppressPackageStartupMessages(library(data.table))
setwd("/scratch/bt307958/REBUILD_V2")

EXPECTED_N <- 17200
THRESHOLD <- 0.05

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------
cat("=== LOADING DATA ===\n")

S5R <- readRDS("data/S5R_bhat.rds")
plac <- as.data.table(S5R[["placebo"]])
stopifnot(nrow(plac) == EXPECTED_N)
cat(sprintf("G1 Placebo pairs n = %d: PASS\n", nrow(plac)))

# theta_B is already in S5R$placebo
stopifnot("theta_B" %in% names(plac))
stopifnot("size_decile" %in% names(plac))

# -----------------------------------------------------------------------------
# Compute overall statistics
# -----------------------------------------------------------------------------
cat("\n=== OVERALL STATISTICS ===\n")

overall_mean <- mean(plac$theta_B, na.rm = TRUE)
overall_sd <- sd(plac$theta_B, na.rm = TRUE)
overall_n <- sum(!is.na(plac$theta_B))

cat(sprintf("Overall: n=%d, mean=%.15f, SD=%.15f\n", overall_n, overall_mean, overall_sd))

# G2: |mean| > 0.05 (documents bias)
bias_present <- abs(overall_mean) > THRESHOLD
cat(sprintf("G2 |mean|=%.4f > %.2f: %s (bias documented)\n",
            abs(overall_mean), THRESHOLD,
            ifelse(bias_present, "FAIL", "PASS")))

# -----------------------------------------------------------------------------
# Decile breakdown
# -----------------------------------------------------------------------------
cat("\n=== DECILE BREAKDOWN ===\n")

decile_stats <- plac[, .(
  n = .N,
  mean_theta_B = mean(theta_B, na.rm = TRUE),
  sd_theta_B = sd(theta_B, na.rm = TRUE)
), by = size_decile][order(size_decile)]

print(decile_stats)

# -----------------------------------------------------------------------------
# OUTPUT: 1 overall + 10 deciles = 11 rows
# -----------------------------------------------------------------------------
cat("\n=== OUTPUT ===\n")

out_overall <- data.table(
  ID = "PLACEBO_B_UNCORR_OVERALL",
  quantity = "Mean theta_B (uncorrected placebo)",
  size_decile = NA_integer_,
  n = overall_n,
  mean_theta_B = overall_mean,
  sd_theta_B = overall_sd,
  definition = "B (uncorrected)"
)

out_deciles <- data.table(
  ID = sprintf("PLACEBO_B_UNCORR_DECILE%d", decile_stats$size_decile),
  quantity = sprintf("Mean theta_B decile %d", decile_stats$size_decile),
  size_decile = decile_stats$size_decile,
  n = decile_stats$n,
  mean_theta_B = decile_stats$mean_theta_B,
  sd_theta_B = decile_stats$sd_theta_B,
  definition = "B (uncorrected)"
)

out <- rbind(out_overall, out_deciles)

# -----------------------------------------------------------------------------
# Reproduction gates — these values must not move. Halt if they do.
# -----------------------------------------------------------------------------
stopifnot(nrow(out) == 11L)                                  # 1 overall + 10 deciles
stopifnot(abs(overall_mean - (-0.207204589838223)) < 1e-12)
stopifnot(abs(overall_sd   -   0.824354559230742) < 1e-12)
stopifnot(out_overall$n == 17200L)

cat("Reproduction gates: PASS\n")

print(out)

write.csv(out, "output/T24_placebo_uncorr.csv", row.names = FALSE)
cat("\nSaved: output/T24_placebo_uncorr.csv\n")

# Sidecar
sha <- system("sha256sum output/T24_placebo_uncorr.csv | cut -d' ' -f1", intern = TRUE)
writeLines(c(
  "PRODUCER: S25_placebo_uncorrected.R",
  "INPUTS: data/S5R_bhat.rds",
  "SEED: NONE",
  sprintf("EXPECTED_N: %d", EXPECTED_N),
  "DEFINITION: B (uncorrected) - theta_B = log(sum(trade_post)/sum(y_hat_0_post))",
  "",
  "GATES:",
  sprintf("  G1: placebo pairs n = %d - PASS", EXPECTED_N),
  sprintf("  G2: |mean| = %.4f > 0.05 - FAIL (bias documented)", abs(overall_mean)),
  "",
  "NOTE: G2 FAIL is expected and is the point of the table: the uncorrected placebo",
  "  carries Jensen and drift bias. This documents the bias magnitude; it is not a",
  "  validity check. theta_B is seed-invariant on the fixed placebo set, so no",
  "  per-seed rows are reported (SYNC-6; superseded the four identical seed rows",
  "  emitted at dc47cb4).",
  "",
  sprintf("OVERALL: mean=%.15f, SD=%.15f, n=%d", overall_mean, overall_sd, overall_n),
  "",
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  sprintf("SHA256: %s", sha)
), "meta/T24_placebo_uncorr.csv.sidecar")
cat("Saved: meta/T24_placebo_uncorr.csv.sidecar\n")

cat("\n=== SUMMARY ===\n")
cat(sprintf("11 rows output (1 overall + 10 deciles)\n"))
cat(sprintf("Overall mean = %.4f, SD = %.4f\n", overall_mean, overall_sd))
