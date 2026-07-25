#!/usr/bin/env Rscript
# S5_bhat.R - b_hat Computation and Sensitivity Analysis
# OUTPUTS: data/S5_bhat.rds
# INPUTS:  data/S3_theta.rds, data/S4_placebo.rds, data/S1_ppml.rds, data/S2_pairs.rds
# SEED:    Multiple seeds for sensitivity (20260719, 42, 999, 12345)
# GATES:   finite SD per decile, non-NA b_hat for all deciles with treated pairs

cat("================================================================\n")
cat("S5: b_hat COMPUTATION AND SENSITIVITY ANALYSIS\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

suppressPackageStartupMessages(library(data.table))

SEEDS <- c(20260719, 42, 999, 12345)
MIN_PRE <- 3
MIN_POST <- 3

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    strsplit(result, " ")[[1]][1]
}

# Load inputs
cat("=== LOAD INPUTS ===\n")
theta <- readRDS(file.path(REBUILD_DIR, "data/S3_theta.rds"))
placebo_base <- readRDS(file.path(REBUILD_DIR, "data/S4_placebo.rds"))
d <- readRDS(file.path(REBUILD_DIR, "data/S1_ppml.rds"))
pairs <- readRDS(file.path(REBUILD_DIR, "data/S2_pairs.rds"))

cat(sprintf("Theta rows: %d\n", nrow(theta)))
cat(sprintf("Placebo rows (seed 20260719): %d\n\n", nrow(placebo_base)))

# Function to run placebo matching with a given seed
run_placebo_matching <- function(seed, d, pairs) {
    set.seed(seed)
    
    never_treated <- pairs[classification == "never_treated"]
    switchers <- pairs[classification == "single_switcher"]
    switcher_decile_dist <- switchers[, .N, by = size_decile][order(size_decile)]
    
    d_never <- merge(d[in_model == TRUE], never_treated[, .(pair, size_decile)], by = "pair")
    
    # Assign pseudo-adoption years
    placebo_assignments <- d_never[, {
        pair_data <- .SD[order(year)]
        pos_years <- pair_data[trade > 0]$year
        
        if (length(pos_years) < MIN_PRE + MIN_POST) {
            list(pseudo_adoption_year = NA_integer_)
        } else {
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
                list(pseudo_adoption_year = NA_integer_)
            } else {
                earliest <- best_run[MIN_PRE + 1]
                latest <- best_run[length(best_run) - MIN_POST + 1]
                
                if (earliest > latest) {
                    list(pseudo_adoption_year = NA_integer_)
                } else {
                    valid_years <- best_run[best_run >= earliest & best_run <= latest]
                    if (length(valid_years) == 0) {
                        list(pseudo_adoption_year = NA_integer_)
                    } else {
                        list(pseudo_adoption_year = sample(valid_years, 1))
                    }
                }
            }
        }
    }, by = .(pair, size_decile)]
    
    placebo_valid <- placebo_assignments[!is.na(pseudo_adoption_year)]
    
    # Match to switchers
    matched <- rbindlist(lapply(1:10, function(dec) {
        n_real <- switcher_decile_dist[size_decile == dec]$N
        if (length(n_real) == 0 || n_real == 0) return(NULL)
        available <- placebo_valid[size_decile == dec]
        if (nrow(available) == 0) return(NULL)
        available[sample(.N, n_real, replace = n_real > nrow(available))]
    }))
    
    # Compute theta_B
    placebo_theta <- merge(matched, d_never, by = c("pair", "size_decile"), allow.cartesian = TRUE)
    
    results <- placebo_theta[, {
        post <- .SD[year >= pseudo_adoption_year & trade > 0 & y_hat_0 > 0]
        if (nrow(post) == 0) {
            list(theta_B = NA_real_)
        } else {
            list(theta_B = log(sum(post$trade) / sum(post$y_hat_0)))
        }
    }, by = .(pair, size_decile, pseudo_adoption_year)]
    
    return(results[!is.na(theta_B)])
}

# -----------------------------------------------------------------------------
# (a) b_hat TABLE - 10 rows, 12 decimals, with n and SE
# -----------------------------------------------------------------------------
cat("=== (a) b_hat TABLE (seed 20260719) ===\n")

bhat_table <- placebo_base[!is.na(theta_B), .(
    n = .N,
    b_hat = mean(theta_B),
    SE = sd(theta_B) / sqrt(.N)
), by = size_decile][order(size_decile)]

# Add 12 decimal precision
bhat_table[, b_hat_12 := sprintf("%.12f", b_hat)]
bhat_table[, SE_12 := sprintf("%.12f", SE)]

print(bhat_table)
cat("\n")

# -----------------------------------------------------------------------------
# (b) DECILES WITH ZERO OR < 30 MATCHED PLACEBOS
# -----------------------------------------------------------------------------
cat("=== (b) SPARSE DECILES ===\n")

sparse_deciles <- bhat_table[n < 30]
if (nrow(sparse_deciles) > 0) {
    cat("Deciles with fewer than 30 matched placebos:\n")
    print(sparse_deciles[, .(size_decile, n)])
} else {
    cat("All deciles have >= 30 matched placebos\n")
}

zero_deciles <- bhat_table[n == 0]
if (nrow(zero_deciles) > 0) {
    cat("Deciles with ZERO placebos:\n")
    print(zero_deciles[, .(size_decile)])
} else {
    cat("No deciles with zero placebos\n")
}
cat("\n")

# -----------------------------------------------------------------------------
# (c) COMPARE WITH OLD b_hat
# -----------------------------------------------------------------------------
cat("=== (c) COMPARISON WITH OLD b_hat ===\n")

old_bhat <- c(-0.4993, -1.2138, -0.3566, -1.1336, -0.5650, 
              -0.5069, -0.3325, -0.1651, -0.1735, -0.0468)

comparison <- data.table(
    size_decile = 1:10,
    old_bhat = old_bhat,
    new_bhat = bhat_table$b_hat,
    difference = bhat_table$b_hat - old_bhat
)
print(comparison)
cat("\n")

# -----------------------------------------------------------------------------
# (d) SENSITIVITY: SEEDS 42, 999, 12345
# -----------------------------------------------------------------------------
cat("=== (d) SENSITIVITY ANALYSIS ===\n")

all_bhat <- list()
all_bhat[["20260719"]] <- bhat_table[, .(size_decile, b_hat)]

for (s in c(42, 999, 12345)) {
    cat(sprintf("Running seed %d...\n", s))
    placebo_s <- run_placebo_matching(s, d, pairs)
    bhat_s <- placebo_s[, .(b_hat = mean(theta_B)), by = size_decile][order(size_decile)]
    all_bhat[[as.character(s)]] <- bhat_s
}

# Combine all seeds
sensitivity <- Reduce(function(x, y) merge(x, y, by = "size_decile", all = TRUE), all_bhat)
setnames(sensitivity, c("size_decile", "b_hat_20260719", "b_hat_42", "b_hat_999", "b_hat_12345"))

# Add range
sensitivity[, range_low := pmin(b_hat_20260719, b_hat_42, b_hat_999, b_hat_12345, na.rm = TRUE)]
sensitivity[, range_high := pmax(b_hat_20260719, b_hat_42, b_hat_999, b_hat_12345, na.rm = TRUE)]
sensitivity[, range_width := range_high - range_low]

cat("\nb_hat under all seeds:\n")
print(sensitivity)
cat("\n")

# -----------------------------------------------------------------------------
# (e) theta_D = theta_B - b_hat
# -----------------------------------------------------------------------------
cat("=== (e) theta_D STATISTICS ===\n")

# Merge b_hat onto theta
theta_d <- merge(theta, bhat_table[, .(size_decile, b_hat)], by = "size_decile")
theta_d[, theta_D := theta_B - b_hat]

n_theta_d <- nrow(theta_d[!is.na(theta_D)])
mean_theta_d <- mean(theta_d$theta_D, na.rm = TRUE)
sd_theta_d <- sd(theta_d$theta_D, na.rm = TRUE)

cat(sprintf("n:    %d\n", n_theta_d))
cat(sprintf("mean: %.6f\n", mean_theta_d))
cat(sprintf("SD:   %.6f\n", sd_theta_d))
cat("\n")

# -----------------------------------------------------------------------------
# (f) theta_D BY SIZE QUINTILE, ALL SEEDS
# -----------------------------------------------------------------------------
cat("=== (f) theta_D BY QUINTILE (all seeds) ===\n")

# Create quintile from decile
theta_d[, quintile := ceiling(size_decile / 2)]

quintile_stats_base <- theta_d[!is.na(theta_D), .(
    mean_theta_D = mean(theta_D)
), by = quintile][order(quintile)]

cat("Quintile means (seed 20260719):\n")
print(quintile_stats_base)

q1_q5_spread_base <- quintile_stats_base[quintile == 1]$mean_theta_D - 
                      quintile_stats_base[quintile == 5]$mean_theta_D
cat(sprintf("Q1-Q5 spread: %.6f\n\n", q1_q5_spread_base))

# Compute for other seeds
quintile_all <- list()
quintile_all[["20260719"]] <- quintile_stats_base

for (s in c(42, 999, 12345)) {
    bhat_s <- all_bhat[[as.character(s)]]
    theta_s <- merge(theta, bhat_s, by = "size_decile")
    theta_s[, theta_D := theta_B - b_hat]
    theta_s[, quintile := ceiling(size_decile / 2)]
    
    q_stats <- theta_s[!is.na(theta_D), .(mean_theta_D = mean(theta_D)), by = quintile][order(quintile)]
    quintile_all[[as.character(s)]] <- q_stats
}

# Combine
quintile_sensitivity <- Reduce(function(x, y) merge(x, y, by = "quintile", all = TRUE), quintile_all)
setnames(quintile_sensitivity, c("quintile", "seed_20260719", "seed_42", "seed_999", "seed_12345"))

cat("Quintile means under all seeds:\n")
print(quintile_sensitivity)

# Q1-Q5 spread for all seeds
spreads <- sapply(quintile_all, function(q) q[quintile == 1]$mean_theta_D - q[quintile == 5]$mean_theta_D)
cat(sprintf("\nQ1-Q5 spread: 20260719=%.4f, 42=%.4f, 999=%.4f, 12345=%.4f\n",
            spreads[1], spreads[2], spreads[3], spreads[4]))
cat(sprintf("Spread range: [%.4f, %.4f]\n", min(spreads), max(spreads)))

# -----------------------------------------------------------------------------
# GATES
# -----------------------------------------------------------------------------
cat("\n=== GATES ===\n")

# Gate: finite SD per decile
finite_sd <- bhat_table[, all(is.finite(SE))]
stopifnot(finite_sd)
cat("GATE: Finite SD per decile [PASS]\n")

# Gate: non-NA b_hat for all deciles with treated pairs
deciles_with_treated <- theta[, unique(size_decile)]
bhat_deciles <- bhat_table$size_decile
missing_bhat <- setdiff(deciles_with_treated, bhat_deciles)
stopifnot(length(missing_bhat) == 0)
cat("GATE: Non-NA b_hat for all deciles with treated [PASS]\n")

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
output <- list(
    bhat_table = bhat_table,
    theta_d = theta_d,
    sensitivity = sensitivity,
    quintile_sensitivity = quintile_sensitivity,
    old_bhat_comparison = comparison,
    spreads = spreads
)

OUTPUT_PATH <- file.path(REBUILD_DIR, "data/S5_bhat.rds")
saveRDS(output, OUTPUT_PATH)
output_sha <- get_sha256(OUTPUT_PATH)

cat(sprintf("\nSaved: %s\nSHA256: %s\n", OUTPUT_PATH, output_sha))

# Sidecar
SIDECAR_PATH <- file.path(REBUILD_DIR, "meta/S5_bhat.rds.sidecar")
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S5_bhat.R"))

writeLines(c(
    "FILE:      S5_bhat.rds",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S5_bhat.R (SHA256: %s)", script_sha),
    "INPUTS:    data/S3_theta.rds, data/S4_placebo.rds, data/S1_ppml.rds, data/S2_pairs.rds",
    "SEEDS:     20260719, 42, 999, 12345",
    sprintf("GATE:      finite_SD [PASS, %s]", format(Sys.time())),
    sprintf("GATE:      nonNA_bhat [PASS, %s]", format(Sys.time())),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "=== KEY RESULTS ===",
    sprintf("theta_D: n=%d, mean=%.6f, SD=%.6f", n_theta_d, mean_theta_d, sd_theta_d),
    sprintf("Q1-Q5 spread (seed 20260719): %.6f", q1_q5_spread_base)
), SIDECAR_PATH)

cat(sprintf("\nSidecar: %s\n", SIDECAR_PATH))

cat("\n================================================================\n")
cat("S5 COMPLETE\n")
cat(sprintf("End: %s\n", format(Sys.time())))
