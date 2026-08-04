#!/usr/bin/env Rscript
# =============================================================================
# N4_distribution.R - Distribution Analysis (Conditional on N3)
# =============================================================================
# OUTPUTS: output/T12_N4_distribution.csv, output/T12_N4_mixture.csv,
#          output/T12_N4_gradient.csv
# INPUTS:  data/S5R_bhat.rds, data/N3_deconv.rds
# EXPECTED_N: 4182
# SEED:    20260719
# =============================================================================

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(dplyr))

SEED <- 20260719
set.seed(SEED)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(file.path(RTA_ROOT, p)), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("N4: DISTRIBUTION ANALYSIS")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load inputs
S5R <- readRDS(file.path(RTA_ROOT, "data/S5R_bhat.rds"))
baseline <- S5R$baseline
stopifnot(nrow(baseline) == 4182)
N3 <- readRDS(file.path(RTA_ROOT, "data/N3_deconv.rds"))

say("Baseline pairs: %d", nrow(baseline))
say("Columns: %s", paste(names(baseline), collapse = ", "))

# Add se_total using mean(sd_cf^2) from archive/retired_2026-07-29/output/T11_se_decomposition.csv
# This constant was live under a silent fallback from script creation until INV-047 (2026-08-04).
# The file S17_se_cf.rds never existed; the fallback always fired. See INV-047 in canonical_facts.md.
mean_sd_cf_sq <- 0.0894  # ID: MEAN_SD_CF_SQ (T11 row: mean_sd_cf_sq = 0.0894473839133736)
baseline$se_total <- sqrt(baseline$se_B^2 + mean_sd_cf_sq)
say("Added se_total using ledgered mean(sd_cf^2) = %.4f (INV-047)", mean_sd_cf_sq)

# =============================================================================
# QUANTILE SKEW
# =============================================================================
say("")
say("================================================================")
say("QUANTILE SKEW")
say("================================================================")

theta_D <- baseline$theta_D

q10 <- quantile(theta_D, 0.10)
q25 <- quantile(theta_D, 0.25)
q50 <- quantile(theta_D, 0.50)
q75 <- quantile(theta_D, 0.75)
q90 <- quantile(theta_D, 0.90)

say("q10: %.4f", q10)
say("q25: %.4f", q25)
say("q50: %.4f (median)", q50)
say("q75: %.4f", q75)
say("q90: %.4f", q90)

# Skewness measures
iqr <- q75 - q25
upper_tail <- q90 - q50
lower_tail <- q50 - q10
skew_ratio <- upper_tail / lower_tail

say("")
say("IQR: %.4f", iqr)
say("Upper tail (q90-q50): %.4f", upper_tail)
say("Lower tail (q50-q10): %.4f", lower_tail)
say("Skew ratio: %.4f", skew_ratio)

# =============================================================================
# P(theta <= 0) LADDER
# =============================================================================
say("")
say("================================================================")
say("P(theta <= 0) LADDER")
say("================================================================")

# Using theta_D directly
p_theta_D_neg <- mean(theta_D <= 0)
say("P(theta_D <= 0): %.4f", p_theta_D_neg)

# Deconvolved: assume theta_true ~ N(mean, SD_true^2)
# P(theta_true <= 0 | theta_D) requires Bayesian shrinkage

# For each arm, compute implied P(theta_true <= 0)
# Using empirical Bayes shrinkage: theta_true | theta_D ~ N(shrunk_theta, posterior_var)

# Arm A shrinkage
var_true_A <- N3$SD_true_A^2
shrinkage_A <- var_true_A / (var_true_A + baseline$se_total^2)
shrunk_A <- mean(theta_D) + shrinkage_A * (theta_D - mean(theta_D))
posterior_var_A <- shrinkage_A * baseline$se_total^2
p_neg_A <- pnorm(0, mean = shrunk_A, sd = sqrt(posterior_var_A))
p_true_neg_A <- mean(p_neg_A)

# Arm C shrinkage
var_true_C <- N3$SD_true_C^2
shrinkage_C <- var_true_C / (var_true_C + baseline$se_total^2)
shrunk_C <- mean(theta_D) + shrinkage_C * (theta_D - mean(theta_D))
posterior_var_C <- shrinkage_C * baseline$se_total^2
p_neg_C <- pnorm(0, mean = shrunk_C, sd = sqrt(posterior_var_C))
p_true_neg_C <- mean(p_neg_C)

say("P(theta_true <= 0) under Arm A: %.4f", p_true_neg_A)
say("P(theta_true <= 0) under Arm C: %.4f", p_true_neg_C)

# =============================================================================
# GRADIENT BY REAL QUINTILES
# =============================================================================
say("")
say("================================================================")
say("GRADIENT BY REAL QUINTILES (within population)")
say("================================================================")

# Use pre_trade for quintiles
baseline$quintile <- as.integer(cut(rank(baseline$pre_trade), breaks = 5, labels = FALSE))

gradient <- baseline %>%
    group_by(quintile) %>%
    summarise(
        n = n(),
        mean_theta_D = mean(theta_D, na.rm = TRUE),
        mean_theta_B = mean(theta_B, na.rm = TRUE),
        mean_pre_trade = mean(pre_trade, na.rm = TRUE),
        sd_theta_D = sd(theta_D, na.rm = TRUE),
        se_mean = sd(theta_D, na.rm = TRUE) / sqrt(n()),
        .groups = "drop"
    )

say("")
print(gradient)

Q1 <- gradient$mean_theta_D[gradient$quintile == 1]
Q5 <- gradient$mean_theta_D[gradient$quintile == 5]
say("")
say("Q1-Q5 spread: %.4f", Q1 - Q5)

# =============================================================================
# TRADE-WEIGHTED MEAN
# =============================================================================
say("")
say("================================================================")
say("TRADE-WEIGHTED MEAN")
say("================================================================")

tw_mean <- sum(baseline$theta_D * baseline$pre_trade) / sum(baseline$pre_trade)
unweighted_mean <- mean(baseline$theta_D)

say("Unweighted mean(theta_D): %.4f", unweighted_mean)
say("Trade-weighted mean(theta_D): %.4f", tw_mean)

# =============================================================================
# MIXTURE MODELS (K=2, K=3)
# =============================================================================
say("")
say("================================================================")
say("MIXTURE MODELS")
say("================================================================")

# Simple K=2 mixture via EM
# theta_D | k ~ N(mu_k, sigma_true^2 + se_total^2)

fit_mixture_em <- function(theta, se, K, max_iter = 100, tol = 1e-6) {
    n <- length(theta)

    # Initialize
    pi_k <- rep(1/K, K)
    mu_k <- quantile(theta, probs = seq(0.2, 0.8, length.out = K))
    sigma_k <- rep(sd(theta) / sqrt(K), K)

    for (iter in 1:max_iter) {
        # E-step: compute responsibilities
        gamma <- matrix(0, n, K)
        for (k in 1:K) {
            total_var <- sigma_k[k]^2 + se^2
            gamma[, k] <- pi_k[k] * dnorm(theta, mu_k[k], sqrt(total_var))
        }
        gamma <- gamma / rowSums(gamma)

        # M-step
        N_k <- colSums(gamma)
        pi_k_new <- N_k / n
        mu_k_new <- colSums(gamma * theta) / N_k

        # Update sigma_k
        for (k in 1:K) {
            residuals <- (theta - mu_k_new[k])^2 - se^2
            sigma_k[k] <- sqrt(max(0.01, sum(gamma[, k] * residuals) / N_k[k]))
        }

        # Check convergence
        if (max(abs(mu_k_new - mu_k)) < tol && max(abs(pi_k_new - pi_k)) < tol) {
            break
        }

        mu_k <- mu_k_new
        pi_k <- pi_k_new
    }

    list(pi = pi_k, mu = mu_k, sigma = sigma_k, iterations = iter)
}

# K=2
say("")
say("K=2 Mixture:")
mix2 <- fit_mixture_em(baseline$theta_D, baseline$se_total, K = 2)
say("  Component 1: pi=%.3f, mu=%.3f, sigma=%.3f", mix2$pi[1], mix2$mu[1], mix2$sigma[1])
say("  Component 2: pi=%.3f, mu=%.3f, sigma=%.3f", mix2$pi[2], mix2$mu[2], mix2$sigma[2])
say("  Iterations: %d", mix2$iterations)

# K=3
say("")
say("K=3 Mixture:")
mix3 <- fit_mixture_em(baseline$theta_D, baseline$se_total, K = 3)
for (k in 1:3) {
    say("  Component %d: pi=%.3f, mu=%.3f, sigma=%.3f", k, mix3$pi[k], mix3$mu[k], mix3$sigma[k])
}
say("  Iterations: %d", mix3$iterations)

# =============================================================================
# OUTPUTS
# =============================================================================
say("")

# Main distribution table
dist_results <- data.frame(
    quantity = c("mean_theta_D", "SD_theta_D", "median_theta_D",
                 "q10", "q25", "q75", "q90",
                 "IQR", "skew_ratio",
                 "P_theta_D_neg", "P_true_neg_A", "P_true_neg_C",
                 "Q1_Q5_spread", "tw_mean_theta_D"),
    value = c(mean(theta_D), sd(theta_D), median(theta_D),
              q10, q25, q75, q90,
              iqr, skew_ratio,
              p_theta_D_neg, p_true_neg_A, p_true_neg_C,
              Q1 - Q5, tw_mean)
)
write.csv(dist_results, file.path(RTA_ROOT, "output/T12_N4_distribution.csv"), row.names = FALSE)

# Mixture table
mix_results <- data.frame(
    K = c(rep(2, 2), rep(3, 3)),
    component = c(1, 2, 1, 2, 3),
    pi = c(mix2$pi, mix3$pi),
    mu = c(mix2$mu, mix3$mu),
    sigma = c(mix2$sigma, mix3$sigma)
)
write.csv(mix_results, file.path(RTA_ROOT, "output/T12_N4_mixture.csv"), row.names = FALSE)

# Gradient table
write.csv(gradient, file.path(RTA_ROOT, "output/T12_N4_gradient.csv"), row.names = FALSE)

# Save for downstream
saveRDS(list(
    theta_D = theta_D,
    se_total = baseline$se_total,
    quantiles = c(q10 = q10, q25 = q25, q50 = q50, q75 = q75, q90 = q90),
    skew_ratio = skew_ratio,
    p_true_neg_A = p_true_neg_A,
    p_true_neg_C = p_true_neg_C,
    gradient = gradient,
    tw_mean = tw_mean,
    mix2 = mix2,
    mix3 = mix3,
    shrunk_C = shrunk_C,
    seed = SEED
), file.path(RTA_ROOT, "data/N4_distribution.rds"))

# Sidecars
code_sha <- get_sha256("code/N4_distribution.R")

writeLines(c(
    "FILE:      T12_N4_distribution.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N4_distribution.csv")),
    sprintf("PRODUCER:  code/N4_distribution.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S5R_bhat.rds, data/N3_deconv.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("Q1_Q5_SPREAD: %.4f", Q1 - Q5),
    sprintf("TW_MEAN:   %.4f", tw_mean),
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/T12_N4_distribution.csv.sidecar"))

writeLines(c(
    "FILE:      T12_N4_mixture.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N4_mixture.csv")),
    sprintf("PRODUCER:  code/N4_distribution.R (SHA256: %s)", code_sha),
    "METHOD:    EM with per-pair se_total",
    sprintf("K2_mu:     %.3f, %.3f", mix2$mu[1], mix2$mu[2]),
    sprintf("K3_mu:     %.3f, %.3f, %.3f", mix3$mu[1], mix3$mu[2], mix3$mu[3]),
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/T12_N4_mixture.csv.sidecar"))

writeLines(c(
    "FILE:      T12_N4_gradient.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N4_gradient.csv")),
    sprintf("PRODUCER:  code/N4_distribution.R (SHA256: %s)", code_sha),
    sprintf("Q1_Q5_SPREAD: %.4f", Q1 - Q5),
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/T12_N4_gradient.csv.sidecar"))

say("")
say("Wrote output/T12_N4_distribution.csv")
say("Wrote output/T12_N4_mixture.csv")
say("Wrote output/T12_N4_gradient.csv")
say("Done: %s", format(Sys.time()))
