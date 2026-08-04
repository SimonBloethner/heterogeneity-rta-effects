#!/usr/bin/env Rscript
# =============================================================================
# S10R_exhibits.R - Generate Exhibit Tables (FIXED CHAIN)
# =============================================================================
# OUTPUTS: output/T*R CSV files
# INPUTS:  data/S5R_bhat.rds, S7R_deconv.rds, S8R_ge.rds, S9R_spec.rds
# NOTE:    Uses dplyr (no data.table) for Festus compatibility.
# =============================================================================
# EXPECTED_N: 4182

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(dplyr))

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S10R: GENERATE EXHIBIT TABLES (FIXED CHAIN)")
say("Start: %s", format(Sys.time()))
say("================================================================")

write_exhibit <- function(df, filename, description) {
  path <- file.path(RTA_ROOT, "output", filename)
  write.csv(df, path, row.names = FALSE)
  sha <- get_sha256(path)
  say("  %s: %s", filename, sha)

  sidecar <- c(
    sprintf("FILE:      %s", filename),
    sprintf("SHA256:    %s", sha),
    sprintf("PRODUCER:  code/S10R_exhibits.R (SHA256: %s)", get_sha256(file.path(RTA_ROOT, "code/S10R_exhibits.R"))),
    sprintf("DESCRIPTION: %s", description),
    sprintf("CREATED:   %s", format(Sys.time()))
  )
  writeLines(sidecar, file.path(RTA_ROOT, "meta", paste0(filename, ".sidecar")))
}

# =============================================================================
# T1R: SPECIFICATION SPREAD
# =============================================================================
say("")
say("=== T1R: Specification Spread ===")

S9R <- readRDS(file.path(RTA_ROOT, "data/S9R_spec.rds"))
T1R <- S9R$results[, c("spec", "published", "estimate", "se")]
names(T1R) <- c("Specification", "Published", "REBUILD", "SE")
T1R$Difference <- T1R$REBUILD - T1R$Published

write_exhibit(T1R, "T1R_spec_spread.csv", "Four-specification RTA coefficient comparison (FIXED CHAIN)")

# =============================================================================
# T2R: VARIANCE DECOMPOSITION
# =============================================================================
say("")
say("=== T2R: Variance Decomposition ===")

S7R <- readRDS(file.path(RTA_ROOT, "data/S7R_deconv.rds"))

T2R <- data.frame(
  Population = "BASELINE",
  N = S7R$baseline_n,
  Var_theta_hat = S7R$var_decomp$var_theta_hat,
  Mean_SE_sq = S7R$var_decomp$mean_se_sq,
  Var_theta = S7R$var_decomp$var_theta,
  SD_theta_true = S7R$sd_theta_true,
  SE_SD_theta_true = S7R$se_sd_theta_true,
  SD_theta_D = S7R$sd_theta_D,
  SE_SD_theta_D = S7R$se_sd_theta_D
)

write_exhibit(T2R, "T2R_variance_decomposition.csv", "Variance decomposition with bootstrap SEs (FIXED CHAIN)")

# =============================================================================
# T3R: SIZE GRADIENT BY QUINTILE
# =============================================================================
say("")
say("=== T3R: Size Gradient ===")

T3R <- as.data.frame(S7R$quintile_gradient)

write_exhibit(T3R, "T3R_size_gradient.csv", "Mean theta_D by pre-adoption trade quintile (BASELINE)")

# =============================================================================
# T4R: GE PROPAGATION
# =============================================================================
say("")
say("=== T4R: GE Propagation ===")

S8R <- readRDS(file.path(RTA_ROOT, "data/S8R_ge.rds"))

T4R <- data.frame(
  Quantity = c("Dyad", "Sigma", "N_draws", "N_valid",
               "q10", "q25", "q50", "q75", "q90",
               "Range_1090", "Range_1090_normal"),
  Value = c(
    paste(S8R$dyad, collapse = "-"),
    S8R$sigma,
    S8R$n_draws,
    S8R$n_valid,
    sprintf("%.4f", S8R$quantiles["q10"]),
    sprintf("%.4f", S8R$quantiles["q25"]),
    sprintf("%.4f", S8R$quantiles["q50"]),
    sprintf("%.4f", S8R$quantiles["q75"]),
    sprintf("%.4f", S8R$quantiles["q90"]),
    sprintf("%.4f", S8R$range_1090),
    sprintf("%.4f", S8R$range_normal)
  )
)

write_exhibit(T4R, "T4R_ge_propagation.csv", "GE trade cost change quantiles sigma=5 (FIXED CHAIN)")

# =============================================================================
# T5R: THETA SUMMARY
# =============================================================================
say("")
say("=== T5R: Theta Summary ===")

S5R <- readRDS(file.path(RTA_ROOT, "data/S5R_bhat.rds"))
base <- S5R$baseline
stopifnot(nrow(base) == 4182)

T5R <- data.frame(
  Population = "BASELINE",
  N = nrow(base),
  Mean_theta_A = mean(base$theta_A, na.rm = TRUE),
  SD_theta_A = sd(base$theta_A, na.rm = TRUE),
  Mean_theta_B = mean(base$theta_B, na.rm = TRUE),
  SD_theta_B = sd(base$theta_B, na.rm = TRUE),
  Mean_theta_D = mean(base$theta_D, na.rm = TRUE),
  SD_theta_D = sd(base$theta_D, na.rm = TRUE),
  theta_D_q10 = quantile(base$theta_D, 0.10, na.rm = TRUE),
  theta_D_q50 = quantile(base$theta_D, 0.50, na.rm = TRUE),
  theta_D_q90 = quantile(base$theta_D, 0.90, na.rm = TRUE)
)

write_exhibit(T5R, "T5R_theta_summary.csv", "Theta distribution summary statistics (BASELINE)")

# =============================================================================
# T10R: RECONCILIATION TABLE (with bootstrap SEs)
# =============================================================================
say("")
say("=== T10R: Reconciliation Table ===")

# Load all R-chain outputs for reconciliation
T10R <- data.frame(
  quantity = c("N_pairs", "mean_theta_D", "SD_theta_D", "SD_theta_true",
               "TW_mean", "Q1_Q5_spread", "spec_spread_B_FULL"),
  pack = c(4182, 0.214, NA, NA, NA, 0.465, 1.307),
  fixed = c(
    S7R$baseline_n,
    S7R$mean_theta_D,
    S7R$sd_theta_D,
    S7R$sd_theta_true,
    S7R$tw_mean,
    S7R$q1_q5_spread,
    S9R$spread
  ),
  se_fixed = c(
    NA,
    S7R$se_mean_theta_D,
    S7R$se_sd_theta_D,
    S7R$se_sd_theta_true,
    S7R$se_tw_mean,
    S7R$se_q1_q5_spread,
    NA
  )
)

T10R$deviation <- T10R$fixed - T10R$pack
T10R$deviation_se <- ifelse(!is.na(T10R$se_fixed) & T10R$se_fixed > 0,
                             T10R$deviation / T10R$se_fixed, NA)

write_exhibit(T10R, "T10R_reconciliation.csv", "Reconciliation of fixed-chain vs pack (with bootstrap SEs)")

# =============================================================================
# SUMMARY
# =============================================================================
say("")
say("================================================================")
say("EXHIBITS GENERATED:")
say("================================================================")
say("  T1R_spec_spread.csv          - Specification spread (B, C, CY, FULL)")
say("  T2R_variance_decomposition.csv - Var(theta) decomposition")
say("  T3R_size_gradient.csv        - Size gradient by quintile")
say("  T4R_ge_propagation.csv       - GE quantiles")
say("  T5R_theta_summary.csv        - Theta summary stats")
say("  T10R_reconciliation.csv      - Reconciliation table")

say("")
say("Done: %s", format(Sys.time()))
