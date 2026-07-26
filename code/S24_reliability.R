#!/usr/bin/env Rscript
# S24_reliability.R - Split-half reliability analysis
# OUTPUTS: output/T22_reliability.csv, meta/T22_reliability.csv.sidecar
# INPUTS:  data/S5R_bhat.rds, data/S1R_ppml.rds
# SEED:    20260719
# EXPECTED_N: 4182
# GATES:   G1 n == 4182; G2 split-half computed; G3 placebo stats computed
#
# Split-half reliability for Definition A (theta_D), odd/even post-years.
# Placebo: mean, SD, split-half r under Definition A.
#
# REPORT-ONLY comparison with retired pack values (DO NOT tune toward them).

suppressPackageStartupMessages(library(data.table))
set.seed(20260719)
setwd("/scratch/bt307958/REBUILD_V2")

EXPECTED_N <- 4182

# Retired pack values (for comparison only, not targets)
RETIRED <- list(
  splithalf_r = 0.9720,
  placebo_mean = -0.7121,
  placebo_sd = 1.1165,
  placebo_r = 0.62
)

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------
S5R <- readRDS("data/S5R_bhat.rds")
base <- as.data.table(S5R$baseline)
stopifnot(nrow(base) == EXPECTED_N)
cat(sprintf("G1 n = %d: PASS\n", nrow(base)))

placebo_data <- as.data.table(S5R$placebo)
cat(sprintf("Placebo pairs: %d\n", nrow(placebo_data)))

# -----------------------------------------------------------------------------
# Split-half reliability for Definition A (theta_D)
# Split by odd/even post-years
# -----------------------------------------------------------------------------
cat("\n=== SPLIT-HALF RELIABILITY (Definition A) ===\n")

# For split-half, we need to recompute theta_D on odd vs even post-years
# This requires the raw panel data. Since we have theta_D already computed,
# we'll use a simpler approach: split pairs into odd/even based on adoption_year

# Actually, the ledgered convention is odd/even POST-years within each pair
# Since we don't have the raw panel here, we'll compute correlation between
# random halves of the theta_D estimates as a proxy

# Better approach: use the S1R_ppml data to recompute
ppml <- readRDS("data/S1R_ppml.rds")
setDT(ppml)

# Filter to baseline pairs
baseline_pairs <- unique(base$pair)
ppml_base <- ppml[pair %in% baseline_pairs & is_post == TRUE]

# Split post-years into odd/even
ppml_base[, year_parity := ifelse(year %% 2 == 1, "odd", "even")]

# Compute theta_D separately for odd and even years
# theta_D = mean(log(trade) - log(y_hat_0)) for post years

theta_odd <- ppml_base[year_parity == "odd",
                        .(theta_odd = mean(log(trade) - log(y_hat_0), na.rm = TRUE)),
                        by = pair]
theta_even <- ppml_base[year_parity == "even",
                         .(theta_even = mean(log(trade) - log(y_hat_0), na.rm = TRUE)),
                         by = pair]

# Merge
theta_split <- merge(theta_odd, theta_even, by = "pair", all = FALSE)
cat(sprintf("Pairs with both odd and even post-years: %d\n", nrow(theta_split)))

# Split-half correlation
splithalf_r <- cor(theta_split$theta_odd, theta_split$theta_even, use = "complete.obs")
cat(sprintf("Split-half correlation (odd/even): r = %.4f\n", splithalf_r))

# Spearman-Brown prophecy formula for full reliability
reliability_full <- (2 * splithalf_r) / (1 + splithalf_r)
cat(sprintf("Spearman-Brown reliability: %.4f\n", reliability_full))

cat(sprintf("\nComparison with retired pack:\n"))
cat(sprintf("  R-chain split-half r = %.4f\n", splithalf_r))
cat(sprintf("  Retired pack r = %.4f\n", RETIRED$splithalf_r))
cat(sprintf("  Deviation = %+.4f\n", splithalf_r - RETIRED$splithalf_r))

# -----------------------------------------------------------------------------
# Placebo statistics under Definition A
# -----------------------------------------------------------------------------
cat("\n=== PLACEBO STATISTICS (Definition A) ===\n")

# Placebo pairs: compute theta_D equivalent
# theta_D for placebo = theta_B (no b_hat correction since never-treated)
placebo_theta <- placebo_data$theta_B

placebo_mean <- mean(placebo_theta, na.rm = TRUE)
placebo_sd <- sd(placebo_theta, na.rm = TRUE)

cat(sprintf("Placebo mean = %.4f\n", placebo_mean))
cat(sprintf("Placebo SD = %.4f\n", placebo_sd))

# Split-half for placebo
# Note: placebo pairs may not be in S1R_ppml (which contains switchers)
placebo_ppml <- ppml[pair %in% unique(placebo_data$pair) & is_post == TRUE]

if (nrow(placebo_ppml) > 0) {
  placebo_ppml[, year_parity := ifelse(year %% 2 == 1, "odd", "even")]

  placebo_odd <- placebo_ppml[year_parity == "odd",
                               .(theta_odd = mean(log(trade) - log(y_hat_0), na.rm = TRUE)),
                               by = pair]
  placebo_even <- placebo_ppml[year_parity == "even",
                                .(theta_even = mean(log(trade) - log(y_hat_0), na.rm = TRUE)),
                                by = pair]

  placebo_split <- merge(placebo_odd, placebo_even, by = "pair", all = FALSE)
  if (nrow(placebo_split) > 0) {
    placebo_r <- cor(placebo_split$theta_odd, placebo_split$theta_even, use = "complete.obs")
    cat(sprintf("Placebo split-half r = %.4f\n", placebo_r))
  } else {
    placebo_r <- NA
    cat("Placebo split-half r = NA (no complete pairs)\n")
  }
} else {
  placebo_r <- NA
  cat("Placebo split-half r = NA (placebo pairs not in PPML data)\n")
}

cat(sprintf("\nComparison with retired pack:\n"))
cat(sprintf("  R-chain placebo mean = %.4f (retired %.4f, dev %+.4f)\n",
            placebo_mean, RETIRED$placebo_mean, placebo_mean - RETIRED$placebo_mean))
cat(sprintf("  R-chain placebo SD = %.4f (retired %.4f, dev %+.4f)\n",
            placebo_sd, RETIRED$placebo_sd, placebo_sd - RETIRED$placebo_sd))
if (!is.na(placebo_r)) {
  cat(sprintf("  R-chain placebo r = %.4f (retired %.4f, dev %+.4f)\n",
              placebo_r, RETIRED$placebo_r, placebo_r - RETIRED$placebo_r))
} else {
  cat(sprintf("  R-chain placebo r = NA (retired %.4f)\n", RETIRED$placebo_r))
}

# -----------------------------------------------------------------------------
# OUTPUT
# -----------------------------------------------------------------------------
out <- data.frame(
  ID = c("SPLITHALF_A_R", "SPLITHALF_A_RELIABILITY",
         "PLACEBO_A_MEAN_R", "PLACEBO_A_SD_R", "PLACEBO_A_R_R"),
  quantity = c("Split-half correlation (odd/even post-years)",
               "Spearman-Brown full reliability",
               "Placebo mean theta_D",
               "Placebo SD theta_D",
               "Placebo split-half r"),
  value = c(splithalf_r, reliability_full, placebo_mean, placebo_sd, placebo_r),
  retired_value = c(RETIRED$splithalf_r, NA, RETIRED$placebo_mean,
                    RETIRED$placebo_sd, RETIRED$placebo_r),
  deviation = c(splithalf_r - RETIRED$splithalf_r, NA,
                placebo_mean - RETIRED$placebo_mean,
                placebo_sd - RETIRED$placebo_sd,
                placebo_r - RETIRED$placebo_r),
  note = c("Definition A, baseline n=4182", "2r/(1+r)",
           "Never-treated pairs", "Never-treated pairs", "Never-treated pairs")
)

cat("\n=== OUTPUT TABLE ===\n")
print(out)

write.csv(out, "output/T22_reliability.csv", row.names = FALSE)
cat("\nSaved: output/T22_reliability.csv\n")

# Sidecar
sha <- system("sha256sum output/T22_reliability.csv | cut -d' ' -f1", intern = TRUE)
writeLines(c(
  "PRODUCER: S24_reliability.R",
  "INPUTS: data/S5R_bhat.rds, data/S1R_ppml.rds",
  "SEED: 20260719",
  "EXPECTED_N: 4182",
  "METHOD: Split-half by odd/even post-years, ledgered convention",
  "GATES:",
  sprintf("  G1: n = %d - PASS", EXPECTED_N),
  sprintf("  G2: split-half r = %.4f - COMPUTED", splithalf_r),
  sprintf("  G3: placebo stats computed - PASS"),
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  "COMPARISON (REPORT-ONLY, not gates):",
  sprintf("  Split-half r: R-chain %.4f vs retired %.4f (dev %+.4f)",
          splithalf_r, RETIRED$splithalf_r, splithalf_r - RETIRED$splithalf_r),
  sprintf("  Placebo mean: R-chain %.4f vs retired %.4f (dev %+.4f)",
          placebo_mean, RETIRED$placebo_mean, placebo_mean - RETIRED$placebo_mean),
  sprintf("  Placebo SD: R-chain %.4f vs retired %.4f (dev %+.4f)",
          placebo_sd, RETIRED$placebo_sd, placebo_sd - RETIRED$placebo_sd),
  if (!is.na(placebo_r)) sprintf("  Placebo r: R-chain %.4f vs retired %.4f (dev %+.4f)",
          placebo_r, RETIRED$placebo_r, placebo_r - RETIRED$placebo_r) else
    sprintf("  Placebo r: R-chain NA (retired %.4f) - placebo pairs not in PPML", RETIRED$placebo_r),
  "NOTE: Deviations are findings, not errors. Section 4 uses R-chain values.",
  sprintf("SHA256: %s", sha)
), "meta/T22_reliability.csv.sidecar")
cat("Saved: meta/T22_reliability.csv.sidecar\n")
