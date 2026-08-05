#!/usr/bin/env Rscript
# =============================================================================
# S29_v1c_pairlevel.R - V1c Reliability with Pair-Level Noise Terms
# =============================================================================
# OUTPUTS: T28_v1c_pairlevel.csv, T28_v1c_pairlevel.csv.sidecar
# INPUTS:  data/S5R_bhat.rds, data/S1R_ppml.rds,
#          output/T25a_prop_constants.csv, output/T22_theta_A_placebo.csv
# EXPECTED_N: 15683
# SEED:    NONE
# SCRATCH: /scratch/bt307958/V1C_PAIRLEVEL/
# =============================================================================

# Login node guard
stopifnot(!grepl("login", Sys.info()[["nodename"]]))

cat("=============================================================================\n")
cat("S29_v1c_pairlevel.R - V1c Reliability with Pair-Level Noise Terms\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat(sprintf("Node: %s\n", Sys.info()[["nodename"]]))
cat("=============================================================================\n\n")

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(data.table))

# SHA256 verification function
get_sha256 <- function(p) {
  strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
}


# =============================================================================
# LOAD DATA
# =============================================================================
cat("=== LOADING DATA ===\n")

S5R <- readRDS(file.path(RTA_ROOT, "data/S5R_bhat.rds"))
placebo_meta <- as.data.table(S5R[["placebo"]])
cat(sprintf("Placebo pairs in S5R: %d\n", nrow(placebo_meta)))

ppml <- readRDS(file.path(RTA_ROOT, "data/S1R_ppml.rds"))
setDT(ppml)
cat(sprintf("PPML rows: %d\n", nrow(ppml)))

T22 <- fread(file.path(RTA_ROOT, "output/T22_theta_A_placebo.csv"))
cat(sprintf("T22 rows: %d\n", nrow(T22)))
cat(sprintf("T22 columns: %s\n", paste(names(T22), collapse = ", ")))

T25a <- fread(file.path(RTA_ROOT, "output/T25a_prop_constants.csv"))
cat(sprintf("T25a rows: %d\n", nrow(T25a)))

# =============================================================================
# FILTER TO QUALIFYING PAIRS
# =============================================================================
cat("\n=== FILTERING TO QUALIFYING PAIRS ===\n")

# T22_theta_A_placebo.csv now contains only qualifying pairs (INV-048)
# All rows are already qualifying (>= 4 post cells, >= 2 per half)
qualifying <- T22
n_qualifying <- nrow(qualifying)
cat(sprintf("Qualifying pairs (all rows in T22 are qualifying): %d\n", n_qualifying))

# G1: n used == 15683
cat(sprintf("\nG1: n used = %d, expected 15683\n", n_qualifying))
stopifnot(n_qualifying == 15683)
cat("G1 PASS\n")

# =============================================================================
# COMPUTE PER-PAIR QUANTITIES
# =============================================================================
cat("\n=== COMPUTING PER-PAIR QUANTITIES ===\n")

# Get pseudo-adoption years from placebo_meta
pseudo_years <- setNames(placebo_meta$pseudo, placebo_meta$pair)

# Pre-allocate results
results <- data.table(
  pair = qualifying$pair,
  theta_A = qualifying$theta_A,
  sigma2_i = NA_real_,
  T_post_i = NA_integer_,
  T_h_i = NA_real_
)

cat("Processing pairs...\n")
pb_interval <- 1000

for (idx in seq_len(nrow(results))) {
  p <- results$pair[idx]
  pseudo <- pseudo_years[p]

  # Get post cells: year > pseudo + 1 & trade > 0 & y_hat_0 > 0
  # (exactly as in S24_reliability.R line 64)
  ppml_pair <- ppml[pair == p]
  post_cells <- ppml_pair[year > pseudo + 1 & trade > 0 & y_hat_0 > 0]

  if (nrow(post_cells) < 2) {
    # Should not happen for qualifying pairs, but guard
    next
  }

  # Compute g_ijt = log(trade) - log(y_hat_0)
  g_ijt <- log(post_cells$trade) - log(post_cells$y_hat_0)

  # sigma2_i = var(g_ijt), R default uses n-1 denominator
  results$sigma2_i[idx] <- var(g_ijt)
  results$T_post_i[idx] <- length(g_ijt)
  results$T_h_i[idx] <- length(g_ijt) / 2

  if (idx %% pb_interval == 0) {
    cat(sprintf("  Processed %d / %d pairs\n", idx, nrow(results)))
  }
}

cat(sprintf("Processed %d pairs\n", nrow(results)))

# Check no NAs
n_complete <- sum(complete.cases(results))
cat(sprintf("Complete cases: %d\n", n_complete))
stopifnot(n_complete == n_qualifying)

# =============================================================================
# LOAD T25a COMMITTED VALUES
# =============================================================================
cat("\n=== LOADING T25a COMMITTED VALUES ===\n")

ESIGMA2 <- T25a[ID == "PROP_ESIGMA2", value]
V_SIGMA2_PLUGIN <- T25a[ID == "PROP_V_SIGMA2_PLUGIN", value]
T_H_BAR <- T25a[ID == "PROP_TH", value]
T_POST_BAR <- T25a[ID == "PROP_TPOST", value]
R_PRED_PLUGIN <- T25a[ID == "PROP_R_PRED_PLUGIN", value]
PLACEBO_A_R <- T25a[ID == "PROP_PLACEBO_R", value]

# A0 from plug-in decomposition (reference only)
A0 <- V_SIGMA2_PLUGIN / 4

cat(sprintf("ESIGMA2 (from T25a):       %.15f\n", ESIGMA2))
cat(sprintf("V_SIGMA2_PLUGIN (from T25a): %.15f\n", V_SIGMA2_PLUGIN))
cat(sprintf("A0 = V_SIGMA2_PLUGIN/4:    %.15f\n", A0))
cat(sprintf("T_H_BAR (from T25a):       %.15f\n", T_H_BAR))
cat(sprintf("T_POST_BAR (from T25a):    %.15f\n", T_POST_BAR))
cat(sprintf("R_PRED_PLUGIN (from T25a): %.15f\n", R_PRED_PLUGIN))
cat(sprintf("PLACEBO_A_R (from T25a):   %.15f\n", PLACEBO_A_R))

# =============================================================================
# COMPUTE PAIR-LEVEL QUANTITIES
# =============================================================================
cat("\n=== COMPUTING PAIR-LEVEL QUANTITIES ===\n")

# Variance of theta_A across pairs
var_theta_A <- var(results$theta_A)
cat(sprintf("var(theta_A):          %.15f\n", var_theta_A))

# Mean of sigma2_i / T_post,i
mean_sigma2_over_Tpost <- mean(results$sigma2_i / results$T_post_i)
cat(sprintf("mean(sigma2_i/T_post,i): %.15f\n", mean_sigma2_over_Tpost))

# VarSig2 from decomposition (spec formula)
VarSig2 <- 4 * (var_theta_A - mean_sigma2_over_Tpost)
A <- VarSig2 / 4  # = var_theta_A - mean_sigma2_over_Tpost
cat(sprintf("VarSig2 = 4*(var - mean): %.15f\n", VarSig2))
cat(sprintf("A = VarSig2/4:           %.15f\n", A))

# Mean of 1/T_h,i
mean_inv_Th <- mean(1 / results$T_h_i)
cat(sprintf("mean(1/T_h,i):         %.15f\n", mean_inv_Th))

# Mean of sigma2_i / T_h,i
mean_sigma2_over_Th <- mean(results$sigma2_i / results$T_h_i)
cat(sprintf("mean(sigma2_i/T_h,i):  %.15f\n", mean_sigma2_over_Th))

# Arithmetic and harmonic mean of T_h,i
arith_mean_Th <- mean(results$T_h_i)
harm_mean_Th <- 1 / mean(1 / results$T_h_i)
cat(sprintf("Arithmetic mean T_h,i: %.15f\n", arith_mean_Th))
cat(sprintf("Harmonic mean T_h,i:   %.15f\n", harm_mean_Th))

# Mean of sigma2_i
mean_sigma2 <- mean(results$sigma2_i)
cat(sprintf("mean(sigma2_i):        %.15f\n", mean_sigma2))
cat(sprintf("ESIGMA2 (committed):   %.15f\n", ESIGMA2))

# Spearman correlation of sigma2_i with T_h,i
spearman_rho <- cor(results$sigma2_i, results$T_h_i, method = "spearman")
cat(sprintf("Spearman(sigma2_i, T_h,i): %.15f\n", spearman_rho))

# =============================================================================
# COMPUTE THREE ARMS
# =============================================================================
cat("\n=== COMPUTING THREE ARMS ===\n")

# Arm 0 (plug-in, current): r0 = A0 / (A0 + ESIGMA2 / T_h_bar)
r0 <- A0 / (A0 + ESIGMA2 / T_H_BAR)
cat(sprintf("Arm 0: r0 = %.15f\n", r0))
cat(sprintf("       A0 / (A0 + ESIGMA2/T_h_bar) = %.6f / (%.6f + %.6f/%.6f)\n",
            A0, A0, ESIGMA2, T_H_BAR))

# Arm 1 (Jensen on 1/T only): r1 = A / (A + ESIGMA2 * mean_i(1/T_h,i))
r1 <- A / (A + ESIGMA2 * mean_inv_Th)
cat(sprintf("Arm 1: r1 = %.15f\n", r1))
cat(sprintf("       A / (A + ESIGMA2 * mean(1/T_h)) = %.6f / (%.6f + %.6f * %.6f)\n",
            A, A, ESIGMA2, mean_inv_Th))

# Arm 2 (full pair-level): r2 = A / (A + mean_i(sigma2_i / T_h,i))
r2 <- A / (A + mean_sigma2_over_Th)
cat(sprintf("Arm 2: r2 = %.15f\n", r2))
cat(sprintf("       A / (A + mean(sigma2/T_h)) = %.6f / (%.6f + %.6f)\n",
            A, A, mean_sigma2_over_Th))

# R_GAP for each arm
R_GAP_0 <- r0 - PLACEBO_A_R
R_GAP_1 <- r1 - PLACEBO_A_R
R_GAP_2 <- r2 - PLACEBO_A_R

cat(sprintf("\nR_GAP_0 = r0 - %.15f = %.15f\n", PLACEBO_A_R, R_GAP_0))
cat(sprintf("R_GAP_1 = r1 - %.15f = %.15f\n", PLACEBO_A_R, R_GAP_1))
cat(sprintf("R_GAP_2 = r2 - %.15f = %.15f\n", PLACEBO_A_R, R_GAP_2))

# =============================================================================
# GATES G2-G4
# =============================================================================
cat("\n=== GATES G2-G4 ===\n")

# G2: r0 matches plug-in r_pred from T25a (consistency check)
g2_diff <- abs(r0 - R_PRED_PLUGIN)
cat(sprintf("G2: |r0 - R_PRED_PLUGIN| = %.15e, expected < 1e-4\n", g2_diff))
stopifnot(g2_diff < 1e-4)
cat("G2 PASS\n")

# G3: harmonic_mean(T_h,i) < arithmetic_mean(T_h,i)
cat(sprintf("G3: harmonic %.6f < arithmetic %.6f\n", harm_mean_Th, arith_mean_Th))
stopifnot(harm_mean_Th < arith_mean_Th)
cat("G3 PASS\n")

# G4: r2 <= r0 (correction must move reliability DOWN)
cat(sprintf("G4: r2 = %.6f <= r0 = %.6f\n", r2, r0))
stopifnot(r2 <= r0)
cat("G4 PASS\n")

# =============================================================================
# OUTPUT FILES (write BEFORE terminal gate)
# =============================================================================
cat("\n=== WRITING OUTPUT FILES ===\n")

# T28_v1c_pairlevel.csv
out <- data.frame(
  quantity = c(
    "n_qualifying",
    "var_theta_A",
    "mean_sigma2_over_Tpost",
    "VarSig2",
    "A",
    "A0_T25",
    "ESIGMA2",
    "T_h_bar_T25",
    "mean_inv_Th",
    "mean_sigma2_over_Th",
    "arith_mean_Th",
    "harm_mean_Th",
    "mean_sigma2",
    "spearman_sigma2_Th",
    "r0",
    "r1",
    "r2",
    "R_GAP_0",
    "R_GAP_1",
    "R_GAP_2",
    "PLACEBO_A_R"
  ),
  value = c(
    n_qualifying,
    var_theta_A,
    mean_sigma2_over_Tpost,
    VarSig2,
    A,
    A0,
    ESIGMA2,
    T_H_BAR,
    mean_inv_Th,
    mean_sigma2_over_Th,
    arith_mean_Th,
    harm_mean_Th,
    mean_sigma2,
    spearman_rho,
    r0,
    r1,
    r2,
    R_GAP_0,
    R_GAP_1,
    R_GAP_2,
    PLACEBO_A_R
  ),
  stringsAsFactors = FALSE
)

write.csv(out, file.path(RTA_ROOT, "output/T28_v1c_pairlevel.csv"), row.names = FALSE)
cat("Wrote: output/T28_v1c_pairlevel.csv\n")

# SHA256 of output
sha_T28 <- get_sha256(file.path(RTA_ROOT, "output/T28_v1c_pairlevel.csv"))

# Sidecar
sidecar_lines <- c(
  "FILE:      T28_v1c_pairlevel.csv",
  sprintf("SHA256:    %s", sha_T28),
  "PRODUCER:  S29_v1c_pairlevel.R",
  "INPUTS:",
  "  data/S5R_bhat.rds",
  "  data/S1R_ppml.rds",
  "  output/T25a_prop_constants.csv",
  "  output/T22_theta_A_placebo.csv",
  "SEED:      NONE",
  "",
  "POPULATION: Split-half qualifying placebo pairs (qualifies == TRUE)",
  sprintf("  n = %d", n_qualifying),
  "",
  "PAIR-LEVEL QUANTITIES:",
  sprintf("  var(theta_A):            %.15f", var_theta_A),
  sprintf("  mean(sigma2_i/T_post,i): %.15f", mean_sigma2_over_Tpost),
  sprintf("  VarSig2 = 4*(var - mean): %.15f", VarSig2),
  sprintf("  A = VarSig2/4:           %.15f", A),
  "",
  "T_h STATISTICS:",
  sprintf("  Arithmetic mean:         %.15f", arith_mean_Th),
  sprintf("  Harmonic mean:           %.15f", harm_mean_Th),
  sprintf("  mean(1/T_h,i):           %.15f", mean_inv_Th),
  "",
  "SIGMA2 STATISTICS:",
  sprintf("  mean(sigma2_i):          %.15f", mean_sigma2),
  sprintf("  ESIGMA2 (committed):     %.15f", ESIGMA2),
  sprintf("  Spearman(sigma2, T_h):   %.15f", spearman_rho),
  "",
  "THREE ARMS:",
  sprintf("  Arm 0 (plug-in):         r0 = %.15f", r0),
  sprintf("  Arm 1 (Jensen 1/T):      r1 = %.15f", r1),
  sprintf("  Arm 2 (full pair-level): r2 = %.15f", r2),
  "",
  "R_GAP (r - 0.74630841671878):",
  sprintf("  R_GAP_0 = %.15f", R_GAP_0),
  sprintf("  R_GAP_1 = %.15f", R_GAP_1),
  sprintf("  R_GAP_2 = %.15f", R_GAP_2),
  "",
  "GATES:",
  sprintf("  G1: n = %d == 15683: PASS", n_qualifying),
  sprintf("  G2: |r0 - R_PRED_PLUGIN| = %.2e < 1e-4: PASS", g2_diff),
  sprintf("  G3: harm(%.4f) < arith(%.4f): PASS", harm_mean_Th, arith_mean_Th),
  sprintf("  G4: r2(%.6f) <= r0(%.6f): PASS", r2, r0),
  sprintf("  G5: |R_GAP_2| = %.6f < 0.05: %s", abs(R_GAP_2), ifelse(abs(R_GAP_2) < 0.05, "PASS", "FAIL")),
  "",
  sprintf("CREATED: %s", format(Sys.time()))
)

writeLines(sidecar_lines, file.path(RTA_ROOT, "meta/T28_v1c_pairlevel.csv.sidecar"))
cat("Wrote: meta/T28_v1c_pairlevel.csv.sidecar\n")

# =============================================================================
# SUMMARY
# =============================================================================
cat("\n=============================================================================\n")
cat("SUMMARY\n")
cat("=============================================================================\n")
cat(sprintf("G1: n = %d == 15683: %s\n", n_qualifying, ifelse(n_qualifying == 15683, "PASS", "FAIL")))
cat(sprintf("G2: |r0 - R_PRED_PLUGIN| = %.2e < 1e-4: %s\n", g2_diff, ifelse(g2_diff < 1e-4, "PASS", "FAIL")))
cat(sprintf("G3: harmonic(%.4f) < arithmetic(%.4f): %s\n", harm_mean_Th, arith_mean_Th, ifelse(harm_mean_Th < arith_mean_Th, "PASS", "FAIL")))
cat(sprintf("G4: r2(%.6f) <= r0(%.6f): %s\n", r2, r0, ifelse(r2 <= r0, "PASS", "FAIL")))
cat("=============================================================================\n")
cat(sprintf("Done: %s\n", format(Sys.time())))
