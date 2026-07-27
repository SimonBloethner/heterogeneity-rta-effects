#!/usr/bin/env Rscript
# =============================================================================
# S5R_bhat_split.R - b_hat on a 50/50 placebo split, validated OUT OF SAMPLE
# =============================================================================
# NOTE: Uses dplyr (no data.table) for Festus compatibility.
# EXPECTED_N: NA (computes b_hat from S3R_theta.rds placebo pairs)
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))

suppressPackageStartupMessages(library(dplyr))

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEED      <- 20260719
ANTICIP   <- 1
MIN_PRE   <- 3
MIN_POST  <- 3
GATE_ALL  <- 0.05
GATE_DEC  <- 0.10

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S5R: b_hat WITH HELD-OUT PLACEBO VALIDATION")
say("Start: %s", format(Sys.time()))
say("================================================================")

d     <- readRDS("data/S1R_ppml.rds")
theta <- readRDS("data/S3R_theta.rds")
popn  <- readRDS("data/S6R_population.rds")

# Size deciles on total trade
pair_trade <- d %>%
    filter(in_model == TRUE) %>%
    group_by(pair) %>%
    summarise(total_trade = sum(trade), .groups = "drop")

br <- unique(quantile(pair_trade$total_trade, probs = seq(0, 1, 0.1), na.rm = TRUE))
pair_trade$size_decile <- as.integer(cut(pair_trade$total_trade, breaks = br,
                                         include.lowest = TRUE, labels = FALSE))
say("Size deciles built on %d pairs, %d bins", nrow(pair_trade), length(br) - 1)

d <- d %>% left_join(pair_trade %>% select(pair, size_decile), by = "pair")

never <- d %>% filter(classification == "never_treated")
stopifnot(all(never$rta == 0))
say("G1 no placebo pair is treated: PASS  (never-treated pairs: %d)", length(unique(never$pair)))

# Pseudo-adoption assignment
set.seed(SEED)
assign_df <- never %>%
    filter(trade > 0) %>%
    group_by(pair, size_decile) %>%
    summarise(years = list(sort(unique(year))), .groups = "drop") %>%
    rowwise() %>%
    mutate(pseudo = {
        ys <- unlist(years)
        out <- NA_integer_
        need <- MIN_PRE + MIN_POST + 2 * ANTICIP + 1
        if (length(ys) >= need) {
            dif <- diff(ys); brk <- which(dif != 1)
            if (length(brk) == 0) best <- ys else {
                st <- c(1, brk + 1); en <- c(brk, length(ys))
                i <- which.max(en - st + 1); best <- ys[st[i]:en[i]]
            }
            if (length(best) >= need) {
                lo <- best[MIN_PRE + ANTICIP + 1]
                hi <- best[length(best) - MIN_POST - ANTICIP]
                if (lo <= hi) {
                    vy <- best[best >= lo & best <= hi]
                    if (length(vy) > 0) out <- sample(vy, 1)
                }
            }
        }
        out
    }) %>%
    ungroup() %>%
    select(pair, size_decile, pseudo)

valid <- assign_df %>% filter(!is.na(pseudo))
say("Placebo pairs with a valid pseudo-adoption year: %d", nrow(valid))

# Placebo theta_B
pl <- valid %>%
    left_join(never %>% select(pair, year, trade, y_hat_0, in_model), by = "pair") %>%
    filter(in_model == TRUE, trade > 0)

pl_theta <- pl %>%
    group_by(pair, size_decile, pseudo) %>%
    summarise(
        n_post = sum(year > pseudo + ANTICIP),
        n_pre = sum(year < pseudo - ANTICIP),
        theta_B = if (sum(year > pseudo + ANTICIP) < MIN_POST || sum(year < pseudo - ANTICIP) < MIN_PRE) NA_real_
                  else log(sum(trade[year > pseudo + ANTICIP]) / sum(y_hat_0[year > pseudo + ANTICIP])),
        .groups = "drop"
    ) %>%
    filter(!is.na(theta_B))

say("Placebo pairs with computable theta_B: %d", nrow(pl_theta))
say("Uncorrected placebo theta_B: mean %.6f  sd %.6f",
    mean(pl_theta$theta_B), sd(pl_theta$theta_B))

# 50/50 split
set.seed(SEED)
pl_theta$half <- sample(c("CAL", "VAL"), nrow(pl_theta), replace = TRUE)
stopifnot(length(intersect(pl_theta$pair[pl_theta$half == "CAL"],
                           pl_theta$pair[pl_theta$half == "VAL"])) == 0)
say("G2 CAL/VAL disjoint and exhaustive: PASS  (CAL %d, VAL %d)",
    sum(pl_theta$half == "CAL"), sum(pl_theta$half == "VAL"))

bhat <- pl_theta %>%
    filter(half == "CAL") %>%
    group_by(size_decile) %>%
    summarise(b_hat = mean(theta_B), n_cal = n(),
              se_bhat = sd(theta_B) / sqrt(n()), .groups = "drop") %>%
    arrange(size_decile)
say("")
print(as.data.frame(bhat))

# Held-out validation
val <- pl_theta %>%
    filter(half == "VAL") %>%
    left_join(bhat %>% select(size_decile, b_hat), by = "size_decile") %>%
    mutate(corrected = theta_B - b_hat)

holdout_mean <- mean(val$corrected, na.rm = TRUE)
by_dec <- val %>%
    group_by(size_decile) %>%
    summarise(n_val = n(), mean_corrected = mean(corrected),
              se = sd(corrected) / sqrt(n()), .groups = "drop") %>%
    arrange(size_decile)

say("")
say("=== HELD-OUT CORRECTED PLACEBO (VAL half, b_hat from CAL) ===")
print(as.data.frame(by_dec))
say("")
say("Overall held-out corrected mean: %.6f   gate |mean| < %.2f : %s",
    holdout_mean, GATE_ALL, ifelse(abs(holdout_mean) < GATE_ALL, "PASS", "FAIL"))
say("Worst decile |mean|:            %.6f   gate < %.2f : %s",
    max(abs(by_dec$mean_corrected)), GATE_DEC,
    ifelse(max(abs(by_dec$mean_corrected)) < GATE_DEC, "PASS", "FAIL"))

write.csv(rbind(
    data.frame(size_decile = NA_integer_, n_val = nrow(val),
               mean_corrected = holdout_mean,
               se = sd(val$corrected) / sqrt(nrow(val))),
    as.data.frame(by_dec)), "output/T9_placebo_holdout.csv", row.names = FALSE)

# Gates
stopifnot(abs(holdout_mean) < GATE_ALL)
say("G3 held-out corrected mean: PASS")

# G4: Three-state gate (INV-016)
# PASS: all |mean| < GATE_DEC
# PARTIAL: some |mean| >= GATE_DEC but all < 2*GATE_DEC
# FAIL (halts): any |mean| >= 2*GATE_DEC
exceeding <- by_dec %>% filter(abs(mean_corrected) >= GATE_DEC)
if (nrow(exceeding) > 0) {
    say("")
    say("G4 exceeding deciles (|mean| >= %.2f):", GATE_DEC)
    for (i in seq_len(nrow(exceeding))) {
        row <- exceeding[i, ]
        t_val <- row$mean_corrected / row$se
        say("  decile %d: n_val=%d  mean=%+.6f  SE=%.6f  t_vs_zero=%+.2f",
            row$size_decile, row$n_val, row$mean_corrected, row$se, t_val)
    }
}
worst <- max(abs(by_dec$mean_corrected))
if (worst >= 2 * GATE_DEC) {
    say("G4 held-out per-decile: FAIL (worst %.4f >= %.2f)", worst, 2 * GATE_DEC)
    stop("HALT: G4 gate failure at 2x bound")
} else if (worst >= GATE_DEC) {
    say("G4 held-out per-decile: PARTIAL (worst %.4f >= %.2f but < %.2f)", worst, GATE_DEC, 2 * GATE_DEC)
    G4_STATUS <- "PARTIAL"
} else {
    say("G4 held-out per-decile: PASS (worst %.4f < %.2f)", worst, GATE_DEC)
    G4_STATUS <- "PASS"
}

# Apply b_hat
th <- theta %>%
    left_join(pair_trade %>% select(pair, size_decile), by = "pair") %>%
    left_join(bhat %>% select(size_decile, b_hat), by = "size_decile") %>%
    mutate(theta_D = theta_B - b_hat)

stopifnot(all(abs((th$theta_B - th$b_hat) - th$theta_D) < 1e-12, na.rm = TRUE))
say("G5 identity: PASS")

base <- th %>% filter(pair %in% popn$pair)
say("")
say("BASELINE n=%d   mean theta_D %.6f   sd %.6f",
    nrow(base), mean(base$theta_D, na.rm = TRUE), sd(base$theta_D, na.rm = TRUE))

saveRDS(list(bhat = bhat, placebo = pl_theta, holdout = by_dec,
             theta = th, baseline = base), "data/S5R_bhat.rds")
osha <- get_sha256("data/S5R_bhat.rds")

writeLines(c(
    "FILE:      S5R_bhat.rds",
    sprintf("SHA256:    %s", osha),
    sprintf("PRODUCER:  code/S5R_bhat_split.R (SHA256: %s)", get_sha256("code/S5R_bhat_split.R")),
    "INPUTS:    data/S1R_ppml.rds, data/S3R_theta.rds, data/S6R_population.rds",
    sprintf("SEED:      %d", SEED),
    "MATCHING CELL: size_decile  (SELECTED)",
    "VALIDATION: 50/50 placebo split by pair; b_hat from CAL; gate on VAL",
    "GATE:      G1_no_treated_placebo [PASS]",
    "GATE:      G2_split_disjoint [PASS]",
    sprintf("GATE:      G3_holdout_mean [PASS, %.6f < %.2f]", abs(holdout_mean), GATE_ALL),
    sprintf("GATE:      G4_holdout_decile [%s, max %.6f, bound %.2f, 2x_bound %.2f]",
            G4_STATUS, max(abs(by_dec$mean_corrected)), GATE_DEC, 2 * GATE_DEC),
    "GATE:      G5_identity [PASS]",
    sprintf("UNCORRECTED_PLACEBO_MEAN: %.6f", mean(pl_theta$theta_B)),
    sprintf("BASELINE_MEAN_THETA_D:    %.6f", mean(base$theta_D, na.rm = TRUE)),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/S5R_bhat.rds.sidecar")

say("Wrote data/S5R_bhat.rds and output/T9_placebo_holdout.csv")
say("Done: %s", format(Sys.time()))
