#!/usr/bin/env Rscript
# =============================================================================
# S21_section3_inputs.R - Section 3 Manuscript Inputs (BLOCKING)
# =============================================================================
# OUTPUT:  output/T13_section3_inputs.csv
# INPUTS:  data/S1R_ppml.rds, data/S5R_bhat.rds, ITPDE_total.rds
# PURPOSE: Census reprint, world-trade share, top-ten pairs
#          These numbers appear in Section 3 of the manuscript
# STATUS:  BLOCKING - no producer existed prior to this script
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
say("S21: SECTION 3 INPUTS")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load data
S1R <- readRDS("data/S1R_ppml.rds")
S5R <- readRDS("data/S5R_bhat.rds")
baseline <- S5R$baseline
df_full <- readRDS("/groups/m-larch/bt307958/tails/data/ITPDE_total.rds")

say("Baseline pairs: %d", nrow(baseline))

# =============================================================================
# I1: CENSUS
# =============================================================================
say("")
say("=== I1: SAMPLE SELECTION CENSUS ===")

switcher_lookup <- S1R %>%
    filter(!is.na(adoption_year)) %>%
    select(pair, adoption_year) %>%
    distinct()

# R0: All pairs
n_R0 <- S1R %>% select(pair) %>% distinct() %>% nrow()

# R1: Switchers
n_R1 <- nrow(switcher_lookup)

# R2: Has pre-period trade
pre_pairs <- S1R %>%
    filter(pair %in% switcher_lookup$pair, rta == 0, trade > 0) %>%
    select(pair) %>% distinct()
n_R2 <- nrow(pre_pairs)

# R3: Has post-period trade
post_pairs <- S1R %>%
    filter(pair %in% pre_pairs$pair, rta == 1, trade > 0) %>%
    select(pair) %>% distinct()
n_R3 <- nrow(post_pairs)

# R4: Has y_hat_0 > 0 in both pre and post
yhat_pre <- S1R %>%
    filter(pair %in% post_pairs$pair, rta == 0, trade > 0, y_hat_0 > 0) %>%
    select(pair) %>% distinct()
yhat_post <- S1R %>%
    filter(pair %in% post_pairs$pair, rta == 1, trade > 0, y_hat_0 > 0) %>%
    select(pair) %>% distinct()
pairs_R4 <- intersect(yhat_pre$pair, yhat_post$pair)
n_R4 <- length(pairs_R4)

# R5: n_post >= 3 (symmetric window)
post_length <- S1R %>%
    filter(pair %in% pairs_R4, rta == 1, trade > 0) %>%
    select(pair, year) %>%
    left_join(switcher_lookup, by = "pair") %>%
    filter(year > adoption_year + 1) %>%
    group_by(pair) %>%
    summarise(n_post = n_distinct(year), .groups = "drop") %>%
    filter(n_post >= 3)
n_R5 <- nrow(post_length)

# R6: 50/50 estimation split
n_R6 <- nrow(baseline)

census <- data.frame(
    Rule = c("R0", "R1", "R2", "R3", "R4", "R5", "R6"),
    Description = c(
        "All pairs in ITPD-E",
        "Switcher pairs (have adoption_year)",
        "Has pre-period trade > 0",
        "Has post-period trade > 0",
        "Has y_hat_0 > 0 in pre and post",
        "n_post >= 3 (symmetric window)",
        "50/50 estimation split"
    ),
    Remaining = c(n_R0, n_R1, n_R2, n_R3, n_R4, n_R5, n_R6),
    Dropped = c(NA, n_R0-n_R1, n_R1-n_R2, n_R2-n_R3, n_R3-n_R4, n_R4-n_R5, n_R5-n_R6)
)

say("")
print(census)

# =============================================================================
# I2: SHARE OF WORLD TRADE
# =============================================================================
say("")
say("=== I2: WORLD TRADE SHARE ===")

# Total international trade 2015 (units: millions USD)
intl_2015 <- df_full %>%
    filter(year == 2015, exporter != importer, trade > 0)
total_intl_2015 <- sum(intl_2015$trade)

say("World international goods trade (2015): %.2f trillion USD", total_intl_2015 / 1e6)

# Canonical pairs total trade 2015
intl_2015 <- intl_2015 %>%
    mutate(pair = paste(pmin(exporter, importer), pmax(exporter, importer), sep = "_"))

canon_2015 <- intl_2015 %>%
    filter(pair %in% baseline$pair)

canon_trade_2015 <- sum(canon_2015$trade)
share_2015 <- canon_trade_2015 / total_intl_2015

say("Canonical pair trade (2015): %.2f trillion USD", canon_trade_2015 / 1e6)
say("Share of world international: %.1f%%", share_2015 * 100)

# Total pre-trade from baseline (all pre-adoption years)
total_pre_trade <- sum(baseline$pre_trade)
say("")
say("Canonical pre_trade (all years): %.2f trillion USD", total_pre_trade / 1e6)

# =============================================================================
# I3: TOP 10 PAIRS
# =============================================================================
say("")
say("=== I3: TOP 10 PAIRS BY PRE-ADOPTION TRADE ===")

top10 <- baseline %>%
    arrange(desc(pre_trade)) %>%
    head(10) %>%
    select(pair, adoption_year, pre_trade) %>%
    mutate(
        pre_trade_B = pre_trade / 1e3,  # billions USD
        pct_of_canon = 100 * pre_trade / total_pre_trade
    )

say("")
print(as.data.frame(top10 %>% select(pair, adoption_year, pre_trade_B, pct_of_canon)))

top10_share <- sum(top10$pre_trade) / total_pre_trade
say("")
say("Top 10 combined: %.1f%% of canonical pre-trade", top10_share * 100)

# =============================================================================
# OUTPUT
# =============================================================================
say("")

# Combine key numbers
section3 <- data.frame(
    item = c(
        "n_canonical", "n_all_pairs", "n_switchers",
        "world_trade_2015_T", "canon_trade_2015_T", "share_world_pct",
        "canon_pre_trade_T", "top10_share_pct",
        paste0("top", 1:10, "_pair"), paste0("top", 1:10, "_trade_B")
    ),
    value = c(
        n_R6, n_R0, n_R1,
        total_intl_2015 / 1e6, canon_trade_2015 / 1e6, share_2015 * 100,
        total_pre_trade / 1e6, top10_share * 100,
        top10$pair, top10$pre_trade_B
    ),
    stringsAsFactors = FALSE
)

write.csv(section3, "output/T13_section3_inputs.csv", row.names = FALSE)

# Also write top10 as separate CSV for manuscript
write.csv(top10 %>% select(pair, adoption_year, pre_trade_B, pct_of_canon),
          "output/T13_top10_pairs.csv", row.names = FALSE)

# Sidecar
code_sha <- get_sha256("code/S21_section3_inputs.R")
writeLines(c(
    "FILE:      T13_section3_inputs.csv",
    sprintf("SHA256:    %s", get_sha256("output/T13_section3_inputs.csv")),
    sprintf("PRODUCER:  code/S21_section3_inputs.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S1R_ppml.rds, data/S5R_bhat.rds, ITPDE_total.rds",
    sprintf("SEED:      %d", SEED),
    "",
    "STATUS:    BLOCKING - these numbers appear in Section 3",
    "",
    "CENSUS:",
    sprintf("  R0 (all pairs):    %d", n_R0),
    sprintf("  R1 (switchers):    %d", n_R1),
    sprintf("  R6 (canonical):    %d", n_R6),
    "",
    "WORLD TRADE (2015):",
    sprintf("  Total international: %.2f T USD", total_intl_2015 / 1e6),
    sprintf("  Canonical pairs:     %.2f T USD", canon_trade_2015 / 1e6),
    sprintf("  Share:               %.1f%%", share_2015 * 100),
    "",
    sprintf("TOP 10 SHARE: %.1f%%", top10_share * 100),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T13_section3_inputs.csv.sidecar")

writeLines(c(
    "FILE:      T13_top10_pairs.csv",
    sprintf("SHA256:    %s", get_sha256("output/T13_top10_pairs.csv")),
    sprintf("PRODUCER:  code/S21_section3_inputs.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S5R_bhat.rds",
    "",
    "Top 10 canonical pairs by pre-adoption trade",
    sprintf("Combined share: %.1f%%", top10_share * 100),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T13_top10_pairs.csv.sidecar")

say("")
say("Wrote output/T13_section3_inputs.csv")
say("Wrote output/T13_top10_pairs.csv")
say("Done: %s", format(Sys.time()))
