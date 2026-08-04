#!/usr/bin/env Rscript
# =============================================================================
# V3_horizon_cohort.R - Horizon-Cohort Analysis (H1-H3)
# =============================================================================
# OUTPUT:  output/V3_horizon_cohort.csv
# INPUTS:  data/S18_null_stack.rds, data/S5R_bhat.rds, data/S1R_ppml.rds
# PURPOSE: Document horizon-cohort disjunction in 11+ bin (INV-025)
#          H1: Adoption-year distribution
#          H2: Variance by cohort
#          H3: Bin verification
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
say("V3: HORIZON-COHORT ANALYSIS (H1-H3)")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load data
S1R <- readRDS(file.path(RTA_ROOT, "data/S1R_ppml.rds"))
S5R <- readRDS(file.path(RTA_ROOT, "data/S5R_bhat.rds"))
baseline <- S5R$baseline
S18 <- readRDS(file.path(RTA_ROOT, "data/S18_null_stack.rds"))

pseudo <- S18$pseudo_results

# Add adoption year to pseudo
switcher_info <- S1R %>%
    filter(!is.na(adoption_year)) %>%
    select(pair, adoption_year) %>%
    distinct()

pseudo <- pseudo %>%
    left_join(switcher_info, by = "pair") %>%
    rename(adopt_yr = adoption_year.y) %>%
    mutate(cohort = ifelse(adopt_yr < 2008, "pre_2008", "post_2008"))

# =============================================================================
# H1: ADOPTION-YEAR DISTRIBUTION IN 11+ BIN
# =============================================================================
say("")
say("=== H1: 11+ BIN ADOPTION-YEAR DISTRIBUTION ===")

pseudo_11plus <- pseudo %>% filter(horizon_bin == "11+")
say("Pseudo pairs in 11+ bin: %d", nrow(pseudo_11plus))

# Treated 11+ (symmetric)
adopt_lookup <- baseline %>% select(pair, adopt_yr = adoption_year) %>% distinct()
treated_11plus <- S1R %>%
    filter(pair %in% baseline$pair, rta == 1, trade > 0) %>%
    select(pair, year) %>%
    inner_join(adopt_lookup, by = "pair") %>%
    filter(year > adopt_yr + 1) %>%
    group_by(pair, adopt_yr) %>%
    summarise(n_post = n_distinct(year), .groups = "drop") %>%
    filter(n_post >= 11)

say("Treated pairs in 11+ bin: %d", nrow(treated_11plus))

# Adoption year ranges
pseudo_years <- range(pseudo_11plus$adopt_yr, na.rm = TRUE)
treated_years <- range(treated_11plus$adopt_yr)

say("")
say("Pseudo 11+ adoption years: %d - %d", pseudo_years[1], pseudo_years[2])
say("Treated 11+ adoption years: %d - %d", treated_years[1], treated_years[2])

# Overlap
overlap <- intersect(unique(pseudo_11plus$adopt_yr), unique(treated_11plus$adopt_yr))
say("")
say("Overlapping years: %d", length(overlap))
if (length(overlap) == 0) {
    say("FINDING: DISJOINT - no shared adoption years in 11+ bin")
}

# =============================================================================
# H2: VARIANCE BY COHORT
# =============================================================================
say("")
say("=== H2: VARIANCE BY COHORT ===")

cohort_var <- pseudo %>%
    filter(!is.na(cohort)) %>%
    group_by(horizon_bin, cohort) %>%
    summarise(
        n = n(),
        var_pseudo_D = var(pseudo_theta_D, na.rm = TRUE),
        .groups = "drop"
    ) %>%
    arrange(horizon_bin, cohort)

say("")
print(as.data.frame(cohort_var))

# Compute ratios
ratios <- cohort_var %>%
    tidyr::pivot_wider(names_from = cohort, values_from = c(n, var_pseudo_D)) %>%
    mutate(ratio_pre_post = var_pseudo_D_pre_2008 / var_pseudo_D_post_2008)

say("")
say("Variance ratios (pre/post):")
print(as.data.frame(ratios %>% select(horizon_bin, ratio_pre_post)))

# =============================================================================
# H3: 2-3 BIN VERIFICATION
# =============================================================================
say("")
say("=== H3: 2-3 BIN VERIFICATION ===")

# Count treated pairs with n_post = 3, 4, 5 (symmetric)
treated_short <- S1R %>%
    filter(pair %in% baseline$pair, rta == 1, trade > 0) %>%
    select(pair, year) %>%
    inner_join(adopt_lookup, by = "pair") %>%
    filter(year > adopt_yr + 1) %>%
    group_by(pair) %>%
    summarise(n_post = n_distinct(year), .groups = "drop")

say("n_post distribution (treated, symmetric):")
print(table(treated_short$n_post))

say("")
say("Pairs with n_post = 3: %d", sum(treated_short$n_post == 3))
say("Pairs with n_post = 4: %d", sum(treated_short$n_post == 4))
say("Pairs with n_post = 5: %d", sum(treated_short$n_post == 5))

# =============================================================================
# OUTPUT
# =============================================================================
say("")

results <- bind_rows(
    data.frame(item = "pseudo_11plus_n", value = nrow(pseudo_11plus)),
    data.frame(item = "treated_11plus_n", value = nrow(treated_11plus)),
    data.frame(item = "overlap_years", value = length(overlap)),
    data.frame(item = "disjoint", value = ifelse(length(overlap) == 0, 1, 0)),
    cohort_var %>%
        mutate(item = paste0("var_", horizon_bin, "_", cohort)) %>%
        select(item, value = var_pseudo_D),
    ratios %>%
        filter(!is.na(ratio_pre_post)) %>%
        mutate(item = paste0("ratio_", horizon_bin)) %>%
        select(item, value = ratio_pre_post)
)

write.csv(results, file.path(RTA_ROOT, "output/V3_horizon_cohort.csv"), row.names = FALSE)

# Sidecar
code_sha <- get_sha256("code/validation/V3_horizon_cohort.R")
writeLines(c(
    "FILE:      V3_horizon_cohort.csv",
    sprintf("SHA256:    %s", get_sha256("output/V3_horizon_cohort.csv")),
    sprintf("PRODUCER:  code/validation/V3_horizon_cohort.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S18_null_stack.rds, data/S5R_bhat.rds, data/S1R_ppml.rds",
    "",
    "H1: 11+ BIN DISJUNCTION",
    sprintf("  Pseudo 11+:  %d pairs, adoption %d-%d", nrow(pseudo_11plus), pseudo_years[1], pseudo_years[2]),
    sprintf("  Treated 11+: %d pairs, adoption %d-%d", nrow(treated_11plus), treated_years[1], treated_years[2]),
    sprintf("  Overlap:     %d years", length(overlap)),
    sprintf("  DISJOINT:    %s", ifelse(length(overlap) == 0, "YES", "NO")),
    "",
    "H2: COHORT VARIANCE RATIOS (pre/post)",
    sprintf("  2-3:  %.3f", ratios$ratio_pre_post[ratios$horizon_bin == "2-3"]),
    sprintf("  4-5:  %.3f", ratios$ratio_pre_post[ratios$horizon_bin == "4-5"]),
    sprintf("  6-10: %.3f", ratios$ratio_pre_post[ratios$horizon_bin == "6-10"]),
    "",
    "INV-025: Horizon-cohort disjunction documented",
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/V3_horizon_cohort.csv.sidecar"))

say("")
say("Wrote output/V3_horizon_cohort.csv")
say("Done: %s", format(Sys.time()))
