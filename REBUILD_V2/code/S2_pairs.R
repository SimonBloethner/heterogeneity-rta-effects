#!/usr/bin/env Rscript
# =============================================================================
# S2_pairs.R - Pair Classification
# =============================================================================
# OUTPUTS: data/S2_pairs.rds
# INPUTS:  data/S1_ppml.rds
# SEED:    NONE
# GATES:   classifications sum to total unique pairs
#          no pair classified twice
# =============================================================================

cat("================================================================\n")
cat("S2: PAIR CLASSIFICATION\n")
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

INPUT_PATH <- file.path(REBUILD_DIR, "data/S1_ppml.rds")
input_sha <- get_sha256(INPUT_PATH)
cat(sprintf("Input: %s\n", INPUT_PATH))
cat(sprintf("SHA256: %s\n", input_sha))

d <- readRDS(INPUT_PATH)
cat(sprintf("Loaded rows: %d\n", nrow(d)))
cat(sprintf("Unique pairs: %d\n\n", uniqueN(d$pair)))

# -----------------------------------------------------------------------------
# PAIR CLASSIFICATION
# -----------------------------------------------------------------------------
cat("=== PAIR CLASSIFICATION ===\n")

# Compute RTA transition statistics per pair
pair_rta <- d[, .(
    first_rta_year = if (any(rta == 1)) min(year[rta == 1]) else NA_integer_,
    last_no_rta_year = if (any(rta == 0)) max(year[rta == 0]) else NA_integer_,
    n_transitions_01 = sum(diff(rta[order(year)]) == 1),
    n_transitions_10 = sum(diff(rta[order(year)]) == -1),
    always_rta = all(rta == 1),
    never_rta = all(rta == 0),
    n_years = .N,
    min_year = min(year),
    max_year = max(year),
    total_trade = sum(trade),
    mean_trade = mean(trade)
), by = pair]

cat(sprintf("Pairs analyzed: %d\n\n", nrow(pair_rta)))

# Classification
pair_rta[, classification := fcase(
    always_rta, "always_treated",
    never_rta, "never_treated",
    n_transitions_01 == 1 & n_transitions_10 == 0, "single_switcher",
    n_transitions_01 > 1 | n_transitions_10 > 0, "multi_switcher",
    default = "other"
)]

# For single switchers, adoption year is the first RTA year
pair_rta[classification == "single_switcher", adoption_year := first_rta_year]

# For multi-switchers, also record first RTA year for reference
pair_rta[classification == "multi_switcher", adoption_year := first_rta_year]

# -----------------------------------------------------------------------------
# CLASSIFICATION COUNTS
# -----------------------------------------------------------------------------
cat("=== CLASSIFICATION COUNTS ===\n\n")

class_counts <- pair_rta[, .N, by = classification][order(-N)]
print(class_counts)
cat("\n")

n_single <- pair_rta[classification == "single_switcher", .N]
n_multi <- pair_rta[classification == "multi_switcher", .N]
n_ever_treated <- n_single + n_multi
n_always <- pair_rta[classification == "always_treated", .N]
n_never <- pair_rta[classification == "never_treated", .N]
n_other <- pair_rta[classification == "other", .N]
n_total <- nrow(pair_rta)

cat("Summary:\n")
cat(sprintf("  Single switchers:  %d\n", n_single))
cat(sprintf("  Multi switchers:   %d\n", n_multi))
cat(sprintf("  Ever-treated:      %d (single + multi)\n", n_ever_treated))
cat(sprintf("  Always treated:    %d\n", n_always))
cat(sprintf("  Never treated:     %d\n", n_never))
cat(sprintf("  Other:             %d\n", n_other))
cat(sprintf("  TOTAL:             %d\n\n", n_total))

# -----------------------------------------------------------------------------
# GATE: Classifications sum to total
# -----------------------------------------------------------------------------
stopifnot(n_single + n_multi + n_always + n_never + n_other == n_total)
cat("GATE: Classifications sum to total [PASS]\n")

# GATE: No pair classified twice (implicit - each pair has one row)
stopifnot(nrow(pair_rta) == uniqueN(pair_rta$pair))
cat("GATE: No duplicate pairs [PASS]\n\n")

# -----------------------------------------------------------------------------
# SIZE DECILE ASSIGNMENT
# -----------------------------------------------------------------------------
cat("=== SIZE DECILE ASSIGNMENT ===\n")

# Assign size deciles based on total trade
pair_rta[, size_decile := cut(total_trade, 
                               breaks = quantile(total_trade, probs = 0:10/10, na.rm = TRUE),
                               labels = 1:10,
                               include.lowest = TRUE)]
pair_rta[, size_decile := as.integer(as.character(size_decile))]

# Handle NA deciles (if any)
n_na_decile <- sum(is.na(pair_rta$size_decile))
if (n_na_decile > 0) {
    cat(sprintf("WARNING: %d pairs with NA decile, assigning to decile 1\n", n_na_decile))
    pair_rta[is.na(size_decile), size_decile := 1L]
}

cat("Size decile distribution:\n")
print(pair_rta[, .N, by = size_decile][order(size_decile)])
cat("\n")

# -----------------------------------------------------------------------------
# ADOPTION YEAR DISTRIBUTION (for switchers)
# -----------------------------------------------------------------------------
cat("=== ADOPTION YEAR DISTRIBUTION (Single Switchers) ===\n")
adoption_dist <- pair_rta[classification == "single_switcher", .N, by = adoption_year][order(adoption_year)]
print(adoption_dist)
cat("\n")

cat(sprintf("Adoption year range: %d - %d\n", 
            min(pair_rta[classification == "single_switcher"]$adoption_year),
            max(pair_rta[classification == "single_switcher"]$adoption_year)))
cat("\n")

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
OUTPUT_PATH <- file.path(REBUILD_DIR, "data/S2_pairs.rds")
saveRDS(pair_rta, OUTPUT_PATH)

output_sha <- get_sha256(OUTPUT_PATH)
cat(sprintf("Saved: %s\n", OUTPUT_PATH))
cat(sprintf("SHA256: %s\n", output_sha))

# -----------------------------------------------------------------------------
# WRITE SIDECAR
# -----------------------------------------------------------------------------
SIDECAR_PATH <- file.path(REBUILD_DIR, "meta/S2_pairs.rds.sidecar")
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S2_pairs.R"))

sidecar_lines <- c(
    "FILE:      S2_pairs.rds",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S2_pairs.R (SHA256: %s)", script_sha),
    sprintf("INPUTS:    data/S1_ppml.rds (SHA256: %s)", input_sha),
    "SEED:      NONE",
    sprintf("GATE:      classifications_sum_to_total [PASS, %s]", format(Sys.time())),
    sprintf("GATE:      no_duplicate_pairs [PASS, %s]", format(Sys.time())),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("ROWS:      %d", nrow(pair_rta)),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "=== CLASSIFICATION COUNTS ===",
    sprintf("single_switcher:  %d", n_single),
    sprintf("multi_switcher:   %d", n_multi),
    sprintf("ever_treated:     %d", n_ever_treated),
    sprintf("always_treated:   %d", n_always),
    sprintf("never_treated:    %d", n_never),
    sprintf("other:            %d", n_other),
    sprintf("TOTAL:            %d", n_total)
)

writeLines(sidecar_lines, SIDECAR_PATH)
cat(sprintf("\nSidecar written: %s\n", SIDECAR_PATH))

# -----------------------------------------------------------------------------
# DECISION REQUIRED OUTPUT
# -----------------------------------------------------------------------------
cat("\n================================================================\n")
cat("DECISION REQUIRED\n")
cat("================================================================\n")
cat("Which pairs should be used for theta estimation?\n\n")
cat(sprintf("Option A: Single switchers only:     %d pairs\n", n_single))
cat(sprintf("Option B: All ever-treated:          %d pairs (single + multi)\n", n_ever_treated))
cat("\n")
cat("Multi-switchers have multiple RTA transitions (on/off or multiple on).\n")
cat("Including them complicates the adoption year definition.\n")
cat("\n")
cat("HALT: Awaiting decision before proceeding to S3_theta.R\n")

cat("\n================================================================\n")
cat("S2 PAIR CLASSIFICATION COMPLETE\n")
cat("================================================================\n")
cat(sprintf("End: %s\n", format(Sys.time())))
