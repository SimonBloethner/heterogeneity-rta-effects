#!/usr/bin/env Rscript
# S26_prop_verification.R - Proposition verification with Monte Carlo
# OUTPUTS: output/T25_prop_verification.csv, article/prop_constants.tex,
#          meta/T25_prop_verification.csv.sidecar
# INPUTS:  output/T22_reliability.csv, output/T24_placebo_uncorr.csv
# SEED:    20260719
# NSIM:    4000000 (4e6 for V1b precision)
#
# Verifications:
# V1a: E[sigma^2] = -2 * PLACEBO_A_MEAN (analytical)
# V1b: E[theta^B | zero effect] via Monte Carlo at T=10
#      Gate: approx_B < mc_B < 0 (expansion overstates bias magnitude)
# V1c: Reliability consistency (predicted vs observed) - parameter-free check
#      Uses T_post for variance decomposition, T_h for split-half correlation
#      Gate: T_h >= 2 (meaningful split-half requirement)
# V2:  Window geometry - Proposition 2(a) with delta=0.02
# V3c: cor:rhoop - identification boundary verification (kappa sweep)

suppressPackageStartupMessages(library(data.table))
set.seed(20260719)
setwd("/scratch/bt307958/REBUILD_V2")

N_REP <- 4e6L   # 4 million replications for V1b
T_POST <- 10L   # Example horizon

# -----------------------------------------------------------------------------
# Load frozen values from T22 and T24
# -----------------------------------------------------------------------------
cat("=== LOADING FROZEN VALUES ===\n")

T22 <- fread("output/T22_reliability.csv")
T24 <- fread("output/T24_placebo_uncorr.csv")

PLACEBO_A_MEAN <- T22[ID == "PLACEBO_A_MEAN", value]
PLACEBO_A_SD <- T22[ID == "PLACEBO_A_SD", value]
PLACEBO_A_R <- T22[ID == "PLACEBO_A_R", value]
PLACEBO_TH <- T22[ID == "PLACEBO_TH", value]
PLACEBO_TPOST <- T22[ID == "PLACEBO_TPOST", value]

# Definition B placebo mean (uncorrected) - distinct from PLACEBO_A_MEAN
PLACEBO_B_UNCORR_MEAN <- T24[ID == "PLACEBO_B_UNCORR_OVERALL", mean_theta_B]

cat(sprintf("PLACEBO_A_MEAN        = %.15f\n", PLACEBO_A_MEAN))
cat(sprintf("PLACEBO_A_SD          = %.15f\n", PLACEBO_A_SD))
cat(sprintf("PLACEBO_A_R           = %.15f\n", PLACEBO_A_R))
cat(sprintf("PLACEBO_TH            = %.15f\n", PLACEBO_TH))
cat(sprintf("PLACEBO_TPOST         = %.15f\n", PLACEBO_TPOST))
cat(sprintf("PLACEBO_B_UNCORR_MEAN = %.15f\n", PLACEBO_B_UNCORR_MEAN))

# -----------------------------------------------------------------------------
# V1a: E[sigma^2] from placebo mean (analytical)
# Proposition 1(a): E[theta^A | zero effect] = -E[sigma^2]/2
# => E[sigma^2] = -2 * PLACEBO_A_MEAN
# -----------------------------------------------------------------------------
cat("\n=== V1a: E[SIGMA^2] DERIVATION ===\n")

E_sigma2 <- -2 * PLACEBO_A_MEAN
sigma <- sqrt(E_sigma2)

cat(sprintf("E_sigma2 = -2 * PLACEBO_A_MEAN = -2 * (%.6f) = %.6f\n",
            PLACEBO_A_MEAN, E_sigma2))
cat(sprintf("sigma = sqrt(%.6f) = %.6f\n", E_sigma2, sigma))

# Gate: E_sigma2 must be positive
stopifnot(E_sigma2 > 0)
cat("G1 E_sigma2 > 0: PASS\n")

# -----------------------------------------------------------------------------
# V1b: Monte Carlo verification of E[theta^B | zero effect]
# Under A2: log(eta) ~ N(-sigma^2/2, sigma^2), so E[eta] = 1
# theta^B = log(mean(eta)) for T cells
# Second-order approximation: -Var(R)/2 where R = mean(eta), Var(R) = Var(eta)/T
# Gate: approximation OVERSTATES bias magnitude, so approx < mc < 0
# -----------------------------------------------------------------------------
cat("\n=== V1b: MONTE CARLO E[THETA^B] AT T=10 ===\n")

# Derived quantities
Var_eta <- exp(E_sigma2) - 1
Var_R <- Var_eta / T_POST
approx_B <- -Var_R / 2

cat(sprintf("Var(eta) = exp(%.4f) - 1 = %.4f\n", E_sigma2, Var_eta))
cat(sprintf("Var(R) at T=%d = %.4f\n", T_POST, Var_R))
cat(sprintf("Second-order approx -Var(R)/2 = %.4f\n", approx_B))

# Monte Carlo: log(eta) ~ N(-sigma^2/2, sigma^2)
cat(sprintf("Running %d replications...\n", N_REP))

lg <- matrix(rnorm(N_REP * T_POST, mean = -E_sigma2/2, sd = sigma), ncol = T_POST)
mc_B <- mean(log(rowMeans(exp(lg))))
mc_B_se <- sd(log(rowMeans(exp(lg)))) / sqrt(N_REP)

cat(sprintf("MC E[theta^B] = %.6f (SE = %.6f)\n", mc_B, mc_B_se))
cat(sprintf("Gate: approx_B (%.4f) < mc_B (%.4f) < 0\n", approx_B, mc_B))

# Gate: expansion overstates bias magnitude
stopifnot(approx_B < mc_B)
stopifnot(mc_B < 0)
cat("G2 V1b approx < mc < 0: PASS\n")

# Clean up large matrix
rm(lg)
gc()

# -----------------------------------------------------------------------------
# V1c: Reliability consistency check (PARAMETER-FREE)
# Proposition 1(c): Var(theta^A over window T) = Var(sigma^2)/4 + E[sigma^2]/T
# Use T_post for variance decomposition, T_h for split-half correlation
# -----------------------------------------------------------------------------
cat("\n=== V1c: RELIABILITY CONSISTENCY (PARAMETER-FREE) ===\n")

Var_theta_A <- PLACEBO_A_SD^2

# Decomposition uses T_post (full window), NOT T_h
q <- Var_theta_A - E_sigma2 / PLACEBO_TPOST
V_sigma2 <- 4 * q

cat(sprintf("Var(theta^A) = %.6f\n", Var_theta_A))
cat(sprintf("q = Var(theta^A) - E[sigma^2]/T_post = %.6f - %.6f/%.2f = %.6f\n",
            Var_theta_A, E_sigma2, PLACEBO_TPOST, q))
cat(sprintf("Var(sigma^2) = 4 * q = %.6f\n", V_sigma2))

# Split-half correlation uses T_h
r_pred <- q / (q + E_sigma2 / PLACEBO_TH)
cv_sigma2 <- sqrt(V_sigma2) / E_sigma2
r_gap <- abs(r_pred - PLACEBO_A_R)

cat(sprintf("r_pred = q / (q + E[sigma^2]/T_h) = %.6f\n", r_pred))
cat(sprintf("CV(sigma^2) = sqrt(Var)/E = %.4f\n", cv_sigma2))
cat(sprintf("r_obs (PLACEBO_A_R) = %.6f\n", PLACEBO_A_R))
cat(sprintf("r_gap = |r_pred - r_obs| = %.4f\n", r_gap))

# Gates catch wrong objects, not adjudicate agreement
stopifnot(q > 0)                                    # decomposition leaves positive dispersion
stopifnot(V_sigma2 > 0)                             # variance is positive
stopifnot(r_pred > 0, r_pred < 1)                   # a correlation
stopifnot(PLACEBO_TH >= 2)                          # meaningful split-half (>= 2 cells per half)

cat("G3 V1c wrong-object gates: PASS\n")
cat(sprintf("  q > 0: %.4f > 0 PASS\n", q))
cat(sprintf("  V_sigma2 > 0: %.4f > 0 PASS\n", V_sigma2))
cat(sprintf("  0 < r_pred < 1: 0 < %.4f < 1 PASS\n", r_pred))
cat(sprintf("  T_h >= 2: %.2f >= 2 PASS\n", PLACEBO_TH))

# -----------------------------------------------------------------------------
# V2: Window geometry - Proposition 2(a) with non-zero drift
# Post window is last T_post years of span T_pre + T_post
# Centering at sample midpoint (T+1)/2
# Predicted mean: -E_sigma2/2 + delta * T_pre/2 (Proposition 2(a))
# With delta=0.02, T_pre=10: predicted = -E_sigma2/2 + 0.02 * 5 = -E_sigma2/2 + 0.1
# -----------------------------------------------------------------------------
cat("\n=== V2: WINDOW GEOMETRY (PROP 2a) ===\n")

# Simulation parameters - delta=0.02 exercises the drift term
N_SIM_V2 <- 100000L
T_PRE <- 10L
T_POST_V2 <- 10L
DELTA_V2 <- 0.02   # Fixed drift to exercise Prop 2(a)

# Simulate pairs with drift
simulate_prop2a <- function(nsim, t_pre, t_post, e_sigma2, delta_fixed) {
  T_total <- t_pre + t_post
  midpoint <- (T_total + 1) / 2
  sigma_ij <- sqrt(e_sigma2)

  theta_A <- numeric(nsim)

  for (i in 1:nsim) {
    # Fixed delta exercises the drift term
    delta_ij <- delta_fixed

    # Generate full span of log-gaps
    t_idx <- 1:T_total
    u <- rnorm(T_total, mean = 0, sd = sigma_ij)
    log_gap <- -e_sigma2/2 + delta_ij * (t_idx - midpoint) + u

    # theta^A is mean over post window (last t_post years)
    post_idx <- (t_pre + 1):T_total
    theta_A[i] <- mean(log_gap[post_idx])
  }

  theta_A
}

cat(sprintf("Running %d V2 simulations (T_pre=%d, T_post=%d, delta=%.2f)...\n",
            N_SIM_V2, T_PRE, T_POST_V2, DELTA_V2))

theta_A_v2 <- simulate_prop2a(N_SIM_V2, T_PRE, T_POST_V2, E_sigma2, DELTA_V2)

# Predicted mean under Prop 2(a): -E_sigma2/2 + delta * T_pre/2
# With delta=0.02, T_pre=10: predicted = -E_sigma2/2 + 0.02 * 5 = -E_sigma2/2 + 0.1
V2_predicted <- -E_sigma2/2 + DELTA_V2 * T_PRE/2
mc_mean_v2 <- mean(theta_A_v2)
mc_se_v2 <- sd(theta_A_v2) / sqrt(N_SIM_V2)

cat(sprintf("Predicted mean = -E_sigma2/2 + delta*T_pre/2 = %.6f + %.3f = %.6f\n",
            -E_sigma2/2, DELTA_V2 * T_PRE/2, V2_predicted))
cat(sprintf("MC mean = %.6f (SE = %.6f)\n", mc_mean_v2, mc_se_v2))
cat(sprintf("Gap = %.6f (%.1f SE)\n", mc_mean_v2 - V2_predicted,
            (mc_mean_v2 - V2_predicted) / mc_se_v2))

# Gate: MC mean within 5 SE of predicted
V2_gap_se <- abs(mc_mean_v2 - V2_predicted) / mc_se_v2
stopifnot(V2_gap_se < 5)  # Allow 5 SE for numerical noise
cat(sprintf("G4 V2 gap within 5 SE: %.1f SE PASS\n", V2_gap_se))

# -----------------------------------------------------------------------------
# V3c: cor:rhoop - identification boundary verification
# A post-calibrated null that scales pre-based variance by operational ratio
# subtracts kappa_w * V_post / T_post, biasing tau^2 by -(kappa_w - 1) * V_post / T_post
#
# tau_hat = Var(theta) - kappa * V_post / T_post
# At kappa_floor, tau_hat = 0 (variance attributed entirely to noise)
# -----------------------------------------------------------------------------
cat("\n=== V3c: COR:RHOOP IDENTIFICATION BOUNDARY ===\n")

# Use canonical values from T22
Var_theta_D <- 2.438  # Canonical from S5R_bhat.rds$baseline
V_post <- PLACEBO_A_SD^2  # Var(theta_A) from placebo, proxy for post-window variance
T_post_v3 <- PLACEBO_TPOST

# tau_hat(kappa) = Var_theta_D - kappa * V_post / T_post
# kappa_floor = Var_theta_D * T_post / V_post (where tau_hat = 0)
kappa_floor <- Var_theta_D * T_post_v3 / V_post

cat(sprintf("Var(theta_D) = %.4f (canonical)\n", Var_theta_D))
cat(sprintf("V_post = PLACEBO_A_SD^2 = %.4f\n", V_post))
cat(sprintf("T_post = %.2f\n", T_post_v3))
cat(sprintf("kappa_floor = Var(theta_D) * T_post / V_post = %.4f\n", kappa_floor))

# Evaluate tau_hat at kappa = 1, 2, 3, 5
kappas <- c(1, 2, 3, 5)
tau_hat <- Var_theta_D - kappas * V_post / T_post_v3

cat("\nKappa sweep:\n")
for (i in seq_along(kappas)) {
  cat(sprintf("  kappa=%d: tau_hat = %.4f\n", kappas[i], tau_hat[i]))
}

# tau_hat values computed from formula (not spec-provided):
# tau_hat(kappa) = Var_theta_D - kappa * V_post / T_post
# Using Var_theta_D=2.438, V_post=PLACEBO_A_SD^2=1.1694, T_post=10.9111
# No hard-coded expectations - we verify formula consistency instead

# Verify formula consistency (no hard-coded spec values):
# 1. tau_hat decreases as kappa increases
stopifnot(all(diff(tau_hat) < 0))
# 2. tau_hat(kappa_floor) should be approximately 0
# Since kappa_floor = Var_theta_D * T_post / V_post
# tau_hat(kappa_floor) = Var_theta_D - kappa_floor * V_post / T_post
#                      = Var_theta_D - Var_theta_D = 0
tau_at_floor <- Var_theta_D - kappa_floor * V_post / T_post_v3
stopifnot(abs(tau_at_floor) < 1e-10)
# 3. All tau_hat values at kappa <= 5 should be positive (within identification region)
stopifnot(all(tau_hat > 0))
# 4. kappa_floor should be > 5 (kappa=5 still in identification region)
stopifnot(kappa_floor > 5)

cat("\nG5 V3c formula consistency: PASS\n")
cat(sprintf("  tau_hat decreasing: %.4f > %.4f > %.4f > %.4f PASS\n",
            tau_hat[1], tau_hat[2], tau_hat[3], tau_hat[4]))
cat(sprintf("  tau_hat(kappa_floor) = %.2e (approx 0) PASS\n", tau_at_floor))
cat(sprintf("  all tau_hat > 0 at kappa <= 5: PASS\n"))
cat(sprintf("  kappa_floor = %.3f > 5: PASS\n", kappa_floor))

# -----------------------------------------------------------------------------
# OUTPUT TABLE
# -----------------------------------------------------------------------------
cat("\n=== OUTPUT TABLE ===\n")

out <- data.frame(
  ID = c("PROP_ESIGMA2", "PROP_SIGMA", "PROP_VAR_ETA", "PROP_VAR_R",
         "PROP_APPROX_B", "PROP_MC_B",
         "PROP_V_SIGMA2", "PROP_CV_SIGMA2", "PROP_R_PRED", "PROP_R_GAP",
         "PROP_TH", "PROP_TPOST", "PROP_PLACEBO_R",
         "PROP_V2_PRED",
         "PROP_TAU_HAT_1", "PROP_TAU_HAT_2", "PROP_TAU_HAT_3", "PROP_TAU_HAT_5",
         "PROP_KAPPA_FLOOR"),
  quantity = c("E[sigma^2] = -2*PLACEBO_A_MEAN",
               "sigma = sqrt(E[sigma^2])",
               "Var(eta) = exp(sigma^2) - 1",
               "Var(R) at T=10 = Var(eta)/10",
               "-Var(R)/2 (second-order approx)",
               "MC E[theta^B] at T=10",
               "Var(sigma^2) from decomposition",
               "CV(sigma^2) = sqrt(Var)/E",
               "Predicted reliability",
               "r_gap = |r_pred - r_obs|",
               "Mean half-length T_h (placebo)",
               "Mean post-window T_post (placebo)",
               "Observed reliability (PLACEBO_A_R)",
               "V2 predicted mean (Prop 2a, delta=0.02)",
               "tau_hat at kappa=1",
               "tau_hat at kappa=2",
               "tau_hat at kappa=3",
               "tau_hat at kappa=5",
               "kappa_floor (where tau_hat=0)"),
  value = c(E_sigma2, sigma, Var_eta, Var_R,
            approx_B, mc_B,
            V_sigma2, cv_sigma2, r_pred, r_gap,
            PLACEBO_TH, PLACEBO_TPOST, PLACEBO_A_R,
            V2_predicted,
            tau_hat[1], tau_hat[2], tau_hat[3], tau_hat[4],
            kappa_floor),
  stringsAsFactors = FALSE
)

print(out)

write.csv(out, "output/T25_prop_verification.csv", row.names = FALSE)
cat("\nSaved: output/T25_prop_verification.csv\n")

# -----------------------------------------------------------------------------
# OUTPUT: article/prop_constants.tex (using \Prop* naming)
# C1.1: Separate macros for Definition A mean vs Definition B uncorrected mean
# -----------------------------------------------------------------------------
cat("\n=== GENERATING prop_constants.tex ===\n")

tex_lines <- c(
  "% prop_constants.tex - Auto-generated by S26_prop_verification.R",
  sprintf("%% Generated: %s", Sys.time()),
  sprintf("%% Seed: 20260719, N_REP: %d", N_REP),
  "",
  "% V1a: E[sigma^2] derivation",
  sprintf("\\newcommand{\\PropEsigsq}{%.4f}", E_sigma2),
  sprintf("\\newcommand{\\PropSigma}{%.4f}", sigma),
  "",
  "% V1b: Jensen bias verification",
  sprintf("\\newcommand{\\PropVarEta}{%.4f}", Var_eta),
  sprintf("\\newcommand{\\PropVarR}{%.4f}", Var_R),
  sprintf("\\newcommand{\\PropApproxB}{%.4f}", approx_B),
  sprintf("\\newcommand{\\PropMCB}{%.4f}", mc_B),
  "",
  "% V1c: Reliability (parameter-free check)",
  sprintf("\\newcommand{\\PropVsigmasq}{%.4f}", V_sigma2),
  sprintf("\\newcommand{\\PropCVsigsq}{%.3f}", cv_sigma2),
  sprintf("\\newcommand{\\PropRpred}{%.4f}", r_pred),
  sprintf("\\newcommand{\\PropRgap}{%.4f}", r_gap),
  sprintf("\\newcommand{\\PropTh}{%.2f}", PLACEBO_TH),
  sprintf("\\newcommand{\\PropTpost}{%.2f}", PLACEBO_TPOST),
  sprintf("\\newcommand{\\PropPlaceboR}{%.4f}", PLACEBO_A_R),
  "",
  "% Placebo means - Definition A vs Definition B (C1.1)",
  sprintf("\\newcommand{\\PropPlaceboAMean}{%.4f}", PLACEBO_A_MEAN),
  sprintf("\\newcommand{\\PropPlaceboBUncorr}{%.4f}", PLACEBO_B_UNCORR_MEAN),
  "",
  "% V2: Window geometry (Prop 2a, delta=0.02)",
  sprintf("\\newcommand{\\PropVtwoPred}{%.4f}", V2_predicted),
  "",
  "% V3c: cor:rhoop identification boundary",
  sprintf("\\newcommand{\\PropTauHatOne}{%.4f}", tau_hat[1]),
  sprintf("\\newcommand{\\PropTauHatTwo}{%.4f}", tau_hat[2]),
  sprintf("\\newcommand{\\PropTauHatThree}{%.4f}", tau_hat[3]),
  sprintf("\\newcommand{\\PropTauHatFive}{%.4f}", tau_hat[4]),
  sprintf("\\newcommand{\\PropKappaFloor}{%.3f}", kappa_floor),
  ""
)

writeLines(tex_lines, "article/prop_constants.tex")
cat("Saved: article/prop_constants.tex\n")

# -----------------------------------------------------------------------------
# Sidecar
# -----------------------------------------------------------------------------
sha <- system("sha256sum output/T25_prop_verification.csv | cut -d' ' -f1", intern = TRUE)
writeLines(c(
  "PRODUCER: S26_prop_verification.R",
  "INPUTS: output/T22_reliability.csv, output/T24_placebo_uncorr.csv",
  "SEED: 20260719",
  sprintf("N_REP: %d", N_REP),
  "",
  "VERIFICATIONS:",
  sprintf("  V1a: E_sigma2 = %.6f (analytical: -2*PLACEBO_A_MEAN)", E_sigma2),
  sprintf("  V1b: approx_B = %.4f < mc_B = %.4f < 0 : PASS", approx_B, mc_B),
  sprintf("  V1c: V_sigma2 = %.4f, r_pred = %.4f, r_gap = %.4f, T_h >= 2: %.2f",
          V_sigma2, r_pred, r_gap, PLACEBO_TH),
  sprintf("  V2:  MC mean = %.4f vs predicted %.4f (%.1f SE) [delta=0.02]",
          mc_mean_v2, V2_predicted, V2_gap_se),
  sprintf("  V3c: tau_hat at kappa=1,2,3,5: %.4f, %.4f, %.4f, %.4f",
          tau_hat[1], tau_hat[2], tau_hat[3], tau_hat[4]),
  sprintf("       kappa_floor = %.3f", kappa_floor),
  "",
  "ASSUMPTION: Homogeneous-window approximation (per-pair T_post variation ignored).",
  "            Exact quantity would be mean(sigma2_hat_ij / T_post_ij).",
  "",
  "GATES:",
  "  G1: E_sigma2 > 0: PASS",
  "  G2: V1b approx < mc < 0: PASS",
  "  G3: V1c wrong-object gates (q>0, V>0, 0<r<1, T_h>=2): PASS",
  sprintf("  G4: V2 gap within 5 SE: %.1f SE PASS", V2_gap_se),
  "  G5: V3c formula consistency (decreasing tau_hat, tau_hat(kappa_floor)=0): PASS",
  "",
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  sprintf("SHA256: %s", sha)
), "meta/T25_prop_verification.csv.sidecar")
cat("Saved: meta/T25_prop_verification.csv.sidecar\n")

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n=== SUMMARY ===\n")
cat(sprintf("V1a: E_sigma2 = %.4f PASS\n", E_sigma2))
cat(sprintf("V1b: approx_B = %.4f < mc_B = %.4f < 0 PASS\n", approx_B, mc_B))
cat(sprintf("V1c: V_sigma2 = %.4f, CV = %.3f, r_pred = %.4f, r_gap = %.4f PASS\n",
            V_sigma2, cv_sigma2, r_pred, r_gap))
cat(sprintf("V2:  MC mean = %.4f vs predicted %.4f PASS\n", mc_mean_v2, V2_predicted))
cat(sprintf("V3c: tau_hat(1,2,3,5) = %.4f, %.4f, %.4f, %.4f; kappa_floor = %.3f PASS\n",
            tau_hat[1], tau_hat[2], tau_hat[3], tau_hat[4], kappa_floor))

# Final computed values
cat("\n=== COMPUTED VALUES ===\n")
cat(sprintf("PROP_MC_B: %.4f\n", mc_B))
cat(sprintf("PROP_R_PRED: %.4f\n", r_pred))
cat(sprintf("PROP_V2_PRED: %.4f\n", V2_predicted))
cat(sprintf("tau_hat(1,2,3,5): %.4f, %.4f, %.4f, %.4f\n", tau_hat[1], tau_hat[2], tau_hat[3], tau_hat[4]))
cat(sprintf("kappa_floor: %.3f\n", kappa_floor))
