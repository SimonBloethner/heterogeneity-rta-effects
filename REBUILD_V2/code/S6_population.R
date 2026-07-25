#!/usr/bin/env Rscript
# S6_population.R - Population Census (TD1)
# OUTPUTS: output/TD1_population_census.csv
# INPUTS:  data/S1_ppml.rds, data/S2_pairs.rds
# SEED:    NONE
# GATES:   census rows sum to final count; no pair enters twice

cat("================================================================\n")
cat("S6: POPULATION CENSUS\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

suppressPackageStartupMessages(library(data.table))

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    strsplit(result, " ")[[1]][1]
}

# BASELINE selection rules (from gates_lib_v2.R)
BASELINE <- list(
    min_pre = 3,
    min_post = 3,
    anticipation_exclude = 1,
    adoption_range = c(1991, 2016)
)

cat("=== BASELINE SELECTION RULES ===\n")
cat(sprintf("min_pre: %d years\n", BASELINE$min_pre))
cat(sprintf("min_post: %d years\n", BASELINE$min_post))
cat(sprintf("anticipation_exclude: %d year\n", BASELINE$anticipation_exclude))
cat(sprintf("adoption_range: %d-%d\n", BASELINE$adoption_range[1], BASELINE$adoption_range[2]))
cat("\n")

# Load data
cat("=== LOAD DATA ===\n")
d <- readRDS(file.path(REBUILD_DIR, "data/S1_ppml.rds"))
pairs <- readRDS(file.path(REBUILD_DIR, "data/S2_pairs.rds"))

s1_sha <- get_sha256(file.path(REBUILD_DIR, "data/S1_ppml.rds"))
s2_sha <- get_sha256(file.path(REBUILD_DIR, "data/S2_pairs.rds"))

cat(sprintf("Trade rows: %d\n", nrow(d)))
cat(sprintf("Pairs: %d\n\n", nrow(pairs)))

# -----------------------------------------------------------------------------
# CENSUS: Apply rules in order, track survivors
# -----------------------------------------------------------------------------
cat("=== POPULATION CENSUS ===\n\n")

census <- data.table(
    rule = character(),
    description = character(),
    pairs_remaining = integer(),
    pairs_dropped = integer()
)

add_census_row <- function(rule, desc, remaining, previous) {
    dropped <- previous - remaining
    census <<- rbind(census, data.table(
        rule = rule,
        description = desc,
        pairs_remaining = remaining,
        pairs_dropped = dropped
    ))
    cat(sprintf("%-5s %-45s %6d remaining (%+d)\n", rule, desc, remaining, -dropped))
}

# Start with all pairs
n_total <- nrow(pairs)
add_census_row("R0", "All pairs in data", n_total, n_total)

# Rule 1: Single switchers only
switchers <- pairs[classification == "single_switcher"]
n_switchers <- nrow(switchers)
add_census_row("R1", "Single switchers (one 0->1 transition)", n_switchers, n_total)

# Rule 2: Adoption year in range
switchers_in_range <- switchers[adoption_year >= BASELINE$adoption_range[1] & 
                                 adoption_year <= BASELINE$adoption_range[2]]
n_in_range <- nrow(switchers_in_range)
add_census_row("R2", sprintf("Adoption year in [%d, %d]", 
                              BASELINE$adoption_range[1], BASELINE$adoption_range[2]),
               n_in_range, n_switchers)

# Rule 3: In model (not dropped by PPML)
d_switchers <- merge(d, switchers_in_range[, .(pair, adoption_year)], by = "pair")
pairs_in_model <- d_switchers[in_model == TRUE, .(has_model = TRUE), by = pair]
switchers_in_model <- merge(switchers_in_range, pairs_in_model, by = "pair", all.x = TRUE)
switchers_in_model <- switchers_in_model[has_model == TRUE]
n_in_model <- nrow(switchers_in_model)
add_census_row("R3", "Has valid PPML predictions", n_in_model, n_in_range)

# Rule 4: Minimum pre-period years (with positive trade)
d_merged <- merge(d[in_model == TRUE], switchers_in_model[, .(pair, adoption_year)], by = "pair")

pre_counts <- d_merged[year < adoption_year - BASELINE$anticipation_exclude & trade > 0, 
                        .N, by = pair]
setnames(pre_counts, "N", "n_pre")
switchers_pre <- merge(switchers_in_model, pre_counts, by = "pair", all.x = TRUE)
switchers_pre[is.na(n_pre), n_pre := 0]
switchers_pre_ok <- switchers_pre[n_pre >= BASELINE$min_pre]
n_pre_ok <- nrow(switchers_pre_ok)
add_census_row("R4", sprintf("At least %d pre-years (excl. anticipation)", BASELINE$min_pre),
               n_pre_ok, n_in_model)

# Rule 5: Minimum post-period years (with positive trade)
post_counts <- d_merged[year >= adoption_year & trade > 0, .N, by = pair]
setnames(post_counts, "N", "n_post")
switchers_post <- merge(switchers_pre_ok, post_counts, by = "pair", all.x = TRUE)
switchers_post[is.na(n_post), n_post := 0]
switchers_final <- switchers_post[n_post >= BASELINE$min_post]
n_final <- nrow(switchers_final)
add_census_row("R5", sprintf("At least %d post-years", BASELINE$min_post), n_final, n_pre_ok)

cat("\n")

# -----------------------------------------------------------------------------
# FINAL POPULATION
# -----------------------------------------------------------------------------
cat("=== FINAL POPULATION ===\n")
cat(sprintf("Pairs surviving all rules: %d\n", n_final))
cat(sprintf("Pairs excluded: %d (%.1f%%)\n", n_total - n_final, 
            100 * (n_total - n_final) / n_total))

# Distribution by decile
cat("\nFinal population by size decile:\n")
print(switchers_final[, .N, by = size_decile][order(size_decile)])

# Distribution by adoption year
cat("\nFinal population by adoption year:\n")
print(switchers_final[, .N, by = adoption_year][order(adoption_year)])

# -----------------------------------------------------------------------------
# GATES
# -----------------------------------------------------------------------------
cat("\n=== GATES ===\n")

# Gate 1: Census rows sum correctly
# Each rule should be monotonically decreasing
for (i in 2:nrow(census)) {
    prev <- census$pairs_remaining[i-1]
    curr <- census$pairs_remaining[i]
    dropped <- census$pairs_dropped[i]
    stopifnot(curr == prev - dropped)
    stopifnot(curr <= prev)
}
cat("GATE: Census rows sum correctly [PASS]\n")

# Gate 2: No pair appears twice (final population has unique pairs)
stopifnot(uniqueN(switchers_final$pair) == nrow(switchers_final))
cat("GATE: No duplicate pairs in final population [PASS]\n")

# -----------------------------------------------------------------------------
# SAVE OUTPUT
# -----------------------------------------------------------------------------
OUTPUT_PATH <- file.path(REBUILD_DIR, "output/TD1_population_census.csv")
fwrite(census, OUTPUT_PATH)
output_sha <- get_sha256(OUTPUT_PATH)

cat(sprintf("\nSaved: %s\n", OUTPUT_PATH))
cat(sprintf("SHA256: %s\n", output_sha))

# Also save final population for downstream use
POP_PATH <- file.path(REBUILD_DIR, "data/S6_population.rds")
saveRDS(switchers_final, POP_PATH)
pop_sha <- get_sha256(POP_PATH)
cat(sprintf("Population saved: %s (SHA256: %s)\n", POP_PATH, pop_sha))

# Sidecar
SIDECAR_PATH <- file.path(REBUILD_DIR, "meta/TD1_population_census.csv.sidecar")
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S6_population.R"))

writeLines(c(
    "FILE:      TD1_population_census.csv",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S6_population.R (SHA256: %s)", script_sha),
    sprintf("INPUTS:    data/S1_ppml.rds (SHA256: %s)", s1_sha),
    sprintf("           data/S2_pairs.rds (SHA256: %s)", s2_sha),
    "SEED:      NONE",
    sprintf("GATE:      census_sums_correct [PASS, %s]", format(Sys.time())),
    sprintf("GATE:      no_duplicate_pairs [PASS, %s]", format(Sys.time())),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("ROWS:      %d", nrow(census)),
    sprintf("FINAL_POPULATION: %d", n_final),
    sprintf("CREATED:   %s", format(Sys.time()))
), SIDECAR_PATH)

cat(sprintf("Sidecar: %s\n", SIDECAR_PATH))

cat("\n================================================================\n")
cat("S6 POPULATION CENSUS COMPLETE\n")
cat(sprintf("Final population: %d pairs\n", n_final))
cat(sprintf("End: %s\n", format(Sys.time())))
