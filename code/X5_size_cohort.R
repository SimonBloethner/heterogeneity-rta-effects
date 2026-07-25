#!/usr/bin/env Rscript
# X5: Size Link and Cohort Analysis
# Canonical population, Definition D only

cat("========================================================================\n")
cat("X5: SIZE LINK AND COHORT ANALYSIS\n")
cat("Start:", format(Sys.time()), "\n")
cat("========================================================================\n\n")

suppressPackageStartupMessages({
    library(data.table)
})

set.seed(20260721)

# -----------------------------------------------------------------------------
# STEP 0: Load data
# -----------------------------------------------------------------------------
cat("STEP 0: Loading data...\n")

# Canonical population
w1 <- as.data.table(readRDS("/scratch/bt307958/W1_pop_canon.rds"))
cat("  W1 canonical pairs:", nrow(w1), "\n")
stopifnot(nrow(w1) == 4182)

# O1 for theta_D and adoption_year
o1 <- as.data.table(readRDS("/scratch/bt307958/O1_switcher_theta.rds"))

# Merge
merged <- merge(w1[, .(pair, s_hat)], o1[, .(pair, theta_D, adoption_year, size_decile)], 
                by = "pair", all.x = TRUE)
merged <- merged[!is.na(theta_D)]
cat("  Merged pairs:", nrow(merged), "\n")

# Load raw trade data to compute pre-adoption mean trade
raw_data <- as.data.table(readRDS("/scratch/bt307958/N0_data.rds"))
cat("  Raw data loaded:", nrow(raw_data), "\n")

# Pair trade for weights
pair_trade <- as.data.table(readRDS("/scratch/bt307958/N0_pair_trade.rds"))

# Merge trade weights
merged <- merge(merged, pair_trade[, .(pair, total_trade)], by = "pair", all.x = TRUE)
merged[is.na(total_trade), total_trade := 0]
merged[, trade_weight := total_trade / sum(total_trade)]

# -----------------------------------------------------------------------------
# Compute pre-adoption mean trade for each pair
# -----------------------------------------------------------------------------
cat("\nComputing pre-adoption mean trade...\n")

# Get pre-adoption trade for each pair
compute_pre_mean <- function(pair_id, adopt_yr, data) {
    pair_data <- data[pair == pair_id & year < adopt_yr]
    if (nrow(pair_data) == 0) return(NA_real_)
    mean(pair_data$trade, na.rm = TRUE)
}

# Vectorized version
pre_means <- raw_data[, .(pre_mean_trade = mean(trade[year < adopt_yr[1]], na.rm = TRUE)),
                       by = .(pair, adopt_yr = merged$adoption_year[match(pair, merged$pair)])]

# Filter to pairs in merged
pre_means <- pre_means[pair %in% merged$pair]
pre_means <- pre_means[!is.na(adopt_yr)]

# Actually, let me do this more carefully
merged[, pre_mean_trade := NA_real_]
for (i in 1:nrow(merged)) {
    p <- merged$pair[i]
    ay <- merged$adoption_year[i]
    pre_data <- raw_data[pair == p & year < ay, trade]
    if (length(pre_data) > 0) {
        merged$pre_mean_trade[i] <- mean(pre_data, na.rm = TRUE)
    }
}

n_valid_pre <- sum(!is.na(merged$pre_mean_trade) & merged$pre_mean_trade > 0)
cat("  Pairs with valid pre-adoption trade:", n_valid_pre, "\n")

# Log pre-adoption mean
merged[, log_pre_mean := log(pre_mean_trade)]
merged_valid <- merged[!is.na(log_pre_mean) & is.finite(log_pre_mean)]
cat("  Pairs with finite log pre-mean:", nrow(merged_valid), "\n\n")

# -----------------------------------------------------------------------------
# Global assertions
# -----------------------------------------------------------------------------
cat("GLOBAL ASSERTIONS:\n")
global_mean <- mean(merged$theta_D, na.rm = TRUE)
global_tw_mean <- sum(merged$theta_D * merged$trade_weight, na.rm = TRUE)

cat(sprintf("  Mean theta_D = %.4f (target: 0.2138 ± 0.002)\n", global_mean))
stopifnot(abs(global_mean - 0.2138) <= 0.002)
cat("    PASS\n")

cat(sprintf("  TW Mean theta_D = %.4f (target: 0.1412 ± 0.003)\n", global_tw_mean))
stopifnot(abs(global_tw_mean - 0.1412) <= 0.003)
cat("    PASS\n\n")

# -----------------------------------------------------------------------------
# (a) SIZE LINK
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("(a) SIZE LINK: Correlation(theta_D, log pre-adoption mean trade)\n")
cat("========================================================================\n\n")

# Point estimates
pearson_r <- cor(merged_valid$theta_D, merged_valid$log_pre_mean, method = "pearson")
spearman_r <- cor(merged_valid$theta_D, merged_valid$log_pre_mean, method = "spearman")

cat(sprintf("Point estimates (n=%d):\n", nrow(merged_valid)))
cat(sprintf("  Pearson r: %.4f\n", pearson_r))
cat(sprintf("  Spearman rho: %.4f\n", spearman_r))

# Bootstrap CIs
n_boot <- 500
boot_pearson <- numeric(n_boot)
boot_spearman <- numeric(n_boot)

cat("\nBootstrapping 500 reps...\n")
for (b in 1:n_boot) {
    idx <- sample(nrow(merged_valid), replace = TRUE)
    boot_pearson[b] <- cor(merged_valid$theta_D[idx], merged_valid$log_pre_mean[idx], method = "pearson")
    boot_spearman[b] <- cor(merged_valid$theta_D[idx], merged_valid$log_pre_mean[idx], method = "spearman")
}

pearson_ci <- quantile(boot_pearson, c(0.025, 0.975))
spearman_ci <- quantile(boot_spearman, c(0.025, 0.975))

cat(sprintf("  Pearson 95%% CI: [%.4f, %.4f]\n", pearson_ci[1], pearson_ci[2]))
cat(sprintf("  Spearman 95%% CI: [%.4f, %.4f]\n", spearman_ci[1], spearman_ci[2]))

# Quintile analysis
cat("\nMean theta_D by pre-adoption size quintile:\n")
merged_valid[, size_quintile := cut(log_pre_mean, 
                                     breaks = quantile(log_pre_mean, probs = seq(0, 1, 0.2)),
                                     labels = 1:5, include.lowest = TRUE)]

quintile_stats <- merged_valid[, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE)
), by = size_quintile][order(size_quintile)]

# Bootstrap CIs for quintile means
cat("Computing quintile bootstrap CIs...\n")
quintile_boot <- matrix(NA, n_boot, 5)
for (b in 1:n_boot) {
    idx <- sample(nrow(merged_valid), replace = TRUE)
    boot_data <- merged_valid[idx]
    boot_data[, size_quintile := cut(log_pre_mean, 
                                      breaks = quantile(merged_valid$log_pre_mean, probs = seq(0, 1, 0.2)),
                                      labels = 1:5, include.lowest = TRUE)]
    boot_means <- boot_data[, mean(theta_D, na.rm = TRUE), by = size_quintile][order(size_quintile)]
    for (q in 1:5) {
        if (q <= nrow(boot_means)) {
            quintile_boot[b, q] <- boot_means$V1[q]
        }
    }
}

quintile_ci_low <- apply(quintile_boot, 2, quantile, probs = 0.025, na.rm = TRUE)
quintile_ci_high <- apply(quintile_boot, 2, quantile, probs = 0.975, na.rm = TRUE)

# -----------------------------------------------------------------------------
# OUTPUT: X5-1
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("X5-1: SIZE LINK TABLE\n")
cat("========================================================================\n\n")

cat("Correlations (n =", nrow(merged_valid), "):\n")
cat(sprintf("  %-12s %10s %20s\n", "Measure", "Estimate", "95% Bootstrap CI"))
cat(paste(rep("-", 45), collapse = ""), "\n")
cat(sprintf("  %-12s %10.4f [%7.4f, %7.4f]\n", "Pearson", pearson_r, pearson_ci[1], pearson_ci[2]))
cat(sprintf("  %-12s %10.4f [%7.4f, %7.4f]\n", "Spearman", spearman_r, spearman_ci[1], spearman_ci[2]))

cat("\nMean theta_D by pre-adoption size quintile:\n")
cat(sprintf("  %-10s %6s %12s %20s\n", "Quintile", "n", "Mean_theta_D", "95% Bootstrap CI"))
cat(paste(rep("-", 52), collapse = ""), "\n")
for (i in 1:nrow(quintile_stats)) {
    cat(sprintf("  %-10s %6d %12.4f [%7.4f, %7.4f]\n",
                paste0("Q", quintile_stats$size_quintile[i]),
                quintile_stats$n[i],
                quintile_stats$mean_theta_D[i],
                quintile_ci_low[i],
                quintile_ci_high[i]))
}

# -----------------------------------------------------------------------------
# (b) COHORTS
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("(b) COHORTS: Adoption cohort analysis\n")
cat("========================================================================\n\n")

# Pre-2008 vs 2008+
merged[, cohort := ifelse(adoption_year < 2008, "pre-2008", "2008+")]

cohort_stats <- merged[, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE),
    tw_mean = sum(theta_D * trade_weight, na.rm = TRUE) / sum(trade_weight, na.rm = TRUE),
    sd_theta_D = sd(theta_D, na.rm = TRUE)
), by = cohort][order(cohort)]

# Correct tw_mean calculation (need global weights)
cohort_stats_tw <- merged[, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE),
    tw_mean = sum(theta_D * trade_weight, na.rm = TRUE),
    sd_theta_D = sd(theta_D, na.rm = TRUE)
), by = cohort][order(cohort)]

# By year (1991-2016)
year_stats <- merged[adoption_year >= 1991 & adoption_year <= 2016, .(
    n = .N,
    mean_theta_D = mean(theta_D, na.rm = TRUE),
    tw_mean = sum(theta_D * trade_weight, na.rm = TRUE),
    sd_theta_D = sd(theta_D, na.rm = TRUE)
), by = adoption_year][order(adoption_year)]

# Global row
global_row <- data.table(
    adoption_year = "GLOBAL",
    n = nrow(merged),
    mean_theta_D = global_mean,
    tw_mean = global_tw_mean,
    sd_theta_D = sd(merged$theta_D, na.rm = TRUE)
)

# -----------------------------------------------------------------------------
# OUTPUT: X5-2
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("X5-2: COHORT TABLES\n")
cat("========================================================================\n\n")

cat("Pre-2008 vs 2008+ cohorts:\n")
cat(sprintf("  %-10s %6s %12s %12s %12s\n", "Cohort", "n", "Mean", "TW_Mean", "SD"))
cat(paste(rep("-", 56), collapse = ""), "\n")
for (i in 1:nrow(cohort_stats_tw)) {
    cat(sprintf("  %-10s %6d %12.4f %12.4f %12.4f\n",
                cohort_stats_tw$cohort[i],
                cohort_stats_tw$n[i],
                cohort_stats_tw$mean_theta_D[i],
                cohort_stats_tw$tw_mean[i],
                cohort_stats_tw$sd_theta_D[i]))
}
cat(sprintf("  %-10s %6d %12.4f %12.4f %12.4f\n",
            "GLOBAL", nrow(merged), global_mean, global_tw_mean, sd(merged$theta_D)))

cat("\nBy adoption year (1991-2016):\n")
cat(sprintf("  %-6s %6s %12s %12s %12s\n", "Year", "n", "Mean", "TW_Mean", "SD"))
cat(paste(rep("-", 52), collapse = ""), "\n")
for (i in 1:nrow(year_stats)) {
    cat(sprintf("  %-6d %6d %12.4f %12.4f %12.4f\n",
                year_stats$adoption_year[i],
                year_stats$n[i],
                year_stats$mean_theta_D[i],
                year_stats$tw_mean[i],
                year_stats$sd_theta_D[i]))
}

# -----------------------------------------------------------------------------
# LEDGER
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("LEDGER ENTRIES\n")
cat("========================================================================\n")

cat(sprintf("SIZE_THETA_CORR = Pearson %.4f [%.4f, %.4f], Spearman %.4f [%.4f, %.4f]\n",
            pearson_r, pearson_ci[1], pearson_ci[2],
            spearman_r, spearman_ci[1], spearman_ci[2]))

cat(sprintf("COHORT_MEANS = pre2008 %.4f (n=%d), 2008+ %.4f (n=%d)\n",
            cohort_stats_tw[cohort == "pre-2008", mean_theta_D],
            cohort_stats_tw[cohort == "pre-2008", n],
            cohort_stats_tw[cohort == "2008+", mean_theta_D],
            cohort_stats_tw[cohort == "2008+", n]))

# Save results
saveRDS(list(
    correlations = list(
        pearson = pearson_r,
        pearson_ci = pearson_ci,
        spearman = spearman_r,
        spearman_ci = spearman_ci
    ),
    quintile_stats = quintile_stats,
    quintile_ci = list(low = quintile_ci_low, high = quintile_ci_high),
    cohort_stats = cohort_stats_tw,
    year_stats = year_stats,
    global = list(mean = global_mean, tw_mean = global_tw_mean)
), "/scratch/bt307958/X5_results.rds")

cat("\nX5 COMPLETE:", format(Sys.time()), "\n")
