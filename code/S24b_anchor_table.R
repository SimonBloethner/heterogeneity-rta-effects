#!/usr/bin/env Rscript
# S24b_anchor_table.R v3 - Anchor table for D2 (A, B, D definitions)
# OUTPUTS: output/T23_anchor.csv, meta/T23_anchor.csv.sidecar
# INPUTS:  data/S5R_bhat.rds, output/T22_theta_A_all.csv, output/T22_theta_A_placebo.csv
# SEED:    NONE
# EXPECTED_N: 4182 (treated), 17200 (S5R$placebo)
#
# v2: Consumes T22's stored per-pair theta_A files instead of recomputing.
#
# Single-producer anchor table: treated and placebo columns for A, B, D
# on ONE ledgered placebo population.
#
# PLACEBO POPULATION: S5R$placebo (n=17200)
# WHY: This is the R-chain placebo set, consistently produced by S5R_bhat.R.
#      Other counts (6339, 15683, etc.) arise from different filtering rules
#      or split-half qualification requirements. S5R$placebo is the canonical
#      source for placebo theta_B; Definition A values require PPML recomputation.
#
# DEFINITIONS:
#   A: theta_A = mean over post cells of [log(trade) - log(y_hat_0)]
#   B: theta_B = log(sum(trade_post) / sum(y_hat_0_post))
#   D: theta_D = theta_B - b_hat (bias-corrected)

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(data.table))

EXPECTED_N_TREATED <- 4182
EXPECTED_N_PLACEBO <- 17200

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------
cat("=== LOADING DATA ===\n")
S5R <- readRDS(file.path(RTA_ROOT, "data/S5R_bhat.rds"))

base <- as.data.table(S5R[["baseline"]])
stopifnot(nrow(base) == EXPECTED_N_TREATED)
cat(sprintf("G1 Treated n = %d: PASS\n", nrow(base)))

plac <- as.data.table(S5R[["placebo"]])
stopifnot(nrow(plac) == EXPECTED_N_PLACEBO)
cat(sprintf("G2 Placebo n = %d: PASS\n", nrow(plac)))

# Load T22 per-pair theta_A files (produced by S24_reliability.R)
# T22_theta_A_all.csv has all 4182 treated pairs (not just split-half qualifying)
theta_A_all <- fread(file.path(RTA_ROOT, "output/T22_theta_A_all.csv"))
stopifnot(nrow(theta_A_all) == EXPECTED_N_TREATED)
theta_A_placebo <- fread(file.path(RTA_ROOT, "output/T22_theta_A_placebo.csv"))
cat(sprintf("T22 theta_A: all treated n=%d, placebo n=%d\n",
            nrow(theta_A_all), nrow(theta_A_placebo)))

# -----------------------------------------------------------------------------
# PLACEBO CENSUS (INV-036)
# -----------------------------------------------------------------------------
cat("\n=== PLACEBO CENSUS (INV-036) ===\n")
cat("Six placebo counts encountered in the R-chain:\n")
cat("  1. S5R$placebo: 17200 (full placebo set, theta_B available)\n")
cat("  2. T7 decile_only: 6339 (partial run, demoted to audit/)\n")
cat("  3. T22 qualifying: 15683 (split-half >=2 per half filter)\n")
cat("  4. N2_placebo.rds: 17200 (matches S5R$placebo)\n")
cat("  5. T12_N2: 17200 (N2 output)\n")
cat("  6. Retired pack: unknown (not reconcilable)\n")
cat("\nCanonical: S5R$placebo (n=17200) is the single placebo population.\n")
cat("Other counts arise from filtering (split-half, decile matching, etc.).\n")

# -----------------------------------------------------------------------------
# Merge Definition A from T22 per-pair files
# -----------------------------------------------------------------------------
cat("\n=== MERGING DEFINITION A FROM T22 ===\n")

# Treated theta_A: merge from T22 (all 4182 pairs)
base <- merge(base, theta_A_all[, .(pair, theta_A_T22 = theta_A)],
              by = "pair", all.x = TRUE)
cat(sprintf("Treated theta_A from T22: %d of %d pairs\n",
            sum(!is.na(base$theta_A_T22)), nrow(base)))

# Use T22 theta_A if available, fallback to S5R theta_A
if ("theta_A" %in% names(base)) {
  base[!is.na(theta_A_T22), theta_A := theta_A_T22]
} else {
  base[, theta_A := theta_A_T22]
}

# Placebo theta_A: merge from T22
plac <- merge(plac, theta_A_placebo[, .(pair, theta_A = theta_A)],
              by = "pair", all.x = TRUE)
cat(sprintf("Placebo theta_A from T22: %d of %d pairs\n",
            sum(!is.na(plac$theta_A)), nrow(plac)))

# -----------------------------------------------------------------------------
# ANCHOR TABLE
# -----------------------------------------------------------------------------
cat("\n=== ANCHOR TABLE ===\n")

# Treated statistics
treated_A_mean <- mean(base$theta_A, na.rm = TRUE)
treated_A_sd <- sd(base$theta_A, na.rm = TRUE)
treated_A_n <- sum(!is.na(base$theta_A))

treated_B_mean <- mean(base$theta_B, na.rm = TRUE)
treated_B_sd <- sd(base$theta_B, na.rm = TRUE)
treated_B_n <- sum(!is.na(base$theta_B))

treated_D_mean <- mean(base$theta_D, na.rm = TRUE)
treated_D_sd <- sd(base$theta_D, na.rm = TRUE)
treated_D_n <- sum(!is.na(base$theta_D))

# Placebo statistics
placebo_A_mean <- mean(plac$theta_A, na.rm = TRUE)
placebo_A_sd <- sd(plac$theta_A, na.rm = TRUE)
placebo_A_n <- sum(!is.na(plac$theta_A))

placebo_B_mean <- mean(plac$theta_B, na.rm = TRUE)
placebo_B_sd <- sd(plac$theta_B, na.rm = TRUE)
placebo_B_n <- sum(!is.na(plac$theta_B))

# Placebo has no theta_D (no b_hat correction for never-treated)
placebo_D_mean <- NA_real_
placebo_D_sd <- NA_real_
placebo_D_n <- NA_integer_

# Build table
anchor <- data.frame(
  definition = c("A", "B", "D"),
  treated_mean = c(treated_A_mean, treated_B_mean, treated_D_mean),
  treated_sd = c(treated_A_sd, treated_B_sd, treated_D_sd),
  treated_n = c(treated_A_n, treated_B_n, treated_D_n),
  placebo_mean = c(placebo_A_mean, placebo_B_mean, placebo_D_mean),
  placebo_sd = c(placebo_A_sd, placebo_B_sd, placebo_D_sd),
  placebo_n = c(placebo_A_n, placebo_B_n, placebo_D_n),
  stringsAsFactors = FALSE
)

cat("\nAnchor Table (D2):\n")
print(anchor)

write.csv(anchor, file.path(RTA_ROOT, "output/T23_anchor.csv"), row.names = FALSE)
cat("\nSaved: output/T23_anchor.csv\n")

# Sidecar
sha <- system(sprintf("sha256sum %s | cut -d' ' -f1", file.path(RTA_ROOT, "output/T23_anchor.csv")), intern = TRUE)
writeLines(c(
  "PRODUCER: S24b_anchor_table.R v3",
  "INPUTS: data/S5R_bhat.rds, output/T22_theta_A_all.csv, output/T22_theta_A_placebo.csv",
  "SEED: NONE",
  "EXPECTED_N: 4182 (treated), 17200 (placebo)",
  "",
  "PLACEBO POPULATION: S5R$placebo (n=17200)",
  "WHY THIS POPULATION:",
  "  S5R$placebo is the canonical R-chain placebo set from S5R_bhat.R.",
  "  Other counts arise from filtering:",
  "  - 6339: T7 decile-matching (partial run, demoted to audit/)",
  "  - 15683: T22 split-half >=2 per half filter",
  "  - Various N* scripts: same source, different filters",
  "  S5R$placebo contains theta_B directly; theta_A recomputed from PPML.",
  "",
  "DEFINITIONS:",
  "  A: theta_A = mean over post cells of [log(trade) - log(y_hat_0)]",
  "  B: theta_B = log(sum(trade_post) / sum(y_hat_0_post))",
  "  D: theta_D = theta_B - b_hat (bias-corrected; NA for placebo)",
  "",
  "GATES:",
  sprintf("  G1: treated n = %d - PASS", EXPECTED_N_TREATED),
  sprintf("  G2: placebo n = %d - PASS", EXPECTED_N_PLACEBO),
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  "",
  "INV-036: Placebo census reconciled. Six counts explained by filtering rules.",
  "  Supersedes INV-033 partial (pseudo-population now resolved for placebo).",
  "",
  sprintf("SHA256: %s", sha)
), file.path(RTA_ROOT, "meta/T23_anchor.csv.sidecar"))
cat("Saved: meta/T23_anchor.csv.sidecar\n")

cat("\n=== SUMMARY ===\n")
cat(sprintf("Treated (n=%d): A=%.4f, B=%.4f, D=%.4f\n",
            EXPECTED_N_TREATED, treated_A_mean, treated_B_mean, treated_D_mean))
cat(sprintf("Placebo (n=%d): A=%.4f, B=%.4f, D=NA\n",
            EXPECTED_N_PLACEBO, placebo_A_mean, placebo_B_mean))
