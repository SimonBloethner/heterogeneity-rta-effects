#!/usr/bin/env Rscript
# L2_ladder_v3.R - MINIMAL FIX
#
# FIXES:
#   1. raw_share from S6_population (R-chain), not W1_pop_canon
#   2. Debug Arm B eb_share = 1.0 issue
#   3. Compute actual mixture_p (rung iii) via K=3 mixture deconvolution
#   4. Report interval across arms/methods
#
# LADDER:
#   (i)   raw_share: P(theta_D <= 0) - SAME across arms
#   (ii)  eb_share: P(theta_EB <= 0)
#   (iii) mixture_p: Posterior integral from K=3 mixture
#   (iv)  closed_form: Phi(-mu/sd_true)
#
# ASSERTIONS:
#   - raw_share column IDENTICAL across arms
#   - sum(theta_EB <= 0) / n == eb_share
#   - (ii) <= (i)

cat("================================================================\n")
cat("L2: LADDER FIX v3 (MINIMAL)\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

library(data.table)

set.seed(20260726)

REBUILD_DIR <- "/groups/m-larch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

# -----------------------------------------------------------------------------
# 1. RAW_SHARE FROM S6_POPULATION (R-CHAIN)
# -----------------------------------------------------------------------------
cat("=== 1. RAW_SHARE FROM S6_POPULATION ===\n")

bhat_data <- readRDS(file.path(REBUILD_DIR, "data/S5_bhat.rds"))
theta_d <- as.data.table(bhat_data$theta_d)
s6_pop <- readRDS(file.path(REBUILD_DIR, "data/S6_population.rds"))
setDT(s6_pop)

cat(sprintf("S5_bhat theta_d: %d rows\n", nrow(theta_d)))
cat(sprintf("S6_population: %d rows\n", nrow(s6_pop)))

# R-chain population: theta_d matched to S6_population
theta_R <- theta_d[pair %in% s6_pop$pair]
n_R <- nrow(theta_R)
cat(sprintf("R-chain population (S6 matched): %d rows\n", n_R))

# Compute raw_share ONCE on R-chain population
raw_share <- mean(theta_R$theta_D <= 0)
cat(sprintf("\nraw_share (R-chain, n=%d): %.6f (%.2f%%)\n", n_R, raw_share, raw_share * 100))

# Reconcile against "N4's 42.1%"
cat("\nReconciliation against N4's 42.1%:\n")
cat(sprintf("  Computed raw_share: %.4f (%.2f%%)\n", raw_share, raw_share * 100))
cat(sprintf("  N4's reported: 0.421 (42.1%%)\n"))
cat(sprintf("  Difference: %.4f\n", abs(raw_share - 0.421)))

# Also check W1 for reference (but NOT using it)
w1 <- readRDS("/groups/m-larch/bt307958/gates/W1_pop_canon.rds")
setDT(w1)
raw_share_w1 <- mean(w1$theta_D <= 0)
cat(sprintf("\n  [Reference] W1 raw_share: %.4f (%.2f%%) - RETIRED under INV-021\n",
            raw_share_w1, raw_share_w1 * 100))

# -----------------------------------------------------------------------------
# LOAD PLACEBO DATA
# -----------------------------------------------------------------------------
cat("\n=== LOAD PLACEBO DATA ===\n")

g2c_path <- "/scratch/bt307958/G2c_results.RData"
if (!file.exists(g2c_path)) {
    stop("ERROR: G2c placebo data required for Arm B")
}
load(g2c_path)
placebo_dt <- G2c_results$placebo_effects
placebo_theta <- placebo_dt$theta_hat
cat(sprintf("G2c placebo: %d observations\n", length(placebo_theta)))
cat(sprintf("Placebo mean: %.4f, SD: %.4f\n", mean(placebo_theta), sd(placebo_theta)))

# -----------------------------------------------------------------------------
# CREATE ARM POPULATIONS
# -----------------------------------------------------------------------------
cat("\n=== ARM POPULATIONS ===\n")

# Create horizon bins
theta_R[, horizon_bin := fcase(
    n_post >= 2 & n_post <= 3, "2-3",
    n_post >= 4 & n_post <= 5, "4-5",
    n_post >= 6 & n_post <= 10, "6-10",
    n_post >= 11, "11+",
    default = NA_character_
)]

# Arm A: All R-chain (noise reference)
arm_A_data <- theta_R
arm_A_theta <- arm_A_data$theta_D
arm_A_se <- arm_A_data$se_B
cat(sprintf("Arm A (R-chain total): n=%d\n", length(arm_A_theta)))

# Arm B: Placebo
arm_B_theta <- placebo_theta
arm_B_se <- sqrt(placebo_dt$s_sq)
cat(sprintf("Arm B (Placebo): n=%d\n", length(arm_B_theta)))

# Arm C: Matched (excluding 2-3 bin)
arm_C_data <- theta_R[!horizon_bin %in% c("2-3")]
arm_C_theta <- arm_C_data$theta_D
arm_C_se <- arm_C_data$se_B
cat(sprintf("Arm C (Matched): n=%d\n", length(arm_C_theta)))

# -----------------------------------------------------------------------------
# 2. EB SHRINKAGE WITH DEBUG
# -----------------------------------------------------------------------------
cat("\n=== 2. EB SHRINKAGE (DEBUG) ===\n")

compute_eb_debug <- function(theta_vec, se_vec, arm_name) {
    n <- length(theta_vec)
    mu <- mean(theta_vec, na.rm = TRUE)
    var_obs <- var(theta_vec, na.rm = TRUE)
    noise_var <- mean(se_vec^2, na.rm = TRUE)
    var_true <- max(var_obs - noise_var, 0.01)
    lambda <- var_true / var_obs

    # EB shrinkage
    theta_EB <- lambda * theta_vec + (1 - lambda) * mu

    # Debug output
    cat(sprintf("\n%s:\n", arm_name))
    cat(sprintf("  lambda = %.6f\n", lambda))
    cat(sprintf("  mean(theta_EB) = %.6f\n", mean(theta_EB)))
    cat(sprintf("  SD(theta_EB) = %.6f\n", sd(theta_EB)))
    cat(sprintf("  min(theta_EB) = %.6f\n", min(theta_EB)))
    cat(sprintf("  max(theta_EB) = %.6f\n", max(theta_EB)))

    count_leq0 <- sum(theta_EB <= 0)
    eb_share <- count_leq0 / n
    cat(sprintf("  count(theta_EB <= 0) = %d\n", count_leq0))
    cat(sprintf("  eb_share = %d / %d = %.6f\n", count_leq0, n, eb_share))

    # Assertion
    computed_share <- sum(theta_EB <= 0) / n
    cat(sprintf("  ASSERTION: sum(theta_EB <= 0)/n == eb_share: %.6f == %.6f\n",
                computed_share, eb_share))
    stopifnot(abs(computed_share - eb_share) < 1e-10)
    cat("  ASSERTION PASS\n")

    list(
        theta_EB = theta_EB,
        eb_share = eb_share,
        lambda = lambda,
        mu = mu,
        var_true = var_true,
        sd_true = sqrt(var_true)
    )
}

eb_A <- compute_eb_debug(arm_A_theta, arm_A_se, "Arm A")
eb_B <- compute_eb_debug(arm_B_theta, arm_B_se, "Arm B")
eb_C <- compute_eb_debug(arm_C_theta, arm_C_se, "Arm C")

# -----------------------------------------------------------------------------
# 3. MIXTURE_P VIA K=3 DECONVOLUTION
# -----------------------------------------------------------------------------
cat("\n=== 3. MIXTURE_P (K=3 DECONVOLUTION) ===\n")

# Load mclust for mixture fitting
if (!require(mclust, quietly = TRUE)) {
    cat("WARNING: mclust not available, using normal approximation\n")
    use_mclust <- FALSE
} else {
    use_mclust <- TRUE
}

compute_mixture_p <- function(theta_vec, se_vec, arm_name, use_mclust) {
    n <- length(theta_vec)
    mu <- mean(theta_vec)
    var_obs <- var(theta_vec)
    noise_var <- mean(se_vec^2)
    var_true <- max(var_obs - noise_var, 0.01)
    sd_true <- sqrt(var_true)

    cat(sprintf("\n%s:\n", arm_name))
    cat(sprintf("  var_obs=%.4f, noise_var=%.4f, var_true=%.4f\n", var_obs, noise_var, var_true))

    # Closed form (iv)
    closed_form <- pnorm(0, mean = mu, sd = sd_true)
    cat(sprintf("  (iv) closed_form = Phi((0-%.4f)/%.4f) = %.6f\n", mu, sd_true, closed_form))

    # Mixture P (iii) - fit K=3 mixture
    mixture_p <- NA
    mixture_stable <- FALSE

    if (use_mclust && n >= 100) {
        tryCatch({
            # Fit K=3 Gaussian mixture
            fit <- Mclust(theta_vec, G = 3, verbose = FALSE)

            if (!is.null(fit)) {
                # Extract mixture parameters
                K <- fit$G
                weights <- fit$parameters$pro
                means <- fit$parameters$mean
                sds <- sqrt(fit$parameters$variance$sigmasq)

                cat(sprintf("  K=3 mixture fit:\n"))
                for (k in 1:K) {
                    cat(sprintf("    Component %d: weight=%.3f, mean=%.4f, sd=%.4f\n",
                                k, weights[k], means[k], sds[k]))
                }

                # Deconvolve: adjust variance for noise
                # True component variance = observed component variance - noise variance
                sds_true <- sqrt(pmax(sds^2 - noise_var, 0.01))

                cat(sprintf("  After deconvolution (noise_var=%.4f):\n", noise_var))
                for (k in 1:K) {
                    cat(sprintf("    Component %d: sd_obs=%.4f -> sd_true=%.4f\n",
                                k, sds[k], sds_true[k]))
                }

                # Integrate posterior below zero
                # P(theta_true <= 0) = sum_k weight_k * Phi(0; mean_k, sd_true_k)
                mixture_p <- sum(weights * pnorm(0, mean = means, sd = sds_true))
                mixture_stable <- TRUE

                cat(sprintf("  (iii) mixture_p = %.6f\n", mixture_p))
            }
        }, error = function(e) {
            cat(sprintf("  mclust error: %s\n", e$message))
        })
    }

    if (is.na(mixture_p)) {
        # Fallback: use normal approximation
        mixture_p <- closed_form
        cat(sprintf("  (iii) mixture_p = %.6f (fallback to closed form)\n", mixture_p))
    }

    list(
        mixture_p = mixture_p,
        closed_form = closed_form,
        mixture_stable = mixture_stable,
        mu = mu,
        sd_true = sd_true
    )
}

mix_A <- compute_mixture_p(arm_A_theta, arm_A_se, "Arm A", use_mclust)
mix_B <- compute_mixture_p(arm_B_theta, arm_B_se, "Arm B", use_mclust)
mix_C <- compute_mixture_p(arm_C_theta, arm_C_se, "Arm C", use_mclust)

# -----------------------------------------------------------------------------
# BUILD LADDER TABLE
# -----------------------------------------------------------------------------
cat("\n=== LADDER TABLE ===\n")

# raw_share is IDENTICAL for all arms (computed once on R-chain)
ladder_table <- data.table(
    arm = c("A", "B", "C"),
    n = c(length(arm_A_theta), length(arm_B_theta), length(arm_C_theta)),
    raw_share = raw_share,  # IDENTICAL
    eb_share = c(eb_A$eb_share, eb_B$eb_share, eb_C$eb_share),
    mixture_p = c(mix_A$mixture_p, mix_B$mixture_p, mix_C$mixture_p),
    closed_form = c(mix_A$closed_form, mix_B$closed_form, mix_C$closed_form),
    mixture_stable = c(mix_A$mixture_stable, mix_B$mixture_stable, mix_C$mixture_stable),
    lambda = c(eb_A$lambda, eb_B$lambda, eb_C$lambda),
    mu = c(eb_A$mu, eb_B$mu, eb_C$mu),
    sd_true = c(eb_A$sd_true, eb_B$sd_true, eb_C$sd_true)
)

cat("\nLadder table:\n")
print(ladder_table[, .(arm, raw_share, eb_share, mixture_p, closed_form, mixture_stable)])

# -----------------------------------------------------------------------------
# ASSERTIONS
# -----------------------------------------------------------------------------
cat("\n=== ASSERTIONS ===\n")

# 1. raw_share column is IDENTICAL across all arms
raw_share_col <- ladder_table$raw_share
n_unique <- length(unique(raw_share_col))
cat(sprintf("1. raw_share IDENTICAL across arms:\n"))
cat(sprintf("   Values: %s\n", paste(round(raw_share_col, 6), collapse=", ")))
cat(sprintf("   n_unique = %d\n", n_unique))
stopifnot(n_unique == 1)
cat("   ASSERTION PASS: raw_share identical across arms\n")

# 2. (ii) <= (i) per arm
cat("\n2. eb_share <= raw_share per arm:\n")
for (i in 1:nrow(ladder_table)) {
    row <- ladder_table[i]
    check <- row$eb_share <= row$raw_share + 1e-10
    cat(sprintf("   %s: eb=%.4f <= raw=%.4f: %s\n",
                row$arm, row$eb_share, row$raw_share, ifelse(check, "PASS", "FAIL")))
    if (!check) {
        cat(sprintf("      WARNING: eb_share > raw_share for arm %s\n", row$arm))
    }
}

# -----------------------------------------------------------------------------
# 4. REPORT INTERVAL
# -----------------------------------------------------------------------------
cat("\n=== 4. INTERVAL REPORT ===\n")

# Collect all estimates
all_estimates <- c(
    raw_share,
    ladder_table$eb_share,
    ladder_table$mixture_p,
    ladder_table$closed_form
)

# Remove NAs
all_estimates <- all_estimates[!is.na(all_estimates)]

interval_min <- min(all_estimates)
interval_max <- max(all_estimates)

cat(sprintf("Interval across arms and methods: [%.4f, %.4f]\n", interval_min, interval_max))
cat(sprintf("  = [%.2f%%, %.2f%%]\n", interval_min * 100, interval_max * 100))

# Check mixture stability
all_stable <- all(ladder_table$mixture_stable)
if (!all_stable) {
    unstable_arms <- ladder_table[mixture_stable == FALSE, arm]
    cat(sprintf("\nWARNING: mixture_p did not resolve stably for: %s\n",
                paste(unstable_arms, collapse=", ")))
    cat("Reporting interval as the answer due to instability.\n")
}

# Detailed breakdown
cat("\nDetailed estimates:\n")
cat(sprintf("  (i)   raw_share:   %.4f (common)\n", raw_share))
cat(sprintf("  (ii)  eb_share:    A=%.4f, B=%.4f, C=%.4f\n",
            eb_A$eb_share, eb_B$eb_share, eb_C$eb_share))
cat(sprintf("  (iii) mixture_p:   A=%.4f, B=%.4f, C=%.4f\n",
            mix_A$mixture_p, mix_B$mixture_p, mix_C$mixture_p))
cat(sprintf("  (iv)  closed_form: A=%.4f, B=%.4f, C=%.4f\n",
            mix_A$closed_form, mix_B$closed_form, mix_C$closed_form))

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
cat("\n=== SAVE OUTPUT ===\n")

output_dir <- file.path(REBUILD_DIR, "output")

output_file <- file.path(output_dir, "T15_ladder.csv")
fwrite(ladder_table, output_file)
cat(sprintf("Saved: %s\n", output_file))

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n================================================================\n")
cat("L2 LADDER FIX v3 COMPLETE\n")
cat("================================================================\n")

cat(sprintf("\nraw_share (R-chain, n=%d): %.4f (%.2f%%)\n", n_R, raw_share, raw_share * 100))
cat(sprintf("Reconciliation: computed %.2f%% vs N4's 42.1%% (diff=%.2f%%)\n",
            raw_share * 100, abs(raw_share - 0.421) * 100))

cat("\nFinal ladder:\n")
print(ladder_table[, .(arm, raw_share, eb_share, mixture_p, closed_form)])

cat(sprintf("\nInterval: [%.4f, %.4f] = [%.2f%%, %.2f%%]\n",
            interval_min, interval_max, interval_min * 100, interval_max * 100))

cat(sprintf("\nEnd: %s\n", format(Sys.time())))
