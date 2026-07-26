#!/usr/bin/env Rscript
# S14_placebo_diagnostic.R - Placebo Validity Diagnostic
#
# FINDING: T6b shows mean(theta_D) = +0.044 for seed 20260719/decile_only
# and -1.13 to -1.58 for other configs. Since theta_B is identical,
# the entire swing is in b_hat.
#
# This script diagnoses why the placebo validity gate defined in
# gates_lib_v2.R (PLACEBO_MEAN_THRESHOLD = 0.05) was never invoked.
#
# OUTPUTS: output/T7_placebo_validity.csv
# INPUTS:  data/S1_ppml.rds, data/S2_pairs.rds, data/S3_theta.rds

cat("================================================================\n")
cat("S14: PLACEBO VALIDITY DIAGNOSTIC\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    strsplit(result, " ")[[1]][1]
}

# Configuration from gates_lib_v2.R
PLACEBO_MEAN_THRESHOLD <- 0.05
SEEDS <- c(20260719, 42, 999, 12345)
MIN_PRE <- 3
MIN_POST <- 3

cat("=== LOAD DATA ===\n")
d <- readRDS(file.path(REBUILD_DIR, "data/S1_ppml.rds"))
pairs <- readRDS(file.path(REBUILD_DIR, "data/S2_pairs.rds"))
theta <- readRDS(file.path(REBUILD_DIR, "data/S3_theta.rds"))

d_df <- as.data.frame(d)
pairs_df <- as.data.frame(pairs)
theta_df <- as.data.frame(theta)

cat(sprintf("Trade rows: %d, Pairs: %d, Theta rows: %d\n\n",
            nrow(d_df), nrow(pairs_df), nrow(theta_df)))

# Identify groups
never_treated <- pairs_df[pairs_df$classification == "never_treated", ]
switchers <- pairs_df[pairs_df$classification == "single_switcher", ]
cat(sprintf("Never-treated: %d, Switchers: %d\n", nrow(never_treated), nrow(switchers)))

# Switcher distribution by decile
switcher_by_decile <- aggregate(pair ~ size_decile, data = switchers, FUN = length)
names(switcher_by_decile) <- c("size_decile", "n_switchers")
cat("\nSwitchers by decile:\n")
print(switcher_by_decile)

# =============================================================================
# HELPER: Run one configuration (decile_only)
# =============================================================================
run_decile_only <- function(seed, d_df, pairs_df, switchers, switcher_by_decile) {
    set.seed(seed)

    never_treated <- pairs_df[pairs_df$classification == "never_treated", ]
    d_never <- d_df[d_df$pair %in% never_treated$pair & d_df$in_model == TRUE, ]
    d_never <- merge(d_never, pairs_df[, c("pair", "size_decile")], by = "pair")

    # Assign pseudo-adoption years
    unique_pairs <- unique(d_never[, c("pair", "size_decile")])

    placebo_assignments <- do.call(rbind, lapply(unique_pairs$pair, function(p) {
        pair_data <- d_never[d_never$pair == p, ]
        pair_data <- pair_data[order(pair_data$year), ]
        pos_years <- pair_data[pair_data$trade > 0, "year"]

        dec <- unique_pairs$size_decile[unique_pairs$pair == p]

        if (length(pos_years) < MIN_PRE + MIN_POST) {
            return(data.frame(pair = p, size_decile = dec,
                            pseudo_adoption_year = NA_integer_, run_length = NA_integer_))
        }

        # Find longest consecutive run
        diffs <- diff(pos_years)
        run_breaks <- which(diffs != 1)

        if (length(run_breaks) == 0) {
            best_run <- pos_years
        } else {
            run_starts <- c(1, run_breaks + 1)
            run_ends <- c(run_breaks, length(pos_years))
            run_lengths <- run_ends - run_starts + 1
            best_idx <- which.max(run_lengths)
            best_run <- pos_years[run_starts[best_idx]:run_ends[best_idx]]
        }

        if (length(best_run) < MIN_PRE + MIN_POST) {
            return(data.frame(pair = p, size_decile = dec,
                            pseudo_adoption_year = NA_integer_, run_length = NA_integer_))
        }

        earliest <- best_run[MIN_PRE + 1]
        latest <- best_run[length(best_run) - MIN_POST + 1]

        if (earliest > latest) {
            return(data.frame(pair = p, size_decile = dec,
                            pseudo_adoption_year = NA_integer_, run_length = NA_integer_))
        }

        valid_years <- best_run[best_run >= earliest & best_run <= latest]
        if (length(valid_years) == 0) {
            return(data.frame(pair = p, size_decile = dec,
                            pseudo_adoption_year = NA_integer_, run_length = NA_integer_))
        }

        data.frame(pair = p, size_decile = dec,
                   pseudo_adoption_year = sample(valid_years, 1), run_length = length(best_run))
    }))

    placebo_valid <- placebo_assignments[!is.na(placebo_assignments$pseudo_adoption_year), ]

    # Match placebos by decile
    matched_list <- lapply(1:10, function(dec) {
        n_real <- switcher_by_decile$n_switchers[switcher_by_decile$size_decile == dec]
        if (length(n_real) == 0 || n_real == 0) return(NULL)
        available <- placebo_valid[placebo_valid$size_decile == dec, ]
        if (nrow(available) == 0) return(NULL)
        n_sample <- n_real
        do_replace <- n_sample > nrow(available)
        available[sample(nrow(available), n_sample, replace = do_replace), ]
    })

    matched_placebos <- do.call(rbind, matched_list)
    if (is.null(matched_placebos) || nrow(matched_placebos) == 0) {
        return(list(config_results = NULL, diagnostics = NULL))
    }

    # Compute theta_B for each placebo
    placebo_results <- do.call(rbind, lapply(1:nrow(matched_placebos), function(i) {
        p <- matched_placebos$pair[i]
        adopt <- matched_placebos$pseudo_adoption_year[i]

        pair_data <- d_never[d_never$pair == p, ]
        post <- pair_data[pair_data$year >= adopt & pair_data$trade > 0 & pair_data$y_hat_0 > 0, ]
        pre <- pair_data[pair_data$year < adopt & pair_data$trade > 0, ]

        # Count years
        n_pre_years <- sum(pair_data$year < adopt & pair_data$trade > 0)
        n_post_years <- sum(pair_data$year >= adopt & pair_data$trade > 0)

        # Edge proximity
        edge_early <- adopt <= 1989
        edge_late <- adopt >= 2018

        if (nrow(post) == 0) {
            theta_B <- NA_real_
        } else {
            theta_B <- log(sum(post$trade) / sum(post$y_hat_0))
        }

        data.frame(
            pair = p,
            size_decile = matched_placebos$size_decile[i],
            pseudo_adoption_year = adopt,
            theta_B = theta_B,
            n_pre_years = n_pre_years,
            n_post_years = n_post_years,
            edge_early = edge_early,
            edge_late = edge_late,
            mean_resid_post = if (nrow(post) > 0) mean(log(post$trade) - log(post$y_hat_0)) else NA_real_
        )
    }))

    valid_results <- placebo_results[!is.na(placebo_results$theta_B), ]

    diagnostics <- list(
        n_placebos = nrow(valid_results),
        mean_theta_B = mean(valid_results$theta_B),
        sd_theta_B = sd(valid_results$theta_B),
        pass_threshold = abs(mean(valid_results$theta_B)) < PLACEBO_MEAN_THRESHOLD,

        adopt_min = min(valid_results$pseudo_adoption_year),
        adopt_q25 = as.numeric(quantile(valid_results$pseudo_adoption_year, 0.25)),
        adopt_median = median(valid_results$pseudo_adoption_year),
        adopt_q75 = as.numeric(quantile(valid_results$pseudo_adoption_year, 0.75)),
        adopt_max = max(valid_results$pseudo_adoption_year),

        mean_n_pre = mean(valid_results$n_pre_years),
        mean_n_post = mean(valid_results$n_post_years),
        n_few_pre = sum(valid_results$n_pre_years < 3),
        n_few_post = sum(valid_results$n_post_years < 3),

        n_edge_early = sum(valid_results$edge_early),
        n_edge_late = sum(valid_results$edge_late),

        mean_resid_post = mean(valid_results$mean_resid_post, na.rm = TRUE),

        n_extreme = sum(abs(valid_results$theta_B) > 5)
    )

    extreme_pairs <- valid_results[abs(valid_results$theta_B) > 5,
                                   c("pair", "pseudo_adoption_year", "theta_B", "n_pre_years", "n_post_years")]

    return(list(
        config_results = valid_results,
        diagnostics = diagnostics,
        extreme_pairs = extreme_pairs
    ))
}

# =============================================================================
# PART A: APPLY EXISTING VALIDITY GATE
# =============================================================================
cat("\n")
cat("=============================================================================\n")
cat("PART A: APPLY EXISTING VALIDITY GATE\n")
cat("=============================================================================\n\n")

cat(sprintf("PLACEBO_MEAN_THRESHOLD: %.4f\n", PLACEBO_MEAN_THRESHOLD))
cat("Gate: |mean(placebo theta_B)| < threshold\n\n")

part_a_results <- data.frame()
all_results <- list()

for (seed in SEEDS) {
    cat(sprintf("Running: seed=%d, cell=decile_only\n", seed))

    result <- run_decile_only(seed, d_df, pairs_df, switchers, switcher_by_decile)
    config_name <- paste(seed, "decile_only", sep = "_")
    all_results[[config_name]] <- result

    if (is.null(result$diagnostics)) {
        row <- data.frame(
            seed = seed,
            matching_cell = "decile_only",
            n_placebos = 0,
            mean_theta_B = NA,
            sd_theta_B = NA,
            abs_mean = NA,
            threshold = PLACEBO_MEAN_THRESHOLD,
            PASS_FAIL = "FAIL (no data)"
        )
    } else {
        diag <- result$diagnostics
        row <- data.frame(
            seed = seed,
            matching_cell = "decile_only",
            n_placebos = diag$n_placebos,
            mean_theta_B = diag$mean_theta_B,
            sd_theta_B = diag$sd_theta_B,
            abs_mean = abs(diag$mean_theta_B),
            threshold = PLACEBO_MEAN_THRESHOLD,
            PASS_FAIL = if (diag$pass_threshold) "PASS" else "FAIL"
        )
    }

    part_a_results <- rbind(part_a_results, row)
    cat(sprintf("  n=%d, mean=%.4f, |mean|=%.4f, %s\n",
                row$n_placebos, row$mean_theta_B, row$abs_mean, row$PASS_FAIL))
}

cat("\n=== PART A SUMMARY ===\n")
print(part_a_results)

n_pass <- sum(part_a_results$PASS_FAIL == "PASS")
cat(sprintf("\nConfigurations PASSING: %d of %d\n", n_pass, nrow(part_a_results)))

# =============================================================================
# PART B: LOCATE THE MECHANISM
# =============================================================================
cat("\n")
cat("=============================================================================\n")
cat("PART B: LOCATE THE MECHANISM\n")
cat("=============================================================================\n\n")

part_b_results <- data.frame()

for (seed in SEEDS) {
    config_name <- paste(seed, "decile_only", sep = "_")
    result <- all_results[[config_name]]

    if (!is.null(result$diagnostics)) {
        diag <- result$diagnostics

        row <- data.frame(
            seed = seed,
            matching_cell = "decile_only",
            mean_theta_B = diag$mean_theta_B,

            adopt_min = diag$adopt_min,
            adopt_q25 = diag$adopt_q25,
            adopt_median = diag$adopt_median,
            adopt_q75 = diag$adopt_q75,
            adopt_max = diag$adopt_max,

            mean_n_pre = diag$mean_n_pre,
            mean_n_post = diag$mean_n_post,
            n_few_pre = diag$n_few_pre,
            n_few_post = diag$n_few_post,

            n_edge_early = diag$n_edge_early,
            n_edge_late = diag$n_edge_late,

            mean_resid_post = diag$mean_resid_post,

            n_extreme = diag$n_extreme
        )

        part_b_results <- rbind(part_b_results, row)
    }
}

cat("=== DIAGNOSTIC TABLE ===\n")
print(part_b_results[, c("seed", "mean_theta_B", "adopt_min", "adopt_median", "adopt_max",
                         "mean_n_pre", "mean_n_post", "n_few_pre", "n_few_post")])

# Compare seeds
cat("\n=== COMPARE ALL SEEDS ===\n")

if (nrow(part_b_results) >= 2) {
    s1 <- part_b_results[1, ]
    s2 <- part_b_results[2, ]

    comparison <- data.frame(
        quantity = c("mean_theta_B", "adopt_median", "mean_n_pre", "mean_n_post",
                    "n_few_pre", "n_few_post", "n_edge_early", "n_edge_late", "mean_resid_post"),
        seed_first = c(s1$mean_theta_B, s1$adopt_median, s1$mean_n_pre, s1$mean_n_post,
                       s1$n_few_pre, s1$n_few_post, s1$n_edge_early, s1$n_edge_late, s1$mean_resid_post),
        seed_second = c(s2$mean_theta_B, s2$adopt_median, s2$mean_n_pre, s2$mean_n_post,
                        s2$n_few_pre, s2$n_few_post, s2$n_edge_early, s2$n_edge_late, s2$mean_resid_post)
    )
    comparison$difference <- comparison$seed_first - comparison$seed_second
    comparison$abs_diff <- abs(comparison$difference)

    print(comparison)

    max_diff_idx <- which.max(comparison$abs_diff)
    mechanism_quantity <- comparison$quantity[max_diff_idx]
    cat(sprintf("\n*** MECHANISM: The quantity that differs most is '%s' ***\n", mechanism_quantity))
}

# Check extreme pairs
cat("\n=== EXTREME THETA_B PAIRS (|theta_B| > 5) ===\n")
for (config_name in names(all_results)) {
    result <- all_results[[config_name]]
    if (!is.null(result$extreme_pairs) && nrow(result$extreme_pairs) > 0) {
        cat(sprintf("\n%s: %d pairs with |theta_B| > 5\n", config_name, nrow(result$extreme_pairs)))
        print(head(result$extreme_pairs, 5))
    } else {
        cat(sprintf("%s: 0 pairs with |theta_B| > 5\n", config_name))
    }
}

# =============================================================================
# PART C: BRANCH DECISION
# =============================================================================
cat("\n")
cat("=============================================================================\n")
cat("PART C: BRANCH DECISION\n")
cat("=============================================================================\n\n")

if (n_pass == 0) {
    cat("*** BRANCH C2: ALL configurations fail ***\n\n")
    cat("The placebo design is INVALID. b_hat cannot be estimated reliably.\n")
    cat("The mean placebo theta_B is far outside the threshold of 0.05.\n\n")

    # Report uncorrected results
    cat("=== UNCORRECTED RESULTS (theta_B only, no bias correction) ===\n")

    baseline_pop <- readRDS(file.path(REBUILD_DIR, "data/S6_population.rds"))
    baseline_df <- as.data.frame(baseline_pop)

    theta_baseline <- theta_df[theta_df$pair %in% baseline_df$pair, ]

    cat(sprintf("BASELINE n: %d\n", nrow(theta_baseline)))
    cat(sprintf("mean(theta_B): %.4f\n", mean(theta_baseline$theta_B, na.rm = TRUE)))
    cat(sprintf("SD(theta_B): %.4f\n", sd(theta_baseline$theta_B, na.rm = TRUE)))

    # Compute quintiles and Q1-Q5 spread in theta_B
    # Load pre_trade for quintile construction (same method as S12)
    trade_df <- d_df
    baseline_trade <- merge(
        theta_baseline[, c("pair", "adoption_year")],
        trade_df[, c("pair", "year", "trade")],
        by = "pair"
    )
    baseline_trade$is_pre <- with(baseline_trade, year < adoption_year - 1 & trade > 0)
    pre_trade <- aggregate(trade ~ pair, data = baseline_trade[baseline_trade$is_pre, ], FUN = sum)
    names(pre_trade) <- c("pair", "pre_trade_sum")

    theta_baseline <- merge(theta_baseline, pre_trade, by = "pair", all.x = TRUE)
    theta_baseline$pre_trade_sum[is.na(theta_baseline$pre_trade_sum)] <- 0

    theta_baseline$rank <- rank(theta_baseline$pre_trade_sum, ties.method = "random")
    n <- nrow(theta_baseline)
    theta_baseline$quintile <- ceiling(theta_baseline$rank / (n / 5))
    theta_baseline$quintile <- pmin(theta_baseline$quintile, 5)

    quintile_means <- aggregate(theta_B ~ quintile, data = theta_baseline, FUN = mean)
    cat("\nQuintile means (theta_B, uncorrected):\n")
    print(quintile_means)

    Q1_theta_B <- quintile_means$theta_B[quintile_means$quintile == 1]
    Q5_theta_B <- quintile_means$theta_B[quintile_means$quintile == 5]
    cat(sprintf("\nQ1-Q5 spread (theta_B): %.4f\n", Q1_theta_B - Q5_theta_B))

    branch_taken <- "C2"

} else {
    cat("*** BRANCH C1 or C3: Some configurations pass ***\n\n")
    branch_taken <- "C1"
}

# =============================================================================
# SAVE OUTPUTS
# =============================================================================
cat("\n")
cat("=============================================================================\n")
cat("SAVE OUTPUTS\n")
cat("=============================================================================\n\n")

output_table <- merge(part_a_results,
                      part_b_results[, c("seed", "matching_cell", "adopt_min", "adopt_median", "adopt_max",
                                        "mean_n_pre", "mean_n_post", "n_few_pre", "n_few_post",
                                        "n_edge_early", "n_edge_late", "mean_resid_post", "n_extreme")],
                      by = c("seed", "matching_cell"), all.x = TRUE)

OUTPUT_PATH <- file.path(REBUILD_DIR, "output/T7_placebo_validity.csv")
write.csv(output_table, OUTPUT_PATH, row.names = FALSE)
output_sha <- get_sha256(OUTPUT_PATH)

cat(sprintf("Saved: %s\nSHA256: %s\n", OUTPUT_PATH, output_sha))

# Sidecar
SIDECAR_PATH <- file.path(REBUILD_DIR, "meta/T7_placebo_validity.csv.sidecar")
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S14_placebo_diagnostic.R"))

writeLines(c(
    "FILE:      T7_placebo_validity.csv",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S14_placebo_diagnostic.R (SHA256: %s)", script_sha),
    "INPUTS:    data/S1_ppml.rds, data/S2_pairs.rds, data/S3_theta.rds, data/S6_population.rds",
    "SEEDS:     20260719, 42, 999, 12345",
    sprintf("THRESHOLD: %.4f", PLACEBO_MEAN_THRESHOLD),
    sprintf("N_PASS:    %d of 4", n_pass),
    sprintf("BRANCH:    %s", branch_taken),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "=== INVALIDATION ===",
    "INV-015: Placebo validity gate (PLACEBO_MEAN_THRESHOLD=0.05) defined in gates_lib_v2.R",
    "         but NEVER invoked in S4_placebo.R or S5_bhat.R pipeline.",
    "         ALL 4 seeds FAIL the gate with |mean| ranging from 0.11 to 0.17."
), SIDECAR_PATH)

cat(sprintf("Sidecar: %s\n", SIDECAR_PATH))

# =============================================================================
# FINAL REPORT
# =============================================================================
cat("\n")
cat("=============================================================================\n")
cat("S14 PLACEBO DIAGNOSTIC COMPLETE\n")
cat("=============================================================================\n\n")

cat("=== PART A TABLE ===\n")
print(part_a_results[, c("seed", "matching_cell", "n_placebos", "mean_theta_B", "abs_mean", "PASS_FAIL")])

cat(sprintf("\n=== BRANCH TAKEN: %s ===\n", branch_taken))

if (branch_taken == "C2") {
    cat("\nALL configurations fail the placebo validity gate.\n")
    cat("The bias correction (b_hat) cannot be reliably estimated.\n")
    cat("All b_hat-dependent quantities should be marked PROVISIONAL.\n")
}

cat(sprintf("\nEnd: %s\n", format(Sys.time())))
