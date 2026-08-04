#!/usr/bin/env Rscript
# S26b_prop_verification.R - V1c Arm 1' decomposition (reads T28b)
# OUTPUTS: output/T25_prop_verification.csv, article/prop_constants.tex,
#          meta/T25_prop_verification.csv.sidecar
# INPUTS:  output/T25a_prop_constants.csv, output/T28b_v1c_arm1p.csv
# SEED:    NONE (deterministic merge of T25a + T28b values)
#
# Split from S26: Merges T25a (V1a/V1b/V2/V3c) with T28b (Arm 1' values)
# to produce final T25 with V1c values.

# Login node guard
stopifnot(!grepl("login", Sys.info()[["nodename"]]))

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(data.table))

cat("=============================================================================\n")
cat("S26b_prop_verification.R - V1c Arm 1' decomposition (reads T28b)\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat(sprintf("Node: %s\n", Sys.info()[["nodename"]]))
cat("=============================================================================\n\n")

# SHA256 verification function
get_sha256 <- function(p) {
  strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
}

# -----------------------------------------------------------------------------
# Load T25a (V1a/V1b/V2/V3c) and T28b (Arm 1' values)
# -----------------------------------------------------------------------------
cat("=== LOADING INPUTS ===\n")

T25a <- fread(file.path(RTA_ROOT, "output/T25a_prop_constants.csv"))
T28b <- fread(file.path(RTA_ROOT, "output/T28b_v1c_arm1p.csv"))

cat(sprintf("T25a rows: %d\n", nrow(T25a)))
cat(sprintf("T28b rows: %d\n", nrow(T28b)))

# Extract values from T25a
E_sigma2 <- T25a[ID == "PROP_ESIGMA2", value]
sigma <- T25a[ID == "PROP_SIGMA", value]
Var_eta <- T25a[ID == "PROP_VAR_ETA", value]
Var_R <- T25a[ID == "PROP_VAR_R", value]
approx_B <- T25a[ID == "PROP_APPROX_B", value]
mc_B <- T25a[ID == "PROP_MC_B", value]
overstate_pct <- T25a[ID == "PROP_OVERSTATE_PCT", value]
r_pred_plugin <- T25a[ID == "PROP_R_PRED_PLUGIN", value]
V_sigma2_plugin <- T25a[ID == "PROP_V_SIGMA2_PLUGIN", value]
cv_sigma2_plugin <- T25a[ID == "PROP_CV_SIGMA2_PLUGIN", value]
PLACEBO_TH <- T25a[ID == "PROP_TH", value]
PLACEBO_TPOST <- T25a[ID == "PROP_TPOST", value]
PLACEBO_A_R <- T25a[ID == "PROP_PLACEBO_R", value]
PLACEBO_A_MEAN <- T25a[ID == "PROP_PLACEBO_A_MEAN", value]
PLACEBO_B_UNCORR_MEAN <- T25a[ID == "PROP_PLACEBO_B_UNCORR", value]
V2_predicted <- T25a[ID == "PROP_V2_PRED", value]
mc_mean_v2 <- T25a[ID == "PROP_V2_SIM", value]
V2_shift <- T25a[ID == "PROP_V2_SHIFT", value]
tau_hat_1 <- T25a[ID == "PROP_TAU_K1", value]
tau_hat_2 <- T25a[ID == "PROP_TAU_K2", value]
tau_hat_3 <- T25a[ID == "PROP_TAU_K3", value]
tau_hat_5 <- T25a[ID == "PROP_TAU_K5", value]
kappa_floor <- T25a[ID == "PROP_KAPPA_FLOOR", value]

# Extract Arm 1' values from T28b
r1p <- T28b[quantity == "r1p", value]
R_GAP_1p <- T28b[quantity == "R_GAP_1p", value]
A1p <- T28b[quantity == "A1p", value]
mean_inv_Th <- T28b[quantity == "mean_inv_Th", value]

cat(sprintf("E_sigma2 (T25a)       = %.15f\n", E_sigma2))
cat(sprintf("r1p (T28b)            = %.15f\n", r1p))
cat(sprintf("R_GAP_1p (T28b)       = %.15f\n", R_GAP_1p))
cat(sprintf("A1p (T28b)            = %.15f\n", A1p))
cat(sprintf("mean_inv_Th (T28b)    = %.15f\n", mean_inv_Th))

# -----------------------------------------------------------------------------
# V1c: Reliability - Arm 1' decomposition
# -----------------------------------------------------------------------------
cat("\n=== V1c: RELIABILITY (ARM 1' DECOMPOSITION) ===\n")

V_sigma2 <- 4 * A1p
cv_sigma2 <- sqrt(V_sigma2) / E_sigma2
r_pred <- r1p
r_gap <- abs(R_GAP_1p)

cat(sprintf("A1p = %.15f\n", A1p))
cat(sprintf("V_sigma2 = 4 * A1p = %.15f\n", V_sigma2))
cat(sprintf("cv_sigma2 = sqrt(V)/E = %.15f\n", cv_sigma2))
cat(sprintf("r_pred = r1p = %.15f\n", r_pred))
cat(sprintf("r_gap = |R_GAP_1p| = %.15f\n", r_gap))

# Wrong-object gates
stopifnot(A1p > 0)
stopifnot(V_sigma2 > 0)
stopifnot(r_pred > 0, r_pred < 1)
stopifnot(PLACEBO_TH >= 2)

cat("\nV1c wrong-object gates: PASS\n")

# -----------------------------------------------------------------------------
# OUTPUT TABLE (T25 - full with V1c Arm 1' values)
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
            tau_hat_1, tau_hat_2, tau_hat_3, tau_hat_5,
            kappa_floor),
  stringsAsFactors = FALSE
)

print(out)

write.csv(out, file.path(RTA_ROOT, "output/T25_prop_verification.csv"), row.names = FALSE)
cat("\nSaved: output/T25_prop_verification.csv\n")

# -----------------------------------------------------------------------------
# OUTPUT: prop_constants.tex
# -----------------------------------------------------------------------------
cat("\n=== GENERATING prop_constants.tex ===\n")

tex_lines <- c(
  "% prop_constants.tex - Auto-generated by S26b_prop_verification.R",
  sprintf("%% Generated: %s", Sys.time()),
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
  sprintf("\\newcommand{\\PropTauKone}{%.4f}", tau_hat_1),
  sprintf("\\newcommand{\\PropTauKtwo}{%.4f}", tau_hat_2),
  sprintf("\\newcommand{\\PropTauKthree}{%.4f}", tau_hat_3),
  sprintf("\\newcommand{\\PropTauKfive}{%.4f}", tau_hat_5),
  sprintf("\\newcommand{\\PropKappaFloor}{%.3f}", kappa_floor),
  ""
)

writeLines(tex_lines, file.path(RTA_ROOT, "article/prop_constants.tex"))
cat("Saved: article/prop_constants.tex\n")

# -----------------------------------------------------------------------------
# Sidecar
# -----------------------------------------------------------------------------
sha_out <- get_sha256(file.path(RTA_ROOT, "output/T25_prop_verification.csv"))
writeLines(c(
  "PRODUCER: S26b_prop_verification.R",
  "INPUTS: output/T25a_prop_constants.csv, output/T28b_v1c_arm1p.csv",
  "SEED: NONE (deterministic merge)",
  "",
  "V1c CHAIN ON ARM 1' DECOMPOSITION:",
  sprintf("  A1p (from T28b) = %.15f", A1p),
  sprintf("  V_sigma2 = 4 * A1p = %.15f", V_sigma2),
  sprintf("  CV_sigma2 = sqrt(V)/E = %.15f", cv_sigma2),
  sprintf("  r_pred (Arm 1') = %.15f", r_pred),
  sprintf("  r_gap = %.15f", r_gap),
  "",
  "PLUG-IN DIAGNOSTICS (Arm 0, from T25a):",
  sprintf("  V_sigma2_plugin = %.15f", V_sigma2_plugin),
  sprintf("  CV_sigma2_plugin = %.15f", cv_sigma2_plugin),
  sprintf("  r_pred_plugin = %.15f", r_pred_plugin),
  "",
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  sprintf("SHA256: %s", sha_out)
), file.path(RTA_ROOT, "meta/T25_prop_verification.csv.sidecar"))
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

# G5: All main.tex macros resolve
cat("G5: Checking prop_constants.tex macros...\n")
tex_content <- readLines(file.path(RTA_ROOT, "article/prop_constants.tex"))
required_macros <- c("PropEsigsq", "PropSigma", "PropVarEta", "PropVarR",
                     "PropApproxB", "PropMCB", "PropOverstatePct",
                     "PropVsigmasq", "PropCVsigsq", "PropRpred", "PropRgap",
                     "PropTh", "PropTpost", "PropPlaceboR",
                     "PropPlaceboAMean", "PropPlaceboBUncorr",
                     "PropVtwoPred", "PropVtwoSim", "PropVtwoShift",
                     "PropTauKone", "PropTauKtwo", "PropTauKthree", "PropTauKfive",
                     "PropKappaFloor")

g5_pass <- TRUE
for (macro in required_macros) {
  pattern <- sprintf("\\\\newcommand\\{\\\\%s\\}", macro)
  if (!any(grepl(pattern, tex_content))) {
    cat(sprintf("  MISSING: \\%s\n", macro))
    g5_pass <- FALSE
  }
}
if (g5_pass) {
  cat("G5 PASS\n")
} else {
  stop("G5 FAIL")
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
cat(sprintf("G5: All main.tex macros resolve: PASS\n"))
cat("=============================================================================\n")
cat(sprintf("Done: %s\n", format(Sys.time())))
