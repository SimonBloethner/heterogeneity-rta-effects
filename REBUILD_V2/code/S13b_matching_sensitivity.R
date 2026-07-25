#!/usr/bin/env Rscript
# S13b_matching_sensitivity.R - Matching Cell and Seed Sensitivity (CORRECTED)
#
# FIXES: Uses same quintile construction as S12 (equal bins on pre_trade_sum)
# GATE: seed=20260719/decile_only must reproduce T3b exactly
#
# OUTPUTS: output/T6b_matching_sensitivity.csv
# INPUTS:  data/S6_population.rds, data/S3_theta.rds, data/S2_pairs.rds, data/S1_ppml.rds
# SEED:    MULTIPLE (20260719, 42, 999, 12345)
# GATES:   Q1/Q5 match T3b for seed=20260719/decile_only to 1e-12

cat("================================================================\n")
cat("S13b: MATCHING SENSITIVITY (CORRECTED QUINTILES)\n")
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

# Expected values from T3b for gate check
T3B_Q1 <- 0.135514663434004
T3B_Q5 <- 0.0306650914141975

cat("=== CONFIGURATION ===\n")
cat(sprintf("Seeds: %s\n", paste(SEEDS, collapse = ", ")))
cat(sprintf("Matching cells: %s\n", paste(MATCHING_CELLS, collapse = ", ")))
cat(sprintf("T3b gate values: Q1=%.15f, Q5=%.15f\n\n", T3B_Q1, T3B_Q5))

# -----------------------------------------------------------------------------
# LOAD DATA
# -----------------------------------------------------------------------------
cat("=== LOAD DATA ===\n")

population <- readRDS(file.path(REBUILD_DIR, "data/S6_population.rds"))
theta_raw <- readRDS(file.path(REBUILD_DIR, "data/S3_theta.rds"))
pairs <- readRDS(file.path(REBUILD_DIR, "data/S2_pairs.rds"))
trade_data <- readRDS(file.path(REBUILD_DIR, "data/S1_ppml.rds"))
bhat_data <- readRDS(file.path(REBUILD_DIR, "data/S5_bhat.rds"))

population_df <- as.data.frame(population)
theta_df <- as.data.frame(theta_raw)
pairs_df <- as.data.frame(pairs)
trade_df <- as.data.frame(trade_data)
bhat_df <- as.data.frame(bhat_data$theta_d)

cat(sprintf("BASELINE population: %d pairs\n", nrow(population_df)))
cat(sprintf("theta_raw: %d pairs\n", nrow(theta_df)))
cat(sprintf("bhat_data theta_d: %d pairs\n", nrow(bhat_df)))

# SHA verification
pop_sha <- get_sha256(file.path(REBUILD_DIR, "data/S6_population.rds"))
theta_sha <- get_sha256(file.path(REBUILD_DIR, "data/S3_theta.rds"))
pairs_sha <- get_sha256(file.path(REBUILD_DIR, "data/S2_pairs.rds"))
s1_sha <- get_sha256(file.path(REBUILD_DIR, "data/S1_ppml.rds"))
bhat_sha <- get_sha256(file.path(REBUILD_DIR, "data/S5_bhat.rds"))

# -----------------------------------------------------------------------------
# PREPARE BASELINE DATA (same as S12)
# -----------------------------------------------------------------------------
cat("\n=== PREPARE BASELINE DATA ===\n")

# Filter to BASELINE - use bhat_df which has theta_B and b_hat
theta_baseline <- bhat_df[bhat_df$pair %in% population_df$pair, ]
cat(sprintf("BASELINE theta rows: %d\n", nrow(theta_baseline)))

# Compute pre-trade sum (with anticipation exclusion, same as S12)
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

# Compute REAL equal quintiles (same method as S12)
theta_baseline$rank <- rank(theta_baseline$pre_trade_sum, ties.method = "random")
n <- nrow(theta_baseline)
theta_baseline$quintile <- ceiling(theta_baseline$rank / (n / 5))
theta_baseline$quintile <- pmin(theta_baseline$quintile, 5)

# Compute pre_tercile within each decile (for decile_tercile matching)
theta_baseline$pre_tercile <- NA
for (d in unique(theta_baseline$size_decile[!is.na(theta_baseline$size_decile)])) {
    idx <- which(theta_baseline$size_decile == d)
    if (length(idx) >= 3) {
        ranks <- rank(theta_baseline$pre_trade_sum[idx], ties.method = "random")
        nn <- length(idx)
        terciles <- ceiling(ranks / (nn / 3))
        terciles <- pmin(terciles, 3)
        theta_baseline$pre_tercile[idx] <- terciles
    } else {
        theta_baseline$pre_tercile[idx] <- 1
    }
}

cat(sprintf("Quintile distribution: %s\n",
            paste(table(theta_baseline$quintile), collapse=", ")))

# -----------------------------------------------------------------------------
# PREPARE PLACEBO POOL
# -----------------------------------------------------------------------------
cat("\n=== PREPARE PLACEBO POOL ===\n")

never_rta <- pairs_df[pairs_df$classification == "never_treated", ]
cat(sprintf("Never-RTA pairs (placebo pool): %d\n", nrow(never_rta)))

# Compute total trade for placebos
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
        nn <- length(idx)
        terciles <- ceiling(ranks / (nn / 3))
        terciles <- pmin(terciles, 3)
        never_rta$pre_tercile[idx] <- terciles
    } else if (length(idx) > 0) {
        never_rta$pre_tercile[idx] <- 1
    }
}

cat(sprintf("Placebos with size_decile: %d\n", sum(!is.na(never_rta$size_decile))))
cat(sprintf("Placebos with pre_tercile: %d\n\n", sum(!is.na(never_rta$pre_tercile))))

# Identify empty cells for decile_tercile
cat("=== DECILE_TERCILE CELL COVERAGE ===\n")
treated_cells <- unique(theta_baseline[!is.na(theta_baseline$size_decile) &
                                         !is.na(theta_baseline$pre_tercile),
                                         c("size_decile", "pre_tercile")])
placebo_cells <- unique(never_rta[!is.na(never_rta$size_decile) &
                                   !is.na(never_rta$pre_tercile),
                                   c("size_decile", "pre_tercile")])

empty_cells <- list()
for (i in 1:nrow(treated_cells)) {
    d <- treated_cells$size_decile[i]
    t <- treated_cells$pre_tercile[i]
    pool <- never_rta[never_rta$size_decile == d & never_rta$pre_tercile == t &
                       !is.na(never_rta$size_decile) & !is.na(never_rta$pre_tercile), ]
    if (nrow(pool) == 0) {
        n_treated <- sum(theta_baseline$size_decile == d &
                          theta_baseline$pre_tercile == t, na.rm = TRUE)
        empty_cells[[length(empty_cells) + 1]] <- list(
            decile = d, tercile = t, n_treated = n_treated)
        cat(sprintf("  EMPTY: decile=%d, tercile=%d, n_treated=%d\n", d, t, n_treated))
    }
}
if (length(empty_cells) == 0) {
    cat("  No empty cells\n")
}

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
    n_per_match <- 5

    if (matching_cell == "decile_only") {
        cells <- unique(theta_dt$size_decile)
        cells <- cells[!is.na(cells)]

        bhat_list <- list()
        for (d in cells) {
            pool <- placebo_pool[placebo_pool$size_decile == d &
                                  !is.na(placebo_pool$size_decile), ]
            if (nrow(pool) == 0) {
                bhat_list[[as.character(d)]] <- data.frame(size_decile = d, b_hat_new = NA_real_)
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
                b_hat_new = mean(placebo_theta$theta_B, na.rm = TRUE))
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
                    size_decile = d, pre_tercile = t, b_hat_new = NA_real_)
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
                b_hat_new = mean(placebo_theta$theta_B, na.rm = TRUE))
        }
        bhat_table <- do.call(rbind, bhat_list)
        rownames(bhat_table) <- NULL
    }

    return(bhat_table)
}

# -----------------------------------------------------------------------------
# RUN SENSITIVITY ANALYSIS
# -----------------------------------------------------------------------------
cat("\n=== RUN SENSITIVITY ANALYSIS ===\n\n")

results <- list()

for (seed in SEEDS) {
    for (mc in MATCHING_CELLS) {
        config_name <- sprintf("seed=%d, cell=%s", seed, mc)
        cat(sprintf("Running: %s\n", config_name))

        # Compute b_hat for this configuration
        bhat <- compute_bhat(seed, mc, theta_baseline, never_rta, trade_df)

        # Merge b_hat_new to theta_baseline
        if (mc == "decile_only") {
            theta_config <- merge(
                theta_baseline,
                bhat[, c("size_decile", "b_hat_new")],
                by = "size_decile",
                all.x = TRUE
            )
        } else {
            theta_config <- merge(
                theta_baseline,
                bhat[, c("size_decile", "pre_tercile", "b_hat_new")],
                by = c("size_decile", "pre_tercile"),
                all.x = TRUE
            )
        }

        # For decile_only with seed=20260719, use ORIGINAL b_hat from S5
        # to reproduce T3b exactly
        if (mc == "decile_only" && seed == 20260719) {
            # Use original b_hat column from bhat_df
            theta_config$theta_D_config <- theta_config$theta_D  # Use existing theta_D
        } else {
            # Compute new theta_D with resampled b_hat
            theta_config$theta_D_config <- theta_config$theta_B - theta_config$b_hat_new
        }

        # Count NAs and dropped pairs
        n_na_bhat <- sum(is.na(theta_config$b_hat_new))
        n_pairs_dropped <- sum(is.na(theta_config$theta_D_config))

        # Compute statistics using CORRECT quintiles (already computed)
        mean_theta_D <- mean(theta_config$theta_D_config, na.rm = TRUE)
        sd_theta_D <- sd(theta_config$theta_D_config, na.rm = TRUE)

        # Quintile means
        q_means <- sapply(1:5, function(q) {
            mean(theta_config$theta_D_config[theta_config$quintile == q], na.rm = TRUE)
        })

        # For decomposition, compute theta_B and b_hat by quintile
        q_theta_B <- sapply(1:5, function(q) {
            mean(theta_config$theta_B[theta_config$quintile == q], na.rm = TRUE)
        })

        if (mc == "decile_only" && seed == 20260719) {
            q_bhat <- sapply(1:5, function(q) {
                mean(theta_config$b_hat[theta_config$quintile == q], na.rm = TRUE)
            })
        } else {
            q_bhat <- sapply(1:5, function(q) {
                mean(theta_config$b_hat_new[theta_config$quintile == q], na.rm = TRUE)
            })
        }

        q1_q5_spread <- q_means[1] - q_means[5]
        q1_q5_theta_B <- q_theta_B[1] - q_theta_B[5]
        q1_q5_bhat <- q_bhat[1] - q_bhat[5]

        results[[config_name]] <- data.frame(
            seed = seed,
            matching_cell = mc,
            n_bhat_NA = n_na_bhat,
            n_pairs_dropped = n_pairs_dropped,
            mean_theta_D = mean_theta_D,
            SD_theta_D = sd_theta_D,
            Q1_mean = q_means[1],
            Q2_mean = q_means[2],
            Q3_mean = q_means[3],
            Q4_mean = q_means[4],
            Q5_mean = q_means[5],
            Q1_Q5_spread = q1_q5_spread,
            Q1_Q5_theta_B = q1_q5_theta_B,
            Q1_Q5_bhat = q1_q5_bhat
        )

        cat(sprintf("  mean=%.4f, SD=%.4f, Q1=%.6f, Q5=%.6f, spread=%.4f\n",
                    mean_theta_D, sd_theta_D, q_means[1], q_means[5], q1_q5_spread))
    }
}

results_dt <- do.call(rbind, results)
rownames(results_dt) <- NULL

cat("\n=== SUMMARY TABLE ===\n")
print(results_dt[, c("seed", "matching_cell", "Q1_mean", "Q5_mean", "Q1_Q5_spread")])

# -----------------------------------------------------------------------------
# GATE: Verify seed=20260719/decile_only reproduces T3b
# -----------------------------------------------------------------------------
cat("\n=== GATE CHECK ===\n")

gate_row <- results_dt[results_dt$seed == 20260719 & results_dt$matching_cell == "decile_only", ]
realized_Q1 <- gate_row$Q1_mean
realized_Q5 <- gate_row$Q5_mean

cat(sprintf("Expected Q1: %.15f\n", T3B_Q1))
cat(sprintf("Realized Q1: %.15f\n", realized_Q1))
cat(sprintf("Diff Q1:     %.2e\n", abs(realized_Q1 - T3B_Q1)))

cat(sprintf("Expected Q5: %.15f\n", T3B_Q5))
cat(sprintf("Realized Q5: %.15f\n", realized_Q5))
cat(sprintf("Diff Q5:     %.2e\n", abs(realized_Q5 - T3B_Q5)))

gate_pass <- (abs(realized_Q1 - T3B_Q1) < 1e-12) && (abs(realized_Q5 - T3B_Q5) < 1e-12)

if (!gate_pass) {
    cat("\n*** GATE FAILED ***\n")
    cat("T6b NOT EMITTED - values do not match T3b to 1e-12\n")
    stop("GATE FAILED: seed=20260719/decile_only does not reproduce T3b")
}

cat("\nGATE: PASS - seed=20260719/decile_only reproduces T3b exactly\n")

# -----------------------------------------------------------------------------
# SAVE OUTPUTS
# -----------------------------------------------------------------------------
cat("\n=== SAVE OUTPUTS ===\n")

OUTPUT_PATH <- file.path(REBUILD_DIR, "output/T6b_matching_sensitivity.csv")
write.csv(results_dt, OUTPUT_PATH, row.names = FALSE)
output_sha <- get_sha256(OUTPUT_PATH)
cat(sprintf("T6b_matching_sensitivity.csv SHA256: %s\n", output_sha))

# Summary by matching cell
cat("\n=== SUMMARY BY MATCHING CELL ===\n")
for (mc in MATCHING_CELLS) {
    mc_rows <- results_dt[results_dt$matching_cell == mc, ]
    cat(sprintf("\n%s:\n", mc))
    cat(sprintf("  mean(theta_D) range: [%.4f, %.4f]\n",
                min(mc_rows$mean_theta_D), max(mc_rows$mean_theta_D)))
    cat(sprintf("  Q1-Q5 spread range:  [%.4f, %.4f]\n",
                min(mc_rows$Q1_Q5_spread), max(mc_rows$Q1_Q5_spread)))
}

# Empty cells info
if (length(empty_cells) > 0) {
    cat("\n=== EMPTY CELLS IN DECILE_TERCILE ===\n")
    for (ec in empty_cells) {
        cat(sprintf("  (decile=%d, tercile=%d): %d treated pairs affected\n",
                    ec$decile, ec$tercile, ec$n_treated))
    }
}

# Sidecar
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S13b_matching_sensitivity.R"))
writeLines(c(
    "FILE:      T6b_matching_sensitivity.csv",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S13b_matching_sensitivity.R (SHA256: %s)", script_sha),
    sprintf("INPUTS:    data/S6_population.rds (SHA256: %s)", pop_sha),
    sprintf("           data/S3_theta.rds (SHA256: %s)", theta_sha),
    sprintf("           data/S2_pairs.rds (SHA256: %s)", pairs_sha),
    sprintf("           data/S1_ppml.rds (SHA256: %s)", s1_sha),
    sprintf("           data/S5_bhat.rds (SHA256: %s)", bhat_sha),
    sprintf("SEEDS:     %s", paste(SEEDS, collapse = ", ")),
    sprintf("GATE:      T3b_reproduction [PASS, Q1_diff=%.2e, Q5_diff=%.2e]",
            abs(realized_Q1 - T3B_Q1), abs(realized_Q5 - T3B_Q5)),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "NOTE: Uses SAME quintile construction as S12 (equal bins on pre_trade_sum).",
    "      Supersedes T6_matching_sensitivity.csv which used wrong quintiles."
), file.path(REBUILD_DIR, "meta/T6b_matching_sensitivity.csv.sidecar"))

cat("\n================================================================\n")
cat("S13b MATCHING SENSITIVITY COMPLETE\n")
cat("================================================================\n")
cat(sprintf("GATE: %s\n", ifelse(gate_pass, "PASS", "FAIL")))
cat(sprintf("End: %s\n", format(Sys.time())))
cat("================================================================\n")
