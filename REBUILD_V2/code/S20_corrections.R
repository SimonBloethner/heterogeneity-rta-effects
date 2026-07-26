#!/usr/bin/env Rscript
# =============================================================================
# S20_corrections.R - C1-C4 Corrections and INV-024 Documentation
# =============================================================================
# OUTPUT:  output/T12_C_corrections.csv
# INPUTS:  data/S18_null_stack.rds, data/S5R_bhat.rds
# PURPOSE: Document corrections to null analyses (INV-024)
#          C1: G3 applied to pseudo_theta_D (corrected), not pseudo_theta_B
#          C2: Arm C uses Var(pseudo_theta_D)
#          C3: Horizon support table
#          C4: Trade-weighted mean definition
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
suppressPackageStartupMessages(library(dplyr))

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEED <- 20260719
set.seed(SEED)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S20: C1-C4 CORRECTIONS")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load data
S18 <- readRDS("data/S18_null_stack.rds")
S5R <- readRDS("data/S5R_bhat.rds")
baseline <- S5R$baseline

# =============================================================================
# C1: G3 GATE APPLIED TO CORRECTED OBJECT
# =============================================================================
say("")
say("=== C1: G3 GATE CORRECTION ===")

pseudo <- S18$pseudo_results
mean_bhat <- mean(baseline$theta_B - baseline$theta_D)

# Uncorrected (pseudo_theta_B)
mean_pseudo_B <- mean(pseudo$pseudo_theta_B)
se_pseudo_B <- sd(pseudo$pseudo_theta_B) / sqrt(nrow(pseudo))

# Corrected (pseudo_theta_D = pseudo_theta_B - mean_bhat)
mean_pseudo_D <- mean(pseudo$pseudo_theta_D)
se_pseudo_D <- sd(pseudo$pseudo_theta_D) / sqrt(nrow(pseudo))

say("mean(pseudo_theta_B) = %.4f (uncorrected)", mean_pseudo_B)
say("mean(pseudo_theta_D) = %.4f (corrected)", mean_pseudo_D)
say("mean(b_hat) = %.4f", mean_bhat)
say("Cross-check: %.4f - %.4f = %.4f", mean_pseudo_B, mean_bhat, mean_pseudo_B - mean_bhat)

G3_uncorrected <- ifelse(abs(mean_pseudo_B) < 0.05, "PASS",
                         ifelse(abs(mean_pseudo_B) < 0.10, "PARTIAL", "FAIL"))
G3_corrected <- ifelse(abs(mean_pseudo_D) < 0.05, "PASS",
                       ifelse(abs(mean_pseudo_D) < 0.10, "PARTIAL", "FAIL"))

say("")
say("G3 (uncorrected): %s (|%.4f| vs threshold)", G3_uncorrected, mean_pseudo_B)
say("G3 (corrected):   %s (|%.4f| vs threshold)", G3_corrected, mean_pseudo_D)

# =============================================================================
# C2: ARM C USES VAR(PSEUDO_THETA_D)
# =============================================================================
say("")
say("=== C2: ARM C VARIANCE ===")

Var_pseudo_B <- var(pseudo$pseudo_theta_B)
Var_pseudo_D <- var(pseudo$pseudo_theta_D)

say("Var(pseudo_theta_B) = %.4f", Var_pseudo_B)
say("Var(pseudo_theta_D) = %.4f", Var_pseudo_D)
say("Note: Variance is invariant to constant shift, so these are equal")

# Var_null_matched uses horizon-weighted variance
say("")
say("Var_null_matched (from S18): %.4f", S18$Var_null_matched)

# =============================================================================
# C3: HORIZON SUPPORT TABLE
# =============================================================================
say("")
say("=== C3: HORIZON SUPPORT ===")

horizon_table <- S18$var_by_bin %>%
    left_join(S18$weights_sym %>% select(horizon_bin, n_treated = n, weight),
              by = "horizon_bin")

say("Horizon support table:")
print(as.data.frame(horizon_table))

# Check for thin bins
thin_threshold <- 100
thin_bins <- horizon_table %>%
    filter(n < thin_threshold | (n_treated < thin_threshold & weight > 0))

if (nrow(thin_bins) > 0) {
    say("")
    say("WARNING: Thin bins detected (n < %d):", thin_threshold)
    print(as.data.frame(thin_bins))
} else {
    say("")
    say("No thin bins (all n >= %d where weight > 0)", thin_threshold)
}

# =============================================================================
# C4: TRADE-WEIGHTED MEAN DEFINITION
# =============================================================================
say("")
say("=== C4: TRADE-WEIGHTED MEAN ===")

# Using pre_trade (avoids endogeneity)
tw_mean_pre <- sum(baseline$theta_D * baseline$pre_trade) / sum(baseline$pre_trade)
uw_mean <- mean(baseline$theta_D)

say("Unweighted mean(theta_D): %.4f", uw_mean)
say("Pre-trade weighted mean:  %.4f", tw_mean_pre)
say("")
say("Definition: pre_trade weights avoid endogeneity (treatment doesn't affect pre_trade)")

# =============================================================================
# OUTPUT
# =============================================================================
say("")

corrections <- data.frame(
    item = c("C1_mean_pseudo_B", "C1_mean_pseudo_D", "C1_mean_bhat",
             "C1_G3_uncorrected", "C1_G3_corrected",
             "C2_Var_pseudo_B", "C2_Var_pseudo_D", "C2_Var_null_matched",
             "C3_thin_bins",
             "C4_tw_mean_pre", "C4_uw_mean"),
    value = c(mean_pseudo_B, mean_pseudo_D, mean_bhat,
              NA, NA,
              Var_pseudo_B, Var_pseudo_D, S18$Var_null_matched,
              nrow(thin_bins),
              tw_mean_pre, uw_mean),
    stringsAsFactors = FALSE
)
corrections$value[4] <- G3_uncorrected
corrections$value[5] <- G3_corrected

write.csv(corrections, "output/T12_C_corrections.csv", row.names = FALSE)

# Sidecar
code_sha <- get_sha256("code/S20_corrections.R")
writeLines(c(
    "FILE:      T12_C_corrections.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_C_corrections.csv")),
    sprintf("PRODUCER:  code/S20_corrections.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S18_null_stack.rds, data/S5R_bhat.rds",
    "",
    "C1: G3 GATE CORRECTION (INV-024)",
    sprintf("  Uncorrected: mean=%.4f -> %s", mean_pseudo_B, G3_uncorrected),
    sprintf("  Corrected:   mean=%.4f -> %s", mean_pseudo_D, G3_corrected),
    "",
    "C2: ARM C VARIANCE",
    sprintf("  Var_null_matched = %.4f", S18$Var_null_matched),
    "",
    sprintf("C3: THIN BINS: %d", nrow(thin_bins)),
    "",
    "C4: TRADE-WEIGHTED MEAN",
    sprintf("  pre_trade weighted: %.4f", tw_mean_pre),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T12_C_corrections.csv.sidecar")

say("")
say("Wrote output/T12_C_corrections.csv")
say("Done: %s", format(Sys.time()))
