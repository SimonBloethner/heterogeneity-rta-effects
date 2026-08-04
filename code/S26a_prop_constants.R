#!/usr/bin/env Rscript
# S26a_prop_constants.R - V1a/V1b/V2/V3c (no T28b dependency)
# OUTPUTS: output/T25a_prop_constants.csv, meta/T25a_prop_constants.csv.sidecar
# INPUTS:  output/T22_reliability.csv, output/T24_placebo_uncorr.csv, output/T21_arms.csv
# SEED:    20260719
# NSIM:    4000000 (4e6 for V1b precision)
#
# Split from S26: V1a, V1b, V2, V3c computed here without T28b dependency.
# V1c (Arm 1' values) computed separately in S26b after T28b is available.

# Login node guard
stopifnot(!grepl("login", Sys.info()[["nodename"]]))

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(data.table))
set.seed(20260719)

N_REP <- 4e6L
T_POST <- 10L

cat("=============================================================================\n")
cat("S26a_prop_constants.R - V1a/V1b/V2/V3c (no T28b dependency)\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat(sprintf("Node: %s\n", Sys.info()[["nodename"]]))
cat("=============================================================================\n\n")

# SHA256 verification function
get_sha256 <- function(p) {
  strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
}

# -----------------------------------------------------------------------------
# Load frozen values (NO T28b)
# -----------------------------------------------------------------------------
cat("=== LOADING FROZEN VALUES ===\n")

T22 <- fread(file.path(RTA_ROOT, "output/T22_reliability.csv"))
T24 <- fread(file.path(RTA_ROOT, "output/T24_placebo_uncorr.csv"))
T21 <- fread(file.path(RTA_ROOT, "output/T21_arms.csv"))

PLACEBO_A_MEAN <- T22[ID == "PLACEBO_A_MEAN", value]
PLACEBO_A_SD <- T22[ID == "PLACEBO_A_SD", value]
PLACEBO_A_R <- T22[ID == "PLACEBO_A_R", value]
PLACEBO_TH <- T22[ID == "PLACEBO_TH", value]
PLACEBO_TPOST <- T22[ID == "PLACEBO_TPOST", value]

PLACEBO_B_UNCORR_MEAN <- T24[ID == "PLACEBO_B_UNCORR_OVERALL", mean_theta_B]

VAR_NULL_A <- T21[arm == "A_noise_only", Var_null_subtracted]
SD_TRUE_A <- T21[arm == "A_noise_only", SD_true]
VAR_THETA_D <- VAR_NULL_A + SD_TRUE_A^2

cat(sprintf("PLACEBO_A_MEAN        = %.15f\n", PLACEBO_A_MEAN))
cat(sprintf("PLACEBO_A_SD          = %.15f\n", PLACEBO_A_SD))
cat(sprintf("PLACEBO_A_R           = %.15f\n", PLACEBO_A_R))
cat(sprintf("PLACEBO_TH            = %.15f\n", PLACEBO_TH))
cat(sprintf("PLACEBO_TPOST         = %.15f\n", PLACEBO_TPOST))

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
# Plug-in decomposition (Arm 0, for reference)
# -----------------------------------------------------------------------------
cat("\n=== PLUG-IN DECOMPOSITION (ARM 0) ===\n")

Var_theta_A <- PLACEBO_A_SD^2

q_plugin <- Var_theta_A - E_sigma2 / PLACEBO_TPOST
V_sigma2_plugin <- 4 * q_plugin
cv_sigma2_plugin <- sqrt(V_sigma2_plugin) / E_sigma2
r_pred_plugin <- q_plugin / (q_plugin + E_sigma2 / PLACEBO_TH)

cat(sprintf("q_plugin = %.15f\n", q_plugin))
cat(sprintf("V_sigma2_plugin = 4 * q = %.15f\n", V_sigma2_plugin))
cat(sprintf("cv_sigma2_plugin = %.15f\n", cv_sigma2_plugin))
cat(sprintf("r_pred_plugin = %.15f\n", r_pred_plugin))

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
# OUTPUT TABLE (T25a - without V1c Arm 1' values)
# -----------------------------------------------------------------------------
cat("\n=== OUTPUT TABLE ===\n")

out <- data.frame(
  ID = c("PROP_ESIGMA2", "PROP_SIGMA", "PROP_VAR_ETA", "PROP_VAR_R",
         "PROP_APPROX_B", "PROP_MC_B", "PROP_OVERSTATE_PCT",
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
            r_pred_plugin, V_sigma2_plugin, cv_sigma2_plugin,
            PLACEBO_TH, PLACEBO_TPOST, PLACEBO_A_R,
            PLACEBO_A_MEAN, PLACEBO_B_UNCORR_MEAN,
            V2_predicted, mc_mean_v2, V2_shift,
            tau_hat[1], tau_hat[2], tau_hat[3], tau_hat[4],
            kappa_floor),
  stringsAsFactors = FALSE
)

print(out)

write.csv(out, file.path(RTA_ROOT, "output/T25a_prop_constants.csv"), row.names = FALSE)
cat("\nSaved: output/T25a_prop_constants.csv\n")

# -----------------------------------------------------------------------------
# Sidecar
# -----------------------------------------------------------------------------
sha_out <- get_sha256(file.path(RTA_ROOT, "output/T25a_prop_constants.csv"))
writeLines(c(
  "PRODUCER: S26a_prop_constants.R",
  "INPUTS: output/T22_reliability.csv, output/T24_placebo_uncorr.csv, output/T21_arms.csv",
  "SEED: 20260719",
  sprintf("N_REP: %d", N_REP),
  "",
  "V1a/V1b/V2/V3c CONSTANTS (no T28b dependency):",
  sprintf("  E_sigma2 = %.15f", E_sigma2),
  sprintf("  sigma = %.15f", sigma),
  sprintf("  Var_eta = %.15f", Var_eta),
  sprintf("  mc_B = %.15f", mc_B),
  "",
  "PLUG-IN (Arm 0) REFERENCE VALUES:",
  sprintf("  r_pred_plugin = %.15f", r_pred_plugin),
  sprintf("  V_sigma2_plugin = %.15f", V_sigma2_plugin),
  sprintf("  cv_sigma2_plugin = %.15f", cv_sigma2_plugin),
  "",
  "NOTE: V1c Arm 1' values computed separately in S26b after T28b available.",
  "",
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  sprintf("SHA256: %s", sha_out)
), file.path(RTA_ROOT, "meta/T25a_prop_constants.csv.sidecar"))
cat("Saved: T25a_prop_constants.csv.sidecar\n")

# -----------------------------------------------------------------------------
# COMMITTED VALUE GATES
# -----------------------------------------------------------------------------
cat("\n=== COMMITTED VALUE GATES ===\n")

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

g_pass <- TRUE
cat("Checking committed values...\n")
for (id in names(committed)) {
  expected <- committed[[id]]
  actual <- out$value[out$ID == id]
  diff <- abs(actual - expected)
  if (diff > 1e-10) {
    cat(sprintf("  MISMATCH: %s expected %.15f, got %.15f\n", id, expected, actual))
    g_pass <- FALSE
  }
}
if (g_pass) {
  cat("All committed values PASS\n")
} else {
  stop("Committed values FAIL")
}

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n=============================================================================\n")
cat("SUMMARY: S26a COMPLETE\n")
cat("=============================================================================\n")
cat("Output: T25a_prop_constants.csv (V1a/V1b/V2/V3c, no T28b dependency)\n")
cat("Next: S29 -> S29b -> S26b (to add V1c Arm 1' values)\n")
cat("=============================================================================\n")
cat(sprintf("Done: %s\n", format(Sys.time())))
