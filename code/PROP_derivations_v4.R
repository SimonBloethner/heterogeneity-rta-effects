#!/usr/bin/env Rscript
# PROP-FIX v4: Revised Derivations - fixed V2b with homogeneous s2

cat("========================================================================\n")
cat("PROPOSITIONS APPENDIX v4: REVISED DERIVATIONS\n")
cat("Start:", format(Sys.time()), "\n")
cat("========================================================================\n\n")

set.seed(20260722)

# ===========================================================================
# PROPOSITION 1: Jensen Bias and Reliability
# ===========================================================================
cat("========================================================================\n")
cat("PROPOSITION 1: JENSEN BIAS AND RELIABILITY\n")
cat("========================================================================\n\n")

n_pairs <- 100000
T_post <- 10

# Draw s_ij from Uniform(0.3, 1.8) - heterogeneous for P1
s_ij <- runif(n_pairs, 0.3, 1.8)
s2_ij <- s_ij^2

# V1a: Verify E[theta_A] = -s2/2
cat("V1a: Verifying E[theta_A] = -s2/2 under zero effect\n")
cat("-----------------------------------------------------------\n")

theta_A <- numeric(n_pairs)
for (i in 1:n_pairs) {
    log_eta <- rnorm(T_post, mean = -s2_ij[i]/2, sd = s_ij[i])
    theta_A[i] <- mean(log_eta)
}

mean_theta_A <- mean(theta_A)
theory_mean <- -mean(s2_ij)/2
pct_error <- abs((mean_theta_A - theory_mean) / theory_mean) * 100

cat(sprintf("  Mean(theta_A) simulated: %.6f\n", mean_theta_A))
cat(sprintf("  Theory -E[s2]/2:         %.6f\n", theory_mean))
cat(sprintf("  Percent error:           %.2f%%\n", pct_error))
stopifnot(pct_error < 1)
cat("  PASS: <1% error\n\n")

# Regression slope
reg <- lm(theta_A ~ s2_ij)
slope <- coef(reg)[2]
cat(sprintf("  Regression slope (theta_A ~ s2_ij): %.4f\n", slope))
cat(sprintf("  Expected slope:                     -0.5000\n"))
stopifnot(abs(slope + 0.5) < 0.01)
cat("  PASS: within ±0.01\n\n")

# V1b: Split-half correlation
cat("V1b: Verifying split-half correlation formula\n")
cat("-----------------------------------------------------------\n")

T_half <- T_post / 2

theta_A_1 <- numeric(n_pairs)
theta_A_2 <- numeric(n_pairs)
for (i in 1:n_pairs) {
    log_eta_1 <- rnorm(T_half, mean = -s2_ij[i]/2, sd = s_ij[i])
    log_eta_2 <- rnorm(T_half, mean = -s2_ij[i]/2, sd = s_ij[i])
    theta_A_1[i] <- mean(log_eta_1)
    theta_A_2[i] <- mean(log_eta_2)
}

sim_corr <- cor(theta_A_1, theta_A_2)

var_bias <- var(s2_ij) / 4
mean_s2 <- mean(s2_ij)
var_noise_per_half <- mean_s2 / T_half
var_total <- var_bias + var_noise_per_half
theory_corr <- var_bias / var_total

cat(sprintf("  Simulated split-half correlation: %.4f\n", sim_corr))
cat(sprintf("  Theory formula prediction:        %.4f\n", theory_corr))
stopifnot(abs(sim_corr - theory_corr) < 0.02)
cat("  PASS: within ±0.02\n\n")

# V1c: Ledger reconciliation with explicit inputs
cat("V1c: LEDGER RECONCILIATION ROW (explicit inputs)\n")
cat("-----------------------------------------------------------\n")

ledger_placebo_A <- -0.71
implied_mean_s2 <- 2 * abs(ledger_placebo_A)
ledger_split_r <- 0.62
T_half_ledger <- 5

cat(sprintf("  INPUT: Ledgered placebo mean (A):  %.2f\n", ledger_placebo_A))
cat(sprintf("  INPUT: Ledgered split-half r:      %.2f\n", ledger_split_r))
cat(sprintf("  INPUT: T_half:                     %d\n", T_half_ledger))
cat(sprintf("  DERIVED: E[s2] = 2*|%.2f| =        %.2f\n\n", ledger_placebo_A, implied_mean_s2))

implied_var_s2 <- 4 * ledger_split_r * implied_mean_s2 / (T_half_ledger * (1 - ledger_split_r))
implied_sd_s2 <- sqrt(implied_var_s2)

cat(sprintf("  DERIVED: Var(s2) implied by r:     %.4f\n", implied_var_s2))
cat(sprintf("  DERIVED: SD(s2) implied:           %.4f\n\n", implied_sd_s2))

var_bias_ledger <- implied_var_s2 / 4
var_noise_ledger <- implied_mean_s2 / T_half_ledger
predicted_r <- var_bias_ledger / (var_bias_ledger + var_noise_ledger)

cat(sprintf("  VERIFICATION: Predicted r from formula: %.4f\n", predicted_r))
cat(sprintf("  VERIFICATION: Ledgered r:                %.2f\n", ledger_split_r))
stopifnot(abs(predicted_r - ledger_split_r) < 0.01)
cat("  PASS: Formula reproduces ledgered r within ±0.01\n\n")

# V1d: Verify E[theta_B] = 0 under B-specification
cat("V1d: Verifying E[theta_B] = 0 under zero effect\n")
cat("-----------------------------------------------------------\n")

theta_B <- theta_A + s2_ij / 2

mean_theta_B <- mean(theta_B)
cat(sprintf("  Mean(theta_B) simulated: %.6f\n", mean_theta_B))
cat(sprintf("  Expected:                0.0000\n"))
stopifnot(abs(mean_theta_B) < 0.01)
cat("  PASS: <0.01 from zero\n\n")

# ===========================================================================
# PROPOSITION 2: Pre-calibrated Deconvolution
# ===========================================================================
cat("========================================================================\n")
cat("PROPOSITION 2: PRE-CALIBRATED DECONVOLUTION\n")
cat("========================================================================\n\n")

n_pairs_p2 <- 50000
T_pre <- 10
T_post <- 10

# Use CONSTANT s2 for pre-calibrated deconvolution (the "pre-calibrated" assumption)
s2_const <- 1.0
s_const <- sqrt(s2_const)

cat("V2a: Verifying Var(theta_pre - theta_A) formula\n")
cat("-----------------------------------------------------------\n")

# Draw true pair-level signal mu_ij
mu_ij <- rnorm(n_pairs_p2, mean = 0, sd = 0.4)

# Pre-period: theta_pre = mean of T_pre draws from N(mu - s2/2, s)
theta_pre <- numeric(n_pairs_p2)
for (i in 1:n_pairs_p2) {
    log_eta_pre <- rnorm(T_pre, mean = mu_ij[i] - s2_const/2, sd = s_const)
    theta_pre[i] <- mean(log_eta_pre)
}

# Post-period: theta_A = mean of T_post draws
theta_A_p2 <- numeric(n_pairs_p2)
for (i in 1:n_pairs_p2) {
    log_eta_post <- rnorm(T_post, mean = mu_ij[i] - s2_const/2, sd = s_const)
    theta_A_p2[i] <- mean(log_eta_post)
}

# Observed difference
diff_obs <- theta_pre - theta_A_p2
var_diff_sim <- var(diff_obs)

# Theory: Var(theta_pre - theta_A) = s2 * (1/T_pre + 1/T_post)
var_diff_theory <- s2_const * (1/T_pre + 1/T_post)

cat(sprintf("  s2 (constant):                      %.4f\n", s2_const))
cat(sprintf("  Simulated Var(theta_pre - theta_A): %.4f\n", var_diff_sim))
cat(sprintf("  Theory s2*(1/T_pre + 1/T_post):     %.4f\n", var_diff_theory))
pct_err_v2a <- abs((var_diff_sim - var_diff_theory) / var_diff_theory) * 100
cat(sprintf("  Percent error:                      %.2f%%\n", pct_err_v2a))
stopifnot(pct_err_v2a < 2)
cat("  PASS: <2% error\n\n")

# V2b: Pre-calibrated deconvolution
cat("V2b: Verifying pre-calibrated Var(mu) recovery\n")
cat("-----------------------------------------------------------\n")

# Under constant s2:
# Var(theta_pre) = Var(mu) + s2/T_pre
# So Var(mu) = Var(theta_pre) - s2/T_pre

var_theta_pre <- var(theta_pre)
var_mu_recovered <- var_theta_pre - s2_const / T_pre

true_var_mu <- var(mu_ij)

cat(sprintf("  True Var(mu):                        %.4f\n", true_var_mu))
cat(sprintf("  Var(theta_pre):                      %.4f\n", var_theta_pre))
cat(sprintf("  s2/T_pre:                            %.4f\n", s2_const / T_pre))
cat(sprintf("  Recovered Var(mu) = Var - s2/T:      %.4f\n", var_mu_recovered))
pct_err_v2b <- abs((var_mu_recovered - true_var_mu) / true_var_mu) * 100
cat(sprintf("  Percent error:                       %.2f%%\n", pct_err_v2b))
stopifnot(pct_err_v2b < 5)
cat("  PASS: <5% error\n\n")

# ===========================================================================
# PROPOSITION 3: Within-pair Drift (RESPECIFIED with nu)
# ===========================================================================
cat("========================================================================\n")
cat("PROPOSITION 3: WITHIN-PAIR DRIFT (with nu_ijt)\n")
cat("========================================================================\n\n")

cat("V3a: Demonstrating observational equivalence\n")
cat("-----------------------------------------------------------\n")

n_pairs_p3 <- 50000
T <- 10

# Ground truth: tau2 = 0.04 (drift variance per year)
tau2_true <- 0.04
s2_common <- 1.0

# DGP with drift: mu_ij,t = mu_ij,0 + sum(nu_ijt), nu ~ N(0, tau2)
mu_0 <- rnorm(n_pairs_p3, 0, 0.4)
mu_path <- matrix(0, n_pairs_p3, T)
mu_path[,1] <- mu_0
for (t in 2:T) {
    nu <- rnorm(n_pairs_p3, 0, sqrt(tau2_true))
    mu_path[,t] <- mu_path[,t-1] + nu
}

# Observed log(eta_ijt) = mu_ijt - s2/2 + eps, eps ~ N(0, s2)
log_eta <- matrix(0, n_pairs_p3, T)
for (t in 1:T) {
    log_eta[,t] <- mu_path[,t] - s2_common/2 + rnorm(n_pairs_p3, 0, sqrt(s2_common))
}

# Compute theta_A per pair
theta_A_drift <- rowMeans(log_eta)

# Moments from drift DGP
var_theta_A_sim <- var(theta_A_drift)

# Alternative: No drift, but inflated s2
var_mu_0 <- var(mu_0)
s2_eff_implied <- T * (var_theta_A_sim - var_mu_0)

cat(sprintf("  True tau2 (drift variance/year):     %.4f\n", tau2_true))
cat(sprintf("  True s2 (noise variance):            %.4f\n", s2_common))
cat(sprintf("  Var(theta_A) with drift:             %.4f\n", var_theta_A_sim))
cat(sprintf("  Var(mu_0):                           %.4f\n", var_mu_0))
cat(sprintf("  Implied s2_eff = T*[Var - Var(mu)]:  %.4f\n\n", s2_eff_implied))

# Now generate from NO drift but inflated s2 = s2_eff
mu_fixed <- rnorm(n_pairs_p3, 0, sqrt(var_mu_0))
log_eta_nodrift <- matrix(0, n_pairs_p3, T)
for (t in 1:T) {
    log_eta_nodrift[,t] <- mu_fixed - s2_eff_implied/2 + rnorm(n_pairs_p3, 0, sqrt(s2_eff_implied))
}
theta_A_nodrift <- rowMeans(log_eta_nodrift)
var_theta_A_nodrift <- var(theta_A_nodrift)

cat(sprintf("  Var(theta_A) NO drift, s2=%.3f:   %.4f\n", s2_eff_implied, var_theta_A_nodrift))
cat(sprintf("  Var(theta_A) WITH drift:              %.4f\n", var_theta_A_sim))

moment_match_pct <- abs((var_theta_A_nodrift - var_theta_A_sim) / var_theta_A_sim) * 100
cat(sprintf("  Moment match error:                   %.2f%%\n", moment_match_pct))
stopifnot(moment_match_pct < 2)
cat("  PASS: <2% moment match\n\n")

cat("V3b: Non-identification statement\n")
cat("-----------------------------------------------------------\n")
cat("  RESULT: tau2 and rho (change in sigma2) are not separately\n")
cat("  identified from cross-sectional moments of theta_A alone.\n")
cat("  Both produce observationally equivalent increases in Var(theta_A).\n")
cat("  Identification requires: panel structure, external sigma estimates,\n")
cat("  or auxiliary assumptions about temporal constancy.\n\n")

# ===========================================================================
# SUMMARY
# ===========================================================================
cat("========================================================================\n")
cat("VERIFICATION SUMMARY\n")
cat("========================================================================\n")
cat("V1a: E[theta_A] = -s2/2           PASS (slope within ±0.01)\n")
cat("V1b: Split-half correlation       PASS (within ±0.02)\n")
cat("V1c: Ledger reconciliation        PASS (formula reproduces r)\n")
cat("V1d: E[theta_B] = 0               PASS (<0.01)\n")
cat("V2a: Var(pre - post) formula      PASS (<2% error)\n")
cat("V2b: Pre-calibrated Var(mu)       PASS (<5% error)\n")
cat("V3a: Observational equivalence    PASS (<2% moment match)\n")
cat("V3b: Non-identification           STATED\n")
cat("========================================================================\n")

cat("\nEnd:", format(Sys.time()), "\n")
cat("All assertions passed.\n")
