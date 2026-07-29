#!/usr/bin/env Rscript
# S26_prop_verification.R v3 - V1c chain on Arm 1' decomposition
# OUTPUTS: output/T25_prop_verification.csv, article/prop_constants.tex,
#          meta/T25_prop_verification.csv.sidecar
# INPUTS:  output/T22_reliability.csv, output/T24_placebo_uncorr.csv, output/T21_arms.csv,
#          output/T28b_v1c_arm1p.csv
# SEED:    20260719
# NSIM:    4000000 (4e6 for V1b precision)
#
# V1c now fully sourced from Arm 1' (T28b):
#   - PROP_R_PRED, PROP_R_GAP from r1p, R_GAP_1p
#   - PROP_V_SIGMA2 = 4 * A1p, PROP_CV_SIGMA2 = sqrt(V)/E
# Plug-in values retained as diagnostics.

# Login node guard
stopifnot(!grepl("login", Sys.info()[["nodename"]]))

suppressPackageStartupMessages(library(data.table))
set.seed(20260719)

SCRATCH_DIR <- "/scratch/bt307958/S26_VSIG"
setwd(SCRATCH_DIR)

N_REP <- 4e6L
T_POST <- 10L

cat("=============================================================================\n")
cat("S26_prop_verification.R v3 - V1c chain on Arm 1' decomposition\n")
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
stopifnot(sha_T28b == expected_sha_T28b)
cat("T28b SHA256 verified: PASS\n\n")

# -----------------------------------------------------------------------------
# Load frozen values
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

PLACEBO_B_UNCORR_MEAN <- T24[ID == "PLACEBO_B_UNCORR_OVERALL", mean_theta_B]

VAR_NULL_A <- T21[arm == "A_noise_only", Var_null_subtracted]
SD_TRUE_A <- T21[arm == "A_noise_only", SD_true]
VAR_THETA_D <- VAR_NULL_A + SD_TRUE_A^2

# Arm 1' values from T28b
r1p <- T28b[quantity == "r1p", value]
R_GAP_1p <- T28b[quantity == "R_GAP_1p", value]
A1p <- T28b[quantity == "A1p", value]
mean_inv_Th <- T28b[quantity == "mean_inv_Th", value]

cat(sprintf("PLACEBO_A_MEAN        = %.15f\n", PLACEBO_A_MEAN))
cat(sprintf("PLACEBO_A_SD          = %.15f\n", PLACEBO_A_SD))
cat(sprintf("PLACEBO_A_R           = %.15f\n", PLACEBO_A_R))
cat(sprintf("PLACEBO_TH            = %.15f\n", PLACEBO_TH))
cat(sprintf("PLACEBO_TPOST         = %.15f\n", PLACEBO_TPOST))
cat(sprintf("r1p (T28b)            = %.15f\n", r1p))
cat(sprintf("R_GAP_1p (T28b)       = %.15f\n", R_GAP_1p))
cat(sprintf("A1p (T28b)            = %.15f\n", A1p))
cat(sprintf("mean_inv_Th (T28b)    = %.15f\n", mean_inv_Th))

# -----------------------------------------------------------------------------
# V1a: E[sigma^2]
# -----------------------------------------------------------------------------
cat("\n=== V1a: E[SIGMA^2] DERIVATION ===\n")

E_sigma2 <- -2 * PLACEBO_A_MEAN
sigma <- sqrt(E_sigma2)

cat(sprintf("E_sigma2 = -2 * PLACEBO_A_MEAN = %.15f\n", E_sigma2))
cat(sprintf("sigma = sqrt(E_sigma2) = %.15f\n", sigma))

stopifnot(E_sigma2 > 0)
cat("G1 E_sigma2 > 0: PASS\n")

# -----------------------------------------------------------------------------
# V1b: Monte Carlo
# -----------------------------------------------------------------------------
cat("\n=== V1b: MONTE CARLO E[THETA^B] AT T=10 ===\n")

Var_eta <- exp(E_sigma2) - 1
Var_R <- Var_eta / T_POST
approx_B <- -Var_R / 2

cat(sprintf("Var(eta) = %.15f\n", Var_eta))
cat(sprintf("Var(R) at T=%d = %.15f\n", T_POST, Var_R))
cat(sprintf("approx_B = %.15f\n", approx_B))

cat(sprintf("Running %d replications...\n", N_REP))

lg <- matrix(rnorm(N_REP * T_POST, mean = -E_sigma2/2, sd = sigma), ncol = T_POST)
mc_B <- mean(log(rowMeans(exp(lg))))
mc_B_se <- sd(log(rowMeans(exp(lg)))) / sqrt(N_REP)

cat(sprintf("MC E[theta^B] = %.15f (SE = %.6f)\n", mc_B, mc_B_se))

stopifnot(approx_B < mc_B)
stopifnot(mc_B < 0)
cat("G2 V1b approx < mc < 0: PASS\n")

overstate_pct <- 100 * (abs(approx_B) - abs(mc_B)) / abs(mc_B)
cat(sprintf("Overstatement = %.1f%%\n", overstate_pct))

rm(lg)
gc()

# -----------------------------------------------------------------------------
# V1c: Reliability - Arm 1' decomposition
# -----------------------------------------------------------------------------
cat("\n=== V1c: RELIABILITY (ARM 1' DECOMPOSITION) ===\n")

Var_theta_A <- PLACEBO_A_SD^2

# Plug-in decomposition (retained as diagnostic)
q_plugin <- Var_theta_A - E_sigma2 / PLACEBO_TPOST
V_sigma2_plugin <- 4 * q_plugin
cv_sigma2_plugin <- sqrt(V_sigma2_plugin) / E_sigma2
r_pred_plugin <- q_plugin / (q_plugin + E_sigma2 / PLACEBO_TH)

cat(sprintf("PLUG-IN (Arm 0):\n"))
cat(sprintf("  q_plugin = %.15f\n", q_plugin))
cat(sprintf("  V_sigma2_plugin = 4 * q = %.15f\n", V_sigma2_plugin))
cat(sprintf("  cv_sigma2_plugin = %.15f\n", cv_sigma2_plugin))
cat(sprintf("  r_pred_plugin = %.15f\n", r_pred_plugin))

# Arm 1' decomposition (sourced from T28b)
V_sigma2 <- 4 * A1p
cv_sigma2 <- sqrt(V_sigma2) / E_sigma2
r_pred <- r1p
r_gap <- abs(R_GAP_1p)

cat(sprintf("\nARM 1' (from T28b):\n"))
cat(sprintf("  A1p = %.15f\n", A1p))
cat(sprintf("  V_sigma2 = 4 * A1p = %.15f\n", V_sigma2))
cat(sprintf("  cv_sigma2 = sqrt(V)/E = %.15f\n", cv_sigma2))
cat(sprintf("  r_pred = r1p = %.15f\n", r_pred))
cat(sprintf("  r_gap = |R_GAP_1p| = %.15f\n", r_gap))

# Wrong-object gates
stopifnot(A1p > 0)
stopifnot(V_sigma2 > 0)
stopifnot(r_pred > 0, r_pred < 1)
stopifnot(PLACEBO_TH >= 2)

cat("\nV1c wrong-object gates: PASS\n")

# -----------------------------------------------------------------------------
# V2: Window geometry
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
    u <- rnorm(T_total, mean = 0, sd = sigma_ij)
    log_gap <- -e_sigma2/2 + delta_fixed * (t_idx - midpoint) + u
    post_idx <- (t_pre + 1):T_total
    theta_A[i] <- mean(log_gap[post_idx])
  }
  theta_A
}

cat(sprintf("Running %d V2 simulations...\n", N_SIM_V2))
theta_A_v2 <- simulate_prop2a(N_SIM_V2, T_PRE, T_POST_V2, E_sigma2, DELTA_V2)

V2_predicted <- -E_sigma2/2 + DELTA_V2 * T_PRE/2
mc_mean_v2 <- mean(theta_A_v2)
V2_gap <- abs(mc_mean_v2 - V2_predicted)

cat(sprintf("Predicted = %.15f, MC = %.15f, gap = %.6f\n", V2_predicted, mc_mean_v2, V2_gap))
stopifnot(V2_gap < 0.02)
cat("G4 V2 gap < 0.02: PASS\n")

theta_A_v2_shift <- simulate_prop2a(N_SIM_V2, T_PRE, T_POST_V2, E_sigma2, DELTA_V2, offset = 5)
V2_shift <- mean(theta_A_v2_shift) - mc_mean_v2
cat(sprintf("V2 shift = %.15f\n", V2_shift))
stopifnot(abs(V2_shift) < 0.01)
cat("G6 V2 shift < 0.01: PASS\n")

# -----------------------------------------------------------------------------
# V3c: cor:rhoop
# -----------------------------------------------------------------------------
cat("\n=== V3c: COR:RHOOP ===\n")

kappas <- c(1, 2, 3, 5)
tau2_hat <- pmax(0, VAR_THETA_D - kappas * VAR_NULL_A)
tau_hat <- sqrt(tau2_hat)
kappa_floor <- VAR_THETA_D / VAR_NULL_A

cat(sprintf("kappa_floor = %.15f\n", kappa_floor))
for (i in seq_along(kappas)) {
  cat(sprintf("  kappa=%d: tau_hat = %.4f\n", kappas[i], tau_hat[i]))
}

stopifnot(abs(tau_hat[1] - SD_TRUE_A) < 1e-3)
stopifnot(all(diff(tau_hat) < 0))
stopifnot(kappa_floor > 5, kappa_floor < 20)
cat("G5 V3c: PASS\n")

# -----------------------------------------------------------------------------
# OUTPUT TABLE
# -----------------------------------------------------------------------------
cat("\n=== OUTPUT TABLE ===\n")

out <- data.frame(
  ID = c("PROP_ESIGMA2", "PROP_SIGMA", "PROP_VAR_ETA", "PROP_VAR_R",
         "PROP_APPROX_B", "PROP_MC_B", "PROP_OVERSTATE_PCT",
         "PROP_V_SIGMA2", "PROP_CV_SIGMA2",
         "PROP_R_PRED", "PROP_R_GAP",
         "PROP_R_PRED_PLUGIN", "PROP_V_SIGMA2_PLUGIN", "PROP_CV_SIGMA2_PLUGIN",
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
               "Var(sigma^2) from Arm 1' decomposition",
               "CV(sigma^2) = sqrt(Var)/E (Arm 1')",
               "Predicted reliability (Arm 1')",
               "r_gap = |r_pred - r_obs| (Arm 1')",
               "Predicted reliability (plug-in, Arm 0)",
               "Var(sigma^2) from plug-in decomposition",
               "CV(sigma^2) = sqrt(Var)/E (plug-in)",
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
            V_sigma2, cv_sigma2,
            r_pred, r_gap,
            r_pred_plugin, V_sigma2_plugin, cv_sigma2_plugin,
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
# OUTPUT: prop_constants.tex
# -----------------------------------------------------------------------------
cat("\n=== GENERATING prop_constants.tex ===\n")

tex_lines <- c(
  "% prop_constants.tex - Auto-generated by S26_prop_verification.R",
  sprintf("%% Generated: %s", Sys.time()),
  sprintf("%% Seed: 20260719, N_REP: %d", N_REP),
  "%% V1c fully on Arm 1' decomposition (T28b_v1c_arm1p.csv)",
  "",
  "% V1a: E[sigma^2] derivation",
  sprintf("\\newcommand{\\PropEsigsq}{%.4f}", E_sigma2),
  sprintf("\\newcommand{\\PropSigma}{%.4f}", sigma),
  "",
  "% V1b: Jensen bias verification",
  sprintf("\\newcommand{\\PropVarEta}{%.4f}", Var_eta),
  sprintf("\\newcommand{\\PropVarR}{%.4f}", Var_R),
  sprintf("\\newcommand{\\PropApproxB}{%.4f}", approx_B),
  sprintf("\\newcommand{\\PropMCB}{%.3f}", round(mc_B, 3)),
  sprintf("\\newcommand{\\PropOverstatePct}{%.0f}", round(overstate_pct)),
  "",
  "% V1c: Reliability (Arm 1' decomposition)",
  sprintf("\\newcommand{\\PropVsigmasq}{%.4f}", V_sigma2),
  sprintf("\\newcommand{\\PropCVsigsq}{%.3f}", cv_sigma2),
  sprintf("\\newcommand{\\PropRpred}{%.4f}", r_pred),
  sprintf("\\newcommand{\\PropRgap}{%.4f}", r_gap),
  sprintf("\\newcommand{\\PropTh}{%.2f}", PLACEBO_TH),
  sprintf("\\newcommand{\\PropTpost}{%.2f}", PLACEBO_TPOST),
  sprintf("\\newcommand{\\PropPlaceboR}{%.4f}", PLACEBO_A_R),
  "",
  "% V1c plug-in diagnostics (Arm 0, retained)",
  sprintf("\\newcommand{\\PropVsigmasqPlugin}{%.4f}", V_sigma2_plugin),
  sprintf("\\newcommand{\\PropCVsigsqPlugin}{%.3f}", cv_sigma2_plugin),
  "",
  "% Placebo means - Definition A vs Definition B",
  sprintf("\\newcommand{\\PropPlaceboAMean}{%.4f}", PLACEBO_A_MEAN),
  sprintf("\\newcommand{\\PropPlaceboBUncorr}{%.4f}", PLACEBO_B_UNCORR_MEAN),
  "",
  "% V2: Window geometry (Prop 2a, delta=0.02)",
  sprintf("\\newcommand{\\PropVtwoPred}{%.4f}", V2_predicted),
  sprintf("\\newcommand{\\PropVtwoSim}{%.4f}", mc_mean_v2),
  sprintf("\\newcommand{\\PropVtwoShift}{%.4f}", V2_shift),
  "",
  "% V3c: cor:rhoop identification boundary",
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
  "PRODUCER: S26_prop_verification.R v3",
  "INPUTS: T22_reliability.csv, T24_placebo_uncorr.csv, T21_arms.csv, T28b_v1c_arm1p.csv",
  "SEED: 20260719",
  sprintf("N_REP: %d", N_REP),
  "",
  "V1c CHAIN ON ARM 1' DECOMPOSITION:",
  sprintf("  A1p (from T28b) = %.15f", A1p),
  sprintf("  V_sigma2 = 4 * A1p = %.15f", V_sigma2),
  sprintf("  CV_sigma2 = sqrt(V)/E = %.15f", cv_sigma2),
  sprintf("  r_pred (Arm 1') = %.15f", r_pred),
  sprintf("  r_gap = %.15f", r_gap),
  "",
  "PLUG-IN DIAGNOSTICS (Arm 0, retained):",
  sprintf("  V_sigma2_plugin = %.15f", V_sigma2_plugin),
  sprintf("  CV_sigma2_plugin = %.15f", cv_sigma2_plugin),
  sprintf("  r_pred_plugin = %.15f", r_pred_plugin),
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

# G1: V_sigma2 matches expected
g1_diff <- abs(V_sigma2 - 4.021025258951288)
cat(sprintf("G1: |PROP_V_SIGMA2 - 4.021025258951288| = %.15e\n", g1_diff))
stopifnot(g1_diff < 1e-9)
cat("G1 PASS\n")

# G2: cv_sigma2 matches expected
g2_diff <- abs(cv_sigma2 - 1.469896453257487)
cat(sprintf("G2: |PROP_CV_SIGMA2 - 1.469896453257487| = %.15e\n", g2_diff))
stopifnot(g2_diff < 1e-9)
cat("G2 PASS\n")

# G3: Chain coherence
A_pub <- V_sigma2 / 4
r_rec <- A_pub / (A_pub + E_sigma2 * mean_inv_Th)
g3_diff <- abs(r_rec - r_pred)
cat(sprintf("G3: Chain coherence\n"))
cat(sprintf("    A_pub = V_sigma2/4 = %.15f\n", A_pub))
cat(sprintf("    r_rec = A_pub/(A_pub + E*m_inv_Th) = %.15f\n", r_rec))
cat(sprintf("    r_pred = %.15f\n", r_pred))
cat(sprintf("    |r_rec - r_pred| = %.15e\n", g3_diff))
stopifnot(g3_diff < 1e-9)
cat("G3 PASS\n")

# G4: R_PRED and R_GAP unchanged
expected_r_pred <- 0.753863355754621
expected_r_gap <- 0.00755493903584137
g4a_diff <- abs(r_pred - expected_r_pred)
g4b_diff <- abs(r_gap - expected_r_gap)
cat(sprintf("G4: |r_pred - committed| = %.15e, |r_gap - committed| = %.15e\n", g4a_diff, g4b_diff))
stopifnot(g4a_diff < 1e-12)
stopifnot(g4b_diff < 1e-12)
cat("G4 PASS\n")

# G5: V1a/V1b/V2/V3c rows unchanged
committed <- list(
  PROP_ESIGMA2 = 1.36421135051832,
  PROP_SIGMA = 1.16799458496961,
  PROP_VAR_ETA = 2.91263613644454,
  PROP_VAR_R = 0.291263613644454,
  PROP_APPROX_B = -0.145631806822227,
  PROP_TH = 5.45552509086272,
  PROP_TPOST = 10.9110501817254,
  PROP_PLACEBO_R = 0.74630841671878,
  PROP_PLACEBO_A_MEAN = -0.68210567525916,
  PROP_PLACEBO_B_UNCORR = -0.207204589838223,
  PROP_V2_PRED = -0.58210567525916,
  PROP_TAU_K1 = 1.4754,
  PROP_TAU_K2 = 1.38407375526017,
  PROP_TAU_K3 = 1.2862795808066,
  PROP_TAU_K5 = 1.06406069375764,
  PROP_KAPPA_FLOOR = 9.3356187558636
)

g5_pass <- TRUE
cat("G5: Checking V1a/V1b/V2/V3c rows...\n")
for (id in names(committed)) {
  expected <- committed[[id]]
  actual <- out$value[out$ID == id]
  diff <- abs(actual - expected)
  if (diff > 1e-10) {
    cat(sprintf("  MISMATCH: %s expected %.15f, got %.15f\n", id, expected, actual))
    g5_pass <- FALSE
  }
}
if (g5_pass) {
  cat("G5 PASS\n")
} else {
  stop("G5 FAIL")
}

# G6: All main.tex macros resolve
cat("G6: Checking prop_constants.tex macros...\n")
tex_content <- readLines("prop_constants.tex")
required_macros <- c("PropEsigsq", "PropSigma", "PropVarEta", "PropVarR",
                     "PropApproxB", "PropMCB", "PropOverstatePct",
                     "PropVsigmasq", "PropCVsigsq", "PropRpred", "PropRgap",
                     "PropTh", "PropTpost", "PropPlaceboR",
                     "PropPlaceboAMean", "PropPlaceboBUncorr",
                     "PropVtwoPred", "PropVtwoSim", "PropVtwoShift",
                     "PropTauKone", "PropTauKtwo", "PropTauKthree", "PropTauKfive",
                     "PropKappaFloor")

g6_pass <- TRUE
for (macro in required_macros) {
  pattern <- sprintf("\\\\newcommand\\{\\\\%s\\}", macro)
  if (!any(grepl(pattern, tex_content))) {
    cat(sprintf("  MISSING: \\%s\n", macro))
    g6_pass <- FALSE
  }
}
if (g6_pass) {
  cat("G6 PASS\n")
} else {
  stop("G6 FAIL")
}

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n=============================================================================\n")
cat("SUMMARY: ALL GATES PASSED\n")
cat("=============================================================================\n")
cat(sprintf("G1: PROP_V_SIGMA2 = %.15f: PASS\n", V_sigma2))
cat(sprintf("G2: PROP_CV_SIGMA2 = %.15f: PASS\n", cv_sigma2))
cat(sprintf("G3: Chain coherence r_rec = r_pred: PASS\n"))
cat(sprintf("G4: PROP_R_PRED, PROP_R_GAP unchanged: PASS\n"))
cat(sprintf("G5: V1a/V1b/V2/V3c rows unchanged: PASS\n"))
cat(sprintf("G6: All main.tex macros resolve: PASS\n"))
cat("=============================================================================\n")
cat(sprintf("Done: %s\n", format(Sys.time())))
