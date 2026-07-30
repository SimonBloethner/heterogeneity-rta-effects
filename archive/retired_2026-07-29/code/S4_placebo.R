#!/usr/bin/env Rscript
# S4_placebo.R - Placebo Assignment and Matching
# OUTPUTS: data/S4_placebo.rds
# INPUTS:  data/S1_ppml.rds, data/S2_pairs.rds
# SEED:    20260719
# MATCHING CELL: size_decile only

cat("================================================================\n")
cat("S4: PLACEBO ASSIGNMENT AND MATCHING\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

suppressPackageStartupMessages(library(data.table))

SEED <- 20260719
MIN_PRE <- 3
MIN_POST <- 3

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    strsplit(result, " ")[[1]][1]
}

cat("=== INPUT VERIFICATION ===\n")
S1_PATH <- file.path(REBUILD_DIR, "data/S1_ppml.rds")
S2_PATH <- file.path(REBUILD_DIR, "data/S2_pairs.rds")
s1_sha <- get_sha256(S1_PATH)
s2_sha <- get_sha256(S2_PATH)
cat(sprintf("Input 1: %s\n", S1_PATH))
cat(sprintf("Input 2: %s\n", S2_PATH))

d <- readRDS(S1_PATH)
pairs <- readRDS(S2_PATH)
cat(sprintf("Trade rows: %d, Pairs: %d\n\n", nrow(d), nrow(pairs)))

cat("=== IDENTIFY GROUPS ===\n")
never_treated <- pairs[classification == "never_treated"]
switchers <- pairs[classification == "single_switcher"]
cat(sprintf("Never-treated: %d, Switchers: %d\n", nrow(never_treated), nrow(switchers)))

switcher_decile_dist <- switchers[, .N, by = size_decile][order(size_decile)]
print(switcher_decile_dist)

d_never <- merge(d[in_model == TRUE], never_treated[, .(pair, size_decile)], by = "pair")
stopifnot(all(d_never$rta == 0))
cat("\nAll never-treated have rta==0: VERIFIED\n\n")

cat("=== ASSIGN PSEUDO-ADOPTION YEARS ===\n")
cat(sprintf("SEED: %d, MIN_PRE: %d, MIN_POST: %d\n", SEED, MIN_PRE, MIN_POST))

set.seed(SEED)

placebo_assignments <- d_never[, {
    pair_data <- .SD[order(year)]
    pos_years <- pair_data[trade > 0]$year
    
    if (length(pos_years) < MIN_PRE + MIN_POST) {
        list(pseudo_adoption_year = NA_integer_, run_length = NA_integer_)
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
            list(pseudo_adoption_year = NA_integer_, run_length = NA_integer_)
        } else {
            earliest <- best_run[MIN_PRE + 1]
            latest <- best_run[length(best_run) - MIN_POST + 1]
            
            if (earliest > latest) {
                list(pseudo_adoption_year = NA_integer_, run_length = NA_integer_)
            } else {
                valid_years <- best_run[best_run >= earliest & best_run <= latest]
                if (length(valid_years) == 0) {
                    list(pseudo_adoption_year = NA_integer_, run_length = NA_integer_)
                } else {
                    list(pseudo_adoption_year = sample(valid_years, 1), 
                         run_length = length(best_run))
                }
            }
        }
    }
}, by = .(pair, size_decile)]

placebo_valid <- placebo_assignments[!is.na(pseudo_adoption_year)]
cat(sprintf("Valid placebo assignments: %d of %d\n", nrow(placebo_valid), nrow(never_treated)))

cat("\nPlacebo by decile:\n")
print(placebo_valid[, .N, by = size_decile][order(size_decile)])

cat("\n=== MATCH PLACEBOS TO SWITCHERS ===\n")
set.seed(SEED)

matched_placebos <- rbindlist(lapply(1:10, function(dec) {
    n_real <- switcher_decile_dist[size_decile == dec]$N
    if (length(n_real) == 0 || n_real == 0) return(NULL)
    
    available <- placebo_valid[size_decile == dec]
    if (nrow(available) == 0) {
        cat(sprintf("Decile %d: %d switchers, 0 placebos\n", dec, n_real))
        return(NULL)
    }
    
    n_sample <- n_real
    do_replace <- n_sample > nrow(available)
    sampled <- available[sample(.N, n_sample, replace = do_replace)]
    
    cat(sprintf("Decile %d: %d switchers, %d available, sampled %d%s\n",
                dec, n_real, nrow(available), n_sample,
                ifelse(do_replace, " (replace)", "")))
    
    sampled
}))

cat(sprintf("\nTotal matched: %d\n", nrow(matched_placebos)))

cat("\n=== COMPUTE PLACEBO THETA_B ===\n")

placebo_theta <- merge(
    matched_placebos[, .(pair, size_decile, pseudo_adoption_year)],
    d_never, by = c("pair", "size_decile"), allow.cartesian = TRUE
)

placebo_results <- placebo_theta[, {
    post <- .SD[year >= pseudo_adoption_year & trade > 0 & y_hat_0 > 0]
    if (nrow(post) == 0) {
        list(theta_B = NA_real_, n_post = 0L)
    } else {
        list(theta_B = log(sum(post$trade) / sum(post$y_hat_0)), n_post = nrow(post))
    }
}, by = .(pair, size_decile, pseudo_adoption_year)]

valid_placebo <- placebo_results[!is.na(theta_B)]
cat(sprintf("Valid placebo theta: %d\n", nrow(valid_placebo)))
cat(sprintf("Mean: %.6f, SD: %.6f\n", mean(valid_placebo$theta_B), sd(valid_placebo$theta_B)))

cat("\n=== GATES ===\n")

# Gate 1: rta == 0 always
placebo_rta <- merge(placebo_results[, .(pair)], d[, .(pair, rta)], by = "pair")
stopifnot(all(placebo_rta$rta == 0))
cat("GATE: rta==0 always [PASS]\n")

# Gate 2: not in treated
treated_pairs <- pairs[classification %in% c("single_switcher", "multi_switcher", "always_treated")]$pair
stopifnot(length(intersect(placebo_results$pair, treated_pairs)) == 0)
cat("GATE: not in treated [PASS]\n")

# Gate 3: reproducible
set.seed(SEED)
check <- rbindlist(lapply(1:10, function(dec) {
    n_real <- switcher_decile_dist[size_decile == dec]$N
    if (length(n_real) == 0 || n_real == 0) return(NULL)
    available <- placebo_valid[size_decile == dec]
    if (nrow(available) == 0) return(NULL)
    available[sample(.N, n_real, replace = n_real > nrow(available))]
}))
stopifnot(identical(matched_placebos$pair, check$pair))
cat("GATE: reproducible [PASS]\n")

cat("\n=== PLACEBO BY DECILE ===\n")
print(valid_placebo[, .(n = .N, mean_theta_B = mean(theta_B), sd = sd(theta_B)), by = size_decile][order(size_decile)])

OUTPUT_PATH <- file.path(REBUILD_DIR, "data/S4_placebo.rds")
saveRDS(placebo_results, OUTPUT_PATH)
output_sha <- get_sha256(OUTPUT_PATH)
cat(sprintf("\nSaved: %s\nSHA256: %s\n", OUTPUT_PATH, output_sha))

SIDECAR_PATH <- file.path(REBUILD_DIR, "meta/S4_placebo.rds.sidecar")
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S4_placebo.R"))

writeLines(c(
    "FILE:      S4_placebo.rds",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S4_placebo.R (SHA256: %s)", script_sha),
    sprintf("INPUTS:    data/S1_ppml.rds (SHA256: %s)", s1_sha),
    sprintf("           data/S2_pairs.rds (SHA256: %s)", s2_sha),
    sprintf("SEED:      %d", SEED),
    "MATCHING:  size_decile only",
    sprintf("GATE:      rta==0_always [PASS, %s]", format(Sys.time())),
    sprintf("GATE:      not_in_treated [PASS, %s]", format(Sys.time())),
    sprintf("GATE:      reproducible [PASS, %s]", format(Sys.time())),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("ROWS:      %d", nrow(placebo_results)),
    sprintf("CREATED:   %s", format(Sys.time()))
), SIDECAR_PATH)

cat(sprintf("\nSidecar: %s\n", SIDECAR_PATH))
cat("\n================================================================\n")
cat("S4 COMPLETE\n")
cat(sprintf("End: %s\n", format(Sys.time())))
