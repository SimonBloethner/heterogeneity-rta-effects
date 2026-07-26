#!/usr/bin/env Rscript
# =============================================================================
# N2_placebo_benchmark.R - Matched-Placebo Benchmark (IN-SAMPLE)
# =============================================================================
# OUTPUTS: output/T12_N2_placebo.csv
# INPUTS:  data/S5R_bhat.rds
# SEED:    20260719
# NOTE:    Placebo pairs are INSIDE the estimation sample. Their dispersion
#          is a LOWER BOUND on the null.
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
suppressPackageStartupMessages(library(dplyr))

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEED <- 20260719
set.seed(SEED)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("N2: MATCHED-PLACEBO BENCHMARK (IN-SAMPLE)")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load S5R data which has placebo results
S5R <- readRDS("data/S5R_bhat.rds")

# Check structure
say("S5R components: %s", paste(names(S5R), collapse = ", "))

# Get placebo theta_B values per decile
# S5R should have placebo component with theta_B for matched placebos
placebo <- S5R$placebo

say("Placebo rows: %d", nrow(placebo))
say("Placebo columns: %s", paste(names(placebo), collapse = ", "))

# Compute basic stats
mean_placebo <- mean(placebo$theta_B, na.rm = TRUE)
sd_placebo <- sd(placebo$theta_B, na.rm = TRUE)
var_placebo <- var(placebo$theta_B, na.rm = TRUE)

say("")
say("=== PLACEBO THETA_B RESULTS ===")
say("N placebo pairs: %d", sum(!is.na(placebo$theta_B)))
say("mean(theta_B):   %.6f", mean_placebo)
say("SD(theta_B):     %.6f", sd_placebo)
say("Var(theta_B):    %.6f", var_placebo)

# Split-half reliability: random split, compute correlation
n_placebo <- sum(!is.na(placebo$theta_B))
idx <- sample(n_placebo)
half1 <- placebo$theta_B[!is.na(placebo$theta_B)][idx[1:(n_placebo/2)]]
half2 <- placebo$theta_B[!is.na(placebo$theta_B)][idx[(n_placebo/2 + 1):n_placebo]]

# For split-half r, we need to compute variance in each half and correlation
# This is a different metric - let's do variance ratio instead
var_half1 <- var(half1)
var_half2 <- var(half2)
split_half_var_ratio <- var_half1 / var_half2

say("")
say("=== SPLIT-HALF RELIABILITY ===")
say("Var(half1): %.6f", var_half1)
say("Var(half2): %.6f", var_half2)
say("Variance ratio: %.4f", split_half_var_ratio)

# By decile (matching structure)
if ("size_decile" %in% names(placebo)) {
    by_decile <- placebo %>%
        group_by(size_decile) %>%
        summarise(
            n = n(),
            mean_theta_B = mean(theta_B, na.rm = TRUE),
            var_theta_B = var(theta_B, na.rm = TRUE),
            .groups = "drop"
        )
    say("")
    say("By size decile:")
    print(by_decile)
}

# Save results
n2_results <- data.frame(
    quantity = c("n_placebo", "mean_theta_B", "SD_theta_B", "Var_theta_B",
                 "split_half_var_ratio", "IN_SAMPLE"),
    value = c(n_placebo, mean_placebo, sd_placebo, var_placebo,
              split_half_var_ratio, 1),
    note = c("", "", "", "", "",
             "Placebo pairs are INSIDE estimation sample; dispersion is LOWER BOUND")
)
write.csv(n2_results, "output/T12_N2_placebo.csv", row.names = FALSE)

# Save for downstream
saveRDS(list(
    mean_placebo = mean_placebo,
    sd_placebo = sd_placebo,
    var_placebo = var_placebo,
    n_placebo = n_placebo,
    seed = SEED
), "data/N2_placebo.rds")

# Sidecar
code_sha <- get_sha256("code/N2_placebo_benchmark.R")
writeLines(c(
    "FILE:      T12_N2_placebo.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N2_placebo.csv")),
    sprintf("PRODUCER:  code/N2_placebo_benchmark.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S5R_bhat.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("N_PLACEBO: %d", n_placebo),
    sprintf("VAR_PLACEBO: %.6f", var_placebo),
    "NOTE:      Placebo pairs are INSIDE estimation sample (IN-SAMPLE benchmark)",
    "           Dispersion is a LOWER BOUND on the true null variance",
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T12_N2_placebo.csv.sidecar")

say("")
say("Wrote output/T12_N2_placebo.csv")
say("Wrote data/N2_placebo.rds")
say("Done: %s", format(Sys.time()))
