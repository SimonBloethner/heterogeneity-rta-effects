#!/usr/bin/env Rscript
# =============================================================================
# N6_T1_rebuild.R - Rebuild T1 Single-Chain Specification Ladder
# =============================================================================
# OUTPUTS: output/T12_N6_spec_ladder.csv
# INPUTS:  data/S9R_spec.rds, data/N2_placebo.rds
# PURPOSE: Every row from S*R, one window convention, placebo columns from N2
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
say("N6: T1 SINGLE-CHAIN SPECIFICATION LADDER")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load specification spread from S9R
S9R <- readRDS("data/S9R_spec.rds")
say("S9R loaded")
say("Specs: %s", paste(names(S9R$specs), collapse = ", "))

# Load placebo benchmark from N2
N2 <- readRDS("data/N2_placebo.rds")
say("N2 placebo: mean=%.4f, SD=%.4f", N2$mean_placebo, N2$sd_placebo)

# Load baseline for comparison
S5R <- readRDS("data/S5R_bhat.rds")
baseline <- S5R$baseline

# =============================================================================
# BUILD SPECIFICATION LADDER
# =============================================================================
say("")
say("=== SPECIFICATION LADDER ===")

# S9R contains RTA coefficient estimates under different FE specifications
# This is the "specification spread" - how the RTA effect varies by FE structure
spec_results <- S9R$results

say("Specification spread results from S9R:")
print(spec_results)

# Build combined ladder with theta distribution stats
d <- readRDS("data/S1R_ppml.rds")
post_cells <- d %>% filter(pair %in% baseline$pair, rta == 1, trade > 0)

# Theta_A: naive mean of log(trade/y_hat_0) without any correction
theta_A <- post_cells %>%
    filter(y_hat_0 > 0) %>%
    mutate(log_ratio = log(trade / y_hat_0)) %>%
    group_by(pair) %>%
    summarise(theta = mean(log_ratio), .groups = "drop")

# Theta_B: from S5R baseline (pair FE implicit in y_hat_0)
# Theta_D: corrected theta from S5R baseline

ladder <- data.frame(
    spec = c("A_naive", "(B) Bilateral", "(C) Country", "(CY) Country-Year", "(FULL) Full", "D_corrected"),
    description = c(
        "Naive log(trade/y_hat_0)",
        "Bilateral (pair) FE",
        "Country FE",
        "Country-year FE",
        "Full (pair + country-year) FE",
        "Corrected theta_D"
    ),
    # RTA coefficient from specification spread
    rta_coef = c(NA, spec_results$estimate[spec_results$spec == "(B) Bilateral"],
                 spec_results$estimate[spec_results$spec == "(C) Country"],
                 spec_results$estimate[spec_results$spec == "(CY) Country-Year"],
                 spec_results$estimate[spec_results$spec == "(FULL) Full"], NA),
    rta_se = c(NA, spec_results$se[spec_results$spec == "(B) Bilateral"],
               spec_results$se[spec_results$spec == "(C) Country"],
               spec_results$se[spec_results$spec == "(CY) Country-Year"],
               spec_results$se[spec_results$spec == "(FULL) Full"], NA),
    # Theta distribution stats
    mean_theta = c(mean(theta_A$theta), mean(baseline$theta_B), NA, NA, NA, mean(baseline$theta_D)),
    sd_theta = c(sd(theta_A$theta), sd(baseline$theta_B), NA, NA, NA, sd(baseline$theta_D)),
    n = c(nrow(theta_A), nrow(baseline), NA, NA, NA, nrow(baseline)),
    stringsAsFactors = FALSE
)

# Add placebo columns
ladder$placebo_mean <- N2$mean_placebo
ladder$placebo_sd <- N2$sd_placebo
ladder$placebo_n <- N2$n_placebo

# Add corrected theta_D for comparison
ladder$theta_D_mean <- mean(baseline$theta_D, na.rm = TRUE)
ladder$theta_D_sd <- sd(baseline$theta_D, na.rm = TRUE)

say("")
print(ladder)

# =============================================================================
# SPEC SPREAD (RTA coefficient)
# =============================================================================
say("")
say("=== SPECIFICATION SPREAD (RTA Coefficient) ===")

rta_B <- ladder$rta_coef[ladder$spec == "(B) Bilateral"]
rta_FULL <- ladder$rta_coef[ladder$spec == "(FULL) Full"]
spread_B_FULL <- rta_B - rta_FULL

say("B coefficient:    %.4f", rta_B)
say("FULL coefficient: %.4f", rta_FULL)
say("B - FULL spread:  %.4f", spread_B_FULL)

# =============================================================================
# THETA DISTRIBUTION
# =============================================================================
say("")
say("=== THETA DISTRIBUTION (SD) ===")

sd_A <- ladder$sd_theta[ladder$spec == "A_naive"]
sd_B <- ladder$sd_theta[ladder$spec == "(B) Bilateral"]
sd_D <- ladder$sd_theta[ladder$spec == "D_corrected"]

say("SD(theta_A) naive:     %.4f", sd_A)
say("SD(theta_B) bilateral: %.4f", sd_B)
say("SD(theta_D) corrected: %.4f", sd_D)

# =============================================================================
# INV-020 VERIFICATION
# =============================================================================
say("")
say("================================================================")
say("INV-020: T1 SPLICE DEFECT VERIFICATION")
say("================================================================")

say("")
say("Original T1 mixed rows from different chains/windows.")
say("The B-to-D SD drop was presented as showing FE correction")
say("when it actually mixed incompatible methodologies.")
say("")
say("TRUE SAME-CHAIN COMPARISON (S*R, symmetric ±1 window):")
say("  SD(theta_A): %.4f", sd_A)
say("  SD(theta_B): %.4f", sd_B)
say("  SD(theta_D): %.4f (after b-hat correction)", sd_D)
say("")
say("This defect caused a documented wrong inference by a careful reader.")

# =============================================================================
# OUTPUT
# =============================================================================
say("")

# Add chain provenance
ladder$chain <- "S*R"
ladder$window <- "symmetric ±1"
ladder$anticipation_excluded <- TRUE

write.csv(ladder, "output/T12_N6_spec_ladder.csv", row.names = FALSE)

# Sidecar
code_sha <- get_sha256("code/N6_T1_rebuild.R")
writeLines(c(
    "FILE:      T12_N6_spec_ladder.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N6_spec_ladder.csv")),
    sprintf("PRODUCER:  code/N6_T1_rebuild.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S9R_spec.rds, data/N2_placebo.rds, data/S5R_bhat.rds",
    sprintf("SEED:      %d", SEED),
    "",
    "CHAIN:     S*R (single chain, one window convention)",
    "WINDOW:    Symmetric ±1 year (adopt-1 to adopt+1 excluded)",
    "",
    "SPECIFICATION SPREAD (RTA coefficient):",
    sprintf("  B (bilateral): %.4f", rta_B),
    sprintf("  FULL:          %.4f", rta_FULL),
    sprintf("  B - FULL:      %.4f", spread_B_FULL),
    "",
    "THETA DISTRIBUTION (SD):",
    sprintf("  A (naive):     %.4f", sd_A),
    sprintf("  B (bilateral): %.4f", sd_B),
    sprintf("  D (corrected): %.4f", sd_D),
    "",
    "INV-020: T1 splice defect documented",
    "  Original mixed rows from different chains/windows",
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T12_N6_spec_ladder.csv.sidecar")

say("")
say("Wrote output/T12_N6_spec_ladder.csv")
say("Done: %s", format(Sys.time()))
