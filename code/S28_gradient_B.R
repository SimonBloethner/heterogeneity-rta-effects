#!/usr/bin/env Rscript
# =============================================================================
# S28_gradient_B.R - Definition B Size-Gradient Exhibit
# =============================================================================
# OUTPUTS: T27_gradient_B.csv, T27_gradient_B_spread.csv, T27_gradient_B.csv.sidecar
# INPUTS:  data/S5R_bhat.rds, output/T12_N4_gradient.csv, output/T5R_theta_summary.csv
# SEED:    NONE
# SCRATCH: /scratch/bt307958/S28_gradient_B/
# =============================================================================

# Login node guard
stopifnot(!grepl("login", Sys.info()[["nodename"]]))

cat("=============================================================================\n")
cat("S28_gradient_B.R - Definition B Size-Gradient Exhibit\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat(sprintf("Node: %s\n", Sys.info()[["nodename"]]))
cat("=============================================================================\n\n")

# Paths
REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
SCRATCH_DIR <- "/scratch/bt307958/S28_gradient_B"

# SHA256 verification function
get_sha256 <- function(p) {
  strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
}

# =============================================================================
# VERIFY INPUT SHA256
# =============================================================================
cat("=== VERIFYING INPUT SHA256 ===\n")

sha_S5R <- get_sha256(file.path(REBUILD_DIR, "data/S5R_bhat.rds"))
sha_T12 <- get_sha256(file.path(REBUILD_DIR, "output/T12_N4_gradient.csv"))
sha_T5R <- get_sha256(file.path(REBUILD_DIR, "output/T5R_theta_summary.csv"))

expected_sha_S5R <- "d46910ef55f0a22018baf8bd218dac5548bde98150d798ad85aa1914af8d12d8"
expected_sha_T12 <- "1bcf1f815ce0bf45466c0e2146ce171bda443d475c8d4cd195901a419f4b8bf8"
expected_sha_T5R <- "aed2be043386613b31f1848e4861ea3d9ea4afb687eec2247faf5feddfb92f8f"

cat(sprintf("S5R_bhat.rds:         %s\n", sha_S5R))
cat(sprintf("  Expected:           %s\n", expected_sha_S5R))
cat(sprintf("  Match: %s\n", ifelse(sha_S5R == expected_sha_S5R, "YES", "HALT")))

cat(sprintf("T12_N4_gradient.csv:  %s\n", sha_T12))
cat(sprintf("  Expected:           %s\n", expected_sha_T12))
cat(sprintf("  Match: %s\n", ifelse(sha_T12 == expected_sha_T12, "YES", "HALT")))

cat(sprintf("T5R_theta_summary.csv: %s\n", sha_T5R))
cat(sprintf("  Expected:           %s\n", expected_sha_T5R))
cat(sprintf("  Match: %s\n", ifelse(sha_T5R == expected_sha_T5R, "YES", "HALT")))

stopifnot(sha_S5R == expected_sha_S5R)
stopifnot(sha_T12 == expected_sha_T12)
stopifnot(sha_T5R == expected_sha_T5R)

cat("All input SHA256 verified: PASS\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================
cat("=== LOADING DATA ===\n")

S5R <- readRDS(file.path(REBUILD_DIR, "data/S5R_bhat.rds"))
baseline <- S5R$baseline
T12 <- read.csv(file.path(REBUILD_DIR, "output/T12_N4_gradient.csv"), stringsAsFactors = FALSE)
T5R <- read.csv(file.path(REBUILD_DIR, "output/T5R_theta_summary.csv"), stringsAsFactors = FALSE)

cat(sprintf("baseline rows: %d\n", nrow(baseline)))
cat(sprintf("T12 rows: %d\n", nrow(T12)))
cat(sprintf("T5R rows: %d\n", nrow(T5R)))

# =============================================================================
# G1: Population size
# =============================================================================
cat("\n=== G1: POPULATION SIZE ===\n")
cat(sprintf("nrow(baseline) = %d, expected 4182\n", nrow(baseline)))
stopifnot(nrow(baseline) == 4182)
cat("G1 PASS\n")

# =============================================================================
# APPLY QUINTILE RULE (verbatim from N4_distribution.R line 136)
# =============================================================================
cat("\n=== APPLYING QUINTILE RULE ===\n")
baseline$quintile <- as.integer(cut(rank(baseline$pre_trade),
                                    breaks = 5, labels = FALSE))
cat("Applied: as.integer(cut(rank(baseline$pre_trade), breaks = 5, labels = FALSE))\n")
cat(sprintf("Quintile counts: %s\n", paste(table(baseline$quintile), collapse = ", ")))

# =============================================================================
# G2: Quintile counts
# =============================================================================
cat("\n=== G2: QUINTILE COUNTS ===\n")
quintile_counts <- as.integer(table(baseline$quintile))
expected_counts <- c(837L, 836L, 836L, 836L, 837L)
cat(sprintf("Observed: %s\n", paste(quintile_counts, collapse = ", ")))
cat(sprintf("Expected: %s\n", paste(expected_counts, collapse = ", ")))
stopifnot(identical(quintile_counts, expected_counts))
cat("G2 PASS\n")

# =============================================================================
# COMPUTE PER-QUINTILE STATISTICS
# =============================================================================
cat("\n=== COMPUTING PER-QUINTILE STATISTICS ===\n")

results <- data.frame(
  quintile = 1:5,
  n = NA_integer_,
  mean_theta_B = NA_real_,
  se_mean_B = NA_real_,
  mean_theta_D = NA_real_,
  se_mean_D = NA_real_,
  mean_pre_trade = NA_real_
)

for (q in 1:5) {
  subset_q <- baseline[baseline$quintile == q, ]
  results$n[q] <- nrow(subset_q)
  results$mean_theta_B[q] <- mean(subset_q$theta_B, na.rm = TRUE)
  results$se_mean_B[q] <- sd(subset_q$theta_B, na.rm = TRUE) / sqrt(nrow(subset_q))
  results$mean_theta_D[q] <- mean(subset_q$theta_D, na.rm = TRUE)
  results$se_mean_D[q] <- sd(subset_q$theta_D, na.rm = TRUE) / sqrt(nrow(subset_q))
  results$mean_pre_trade[q] <- mean(subset_q$pre_trade, na.rm = TRUE)
}

cat("\nPer-quintile results:\n")
print(results)

# =============================================================================
# G3: mean_theta_D matches T12
# =============================================================================
cat("\n=== G3: MEAN_THETA_D MATCHES T12 ===\n")
diff_D <- max(abs(results$mean_theta_D - T12$mean_theta_D))
cat(sprintf("max|mean_theta_D - T12$mean_theta_D| = %.15e\n", diff_D))
stopifnot(diff_D < 1e-9)
cat("G3 PASS\n")

# =============================================================================
# G4: mean_theta_B matches T12
# =============================================================================
cat("\n=== G4: MEAN_THETA_B MATCHES T12 ===\n")
diff_B <- max(abs(results$mean_theta_B - T12$mean_theta_B))
cat(sprintf("max|mean_theta_B - T12$mean_theta_B| = %.15e\n", diff_B))
stopifnot(diff_B < 1e-9)
cat("G4 PASS\n")

# =============================================================================
# G5: se_mean_D matches T12$se_mean
# =============================================================================
cat("\n=== G5: SE_MEAN_D MATCHES T12 ===\n")
diff_se <- max(abs(results$se_mean_D - T12$se_mean))
cat(sprintf("max|se_mean_D - T12$se_mean| = %.15e\n", diff_se))
stopifnot(diff_se < 1e-9)
cat("G5 PASS\n")

# =============================================================================
# G6: Cross-producer anchor (T5R BASELINE Mean_theta_B)
# =============================================================================
cat("\n=== G6: CROSS-PRODUCER ANCHOR (MEAN THETA_B) ===\n")
mean_theta_B_overall <- mean(baseline$theta_B, na.rm = TRUE)
expected_mean_B <- 0.0758107555171095
diff_anchor <- abs(mean_theta_B_overall - expected_mean_B)
cat(sprintf("mean(baseline$theta_B) = %.16f\n", mean_theta_B_overall))
cat(sprintf("Expected (T5R):        = %.16f\n", expected_mean_B))
cat(sprintf("Difference:            = %.15e\n", diff_anchor))
stopifnot(diff_anchor < 1e-9)
cat("G6 PASS\n")

# =============================================================================
# COMPUTE SPREADS
# =============================================================================
cat("\n=== COMPUTING SPREADS ===\n")

# Q1 - Q5 spread
spread_B_value <- results$mean_theta_B[1] - results$mean_theta_B[5]
spread_D_value <- results$mean_theta_D[1] - results$mean_theta_D[5]

# SE: sqrt(se_Q1^2 + se_Q5^2)
spread_B_se <- sqrt(results$se_mean_B[1]^2 + results$se_mean_B[5]^2)
spread_D_se <- sqrt(results$se_mean_D[1]^2 + results$se_mean_D[5]^2)

# Share
share_B_of_D <- spread_B_value / spread_D_value

cat(sprintf("spread_B (Q1-Q5): %.16f (SE: %.16f)\n", spread_B_value, spread_B_se))
cat(sprintf("spread_D (Q1-Q5): %.16f (SE: %.16f)\n", spread_D_value, spread_D_se))
cat(sprintf("share (B/D):      %.16f\n", share_B_of_D))

# =============================================================================
# G7: spread_D_se matches T10R anchor
# =============================================================================
cat("\n=== G7: SPREAD_D_SE MATCHES T10R ANCHOR ===\n")
expected_spread_D_se <- 0.0808586479445326
diff_spread_se <- abs(spread_D_se - expected_spread_D_se)
cat(sprintf("spread_D_se:  %.16f\n", spread_D_se))
cat(sprintf("Expected:     %.16f\n", expected_spread_D_se))
cat(sprintf("Difference:   %.15e\n", diff_spread_se))
stopifnot(diff_spread_se < 1e-9)
cat("G7 PASS\n")

# =============================================================================
# G8: spread_D_value matches anchor
# =============================================================================
cat("\n=== G8: SPREAD_D_VALUE MATCHES ANCHOR ===\n")
expected_spread_D <- 0.9137352197507282
diff_spread_D <- abs(spread_D_value - expected_spread_D)
cat(sprintf("spread_D_value: %.16f\n", spread_D_value))
cat(sprintf("Expected:       %.16f\n", expected_spread_D))
cat(sprintf("Difference:     %.15e\n", diff_spread_D))
stopifnot(diff_spread_D < 1e-9)
cat("G8 PASS\n")

# =============================================================================
# G9: share_B_of_D matches anchor
# =============================================================================
cat("\n=== G9: SHARE_B_OF_D MATCHES ANCHOR ===\n")
expected_share <- 0.7471646326198405
diff_share <- abs(share_B_of_D - expected_share)
cat(sprintf("share_B_of_D: %.16f\n", share_B_of_D))
cat(sprintf("Expected:     %.16f\n", expected_share))
cat(sprintf("Difference:   %.15e\n", diff_share))
stopifnot(diff_share < 1e-9)
cat("G9 PASS\n")

# =============================================================================
# OUTPUT FILES
# =============================================================================
cat("\n=== WRITING OUTPUT FILES ===\n")

# T27_gradient_B.csv
write.csv(results, file.path(SCRATCH_DIR, "T27_gradient_B.csv"), row.names = FALSE)
cat(sprintf("Wrote: %s/T27_gradient_B.csv\n", SCRATCH_DIR))

# T27_gradient_B_spread.csv
spread_df <- data.frame(
  quantity = c("spread_B_Q1_Q5", "spread_D_Q1_Q5", "share_B_of_D"),
  value = c(spread_B_value, spread_D_value, share_B_of_D),
  se = c(spread_B_se, spread_D_se, NA)
)
write.csv(spread_df, file.path(SCRATCH_DIR, "T27_gradient_B_spread.csv"), row.names = FALSE)
cat(sprintf("Wrote: %s/T27_gradient_B_spread.csv\n", SCRATCH_DIR))

# T27_gradient_B.csv.sidecar
sha_T27 <- get_sha256(file.path(SCRATCH_DIR, "T27_gradient_B.csv"))
sha_T27_spread <- get_sha256(file.path(SCRATCH_DIR, "T27_gradient_B_spread.csv"))

sidecar_lines <- c(
  "FILE:      T27_gradient_B.csv",
  sprintf("SHA256:    %s", sha_T27),
  "PRODUCER:  S28_gradient_B.R",
  "INPUTS:",
  sprintf("  data/S5R_bhat.rds:           %s", sha_S5R),
  sprintf("  output/T12_N4_gradient.csv:  %s", sha_T12),
  sprintf("  output/T5R_theta_summary.csv: %s", sha_T5R),
  "SEED:      NONE",
  "",
  "GATES:",
  sprintf("  G1: nrow(baseline) == 4182                           -> %d == 4182: PASS", nrow(baseline)),
  sprintf("  G2: quintile counts == (837,836,836,836,837)          -> (%s): PASS", paste(quintile_counts, collapse=",")),
  sprintf("  G3: max|mean_theta_D - T12| < 1e-9                    -> %.2e: PASS", diff_D),
  sprintf("  G4: max|mean_theta_B - T12| < 1e-9                    -> %.2e: PASS", diff_B),
  sprintf("  G5: max|se_mean_D - T12$se_mean| < 1e-9               -> %.2e: PASS", diff_se),
  sprintf("  G6: |mean(theta_B) - 0.0758107555171095| < 1e-9       -> %.2e: PASS", diff_anchor),
  sprintf("  G7: |spread_D_se - 0.0808586479445326| < 1e-9         -> %.2e: PASS", diff_spread_se),
  sprintf("  G8: |spread_D_value - 0.9137352197507282| < 1e-9      -> %.2e: PASS", diff_spread_D),
  sprintf("  G9: |share_B_of_D - 0.7471646326198405| < 1e-9        -> %.2e: PASS", diff_share),
  "",
  "SPREAD:",
  sprintf("  spread_B_Q1_Q5: %.16f (SE: %.16f)", spread_B_value, spread_B_se),
  sprintf("  spread_D_Q1_Q5: %.16f (SE: %.16f)", spread_D_value, spread_D_se),
  sprintf("  share_B_of_D:   %.16f (SE: NA)", share_B_of_D),
  "",
  "NOTE (share SE):",
  "  Ratio of two spreads; no SE reported - the sampling distribution of the",
  "  ratio is not established by this task.",
  "",
  sprintf("T27_gradient_B_spread.csv SHA256: %s", sha_T27_spread),
  "",
  sprintf("CREATED: %s", format(Sys.time()))
)

writeLines(sidecar_lines, file.path(SCRATCH_DIR, "T27_gradient_B.csv.sidecar"))
cat(sprintf("Wrote: %s/T27_gradient_B.csv.sidecar\n", SCRATCH_DIR))

# =============================================================================
# FINAL OUTPUT SHA256
# =============================================================================
cat("\n=== OUTPUT SHA256 ===\n")
cat(sprintf("T27_gradient_B.csv:        %s\n", sha_T27))
cat(sprintf("T27_gradient_B_spread.csv: %s\n", sha_T27_spread))
sha_sidecar <- get_sha256(file.path(SCRATCH_DIR, "T27_gradient_B.csv.sidecar"))
cat(sprintf("T27_gradient_B.csv.sidecar: %s\n", sha_sidecar))

# =============================================================================
# SUMMARY
# =============================================================================
cat("\n=============================================================================\n")
cat("SUMMARY: ALL GATES PASSED\n")
cat("=============================================================================\n")
cat("G1: nrow(baseline) == 4182                 PASS\n")
cat("G2: quintile counts exact                  PASS\n")
cat("G3: mean_theta_D matches T12               PASS\n")
cat("G4: mean_theta_B matches T12               PASS\n")
cat("G5: se_mean_D matches T12$se_mean          PASS\n")
cat("G6: mean(theta_B) cross-producer anchor    PASS\n")
cat("G7: spread_D_se matches T10R anchor        PASS\n")
cat("G8: spread_D_value matches anchor          PASS\n")
cat("G9: share_B_of_D matches anchor            PASS\n")
cat("=============================================================================\n")
cat(sprintf("Done: %s\n", format(Sys.time())))
