#!/usr/bin/env Rscript
# =============================================================================
# N1_oos_null.R - Out-of-Sample Pseudo-Effect Null
# =============================================================================
# OUTPUTS: output/T12_N1_oos_null.csv, output/T12_N1b_horizon.csv
# INPUTS:  data/S1R_ppml.rds
# SEED:    20260719
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
suppressPackageStartupMessages(library(fixest))
suppressPackageStartupMessages(library(dplyr))
setFixest_nthreads(4)

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEED <- 20260719
set.seed(SEED)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("N1: OUT-OF-SAMPLE PSEUDO-EFFECT NULL")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load data
d <- readRDS("data/S1R_ppml.rds")
say("S1R rows: %d", nrow(d))

# Identify pair types
pairs <- d %>%
    group_by(pair) %>%
    summarise(
        rta_min = min(rta),
        rta_max = max(rta),
        adoption_year = if(any(rta == 1)) min(year[rta == 1]) else NA,
        .groups = "drop"
    ) %>%
    mutate(
        type = case_when(
            rta_max == 0 ~ "never_treated",
            rta_min == 1 ~ "always_treated",
            TRUE ~ "switcher"
        )
    )

never_treated_pairs <- pairs$pair[pairs$type == "never_treated"]
switcher_pairs <- pairs %>% filter(type == "switcher")
say("Never-treated pairs: %d", length(never_treated_pairs))
say("Switcher pairs: %d", nrow(switcher_pairs))

# Get switcher pre-years (year < adoption_year - 1)
# Note: S1R_ppml.rds already has adoption_year column
switcher_pre <- d %>%
    filter(pair %in% switcher_pairs$pair, !is.na(adoption_year)) %>%
    filter(year < adoption_year - 1, trade > 0) %>%
    group_by(pair) %>%
    mutate(n_pre = n()) %>%
    ungroup()

# Filter to pairs with >= 6 pre years
eligible_pairs_df <- switcher_pre %>%
    group_by(pair) %>%
    summarise(n_pre = n(), .groups = "drop") %>%
    filter(n_pre >= 6)

eligible_pairs <- eligible_pairs_df$pair
say("Eligible pairs (>= 6 pre years): %d", length(eligible_pairs))

eligible <- switcher_pre %>% filter(pair %in% eligible_pairs)

# Split each pair's pre-period at midpoint
split_info <- eligible %>%
    group_by(pair) %>%
    summarise(
        pre_years = list(sort(unique(year))),
        n_pre = length(unique(year)),
        .groups = "drop"
    ) %>%
    mutate(
        midpoint = floor(n_pre / 2),
        early_years = lapply(1:n(), function(i) pre_years[[i]][1:midpoint[i]]),
        late_years = lapply(1:n(), function(i) pre_years[[i]][(midpoint[i]+1):n_pre[i]]),
        n_early = sapply(early_years, length),
        n_late = sapply(late_years, length)
    )

say("Split info: mean early=%0.1f, mean late=%0.1f",
    mean(split_info$n_early), mean(split_info$n_late))

# Create EARLY and LATE flags
early_cells <- do.call(rbind, lapply(1:nrow(split_info), function(i) {
    data.frame(pair = split_info$pair[i], year = split_info$early_years[[i]])
}))
late_cells <- do.call(rbind, lapply(1:nrow(split_info), function(i) {
    data.frame(pair = split_info$pair[i], year = split_info$late_years[[i]])
}))

# Mark cells
d$is_early <- paste(d$pair, d$year) %in% paste(early_cells$pair, early_cells$year)
d$is_late <- paste(d$pair, d$year) %in% paste(late_cells$pair, late_cells$year)

say("Early cells: %d", sum(d$is_early))
say("Late cells: %d", sum(d$is_late))

# Build estimation sample: never-treated (all years) + switcher EARLY-pre only
est_sample <- d %>%
    filter(
        (pair %in% never_treated_pairs) |  # never-treated all years
        (is_early)                          # switcher EARLY-pre only
    )

say("")
say("=== ESTIMATION SAMPLE ===")
say("Rows: %d", nrow(est_sample))

# Gate 1: no treated cells in estimation sample
n_treated_in_est <- sum(est_sample$rta == 1)
say("Treated cells in est sample: %d", n_treated_in_est)
stopifnot("G1: No treated cells in estimation sample" = n_treated_in_est == 0)
say("G1 PASS: no treated cells in estimation sample")

# Gate 2: no LATE cells in estimation sample
n_late_in_est <- sum(est_sample$is_late)
say("LATE cells in est sample: %d", n_late_in_est)
stopifnot("G2: No LATE cells in estimation sample" = n_late_in_est == 0)
say("G2 PASS: no LATE cells in estimation sample")

# Fit model
say("")
say("=== FITTING MODEL ===")
fit <- fepois(trade ~ 1 | pair + exporter^year + importer^year, data = est_sample)
say("Model converged")

# Predict y_hat_0 for LATE cells
late_data <- d %>% filter(is_late, trade > 0)
say("LATE cells to predict: %d", nrow(late_data))

late_data$y_hat_0 <- predict(fit, newdata = late_data)

# Compute pseudo_theta_B per pair
pseudo_theta <- late_data %>%
    filter(!is.na(y_hat_0), y_hat_0 > 0) %>%
    group_by(pair) %>%
    summarise(
        n_late = n(),
        sum_trade = sum(trade),
        sum_yhat = sum(y_hat_0),
        pseudo_theta_B = log(sum_trade / sum_yhat),
        .groups = "drop"
    )

say("")
say("=== PSEUDO THETA RESULTS ===")
say("N pairs: %d", nrow(pseudo_theta))
say("mean(pseudo_theta_B): %.6f", mean(pseudo_theta$pseudo_theta_B))
say("SD(pseudo_theta_B):   %.6f", sd(pseudo_theta$pseudo_theta_B))
say("Var(pseudo_theta_B):  %.6f", var(pseudo_theta$pseudo_theta_B))

# Gate 3: |mean| < 0.05 (three-state per INV-016)
mean_pseudo <- abs(mean(pseudo_theta$pseudo_theta_B))
if (mean_pseudo < 0.05) {
    gate_status <- "PASS"
} else if (mean_pseudo < 0.10) {
    gate_status <- "PARTIAL"
} else {
    gate_status <- "FAIL"
}
say("G3 |mean(pseudo_theta_B)|: %.4f -> %s", mean_pseudo, gate_status)

# Save N1 results
n1_results <- data.frame(
    quantity = c("n_pairs", "mean_pseudo_theta_B", "SD_pseudo_theta_B",
                 "Var_pseudo_theta_B", "G3_status"),
    value = c(nrow(pseudo_theta), mean(pseudo_theta$pseudo_theta_B),
              sd(pseudo_theta$pseudo_theta_B), var(pseudo_theta$pseudo_theta_B),
              NA),
    note = c("", "", "", "", gate_status)
)
write.csv(n1_results, "output/T12_N1_oos_null.csv", row.names = FALSE)

# =============================================================================
# N1b: HORIZON MATCHING
# =============================================================================
say("")
say("================================================================")
say("N1b: HORIZON MATCHING")
say("================================================================")

# Add LATE window length to pseudo_theta
pseudo_theta <- pseudo_theta %>%
    mutate(
        late_horizon = n_late,
        horizon_bin = cut(late_horizon,
                         breaks = c(0, 3, 5, 10, Inf),
                         labels = c("2-3", "4-5", "6-10", "11+"),
                         right = TRUE)
    )

# Var by horizon bin
horizon_var <- pseudo_theta %>%
    group_by(horizon_bin) %>%
    summarise(
        n = n(),
        var_pseudo = var(pseudo_theta_B),
        .groups = "drop"
    )
say("Var(pseudo_theta_B) by LATE-window length:")
print(horizon_var)

# Get treated post-window lengths for the 4,182 baseline pairs
S5R <- readRDS("data/S5R_bhat.rds")
baseline <- S5R$baseline
say("")
say("Baseline pairs: %d", nrow(baseline))

# Get post-window lengths
post_lengths <- d %>%
    filter(pair %in% baseline$pair, rta == 1, trade > 0) %>%
    group_by(pair) %>%
    summarise(n_post = n(), .groups = "drop") %>%
    mutate(
        horizon_bin = cut(n_post,
                         breaks = c(0, 3, 5, 10, Inf),
                         labels = c("2-3", "4-5", "6-10", "11+"),
                         right = TRUE)
    )

treated_dist <- post_lengths %>%
    group_by(horizon_bin) %>%
    summarise(n_treated = n(), .groups = "drop") %>%
    mutate(weight = n_treated / sum(n_treated))

say("Treated post-window distribution:")
print(treated_dist)

# Merge to get weights
horizon_merged <- horizon_var %>%
    left_join(treated_dist, by = "horizon_bin")

# Check for unsupported horizons
unsupported <- horizon_merged %>% filter(is.na(var_pseudo) | n == 0)
if (nrow(unsupported) > 0) {
    say("")
    say("WARNING: Some treated horizons have no pseudo support:")
    print(unsupported)
    unsupported_share <- sum(unsupported$n_treated, na.rm = TRUE) / sum(treated_dist$n_treated)
    say("Share of treated pairs unsupported: %.1f%%", 100 * unsupported_share)
}

# Compute horizon-reweighted null variance
supported <- horizon_merged %>% filter(!is.na(var_pseudo), n > 0)
Var_null_matched <- sum(supported$var_pseudo * supported$weight, na.rm = TRUE) /
                    sum(supported$weight, na.rm = TRUE)

say("")
say("=== HORIZON-REWEIGHTED RESULTS ===")
say("Var_null_raw:     %.6f", var(pseudo_theta$pseudo_theta_B))
say("Var_null_matched: %.6f", Var_null_matched)

# Save N1b results
n1b_results <- rbind(
    data.frame(
        horizon_bin = as.character(horizon_var$horizon_bin),
        n_pseudo = horizon_var$n,
        var_pseudo = horizon_var$var_pseudo,
        n_treated = treated_dist$n_treated[match(horizon_var$horizon_bin, treated_dist$horizon_bin)],
        weight = treated_dist$weight[match(horizon_var$horizon_bin, treated_dist$horizon_bin)]
    ),
    data.frame(
        horizon_bin = "MATCHED",
        n_pseudo = nrow(pseudo_theta),
        var_pseudo = Var_null_matched,
        n_treated = sum(treated_dist$n_treated),
        weight = 1.0
    )
)
write.csv(n1b_results, "output/T12_N1b_horizon.csv", row.names = FALSE)

# Save workspace for downstream
saveRDS(list(
    pseudo_theta = pseudo_theta,
    Var_null_raw = var(pseudo_theta$pseudo_theta_B),
    Var_null_matched = Var_null_matched,
    horizon_var = horizon_var,
    treated_dist = treated_dist,
    seed = SEED
), "data/N1_oos_null.rds")

# Sidecars
code_sha <- get_sha256("code/N1_oos_null.R")

writeLines(c(
    "FILE:      T12_N1_oos_null.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N1_oos_null.csv")),
    sprintf("PRODUCER:  code/N1_oos_null.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S1R_ppml.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("N_PAIRS:   %d", nrow(pseudo_theta)),
    sprintf("VAR_NULL:  %.6f", var(pseudo_theta$pseudo_theta_B)),
    sprintf("G3_STATUS: %s", gate_status),
    "METHOD:    Split pre-period at midpoint, refit on EARLY, predict LATE",
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T12_N1_oos_null.csv.sidecar")

writeLines(c(
    "FILE:      T12_N1b_horizon.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N1b_horizon.csv")),
    sprintf("PRODUCER:  code/N1_oos_null.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S1R_ppml.rds, data/S5R_bhat.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("VAR_NULL_MATCHED: %.6f", Var_null_matched),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T12_N1b_horizon.csv.sidecar")

say("")
say("Wrote output/T12_N1_oos_null.csv")
say("Wrote output/T12_N1b_horizon.csv")
say("Wrote data/N1_oos_null.rds")
say("Done: %s", format(Sys.time()))
