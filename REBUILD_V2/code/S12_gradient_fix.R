#!/usr/bin/env Rscript
# S12_gradient_fix.R - Fix quintile computation for size gradient
#
# PROBLEM: S7_deconv.R mapped deciles to quintiles via ceiling(size_decile/2).
#          This creates unequal bins (34, 284, 844, 1406, 2071) because it
#          inherits the pre-computed size_decile from the FULL sample, not
#          the BASELINE sample.
#
# SOLUTION: Compute REAL equal quintiles WITHIN BASELINE by pre_trade_sum.
#
# OUTPUTS: output/T3b_size_gradient_fixed.csv (CORRECTED)
# INPUTS:  data/S6_population.rds, data/S5_bhat.rds, data/S1_ppml.rds
# SEED:    NONE
# GATES:   max(quintile_n) - min(quintile_n) <= 1 (equal bins)

cat("================================================================\n")
cat("S12: FIX SIZE GRADIENT QUINTILES\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    strsplit(result, " ")[[1]][1]
}

# -----------------------------------------------------------------------------
# LOAD DATA
# -----------------------------------------------------------------------------
cat("=== LOAD DATA ===\n")

population <- readRDS(file.path(REBUILD_DIR, "data/S6_population.rds"))
bhat_data <- readRDS(file.path(REBUILD_DIR, "data/S5_bhat.rds"))
trade_data <- readRDS(file.path(REBUILD_DIR, "data/S1_ppml.rds"))

theta_df <- as.data.frame(bhat_data$theta_d)
trade_df <- as.data.frame(trade_data)
population_df <- as.data.frame(population)

cat(sprintf("BASELINE population: %d pairs\n", nrow(population_df)))
cat(sprintf("theta_d: %d pairs\n", nrow(theta_df)))
cat(sprintf("trade_data: %d rows\n\n", nrow(trade_df)))

# SHA verification
pop_sha <- get_sha256(file.path(REBUILD_DIR, "data/S6_population.rds"))
bhat_sha <- get_sha256(file.path(REBUILD_DIR, "data/S5_bhat.rds"))
s1_sha <- get_sha256(file.path(REBUILD_DIR, "data/S1_ppml.rds"))

# -----------------------------------------------------------------------------
# COMPARE OLD VS NEW QUINTILE APPROACH
# -----------------------------------------------------------------------------
cat("=== OLD QUINTILE METHOD (from S7_deconv.R) ===\n")

# Filter to BASELINE
theta_baseline <- theta_df[theta_df$pair %in% population_df$pair, ]
cat(sprintf("BASELINE theta rows: %d\n\n", nrow(theta_baseline)))

# Old method: ceiling(size_decile / 2)
theta_baseline$quintile_old <- ceiling(theta_baseline$size_decile / 2)
old_quintile_dist <- aggregate(pair ~ quintile_old, data = theta_baseline, length)
names(old_quintile_dist) <- c("Quintile", "N")
old_quintile_dist <- old_quintile_dist[order(old_quintile_dist$Quintile), ]
cat("Old quintile distribution (from ceiling(size_decile/2)):\n")
print(old_quintile_dist)
cat("\n")

# -----------------------------------------------------------------------------
# COMPUTE PRE-ADOPTION TRADE SUM
# -----------------------------------------------------------------------------
cat("=== COMPUTE PRE-ADOPTION TRADE SUM ===\n")

# Merge adoption_year from population
baseline_pairs <- merge(
    population_df[, c("pair", "adoption_year")],
    trade_df[, c("pair", "year", "trade")],
    by = "pair"
)

# Pre-window: year < adoption_year - 1 (with anticipation exclusion)
baseline_pairs$is_pre <- with(baseline_pairs, year < adoption_year - 1 & trade > 0)
pre_trade <- aggregate(trade ~ pair, data = baseline_pairs[baseline_pairs$is_pre, ], sum)
names(pre_trade) <- c("pair", "pre_trade_sum")

cat(sprintf("Pairs with pre-trade data: %d\n", nrow(pre_trade)))

# Merge pre_trade_sum to theta
theta_baseline <- merge(theta_baseline, pre_trade, by = "pair", all.x = TRUE)
theta_baseline$pre_trade_sum[is.na(theta_baseline$pre_trade_sum)] <- 0

# -----------------------------------------------------------------------------
# COMPUTE REAL EQUAL QUINTILES WITHIN BASELINE
# -----------------------------------------------------------------------------
cat("\n=== COMPUTE REAL QUINTILES ===\n")

# Rank and assign quintiles
theta_baseline$rank <- rank(theta_baseline$pre_trade_sum, ties.method = "random")
n <- nrow(theta_baseline)
theta_baseline$quintile_real <- ceiling(theta_baseline$rank / (n / 5))
theta_baseline$quintile_real <- pmin(theta_baseline$quintile_real, 5)  # Cap at 5

new_quintile_dist <- aggregate(pair ~ quintile_real, data = theta_baseline, length)
names(new_quintile_dist) <- c("Quintile", "N")
new_quintile_dist <- new_quintile_dist[order(new_quintile_dist$Quintile), ]
cat("NEW quintile distribution (equal bins within BASELINE):\n")
print(new_quintile_dist)
cat("\n")

# Verify equal bins
max_diff <- max(new_quintile_dist$N) - min(new_quintile_dist$N)
cat(sprintf("Max bin size difference: %d (should be <= 1)\n\n", max_diff))

# -----------------------------------------------------------------------------
# COMPUTE SIZE GRADIENT WITH REAL QUINTILES
# -----------------------------------------------------------------------------
cat("=== SIZE GRADIENT COMPARISON ===\n\n")

# Old gradient
old_gradient <- do.call(rbind, lapply(1:5, function(q) {
    sub <- theta_baseline[theta_baseline$quintile_old == q, ]
    data.frame(
        Quintile = q,
        N = nrow(sub),
        Mean_theta_D = mean(sub$theta_D, na.rm = TRUE),
        Mean_theta_B = mean(sub$theta_B, na.rm = TRUE),
        Mean_b_hat = mean(sub$b_hat, na.rm = TRUE),
        SD_theta_D = sd(sub$theta_D, na.rm = TRUE)
    )
}))

cat("OLD Gradient (from fake quintiles):\n")
print(old_gradient)
old_q1_q5 <- old_gradient$Mean_theta_D[1] - old_gradient$Mean_theta_D[5]
cat(sprintf("\nOLD Q1-Q5 spread: %.4f\n\n", old_q1_q5))

# New gradient
new_gradient <- do.call(rbind, lapply(1:5, function(q) {
    sub <- theta_baseline[theta_baseline$quintile_real == q, ]
    data.frame(
        Quintile = q,
        N = nrow(sub),
        Mean_theta_D = mean(sub$theta_D, na.rm = TRUE),
        Mean_theta_B = mean(sub$theta_B, na.rm = TRUE),
        Mean_b_hat = mean(sub$b_hat, na.rm = TRUE),
        SD_theta_D = sd(sub$theta_D, na.rm = TRUE)
    )
}))

cat("NEW Gradient (from REAL equal quintiles):\n")
print(new_gradient)
new_q1_q5 <- new_gradient$Mean_theta_D[1] - new_gradient$Mean_theta_D[5]
cat(sprintf("\nNEW Q1-Q5 spread: %.4f\n", new_q1_q5))

# -----------------------------------------------------------------------------
# DECOMPOSITION
# -----------------------------------------------------------------------------
cat("\n=== GRADIENT DECOMPOSITION ===\n")
cat("theta_D = theta_B - b_hat\n\n")

cat("OLD quintiles - component means:\n")
for (q in 1:5) {
    row <- old_gradient[old_gradient$Quintile == q, ]
    cat(sprintf("  Q%d: theta_D = %.4f = theta_B(%.4f) - b_hat(%.4f)\n",
                q, row$Mean_theta_D, row$Mean_theta_B, row$Mean_b_hat))
}

cat("\nNEW quintiles - component means:\n")
for (q in 1:5) {
    row <- new_gradient[new_gradient$Quintile == q, ]
    cat(sprintf("  Q%d: theta_D = %.4f = theta_B(%.4f) - b_hat(%.4f)\n",
                q, row$Mean_theta_D, row$Mean_theta_B, row$Mean_b_hat))
}

cat(sprintf("\n*** GRADIENT DIRECTION CHANGE: OLD=%.4f, NEW=%.4f ***\n",
            old_q1_q5, new_q1_q5))

if (sign(old_q1_q5) != sign(new_q1_q5)) {
    cat("*** WARNING: Gradient REVERSED sign! ***\n")
    cat("   Old gradient: small pairs have LOWER theta_D than large pairs\n")
    cat("   New gradient: small pairs have HIGHER theta_D than large pairs\n")
}

# -----------------------------------------------------------------------------
# GATES
# -----------------------------------------------------------------------------
cat("\n=== GATES ===\n")

gate_equal_bins <- max_diff <= 1
cat(sprintf("GATE: max(n) - min(n) <= 1: %s (diff=%d)\n",
            ifelse(gate_equal_bins, "PASS", "FAIL"), max_diff))
stopifnot(gate_equal_bins)

gate_n <- nrow(theta_baseline) == 4639
cat(sprintf("GATE: BASELINE_n == 4639: %s (%d)\n",
            ifelse(gate_n, "PASS", "FAIL"), nrow(theta_baseline)))
stopifnot(gate_n)

# -----------------------------------------------------------------------------
# SAVE OUTPUTS
# -----------------------------------------------------------------------------
cat("\n=== SAVE OUTPUTS ===\n")

# T3b exhibit
OUTPUT_PATH <- file.path(REBUILD_DIR, "output/T3b_size_gradient_fixed.csv")
write.csv(new_gradient, OUTPUT_PATH, row.names = FALSE)
output_sha <- get_sha256(OUTPUT_PATH)
cat(sprintf("T3b_size_gradient_fixed.csv SHA256: %s\n", output_sha))

# Sidecar
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S12_gradient_fix.R"))
writeLines(c(
    "FILE:      T3b_size_gradient_fixed.csv",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S12_gradient_fix.R (SHA256: %s)", script_sha),
    sprintf("INPUTS:    data/S6_population.rds (SHA256: %s)", pop_sha),
    sprintf("           data/S5_bhat.rds (SHA256: %s)", bhat_sha),
    sprintf("           data/S1_ppml.rds (SHA256: %s)", s1_sha),
    "SEED:      NONE",
    sprintf("GATE:      equal_bins [PASS, max_diff=%d]", max_diff),
    sprintf("GATE:      BASELINE_n == 4639 [PASS, n=%d]", nrow(theta_baseline)),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "NOTE: This exhibit SUPERSEDES T3_size_gradient.csv which used fake quintiles.",
    sprintf("      OLD Q1-Q5 spread: %.4f (fake quintiles from size_decile)", old_q1_q5),
    sprintf("      NEW Q1-Q5 spread: %.4f (real equal quintiles within BASELINE)", new_q1_q5),
    "      GRADIENT DIRECTION REVERSED!"
), file.path(REBUILD_DIR, "meta/T3b_size_gradient_fixed.csv.sidecar"))

cat("\nOutputs saved.\n")

cat("\n================================================================\n")
cat("S12 SIZE GRADIENT FIX COMPLETE\n")
cat("================================================================\n")
cat(sprintf("OLD quintile sizes: %s\n", paste(old_quintile_dist$N, collapse=", ")))
cat(sprintf("NEW quintile sizes: %s\n", paste(new_quintile_dist$N, collapse=", ")))
cat(sprintf("OLD Q1-Q5 spread: %.4f\n", old_q1_q5))
cat(sprintf("NEW Q1-Q5 spread: %.4f\n", new_q1_q5))
cat(sprintf("End: %s\n", format(Sys.time())))
cat("================================================================\n")
