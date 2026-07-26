#!/usr/bin/env Rscript
# =============================================================================
# G2c_placebo.R — Placebo Test with BATCH Predictions (OPTIMIZED)
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))

library(data.table)
library(fixest)
source("/groups/m-larch/bt307958/gates/gates_lib.R")

SCRATCH <- "/scratch/bt307958"

cat("\n============================================================\n")
cat("G2c: PLACEBO TEST (BATCH OPTIMIZED)\n")
cat("============================================================\n\n")

d <- load_filtered_data()
verify_frozen_facts(d)

# Load G0 results and PPML model
load("/groups/m-larch/bt307958/gates/G0_results.RData")
pair_rta <- results$pair_rta

load(file.path(SCRATCH, "G1_model.RData"))
ppml_fit <- G1_model
cat("Loaded PPML model\n")

# Prepare data
d[, pair := paste(exporter, importer, sep = "_")]
d[, exporter_year := paste(exporter, year, sep = "_")]
d[, importer_year := paste(importer, year, sep = "_")]

# Assign placebo adoption years
set.seed(GATES_SEED)
placebo_assign <- assign_placebo(d, pair_rta, seed = GATES_SEED)
cat(sprintf("Placebo pairs assigned: %d\n", nrow(placebo_assign)))

# BATCH APPROACH: Create all post-placebo cells at once, predict in one call
cat("\nBuilding placebo prediction dataset...\n")

placebo_cells <- rbindlist(lapply(1:nrow(placebo_assign), function(i) {
    p <- placebo_assign$pair[i]
    pseudo_adopt <- placebo_assign$pseudo_adoption_year[i]
    
    pair_data <- d[pair == p & year > (pseudo_adopt + 1) & trade > 0]
    if (nrow(pair_data) < 3) return(NULL)
    
    pair_data[, pseudo_adoption_year := pseudo_adopt]
    return(pair_data)
}))

cat(sprintf("Placebo cells to predict: %d\n", nrow(placebo_cells)))

# BATCH PREDICTION - much faster than per-pair
cat("Running batch prediction...\n")
pred_start <- Sys.time()
placebo_cells[, y_hat_0 := predict(ppml_fit, newdata = placebo_cells)]
pred_time <- difftime(Sys.time(), pred_start, units = "secs")
cat(sprintf("Batch prediction completed in %.1f seconds\n", pred_time))

# Filter valid predictions
placebo_cells <- placebo_cells[!is.na(y_hat_0) & y_hat_0 > 0]
cat(sprintf("Valid predictions: %d\n", nrow(placebo_cells)))

# Compute gaps and effects
placebo_cells[, gap := log(trade) - log(y_hat_0)]

placebo_effects <- placebo_cells[, .(
    theta_hat = mean(gap, na.rm = TRUE),
    se = sd(gap, na.rm = TRUE) / sqrt(.N),
    T_ij = .N,
    s_sq = var(gap, na.rm = TRUE)
), by = pair]

cat(sprintf("\nPlacebo pairs with effects: %d\n", nrow(placebo_effects)))

# Statistics
mean_placebo <- mean(placebo_effects$theta_hat, na.rm = TRUE)
sd_placebo <- sd(placebo_effects$theta_hat, na.rm = TRUE)
mean_se_placebo <- mean(placebo_effects$se, na.rm = TRUE)

cat(sprintf("\nMean placebo theta_hat: %.4f\n", mean_placebo))
cat(sprintf("SD(placebo theta_hat): %.4f\n", sd_placebo))
cat(sprintf("Mean SE_placebo: %.4f\n", mean_se_placebo))
cat(sprintf("Calibration ratio (SD/mean_SE): %.2f\n", sd_placebo/mean_se_placebo))

# Save results
G2c_results <- list(
    placebo_effects = placebo_effects,
    placebo_cells = placebo_cells,
    mean_placebo = mean_placebo,
    sd_placebo = sd_placebo,
    mean_se_placebo = mean_se_placebo,
    n_pairs = nrow(placebo_effects)
)
save(G2c_results, file = file.path(SCRATCH, "G2c_results.RData"))
cat("\nSaved G2c_results.RData\n")
