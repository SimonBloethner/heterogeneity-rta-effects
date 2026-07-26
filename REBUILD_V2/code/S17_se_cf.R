#!/usr/bin/env Rscript
# =============================================================================
# S17_se_cf.R - Counterfactual Uncertainty via Block-Bootstrap
# =============================================================================
# OUTPUTS: data/S17_se_cf.rds, output/T11_se_decomposition.csv
# INPUTS:  data/S1R_ppml.rds, data/S5R_bhat.rds
# SEED:    20260719
# B:       200 (target), realized may be lower if chunks fail
# METHOD:  Block-bootstrap pairs with replacement from estimation sample,
#          refit PPML, re-predict y_hat_0 for post cells, recompute theta_B
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
suppressPackageStartupMessages(library(fixest))
suppressPackageStartupMessages(library(dplyr))
setFixest_nthreads(2)

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEED <- 20260719
B_TARGET <- 200
CHUNK_SIZE <- 10

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S17: COUNTERFACTUAL UNCERTAINTY (BLOCK-BOOTSTRAP)")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load data
d <- readRDS("data/S1R_ppml.rds")
S5R <- readRDS("data/S5R_bhat.rds")
base <- S5R$baseline

say("S1R rows: %d", nrow(d))
say("Baseline pairs: %d", nrow(base))

# Estimation sample: untreated cells
est_sample <- d[d$rta == 0, ]
unique_pairs <- unique(est_sample$pair)
say("Unique pairs in estimation sample: %d", length(unique_pairs))

# Post cells for baseline pairs
post_cells <- d[d$pair %in% base$pair & d$rta == 1,
                c("pair", "year", "exporter", "importer", "trade")]
say("Post cells for baseline: %d", nrow(post_cells))

# Bootstrap function for one draw
bootstrap_theta_B <- function(seed_offset) {
    set.seed(SEED + seed_offset * 1000)

    # Resample pairs with replacement
    boot_pairs <- sample(unique_pairs, length(unique_pairs), replace = TRUE)
    boot_est <- est_sample[est_sample$pair %in% boot_pairs, ]

    # Fit model
    fit_boot <- tryCatch({
        fepois(trade ~ 1 | pair + exporter^year + importer^year, data = boot_est)
    }, error = function(e) NULL)

    if (is.null(fit_boot)) return(rep(NA, nrow(base)))

    # Predict y_hat_0 for post cells
    post_pred <- post_cells
    post_pred$y_hat_0 <- predict(fit_boot, newdata = post_cells)

    # Compute theta_B per pair
    theta_B_boot <- post_pred %>%
        filter(!is.na(y_hat_0), y_hat_0 > 0, trade > 0) %>%
        mutate(log_diff = log(trade) - log(y_hat_0)) %>%
        group_by(pair) %>%
        summarise(theta_B = mean(log_diff), .groups = "drop")

    # Match to baseline order
    result <- base %>%
        left_join(theta_B_boot, by = "pair") %>%
        pull(theta_B.y)

    return(result)
}

# Run bootstrap
say("")
say("=== BLOCK-BOOTSTRAP (B=%d target) ===", B_TARGET)

n_chunks <- ceiling(B_TARGET / CHUNK_SIZE)
boot_results <- list()
chunks_completed <- 0
chunks_failed <- 0

for (chunk in 1:n_chunks) {
    say("Chunk %d/%d...", chunk, n_chunks)
    chunk_results <- list()

    for (b in 1:CHUNK_SIZE) {
        draw_id <- (chunk - 1) * CHUNK_SIZE + b
        result <- tryCatch({
            bootstrap_theta_B(draw_id)
        }, error = function(e) {
            say("  Draw %d failed: %s", draw_id, e$message)
            rep(NA, nrow(base))
        })
        chunk_results[[b]] <- result
    }

    # Check if chunk succeeded (at least one non-NA result)
    chunk_matrix <- do.call(cbind, chunk_results)
    if (any(!is.na(chunk_matrix))) {
        boot_results[[chunk]] <- chunk_matrix
        chunks_completed <- chunks_completed + 1
    } else {
        chunks_failed <- chunks_failed + 1
        say("  Chunk %d FAILED entirely", chunk)
    }
}

# Combine results
boot_matrix <- do.call(cbind, boot_results)
B_realized <- ncol(boot_matrix)
say("")
say("Chunks completed: %d/%d", chunks_completed, n_chunks)
say("Chunks failed: %d", chunks_failed)
say("Draws realized: %d/%d", B_realized, B_TARGET)

# Compute sd_cf per pair
sd_cf <- apply(boot_matrix, 1, sd, na.rm = TRUE)
base$sd_cf <- sd_cf

say("")
say("=== RESULTS ===")
say("sd_cf: mean=%.6f, median=%.6f, min=%.6f, max=%.6f",
    mean(sd_cf, na.rm=TRUE), median(sd_cf, na.rm=TRUE),
    min(sd_cf, na.rm=TRUE), max(sd_cf, na.rm=TRUE))

# Noise decomposition
se_B_sq <- base$se_B^2
sd_cf_sq <- sd_cf^2
se_total_sq <- se_B_sq + sd_cf_sq

say("")
say("=== NOISE DECOMPOSITION ===")
say("mean(se_B^2):     %.6f", mean(se_B_sq, na.rm=TRUE))
say("mean(sd_cf^2):    %.6f", mean(sd_cf_sq, na.rm=TRUE))
say("mean(se_total^2): %.6f", mean(se_total_sq, na.rm=TRUE))

share_se_B <- mean(se_B_sq, na.rm=TRUE) / mean(se_total_sq, na.rm=TRUE)
share_sd_cf <- mean(sd_cf_sq, na.rm=TRUE) / mean(se_total_sq, na.rm=TRUE)
say("Share se_B^2:     %.1f%%", 100*share_se_B)
say("Share sd_cf^2:    %.1f%%", 100*share_sd_cf)

# Deconvolution
var_theta_D <- var(base$theta_D, na.rm=TRUE)
SD_true_seB <- sqrt(max(0, var_theta_D - mean(se_B_sq, na.rm=TRUE)))
SD_true_total <- sqrt(max(0, var_theta_D - mean(se_total_sq, na.rm=TRUE)))

say("")
say("=== DECONVOLUTION ===")
say("Var(theta_D):     %.6f", var_theta_D)
say("SD_true (se_B):   %.6f", SD_true_seB)
say("SD_true (total):  %.6f", SD_true_total)
say("BRACKET:          [%.4f, %.4f]", SD_true_total, SD_true_seB)

# Decision
threshold <- 0.10 * var_theta_D
cf_var <- mean(sd_cf_sq, na.rm=TRUE)
cf_material <- cf_var >= threshold

say("")
say("=== DECISION ===")
say("mean(sd_cf^2) = %.6f", cf_var)
say("0.10 * Var(theta_D) = %.6f", threshold)
if (!cf_material) {
    say("DECISION: CF uncertainty IMMATERIAL (%.4f < %.4f)", cf_var, threshold)
} else {
    say("DECISION: CF uncertainty MATERIAL (%.4f >= %.4f)", cf_var, threshold)
}

# Q1-Q5 spread (unchanged)
base$quintile <- as.integer(cut(rank(base$pre_trade), breaks=5, labels=FALSE))
Q1 <- mean(base$theta_D[base$quintile==1], na.rm=TRUE)
Q5 <- mean(base$theta_D[base$quintile==5], na.rm=TRUE)
say("Q1-Q5 spread:     %.6f (unchanged)", Q1 - Q5)

# Save outputs
output <- list(
    B_target = B_TARGET,
    B_realized = B_realized,
    chunks_completed = chunks_completed,
    chunks_failed = chunks_failed,
    seed = SEED,
    sd_cf = sd_cf,
    mean_se_B_sq = mean(se_B_sq, na.rm=TRUE),
    mean_sd_cf_sq = mean(sd_cf_sq, na.rm=TRUE),
    mean_se_total_sq = mean(se_total_sq, na.rm=TRUE),
    share_se_B = share_se_B,
    share_sd_cf = share_sd_cf,
    var_theta_D = var_theta_D,
    SD_true_seB = SD_true_seB,
    SD_true_total = SD_true_total,
    SD_true_bracket = c(SD_true_total, SD_true_seB),
    threshold = threshold,
    cf_material = cf_material,
    Q1_Q5_spread = Q1 - Q5
)

saveRDS(output, "data/S17_se_cf.rds")
osha <- get_sha256("data/S17_se_cf.rds")

# CSV output
results_df <- data.frame(
    quantity = c("mean_se_B_sq", "mean_sd_cf_sq", "mean_se_total_sq",
                 "share_se_B", "share_sd_cf", "var_theta_D",
                 "SD_true_seB", "SD_true_total", "Q1_Q5_spread",
                 "threshold_10pct", "cf_material", "B_realized", "chunks_failed"),
    value = c(mean(se_B_sq), mean(sd_cf_sq), mean(se_total_sq),
              share_se_B, share_sd_cf, var_theta_D,
              SD_true_seB, SD_true_total, Q1 - Q5,
              threshold, as.numeric(cf_material), B_realized, chunks_failed)
)
write.csv(results_df, "output/T11_se_decomposition.csv", row.names = FALSE)

# Sidecars
writeLines(c(
    "FILE:      S17_se_cf.rds",
    sprintf("SHA256:    %s", osha),
    sprintf("PRODUCER:  code/S17_se_cf.R (SHA256: %s)", get_sha256("code/S17_se_cf.R")),
    "INPUTS:    data/S1R_ppml.rds, data/S5R_bhat.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("B_TARGET:  %d", B_TARGET),
    sprintf("B_REALIZED: %d", B_realized),
    sprintf("CHUNKS_FAILED: %d", chunks_failed),
    "METHOD:    Block-bootstrap pairs, refit PPML, re-predict y_hat_0",
    sprintf("SHARE_SE_B:    %.1f%%", 100*share_se_B),
    sprintf("SHARE_SD_CF:   %.1f%%", 100*share_sd_cf),
    sprintf("SD_TRUE_BRACKET: [%.4f, %.4f]", SD_true_total, SD_true_seB),
    sprintf("CF_MATERIAL:   %s", ifelse(cf_material, "YES", "NO")),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/S17_se_cf.rds.sidecar")

t11_sha <- get_sha256("output/T11_se_decomposition.csv")
writeLines(c(
    "FILE:      T11_se_decomposition.csv",
    sprintf("SHA256:    %s", t11_sha),
    sprintf("PRODUCER:  code/S17_se_cf.R (SHA256: %s)", get_sha256("code/S17_se_cf.R")),
    "INPUTS:    data/S1R_ppml.rds, data/S5R_bhat.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("B_REALIZED: %d", B_realized),
    sprintf("SD_TRUE_BRACKET: [%.4f, %.4f]", SD_true_total, SD_true_seB),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T11_se_decomposition.csv.sidecar")

say("")
say("Wrote data/S17_se_cf.rds  SHA %s", osha)
say("Wrote output/T11_se_decomposition.csv")
say("Done: %s", format(Sys.time()))
