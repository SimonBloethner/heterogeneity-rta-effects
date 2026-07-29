#!/usr/bin/env Rscript
# S26_prop_verification.R - Proposition verification with Monte Carlo
# OUTPUTS: output/T25_prop_verification.csv, article/prop_constants.tex,
#          meta/T25_prop_verification.csv.sidecar
# INPUTS:  output/T22_reliability.csv, output/T24_placebo_uncorr.csv, output/T21_arms.csv,
#          output/T28b_v1c_arm1p.csv
# SEED:    20260719
# NSIM:    4000000 (4e6 for V1b precision)
# EXPECTED_N: NA (loads summary tables T21/T22/T24, not population)
#
# Verifications:
# V1a: E[sigma^2] = -2 * PLACEBO_A_MEAN (analytical)
# V1b: E[theta^B | zero effect] via Monte Carlo at T=10
#      Gate: approx_B < mc_B < 0 (expansion overstates bias magnitude)
# V1c: Reliability consistency (predicted vs observed) - parameter-free check
#      Uses Arm 1' from T28b (Jensen-corrected on both windows)
#      Gate: T_h >= 2 (meaningful split-half requirement)
# V2:  Window geometry - Proposition 2(a) with delta=0.02
# V3c: cor:rhoop - Corollary verification using arm A subtraction (ledger-sourced)

# Login node guard
stopifnot(!grepl("login", Sys.info()[["nodename"]]))

suppressPackageStartupMessages(library(data.table))
set.seed(20260719)

SCRATCH_DIR <- "/scratch/bt307958/S26_ARM1P"
setwd(SCRATCH_DIR)

N_REP <- 4e6L   # 4 million replications for V1b
T_POST <- 10L   # Example horizon

cat("=============================================================================\n")
cat("S26_prop_verification.R v2 - Sourcing V1c from Arm 1'\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat(sprintf("Node: %s\n", Sys.info()[["nodename"]]))
cat("=============================================================================\n\n")

# SHA256 verification function
get_sha256 <- function(p) {
  strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
}

# =============================================================================
# VERIFY T28b SHA256
# =============================================================================
cat("=== VERIFYING T28b SHA256 ===\n")
sha_T28b <- get_sha256(file.path(SCRATCH_DIR, "T28b_v1c_arm1p.csv"))
expected_sha_T28b <- "7bd76254d80324c2c8189c906383ef9b462d000394c3bb19253aad0fd89dcc4c"
cat(sprintf("T28b_v1c_arm1p.csv: %s\n", sha_T28b))
cat(sprintf("Expected:           %s\n", expected_sha_T28b))
cat(sprintf("Match: %s\n", ifelse(sha_T28b == expected_sha_T28b, "YES", "HALT")))
stopifnot(sha_T28b == expected_sha_T28b)
cat("T28b SHA256 verified: PASS\n\n")

# -----------------------------------------------------------------------------
# Load frozen values from T22, T24, T21, and T28b
# -----------------------------------------------------------------------------
cat("=== LOADING FROZEN VALUES ===\n")

T22 <- fread("T22_reliability.csv")
T24 <- fread("T24_placebo_uncorr.csv")
T21 <- fread("T21_arms.csv")
T28b <- fread("T28b_v1c_arm1p.csv")

PLACEBO_A_MEAN <- T22[ID == "PLACEBO_A_MEAN", value]
PLACEBO_A_SD <- T22[ID == "PLACEBO_A_SD", value]
PLACEBO_A_R <- T22[ID == "PLACEBO_A_R", value]
PLACEBO_TH <- T22[ID == "PLACEBO_TH", value]
PLACEBO_TPOST <- T22[ID == "PLACEBO_TPOST", value]

# Definition B placebo mean (uncorrected) - distinct from PLACEBO_A_MEAN
PLACEBO_B_UNCORR_MEAN <- T24[ID == "PLACEBO_B_UNCORR_OVERALL", mean_theta_B]

# Arm A values from T21 for V3c
VAR_NULL_A <- T21[arm == "A_noise_only", Var_null_subtracted]
SD_TRUE_A <- T21[arm == "A_noise_only", SD_true]
VAR_THETA_D <- VAR_NULL_A + SD_TRUE_A^2

# Arm 1' values from T28b for V1c
r1p <- T28b[quantity == "r1p", value]
R_GAP_1p <- T28b[quantity == "R_GAP_1p", value]

cat(sprintf("PLACEBO_A_MEAN        = %.15f\n", PLACEBO_A_MEAN))
cat(sprintf("PLACEBO_A_SD          = %.15f\n", PLACEBO_A_SD))
cat(sprintf("PLACEBO_A_R           = %.15f\n", PLACEBO_A_R))
cat(sprintf("PLACEBO_TH            = %.15f\n", PLACEBO_TH))
cat(sprintf("PLACEBO_TPOST         = %.15f\n", PLACEBO_TPOST))
cat(sprintf("PLACEBO_B_UNCORR_MEAN = %.15f\n", PLACEBO_B_UNCORR_MEAN))
cat(sprintf("VAR_THETA_D (T21)     = %.15f\n", VAR_THETA_D))
cat(sprintf("VAR_NULL_A (T21)      = %.15f\n", VAR_NULL_A))
cat(sprintf("SD_TRUE_A (T21)       = %.15f\n", SD_TRUE_A))
cat(sprintf("r1p (T28b Arm 1')     = %.15f\n", r1p))
cat(sprintf("R_GAP_1p (T28b)       = %.15f\n", R_GAP_1p))

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

# Compute overstatement percentage (D5.1)
overstate_pct <- 100 * (abs(approx_B) - abs(mc_B)) / abs(mc_B)
cat(sprintf("Overstatement = (|%.4f| - |%.4f|) / |%.4f| = %.1f%%\n",
            approx_B, mc_B, mc_B, overstate_pct))

# Clean up large matrix
rm(lg)
gc()

# -----------------------------------------------------------------------------
# V1c: Reliability consistency check
# Now sourced from Arm 1' (T28b) instead of plug-in decomposition
# Still compute plug-in for PROP_R_PRED_PLUGIN diagnostic
# -----------------------------------------------------------------------------
cat("\n=== V1c: RELIABILITY (SOURCED FROM ARM 1') ===\n")

Var_theta_A <- PLACEBO_A_SD^2

# Plug-in decomposition (retained as diagnostic)
q <- Var_theta_A - E_sigma2 / PLACEBO_TPOST
V_sigma2 <- 4 * q
r_pred_plugin <- q / (q + E_sigma2 / PLACEBO_TH)
cv_sigma2 <- sqrt(V_sigma2) / E_sigma2

cat(sprintf("Var(theta^A) = %.6f\n", Var_theta_A))
cat(sprintf("q = Var(theta^A) - E[sigma^2]/T_post = %.6f\n", q))
cat(sprintf("Var(sigma^2) = 4 * q = %.6f\n", V_sigma2))
cat(sprintf("r_pred_plugin (Arm 0) = %.15f\n", r_pred_plugin))
cat(sprintf("CV(sigma^2) = sqrt(Var)/E = %.4f\n", cv_sigma2))

# Arm 1' values (sourced from T28b)
r_pred <- r1p
r_gap <- abs(R_GAP_1p)

cat(sprintf("\nr_pred (Arm 1') = %.15f\n", r_pred))
cat(sprintf("r_gap = |R_GAP_1p| = %.15f\n", r_gap))
cat(sprintf("r_obs (PLACEBO_A_R) = %.15f\n", PLACEBO_A_R))

# Gates catch wrong objects, not adjudicate agreement
stopifnot(q > 0)
stopifnot(V_sigma2 > 0)
stopifnot(r_pred > 0, r_pred < 1)
stopifnot(PLACEBO_TH >= 2)

cat("\nG3 V1c wrong-object gates: PASS\n")
cat(sprintf("  q > 0: %.4f > 0 PASS\n", q))
cat(sprintf("  V_sigma2 > 0: %.4f > 0 PASS\n", V_sigma2))
cat(sprintf("  0 < r_pred < 1: 0 < %.4f < 1 PASS\n", r_pred))
cat(sprintf("  T_h >= 2: %.2f >= 2 PASS\n", PLACEBO_TH))

# -----------------------------------------------------------------------------
# V2: Window geometry - Proposition 2(a) with non-zero drift
# -----------------------------------------------------------------------------
cat("\n=== V2: WINDOW GEOMETRY (PROP 2a) ===\n")

N_SIM_V2 <- 100000L
T_PRE <- 10L
T_POST_V2 <- 10L
DELTA_V2 <- 0.02

simulate_prop2a <- function(nsim, t_pre, t_post, e_sigma2, delta_fixed, offset = 0) {
  T_total <- t_pre + t_post
  t_idx <- 1:T_total + offset
  midpoint <- (T_total + 1) / 2 + offset
  sigma_ij <- sqrt(e_sigma2)

  theta_A <- numeric(nsim)

  for (i in 1:nsim) {
    delta_ij <- delta_fixed
    u <- rnorm(T_total, mean = 0, sd = sigma_ij)
    log_gap <- -e_sigma2/2 + delta_ij * (t_idx - midpoint) + u
    post_idx <- (t_pre + 1):T_total
    theta_A[i] <- mean(log_gap[post_idx])
  }

  theta_A
}

cat(sprintf("Running %d V2 simulations (T_pre=%d, T_post=%d, delta=%.2f)...\n",
            N_SIM_V2, T_PRE, T_POST_V2, DELTA_V2))

theta_A_v2 <- simulate_prop2a(N_SIM_V2, T_PRE, T_POST_V2, E_sigma2, DELTA_V2)

V2_predicted <- -E_sigma2/2 + DELTA_V2 * T_PRE/2
mc_mean_v2 <- mean(theta_A_v2)
mc_se_v2 <- sd(theta_A_v2) / sqrt(N_SIM_V2)

cat(sprintf("Predicted mean = -E_sigma2/2 + delta*T_pre/2 = %.6f\n", V2_predicted))
cat(sprintf("MC mean = %.6f (SE = %.6f)\n", mc_mean_v2, mc_se_v2))

V2_gap <- abs(mc_mean_v2 - V2_predicted)
stopifnot(V2_gap < 0.02)
cat(sprintf("G4 V2 gap < 0.02: %.4f < 0.02 PASS\n", V2_gap))

cat("\nRunning V2 shift simulation (offset=+5 years)...\n")
theta_A_v2_shift <- simulate_prop2a(N_SIM_V2, T_PRE, T_POST_V2, E_sigma2, DELTA_V2, offset = 5)
V2_shift <- mean(theta_A_v2_shift) - mc_mean_v2
cat(sprintf("V2 shift (offset +5): %.6f\n", V2_shift))

stopifnot(abs(V2_shift) < 0.01)
cat(sprintf("G6 V2 shift < 0.01: %.4f PASS\n", abs(V2_shift)))

# -----------------------------------------------------------------------------
# V3c: Corollary cor:rhoop
# -----------------------------------------------------------------------------
cat("\n=== V3c: COR:RHOOP IDENTIFICATION BOUNDARY ===\n")

cat(sprintf("VAR_THETA_D = %.15f\n", VAR_THETA_D))
cat(sprintf("VAR_NULL_A  = %.6f\n", VAR_NULL_A))
cat(sprintf("SD_TRUE_A   = %.4f\n", SD_TRUE_A))

kappas <- c(1, 2, 3, 5)
tau2_hat <- pmax(0, VAR_THETA_D - kappas * VAR_NULL_A)
tau_hat <- sqrt(tau2_hat)
kappa_floor <- VAR_THETA_D / VAR_NULL_A

cat(sprintf("\nkappa_floor = %.3f\n", kappa_floor))
cat("\nKappa sweep:\n")
for (i in seq_along(kappas)) {
  cat(sprintf("  kappa=%d: tau_hat = %.4f\n", kappas[i], tau_hat[i]))
}

stopifnot(abs(tau_hat[1] - SD_TRUE_A) < 1e-3)
stopifnot(all(diff(tau_hat) < 0))
stopifnot(kappa_floor > 5, kappa_floor < 20)
stopifnot(all(tau_hat <= SD_TRUE_A + 1e-9))

cat("\nG5 V3c cor:rhoop: PASS\n")

# -----------------------------------------------------------------------------
# OUTPUT TABLE
# -----------------------------------------------------------------------------
cat("\n=== OUTPUT TABLE ===\n")

out <- data.frame(
  ID = c("PROP_ESIGMA2", "PROP_SIGMA", "PROP_VAR_ETA", "PROP_VAR_R",
         "PROP_APPROX_B", "PROP_MC_B", "PROP_OVERSTATE_PCT",
         "PROP_V_SIGMA2", "PROP_CV_SIGMA2", "PROP_R_PRED", "PROP_R_GAP",
         "PROP_R_PRED_PLUGIN",
         "PROP_TH", "PROP_TPOST", "PROP_PLACEBO_R",
         "PROP_PLACEBO_A_MEAN", "PROP_PLACEBO_B_UNCORR",
         "PROP_V2_PRED", "PROP_V2_SIM", "PROP_V2_SHIFT",
         "PROP_TAU_K1", "PROP_TAU_K2", "PROP_TAU_K3", "PROP_TAU_K5",
         "PROP_KAPPA_FLOOR"),
  quantity = c("E[sigma^2] = -2*PLACEBO_A_MEAN",
               "sigma = sqrt(E[sigma^2])",
               "Var(eta) = exp(sigma^2) - 1",
               "Var(R) at T=10 = Var(eta)/10",
               "-Var(R)/2 (second-order approx)",
               "MC E[theta^B] at T=10",
               "Overstatement percentage",
               "Var(sigma^2) from decomposition",
               "CV(sigma^2) = sqrt(Var)/E",
               "Predicted reliability (Arm 1')",
               "r_gap = |r_pred - r_obs| (Arm 1')",
               "Predicted reliability (plug-in, Arm 0)",
               "Mean half-length T_h (placebo)",
               "Mean post-window T_post (placebo)",
               "Observed reliability (PLACEBO_A_R)",
               "Mean theta_A placebo (T22)",
               "Mean theta_B uncorrected (T24)",
               "V2 predicted mean (Prop 2a, delta=0.02)",
               "V2 simulated mean",
               "V2 shift under +5yr offset",
               "tau_hat at kappa=1 (=SD_TRUE_A)",
               "tau_hat at kappa=2",
               "tau_hat at kappa=3",
               "tau_hat at kappa=5",
               "kappa_floor (where tau_hat=0)"),
  value = c(E_sigma2, sigma, Var_eta, Var_R,
            approx_B, mc_B, overstate_pct,
            V_sigma2, cv_sigma2, r_pred, r_gap,
            r_pred_plugin,
            PLACEBO_TH, PLACEBO_TPOST, PLACEBO_A_R,
            PLACEBO_A_MEAN, PLACEBO_B_UNCORR_MEAN,
            V2_predicted, mc_mean_v2, V2_shift,
            tau_hat[1], tau_hat[2], tau_hat[3], tau_hat[4],
            kappa_floor),
  stringsAsFactors = FALSE
)

print(out)

write.csv(out, "T25_prop_verification.csv", row.names = FALSE)
cat("\nSaved: T25_prop_verification.csv\n")

# -----------------------------------------------------------------------------
# OUTPUT: article/prop_constants.tex
# -----------------------------------------------------------------------------
cat("\n=== GENERATING prop_constants.tex ===\n")

tex_lines <- c(
  "% prop_constants.tex - Auto-generated by S26_prop_verification.R",
  sprintf("%% Generated: %s", Sys.time()),
  sprintf("%% Seed: 20260719, N_REP: %d", N_REP),
  "%% V1c sourced from Arm 1' (T28b_v1c_arm1p.csv)",
  "",
  "% V1a: E[sigma^2] derivation",
  sprintf("\\newcommand{\\PropEsigsq}{%.4f}", E_sigma2),
  sprintf("\\newcommand{\\PropSigma}{%.4f}", sigma),
  "",
  "% V1b: Jensen bias verification (D4.7: round mc_B to 3 decimal places)",
  sprintf("\\newcommand{\\PropVarEta}{%.4f}", Var_eta),
  sprintf("\\newcommand{\\PropVarR}{%.4f}", Var_R),
  sprintf("\\newcommand{\\PropApproxB}{%.4f}", approx_B),
  sprintf("\\newcommand{\\PropMCB}{%.3f}", round(mc_B, 3)),
  sprintf("\\newcommand{\\PropOverstatePct}{%.0f}", round(overstate_pct)),
  "",
  "% V1c: Reliability (Arm 1' - Jensen on both windows)",
  sprintf("\\newcommand{\\PropVsigmasq}{%.4f}", V_sigma2),
  sprintf("\\newcommand{\\PropCVsigsq}{%.3f}", cv_sigma2),
  sprintf("\\newcommand{\\PropRpred}{%.4f}", r_pred),
  sprintf("\\newcommand{\\PropRgap}{%.4f}", r_gap),
  sprintf("\\newcommand{\\PropTh}{%.2f}", PLACEBO_TH),
  sprintf("\\newcommand{\\PropTpost}{%.2f}", PLACEBO_TPOST),
  sprintf("\\newcommand{\\PropPlaceboR}{%.4f}", PLACEBO_A_R),
  "",
  "% Placebo means - Definition A vs Definition B (C1.1, D5.4)",
  sprintf("\\newcommand{\\PropPlaceboAMean}{%.4f}", PLACEBO_A_MEAN),
  sprintf("\\newcommand{\\PropPlaceboBUncorr}{%.4f}", PLACEBO_B_UNCORR_MEAN),
  "",
  "% V2: Window geometry (Prop 2a, delta=0.02)",
  sprintf("\\newcommand{\\PropVtwoPred}{%.4f}", V2_predicted),
  sprintf("\\newcommand{\\PropVtwoSim}{%.4f}", mc_mean_v2),
  sprintf("\\newcommand{\\PropVtwoShift}{%.4f}", V2_shift),
  "",
  "% V3c: cor:rhoop identification boundary (D1: uses arm A subtraction)",
  "% tau_hat values are SD (not variance) - named accordingly",
  sprintf("\\newcommand{\\PropTauKone}{%.4f}", tau_hat[1]),
  sprintf("\\newcommand{\\PropTauKtwo}{%.4f}", tau_hat[2]),
  sprintf("\\newcommand{\\PropTauKthree}{%.4f}", tau_hat[3]),
  sprintf("\\newcommand{\\PropTauKfive}{%.4f}", tau_hat[4]),
  sprintf("\\newcommand{\\PropKappaFloor}{%.3f}", kappa_floor),
  ""
)

writeLines(tex_lines, "prop_constants.tex")
cat("Saved: prop_constants.tex\n")

# -----------------------------------------------------------------------------
# Sidecar
# -----------------------------------------------------------------------------
sha_out <- get_sha256("T25_prop_verification.csv")
writeLines(c(
  "PRODUCER: S26_prop_verification.R v2",
  "INPUTS: output/T22_reliability.csv, output/T24_placebo_uncorr.csv, output/T21_arms.csv,",
  "        output/T28b_v1c_arm1p.csv",
  "SEED: 20260719",
  sprintf("N_REP: %d", N_REP),
  "",
  "V1c SOURCED FROM ARM 1' (T28b):",
  sprintf("  r_pred (Arm 1') = %.15f", r_pred),
  sprintf("  r_gap = |R_GAP_1p| = %.15f", r_gap),
  sprintf("  r_pred_plugin (Arm 0, retained) = %.15f", r_pred_plugin),
  "",
  "VERIFICATIONS:",
  sprintf("  V1a: E_sigma2 = %.6f (analytical: -2*PLACEBO_A_MEAN)", E_sigma2),
  sprintf("  V1b: approx_B = %.4f < mc_B = %.4f < 0 : PASS", approx_B, mc_B),
  sprintf("  V1c: r_pred (Arm 1') = %.4f, r_gap = %.4f", r_pred, r_gap),
  sprintf("  V2:  MC mean = %.4f vs predicted %.4f, gap = %.4f < 0.02",
          mc_mean_v2, V2_predicted, V2_gap),
  sprintf("  V3c: tau_hat(1,2,3,5) = %.4f, %.4f, %.4f, %.4f",
          tau_hat[1], tau_hat[2], tau_hat[3], tau_hat[4]),
  "",
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  sprintf("SHA256: %s", sha_out)
), "T25_prop_verification.csv.sidecar")
cat("Saved: T25_prop_verification.csv.sidecar\n")

# -----------------------------------------------------------------------------
# TASK-SPECIFIC GATES
# -----------------------------------------------------------------------------
cat("\n=== TASK-SPECIFIC GATES ===\n")

# G1: PROP_R_PRED matches Arm 1' r1p
g1_diff <- abs(r_pred - 0.753863355754621)
cat(sprintf("G1: |PROP_R_PRED - 0.753863355754621| = %.15e, expected < 1e-9\n", g1_diff))
stopifnot(g1_diff < 1e-9)
cat("G1 PASS\n")

# G2: PROP_R_GAP matches |R_GAP_1p|
g2_diff <- abs(r_gap - 0.007554939035841)
cat(sprintf("G2: |PROP_R_GAP - 0.007554939035841| = %.15e, expected < 1e-9\n", g2_diff))
stopifnot(g2_diff < 1e-9)
cat("G2 PASS\n")

# G3: All non-V1c rows identical to committed T25
# Load committed T25 for comparison
cat("\nG3: Checking non-V1c rows against committed T25...\n")
# The committed values (from task prompt, verified by SHA256)
committed_values <- list(
  PROP_ESIGMA2 = 1.36421135051832,
  PROP_SIGMA = 1.16799458496961,
  PROP_VAR_ETA = 2.91263613644454,
  PROP_VAR_R = 0.291263613644454,
  PROP_APPROX_B = -0.145631806822227,
  # PROP_MC_B varies by seed - skip exact check, verify bounds
  # PROP_OVERSTATE_PCT varies by seed - skip exact check
  PROP_V_SIGMA2 = 4.1773373153297,
  PROP_CV_SIGMA2 = 1.49819420919883,
  # PROP_R_PRED changed intentionally
  # PROP_R_GAP changed intentionally
  # PROP_R_PRED_PLUGIN is new
  PROP_TH = 5.45552509086272,
  PROP_TPOST = 10.9110501817254,
  PROP_PLACEBO_R = 0.74630841671878,
  PROP_PLACEBO_A_MEAN = -0.68210567525916,
  PROP_PLACEBO_B_UNCORR = -0.207204589838223,
  PROP_V2_PRED = -0.58210567525916,
  # PROP_V2_SIM varies by seed
  # PROP_V2_SHIFT varies by seed
  PROP_TAU_K1 = 1.4754,
  PROP_TAU_K2 = 1.38407375526017,
  PROP_TAU_K3 = 1.2862795808066,
  PROP_TAU_K5 = 1.06406069375764,
  PROP_KAPPA_FLOOR = 9.3356187558636
)

# Check deterministic rows
g3_pass <- TRUE
for (id in names(committed_values)) {
  expected <- committed_values[[id]]
  actual <- out$value[out$ID == id]
  diff <- abs(actual - expected)
  if (diff > 1e-10) {
    cat(sprintf("  MISMATCH: %s expected %.15f, got %.15f (diff %.2e)\n",
                id, expected, actual, diff))
    g3_pass <- FALSE
  }
}

# Check PROP_R_PRED_PLUGIN equals old PROP_R_PRED
plugin_val <- out$value[out$ID == "PROP_R_PRED_PLUGIN"]
expected_plugin <- 0.806812807675821
plugin_diff <- abs(plugin_val - expected_plugin)
if (plugin_diff > 1e-10) {
  cat(sprintf("  MISMATCH: PROP_R_PRED_PLUGIN expected %.15f, got %.15f\n",
              expected_plugin, plugin_val))
  g3_pass <- FALSE
}

if (g3_pass) {
  cat("G3: All deterministic non-V1c rows match committed T25: PASS\n")
} else {
  cat("G3: FAIL - see mismatches above\n")
  stop("G3 FAIL")
}

# G4: prop_constants.tex parses (check macros exist)
cat("\nG4: Checking prop_constants.tex macros...\n")
tex_content <- readLines("prop_constants.tex")
required_macros <- c("PropEsigsq", "PropSigma", "PropVarEta", "PropVarR",
                     "PropApproxB", "PropMCB", "PropOverstatePct",
                     "PropVsigmasq", "PropCVsigsq", "PropRpred", "PropRgap",
                     "PropTh", "PropTpost", "PropPlaceboR",
                     "PropPlaceboAMean", "PropPlaceboBUncorr",
                     "PropVtwoPred", "PropVtwoSim", "PropVtwoShift",
                     "PropTauKone", "PropTauKtwo", "PropTauKthree", "PropTauKfive",
                     "PropKappaFloor")

g4_pass <- TRUE
for (macro in required_macros) {
  pattern <- sprintf("\\\\newcommand\\{\\\\%s\\}", macro)
  if (!any(grepl(pattern, tex_content))) {
    cat(sprintf("  MISSING: \\%s\n", macro))
    g4_pass <- FALSE
  }
}

if (g4_pass) {
  cat("G4: All required macros present in prop_constants.tex: PASS\n")
} else {
  cat("G4: FAIL - missing macros\n")
  stop("G4 FAIL")
}

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n=============================================================================\n")
cat("SUMMARY: ALL GATES PASSED\n")
cat("=============================================================================\n")
cat(sprintf("G1: |PROP_R_PRED - 0.7539| < 1e-9: PASS\n"))
cat(sprintf("G2: |PROP_R_GAP - 0.0076| < 1e-9: PASS\n"))
cat("G3: Non-V1c rows match committed T25: PASS\n")
cat("G4: prop_constants.tex macros complete: PASS\n")
cat("=============================================================================\n")
cat(sprintf("PROP_R_PRED (Arm 1'):     %.15f\n", r_pred))
cat(sprintf("PROP_R_GAP (Arm 1'):      %.15f\n", r_gap))
cat(sprintf("PROP_R_PRED_PLUGIN (Arm 0): %.15f\n", r_pred_plugin))
cat("=============================================================================\n")
cat(sprintf("Done: %s\n", format(Sys.time())))
