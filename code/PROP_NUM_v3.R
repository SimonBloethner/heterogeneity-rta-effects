#!/usr/bin/env Rscript
# PROP-NUM v3: Numerical verification ONLY
# All formulas FROZEN as written

cat("========================================================================\n")
cat("PROP-NUM: Numerical Verification\n")
cat("Seed: 20260719\n")
cat("========================================================================\n\n")

set.seed(20260719)

results <- list()

# ===========================================================================
# [V1a] Jensen bias slope and mean
# ===========================================================================
cat("[V1a] Jensen bias verification\n")
cat("-----------------------------------------------------------\n")

n <- 100000
T_obs <- 10
sigma_ij <- runif(n, 0.3, 1.8)
sigma2_ij <- sigma_ij^2

theta_A <- numeric(n)
for (i in 1:n) {
    g <- rnorm(T_obs, mean = -sigma2_ij[i]/2, sd = sigma_ij[i])
    theta_A[i] <- mean(g)
}

reg <- lm(theta_A ~ sigma2_ij)
slope <- coef(reg)[2]
mean_theta_A <- mean(theta_A)
theory_mean <- -mean(sigma2_ij)/2
pct_err_mean <- abs((mean_theta_A - theory_mean)/theory_mean) * 100

cat(sprintf("  Regression slope:        %.5f\n", slope))
cat(sprintf("  Expected:               -0.50000\n"))
cat(sprintf("  Deviation:               %.5f\n", slope + 0.5))
stopifnot(abs(slope + 0.5) < 0.005)
cat("  PASS: within ±0.005\n\n")

cat(sprintf("  mean(theta_A):           %.5f\n", mean_theta_A))
cat(sprintf("  -mean(sigma^2)/2:        %.5f\n", theory_mean))
cat(sprintf("  Percent error:           %.3f%%\n", pct_err_mean))
stopifnot(pct_err_mean < 1)
cat("  PASS: <1%\n\n")

results$V1a <- "PASS"

# ===========================================================================
# [V1b] Split-half correlation
# ===========================================================================
cat("[V1b] Split-half correlation\n")
cat("-----------------------------------------------------------\n")

set.seed(20260719)
n <- 100000
T_half <- 5
sigma_ij <- runif(n, 0.3, 1.8)
sigma2_ij <- sigma_ij^2

theta_A1 <- numeric(n)
theta_A2 <- numeric(n)
for (i in 1:n) {
    g1 <- rnorm(T_half, mean = -sigma2_ij[i]/2, sd = sigma_ij[i])
    g2 <- rnorm(T_half, mean = -sigma2_ij[i]/2, sd = sigma_ij[i])
    theta_A1[i] <- mean(g1)
    theta_A2[i] <- mean(g2)
}

sim_corr <- cor(theta_A1, theta_A2)
var_s2 <- var(sigma2_ij)
mean_s2 <- mean(sigma2_ij)
formula_r <- (var_s2/4) / (var_s2/4 + mean_s2/5)

cat(sprintf("  Simulated correlation:   %.5f\n", sim_corr))
cat(sprintf("  Formula r:               %.5f\n", formula_r))
cat(sprintf("  Difference:              %.5f\n", sim_corr - formula_r))
stopifnot(abs(sim_corr - formula_r) < 0.01)
cat("  PASS: within ±0.01\n\n")

results$V1b <- "PASS"

# ===========================================================================
# [V1c] Consistency scan
# ===========================================================================
cat("[V1c] Consistency scan: Var(sigma^2) at E[sigma^2]=1.42, T_h=5\n")
cat("-----------------------------------------------------------\n")

var_s2_scan <- c(1.0, 1.5, 1.85, 2.5, 3.0)
E_s2 <- 1.42
T_h <- 5

cat("  Var(sigma^2)    r_formula\n")
for (v in var_s2_scan) {
    r_v <- (v/4) / (v/4 + E_s2/T_h)
    cat(sprintf("  %.2f            %.4f\n", v, r_v))
}
cat("  ---------------------------\n")
cat("  Reference (ledger): r = 0.62\n\n")

results$V1c <- "SCAN"

# ===========================================================================
# [V1d] Definition B bias gap
# ===========================================================================
cat("[V1d] Definition B: lognormal mean estimator\n")
cat("-----------------------------------------------------------\n")

set.seed(20260719)
sigma <- 1.19
T_obs <- 10
B <- 200000

theta_B <- numeric(B)
for (i in 1:B) {
    log_vals <- rnorm(T_obs, mean = -sigma^2/2, sd = sigma)
    eta_vals <- exp(log_vals)
    theta_B[i] <- log(mean(eta_vals))
}

sim_mean <- mean(theta_B)
frozen_approx <- -0.5 * (exp(sigma^2) - 1) / T_obs
gap <- sim_mean - frozen_approx

cat(sprintf("  Simulated mean(theta_B): %.6f\n", sim_mean))
cat(sprintf("  Frozen approximation:    %.6f\n", frozen_approx))
cat(sprintf("  Gap:                     %.6f\n", gap))
cat("  (No tolerance - gap is the deliverable)\n\n")

results$V1d <- "REPORTED"

# ===========================================================================
# [V2a] Size-decile drift verification
# ===========================================================================
cat("[V2a] Size-decile drift: theta_A by decile\n")
cat("-----------------------------------------------------------\n")

set.seed(20260719)
n <- 50000
T_pre <- 10

Z_size <- rnorm(n)
delta_ij <- -0.005 - 0.015 * Z_size + rnorm(n, 0, 0.01)
sigma_ij <- runif(n, 0.3, 1.8)
sigma2_ij <- sigma_ij^2

theta_A <- numeric(n)
for (i in 1:n) {
    g_post <- numeric(10)
    for (t in 11:20) {
        g_post[t-10] <- -sigma2_ij[i]/2 + delta_ij[i] * (t - 10.5) + rnorm(1, 0, sigma_ij[i])
    }
    theta_A[i] <- mean(g_post)
}

deciles <- cut(Z_size, breaks = quantile(Z_size, probs = 0:10/10), 
               include.lowest = TRUE, labels = 1:10)

cat("  Decile  Sim_mean     Formula      Pct_err\n")
all_pass <- TRUE
for (d in 1:10) {
    idx <- which(deciles == d)
    sim_mean_d <- mean(theta_A[idx])
    mean_s2_d <- mean(sigma2_ij[idx])
    mean_delta_d <- mean(delta_ij[idx])
    formula_d <- -mean_s2_d/2 + mean_delta_d * T_pre / 2
    pct_err_d <- abs((sim_mean_d - formula_d) / formula_d) * 100
    cat(sprintf("  %2d      %.4f       %.4f       %.2f%%\n", d, sim_mean_d, formula_d, pct_err_d))
    if (pct_err_d >= 5) all_pass <- FALSE
}
stopifnot(all_pass)
cat("  PASS: all deciles <5%\n\n")

results$V2a <- "PASS"

# ===========================================================================
# [V2b] Pseudo-year R^2
# ===========================================================================
cat("[V2b] Pseudo-adoption year R^2\n")
cat("-----------------------------------------------------------\n")

set.seed(20260719)
n <- 50000
T_pre <- 10
T_post <- 10

pseudo_year <- sample(1991:2016, n, replace = TRUE)
Z_size <- rnorm(n)
delta_ij <- -0.005 - 0.015 * Z_size + rnorm(n, 0, 0.01)
sigma_ij <- runif(n, 0.3, 1.8)
sigma2_ij <- sigma_ij^2

theta_A <- numeric(n)
for (i in 1:n) {
    g_post <- numeric(T_post)
    for (t in 1:T_post) {
        t_cal <- T_pre + t
        g_post[t] <- -sigma2_ij[i]/2 + delta_ij[i] * (t_cal - 10.5) + rnorm(1, 0, sigma_ij[i])
    }
    theta_A[i] <- mean(g_post)
}

df <- data.frame(theta_A = theta_A, pseudo_year = factor(pseudo_year))
reg_year <- lm(theta_A ~ pseudo_year, data = df)
r2 <- summary(reg_year)$r.squared

cat(sprintf("  R^2 from year dummies:   %.5f\n", r2))
cat(sprintf("  R^2 as percent:          %.3f%%\n", r2 * 100))
stopifnot(r2 < 0.02)
cat("  PASS: R^2 < 2%\n\n")

results$V2b <- "PASS"

# ===========================================================================
# [V3a] Prop-3 model tau^2 recovery
# ===========================================================================
cat("[V3a] Prop-3 tau^2 recovery\n")
cat("-----------------------------------------------------------\n")

set.seed(20260719)
n <- 50000
T_pre <- 10
T_post <- 10
tau <- 0.40
omega <- 0.25
rho <- 1.3
theta_mean <- 0.29

sigma_ij <- runif(n, 0.3, 1.8)
sigma2_ij <- sigma_ij^2
theta_ij <- rnorm(n, theta_mean, tau)

g_pre <- matrix(0, n, T_pre)
g_post <- matrix(0, n, T_post)

for (i in 1:n) {
    w_pre <- rnorm(T_pre)
    w_post <- rnorm(T_post)
    g_pre[i,] <- theta_ij[i] + omega * w_pre + rnorm(T_pre, 0, sigma_ij[i])
    g_post[i,] <- theta_ij[i] + omega * w_post + rnorm(T_post, 0, rho * sigma_ij[i])
}

Vpre_hat <- apply(g_pre, 1, var)
Vpost_hat <- apply(g_post, 1, var)
theta_hat <- rowMeans(g_post)

tau2_hat <- var(theta_hat) - mean(Vpost_hat) / T_post

cat(sprintf("  var(theta_hat):          %.5f\n", var(theta_hat)))
cat(sprintf("  mean(Vpost_hat)/10:      %.5f\n", mean(Vpost_hat)/T_post))
cat(sprintf("  tau2_hat:                %.5f\n", tau2_hat))
cat(sprintf("  Target (0.16):           0.16000\n"))
pct_err_tau2 <- abs((tau2_hat - 0.16) / 0.16) * 100
cat(sprintf("  Percent error:           %.2f%%\n", pct_err_tau2))
stopifnot(pct_err_tau2 < 2)
cat("  PASS: <2%\n\n")

results$V3a <- "PASS"

# ===========================================================================
# [V3b] Two worlds observational equivalence
# ===========================================================================
cat("[V3b] Two worlds: omega^2 vs rho^2 equivalence\n")
cat("-----------------------------------------------------------\n")

set.seed(20260719)
n <- 50000
T_pre <- 10
T_post <- 10
tau <- 0.40
theta_mean <- 0.29

sigma_ij <- runif(n, 0.3, 1.8)
sigma2_ij <- sigma_ij^2
theta_ij <- rnorm(n, theta_mean, tau)

# World A: omega^2 = 0.36, rho = 1
omega_A <- sqrt(0.36)
rho_A <- 1

g_pre_A <- matrix(0, n, T_pre)
g_post_A <- matrix(0, n, T_post)
for (i in 1:n) {
    w_pre <- rnorm(T_pre)
    w_post <- rnorm(T_post)
    g_pre_A[i,] <- theta_ij[i] + omega_A * w_pre + rnorm(T_pre, 0, sigma_ij[i])
    g_post_A[i,] <- theta_ij[i] + omega_A * w_post + rnorm(T_post, 0, rho_A * sigma_ij[i])
}

Vpre_A <- apply(g_pre_A, 1, var)
Vpost_A <- apply(g_post_A, 1, var)
theta_A_world <- rowMeans(g_post_A)

# World B: omega = 0, rho^2 = 1 + 0.36/sigma_ij^2
set.seed(20260719)
sigma_ij_B <- runif(n, 0.3, 1.8)
sigma2_ij_B <- sigma_ij_B^2
theta_ij_B <- rnorm(n, theta_mean, tau)
rho2_B <- 1 + 0.36 / sigma2_ij_B

g_pre_B <- matrix(0, n, T_pre)
g_post_B <- matrix(0, n, T_post)
for (i in 1:n) {
    g_pre_B[i,] <- theta_ij_B[i] + rnorm(T_pre, 0, sigma_ij_B[i])
    g_post_B[i,] <- theta_ij_B[i] + rnorm(T_post, 0, sqrt(rho2_B[i]) * sigma_ij_B[i])
}

Vpre_B <- apply(g_pre_B, 1, var)
Vpost_B <- apply(g_post_B, 1, var)
theta_B_world <- rowMeans(g_post_B)

cat("  Moment             World_A      World_B      Pct_diff\n")
mean_Vpre_A <- mean(Vpre_A)
mean_Vpre_B <- mean(Vpre_B)
pct_Vpre <- abs((mean_Vpre_A - mean_Vpre_B) / mean_Vpre_A) * 100
cat(sprintf("  mean(Vpre)         %.5f      %.5f      %.2f%% (structural diff)\n", 
            mean_Vpre_A, mean_Vpre_B, pct_Vpre))

mean_Vpost_A <- mean(Vpost_A)
mean_Vpost_B <- mean(Vpost_B)
pct_Vpost <- abs((mean_Vpost_A - mean_Vpost_B) / mean_Vpost_A) * 100
cat(sprintf("  mean(Vpost)        %.5f      %.5f      %.2f%%\n", 
            mean_Vpost_A, mean_Vpost_B, pct_Vpost))

var_theta_A <- var(theta_A_world)
var_theta_B <- var(theta_B_world)
pct_var <- abs((var_theta_A - var_theta_B) / var_theta_A) * 100
cat(sprintf("  var(theta_hat)     %.5f      %.5f      %.2f%%\n", 
            var_theta_A, var_theta_B, pct_var))

stopifnot(pct_Vpost < 1)
stopifnot(pct_var < 1)
cat("  PASS: Vpost and var(theta) <1%\n")
cat("  NOTE: Vpre differs by design (omega in A only)\n\n")

# KS test
dev_A <- (g_post_A - rowMeans(g_post_A)) / sqrt(Vpost_A)
dev_B <- (g_post_B - rowMeans(g_post_B)) / sqrt(Vpost_B)
pooled_A <- as.vector(dev_A)
pooled_B <- as.vector(dev_B)
ks_test <- ks.test(pooled_A, pooled_B)

cat(sprintf("  KS test D:               %.5f\n", ks_test$statistic))
cat(sprintf("  KS test p-value:         %.4f\n", ks_test$p.value))
cat("  (Expectation: no rejection)\n\n")

results$V3b <- "PASS"

# ===========================================================================
# [V3c] Calibration and mis-windowed estimator
# ===========================================================================
cat("[V3c] Calibration: mis-windowed estimator\n")
cat("-----------------------------------------------------------\n")

tau <- 0.40
omega <- 0
rho <- 1
T_obs <- 10
kappa_w <- 2.4

# Calibrate sigma for recovered = 0.35 at rho = 1
sigma_calib <- sqrt((0.16 - 0.1225) / 0.14)
sigma2_calib <- sigma_calib^2

cat(sprintf("  Calibrated sigma:        %.5f\n", sigma_calib))
cat(sprintf("  Calibrated sigma^2:      %.5f\n", sigma2_calib))

# Formula at rho = 1
rec2_rho1 <- tau^2 - (kappa_w - 1) * sigma2_calib * 1 / T_obs
rec_rho1 <- sqrt(max(rec2_rho1, 0))
cat(sprintf("  Formula recovered (rho=1):   %.5f\n", rec_rho1))

# Formula at rho = 2.5
rho_alt <- 2.5
rec2_rho25 <- tau^2 - (kappa_w - 1) * sigma2_calib * rho_alt^2 / T_obs
rec_rho25 <- sqrt(max(rec2_rho25, 0))
cat(sprintf("  Formula recovered (rho=2.5): %.5f\n", rec_rho25))

cat(sprintf("  Ledgered P4 pair:            (0.35, 0.06)\n\n"))

# SIMULATION: Mis-windowed estimator over-subtracts by factor kappa_w
# recovered^2 = var(theta_hat) - kappa_w * mean(Vpost)/T

set.seed(20260719)
n <- 50000
T_pre <- 10
T_post <- 10
tau <- 0.40
theta_mean <- 0.29
kappa_w <- 2.4

# Scenario 1: rho = 1
theta_ij_s1 <- rnorm(n, theta_mean, tau)

g_post_s1 <- matrix(0, n, T_post)
for (i in 1:n) {
    g_post_s1[i,] <- theta_ij_s1[i] + rnorm(T_post, 0, 1 * sigma_calib)
}

Vpost_s1 <- apply(g_post_s1, 1, var)
theta_hat_s1 <- rowMeans(g_post_s1)

# Mis-windowed: over-subtracts by kappa_w
var_theta_s1 <- var(theta_hat_s1)
rec2_sim_s1 <- var_theta_s1 - kappa_w * mean(Vpost_s1) / T_post
rec_sim_s1 <- sqrt(max(rec2_sim_s1, 0))

cat(sprintf("  Sim recovered (rho=1):       %.5f\n", rec_sim_s1))
cat(sprintf("  Formula prediction:          %.5f\n", rec_rho1))
stopifnot(abs(rec_sim_s1 - rec_rho1) < 0.03)
cat("  PASS: within ±0.03\n")

# Scenario 2: rho = 2.5
set.seed(20260719)
theta_ij_s2 <- rnorm(n, theta_mean, tau)

g_post_s2 <- matrix(0, n, T_post)
for (i in 1:n) {
    g_post_s2[i,] <- theta_ij_s2[i] + rnorm(T_post, 0, 2.5 * sigma_calib)
}

Vpost_s2 <- apply(g_post_s2, 1, var)
theta_hat_s2 <- rowMeans(g_post_s2)

var_theta_s2 <- var(theta_hat_s2)
rec2_sim_s2 <- var_theta_s2 - kappa_w * mean(Vpost_s2) / T_post
rec_sim_s2 <- sqrt(max(rec2_sim_s2, 0))

cat(sprintf("  Sim recovered (rho=2.5):     %.5f\n", rec_sim_s2))
cat(sprintf("  Formula prediction:          %.5f\n", rec_rho25))
stopifnot(abs(rec_sim_s2 - rec_rho25) < 0.03)
cat("  PASS: within ±0.03\n\n")

results$V3c <- "PASS"

# ===========================================================================
# SUMMARY
# ===========================================================================
cat("========================================================================\n")
cat("PASS/FAIL SUMMARY\n")
cat("========================================================================\n")
cat("Check    Status\n")
cat("------   ------\n")
for (nm in names(results)) {
    cat(sprintf("%-8s %s\n", nm, results[[nm]]))
}
cat("========================================================================\n\n")

# ===========================================================================
# AMBIGUITIES
# ===========================================================================
cat("========================================================================\n")
cat("AMBIGUITIES\n")
cat("========================================================================\n")
cat("1. [V1d] theta_B = log(mean(eta)) where eta ~ lognormal. The frozen\n")
cat("   approximation -0.5*(exp(s^2)-1)/T is a Jensen correction. Gap\n")
cat("   reported as deliverable; no tolerance applied.\n")
cat("\n")
cat("2. [V3b] World A has omega in BOTH pre and post; World B has omega=0.\n")
cat("   Pre-periods structurally differ by omega^2=0.36. Observational\n")
cat("   equivalence applies to POST moments only. Tolerance of 1% checked\n")
cat("   on Vpost and var(theta); Vpre reported but not tolerance-checked.\n")
cat("\n")
cat("3. [V3c] \"Mis-windowed estimator\" interpreted as over-subtracting\n")
cat("   noise by factor kappa_w: recovered^2 = var(theta) - kappa_w*Vpost/T.\n")
cat("   This matches the frozen formula bias structure.\n")
cat("========================================================================\n")
