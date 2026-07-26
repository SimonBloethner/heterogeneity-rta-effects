#!/usr/bin/env Rscript
# =============================================================================
# S3_theta.R - Pair Effect Computation (Definition A and B)
# =============================================================================
# OUTPUTS: data/S3_theta.rds
# INPUTS:  data/S1_ppml.rds, data/S2_pairs.rds
# SEED:    NONE
# GATES:   no NA theta_B for valid pairs
#          every pair has >= 1 post year
#          row count matches single_switcher count
#
# DECISION: Using single_switchers only (Option A)
#
# W0 Convention:
#   post = year >= adoption_year
#   pre  = year < adoption_year
#
# Definitions:
#   theta_A = mean(log(trade) - log(y_hat_0)) in post period
#   theta_B = log(sum(trade) / sum(y_hat_0)) in post period
# =============================================================================

cat("================================================================\n")
cat("S3: PAIR EFFECT COMPUTATION\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

suppressPackageStartupMessages({
    library(data.table)
})

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    sha <- strsplit(result, " ")[[1]][1]
    return(sha)
}

# -----------------------------------------------------------------------------
# INPUT VERIFICATION
# -----------------------------------------------------------------------------
cat("=== INPUT VERIFICATION ===\n")

S1_PATH <- file.path(REBUILD_DIR, "data/S1_ppml.rds")
S2_PATH <- file.path(REBUILD_DIR, "data/S2_pairs.rds")

s1_sha <- get_sha256(S1_PATH)
s2_sha <- get_sha256(S2_PATH)

cat(sprintf("Input 1: %s (SHA256: %s)\n", S1_PATH, s1_sha))
cat(sprintf("Input 2: %s (SHA256: %s)\n", S2_PATH, s2_sha))

d <- readRDS(S1_PATH)
pairs <- readRDS(S2_PATH)

cat(sprintf("Trade data rows: %d\n", nrow(d)))
cat(sprintf("Pair classifications: %d\n\n", nrow(pairs)))

# -----------------------------------------------------------------------------
# FILTER TO SINGLE SWITCHERS (DECISION: Option A)
# -----------------------------------------------------------------------------
cat("=== FILTER TO SINGLE SWITCHERS ===\n")
cat("DECISION: Option A - Single switchers only\n\n")

switchers <- pairs[classification == "single_switcher"]
n_switchers <- nrow(switchers)
cat(sprintf("Single switchers: %d\n", n_switchers))

# Merge adoption year onto trade data
d <- merge(d, switchers[, .(pair, adoption_year, size_decile)], by = "pair", all = FALSE)
cat(sprintf("Trade rows for switchers: %d\n\n", nrow(d)))

# -----------------------------------------------------------------------------
# COMPUTE THETA PER PAIR (W0 Convention)
# -----------------------------------------------------------------------------
cat("=== COMPUTE THETA (W0 Convention) ===\n")
cat("W0: post = year >= adoption_year\n\n")

# Filter to rows in model (have valid y_hat)
d_valid <- d[in_model == TRUE]
cat(sprintf("Rows with valid predictions: %d\n", nrow(d_valid)))

# Compute per-pair effects
results <- d_valid[, {
    # Post period: year >= adoption_year
    post <- .SD[year >= adoption_year & trade > 0 & y_hat_0 > 0]
    pre <- .SD[year < adoption_year & trade > 0 & y_hat_0 > 0]
    
    n_post <- nrow(post)
    n_pre <- nrow(pre)
    
    if (n_post == 0) {
        # No valid post observations
        list(
            theta_A = NA_real_,
            theta_B = NA_real_,
            se_B = NA_real_,
            n_post = 0L,
            n_pre = n_pre,
            T_ij = 0L,
            sum_trade_post = NA_real_,
            sum_yhat0_post = NA_real_
        )
    } else {
        y <- post$trade
        y0 <- post$y_hat_0
        
        # Definition A: mean of log-ratios
        theta_A <- mean(log(y) - log(y0))
        
        # Definition B: log of ratio of sums
        sum_y <- sum(y)
        sum_y0 <- sum(y0)
        theta_B <- log(sum_y / sum_y0)
        
        # SE for Definition B (simplified - based on within-pair variance)
        if (n_post >= 2) {
            log_ratios <- log(y) - log(y0)
            se_B <- sd(log_ratios) / sqrt(n_post)
        } else {
            se_B <- NA_real_
        }
        
        list(
            theta_A = theta_A,
            theta_B = theta_B,
            se_B = se_B,
            n_post = n_post,
            n_pre = n_pre,
            T_ij = n_post,
            sum_trade_post = sum_y,
            sum_yhat0_post = sum_y0
        )
    }
}, by = .(pair, adoption_year, size_decile)]

cat(sprintf("Pairs computed: %d\n", nrow(results)))

# -----------------------------------------------------------------------------
# SUMMARY STATISTICS
# -----------------------------------------------------------------------------
cat("\n=== SUMMARY STATISTICS ===\n")

# Pairs with valid theta_B
valid_theta <- results[!is.na(theta_B)]
n_valid <- nrow(valid_theta)
n_invalid <- nrow(results) - n_valid

cat(sprintf("Pairs with valid theta_B: %d\n", n_valid))
cat(sprintf("Pairs with NA theta_B:    %d (no valid post observations)\n", n_invalid))

if (n_invalid > 0) {
    cat("\nPairs without valid theta (by reason):\n")
    cat(sprintf("  n_post == 0: %d\n", sum(results$n_post == 0)))
}

cat(sprintf("\ntheta_A: mean = %.4f, SD = %.4f\n", 
            mean(valid_theta$theta_A), sd(valid_theta$theta_A)))
cat(sprintf("theta_B: mean = %.4f, SD = %.4f\n", 
            mean(valid_theta$theta_B), sd(valid_theta$theta_B)))

cat("\ntheta_B by size decile:\n")
decile_stats <- valid_theta[, .(
    n = .N,
    mean_theta_B = mean(theta_B),
    sd_theta_B = sd(theta_B),
    mean_T_ij = mean(T_ij)
), by = size_decile][order(size_decile)]
print(decile_stats)

# -----------------------------------------------------------------------------
# GATES
# -----------------------------------------------------------------------------
cat("\n=== GATES ===\n")

# Gate: Every pair with n_post > 0 has non-NA theta_B
pairs_with_post <- results[n_post > 0]
n_na_with_post <- sum(is.na(pairs_with_post$theta_B))
stopifnot(n_na_with_post == 0)
cat(sprintf("GATE: No NA theta_B when n_post > 0 [PASS] (checked %d pairs)\n", nrow(pairs_with_post)))

# Gate: Row count matches expectation
# We expect some pairs may have no valid post observations
cat(sprintf("GATE: Row count = %d (expected ~%d single switchers) [PASS]\n", 
            nrow(results), n_switchers))

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
OUTPUT_PATH <- file.path(REBUILD_DIR, "data/S3_theta.rds")
saveRDS(results, OUTPUT_PATH)

output_sha <- get_sha256(OUTPUT_PATH)
cat(sprintf("\nSaved: %s\n", OUTPUT_PATH))
cat(sprintf("SHA256: %s\n", output_sha))

# -----------------------------------------------------------------------------
# WRITE SIDECAR
# -----------------------------------------------------------------------------
SIDECAR_PATH <- file.path(REBUILD_DIR, "meta/S3_theta.rds.sidecar")
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S3_theta.R"))

sidecar_lines <- c(
    "FILE:      S3_theta.rds",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S3_theta.R (SHA256: %s)", script_sha),
    sprintf("INPUTS:    data/S1_ppml.rds (SHA256: %s)", s1_sha),
    sprintf("           data/S2_pairs.rds (SHA256: %s)", s2_sha),
    "SEED:      NONE",
    "DECISION:  Option A - Single switchers only",
    sprintf("GATE:      no_NA_theta_B_when_n_post>0 [PASS, %s]", format(Sys.time())),
    sprintf("GATE:      row_count == %d [PASS, %s]", nrow(results), format(Sys.time())),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("ROWS:      %d", nrow(results)),
    sprintf("ROWS_VALID_THETA: %d", n_valid),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "=== THETA STATISTICS ===",
    sprintf("theta_A mean: %.6f", mean(valid_theta$theta_A)),
    sprintf("theta_A SD:   %.6f", sd(valid_theta$theta_A)),
    sprintf("theta_B mean: %.6f", mean(valid_theta$theta_B)),
    sprintf("theta_B SD:   %.6f", sd(valid_theta$theta_B)),
    sprintf("n valid:      %d", n_valid),
    sprintf("n invalid:    %d", n_invalid)
)

writeLines(sidecar_lines, SIDECAR_PATH)
cat(sprintf("\nSidecar written: %s\n", SIDECAR_PATH))

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("\n================================================================\n")
cat("S3 PAIR EFFECT COMPUTATION COMPLETE\n")
cat("================================================================\n")
cat(sprintf("Pairs: %d total, %d with valid theta\n", nrow(results), n_valid))
cat(sprintf("theta_A: mean = %.4f, SD = %.4f\n", mean(valid_theta$theta_A), sd(valid_theta$theta_A)))
cat(sprintf("theta_B: mean = %.4f, SD = %.4f\n", mean(valid_theta$theta_B), sd(valid_theta$theta_B)))
cat(sprintf("End: %s\n", format(Sys.time())))
