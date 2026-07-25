#!/usr/bin/env Rscript
# S11_baseline_fix.R - Fix BASELINE definition discrepancy
#
# PROBLEM: S10_exhibits.R computed BASELINE as n_pre >= 3 & n_post >= 3 WITHOUT
#          anticipation exclusion, yielding 4,875 pairs. But S6_population.R
#          correctly applies anticipation exclusion, yielding 4,639 pairs.
#
# SOLUTION: Use S6_population.rds as canonical BASELINE source.
#
# OUTPUTS: output/T5b_theta_summary.csv (CORRECTED), data/S11_baseline_comparison.rds
# INPUTS:  data/S6_population.rds, data/S5_bhat.rds
# SEED:    NONE
# GATES:   BASELINE_n == 4639

cat("================================================================\n")
cat("S11: FIX BASELINE DEFINITION\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    strsplit(result, " ")[[1]][1]
}

# -----------------------------------------------------------------------------
# LOAD DATA
# -----------------------------------------------------------------------------
cat("=== LOAD DATA ===\n")

# Canonical BASELINE from S6
population <- readRDS(file.path(REBUILD_DIR, "data/S6_population.rds"))
n_baseline_canonical <- nrow(population)
cat(sprintf("S6_population.rds (canonical BASELINE): %d pairs\n", n_baseline_canonical))

# Theta values from S5
bhat_data <- readRDS(file.path(REBUILD_DIR, "data/S5_bhat.rds"))
theta_df <- as.data.frame(bhat_data$theta_d)
cat(sprintf("S5_bhat.rds theta_d: %d pairs\n", nrow(theta_df)))

# SHA256 verification
pop_sha <- get_sha256(file.path(REBUILD_DIR, "data/S6_population.rds"))
bhat_sha <- get_sha256(file.path(REBUILD_DIR, "data/S5_bhat.rds"))
cat(sprintf("\nS6_population.rds SHA256: %s\n", pop_sha))
cat(sprintf("S5_bhat.rds SHA256: %s\n\n", bhat_sha))

# -----------------------------------------------------------------------------
# COMPARE BASELINE DEFINITIONS
# -----------------------------------------------------------------------------
cat("=== BASELINE DEFINITION COMPARISON ===\n\n")

# S10's naive definition (WITHOUT anticipation exclusion)
theta_df$baseline_naive <- with(theta_df,
    adoption_year >= 1991 & adoption_year <= 2016 & n_pre >= 3 & n_post >= 3)
n_baseline_naive <- sum(theta_df$baseline_naive, na.rm = TRUE)

# Canonical definition (WITH anticipation exclusion via S6_population.rds)
theta_df$baseline_correct <- theta_df$pair %in% population$pair
n_baseline_correct <- sum(theta_df$baseline_correct, na.rm = TRUE)

cat(sprintf("Naive BASELINE (S10's computation): %d pairs\n", n_baseline_naive))
cat(sprintf("Correct BASELINE (S6_population):   %d pairs\n", n_baseline_correct))
cat(sprintf("Difference: %d pairs\n\n", n_baseline_naive - n_baseline_correct))

# Which pairs are in naive but not in correct?
disagreeing <- theta_df[theta_df$baseline_naive & !theta_df$baseline_correct, ]
cat(sprintf("Pairs in naive but NOT in correct BASELINE: %d\n", nrow(disagreeing)))

if (nrow(disagreeing) > 0) {
    cat("\nSample of disagreeing pairs:\n")
    print(head(disagreeing[, c("pair", "adoption_year", "n_pre", "n_post")], 10))

    cat("\nThese pairs fail anticipation exclusion:\n")
    cat("  Pre-period counts in S5 include year immediately before adoption,\n")
    cat("  but S6 correctly excludes it when counting n_pre >= 3.\n")
}

# -----------------------------------------------------------------------------
# COMPUTE CORRECTED THETA SUMMARY
# -----------------------------------------------------------------------------
cat("\n=== CORRECTED THETA SUMMARY ===\n\n")

# Filter to correct BASELINE
theta_baseline <- theta_df[theta_df$baseline_correct, ]

cat(sprintf("BASELINE pairs for analysis: %d\n\n", nrow(theta_baseline)))

# Full sample stats
full_stats <- data.frame(
    Population = "Full",
    N = nrow(theta_df),
    Mean_theta_A = mean(theta_df$theta_A, na.rm = TRUE),
    SD_theta_A = sd(theta_df$theta_A, na.rm = TRUE),
    Mean_theta_B = mean(theta_df$theta_B, na.rm = TRUE),
    SD_theta_B = sd(theta_df$theta_B, na.rm = TRUE),
    Mean_theta_D = mean(theta_df$theta_D, na.rm = TRUE),
    SD_theta_D = sd(theta_df$theta_D, na.rm = TRUE),
    theta_D_q10 = quantile(theta_df$theta_D, 0.10, na.rm = TRUE),
    theta_D_q90 = quantile(theta_df$theta_D, 0.90, na.rm = TRUE)
)

# BASELINE stats (CORRECT definition)
baseline_stats <- data.frame(
    Population = "BASELINE",
    N = nrow(theta_baseline),
    Mean_theta_A = mean(theta_baseline$theta_A, na.rm = TRUE),
    SD_theta_A = sd(theta_baseline$theta_A, na.rm = TRUE),
    Mean_theta_B = mean(theta_baseline$theta_B, na.rm = TRUE),
    SD_theta_B = sd(theta_baseline$theta_B, na.rm = TRUE),
    Mean_theta_D = mean(theta_baseline$theta_D, na.rm = TRUE),
    SD_theta_D = sd(theta_baseline$theta_D, na.rm = TRUE),
    theta_D_q10 = quantile(theta_baseline$theta_D, 0.10, na.rm = TRUE),
    theta_D_q90 = quantile(theta_baseline$theta_D, 0.90, na.rm = TRUE)
)

T5b <- rbind(full_stats, baseline_stats)
rownames(T5b) <- NULL

cat("T5b CORRECTED Theta Summary:\n")
print(T5b)

# -----------------------------------------------------------------------------
# GATES
# -----------------------------------------------------------------------------
cat("\n=== GATES ===\n")

gate_n <- baseline_stats$N == 4639
cat(sprintf("GATE: BASELINE_n == 4639: %s (%d)\n",
            ifelse(gate_n, "PASS", "FAIL"), baseline_stats$N))
stopifnot(gate_n)

# -----------------------------------------------------------------------------
# SAVE OUTPUTS
# -----------------------------------------------------------------------------
cat("\n=== SAVE OUTPUTS ===\n")

# T5b exhibit
OUTPUT_PATH <- file.path(REBUILD_DIR, "output/T5b_theta_summary.csv")
write.csv(T5b, OUTPUT_PATH, row.names = FALSE)
output_sha <- get_sha256(OUTPUT_PATH)
cat(sprintf("T5b_theta_summary.csv SHA256: %s\n", output_sha))

# Comparison data
comparison <- list(
    n_baseline_naive = n_baseline_naive,
    n_baseline_correct = n_baseline_correct,
    disagreeing_pairs = disagreeing[, c("pair", "adoption_year", "n_pre", "n_post")],
    T5b = T5b
)
COMP_PATH <- file.path(REBUILD_DIR, "data/S11_baseline_comparison.rds")
saveRDS(comparison, COMP_PATH)
comp_sha <- get_sha256(COMP_PATH)
cat(sprintf("S11_baseline_comparison.rds SHA256: %s\n", comp_sha))

# Sidecar
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S11_baseline_fix.R"))
writeLines(c(
    "FILE:      T5b_theta_summary.csv",
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S11_baseline_fix.R (SHA256: %s)", script_sha),
    sprintf("INPUTS:    data/S6_population.rds (SHA256: %s)", pop_sha),
    sprintf("           data/S5_bhat.rds (SHA256: %s)", bhat_sha),
    "SEED:      NONE",
    sprintf("GATE:      BASELINE_n == 4639 [PASS, actual=%d]", baseline_stats$N),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "NOTE: This exhibit SUPERSEDES T5_theta_summary.csv which used n=4875 (naive BASELINE).",
    "      Corrected BASELINE uses S6_population.rds with anticipation exclusion."
), file.path(REBUILD_DIR, "meta/T5b_theta_summary.csv.sidecar"))

cat("\nOutputs saved.\n")

cat("\n================================================================\n")
cat("S11 BASELINE FIX COMPLETE\n")
cat(sprintf("Naive BASELINE (S10):  %d pairs\n", n_baseline_naive))
cat(sprintf("Correct BASELINE (S6): %d pairs\n", n_baseline_correct))
cat(sprintf("Disagreeing pairs:     %d\n", nrow(disagreeing)))
cat(sprintf("End: %s\n", format(Sys.time())))
cat("================================================================\n")
