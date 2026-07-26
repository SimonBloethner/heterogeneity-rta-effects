# S1 — Population Reconciliation (blocking)
# Reconcile G0 baseline with O1

library(data.table)

cat("=== S1: Population Reconciliation ===\n\n")

# ============================================================
# PART A: Load all pair lists
# ============================================================
cat("========== PART A: Load Pair Lists ==========\n\n")

# Load O1 switcher theta (n=10,248)
theta_O1 <- readRDS("/scratch/bt307958/O1_switcher_theta.rds")
setDT(theta_O1)
pairs_O1 <- theta_O1$pair
cat(sprintf("O1_switcher_theta.rds: %d pairs\n", length(pairs_O1)))

# Load G0 baseline
cat("\nLoading G0_results.RData...\n")
load("/groups/m-larch/bt307958/gates/G0_results.RData")
cat("Objects loaded:\n")
print(ls())

# Check what G0 contains
if(exists("pairs_G0")) {
  cat(sprintf("pairs_G0: %d pairs\n", length(pairs_G0)))
} 
if(exists("baseline_pairs")) {
  cat(sprintf("baseline_pairs: %d pairs\n", length(baseline_pairs)))
}
if(exists("switcher_theta")) {
  cat(sprintf("switcher_theta rows: %d\n", nrow(switcher_theta)))
}

# Load main data for (3,3) rule computation
main <- readRDS("/scratch/bt307958/N0_data.rds")
setDT(main)

# Compute (3,3) rule pairs
pair_obs <- main[!is.na(adoption_year), .(
  n_pre = sum(post == FALSE, na.rm = TRUE),
  n_post = sum(post == TRUE, na.rm = TRUE),
  adoption_year = unique(adoption_year)[1]
), by = pair]

pairs_33 <- pair_obs[n_pre >= 3 & n_post >= 3, pair]
cat(sprintf("\nPairs satisfying (3,3) rule: %d\n", length(pairs_33)))

# Load Q1 for comparison
Q1 <- readRDS("/scratch/bt307958/Q1_results.rds")
pairs_Q1 <- Q1$switcher_ratios$pair
cat(sprintf("Q1 switcher_ratios: %d pairs\n", length(pairs_Q1)))

# ============================================================
# PART B: Identify the baseline population
# ============================================================
cat("\n\n========== PART B: Baseline Population ==========\n\n")

# Check G0 structure
if(exists("g0_theta") && is.data.frame(g0_theta)) {
  pairs_G0 <- g0_theta$pair
  cat(sprintf("G0 theta pairs: %d\n", length(pairs_G0)))
}

# Use (3,3) filtered as the baseline (matches R2's 5,062)
pairs_baseline <- pairs_33
cat(sprintf("Baseline (3,3) pairs: %d\n", length(pairs_baseline)))

# ============================================================
# PART C: Compare populations
# ============================================================
cat("\n\n========== PART C: Population Comparison ==========\n\n")

intersection <- intersect(pairs_O1, pairs_baseline)
O1_only <- setdiff(pairs_O1, pairs_baseline)
baseline_only <- setdiff(pairs_baseline, pairs_O1)

cat(sprintf("O1 pairs: %d\n", length(pairs_O1)))
cat(sprintf("Baseline (3,3) pairs: %d\n", length(pairs_baseline)))
cat(sprintf("Intersection: %d\n", length(intersection)))
cat(sprintf("O1 only (fail (3,3)): %d\n", length(O1_only)))
cat(sprintf("Baseline only (not in O1): %d\n", length(baseline_only)))

# Characterize O1-only residual (pairs failing (3,3))
if(length(O1_only) > 0) {
  cat("\n--- O1-only pairs (fail (3,3) rule) ---\n")
  o1_only_stats <- pair_obs[pair %in% O1_only]
  cat(sprintf("  Count: %d\n", nrow(o1_only_stats)))
  cat(sprintf("  Median n_pre: %.1f\n", median(o1_only_stats$n_pre, na.rm = TRUE)))
  cat(sprintf("  Median n_post: %.1f\n", median(o1_only_stats$n_post, na.rm = TRUE)))
  cat(sprintf("  n_pre < 3: %d (%.1f%%)\n", sum(o1_only_stats$n_pre < 3), 
              100 * mean(o1_only_stats$n_pre < 3)))
  cat(sprintf("  n_post < 3: %d (%.1f%%)\n", sum(o1_only_stats$n_post < 3),
              100 * mean(o1_only_stats$n_post < 3)))
  
  # Check for multi-switch or timing issues
  cat("\n  Adoption year distribution:\n")
  print(summary(o1_only_stats$adoption_year))
}

# Characterize baseline-only (in (3,3) but not in O1)
if(length(baseline_only) > 0) {
  cat("\n--- Baseline-only pairs (not in O1) ---\n")
  cat(sprintf("  Count: %d\n", length(baseline_only)))
  bl_stats <- pair_obs[pair %in% baseline_only]
  if(nrow(bl_stats) > 0) {
    cat(sprintf("  Median n_pre: %.1f\n", median(bl_stats$n_pre, na.rm = TRUE)))
    cat(sprintf("  Median n_post: %.1f\n", median(bl_stats$n_post, na.rm = TRUE)))
  }
}

# ============================================================
# PART D: Canonical estimates on intersection
# ============================================================
cat("\n\n========== PART D: Canonical Estimates ==========\n\n")

# Filter theta_O1 to intersection
theta_canonical <- theta_O1[pair %in% intersection]
cat(sprintf("Canonical population: %d pairs\n", nrow(theta_canonical)))

# Mean θ̂_D
mean_theta <- mean(theta_canonical$theta_D, na.rm = TRUE)
cat(sprintf("\nMean θ̂_D (unweighted): %.4f\n", mean_theta))

# Trade-weighted mean
pair_trade <- readRDS("/scratch/bt307958/N0_pair_trade.rds")
setDT(pair_trade)
theta_canonical <- merge(theta_canonical, pair_trade[, .(pair, total_trade)], by = "pair", all.x = TRUE)

# Handle missing trade weights
theta_canonical[is.na(total_trade), total_trade := 0]
if(sum(theta_canonical$total_trade, na.rm = TRUE) > 0) {
  tw_mean <- sum(theta_canonical$theta_D * theta_canonical$total_trade, na.rm = TRUE) / 
             sum(theta_canonical$total_trade, na.rm = TRUE)
  cat(sprintf("Trade-weighted mean: %.4f\n", tw_mean))
} else {
  tw_mean <- mean_theta
  cat("Trade-weighted mean: N/A (no trade weights)\n")
}

# SD
sd_theta <- sd(theta_canonical$theta_D, na.rm = TRUE)
cat(sprintf("SD (raw): %.4f\n", sd_theta))

# P(θ̂ ≤ 0)
p_neg <- mean(theta_canonical$theta_D <= 0, na.rm = TRUE)
cat(sprintf("P(θ̂_D ≤ 0): %.1f%%\n", 100 * p_neg))

# ============================================================
# PART E: Deconvolution on canonical population
# ============================================================
cat("\n\n========== PART E: Deconvolution ==========\n\n")

# Load placebo theta
placebo_theta <- readRDS("/scratch/bt307958/O1_placebo_theta.rds")
setDT(placebo_theta)

# For consistent comparison, we need placebos with similar (3,3) structure
# Get placebo pairs that also satisfy (3,3)
main_nr <- main[is.na(adoption_year)]
main_nr[, pseudo_post := year >= 2001]

placebo_pair_obs <- main_nr[, .(
  n_pre = sum(pseudo_post == FALSE, na.rm = TRUE),
  n_post = sum(pseudo_post == TRUE, na.rm = TRUE)
), by = pair]
placebo_33 <- placebo_pair_obs[n_pre >= 3 & n_post >= 3, pair]

cat(sprintf("Placebo pairs satisfying (3,3): %d\n", length(placebo_33)))

# Filter placebo to (3,3) pairs
placebo_canonical <- placebo_theta[pair %in% placebo_33]
cat(sprintf("Placebo canonical: %d pairs\n", nrow(placebo_canonical)))

# Variances
placebo_var <- var(placebo_canonical$theta_D, na.rm = TRUE)
real_var <- var(theta_canonical$theta_D, na.rm = TRUE)

cat(sprintf("\nPlacebo variance (canonical): %.4f\n", placebo_var))
cat(sprintf("Real variance (canonical): %.4f\n", real_var))

# Deconvolution
deconv_var <- real_var - placebo_var
if(deconv_var < 0) {
  cat("Warning: Deconvolved variance negative, setting to 0\n")
  deconv_var <- 0
}
deconv_sd <- sqrt(deconv_var)

cat(sprintf("\nDeconvolved variance: %.4f\n", deconv_var))
cat(sprintf("Deconvolved SD: %.4f\n", deconv_sd))

# Bootstrap CI
set.seed(42)
n_boot <- 1000
boot_sd <- numeric(n_boot)
for(i in 1:n_boot) {
  real_boot <- sample(theta_canonical$theta_D, replace = TRUE)
  plac_boot <- sample(placebo_canonical$theta_D, replace = TRUE)
  var_diff <- var(real_boot) - var(plac_boot)
  boot_sd[i] <- sqrt(max(0, var_diff))
}

sd_ci <- quantile(boot_sd, c(0.025, 0.975))
cat(sprintf("Deconvolved SD 95%% CI: [%.4f, %.4f]\n", sd_ci[1], sd_ci[2]))

# ============================================================
# PART F: Summary
# ============================================================
cat("\n\n==========================================\n")
cat("S1 SUMMARY: CANONICAL POPULATION\n")
cat("==========================================\n\n")

cat("DEFINITION OF CANONICAL POPULATION:\n")
cat("  RTA switchers satisfying (3,3) rule:\n")
cat("    - Adopt RTA during sample period\n")
cat("    - ≥3 pre-adoption observations\n")
cat("    - ≥3 post-adoption observations\n")
cat(sprintf("  n = %d pairs\n", nrow(theta_canonical)))

cat("\nCANONICAL ESTIMATES (S1):\n")
cat(sprintf("  Mean θ̂_D: %.4f\n", mean_theta))
cat(sprintf("  Trade-weighted mean: %.4f\n", tw_mean))
cat(sprintf("  SD (raw): %.4f\n", sd_theta))
cat(sprintf("  SD (deconvolved): %.4f\n", deconv_sd))
cat(sprintf("  SD 95%% CI: [%.4f, %.4f]\n", sd_ci[1], sd_ci[2]))
cat(sprintf("  P(θ̂_D ≤ 0): %.1f%%\n", 100 * p_neg))

cat("\nPREDICTION CHECK:\n")
cat(sprintf("  Mean in [0.25, 0.32]? %.4f → %s\n", mean_theta,
            ifelse(mean_theta >= 0.25 & mean_theta <= 0.32, "YES", "NO")))
cat(sprintf("  SD bracket [0.20, 0.29]? %.4f → %s\n", deconv_sd,
            ifelse(deconv_sd >= 0.20 & deconv_sd <= 0.29, "YES", 
                   ifelse(deconv_sd >= 0.15 & deconv_sd <= 0.35, "NEAR", "NO"))))

cat("\nNUMERATOR-NULL AGREEMENT:\n")
cat(sprintf("  Real population (canonical): %d pairs\n", nrow(theta_canonical)))
cat(sprintf("  Placebo population (canonical): %d pairs\n", nrow(placebo_canonical)))
cat("  Both filtered by same (3,3) rule: YES\n")

# Save
S1 <- list(
  canonical_n = nrow(theta_canonical),
  canonical_pairs = theta_canonical$pair,
  definition = "RTA switchers with (3,3) rule: ≥3 pre and ≥3 post observations",
  mean_theta_D = mean_theta,
  tw_mean = tw_mean,
  sd_raw = sd_theta,
  sd_deconv = deconv_sd,
  sd_ci_95 = as.numeric(sd_ci),
  p_negative = p_neg,
  population_comparison = list(
    O1_total = length(pairs_O1),
    baseline_33 = length(pairs_baseline),
    intersection = length(intersection),
    O1_only = length(O1_only),
    baseline_only = length(baseline_only)
  ),
  placebo_n = nrow(placebo_canonical),
  placebo_var = placebo_var,
  real_var = real_var,
  deconv_var = deconv_var
)

saveRDS(S1, "/scratch/bt307958/S1_results.rds")
saveRDS(theta_canonical, "/scratch/bt307958/S1_canonical_theta.rds")
cat("\n\nS1 results saved.\n")
