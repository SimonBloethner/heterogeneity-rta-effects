#!/usr/bin/env Rscript
# =============================================================================
# S29b_v1c_arm1p.R - V1c Arm 1': ESIGMA2 throughout, Jensen on both windows
# =============================================================================
# OUTPUTS: T28b_v1c_arm1p.csv, T28b_v1c_arm1p.csv.sidecar
# INPUTS:  output/T28_v1c_pairlevel.csv, output/T25_prop_verification.csv,
#          output/T22_theta_A_placebo.csv
# SEED:    NONE
# SCRATCH: /scratch/bt307958/V1C_ARM1P/
# =============================================================================

# Login node guard
stopifnot(!grepl("login", Sys.info()[["nodename"]]))

cat("=============================================================================\n")
cat("S29b_v1c_arm1p.R - V1c Arm 1': ESIGMA2 throughout, Jensen on both windows\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat(sprintf("Node: %s\n", Sys.info()[["nodename"]]))
cat("=============================================================================\n\n")

SCRATCH_DIR <- "/scratch/bt307958/V1C_ARM1P"

# SHA256 verification function
get_sha256 <- function(p) {
  strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
}

# =============================================================================
# VERIFY INPUT SHA256
# =============================================================================
cat("=== VERIFYING INPUT SHA256 ===\n")

sha_T28 <- get_sha256(file.path(SCRATCH_DIR, "T28_v1c_pairlevel.csv"))
sha_T25 <- get_sha256(file.path(SCRATCH_DIR, "T25_prop_verification.csv"))
sha_T22 <- get_sha256(file.path(SCRATCH_DIR, "T22_theta_A_placebo.csv"))

expected_sha_T28 <- "06047099424126dc10b3c3239c2b90055403857ed2148bc06bc6d98d557f797c"
expected_sha_T25 <- "e729b79152f302e245dc63145282d08b92c990860d6eb28564a36457fcbee855"
expected_sha_T22 <- "aeaa1148c90507e089216c4474ef8f0301805c232949e79bd3a3b3bbd0edde18"

cat(sprintf("T28_v1c_pairlevel.csv:     %s\n", sha_T28))
cat(sprintf("  Expected:                %s\n", expected_sha_T28))
cat(sprintf("  Match: %s\n", ifelse(sha_T28 == expected_sha_T28, "YES", "HALT")))

cat(sprintf("T25_prop_verification.csv: %s\n", sha_T25))
cat(sprintf("  Expected:                %s\n", expected_sha_T25))
cat(sprintf("  Match: %s\n", ifelse(sha_T25 == expected_sha_T25, "YES", "HALT")))

cat(sprintf("T22_theta_A_placebo.csv:   %s\n", sha_T22))
cat(sprintf("  Expected:                %s\n", expected_sha_T22))
cat(sprintf("  Match: %s\n", ifelse(sha_T22 == expected_sha_T22, "YES", "HALT")))

stopifnot(sha_T28 == expected_sha_T28)
stopifnot(sha_T25 == expected_sha_T25)
stopifnot(sha_T22 == expected_sha_T22)

cat("All input SHA256 verified: PASS\n\n")

# =============================================================================
# LOAD COMMITTED VALUES FROM T28
# =============================================================================
cat("=== LOADING COMMITTED VALUES FROM T28 ===\n")

T28 <- read.csv(file.path(SCRATCH_DIR, "T28_v1c_pairlevel.csv"), stringsAsFactors = FALSE)

# Helper to extract value by quantity name
get_val <- function(q) T28$value[T28$quantity == q]

# Extract all needed values
ES <- get_val("ESIGMA2")
var_thA <- get_val("var_theta_A")
m_inv_Th <- get_val("mean_inv_Th")
mean_sigma2 <- get_val("mean_sigma2")
PLACEBO_A_R <- get_val("PLACEBO_A_R")

# Arms 0, 1, 2 (preserve unchanged)
r0 <- get_val("r0")
r1 <- get_val("r1")
r2 <- get_val("r2")
R_GAP_0 <- get_val("R_GAP_0")
R_GAP_1 <- get_val("R_GAP_1")
R_GAP_2 <- get_val("R_GAP_2")

cat(sprintf("ESIGMA2:       %.15f\n", ES))
cat(sprintf("var_theta_A:   %.15f\n", var_thA))
cat(sprintf("mean_inv_Th:   %.15f\n", m_inv_Th))
cat(sprintf("mean_sigma2:   %.15f\n", mean_sigma2))
cat(sprintf("PLACEBO_A_R:   %.15f\n", PLACEBO_A_R))
cat(sprintf("\nArms 0,1,2 (preserved):\n"))
cat(sprintf("  r0 = %.15f, R_GAP_0 = %.15f\n", r0, R_GAP_0))
cat(sprintf("  r1 = %.15f, R_GAP_1 = %.15f\n", r1, R_GAP_1))
cat(sprintf("  r2 = %.15f, R_GAP_2 = %.15f\n", r2, R_GAP_2))

# =============================================================================
# COMPUTE ARM 1'
# =============================================================================
cat("\n=== COMPUTING ARM 1' ===\n")

# m_inv_Tp = m_inv_Th / 2 (since T_post,i = 2*T_h,i exactly)
m_inv_Tp <- m_inv_Th / 2

cat(sprintf("m_inv_Th:      %.15f\n", m_inv_Th))
cat(sprintf("m_inv_Tp:      %.15f (= m_inv_Th / 2)\n", m_inv_Tp))

# G1: Window identity assertion
g1_diff <- abs(2 * m_inv_Tp - m_inv_Th)
cat(sprintf("\nG1: |2*m_inv_Tp - m_inv_Th| = %.15e, expected < 1e-12\n", g1_diff))
stopifnot(g1_diff < 1e-12)
cat("G1 PASS\n")

# Arm 1': A1p = var_thA - ES * m_inv_Tp
A1p <- var_thA - ES * m_inv_Tp
cat(sprintf("\nA1p = var_thA - ES * m_inv_Tp\n"))
cat(sprintf("    = %.15f - %.15f * %.15f\n", var_thA, ES, m_inv_Tp))
cat(sprintf("    = %.15f\n", A1p))

# G2: A1p matches expected
g2_diff <- abs(A1p - 1.005256)
cat(sprintf("\nG2: |A1p - 1.005256| = %.15e, expected < 1e-5\n", g2_diff))
stopifnot(g2_diff < 1e-5)
cat("G2 PASS\n")

# r1p = A1p / (A1p + ES * m_inv_Th)
r1p <- A1p / (A1p + ES * m_inv_Th)
cat(sprintf("\nr1p = A1p / (A1p + ES * m_inv_Th)\n"))
cat(sprintf("    = %.15f / (%.15f + %.15f * %.15f)\n", A1p, A1p, ES, m_inv_Th))
cat(sprintf("    = %.15f / %.15f\n", A1p, A1p + ES * m_inv_Th))
cat(sprintf("    = %.15f\n", r1p))

# G3: r1p matches expected
g3_diff <- abs(r1p - 0.753863)
cat(sprintf("\nG3: |r1p - 0.753863| = %.15e, expected < 1e-5\n", g3_diff))
stopifnot(g3_diff < 1e-5)
cat("G3 PASS\n")

# R_GAP_1p
R_GAP_1p <- r1p - PLACEBO_A_R
cat(sprintf("\nR_GAP_1p = r1p - PLACEBO_A_R = %.15f - %.15f = %.15f\n",
            r1p, PLACEBO_A_R, R_GAP_1p))

# Drift inflation ratio
DRIFT_INFLATION_RATIO <- mean_sigma2 / ES
cat(sprintf("\nDRIFT_INFLATION_RATIO = mean(sigma2_i) / ESIGMA2 = %.15f / %.15f = %.15f\n",
            mean_sigma2, ES, DRIFT_INFLATION_RATIO))

# =============================================================================
# OUTPUT FILES (write BEFORE terminal gate)
# =============================================================================
cat("\n=== WRITING OUTPUT FILES ===\n")

out <- data.frame(
  quantity = c(
    "r0", "R_GAP_0",
    "r1", "R_GAP_1",
    "r1p", "R_GAP_1p",
    "r2", "R_GAP_2",
    "A1p",
    "ESIGMA2",
    "var_theta_A",
    "mean_inv_Th",
    "mean_inv_Tp",
    "mean_sigma2",
    "DRIFT_INFLATION_RATIO",
    "PLACEBO_A_R"
  ),
  value = c(
    r0, R_GAP_0,
    r1, R_GAP_1,
    r1p, R_GAP_1p,
    r2, R_GAP_2,
    A1p,
    ES,
    var_thA,
    m_inv_Th,
    m_inv_Tp,
    mean_sigma2,
    DRIFT_INFLATION_RATIO,
    PLACEBO_A_R
  ),
  stringsAsFactors = FALSE
)

write.csv(out, file.path(SCRATCH_DIR, "T28b_v1c_arm1p.csv"), row.names = FALSE)
cat(sprintf("Wrote: %s/T28b_v1c_arm1p.csv\n", SCRATCH_DIR))

# SHA256 of output
sha_out <- get_sha256(file.path(SCRATCH_DIR, "T28b_v1c_arm1p.csv"))

# Sidecar
sidecar_lines <- c(
  "FILE:      T28b_v1c_arm1p.csv",
  sprintf("SHA256:    %s", sha_out),
  "PRODUCER:  S29b_v1c_arm1p.R",
  "INPUTS:",
  sprintf("  output/T28_v1c_pairlevel.csv:     %s", sha_T28),
  sprintf("  output/T25_prop_verification.csv: %s", sha_T25),
  sprintf("  output/T22_theta_A_placebo.csv:   %s", sha_T22),
  "SEED:      NONE",
  "",
  "ARM 1' SPECIFICATION:",
  "  Uses ESIGMA2 throughout (not mean(sigma2_i))",
  "  Jensen-corrects on BOTH windows:",
  "    - T_post for variance decomposition: A1p = var_thA - ES * m_inv_Tp",
  "    - T_h for split-half: r1p = A1p / (A1p + ES * m_inv_Th)",
  "",
  "FOUR ARMS:",
  sprintf("  Arm 0 (plug-in):            r0  = %.15f, R_GAP_0  = %.15f", r0, R_GAP_0),
  sprintf("  Arm 1 (Jensen 1/T_h only):  r1  = %.15f, R_GAP_1  = %.15f", r1, R_GAP_1),
  sprintf("  Arm 1' (Jensen both):       r1p = %.15f, R_GAP_1p = %.15f", r1p, R_GAP_1p),
  sprintf("  Arm 2 (full pair-level):    r2  = %.15f, R_GAP_2  = %.15f", r2, R_GAP_2),
  "",
  sprintf("DRIFT_INFLATION_RATIO = mean(sigma2_i)/ESIGMA2 = %.15f", DRIFT_INFLATION_RATIO),
  "",
  "GATES:",
  sprintf("  G1: |2*m_inv_Tp - m_inv_Th| = %.2e < 1e-12: PASS", g1_diff),
  sprintf("  G2: |A1p - 1.005256| = %.2e < 1e-5: PASS", g2_diff),
  sprintf("  G3: |r1p - 0.753863| = %.2e < 1e-5: PASS", g3_diff),
  sprintf("  G4: |R_GAP_1p| = %.6f < 0.05: %s", abs(R_GAP_1p), ifelse(abs(R_GAP_1p) < 0.05, "PASS", "FAIL")),
  "",
  sprintf("CREATED: %s", format(Sys.time()))
)

writeLines(sidecar_lines, file.path(SCRATCH_DIR, "T28b_v1c_arm1p.csv.sidecar"))
cat(sprintf("Wrote: %s/T28b_v1c_arm1p.csv.sidecar\n", SCRATCH_DIR))

# =============================================================================
# TERMINAL GATE G4
# =============================================================================
cat("\n=== TERMINAL GATE G4 ===\n")
cat(sprintf("G4: |R_GAP_1p| = %.15f, bound = 0.05\n", abs(R_GAP_1p)))

if (abs(R_GAP_1p) < 0.05) {
  cat("G4 PASS\n")
} else {
  cat("G4 FAIL - This is the FINDING\n")
  cat(sprintf("  r1p = %.15f\n", r1p))
  cat(sprintf("  PLACEBO_A_R = %.15f\n", PLACEBO_A_R))
  cat(sprintf("  |R_GAP_1p| = %.15f >= 0.05\n", abs(R_GAP_1p)))
}

stopifnot(abs(R_GAP_1p) < 0.05)

# =============================================================================
# SUMMARY
# =============================================================================
cat("\n=============================================================================\n")
cat("SUMMARY: ALL GATES PASSED\n")
cat("=============================================================================\n")
cat(sprintf("G1: window identity: PASS\n"))
cat(sprintf("G2: |A1p - 1.005256| < 1e-5: PASS\n"))
cat(sprintf("G3: |r1p - 0.753863| < 1e-5: PASS\n"))
cat(sprintf("G4: |R_GAP_1p| = %.6f < 0.05: PASS\n", abs(R_GAP_1p)))
cat("=============================================================================\n")
cat("\nFOUR ARMS COMPARISON:\n")
cat(sprintf("  Arm 0:  r = %.4f, R_GAP = %+.4f\n", r0, R_GAP_0))
cat(sprintf("  Arm 1:  r = %.4f, R_GAP = %+.4f\n", r1, R_GAP_1))
cat(sprintf("  Arm 1': r = %.4f, R_GAP = %+.4f  <-- Jensen on both windows\n", r1p, R_GAP_1p))
cat(sprintf("  Arm 2:  r = %.4f, R_GAP = %+.4f\n", r2, R_GAP_2))
cat("=============================================================================\n")
cat(sprintf("Done: %s\n", format(Sys.time())))
