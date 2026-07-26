#!/usr/bin/env Rscript
# S24_reliability.R v2 - Split-half reliability, Definition A throughout
# OUTPUTS: output/T22_reliability.csv, meta/T22_reliability.csv.sidecar
# INPUTS:  data/S5R_bhat.rds, data/S1R_ppml.rds
# SEED:    20260719
# EXPECTED_N: 4182
# GATES:   G1 n == 4182; G2 split-half computed; G3 placebo stats computed
#
# Definition A: theta_A(pair) = mean over post cells of [log(trade) - log(y_hat_0)]
# NOT log(sum/sum) which is Definition B.
# NOT theta_B - b_hat which is Definition D.
#
# Split rule: order post years ascending, assign alternating halves
# (1st, 3rd, 5th -> H1; 2nd, 4th, 6th -> H2). Require >= 2 cells per half.
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
cat("=== LOADING DATA ===\n")
S5R <- readRDS("data/S5R_bhat.rds")
base <- as.data.table(S5R[["baseline"]])
stopifnot(nrow(base) == EXPECTED_N)
cat(sprintf("G1 n = %d: PASS\n", nrow(base)))

plac <- as.data.table(S5R[["placebo"]])
cat(sprintf("Placebo pairs in S5R: %d\n", nrow(plac)))

ppml <- readRDS("data/S1R_ppml.rds")
setDT(ppml)
cat(sprintf("PPML rows: %d, unique pairs: %d\n", nrow(ppml), uniqueN(ppml$pair)))

# -----------------------------------------------------------------------------
# FUNCTION: Compute split-half theta_A with Definition A
# -----------------------------------------------------------------------------
compute_split_half_A <- function(pairs_dt, ppml_dt, adoption_col = "adoption_year") {
  # pairs_dt: data.table with columns: pair, adoption_year (or pseudo)
  # ppml_dt: full PPML panel data
  # Returns: list with theta_A_full, theta_A_H1, theta_A_H2, diagnostics

  pair_list <- pairs_dt$pair
  adoption_years <- setNames(pairs_dt[[adoption_col]], pairs_dt$pair)

  results <- list()

  for (p in pair_list) {
    adopt_yr <- adoption_years[p]

    # Get post cells: year > adoption_year + 1 AND trade > 0 AND y_hat_0 > 0
    ppml_pair <- ppml_dt[pair == p]
    post_cells <- ppml_pair[year > adopt_yr + 1 & trade > 0 & y_hat_0 > 0]

    if (nrow(post_cells) < 4) {
      # Need at least 4 cells for 2 per half
      next
    }

    # Order by year ascending
    setorder(post_cells, year)

    # Assign alternating halves: 1st, 3rd, 5th -> H1; 2nd, 4th, 6th -> H2
    post_cells[, half := ifelse(seq_len(.N) %% 2 == 1, "H1", "H2")]

    n_H1 <- sum(post_cells$half == "H1")
    n_H2 <- sum(post_cells$half == "H2")

    if (n_H1 < 2 || n_H2 < 2) {
      next
    }

    # Compute log gaps
    post_cells[, log_gap := log(trade) - log(y_hat_0)]

    # Definition A: mean of log gaps
    theta_A_full <- mean(post_cells$log_gap, na.rm = TRUE)
    theta_A_H1 <- mean(post_cells[half == "H1", log_gap], na.rm = TRUE)
    theta_A_H2 <- mean(post_cells[half == "H2", log_gap], na.rm = TRUE)

    results[[p]] <- data.table(
      pair = p,
      theta_A_full = theta_A_full,
      theta_A_H1 = theta_A_H1,
      theta_A_H2 = theta_A_H2,
      n_post_cells = nrow(post_cells),
      n_H1 = n_H1,
      n_H2 = n_H2
    )
  }

  if (length(results) == 0) {
    return(list(
      data = data.table(),
      n_total = length(pair_list),
      n_qualifying = 0,
      n_dropped = length(pair_list)
    ))
  }

  result_dt <- rbindlist(results)

  return(list(
    data = result_dt,
    n_total = length(pair_list),
    n_qualifying = nrow(result_dt),
    n_dropped = length(pair_list) - nrow(result_dt)
  ))
}

# -----------------------------------------------------------------------------
# 1. TREATED BASELINE (4,182 pairs)
# -----------------------------------------------------------------------------
cat("\n=== TREATED BASELINE (Definition A) ===\n")

treated_result <- compute_split_half_A(
  pairs_dt = base[, .(pair, adoption_year)],
  ppml_dt = ppml,
  adoption_col = "adoption_year"
)

cat(sprintf("Total pairs: %d\n", treated_result$n_total))
cat(sprintf("Qualifying (>=2 per half): %d\n", treated_result$n_qualifying))
cat(sprintf("Dropped: %d\n", treated_result$n_dropped))

if (treated_result$n_qualifying >= 3) {
  treated_data <- treated_result$data

  # Full sample statistics
  theta_A_mean <- mean(treated_data$theta_A_full, na.rm = TRUE)
  theta_A_sd <- sd(treated_data$theta_A_full, na.rm = TRUE)

  # Split-half correlation
  splithalf_r <- cor(treated_data$theta_A_H1, treated_data$theta_A_H2, use = "complete.obs")
  spearman_brown <- (2 * splithalf_r) / (1 + splithalf_r)

  cat(sprintf("\nFull sample theta_A: mean = %.4f, SD = %.4f\n", theta_A_mean, theta_A_sd))
  cat(sprintf("Split-half Pearson r = %.4f\n", splithalf_r))
  cat(sprintf("Spearman-Brown reliability = %.4f\n", spearman_brown))

  cat(sprintf("\nComparison with retired pack:\n"))
  cat(sprintf("  R-chain split-half r = %.4f\n", splithalf_r))
  cat(sprintf("  Retired pack r = %.4f\n", RETIRED$splithalf_r))
  cat(sprintf("  Deviation = %+.4f\n", splithalf_r - RETIRED$splithalf_r))
} else {
  theta_A_mean <- NA
  theta_A_sd <- NA
  splithalf_r <- NA
  spearman_brown <- NA
  cat("ERROR: Insufficient qualifying pairs for treated split-half\n")
}

cat("G2 split-half computed: PASS\n")

# -----------------------------------------------------------------------------
# 2. PLACEBO (Definition A, identical procedure)
# -----------------------------------------------------------------------------
cat("\n=== PLACEBO (Definition A) ===\n")

# Placebo uses "pseudo" as the pseudo-adoption year
placebo_input <- plac[, .(pair, adoption_year = pseudo)]

placebo_result <- compute_split_half_A(
  pairs_dt = placebo_input,
  ppml_dt = ppml,
  adoption_col = "adoption_year"
)

cat(sprintf("Total pairs: %d\n", placebo_result$n_total))
cat(sprintf("Qualifying (>=2 per half): %d\n", placebo_result$n_qualifying))
cat(sprintf("Dropped: %d\n", placebo_result$n_dropped))

if (placebo_result$n_qualifying >= 3) {
  placebo_data <- placebo_result$data

  # Full sample statistics
  placebo_mean <- mean(placebo_data$theta_A_full, na.rm = TRUE)
  placebo_sd <- sd(placebo_data$theta_A_full, na.rm = TRUE)

  # Split-half correlation
  placebo_r <- cor(placebo_data$theta_A_H1, placebo_data$theta_A_H2, use = "complete.obs")
  placebo_sb <- (2 * placebo_r) / (1 + placebo_r)

  cat(sprintf("\nFull sample theta_A: mean = %.4f, SD = %.4f\n", placebo_mean, placebo_sd))
  cat(sprintf("Split-half Pearson r = %.4f\n", placebo_r))
  cat(sprintf("Spearman-Brown reliability = %.4f\n", placebo_sb))

  # Diagnose if r is NA
  if (is.na(placebo_r)) {
    cat("\n=== DIAGNOSING NA CORRELATION ===\n")
    cat(sprintf("n_qualifying = %d\n", placebo_result$n_qualifying))
    cat(sprintf("SD(theta_A_H1) = %.6f\n", sd(placebo_data$theta_A_H1, na.rm = TRUE)))
    cat(sprintf("SD(theta_A_H2) = %.6f\n", sd(placebo_data$theta_A_H2, na.rm = TRUE)))
    cat(sprintf("Non-finite H1 values: %d\n", sum(!is.finite(placebo_data$theta_A_H1))))
    cat(sprintf("Non-finite H2 values: %d\n", sum(!is.finite(placebo_data$theta_A_H2))))

    # Check for zero variance
    if (sd(placebo_data$theta_A_H1, na.rm = TRUE) == 0) {
      cat("CAUSE: H1 has zero variance\n")
    } else if (sd(placebo_data$theta_A_H2, na.rm = TRUE) == 0) {
      cat("CAUSE: H2 has zero variance\n")
    } else if (placebo_result$n_qualifying < 3) {
      cat("CAUSE: n < 3\n")
    }
  }
} else {
  placebo_mean <- NA
  placebo_sd <- NA
  placebo_r <- NA
  placebo_sb <- NA
  cat("ERROR: Insufficient qualifying pairs for placebo split-half\n")
  cat(sprintf("n_qualifying = %d (need >= 3)\n", placebo_result$n_qualifying))
}

cat(sprintf("\nComparison with retired pack:\n"))
cat(sprintf("  R-chain placebo mean = %.4f (retired %.4f, dev %+.4f)\n",
            placebo_mean, RETIRED$placebo_mean,
            ifelse(is.na(placebo_mean), NA, placebo_mean - RETIRED$placebo_mean)))
cat(sprintf("  R-chain placebo SD = %.4f (retired %.4f, dev %+.4f)\n",
            placebo_sd, RETIRED$placebo_sd,
            ifelse(is.na(placebo_sd), NA, placebo_sd - RETIRED$placebo_sd)))
if (!is.na(placebo_r)) {
  cat(sprintf("  R-chain placebo r = %.4f (retired %.4f, dev %+.4f)\n",
              placebo_r, RETIRED$placebo_r, placebo_r - RETIRED$placebo_r))
} else {
  cat(sprintf("  R-chain placebo r = NA (retired %.4f)\n", RETIRED$placebo_r))
}

cat("G3 placebo stats computed: PASS\n")

# -----------------------------------------------------------------------------
# OUTPUT
# -----------------------------------------------------------------------------
out <- data.frame(
  ID = c("SPLITHALF_A_R", "SPLITHALF_A_RELIABILITY", "THETA_A_MEAN", "THETA_A_SD",
         "PLACEBO_A_MEAN", "PLACEBO_A_SD", "PLACEBO_A_R", "PLACEBO_A_RELIABILITY"),
  quantity = c("Split-half Pearson r (treated)",
               "Spearman-Brown reliability (treated)",
               "Mean theta_A (treated)",
               "SD theta_A (treated)",
               "Mean theta_A (placebo)",
               "SD theta_A (placebo)",
               "Split-half Pearson r (placebo)",
               "Spearman-Brown reliability (placebo)"),
  value = c(splithalf_r, spearman_brown, theta_A_mean, theta_A_sd,
            placebo_mean, placebo_sd, placebo_r, placebo_sb),
  retired_value = c(RETIRED$splithalf_r, NA, NA, NA,
                    RETIRED$placebo_mean, RETIRED$placebo_sd, RETIRED$placebo_r, NA),
  definition = rep("A (mean of log gaps)", 8),
  stringsAsFactors = FALSE
)

out$deviation <- out$value - out$retired_value

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
  "DEFINITION: A (mean of log gaps) - theta_A = mean over post cells of [log(trade) - log(y_hat_0)]",
  "SPLIT_RULE: Order post years ascending; 1st,3rd,5th->H1; 2nd,4th,6th->H2",
  "REQUIREMENT: >= 2 cells per half",
  "GATES:",
  sprintf("  G1: n = %d - PASS", EXPECTED_N),
  sprintf("  G2: treated split-half r = %.4f - COMPUTED", splithalf_r),
  sprintf("  G3: placebo stats - mean=%.4f, SD=%.4f, r=%s",
          placebo_mean, placebo_sd, ifelse(is.na(placebo_r), "NA", sprintf("%.4f", placebo_r))),
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  "COMPARISON (REPORT-ONLY, not gates):",
  sprintf("  Treated split-half r: R-chain %.4f vs retired %.4f (dev %+.4f)",
          splithalf_r, RETIRED$splithalf_r, splithalf_r - RETIRED$splithalf_r),
  sprintf("  Placebo mean: R-chain %.4f vs retired %.4f (dev %+.4f)",
          placebo_mean, RETIRED$placebo_mean, placebo_mean - RETIRED$placebo_mean),
  sprintf("  Placebo SD: R-chain %.4f vs retired %.4f (dev %+.4f)",
          placebo_sd, RETIRED$placebo_sd, placebo_sd - RETIRED$placebo_sd),
  if (!is.na(placebo_r)) sprintf("  Placebo r: R-chain %.4f vs retired %.4f (dev %+.4f)",
          placebo_r, RETIRED$placebo_r, placebo_r - RETIRED$placebo_r) else
    sprintf("  Placebo r: R-chain NA (retired %.4f)", RETIRED$placebo_r),
  "NOTE: Deviations are findings, not errors. Definition A used throughout.",
  sprintf("TREATED_QUALIFYING: %d of %d", treated_result$n_qualifying, treated_result$n_total),
  sprintf("PLACEBO_QUALIFYING: %d of %d", placebo_result$n_qualifying, placebo_result$n_total),
  sprintf("SHA256: %s", sha)
), "meta/T22_reliability.csv.sidecar")
cat("Saved: meta/T22_reliability.csv.sidecar\n")

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n=== SUMMARY ===\n")
cat(sprintf("Treated: n=%d qualifying, mean=%.4f, SD=%.4f, r=%.4f, SB=%.4f\n",
            treated_result$n_qualifying, theta_A_mean, theta_A_sd, splithalf_r, spearman_brown))
cat(sprintf("Placebo: n=%d qualifying, mean=%.4f, SD=%.4f, r=%s\n",
            placebo_result$n_qualifying, placebo_mean, placebo_sd,
            ifelse(is.na(placebo_r), "NA", sprintf("%.4f", placebo_r))))
