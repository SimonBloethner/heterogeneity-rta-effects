#!/usr/bin/env Rscript
# =============================================================================
# V1_attrition.R - Attrition Analysis
# =============================================================================
# OUTPUT:  output/V1_attrition.csv
# INPUTS:  data/S1R_ppml.rds, data/S5R_bhat.rds
# PURPOSE: Drop rates by quintile, worst-case bounds, n_post >= 6 gradient
# =============================================================================

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(dplyr))

SEED <- 20260719
set.seed(SEED)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(file.path(RTA_ROOT, p)), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("V1: ATTRITION ANALYSIS")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load data
S1R <- readRDS(file.path(RTA_ROOT, "data/S1R_ppml.rds"))
S5R <- readRDS(file.path(RTA_ROOT, "data/S5R_bhat.rds"))
baseline <- S5R$baseline

say("Baseline pairs: %d", nrow(baseline))

# =============================================================================
# DROP RATES BY QUINTILE
# =============================================================================
say("")
say("=== DROP RATES BY PRE-TRADE QUINTILE ===")

# Assign quintiles based on pre_trade
baseline$quintile <- as.integer(cut(rank(baseline$pre_trade), breaks = 5, labels = FALSE))

# Count by quintile
quintile_counts <- baseline %>%
    group_by(quintile) %>%
    summarise(
        n = n(),
        mean_theta_D = mean(theta_D),
        mean_pre_trade = mean(pre_trade),
        .groups = "drop"
    )

say("")
print(as.data.frame(quintile_counts))

# =============================================================================
# WORST-CASE BOUNDS
# =============================================================================
say("")
say("=== WORST-CASE BOUNDS ===")

# If all dropped pairs had theta_D = +2 or -2
n_total_potential <- 6597  # From R2 (pairs with pre-trade)
n_baseline <- nrow(baseline)
n_dropped <- n_total_potential - n_baseline

mean_theta_D <- mean(baseline$theta_D)
sum_theta_D <- sum(baseline$theta_D)

# Worst case: dropped pairs all at +2
worst_high <- (sum_theta_D + n_dropped * 2) / n_total_potential
# Worst case: dropped pairs all at -2
worst_low <- (sum_theta_D + n_dropped * (-2)) / n_total_potential

say("Potential pairs (R2): %d", n_total_potential)
say("Baseline pairs: %d", n_baseline)
say("Dropped: %d (%.1f%%)", n_dropped, 100 * n_dropped / n_total_potential)
say("")
say("Observed mean(theta_D): %.4f", mean_theta_D)
say("Worst-case bounds: [%.4f, %.4f]", worst_low, worst_high)

# =============================================================================
# RESTRICTED GRADIENT (n_post >= 6)
# =============================================================================
say("")
say("=== RESTRICTED GRADIENT (n_post >= 6) ===")

# Get n_post for baseline pairs
adopt_lookup <- baseline %>% select(pair, adopt_yr = adoption_year) %>% distinct()

n_post_calc <- S1R %>%
    filter(pair %in% baseline$pair, rta == 1, trade > 0) %>%
    select(pair, year) %>%
    inner_join(adopt_lookup, by = "pair") %>%
    filter(year > adopt_yr + 1) %>%
    group_by(pair) %>%
    summarise(n_post_sym = n_distinct(year), .groups = "drop")

baseline_npost <- baseline %>%
    left_join(n_post_calc, by = "pair")

# Filter to n_post >= 6 (handle NAs from left_join)
restricted <- baseline_npost %>%
    filter(!is.na(n_post_sym), n_post_sym >= 6)

say("Pairs with n_post >= 6: %d (%.1f%%)",
    nrow(restricted), 100 * nrow(restricted) / nrow(baseline))

# Gradient by quintile (restricted)
restricted$quintile <- as.integer(cut(rank(restricted$pre_trade), breaks = 5, labels = FALSE))

restricted_gradient <- restricted %>%
    group_by(quintile) %>%
    summarise(
        n = n(),
        mean_theta_D = mean(theta_D),
        .groups = "drop"
    )

say("")
say("Restricted gradient (n_post >= 6):")
print(as.data.frame(restricted_gradient))

Q1_restricted <- restricted_gradient$mean_theta_D[1]
Q5_restricted <- restricted_gradient$mean_theta_D[5]
say("")
say("Q1-Q5 spread (restricted): %.4f", Q1_restricted - Q5_restricted)

# =============================================================================
# OUTPUT
# =============================================================================
say("")

results <- bind_rows(
    quintile_counts %>%
        mutate(item = paste0("Q", quintile, "_n")) %>%
        select(item, value = n),
    quintile_counts %>%
        mutate(item = paste0("Q", quintile, "_mean_theta_D")) %>%
        select(item, value = mean_theta_D),
    data.frame(
        item = c("n_dropped", "worst_low", "worst_high",
                 "n_restricted", "Q1_Q5_restricted"),
        value = c(n_dropped, worst_low, worst_high,
                  nrow(restricted), Q1_restricted - Q5_restricted)
    )
)

write.csv(results, file.path(RTA_ROOT, "output/V1_attrition.csv"), row.names = FALSE)

# Sidecar
code_sha <- get_sha256("code/validation/V1_attrition.R")
writeLines(c(
    "FILE:      V1_attrition.csv",
    sprintf("SHA256:    %s", get_sha256("output/V1_attrition.csv")),
    sprintf("PRODUCER:  code/validation/V1_attrition.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S1R_ppml.rds, data/S5R_bhat.rds",
    "",
    sprintf("DROPPED: %d pairs (%.1f%%)", n_dropped, 100 * n_dropped / n_total_potential),
    sprintf("WORST-CASE BOUNDS: [%.4f, %.4f]", worst_low, worst_high),
    sprintf("RESTRICTED (n_post >= 6): %d pairs", nrow(restricted)),
    sprintf("Q1-Q5 SPREAD (restricted): %.4f", Q1_restricted - Q5_restricted),
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/V1_attrition.csv.sidecar"))

say("")
say("Wrote output/V1_attrition.csv")
say("Done: %s", format(Sys.time()))
