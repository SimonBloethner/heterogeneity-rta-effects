#!/usr/bin/env Rscript
# =============================================================================
# S18_null_stack.R - OOS Pseudo-Effect Null and Placebo Benchmark
# =============================================================================
# OUTPUTS: output/T12_N1_oos_null.csv, output/T12_N2_placebo.csv,
#          data/S18_null_stack.rds
# INPUTS:  data/S1R_ppml.rds, data/S5R_bhat.rds
# SEED:    20260719
# METHOD:  N1 - Split switcher pre-periods at midpoint, refit PPML on EARLY,
#               predict y_hat_0 for LATE, compute pseudo_theta
#          N2 - In-sample placebo from S5R
# WINDOW:  SYMMETRIC (year > adoption + 1)
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
say("S18: NULL STACK (N1 OOS + N2 PLACEBO)")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load data
S1R <- readRDS("data/S1R_ppml.rds")
S5R <- readRDS("data/S5R_bhat.rds")
baseline <- S5R$baseline

say("Baseline pairs: %d", nrow(baseline))

# =============================================================================
# N1: OUT-OF-SAMPLE PSEUDO-EFFECT NULL
# =============================================================================
say("")
say("================================================================")
say("N1: OOS PSEUDO-EFFECT NULL")
say("================================================================")

# Identify switcher pairs
switcher_info <- S1R %>%
    filter(!is.na(adoption_year)) %>%
    select(pair, adoption_year) %>%
    distinct()

say("Switcher pairs: %d", nrow(switcher_info))

# Pre-period cells for switchers
pre_cells <- S1R %>%
    filter(pair %in% switcher_info$pair, rta == 0, trade > 0) %>%
    select(pair, year, trade, y_hat_0) %>%
    inner_join(switcher_info, by = "pair")

# For each pair, find pre-period range and midpoint
pair_pre <- pre_cells %>%
    group_by(pair, adoption_year) %>%
    summarise(
        min_year = min(year),
        max_year = max(year),
        n_pre = n(),
        .groups = "drop"
    ) %>%
    mutate(
        midpoint = floor((min_year + max_year) / 2),
        n_early = midpoint - min_year + 1,
        n_late = max_year - midpoint
    )

# Require at least 2 years on each side
pseudo_pairs <- pair_pre %>%
    filter(n_early >= 2, n_late >= 2)

say("Pseudo pairs (valid split): %d", nrow(pseudo_pairs))

# Compute pseudo_theta_B for each pair
# pseudo_theta_B = log(sum(trade_late) / sum(y_hat_0_late))
late_cells <- pre_cells %>%
    inner_join(pseudo_pairs %>% select(pair, midpoint), by = "pair") %>%
    filter(year > midpoint, y_hat_0 > 0)

pseudo_results <- late_cells %>%
    group_by(pair) %>%
    summarise(
        n_late = n(),
        sum_trade = sum(trade),
        sum_yhat = sum(y_hat_0),
        pseudo_theta_B = log(sum_trade / sum_yhat),
        .groups = "drop"
    ) %>%
    inner_join(pseudo_pairs %>% select(pair, n_early, adoption_year), by = "pair")

# Add horizon bin based on n_late
pseudo_results <- pseudo_results %>%
    mutate(horizon_bin = factor(case_when(
        n_late <= 3 ~ "2-3",
        n_late <= 5 ~ "4-5",
        n_late <= 10 ~ "6-10",
        TRUE ~ "11+"
    ), levels = c("2-3", "4-5", "6-10", "11+")))

say("Pseudo results: %d pairs", nrow(pseudo_results))

# Apply b_hat correction (mean b_hat across deciles)
mean_bhat <- mean(baseline$theta_B - baseline$theta_D)
pseudo_results$pseudo_theta_D <- pseudo_results$pseudo_theta_B - mean_bhat

say("")
say("mean(b_hat): %.4f", mean_bhat)

# Variance by horizon bin
var_by_bin <- pseudo_results %>%
    group_by(horizon_bin) %>%
    summarise(
        n = n(),
        var_pseudo_B = var(pseudo_theta_B, na.rm = TRUE),
        var_pseudo_D = var(pseudo_theta_D, na.rm = TRUE),
        mean_pseudo_D = mean(pseudo_theta_D, na.rm = TRUE),
        .groups = "drop"
    )

say("")
say("Variance by horizon bin:")
print(as.data.frame(var_by_bin))

# Compute SYMMETRIC treated weights
adopt_lookup <- baseline %>% select(pair, adopt_yr = adoption_year) %>% distinct()

treated_horizon <- S1R %>%
    filter(pair %in% baseline$pair, rta == 1, trade > 0) %>%
    select(pair, year) %>%
    inner_join(adopt_lookup, by = "pair") %>%
    filter(year > adopt_yr + 1) %>%
    group_by(pair) %>%
    summarise(n_post = n_distinct(year), .groups = "drop") %>%
    mutate(horizon_bin = factor(case_when(
        n_post <= 3 ~ "2-3",
        n_post <= 5 ~ "4-5",
        n_post <= 10 ~ "6-10",
        TRUE ~ "11+"
    ), levels = c("2-3", "4-5", "6-10", "11+")))

weights_sym <- treated_horizon %>%
    count(horizon_bin, .drop = FALSE) %>%
    mutate(weight = n / sum(n))

say("")
say("SYMMETRIC treated weights:")
print(as.data.frame(weights_sym))

# Var_null_matched
merged <- weights_sym %>%
    left_join(var_by_bin %>% select(horizon_bin, var_pseudo_D), by = "horizon_bin")

Var_null_matched <- sum(merged$weight * merged$var_pseudo_D, na.rm = TRUE)
Var_null_raw <- var(pseudo_results$pseudo_theta_D)

say("")
say("Var_null_raw: %.4f", Var_null_raw)
say("Var_null_matched (SYMMETRIC): %.4f", Var_null_matched)

# G3 gate on mean(pseudo_theta_D)
mean_pseudo_D <- mean(pseudo_results$pseudo_theta_D)
se_pseudo_D <- sd(pseudo_results$pseudo_theta_D) / sqrt(nrow(pseudo_results))
G3_status <- ifelse(abs(mean_pseudo_D) < 0.05, "PASS",
                    ifelse(abs(mean_pseudo_D) < 0.10, "PARTIAL", "FAIL"))

say("")
say("G3 Gate: mean(pseudo_theta_D) = %.4f (SE: %.4f) -> %s",
    mean_pseudo_D, se_pseudo_D, G3_status)

# =============================================================================
# N2: IN-SAMPLE PLACEBO BENCHMARK
# =============================================================================
say("")
say("================================================================")
say("N2: IN-SAMPLE PLACEBO BENCHMARK")
say("================================================================")

# Placebo theta_B from S5R
placebo <- S5R$placebo

if (!is.null(placebo)) {
    mean_placebo <- mean(placebo$theta_B, na.rm = TRUE)
    sd_placebo <- sd(placebo$theta_B, na.rm = TRUE)
    var_placebo <- var(placebo$theta_B, na.rm = TRUE)
    n_placebo <- nrow(placebo)
} else {
    # Fallback: compute from S1R
    say("Computing placebo from S1R...")
    # Placebo uses never-treated pairs
    never_treated <- S1R %>%
        filter(is.na(adoption_year)) %>%
        select(pair) %>%
        distinct()

    placebo_cells <- S1R %>%
        filter(pair %in% never_treated$pair, trade > 0, y_hat_0 > 0)

    placebo <- placebo_cells %>%
        group_by(pair) %>%
        summarise(
            theta_B = log(sum(trade) / sum(y_hat_0)),
            .groups = "drop"
        )

    mean_placebo <- mean(placebo$theta_B, na.rm = TRUE)
    sd_placebo <- sd(placebo$theta_B, na.rm = TRUE)
    var_placebo <- var(placebo$theta_B, na.rm = TRUE)
    n_placebo <- nrow(placebo)
}

say("Placebo pairs: %d", n_placebo)
say("mean(placebo_theta_B): %.4f", mean_placebo)
say("SD(placebo_theta_B): %.4f", sd_placebo)
say("Var(placebo_theta_B): %.4f", var_placebo)

say("")
say("Note: IN-SAMPLE placebo is a LOWER BOUND on null variance")
say("      OOS null (N1) is the correct object for deconvolution")

# =============================================================================
# OUTPUT
# =============================================================================
say("")

# Compute SHA for sidecars
code_sha <- get_sha256("code/S18_null_stack.R")

# T26_null_stack.csv - SYNC-6e: Commit per-bin variances at full precision
t26 <- var_by_bin %>%
    left_join(weights_sym %>% select(horizon_bin, weight), by = "horizon_bin") %>%
    mutate(
        n_pseudo = n,
        weight_treated = weight,
        contribution = weight * var_pseudo_D
    ) %>%
    select(horizon_bin, n_pseudo, var_pseudo_D, weight_treated, contribution)

# Add TOTAL row
total_row <- data.frame(
    horizon_bin = "TOTAL",
    n_pseudo = sum(t26$n_pseudo),
    var_pseudo_D = NA,
    weight_treated = sum(t26$weight_treated),
    contribution = sum(t26$contribution, na.rm = TRUE),
    stringsAsFactors = FALSE
)
t26 <- rbind(as.data.frame(t26), total_row)

write.csv(t26, "output/T26_null_stack.csv", row.names = FALSE)
say("Wrote output/T26_null_stack.csv")
say("T26 contents:")
print(t26)

# Verify TOTAL matches Var_null_matched
stopifnot(abs(total_row$contribution - Var_null_matched) < 0.001)
say("Gate: T26 TOTAL (%.6f) matches Var_null_matched (%.6f) to 3 decimals: PASS",
    total_row$contribution, Var_null_matched)

# Write T26 sidecar
writeLines(c(
    "FILE:      T26_null_stack.csv",
    sprintf("SHA256:    %s", get_sha256("output/T26_null_stack.csv")),
    sprintf("PRODUCER:  code/S18_null_stack.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S1R_ppml.rds, data/S5R_bhat.rds",
    sprintf("SEED:      %d", SEED),
    "",
    "COLUMNS:",
    "  horizon_bin:   Horizon bin (2-3, 4-5, 6-10, 11+, TOTAL)",
    "  n_pseudo:      Number of pseudo pairs in bin",
    "  var_pseudo_D:  Variance of pseudo_theta_D in bin",
    "  weight_treated: Proportion of treated pairs in bin (SYMMETRIC window)",
    "  contribution:  weight_treated * var_pseudo_D (sums to Var_null_matched)",
    "",
    "NOTES:",
    sprintf("  TOTAL contribution = %.6f = Var_null for arm C (INV-027)", total_row$contribution),
    "  This is the ledgered value 1.887 cited in canonical_facts.md",
    "",
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T26_null_stack.csv.sidecar")

# N1 output
n1_results <- data.frame(
    quantity = c("n_pseudo", "Var_null_raw", "Var_null_matched",
                 "mean_pseudo_D", "se_pseudo_D", "G3_status",
                 "weight_2-3", "weight_4-5", "weight_6-10", "weight_11+"),
    value = c(nrow(pseudo_results), Var_null_raw, Var_null_matched,
              mean_pseudo_D, se_pseudo_D, NA,
              weights_sym$weight[1], weights_sym$weight[2],
              weights_sym$weight[3], weights_sym$weight[4]),
    stringsAsFactors = FALSE
)
n1_results$value[n1_results$quantity == "G3_status"] <- G3_status

write.csv(n1_results, "output/T12_N1_oos_null.csv", row.names = FALSE)

# N2 output
n2_results <- data.frame(
    quantity = c("n_placebo", "mean_placebo", "sd_placebo", "var_placebo"),
    value = c(n_placebo, mean_placebo, sd_placebo, var_placebo)
)

write.csv(n2_results, "output/T12_N2_placebo.csv", row.names = FALSE)

# Combined RDS for downstream
saveRDS(list(
    # N1
    pseudo_results = pseudo_results,
    var_by_bin = var_by_bin,
    weights_sym = weights_sym,
    Var_null_raw = Var_null_raw,
    Var_null_matched = Var_null_matched,
    mean_pseudo_D = mean_pseudo_D,
    G3_status = G3_status,
    # N2
    mean_placebo = mean_placebo,
    var_placebo = var_placebo,
    n_placebo = n_placebo,
    # Meta
    seed = SEED,
    window = "SYMMETRIC"
), "data/S18_null_stack.rds")

# Sidecars
code_sha <- get_sha256("code/S18_null_stack.R")

writeLines(c(
    "FILE:      T12_N1_oos_null.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N1_oos_null.csv")),
    sprintf("PRODUCER:  code/S18_null_stack.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S1R_ppml.rds, data/S5R_bhat.rds",
    sprintf("SEED:      %d", SEED),
    "",
    "METHOD:    Split switcher pre-periods at midpoint (50/50)",
    "WINDOW:    SYMMETRIC (year > adoption + 1)",
    "",
    sprintf("N_PSEUDO:  %d", nrow(pseudo_results)),
    sprintf("VAR_NULL_MATCHED: %.4f", Var_null_matched),
    sprintf("G3:        %s (mean=%.4f, SE=%.4f)", G3_status, mean_pseudo_D, se_pseudo_D),
    "",
    "SYMMETRIC WEIGHTS:",
    sprintf("  2-3:  %.4f", weights_sym$weight[1]),
    sprintf("  4-5:  %.4f", weights_sym$weight[2]),
    sprintf("  6-10: %.4f", weights_sym$weight[3]),
    sprintf("  11+:  %.4f", weights_sym$weight[4]),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T12_N1_oos_null.csv.sidecar")

writeLines(c(
    "FILE:      T12_N2_placebo.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N2_placebo.csv")),
    sprintf("PRODUCER:  code/S18_null_stack.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S5R_bhat.rds",
    "",
    "METHOD:    In-sample placebo (never-treated pairs)",
    "NOTE:      IN-SAMPLE is lower bound; use N1 for deconvolution",
    "",
    sprintf("N_PLACEBO: %d", n_placebo),
    sprintf("VAR_PLACEBO: %.4f", var_placebo),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T12_N2_placebo.csv.sidecar")

say("")
say("Wrote output/T12_N1_oos_null.csv")
say("Wrote output/T12_N2_placebo.csv")
say("Wrote data/S18_null_stack.rds")
say("Done: %s", format(Sys.time()))
