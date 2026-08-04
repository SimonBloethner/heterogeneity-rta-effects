#!/usr/bin/env Rscript
# L2_ladder_v4.R - FINAL FIX
#
# CHANGES:
#   1. Use S6R_population.rds (n=4,182), not S6_population.rds
#   2. DROP Arm B from ladder - report separately as placebo benchmark
#   3. Ladder has Arms A and C only
#   4. If mixture_p < eb_share, print mixture details for verification

cat("================================================================\n")
cat("L2: LADDER FIX v4 (FINAL)\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

library(data.table)

set.seed(20260726)

REBUILD_DIR <- "/groups/m-larch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

# -----------------------------------------------------------------------------
# 1. LOAD S6R_POPULATION (n=4,182)
# -----------------------------------------------------------------------------
cat("=== 1. LOAD S6R_POPULATION ===\n")

s6r_path <- file.path(REBUILD_DIR, "data/S6R_population.rds")
cat(sprintf("Loading: %s\n", s6r_path))

s6r_pop <- readRDS(s6r_path)
setDT(s6r_pop)

n_s6r <- nrow(s6r_pop)
cat(sprintf("S6R_population rows: %d\n", n_s6r))

# ASSERTION: n == 4182
cat(sprintf("ASSERTION: nrow(popn) == 4182: %d == 4182\n", n_s6r))
stopifnot(nrow(s6r_pop) == 4182)
cat("ASSERTION PASS\n")

# Load theta_d and match to S6R
bhat_data <- readRDS(file.path(REBUILD_DIR, "data/S5_bhat.rds"))
theta_d <- as.data.table(bhat_data$theta_d)
cat(sprintf("S5_bhat theta_d: %d rows\n", nrow(theta_d)))

# R-chain population: theta_d matched to S6R_population
theta_R <- theta_d[pair %in% s6r_pop$pair]
n_R <- nrow(theta_R)
cat(sprintf("R-chain matched: %d rows\n", n_R))

# ASSERTION: matched count
cat(sprintf("ASSERTION: matched == 4182: %d == 4182\n", n_R))
stopifnot(n_R == 4182)
cat("ASSERTION PASS\n")

# Compute raw_share
raw_share <- mean(theta_R$theta_D <= 0)
cat(sprintf("\nraw_share (S6R, n=%d): %.6f (%.2f%%)\n", n_R, raw_share, raw_share * 100))

# N4 reconciliation
cat("\nN4 RECONCILIATION:\n")
cat(sprintf("  Computed raw_share: %.4f (%.2f%%)\n", raw_share, raw_share * 100))
cat(sprintf("  N4's reported:      0.421 (42.1%%)\n"))
cat(sprintf("  Difference:         %.4f (%.2f%%)\n", abs(raw_share - 0.421), abs(raw_share - 0.421) * 100))

# -----------------------------------------------------------------------------
# 2. PLACEBO BENCHMARK (SEPARATE, NOT IN LADDER)
# -----------------------------------------------------------------------------
cat("\n=== 2. PLACEBO BENCHMARK (Arm B - SEPARATE) ===\n")

g2c_path <- "/scratch/bt307958/G2c_results.RData"
load(g2c_path)
placebo_dt <- G2c_results$placebo_effects
placebo_theta <- placebo_dt$theta_hat
placebo_se <- sqrt(placebo_dt$s_sq)

n_placebo <- length(placebo_theta)
mu_placebo <- mean(placebo_theta)
var_obs_placebo <- var(placebo_theta)
noise_var_placebo <- mean(placebo_se^2)
var_true_placebo <- max(var_obs_placebo - noise_var_placebo, 0.01)
lambda_placebo <- var_true_placebo / var_obs_placebo

cat("PLACEBO BENCHMARK (zero-effect reference):\n")
cat(sprintf("  n = %d\n", n_placebo))
cat(sprintf("  mean(theta) = %.4f\n", mu_placebo))
cat(sprintf("  var_obs = %.4f, noise_var = %.4f\n", var_obs_placebo, noise_var_placebo))
cat(sprintf("  var_true = %.4f (floored)\n", var_true_placebo))
cat(sprintf("  lambda = %.6f\n", lambda_placebo))
cat(sprintf("  P(theta <= 0) raw = %.4f\n", mean(placebo_theta <= 0)))

# EB for placebo
theta_EB_placebo <- lambda_placebo * placebo_theta + (1 - lambda_placebo) * mu_placebo
cat(sprintf("  P(theta_EB <= 0) = %.4f\n", mean(theta_EB_placebo <= 0)))
cat("  [All theta_EB are negative due to shrinkage toward mean=-0.71]\n")

# -----------------------------------------------------------------------------
# 3. LADDER: ARMS A AND C ONLY
# -----------------------------------------------------------------------------
cat("\n=== 3. LADDER: ARMS A AND C ===\n")

# Create horizon bins
theta_R[, horizon_bin := fcase(
    n_post >= 2 & n_post <= 3, "2-3",
    n_post >= 4 & n_post <= 5, "4-5",
    n_post >= 6 & n_post <= 10, "6-10",
    n_post >= 11, "11+",
    default = NA_character_
)]

# Arm A: All R-chain
arm_A_theta <- theta_R$theta_D
arm_A_se <- theta_R$se_B
n_A <- length(arm_A_theta)

# Arm C: Matched (excluding 2-3 bin)
arm_C_data <- theta_R[!horizon_bin %in% c("2-3")]
arm_C_theta <- arm_C_data$theta_D
arm_C_se <- arm_C_data$se_B
n_C <- length(arm_C_theta)

cat(sprintf("Arm A (all R-chain): n=%d\n", n_A))
cat(sprintf("Arm C (excluding 2-3): n=%d\n", n_C))

# Load mclust
library(mclust)

# Function to compute full ladder
compute_ladder <- function(theta_vec, se_vec, arm_name, raw_share_common) {
    n <- length(theta_vec)
    mu <- mean(theta_vec)
    var_obs <- var(theta_vec)
    noise_var <- mean(se_vec^2)
    var_true <- max(var_obs - noise_var, 0.01)
    sd_true <- sqrt(var_true)
    lambda <- var_true / var_obs

    cat(sprintf("\n--- %s ---\n", arm_name))
    cat(sprintf("n=%d, mu=%.4f, var_obs=%.4f, noise_var=%.4f\n", n, mu, var_obs, noise_var))
    cat(sprintf("var_true=%.4f, SD_true=%.4f, lambda=%.6f\n", var_true, sd_true, lambda))

    # (i) Raw share (common)
    raw <- raw_share_common
    cat(sprintf("\n(i)  raw_share = %.6f (common across arms)\n", raw))

    # (ii) EB share
    theta_EB <- lambda * theta_vec + (1 - lambda) * mu
    eb <- mean(theta_EB <= 0)
    cat(sprintf("(ii) eb_share = %.6f\n", eb))

    # ASSERTION: (ii) <= (i)
    cat(sprintf("     ASSERTION: eb_share <= raw_share: %.6f <= %.6f\n", eb, raw))
    if (eb <= raw + 1e-10) {
        cat("     ASSERTION PASS\n")
    } else {
        cat("     ASSERTION FAIL\n")
    }
    stopifnot(eb <= raw + 1e-10)

    # (iii) Mixture P via K=3 deconvolution
    cat("\n(iii) Fitting K=3 mixture...\n")
    fit <- Mclust(theta_vec, G = 3, verbose = FALSE)

    weights <- fit$parameters$pro
    means <- fit$parameters$mean
    sds_obs <- sqrt(fit$parameters$variance$sigmasq)

    # Deconvolve
    sds_true <- sqrt(pmax(sds_obs^2 - noise_var, 0.01))

    # Print components
    cat("     Mixture components:\n")
    for (k in 1:3) {
        cat(sprintf("       k=%d: weight=%.4f, mean=%.4f, sd_obs=%.4f, sd_true=%.4f\n",
                    k, weights[k], means[k], sds_obs[k], sds_true[k]))
    }

    # Integrate below zero
    mixture_p <- sum(weights * pnorm(0, mean = means, sd = sds_true))
    cat(sprintf("     mixture_p = sum(w_k * Phi(0; mu_k, sd_true_k)) = %.6f\n", mixture_p))

    # (iv) Closed form
    closed_form <- pnorm(0, mean = mu, sd = sd_true)
    cat(sprintf("\n(iv) closed_form = Phi(0; %.4f, %.4f) = %.6f\n", mu, sd_true, closed_form))

    # Check if (iii) < (ii)
    if (mixture_p < eb - 1e-10) {
        cat("\n*** NOTICE: mixture_p < eb_share ***\n")
        cat("Arithmetic for verification:\n")
        cat(sprintf("  eb_share = %.6f\n", eb))
        cat(sprintf("  mixture_p = %.6f\n", mixture_p))
        cat("  Mixture integration:\n")
        for (k in 1:3) {
            phi_k <- pnorm(0, mean = means[k], sd = sds_true[k])
            contrib_k <- weights[k] * phi_k
            cat(sprintf("    k=%d: w=%.4f * Phi(0; %.4f, %.4f) = %.4f * %.4f = %.6f\n",
                        k, weights[k], means[k], sds_true[k], weights[k], phi_k, contrib_k))
        }
        cat(sprintf("  Sum = %.6f\n", mixture_p))
    }

    list(
        arm = arm_name,
        n = n,
        raw = raw,
        eb = eb,
        mixture = mixture_p,
        closed = closed_form,
        lambda = lambda,
        sd_true = sd_true,
        weights = weights,
        means = means,
        sds_true = sds_true
    )
}

# Compute ladder for A and C
ladder_A <- compute_ladder(arm_A_theta, arm_A_se, "Arm A", raw_share)
ladder_C <- compute_ladder(arm_C_theta, arm_C_se, "Arm C", raw_share)

# -----------------------------------------------------------------------------
# 4. FINAL LADDER TABLE
# -----------------------------------------------------------------------------
cat("\n=== 4. FINAL LADDER TABLE ===\n")

ladder_table <- data.table(
    arm = c("A", "C"),
    n = c(ladder_A$n, ladder_C$n),
    lambda = c(ladder_A$lambda, ladder_C$lambda),
    SD_true = c(ladder_A$sd_true, ladder_C$sd_true),
    raw = c(ladder_A$raw, ladder_C$raw),
    EB = c(ladder_A$eb, ladder_C$eb),
    mixture = c(ladder_A$mixture, ladder_C$mixture),
    closed = c(ladder_A$closed, ladder_C$closed)
)

cat("\nLadder (Arms A and C only):\n")
print(ladder_table)

# Interval for treatment arms
all_vals <- c(ladder_A$raw, ladder_A$eb, ladder_A$mixture, ladder_A$closed,
              ladder_C$raw, ladder_C$eb, ladder_C$mixture, ladder_C$closed)
interval_min <- min(all_vals)
interval_max <- max(all_vals)

cat(sprintf("\nInterval (treatment arms): [%.4f, %.4f] = [%.2f%%, %.2f%%]\n",
            interval_min, interval_max, interval_min * 100, interval_max * 100))

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
cat("\n=== SAVE OUTPUT ===\n")

output_dir <- file.path(REBUILD_DIR, "output")
fwrite(ladder_table, file.path(output_dir, "T15_ladder.csv"))
cat("Saved: T15_ladder.csv\n")

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n================================================================\n")
cat("L2 LADDER FIX v4 COMPLETE\n")
cat("================================================================\n")

cat(sprintf("\nPopulation: S6R_population.rds (n=%d)\n", n_R))
cat(sprintf("raw_share: %.4f (%.2f%%)\n", raw_share, raw_share * 100))
cat(sprintf("N4 reconciliation: %.2f%% vs 42.1%% (diff=%.2f%%)\n",
            raw_share * 100, abs(raw_share - 0.421) * 100))

cat("\nFinal ladder:\n")
cat("       Arm |     n | lambda | SD_true |    raw |     EB | mixture | closed\n")
cat("       ----|-------|--------|---------|--------|--------|---------|--------\n")
cat(sprintf("         A | %5d | %.4f |  %.4f | %.4f | %.4f |  %.4f | %.4f\n",
            ladder_A$n, ladder_A$lambda, ladder_A$sd_true,
            ladder_A$raw, ladder_A$eb, ladder_A$mixture, ladder_A$closed))
cat(sprintf("         C | %5d | %.4f |  %.4f | %.4f | %.4f |  %.4f | %.4f\n",
            ladder_C$n, ladder_C$lambda, ladder_C$sd_true,
            ladder_C$raw, ladder_C$eb, ladder_C$mixture, ladder_C$closed))

cat(sprintf("\nPlacebo benchmark (Arm B): n=%d, mean=%.4f, P(<=0)=%.4f\n",
            n_placebo, mu_placebo, mean(placebo_theta <= 0)))

cat(sprintf("\nEnd: %s\n", format(Sys.time())))
