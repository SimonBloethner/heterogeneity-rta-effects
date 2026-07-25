# S10_exhibits.R: Generate Exhibit Tables
# OUTPUTS: output/T1-T5 CSV files
# INPUTS: data/S5_bhat.rds, S7_deconv.rds, S8_ge.rds, S9_spec.rds

cat("========================================================================\n")
cat("S10: GENERATE EXHIBIT TABLES\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat("========================================================================\n\n")

library(data.table)

BASE <- "/scratch/bt307958/REBUILD_V2"

write_exhibit <- function(df, filename, description) {
  path <- file.path(BASE, "output", filename)
  write.csv(df, path, row.names = FALSE)
  sha <- strsplit(system(sprintf("sha256sum %s", path), intern = TRUE), " ")[[1]][1]
  cat(sprintf("  %s: %s\n", filename, sha))
  
  # Write sidecar
  sidecar <- sprintf("file: %s\nsha256: %s\ncreated: %s\nscript: S10_exhibits.R\ndescription: %s\n",
                     filename, sha, format(Sys.time()), description)
  writeLines(sidecar, file.path(BASE, "meta", paste0(filename, ".sidecar")))
}

# ============================================================================
# T1: SPECIFICATION SPREAD
# ============================================================================
cat("=== T1: Specification Spread ===\n")

S9 <- readRDS(file.path(BASE, "data/S9_spec.rds"))
T1 <- S9$results[, c("spec", "published", "estimate", "se")]
names(T1) <- c("Specification", "Published", "REBUILD", "SE")
T1$Difference <- T1$REBUILD - T1$Published

write_exhibit(T1, "T1_spec_spread.csv", "Four-specification RTA coefficient comparison")

# ============================================================================
# T2: VARIANCE DECOMPOSITION
# ============================================================================
cat("\n=== T2: Variance Decomposition ===\n")

S7 <- readRDS(file.path(BASE, "data/S7_deconv.rds"))

T2 <- data.frame(
  Population = c("Full (all switchers)", "BASELINE (filtered)"),
  N = c(S7$var_decomp_full$n, S7$var_decomp_baseline$n),
  Var_theta_hat = c(S7$var_decomp_full$var_theta_hat, S7$var_decomp_baseline$var_theta_hat),
  Mean_SE_sq = c(S7$var_decomp_full$mean_se_sq, S7$var_decomp_baseline$mean_se_sq),
  Var_theta = c(S7$var_decomp_full$var_theta, S7$var_decomp_baseline$var_theta),
  SD_theta = c(S7$var_decomp_full$sd_theta, S7$var_decomp_baseline$sd_theta),
  Reliability = c(S7$var_decomp_full$reliability, S7$var_decomp_baseline$reliability)
)

write_exhibit(T2, "T2_variance_decomposition.csv", "Variance decomposition: Var(theta) = Var(theta_hat) - E[se^2]")

# ============================================================================
# T3: SIZE GRADIENT BY QUINTILE
# ============================================================================
cat("\n=== T3: Size Gradient ===\n")

T3 <- as.data.frame(S7$quintile_gradient)
names(T3) <- c("Quintile", "N", "Mean_theta_D", "SD_theta_D")

write_exhibit(T3, "T3_size_gradient.csv", "Mean theta_D by pre-adoption trade quintile (BASELINE)")

# ============================================================================
# T3b: COHORT TABLE
# ============================================================================
cat("\n=== T3b: Cohort Table ===\n")

T3b <- as.data.frame(S7$cohort_stats)
names(T3b) <- c("Cohort", "N", "Mean_theta_D", "SD_theta_D")

# Add year bins
year_bins <- as.data.frame(S7$year_bin_stats)
names(year_bins) <- c("Year_Bin", "N", "Mean_theta_D")
year_bins$SD_theta_D <- NA
year_bins$Cohort <- as.character(year_bins$Year_Bin)
year_bins <- year_bins[, c("Cohort", "N", "Mean_theta_D", "SD_theta_D")]

T3b_full <- rbind(T3b, year_bins)

write_exhibit(T3b_full, "T3b_cohort_table.csv", "Cohort analysis: early vs late adopters, by 5-year bins")

# ============================================================================
# T4: GE PROPAGATION
# ============================================================================
cat("\n=== T4: GE Propagation ===\n")

S8 <- readRDS(file.path(BASE, "data/S8_ge.rds"))

T4 <- data.frame(
  Quantity = c("Dyad", "Sigma", "N_draws", "N_valid",
               "q10", "q25", "q50", "q75", "q90",
               "Range_1090", "Range_1090_normal"),
  Value = c(
    paste(S8$dyad, collapse = "-"),
    S8$sigma,
    S8$n_draws,
    S8$n_valid,
    sprintf("%.4f", S8$quantiles["q10"]),
    sprintf("%.4f", S8$quantiles["q25"]),
    sprintf("%.4f", S8$quantiles["q50"]),
    sprintf("%.4f", S8$quantiles["q75"]),
    sprintf("%.4f", S8$quantiles["q90"]),
    sprintf("%.4f", S8$range_1090),
    sprintf("%.4f", S8$range_normal)
  ),
  Canonical = c(
    "MED dyad", "5", "500", "500",
    "+0.1115", NA, "+0.2208", NA, "+0.5104",
    "1.3589", "2.2488"
  )
)

write_exhibit(T4, "T4_ge_propagation.csv", "GE trade cost change quantiles (sigma=5)")

# ============================================================================
# T5: THETA SUMMARY
# ============================================================================
cat("\n=== T5: Theta Summary ===\n")

S5 <- readRDS(file.path(BASE, "data/S5_bhat.rds"))
theta_dt <- S5$theta_d
theta_dt[, baseline := (adoption_year >= 1991 & adoption_year <= 2016 & n_pre >= 3 & n_post >= 3)]

full_stats <- theta_dt[, .(
  N = .N,
  Mean_theta_A = mean(theta_A, na.rm = TRUE),
  SD_theta_A = sd(theta_A, na.rm = TRUE),
  Mean_theta_B = mean(theta_B, na.rm = TRUE),
  SD_theta_B = sd(theta_B, na.rm = TRUE),
  Mean_theta_D = mean(theta_D, na.rm = TRUE),
  SD_theta_D = sd(theta_D, na.rm = TRUE)
)]
full_stats$Population <- "Full"

baseline_stats <- theta_dt[baseline == TRUE, .(
  N = .N,
  Mean_theta_A = mean(theta_A, na.rm = TRUE),
  SD_theta_A = sd(theta_A, na.rm = TRUE),
  Mean_theta_B = mean(theta_B, na.rm = TRUE),
  SD_theta_B = sd(theta_B, na.rm = TRUE),
  Mean_theta_D = mean(theta_D, na.rm = TRUE),
  SD_theta_D = sd(theta_D, na.rm = TRUE)
)]
baseline_stats$Population <- "BASELINE"

T5 <- rbind(
  data.frame(Population = "Full", as.list(full_stats[, -"Population", with = FALSE])),
  data.frame(Population = "BASELINE", as.list(baseline_stats[, -"Population", with = FALSE]))
)

# Add quantiles for theta_D
T5$theta_D_q10 <- c(
  quantile(theta_dt$theta_D, 0.10, na.rm = TRUE),
  quantile(theta_dt[baseline == TRUE]$theta_D, 0.10, na.rm = TRUE)
)
T5$theta_D_q90 <- c(
  quantile(theta_dt$theta_D, 0.90, na.rm = TRUE),
  quantile(theta_dt[baseline == TRUE]$theta_D, 0.90, na.rm = TRUE)
)

write_exhibit(T5, "T5_theta_summary.csv", "Theta distribution summary statistics")

# ============================================================================
# SUMMARY
# ============================================================================
cat("\n========================================================================\n")
cat("EXHIBITS GENERATED:\n")
cat("========================================================================\n")
cat("  T1_spec_spread.csv         - Specification spread (B, C, CY, FULL)\n")
cat("  T2_variance_decomposition.csv - Var(theta) decomposition\n")
cat("  T3_size_gradient.csv       - Size gradient by quintile\n")
cat("  T3b_cohort_table.csv       - Cohort analysis\n")
cat("  T4_ge_propagation.csv      - GE quantiles\n")
cat("  T5_theta_summary.csv       - Theta summary stats\n")

cat(sprintf("\nS10 COMPLETE: %s\n", format(Sys.time())))
cat("========================================================================\n")
