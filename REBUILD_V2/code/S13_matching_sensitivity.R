#!/usr/bin/env Rscript
# S13_matching_sensitivity.R - Matching Cell and Seed Sensitivity Analysis
#
# Tests 8 configurations:
#   2 matching cells: {decile_only, (decile, pre_tercile)}
#   4 seeds: {20260719, 42, 999, 12345}
#
# OUTPUTS: output/T6_matching_sensitivity.csv
# INPUTS:  data/S6_population.rds, data/S3_theta.rds, data/S2_pairs.rds, data/S1_ppml.rds
# SEED:    MULTIPLE (20260719, 42, 999, 12345)
# GATES:   8 configurations complete; all have finite gradient

cat("================================================================\n")
cat("S13: MATCHING CELL AND SEED SENSITIVITY\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    strsplit(result, " ")[[1]][1]
}

# -----------------------------------------------------------------------------
# CONFIGURATION
# -----------------------------------------------------------------------------
SEEDS <- c(20260719, 42, 999, 12345)
MATCHING_CELLS <- c("decile_only", "decile_tercile")

cat("=== CONFIGURATION ===\n")
cat(sprintf("Seeds: %s\n", paste(SEEDS, collapse = ", ")))
cat(sprintf("Matching cells: %s\n\n", paste(MATCHING_CELLS, collapse = ", ")))

# -----------------------------------------------------------------------------
# LOAD DATA
# -----------------------------------------------------------------------------
cat("=== LOAD DATA ===\n")

population <- readRDS(file.path(REBUILD_DIR, "data/S6_population.rds"))
theta_raw <- readRDS(file.path(REBUILD_DIR, "data/S3_theta.rds"))
pairs <- readRDS(file.path(REBUILD_DIR, "data/S2_pairs.rds"))
trade_data <- readRDS(file.path(REBUILD_DIR, "data/S1_ppml.rds"))

population_df <- as.data.frame(population)
theta_df <- as.data.frame(theta_raw)
pairs_df <- as.data.frame(pairs)
trade_df <- as.data.frame(trade_data)

cat(sprintf("BASELINE population: %d pairs\n", nrow(population_df)))
cat(sprintf("theta_raw: %d pairs\n", nrow(theta_df)))
cat(sprintf("All pairs: %d\n", nrow(pairs_df)))
cat(sprintf("Trade data: %d rows\n\n", nrow(trade_df)))

# SHA verification
pop_sha <- get_sha256(file.path(REBUILD_DIR, "data/S6_population.rds"))
theta_sha <- get_sha256(file.path(REBUILD_DIR, "data/S3_theta.rds"))
pairs_sha <- get_sha256(file.path(REBUILD_DIR, "data/S2_pairs.rds"))
s1_sha <- get_sha256(file.path(REBUILD_DIR, "data/S1_ppml.rds"))

# -----------------------------------------------------------------------------
# PREPARE BASELINE THETA
# -----------------------------------------------------------------------------
cat("=== PREPARE BASELINE THETA ===\n")

# Filter theta to BASELINE - theta_df already has size_decile and adoption_year
theta_baseline <- theta_df[theta_df$pair %in% population_df$pair, ]
cat(sprintf("BASELINE theta rows: %d\n", nrow(theta_baseline)))

# Compute pre-trade sum for matching (with anticipation exclusion)
baseline_trade <- merge(
    theta_baseline[, c("pair", "adoption_year")],
    trade_df[, c("pair", "year", "trade")],
    by = "pair"
)
baseline_trade$is_pre <- with(baseline_trade, year < adoption_year - 1 & trade > 0)
pre_trade <- aggregate(trade ~ pair, data = baseline_trade[baseline_trade$is_pre, ], sum)
names(pre_trade) <- c("pair", "pre_trade_sum")

theta_baseline <- merge(theta_baseline, pre_trade, by = "pair", all.x = TRUE)
theta_baseline$pre_trade_sum[is.na(theta_baseline$pre_trade_sum)] <- 0

# Compute pre_tercile within each decile
theta_baseline$pre_tercile <- NA
for (d in unique(theta_baseline$size_decile[!is.na(theta_baseline$size_decile)])) {
    idx <- which(theta_baseline$size_decile == d)
    if (length(idx) >= 3) {
        ranks <- rank(theta_baseline$pre_trade_sum[idx], ties.method = "random")
        n <- length(idx)
        terciles <- ceiling(ranks / (n / 3))
        terciles <- pmin(terciles, 3)
        theta_baseline$pre_tercile[idx] <- terciles
    } else {
        theta_baseline$pre_tercile[idx] <- 1
    }
}

cat(sprintf("Pairs with size_decile: %d\n", sum(!is.na(theta_baseline$size_decile))))
cat(sprintf("Pairs with pre_tercile: %d\n\n", sum(!is.na(theta_baseline$pre_tercile))))

# -----------------------------------------------------------------------------
# IDENTIFY NEVER-RTA PAIRS FOR PLACEBO POOL
# -----------------------------------------------------------------------------
cat("=== PREPARE PLACEBO POOL ===\n")

never_rta <- pairs_df[pairs_df$classification == "never_treated", ]
cat(sprintf("Never-RTA pairs (placebo pool): %d\n", nrow(never_rta)))

# Compute total trade for placebos (use placebo_total to avoid column name collision)
placebo_trade_raw <- merge(
    never_rta[, c("pair", "size_decile")],
    trade_df[trade_df$trade > 0, c("pair", "trade")],
    by = "pair"
)

if (nrow(placebo_trade_raw) > 0) {
    placebo_trade <- aggregate(trade ~ pair, data = placebo_trade_raw, sum)
    names(placebo_trade) <- c("pair", "placebo_total")
    never_rta <- merge(never_rta, placebo_trade, by = "pair", all.x = TRUE)
    never_rta$placebo_total[is.na(never_rta$placebo_total)] <- 0
} else {
    never_rta$placebo_total <- rep(0, nrow(never_rta))
}

# Compute tercile within each decile for placebos
never_rta$pre_tercile <- NA
for (d in unique(never_rta$size_decile[!is.na(never_rta$size_decile)])) {
    idx <- which(never_rta$size_decile == d)
    if (length(idx) >= 3) {
        ranks <- rank(never_rta$placebo_total[idx], ties.method = "random")
        n <- length(idx)
        terciles <- ceiling(ranks / (n / 3))
        terciles <- pmin(terciles, 3)
        never_rta$pre_tercile[idx] <- terciles
    } else if (length(idx) > 0) {
        never_rta$pre_tercile[idx] <- 1
    }
}

cat(sprintf("Placebos with size_decile: %d\n", sum(!is.na(never_rta$size_decile))))
cat(sprintf("Placebos with pre_tercile: %d\n\n", sum(!is.na(never_rta$pre_tercile))))

# -----------------------------------------------------------------------------
# HELPER: Compute theta_B for placebo pairs
# -----------------------------------------------------------------------------
compute_placebo_theta <- function(placebo_pairs, trade_dt) {
    results <- data.frame(pair = character(), theta_B = numeric(), stringsAsFactors = FALSE)

    for (p in placebo_pairs) {
        pair_trade <- trade_dt[trade_dt$pair == p & trade_dt$trade > 0, ]
        if (nrow(pair_trade) < 4) {
            results <- rbind(results, data.frame(pair = p, theta_B = NA_real_))
            next
        }

        median_year <- median(pair_trade$year)
        pre <- pair_trade$trade[pair_trade$year < median_year]
        post <- pair_trade$trade[pair_trade$year >= median_year]

        if (length(pre) == 0 || length(post) == 0) {
            results <- rbind(results, data.frame(pair = p, theta_B = NA_real_))
            next
        }

        theta_B <- log(mean(post)) - log(mean(pre))
        results <- rbind(results, data.frame(pair = p, theta_B = theta_B))
    }

    return(results)
}

# -----------------------------------------------------------------------------
# FUNCTION: Compute b_hat for a configuration
# -----------------------------------------------------------------------------
compute_bhat <- function(seed, matching_cell, theta_dt, placebo_pool, trade_dt) {
    set.seed(seed)
    n_per_match <- 5  # placebos per matching cell

    if (matching_cell == "decile_only") {
        cells <- unique(theta_dt$size_decile)
        cells <- cells[!is.na(cells)]

        bhat_list <- list()
        for (d in cells) {
            pool <- placebo_pool[placebo_pool$size_decile == d & !is.na(placebo_pool$size_decile), ]
            if (nrow(pool) == 0) {
                bhat_list[[as.character(d)]] <- data.frame(size_decile = d, b_hat = NA_real_)
                next
            }
            if (nrow(pool) < n_per_match) {
                sampled <- pool$pair
            } else {
                sampled <- sample(pool$pair, n_per_match)
            }

            placebo_theta <- compute_placebo_theta(sampled, trade_dt)
            bhat_list[[as.character(d)]] <- data.frame(
                size_decile = d,
                b_hat = mean(placebo_theta$theta_B, na.rm = TRUE))
        }
        bhat_table <- do.call(rbind, bhat_list)
        rownames(bhat_table) <- NULL

    } else {  # decile_tercile
        cells <- unique(theta_dt[!is.na(theta_dt$size_decile) & !is.na(theta_dt$pre_tercile),
                                  c("size_decile", "pre_tercile")])

        bhat_list <- list()
        for (i in 1:nrow(cells)) {
            d <- cells$size_decile[i]
            t <- cells$pre_tercile[i]

            pool <- placebo_pool[placebo_pool$size_decile == d &
                                  placebo_pool$pre_tercile == t &
                                  !is.na(placebo_pool$size_decile) &
                                  !is.na(placebo_pool$pre_tercile), ]
            if (nrow(pool) == 0) {
                bhat_list[[paste(d, t, sep = "_")]] <- data.frame(
                    size_decile = d, pre_tercile = t, b_hat = NA_real_)
                next
            }
            if (nrow(pool) < n_per_match) {
                sampled <- pool$pair
            } else {
                sampled <- sample(pool$pair, n_per_match)
            }

            placebo_theta <- compute_placebo_theta(sampled, trade_dt)
            bhat_list[[paste(d, t, sep = "_")]] <- data.frame(
                size_decile = d, pre_tercile = t,
                b_hat = mean(placebo_theta$theta_B, na.rm = TRUE))
        }
        bhat_table <- do.call(rbind, bhat_list)
        rownames(bhat_table) <- NULL
    }

    return(bhat_table)
}

# -----------------------------------------------------------------------------
# RUN SENSITIVITY ANALYSIS
# -----------------------------------------------------------------------------
cat("=== RUN SENSITIVITY ANALYSIS ===\n\n")

results <- list()

for (seed in SEEDS) {
    for (mc in MATCHING_CELLS) {
        config_name <- sprintf("seed=%d, cell=%s", seed, mc)
        cat(sprintf("Running: %s\n", config_name))

        # Compute b_hat for this configuration
        bhat <- compute_bhat(seed, mc, theta_baseline, never_rta, trade_df)

        # Merge b_hat to theta_baseline
        if (mc == "decile_only") {
            theta_config <- merge(
                theta_baseline[, c("pair", "size_decile", "pre_tercile",
                                   "theta_B", "pre_trade_sum")],
                bhat[, c("size_decile", "b_hat")],
                by = "size_decile",
                all.x = TRUE
            )
        } else {
            theta_config <- merge(
                theta_baseline[, c("pair", "size_decile", "pre_tercile",
                                   "theta_B", "pre_trade_sum")],
                bhat[, c("size_decile", "pre_tercile", "b_hat")],
                by = c("size_decile", "pre_tercile"),
                all.x = TRUE
            )
        }

        # Compute theta_D
        theta_config$theta_D <- theta_config$theta_B - theta_config$b_hat

        # Compute real quintiles
        theta_config$rank <- rank(theta_config$pre_trade_sum, ties.method = "random")
        n <- nrow(theta_config)
        theta_config$quintile <- ceiling(theta_config$rank / (n / 5))
        theta_config$quintile <- pmin(theta_config$quintile, 5)

        # Compute gradient
        gradient <- aggregate(theta_D ~ quintile, data = theta_config,
                              function(x) mean(x, na.rm = TRUE))
        names(gradient) <- c("quintile", "mean_theta_D")
        gradient <- gradient[order(gradient$quintile), ]

        q1 <- gradient$mean_theta_D[gradient$quintile == 1]
        q5 <- gradient$mean_theta_D[gradient$quintile == 5]
        q1_q5_spread <- q1 - q5

        # Count NAs
        n_na_bhat <- sum(is.na(theta_config$b_hat))
        n_na_theta_d <- sum(is.na(theta_config$theta_D))

        results[[config_name]] <- data.frame(
            seed = seed,
            matching_cell = mc,
            Q1_mean = q1,
            Q5_mean = q5,
            Q1_Q5_spread = q1_q5_spread,
            n_na_bhat = n_na_bhat,
            n_na_theta_d = n_na_theta_d
        )

        cat(sprintf("  Q1-Q5 spread: %.4f (NA_bhat=%d, NA_theta_D=%d)\n",
                    q1_q5_spread, n_na_bhat, n_na_theta_d))
    }
}

results_dt <- do.call(rbind, results)
rownames(results_dt) <- NULL

cat("\n=== SUMMARY TABLE ===\n")
print(results_dt)

# -----------------------------------------------------------------------------
# GATES
# -----------------------------------------------------------------------------
cat("\n=== GATES ===\n")

gate_complete <- nrow(results_dt) == 8
cat(sprintf("GATE: 8 configurations complete: %s (%d)\n",
            ifelse(gate_complete, "PASS", "FAIL"), nrow(results_dt)))
stopifnot(gate_complete)

gate_finite <- all(is.finite(results_dt$Q1_Q5_spread))
cat(sprintf("GATE: All gradients finite: %s\n",
            ifelse(gate_finite, "PASS", "FAIL")))
stopifnot(gate_finite)

# -----------------------------------------------------------------------------
# SAVE OUTPUTS
# -----------------------------------------------------------------------------
cat("\n=== SAVE OUTPUTS ===\n")

OUTPUT_PATH <- file.path(REBUILD_DIR, "output/T6_matching_sensitivity.csv")
write.csv(results_dt, OUTPUT_PATH, row.names = FALSE)
output_sha <- get_sha256(OUTPUT_PATH)
cat(sprintf("T6_matching_sensitivity.csv SHA256: %s\n", output_sha))

# Summary statistics
spread_range <- range(results_dt$Q1_Q5_spread)
spread_mean <- mean(results_dt$Q1_Q5_spread)
spread_sd <- sd(results_dt$Q1_Q5_spread)

# Sidecar
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S13_matching_sensitivity.R"))
writeLines(c(
    "FILE:      T6_matching_sensitivity.csv",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S13_matching_sensitivity.R (SHA256: %s)", script_sha),
    sprintf("INPUTS:    data/S6_population.rds (SHA256: %s)", pop_sha),
    sprintf("           data/S3_theta.rds (SHA256: %s)", theta_sha),
    sprintf("           data/S2_pairs.rds (SHA256: %s)", pairs_sha),
    sprintf("           data/S1_ppml.rds (SHA256: %s)", s1_sha),
    sprintf("SEEDS:     %s", paste(SEEDS, collapse = ", ")),
    sprintf("GATE:      8_configurations_complete [PASS, n=%d]", nrow(results_dt)),
    sprintf("GATE:      all_gradients_finite [PASS]"),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "=== SENSITIVITY SUMMARY ===",
    sprintf("Q1-Q5 spread range: [%.4f, %.4f]", spread_range[1], spread_range[2]),
    sprintf("Q1-Q5 spread mean:  %.4f", spread_mean),
    sprintf("Q1-Q5 spread SD:    %.4f", spread_sd)
), file.path(REBUILD_DIR, "meta/T6_matching_sensitivity.csv.sidecar"))

cat("\nOutputs saved.\n")

cat("\n================================================================\n")
cat("S13 MATCHING SENSITIVITY COMPLETE\n")
cat("================================================================\n")
cat(sprintf("Configurations tested: %d\n", nrow(results_dt)))
cat(sprintf("Q1-Q5 spread range: [%.4f, %.4f]\n", spread_range[1], spread_range[2]))
cat(sprintf("Q1-Q5 spread mean:  %.4f\n", spread_mean))
cat(sprintf("Q1-Q5 spread SD:    %.4f\n", spread_sd))
cat(sprintf("End: %s\n", format(Sys.time())))
cat("================================================================\n")
