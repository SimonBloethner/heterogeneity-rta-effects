#!/usr/bin/env Rscript
# =============================================================================
# S16_reconcile.R - Exhibit pack vs REBUILD-as-found vs REBUILD-fixed
# =============================================================================
# NOTE: Uses dplyr (no data.table) for Festus compatibility.
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))

suppressPackageStartupMessages(library(dplyr))

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

S5R  <- readRDS("data/S5R_bhat.rds")
popn <- readRDS("data/S6R_population.rds")
base <- S5R$baseline
d    <- readRDS("data/S1R_ppml.rds")

# Quintiles on pre-trade (base already has pre_trade from theta)
bq <- base %>% filter(!is.na(pre_trade)) %>% arrange(pre_trade)
bq$quintile <- as.integer(cut(seq_len(nrow(bq)), breaks = quantile(seq_len(nrow(bq)), probs = 0:5/5),
                              include.lowest = TRUE, labels = FALSE))

g <- bq %>%
    group_by(quintile) %>%
    summarise(n = n(),
              mean_theta_D = mean(theta_D, na.rm = TRUE),
              mean_theta_B = mean(theta_B, na.rm = TRUE),
              mean_b_hat = mean(b_hat, na.rm = TRUE),
              se = sd(theta_D, na.rm = TRUE) / sqrt(n()), .groups = "drop") %>%
    arrange(quintile)

say("")
say("=== FIXED: gradient by pre-adoption trade quintile ===")
print(as.data.frame(g))

Q1 <- g %>% filter(quintile == 1)
Q5 <- g %>% filter(quintile == 5)
spread     <- Q1$mean_theta_D - Q5$mean_theta_D
spread_se  <- sqrt(Q1$se^2 + Q5$se^2)
spread_B   <- Q1$mean_theta_B - Q5$mean_theta_B
spread_bh  <- Q1$mean_b_hat - Q5$mean_b_hat

mean_tD <- mean(base$theta_D, na.rm = TRUE)
sd_tD   <- sd(base$theta_D, na.rm = TRUE)
se_tD   <- sd_tD / sqrt(nrow(base))
mean_tB <- mean(base$theta_B, na.rm = TRUE)

# Noise-deconvolved SD
var_hat <- var(base$theta_D, na.rm = TRUE)
mse     <- mean(base$se_B^2, na.rm = TRUE)
sd_true <- if (var_hat > mse) sqrt(var_hat - mse) else 0

# Trade-weighted mean
tw <- base %>%
    left_join(d %>% filter(in_model == TRUE) %>% group_by(pair) %>%
              summarise(w = sum(trade), .groups = "drop"), by = "pair")
tw_mean <- sum(tw$theta_D * tw$w, na.rm = TRUE) / sum(tw$w, na.rm = TRUE)

# Assemble reconciliation table
R <- data.frame(
    quantity = c("N_pairs", "mean_theta_D", "SD_theta_D", "SD_theta_true",
                 "TW_mean", "Q1_mean", "Q5_mean", "Q1_Q5_spread",
                 "Q1_Q5_from_theta_B", "Q1_Q5_from_b_hat",
                 "mean_theta_B_uncorrected", "holdout_corrected_placebo"),
    pack = c(4182, 0.2138, 0.5950, 0.425, 0.1412, 0.5615, 0.0968, 0.4647,
             NA_real_, NA_real_, NA_real_, NA_real_),
    as_found = c(4639, 0.043822, 0.676722, 0.538717, NA_real_,
                 0.135265, 0.030665, 0.104600, -0.090898, -0.195498,
                 -0.110148, NA_real_),
    fixed = c(nrow(base), mean_tD, sd_tD, sd_true, tw_mean,
              Q1$mean_theta_D, Q5$mean_theta_D, spread,
              spread_B, spread_bh, mean_tB,
              mean(S5R$holdout$mean_corrected)),
    se_fixed = c(NA_real_, se_tD, NA_real_, NA_real_, NA_real_,
                 Q1$se, Q5$se, spread_se, NA_real_, NA_real_,
                 sd(base$theta_B, na.rm = TRUE) / sqrt(nrow(base)), NA_real_)
)

R$dev_vs_pack <- R$fixed - R$pack
R$flag <- ifelse(!is.na(R$se_fixed) & !is.na(R$pack) & abs(R$dev_vs_pack) > 2 * R$se_fixed,
                 "RECONCILE-FAIL", ifelse(is.na(R$pack), "", "ok"))

say("")
say("=== RECONCILIATION ===")
print(R)

say("")
say("Quantities that do NOT reconcile with the exhibit pack:")
bad <- R %>% filter(flag == "RECONCILE-FAIL")
if (nrow(bad) == 0) {
    say("  none")
} else {
    for (i in seq_len(nrow(bad))) {
        say("  %-26s pack %+.4f  fixed %+.4f  dev %+.4f  (2SE = %.4f)",
            bad$quantity[i], bad$pack[i], bad$fixed[i], bad$dev_vs_pack[i], 2 * bad$se_fixed[i])
    }
    say("")
    say("These are findings. Do not resolve them here.")
}

say("")
say("=== GRADIENT DECOMPOSITION (fixed) ===")
say("Q1-Q5 in theta_D : %+.6f", spread)
say("  from theta_B   : %+.6f  (%.0f%%)", spread_B,  100 * spread_B  / spread)
say("  from b_hat     : %+.6f  (%.0f%%)", -spread_bh, -100 * spread_bh / spread)

write.csv(R, "output/T10_reconciliation.csv", row.names = FALSE)
writeLines(c(
    "FILE:      T10_reconciliation.csv",
    sprintf("SHA256:    %s", get_sha256("output/T10_reconciliation.csv")),
    sprintf("PRODUCER:  code/S16_reconcile.R (SHA256: %s)", get_sha256("code/S16_reconcile.R")),
    "INPUTS:    data/S3R_theta.rds, data/S5R_bhat.rds, data/S6R_population.rds",
    "SEED:      NONE",
    "GATE:      none halting; deviations flagged at 2*SE",
    sprintf("RECONCILE_FAIL_COUNT: %d", nrow(bad)),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T10_reconciliation.csv.sidecar")

say("")
say("Wrote output/T10_reconciliation.csv")
