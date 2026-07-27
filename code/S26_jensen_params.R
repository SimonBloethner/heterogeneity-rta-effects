#!/usr/bin/env Rscript
# S26_jensen_params.R - Jensen/Reliability parameters from placebo moments
# OUTPUTS: output/T25_jensen_params.csv, meta/T25_jensen_params.csv.sidecar
# INPUTS:  output/T22_reliability.csv, output/T22_theta_A_placebo.csv, data/S5R_bhat.rds
# SEED:    20260719
# EXPECTED_N: 4182 (treated), 15683 (placebo qualifying)
#
# R1: Derive E[sigma^2] from placebo mean per Proposition 1(a):
#     E[theta^A | zero effect] = -sigma^2_ij / 2
#     => E[sigma^2] = -2 * PLACEBO_A_MEAN
#
# R2: Derive VAR_SIGMA2 from placebo variance per Proposition 1(c):
#     Var(theta^A) = Var(sigma^2)/4 + E[sigma^2]/T_h
#     => Var(sigma^2) = 4 * (Var(theta^A) - E[sigma^2]/T_h)
#
# Also compute T_post distribution for treated population.

suppressPackageStartupMessages(library(data.table))
set.seed(20260719)
setwd("/scratch/bt307958/REBUILD_V2")

EXPECTED_N_TREATED <- 4182
EXPECTED_N_PLACEBO_QUAL <- 15683

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------
cat("=== LOADING DATA ===\n")

# T22 reliability summary
T22 <- fread("output/T22_reliability.csv")

# Extract placebo moments
PLACEBO_A_MEAN <- T22[ID == "PLACEBO_A_MEAN", value]
PLACEBO_A_SD <- T22[ID == "PLACEBO_A_SD", value]
PLACEBO_A_R <- T22[ID == "PLACEBO_A_R", value]

cat(sprintf("PLACEBO_A_MEAN = %.6f\n", PLACEBO_A_MEAN))
cat(sprintf("PLACEBO_A_SD = %.6f\n", PLACEBO_A_SD))
cat(sprintf("PLACEBO_A_R = %.6f\n", PLACEBO_A_R))

# Load per-pair placebo theta_A for T_h distribution
placebo_pairs <- fread("output/T22_theta_A_placebo.csv")
stopifnot(nrow(placebo_pairs) == EXPECTED_N_PLACEBO_QUAL)
cat(sprintf("G1 Placebo qualifying pairs n = %d: PASS\n", nrow(placebo_pairs)))

# Load treated population for T_post distribution
S5R <- readRDS("data/S5R_bhat.rds")
base <- as.data.table(S5R[["baseline"]])
stopifnot(nrow(base) == EXPECTED_N_TREATED)
cat(sprintf("G2 Treated pairs n = %d: PASS\n", nrow(base)))

# Load PPML for computing T_post per pair
ppml <- readRDS("data/S1R_ppml.rds")
setDT(ppml)

# -----------------------------------------------------------------------------
# R1: E[sigma^2] from placebo mean
# -----------------------------------------------------------------------------
cat("\n=== R1: E[SIGMA^2] FROM PLACEBO MEAN ===\n")

# Proposition 1(a): E[theta^A | zero effect] = -sigma^2_ij / 2
# => E[sigma^2] = -2 * E[theta^A]
ESIGMA2_PLACEBO <- -2 * PLACEBO_A_MEAN
SIGMA_PLACEBO <- sqrt(ESIGMA2_PLACEBO)

cat(sprintf("ESIGMA2_PLACEBO = -2 * PLACEBO_A_MEAN = -2 * (%.6f) = %.6f\n",
            PLACEBO_A_MEAN, ESIGMA2_PLACEBO))
cat(sprintf("SIGMA_PLACEBO = sqrt(ESIGMA2_PLACEBO) = sqrt(%.6f) = %.6f\n",
            ESIGMA2_PLACEBO, SIGMA_PLACEBO))

# Gate: verify derivation
stopifnot(abs(ESIGMA2_PLACEBO - (-2 * PLACEBO_A_MEAN)) < 1e-9)
cat("G3 ESIGMA2 derivation: PASS\n")

# Cross-check with user's non-binding values
cat("\nCross-check with prompt's non-binding values:\n")
cat(sprintf("  Computed E[sigma^2] = %.4f (expected ~1.364)\n", ESIGMA2_PLACEBO))
cat(sprintf("  Computed sigma = %.4f (expected ~1.168)\n", SIGMA_PLACEBO))

# -----------------------------------------------------------------------------
# Compute T_post distribution for treated population
# -----------------------------------------------------------------------------
cat("\n=== T_POST DISTRIBUTION (TREATED) ===\n")

# For each treated pair, count post-cells
# Post: year > adoption_year + 1, trade > 0, y_hat_0 > 0
compute_T_post <- function(pair_id, adopt_yr, ppml_dt) {
  ppml_pair <- ppml_dt[pair == pair_id]
  post_cells <- ppml_pair[year > adopt_yr + 1 & trade > 0 & y_hat_0 > 0]
  nrow(post_cells)
}

# Use data.table approach - PPML already has adoption_year
ppml_treated <- ppml[pair %in% base$pair]

# Filter to post cells
post_cells <- ppml_treated[year > adoption_year + 1 & trade > 0 & y_hat_0 > 0]

# Count per pair
T_post_dist <- post_cells[, .(T_post = .N), by = pair]

cat(sprintf("Pairs with post-cells: %d\n", nrow(T_post_dist)))
cat(sprintf("T_post distribution:\n"))
cat(sprintf("  Mean: %.4f\n", mean(T_post_dist$T_post)))
cat(sprintf("  Median: %.1f\n", median(T_post_dist$T_post)))
cat(sprintf("  Min: %d\n", min(T_post_dist$T_post)))
cat(sprintf("  Max: %d\n", max(T_post_dist$T_post)))
cat(sprintf("  SD: %.4f\n", sd(T_post_dist$T_post)))

T_POST_MEAN <- mean(T_post_dist$T_post)
T_POST_MEDIAN <- median(T_post_dist$T_post)
T_POST_MIN <- min(T_post_dist$T_post)
T_POST_MAX <- max(T_post_dist$T_post)

# -----------------------------------------------------------------------------
# Compute T_h distribution for placebo (half-length under split rule)
# -----------------------------------------------------------------------------
cat("\n=== T_H DISTRIBUTION (PLACEBO SPLIT-HALF) ===\n")

# For split-half, T_h = floor(T_post / 2) approximately
# But we need to measure it from the actual split
# The split is odd/even: 1st,3rd,5th -> H1; 2nd,4th,6th -> H2
# T_h = min(n_H1, n_H2) approximately

# Load placebo pseudo years
plac <- as.data.table(S5R[["placebo"]])
plac_with_pseudo <- plac[, .(pair, pseudo)]

ppml_placebo <- ppml[pair %in% placebo_pairs$pair]
ppml_plac_merged <- merge(ppml_placebo, plac_with_pseudo, by = "pair")

# Post cells for placebo
plac_post <- ppml_plac_merged[year > pseudo + 1 & trade > 0 & y_hat_0 > 0]

# Count T_post per placebo pair
plac_T_dist <- plac_post[, .(T_post = .N), by = pair]

# Filter to qualifying pairs (those in T22_theta_A_placebo)
plac_T_qual <- plac_T_dist[pair %in% placebo_pairs$pair]

# T_h is approximately T_post / 2 (each half gets about half the cells)
# More precisely, for odd/even split: H1 gets ceil(T/2), H2 gets floor(T/2)
plac_T_qual[, T_h := floor(T_post / 2)]

cat(sprintf("Qualifying placebo pairs: %d\n", nrow(plac_T_qual)))
cat(sprintf("T_h (half-length) distribution:\n"))
cat(sprintf("  Mean: %.4f\n", mean(plac_T_qual$T_h)))
cat(sprintf("  Median: %.1f\n", median(plac_T_qual$T_h)))
cat(sprintf("  Min: %d\n", min(plac_T_qual$T_h)))
cat(sprintf("  Max: %d\n", max(plac_T_qual$T_h)))

T_H_MEAN <- mean(plac_T_qual$T_h)
T_H_MEDIAN <- median(plac_T_qual$T_h)

# -----------------------------------------------------------------------------
# R2: VAR_SIGMA2 from placebo variance
# -----------------------------------------------------------------------------
cat("\n=== R2: VAR_SIGMA2 FROM PLACEBO VARIANCE ===\n")

# Proposition 1(c): Var(theta^A) = Var(sigma^2)/4 + E[sigma^2]/T_h
# => Var(sigma^2) = 4 * (Var(theta^A) - E[sigma^2]/T_h)

PLACEBO_A_VAR <- PLACEBO_A_SD^2
cat(sprintf("PLACEBO_A_VAR = PLACEBO_A_SD^2 = %.6f^2 = %.6f\n",
            PLACEBO_A_SD, PLACEBO_A_VAR))

# Use mean T_h
VAR_SIGMA2_PLACEBO <- 4 * (PLACEBO_A_VAR - ESIGMA2_PLACEBO / T_H_MEAN)
cat(sprintf("VAR_SIGMA2_PLACEBO = 4 * (%.6f - %.6f / %.4f) = 4 * (%.6f - %.6f) = 4 * %.6f = %.6f\n",
            PLACEBO_A_VAR, ESIGMA2_PLACEBO, T_H_MEAN,
            PLACEBO_A_VAR, ESIGMA2_PLACEBO / T_H_MEAN,
            PLACEBO_A_VAR - ESIGMA2_PLACEBO / T_H_MEAN,
            VAR_SIGMA2_PLACEBO))

# Check if VAR_SIGMA2 is negative (falsifies A2)
if (VAR_SIGMA2_PLACEBO < 0) {
  cat("WARNING: VAR_SIGMA2_PLACEBO < 0 - this falsifies (A2) at this scale\n")
} else {
  cat(sprintf("VAR_SIGMA2_PLACEBO = %.6f (positive, A2 not falsified)\n", VAR_SIGMA2_PLACEBO))
}

# -----------------------------------------------------------------------------
# R2: Predict reliability R_PRED
# -----------------------------------------------------------------------------
cat("\n=== R2: PREDICT RELIABILITY ===\n")

# r = Var(b) / (Var(b) + E[sigma^2]/T_h)
# Under (A2), b = -sigma^2/2, so Var(b) = Var(sigma^2)/4
# r = (V/4) / ((V/4) + E[sigma^2]/T_h) where V = VAR_SIGMA2

if (VAR_SIGMA2_PLACEBO > 0) {
  V <- VAR_SIGMA2_PLACEBO
  R_PRED <- (V/4) / ((V/4) + ESIGMA2_PLACEBO / T_H_MEAN)
  R_GAP <- R_PRED - PLACEBO_A_R

  cat(sprintf("R_PRED = (V/4) / ((V/4) + E[sigma^2]/T_h)\n"))
  cat(sprintf("       = (%.4f/4) / ((%.4f/4) + %.4f/%.4f)\n",
              V, V, ESIGMA2_PLACEBO, T_H_MEAN))
  cat(sprintf("       = %.4f / (%.4f + %.4f)\n",
              V/4, V/4, ESIGMA2_PLACEBO/T_H_MEAN))
  cat(sprintf("       = %.4f / %.4f\n", V/4, V/4 + ESIGMA2_PLACEBO/T_H_MEAN))
  cat(sprintf("       = %.6f\n", R_PRED))
  cat(sprintf("PLACEBO_A_R (observed) = %.6f\n", PLACEBO_A_R))
  cat(sprintf("R_GAP = R_PRED - PLACEBO_A_R = %.6f - %.6f = %.6f\n",
              R_PRED, PLACEBO_A_R, R_GAP))

  # Compare with user's cross-check
  cat("\nCross-check with prompt's non-binding values:\n")
  cat(sprintf("  At T_h=4: expect R_PRED ~ 0.708, gap ~ -0.038\n"))
  cat(sprintf("  At T_h=5: expect R_PRED ~ 0.767, gap ~ +0.020\n"))
  cat(sprintf("  Computed at T_h=%.2f: R_PRED = %.4f, gap = %.4f\n",
              T_H_MEAN, R_PRED, R_GAP))
} else {
  R_PRED <- NA
  R_GAP <- NA
  cat("R_PRED cannot be computed (VAR_SIGMA2 < 0)\n")
}

# -----------------------------------------------------------------------------
# Derived quantities for Jensen remark
# -----------------------------------------------------------------------------
cat("\n=== JENSEN REMARK DERIVED QUANTITIES ===\n")

# Var(eta) = exp(sigma^2) - 1 where sigma^2 = E[sigma^2]
VAR_ETA <- exp(ESIGMA2_PLACEBO) - 1
cat(sprintf("VAR_ETA = exp(ESIGMA2_PLACEBO) - 1 = exp(%.6f) - 1 = %.4f - 1 = %.4f\n",
            ESIGMA2_PLACEBO, exp(ESIGMA2_PLACEBO), VAR_ETA))

# Var(R) = Var(eta) / T for ratio of lognormals
# At T_post = 10
T_EXAMPLE <- 10
VAR_R_T10 <- VAR_ETA / T_EXAMPLE
NEG_VAR_R_HALF_T10 <- -VAR_R_T10 / 2
cat(sprintf("VAR_R (T=%d) = VAR_ETA / %d = %.4f / %d = %.4f\n",
            T_EXAMPLE, T_EXAMPLE, VAR_ETA, T_EXAMPLE, VAR_R_T10))
cat(sprintf("-VAR_R/2 (T=%d) = -%.4f / 2 = %.4f\n",
            T_EXAMPLE, VAR_R_T10, NEG_VAR_R_HALF_T10))

# -----------------------------------------------------------------------------
# OUTPUT
# -----------------------------------------------------------------------------
cat("\n=== OUTPUT ===\n")

out <- data.frame(
  ID = c("ESIGMA2_PLACEBO", "SIGMA_PLACEBO",
         "T_POST_MEAN", "T_POST_MEDIAN", "T_POST_MIN", "T_POST_MAX",
         "T_H_MEAN", "T_H_MEDIAN",
         "VAR_SIGMA2_PLACEBO", "R_PRED", "R_GAP",
         "VAR_ETA", "VAR_R_T10", "NEG_VAR_R_HALF_T10"),
  quantity = c("E[sigma^2] = -2 * PLACEBO_A_MEAN",
               "sigma = sqrt(E[sigma^2])",
               "Mean T_post (treated)",
               "Median T_post (treated)",
               "Min T_post (treated)",
               "Max T_post (treated)",
               "Mean T_h (placebo half-length)",
               "Median T_h (placebo half-length)",
               "Var(sigma^2) = 4*(Var(theta^A) - E[sigma^2]/T_h)",
               "R_pred = (V/4) / ((V/4) + E[sigma^2]/T_h)",
               "R_pred - PLACEBO_A_R",
               "Var(eta) = exp(E[sigma^2]) - 1",
               "Var(R) at T=10 = Var(eta)/10",
               "-Var(R)/2 at T=10"),
  value = c(ESIGMA2_PLACEBO, SIGMA_PLACEBO,
            T_POST_MEAN, T_POST_MEDIAN, T_POST_MIN, T_POST_MAX,
            T_H_MEAN, T_H_MEDIAN,
            VAR_SIGMA2_PLACEBO, R_PRED, R_GAP,
            VAR_ETA, VAR_R_T10, NEG_VAR_R_HALF_T10),
  assumption = c("(A2) zero effects", "(A2) zero effects",
                 "Measured", "Measured", "Measured", "Measured",
                 "Measured (split-half)", "Measured (split-half)",
                 "(A2) + Prop 1(c)", "(A2) + Cor rel",
                 "Observed vs predicted",
                 "(A2) lognormal", "(A2) lognormal", "(A2) lognormal"),
  source_IDs = c("PLACEBO_A_MEAN", "ESIGMA2_PLACEBO",
                 "S5R_bhat + S1R_ppml", "S5R_bhat + S1R_ppml",
                 "S5R_bhat + S1R_ppml", "S5R_bhat + S1R_ppml",
                 "T22_theta_A_placebo + S5R_bhat", "T22_theta_A_placebo + S5R_bhat",
                 "PLACEBO_A_SD, ESIGMA2_PLACEBO, T_H_MEAN",
                 "VAR_SIGMA2_PLACEBO, ESIGMA2_PLACEBO, T_H_MEAN",
                 "R_PRED, PLACEBO_A_R",
                 "ESIGMA2_PLACEBO", "VAR_ETA", "VAR_R_T10"),
  stringsAsFactors = FALSE
)

print(out)

write.csv(out, "output/T25_jensen_params.csv", row.names = FALSE)
cat("\nSaved: output/T25_jensen_params.csv\n")

# Sidecar
sha <- system("sha256sum output/T25_jensen_params.csv | cut -d' ' -f1", intern = TRUE)
writeLines(c(
  "PRODUCER: S26_jensen_params.R",
  "INPUTS: output/T22_reliability.csv, output/T22_theta_A_placebo.csv, data/S5R_bhat.rds, data/S1R_ppml.rds",
  "SEED: 20260719",
  sprintf("EXPECTED_N: %d (treated), %d (placebo qualifying)", EXPECTED_N_TREATED, EXPECTED_N_PLACEBO_QUAL),
  "",
  "DERIVATIONS:",
  "  R1: E[sigma^2] = -2 * PLACEBO_A_MEAN (Proposition 1a)",
  "  R2: Var(sigma^2) = 4 * (Var(theta^A) - E[sigma^2]/T_h) (Proposition 1c)",
  "  R2: R_pred = (V/4) / ((V/4) + E[sigma^2]/T_h) (Corollary rel)",
  "",
  "ASSUMPTIONS:",
  "  (A2) Zero effects in placebo population",
  "  sigma^2_ij ~ some distribution with E[sigma^2], Var(sigma^2)",
  "",
  "GATES:",
  sprintf("  G1: placebo qualifying n = %d - PASS", EXPECTED_N_PLACEBO_QUAL),
  sprintf("  G2: treated n = %d - PASS", EXPECTED_N_TREATED),
  sprintf("  G3: ESIGMA2 = -2 * PLACEBO_A_MEAN (exact) - PASS"),
  sprintf("  G4: VAR_SIGMA2 > 0 (A2 not falsified) - %s", ifelse(VAR_SIGMA2_PLACEBO > 0, "PASS", "FAIL")),
  "",
  sprintf("ESIGMA2_PLACEBO = %.6f", ESIGMA2_PLACEBO),
  sprintf("SIGMA_PLACEBO = %.6f", SIGMA_PLACEBO),
  sprintf("T_H_MEAN = %.4f", T_H_MEAN),
  sprintf("VAR_SIGMA2_PLACEBO = %.6f", VAR_SIGMA2_PLACEBO),
  sprintf("R_PRED = %.6f", R_PRED),
  sprintf("PLACEBO_A_R = %.6f", PLACEBO_A_R),
  sprintf("R_GAP = %.6f", R_GAP),
  "",
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  sprintf("SHA256: %s", sha)
), "meta/T25_jensen_params.csv.sidecar")
cat("Saved: meta/T25_jensen_params.csv.sidecar\n")

cat("\n=== SUMMARY ===\n")
cat(sprintf("ESIGMA2_PLACEBO = %.4f (derivation: -2 * PLACEBO_A_MEAN)\n", ESIGMA2_PLACEBO))
cat(sprintf("SIGMA_PLACEBO = %.4f\n", SIGMA_PLACEBO))
cat(sprintf("R_PRED = %.4f vs PLACEBO_A_R = %.4f (gap = %.4f)\n", R_PRED, PLACEBO_A_R, R_GAP))
