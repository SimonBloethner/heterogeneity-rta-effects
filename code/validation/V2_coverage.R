#!/usr/bin/env Rscript
# =============================================================================
# V2_coverage.R - Per-Pair Post-Window Coverage (G5)
# =============================================================================
# OUTPUT:  output/V2_coverage.csv
# INPUTS:  data/S1R_ppml.rds, data/S5R_bhat.rds
# PURPOSE: Check post-window coverage for theta estimation
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
say("V2: POST-WINDOW COVERAGE (G5)")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load data
S1R <- readRDS(file.path(RTA_ROOT, "data/S1R_ppml.rds"))
S5R <- readRDS(file.path(RTA_ROOT, "data/S5R_bhat.rds"))
baseline <- S5R$baseline

say("Baseline pairs: %d", nrow(baseline))

# =============================================================================
# COVERAGE ANALYSIS
# =============================================================================
say("")
say("=== POST-WINDOW COVERAGE ===")

# Get adoption year
adopt_lookup <- baseline %>% select(pair, adopt_yr = adoption_year) %>% distinct()

# Post cells per pair
post_coverage <- S1R %>%
    filter(pair %in% baseline$pair, rta == 1) %>%
    select(pair, year, trade, y_hat_0) %>%
    inner_join(adopt_lookup, by = "pair") %>%
    filter(year > adopt_yr + 1) %>%  # symmetric window
    group_by(pair) %>%
    summarise(
        n_post = n(),
        n_positive_trade = sum(trade > 0),
        n_positive_yhat = sum(y_hat_0 > 0),
        coverage = n_positive_trade / n_post,
        .groups = "drop"
    )

say("Post coverage statistics:")
say("  Mean n_post: %.1f", mean(post_coverage$n_post))
say("  Mean coverage: %.3f", mean(post_coverage$coverage))
say("  Min coverage: %.3f", min(post_coverage$coverage))
say("  Pairs with 100%% coverage: %d (%.1f%%)",
    sum(post_coverage$coverage == 1),
    100 * sum(post_coverage$coverage == 1) / nrow(post_coverage))

# Distribution of coverage
say("")
say("Coverage distribution:")
coverage_dist <- cut(post_coverage$coverage,
                     breaks = c(0, 0.5, 0.75, 0.9, 0.99, 1),
                     include.lowest = TRUE)
print(table(coverage_dist))

# G5 gate: require mean coverage >= 0.8
G5_threshold <- 0.80
G5_status <- ifelse(mean(post_coverage$coverage) >= G5_threshold, "PASS", "FAIL")

say("")
say("G5 Gate (mean coverage >= %.2f): %s (%.3f)",
    G5_threshold, G5_status, mean(post_coverage$coverage))

# =============================================================================
# OUTPUT
# =============================================================================
say("")

results <- data.frame(
    item = c("n_pairs", "mean_n_post", "mean_coverage", "min_coverage",
             "n_full_coverage", "pct_full_coverage", "G5_threshold", "G5_status"),
    value = c(nrow(post_coverage), mean(post_coverage$n_post),
              mean(post_coverage$coverage), min(post_coverage$coverage),
              sum(post_coverage$coverage == 1),
              100 * sum(post_coverage$coverage == 1) / nrow(post_coverage),
              G5_threshold, NA),
    stringsAsFactors = FALSE
)
results$value[8] <- G5_status

write.csv(results, file.path(RTA_ROOT, "output/V2_coverage.csv"), row.names = FALSE)

# Sidecar
code_sha <- get_sha256("code/validation/V2_coverage.R")
writeLines(c(
    "FILE:      V2_coverage.csv",
    sprintf("SHA256:    %s", get_sha256("output/V2_coverage.csv")),
    sprintf("PRODUCER:  code/validation/V2_coverage.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S1R_ppml.rds, data/S5R_bhat.rds",
    "",
    sprintf("MEAN COVERAGE: %.3f", mean(post_coverage$coverage)),
    sprintf("FULL COVERAGE: %.1f%%", 100 * sum(post_coverage$coverage == 1) / nrow(post_coverage)),
    sprintf("G5 GATE: %s", G5_status),
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/V2_coverage.csv.sidecar"))

say("")
say("Wrote output/V2_coverage.csv")
say("Done: %s", format(Sys.time()))
