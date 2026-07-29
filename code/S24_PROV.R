#!/usr/bin/env Rscript
# =============================================================================
# S24_PROV.R - Regenerate per-pair theta_A artifacts with qualifies column
# =============================================================================
# OUTPUTS (in SCRATCH_DIR):
#   T22_theta_A_treated.csv, T22_theta_A_placebo.csv, T22_reliability.csv,
#   T22_theta_A_treated.csv.sidecar, T22_theta_A_placebo.csv.sidecar
# INPUTS: data/S5R_bhat.rds, data/S1R_ppml.rds
# SEED: 20260719
# =============================================================================

# Login node guard
stopifnot(!grepl("login", Sys.info()[["nodename"]]))

cat("=============================================================================\n")
cat("S24_PROV.R - Regenerate per-pair theta_A artifacts\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat(sprintf("Node: %s\n", Sys.info()[["nodename"]]))
cat("=============================================================================\n\n")

suppressPackageStartupMessages(library(data.table))
set.seed(20260719)

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
SCRATCH_DIR <- "/scratch/bt307958/S24_PROV"

get_sha256 <- function(p) {
  strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
}

# =============================================================================
# VERIFY INPUT SHA256
# =============================================================================
cat("=== VERIFYING INPUT SHA256 ===\n")

sha_S24 <- get_sha256(file.path(REBUILD_DIR, "code/S24_reliability.R"))
sha_S5R <- get_sha256(file.path(REBUILD_DIR, "data/S5R_bhat.rds"))
sha_S1R <- get_sha256(file.path(REBUILD_DIR, "data/S1R_ppml.rds"))
sha_T22 <- get_sha256(file.path(REBUILD_DIR, "output/T22_reliability.csv"))
sha_T23 <- get_sha256(file.path(REBUILD_DIR, "output/T23_anchor.csv"))

expected <- list(
  S24 = "fa1499c9bf15f68df2c3fca1dfded9e85b8210033a4982dc5849caa422c1a372",
  S5R = "d46910ef55f0a22018baf8bd218dac5548bde98150d798ad85aa1914af8d12d8",
  S1R = "45c937cd78805d7b13b4c43f4bc4888e93a2ff15e787ad4fb41d77b51f837d89",
  T22 = "7fbd8fdcdec11ffdbf1ffa960f32a0f1d7f62430f425efca3f9102f492acc3ab",
  T23 = "1377515bbf7d42bbf933b0ef4a54ff976763b62b0946136df693f99dc29491db"
)

cat(sprintf("S24_reliability.R: %s %s\n", sha_S24, ifelse(sha_S24 == expected$S24, "MATCH", "HALT")))
cat(sprintf("S5R_bhat.rds:      %s %s\n", sha_S5R, ifelse(sha_S5R == expected$S5R, "MATCH", "HALT")))
cat(sprintf("S1R_ppml.rds:      %s %s\n", sha_S1R, ifelse(sha_S1R == expected$S1R, "MATCH", "HALT")))
cat(sprintf("T22_reliability.csv: %s %s\n", sha_T22, ifelse(sha_T22 == expected$T22, "MATCH", "HALT")))
cat(sprintf("T23_anchor.csv:    %s %s\n", sha_T23, ifelse(sha_T23 == expected$T23, "MATCH", "HALT")))

stopifnot(sha_S24 == expected$S24)
stopifnot(sha_S5R == expected$S5R)
stopifnot(sha_S1R == expected$S1R)
stopifnot(sha_T22 == expected$T22)
stopifnot(sha_T23 == expected$T23)
cat("All input SHA256 verified: PASS\n\n")

# =============================================================================
# LOAD DATA
# =============================================================================
cat("=== LOADING DATA ===\n")

S5R <- readRDS(file.path(REBUILD_DIR, "data/S5R_bhat.rds"))
base <- as.data.table(S5R[["baseline"]])
plac <- as.data.table(S5R[["placebo"]])
ppml <- readRDS(file.path(REBUILD_DIR, "data/S1R_ppml.rds"))
setDT(ppml)

cat(sprintf("Baseline pairs: %d\n", nrow(base)))
cat(sprintf("Placebo pairs: %d\n", nrow(plac)))
cat(sprintf("PPML rows: %d\n", nrow(ppml)))

# =============================================================================
# FUNCTION: Compute theta_A for ALL pairs (with qualifies flag)
# =============================================================================
compute_theta_A_all <- function(pairs_dt, ppml_dt, adoption_col = "adoption_year") {
  pair_list <- pairs_dt$pair
  adoption_years <- setNames(pairs_dt[[adoption_col]], pairs_dt$pair)
  
  results <- list()
  
  for (p in pair_list) {
    adopt_yr <- adoption_years[p]
    
    # Get post cells: year > adoption_year + 1 AND trade > 0 AND y_hat_0 > 0
    ppml_pair <- ppml_dt[pair == p]
    post_cells <- ppml_pair[year > adopt_yr + 1 & trade > 0 & y_hat_0 > 0]
    
    n_post <- nrow(post_cells)
    
    if (n_post == 0) {
      # No post cells at all
      results[[as.character(p)]] <- data.table(
        pair = p,
        theta_A = NA_real_,
        n_post_cells = 0L,
        qualifies = FALSE
      )
      next
    }
    
    # Compute log gaps and theta_A (Definition A: mean of log gaps)
    post_cells[, log_gap := log(trade) - log(y_hat_0)]
    theta_A_full <- mean(post_cells$log_gap, na.rm = TRUE)
    
    # Check split-half qualification: need >= 4 cells for 2 per half
    # Order by year ascending, assign alternating halves
    setorder(post_cells, year)
    post_cells[, half := ifelse(seq_len(.N) %% 2 == 1, "H1", "H2")]
    
    n_H1 <- sum(post_cells$half == "H1")
    n_H2 <- sum(post_cells$half == "H2")
    
    qualifies <- (n_H1 >= 2 && n_H2 >= 2)
    
    results[[as.character(p)]] <- data.table(
      pair = p,
      theta_A = theta_A_full,
      n_post_cells = n_post,
      qualifies = qualifies
    )
  }
  
  rbindlist(results)
}

# =============================================================================
# COMPUTE THETA_A FOR ALL PAIRS
# =============================================================================
cat("\n=== COMPUTING THETA_A FOR ALL PAIRS ===\n")

# Treated (baseline)
cat("Computing treated...\n")
treated_all <- compute_theta_A_all(
  pairs_dt = base[, .(pair, adoption_year)],
  ppml_dt = ppml,
  adoption_col = "adoption_year"
)
cat(sprintf("Treated: %d total, %d qualifying\n", nrow(treated_all), sum(treated_all$qualifies)))

# Placebo
cat("Computing placebo...\n")
placebo_all <- compute_theta_A_all(
  pairs_dt = plac[, .(pair, adoption_year = pseudo)],
  ppml_dt = ppml,
  adoption_col = "adoption_year"
)
cat(sprintf("Placebo: %d total, %d qualifying\n", nrow(placebo_all), sum(placebo_all$qualifies)))

# =============================================================================
# REGENERATE T22_reliability.csv (for byte-identity test)
# Using the exact same logic as S24_reliability.R
# =============================================================================
cat("\n=== REGENERATING T22_reliability.csv ===\n")

# Compute split-half stats for qualifying pairs (treated)
treated_qual <- treated_all[qualifies == TRUE]
setorder(treated_qual, pair)

# Need to recompute H1/H2 means for each qualifying pair
compute_split_half_detail <- function(pair_id, ppml_dt, adopt_yr) {
  ppml_pair <- ppml_dt[pair == pair_id]
  post_cells <- ppml_pair[year > adopt_yr + 1 & trade > 0 & y_hat_0 > 0]
  setorder(post_cells, year)
  post_cells[, half := ifelse(seq_len(.N) %% 2 == 1, "H1", "H2")]
  post_cells[, log_gap := log(trade) - log(y_hat_0)]
  
  list(
    theta_A_H1 = mean(post_cells[half == "H1", log_gap], na.rm = TRUE),
    theta_A_H2 = mean(post_cells[half == "H2", log_gap], na.rm = TRUE),
    n_H1 = sum(post_cells$half == "H1"),
    n_H2 = sum(post_cells$half == "H2"),
    mean_cells_per_half = (sum(post_cells$half == "H1") + sum(post_cells$half == "H2")) / 2,
    n_post = nrow(post_cells)
  )
}

# Treated split-half
treated_adopt <- setNames(base$adoption_year, base$pair)
treated_split <- rbindlist(lapply(treated_qual$pair, function(p) {
  detail <- compute_split_half_detail(p, ppml, treated_adopt[as.character(p)])
  data.table(pair = p, theta_A_H1 = detail$theta_A_H1, theta_A_H2 = detail$theta_A_H2,
             mean_cells_per_half = detail$mean_cells_per_half, n_post = detail$n_post)
}))
treated_split <- merge(treated_split, treated_qual[, .(pair, theta_A)], by = "pair")

treated_n <- nrow(treated_split)
treated_T_h <- mean(treated_split$mean_cells_per_half, na.rm = TRUE)
treated_T_post <- mean(treated_split$n_post, na.rm = TRUE)
theta_A_mean <- mean(treated_split$theta_A, na.rm = TRUE)
theta_A_sd <- sd(treated_split$theta_A, na.rm = TRUE)
splithalf_r <- cor(treated_split$theta_A_H1, treated_split$theta_A_H2, use = "complete.obs")
spearman_brown <- (2 * splithalf_r) / (1 + splithalf_r)

cat(sprintf("Treated qualifying: n=%d, r=%.6f, T_h=%.4f\n", treated_n, splithalf_r, treated_T_h))

# Placebo split-half
placebo_qual <- placebo_all[qualifies == TRUE]
setorder(placebo_qual, pair)

placebo_adopt <- setNames(plac$pseudo, plac$pair)
placebo_split <- rbindlist(lapply(placebo_qual$pair, function(p) {
  detail <- compute_split_half_detail(p, ppml, placebo_adopt[as.character(p)])
  data.table(pair = p, theta_A_H1 = detail$theta_A_H1, theta_A_H2 = detail$theta_A_H2,
             mean_cells_per_half = detail$mean_cells_per_half, n_post = detail$n_post)
}))
placebo_split <- merge(placebo_split, placebo_qual[, .(pair, theta_A)], by = "pair")

placebo_n <- nrow(placebo_split)
placebo_T_h <- mean(placebo_split$mean_cells_per_half, na.rm = TRUE)
placebo_T_post <- mean(placebo_split$n_post, na.rm = TRUE)
placebo_mean_qual <- mean(placebo_split$theta_A, na.rm = TRUE)
placebo_sd_qual <- sd(placebo_split$theta_A, na.rm = TRUE)
placebo_r <- cor(placebo_split$theta_A_H1, placebo_split$theta_A_H2, use = "complete.obs")
placebo_sb <- (2 * placebo_r) / (1 + placebo_r)

cat(sprintf("Placebo qualifying: n=%d, r=%.6f, T_h=%.4f\n", placebo_n, placebo_r, placebo_T_h))

# Build output table (same format as S24_reliability.R)
out <- data.frame(
  ID = c("SPLITHALF_A_R", "SPLITHALF_A_RELIABILITY", "THETA_A_MEAN", "THETA_A_SD",
         "PLACEBO_A_MEAN", "PLACEBO_A_SD", "PLACEBO_A_R", "PLACEBO_A_RELIABILITY",
         "TREATED_TH", "PLACEBO_TH", "TREATED_TPOST", "PLACEBO_TPOST"),
  quantity = c("Split-half Pearson r (treated)",
               "Spearman-Brown reliability (treated)",
               "Mean theta_A (treated)",
               "SD theta_A (treated)",
               "Mean theta_A (placebo)",
               "SD theta_A (placebo)",
               "Split-half Pearson r (placebo)",
               "Spearman-Brown reliability (placebo)",
               "Mean post cells per split half (treated)",
               "Mean post cells per split half (placebo)",
               "Mean post cells per pair (treated)",
               "Mean post cells per pair (placebo)"),
  value = c(splithalf_r, spearman_brown, theta_A_mean, theta_A_sd,
            placebo_mean_qual, placebo_sd_qual, placebo_r, placebo_sb,
            treated_T_h, placebo_T_h, treated_T_post, placebo_T_post),
  n = c(treated_n, treated_n, treated_n, treated_n,
        placebo_n, placebo_n, placebo_n, placebo_n,
        treated_n, placebo_n, treated_n, placebo_n),
  definition = rep("A (mean of log gaps)", 12),
  stringsAsFactors = FALSE
)

# =============================================================================
# WRITE ALL ARTIFACTS BEFORE GATES
# =============================================================================
cat("\n=== WRITING ARTIFACTS ===\n")

# T22_theta_A_treated.csv
write.csv(treated_all, file.path(SCRATCH_DIR, "T22_theta_A_treated.csv"), row.names = FALSE)
cat(sprintf("Wrote: T22_theta_A_treated.csv (%d rows)\n", nrow(treated_all)))

# T22_theta_A_placebo.csv  
write.csv(placebo_all, file.path(SCRATCH_DIR, "T22_theta_A_placebo.csv"), row.names = FALSE)
cat(sprintf("Wrote: T22_theta_A_placebo.csv (%d rows)\n", nrow(placebo_all)))

# T22_reliability.csv
write.csv(out, file.path(SCRATCH_DIR, "T22_reliability.csv"), row.names = FALSE)
cat(sprintf("Wrote: T22_reliability.csv (%d rows)\n", nrow(out)))

# Sidecars
sha_treated <- get_sha256(file.path(SCRATCH_DIR, "T22_theta_A_treated.csv"))
sha_placebo <- get_sha256(file.path(SCRATCH_DIR, "T22_theta_A_placebo.csv"))
sha_regen <- get_sha256(file.path(SCRATCH_DIR, "T22_reliability.csv"))

writeLines(c(
  "FILE:      T22_theta_A_treated.csv",
  sprintf("SHA256:    %s", sha_treated),
  "PRODUCER:  S24_PROV.R (provenance verification)",
  "INPUTS:",
  sprintf("  data/S5R_bhat.rds: %s", sha_S5R),
  sprintf("  data/S1R_ppml.rds: %s", sha_S1R),
  "SEED:      20260719",
  "",
  "DEFINITION: A (mean of log gaps)",
  "  theta_A = mean over post cells of [log(trade) - log(y_hat_0)]",
  "",
  "COLUMNS:",
  "  pair:         Pair identifier",
  "  theta_A:      Definition A effect estimate (NA if no post cells)",
  "  n_post_cells: Number of qualifying post cells",
  "  qualifies:    TRUE if >= 2 cells in each split half",
  "",
  sprintf("TOTAL_PAIRS: %d", nrow(treated_all)),
  sprintf("QUALIFYING:  %d", sum(treated_all$qualifies)),
  "",
  sprintf("CREATED: %s", format(Sys.time()))
), file.path(SCRATCH_DIR, "T22_theta_A_treated.csv.sidecar"))
cat("Wrote: T22_theta_A_treated.csv.sidecar\n")

writeLines(c(
  "FILE:      T22_theta_A_placebo.csv",
  sprintf("SHA256:    %s", sha_placebo),
  "PRODUCER:  S24_PROV.R (provenance verification)",
  "INPUTS:",
  sprintf("  data/S5R_bhat.rds: %s", sha_S5R),
  sprintf("  data/S1R_ppml.rds: %s", sha_S1R),
  "SEED:      20260719",
  "",
  "DEFINITION: A (mean of log gaps)",
  "  theta_A = mean over post cells of [log(trade) - log(y_hat_0)]",
  "",
  "COLUMNS:",
  "  pair:         Pair identifier",
  "  theta_A:      Definition A effect estimate (NA if no post cells)",
  "  n_post_cells: Number of qualifying post cells", 
  "  qualifies:    TRUE if >= 2 cells in each split half",
  "",
  sprintf("TOTAL_PAIRS: %d", nrow(placebo_all)),
  sprintf("QUALIFYING:  %d", sum(placebo_all$qualifies)),
  "",
  "NESTING VERIFICATION:",
  sprintf("  Full population mean (n=%d):     %.15f", nrow(placebo_all), mean(placebo_all$theta_A, na.rm = TRUE)),
  sprintf("  Qualifying subset mean (n=%d): %.15f", sum(placebo_all$qualifies), placebo_mean_qual),
  "  T23 uses full population; T22 uses qualifying subset.",
  "",
  sprintf("CREATED: %s", format(Sys.time()))
), file.path(SCRATCH_DIR, "T22_theta_A_placebo.csv.sidecar"))
cat("Wrote: T22_theta_A_placebo.csv.sidecar\n")

# =============================================================================
# GATES
# =============================================================================
cat("\n=== RUNNING GATES ===\n")

# G1: nrow(T22_theta_A_placebo) == 17200
g1_val <- nrow(placebo_all)
cat(sprintf("G1: nrow(placebo) = %d, expected 17200\n", g1_val))
stopifnot(g1_val == 17200)
cat("G1 PASS\n\n")

# G2: nrow(T22_theta_A_treated) == 4182
g2_val <- nrow(treated_all)
cat(sprintf("G2: nrow(treated) = %d, expected 4182\n", g2_val))
stopifnot(g2_val == 4182)
cat("G2 PASS\n\n")

# G3: sum(qualifies) == 15683 (placebo)
g3_val <- sum(placebo_all$qualifies)
cat(sprintf("G3: sum(placebo$qualifies) = %d, expected 15683\n", g3_val))
stopifnot(g3_val == 15683)
cat("G3 PASS\n\n")

# G4: sum(qualifies) == 4120 (treated)
g4_val <- sum(treated_all$qualifies)
cat(sprintf("G4: sum(treated$qualifies) = %d, expected 4120\n", g4_val))
stopifnot(g4_val == 4120)
cat("G4 PASS\n\n")

# G5: mean(placebo$theta_A) full population == T23 anchor
g5_val <- mean(placebo_all$theta_A, na.rm = TRUE)
g5_expected <- -0.68798424523333
g5_diff <- abs(g5_val - g5_expected)
cat(sprintf("G5: mean(placebo$theta_A) full = %.15f\n", g5_val))
cat(sprintf("    Expected (T23):              %.15f\n", g5_expected))
cat(sprintf("    Difference:                  %.15e\n", g5_diff))
stopifnot(g5_diff < 1e-9)
cat("G5 PASS\n\n")

# G6: mean(placebo$theta_A[qualifies]) == T22 anchor
g6_val <- mean(placebo_all[qualifies == TRUE, theta_A], na.rm = TRUE)
g6_expected <- -0.68210567525916
g6_diff <- abs(g6_val - g6_expected)
cat(sprintf("G6: mean(placebo$theta_A[qualifies]) = %.15f\n", g6_val))
cat(sprintf("    Expected (T22):                    %.15f\n", g6_expected))
cat(sprintf("    Difference:                        %.15e\n", g6_diff))
stopifnot(g6_diff < 1e-9)
cat("G6 PASS\n\n")

# G7: sd(placebo$theta_A) full population
g7_val <- sd(placebo_all$theta_A, na.rm = TRUE)
g7_expected <- 1.11867236852416
g7_diff <- abs(g7_val - g7_expected)
cat(sprintf("G7: sd(placebo$theta_A) = %.15f\n", g7_val))
cat(sprintf("    Expected:           %.15f\n", g7_expected))
cat(sprintf("    Difference:         %.15e\n", g7_diff))
stopifnot(g7_diff < 1e-9)
cat("G7 PASS\n\n")

# G8: byte-identical T22_reliability.csv
cat("G8: Byte-identity test for T22_reliability.csv\n")
committed_T22 <- file.path(REBUILD_DIR, "output/T22_reliability.csv")
regen_T22 <- file.path(SCRATCH_DIR, "T22_reliability.csv")
sha_committed <- get_sha256(committed_T22)
sha_regenerated <- get_sha256(regen_T22)
cat(sprintf("    Committed:   %s\n", sha_committed))
cat(sprintf("    Regenerated: %s\n", sha_regenerated))
if (sha_committed == sha_regenerated) {
  cat("G8 PASS (byte-identical)\n\n")
} else {
  cat("G8 FAIL (NOT byte-identical)\n")
  cat("Diff follows:\n")
  system2("diff", c(committed_T22, regen_T22), stdout = "", stderr = "")
  stop("G8 FAIL: T22_reliability.csv not byte-identical")
}

# =============================================================================
# OUTPUT SHA256
# =============================================================================
cat("=== OUTPUT SHA256 ===\n")
cat(sprintf("T22_theta_A_treated.csv:         %s\n", sha_treated))
cat(sprintf("T22_theta_A_placebo.csv:         %s\n", sha_placebo))
cat(sprintf("T22_reliability.csv (regen):     %s\n", sha_regen))
sha_sidecar1 <- get_sha256(file.path(SCRATCH_DIR, "T22_theta_A_treated.csv.sidecar"))
sha_sidecar2 <- get_sha256(file.path(SCRATCH_DIR, "T22_theta_A_placebo.csv.sidecar"))
cat(sprintf("T22_theta_A_treated.csv.sidecar: %s\n", sha_sidecar1))
cat(sprintf("T22_theta_A_placebo.csv.sidecar: %s\n", sha_sidecar2))

# =============================================================================
# SUMMARY
# =============================================================================
cat("\n=============================================================================\n")
cat("SUMMARY: ALL GATES PASSED\n")
cat("=============================================================================\n")
cat("G1: nrow(placebo) == 17200              PASS\n")
cat("G2: nrow(treated) == 4182               PASS\n")
cat("G3: sum(placebo$qualifies) == 15683     PASS\n")
cat("G4: sum(treated$qualifies) == 4120      PASS\n")
cat("G5: mean(placebo) full == T23 anchor    PASS\n")
cat("G6: mean(placebo) qualifying == T22     PASS\n")
cat("G7: sd(placebo) full == T23 anchor      PASS\n")
cat("G8: T22_reliability.csv byte-identical  PASS\n")
cat("=============================================================================\n")
cat("\nCONCLUSION: T23 and T22 are the SAME theta_A estimator on NESTED populations.\n")
cat("  - T23 uses full placebo population (n=17200)\n")
cat("  - T22 uses qualifying subset (n=15683, >= 2 cells per split half)\n")
cat("  - No recomputation of T23 is warranted.\n")
cat("=============================================================================\n")
cat(sprintf("Done: %s\n", format(Sys.time())))
