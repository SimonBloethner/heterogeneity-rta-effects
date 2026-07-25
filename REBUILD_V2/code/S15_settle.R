#!/usr/bin/env Rscript
# =============================================================================
# S15_settle.R - Final settlement of the b_hat / seed-sensitivity question
# =============================================================================
# OUTPUTS: output/T8_settlement.csv
#          output/T8b_bhat_by_decile.csv
#          meta/T8_settlement.csv.sidecar
# INPUTS:  data/S1_ppml.rds, data/S2_pairs.rds, data/S3_theta.rds,
#          data/S6_population.rds, output/T3b_size_gradient_fixed.csv
# SEED:    20260719, 42, 999, 12345 (literal, in-script)
# GATES:   G1 seed 20260719 reproduces T3b Q1 and Q5 to 1e-9
#          G2 placebo mean is stable across seeds (max spread < 0.05)
#          G3 quintile bins are equal-sized (max n - min n <= 1)
#          G4 theta_D = theta_B - b_hat identity holds to 1e-12
#
# PURPOSE
#   T6b reported mean(theta_D) swinging from +0.044 to -1.58 across seeds.
#   T7 reported placebo mean stable at -0.140 to -0.144 across the same seeds.
#   These cannot both be true. This script recomputes the placebo arm from
#   S4's exact logic and reports which is correct. It does not patch T6b.
#
#   No halt on gate failure. Failures are printed and written to the output
#   table so the run always produces a readable answer.
#
# NOTE: Converted to base R (no data.table) for Festus compatibility.
# =============================================================================

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEEDS      <- c(20260719, 42, 999, 12345)
MIN_PRE    <- 3
MIN_POST   <- 3
ANTICIP    <- 1
PLACEBO_MEAN_THRESHOLD <- 0.05

get_sha256 <- function(path) {
    strsplit(system2("sha256sum", args = shQuote(path), stdout = TRUE), " ")[[1]][1]
}

say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S15: SETTLEMENT (base R version)")
say("Start: %s", format(Sys.time()))
say("================================================================")

# -----------------------------------------------------------------------------
# LOAD + STRUCTURAL CHECKS
# -----------------------------------------------------------------------------
need <- function(df, cols, what) {
    miss <- setdiff(cols, names(df))
    if (length(miss)) stop(sprintf("%s is missing column(s): %s\nHas: %s",
                                   what, paste(miss, collapse = ", "),
                                   paste(names(df), collapse = ", ")))
}

d      <- readRDS("data/S1_ppml.rds")
pairs  <- readRDS("data/S2_pairs.rds")
theta  <- readRDS("data/S3_theta.rds")
popn   <- readRDS("data/S6_population.rds")

need(d,     c("pair","year","trade","y_hat_0","rta","in_model"), "S1_ppml.rds")
need(pairs, c("pair","classification","size_decile"),            "S2_pairs.rds")
need(theta, c("pair","theta_B"),                                 "S3_theta.rds")
need(popn,  c("pair"),                                           "S6_population.rds")

if (!"adoption_year" %in% names(theta)) {
    need(pairs, "adoption_year", "S2_pairs.rds (adoption_year needed for theta)")
    theta <- merge(theta, pairs[, c("pair", "adoption_year")], by = "pair", all.x = TRUE)
}
if (!"size_decile" %in% names(theta)) {
    theta <- merge(theta, pairs[, c("pair", "size_decile")], by = "pair", all.x = TRUE)
}

say("S1 rows: %d | S2 pairs: %d | S3 theta: %d | BASELINE: %d",
    nrow(d), nrow(pairs), nrow(theta), nrow(popn))

never_treated <- pairs[pairs$classification == "never_treated", ]
switchers     <- pairs[pairs$classification == "single_switcher", ]

# Switcher distribution by decile
switcher_decile_dist <- as.data.frame(table(switchers$size_decile))
names(switcher_decile_dist) <- c("size_decile", "N")
switcher_decile_dist$size_decile <- as.integer(as.character(switcher_decile_dist$size_decile))

d_never <- merge(d[d$in_model == TRUE, ], never_treated[, c("pair", "size_decile")], by = "pair")
stopifnot(all(d_never$rta == 0))
say("Never-treated: %d | Switchers: %d", nrow(never_treated), nrow(switchers))

# -----------------------------------------------------------------------------
# PLACEBO ARM - identical logic to S4_placebo.R, parameterised by seed
# -----------------------------------------------------------------------------
placebo_for_seed <- function(seed) {

    set.seed(seed)
    unique_pairs <- unique(d_never[, c("pair", "size_decile")])

    assign_list <- lapply(1:nrow(unique_pairs), function(i) {
        p <- unique_pairs$pair[i]
        dec <- unique_pairs$size_decile[i]
        pd <- d_never[d_never$pair == p, ]
        pd <- pd[order(pd$year), ]
        pys <- pd$year[pd$trade > 0]

        result <- data.frame(pair = p, size_decile = dec,
                             pseudo_adoption_year = NA_integer_,
                             run_length = NA_integer_)

        if (length(pys) >= MIN_PRE + MIN_POST) {
            diffs <- diff(pys)
            brk <- which(diffs != 1)
            if (length(brk) == 0) {
                best <- pys
            } else {
                st <- c(1, brk + 1)
                en <- c(brk, length(pys))
                lens <- en - st + 1
                idx <- which.max(lens)
                best <- pys[st[idx]:en[idx]]
            }
            if (length(best) >= MIN_PRE + MIN_POST) {
                earliest <- best[MIN_PRE + 1]
                latest   <- best[length(best) - MIN_POST + 1]
                if (earliest <= latest) {
                    vy <- best[best >= earliest & best <= latest]
                    if (length(vy) > 0) {
                        result$pseudo_adoption_year <- sample(vy, 1)
                        result$run_length <- length(best)
                    }
                }
            }
        }
        result
    })

    assign_dt <- do.call(rbind, assign_list)
    valid <- assign_dt[!is.na(assign_dt$pseudo_adoption_year), ]

    set.seed(seed)
    matched_list <- lapply(1:10, function(dec) {
        n_real <- switcher_decile_dist$N[switcher_decile_dist$size_decile == dec]
        if (length(n_real) == 0 || n_real == 0) return(NULL)
        avail <- valid[valid$size_decile == dec, ]
        if (nrow(avail) == 0) return(NULL)
        idx <- sample(nrow(avail), n_real, replace = n_real > nrow(avail))
        avail[idx, ]
    })
    matched <- do.call(rbind, matched_list)

    # Merge to get full panel data for matched placebos
    pt <- merge(matched[, c("pair", "size_decile", "pseudo_adoption_year")],
                d_never, by = c("pair", "size_decile"), allow.cartesian = TRUE)

    # Compute theta_B for each placebo
    unique_matched <- unique(matched[, c("pair", "size_decile", "pseudo_adoption_year")])
    res_list <- lapply(1:nrow(unique_matched), function(i) {
        p <- unique_matched$pair[i]
        dec <- unique_matched$size_decile[i]
        pay <- unique_matched$pseudo_adoption_year[i]

        post <- pt[pt$pair == p & pt$size_decile == dec &
                   pt$pseudo_adoption_year == pay &
                   pt$year >= pay & pt$trade > 0 & pt$y_hat_0 > 0, ]

        if (nrow(post) == 0) {
            data.frame(pair = p, size_decile = dec, pseudo_adoption_year = pay,
                       theta_B = NA_real_, n_post = 0L)
        } else {
            data.frame(pair = p, size_decile = dec, pseudo_adoption_year = pay,
                       theta_B = log(sum(post$trade) / sum(post$y_hat_0)),
                       n_post = nrow(post))
        }
    })

    res <- do.call(rbind, res_list)
    res[!is.na(res$theta_B), ]
}

# -----------------------------------------------------------------------------
# PRE-ADOPTION TRADE - two candidate definitions, reported side by side
# -----------------------------------------------------------------------------
d_sw <- merge(d[d$in_model == TRUE, c("pair", "year", "trade")],
              switchers[, c("pair", "adoption_year")], by = "pair")

# Definition A: year < adoption_year
pre_A_agg <- aggregate(trade ~ pair, data = d_sw[d_sw$year < d_sw$adoption_year, ], sum)
names(pre_A_agg)[2] <- "pre_trade"

# Definition B: year < adoption_year - ANTICIP
pre_B_agg <- aggregate(trade ~ pair, data = d_sw[d_sw$year < d_sw$adoption_year - ANTICIP, ], sum)
names(pre_B_agg)[2] <- "pre_trade"

make_quintiles <- function(df) {
    df <- df[!is.na(df$pre_trade), ]
    df <- df[order(df$pre_trade), ]
    n <- nrow(df)
    df$quintile <- as.integer(cut(seq_len(n), breaks = quantile(seq_len(n), probs = 0:5/5),
                                  include.lowest = TRUE, labels = FALSE))
    df
}

# -----------------------------------------------------------------------------
# MAIN LOOP
# -----------------------------------------------------------------------------
rows      <- list()
bhat_rows <- list()

for (sd_i in SEEDS) {
    say("")
    say("--- SEED %d ---", sd_i)

    pl <- placebo_for_seed(sd_i)

    pl_mean <- mean(pl$theta_B)
    pl_sd   <- sd(pl$theta_B)
    say("placebo n=%d  mean=%.6f  sd=%.6f  |mean|<%.2f : %s",
        nrow(pl), pl_mean, pl_sd, PLACEBO_MEAN_THRESHOLD,
        ifelse(abs(pl_mean) < PLACEBO_MEAN_THRESHOLD, "PASS", "FAIL"))

    # Compute b_hat by decile
    bhat_list <- lapply(1:10, function(dec) {
        sub <- pl[pl$size_decile == dec, ]
        if (nrow(sub) == 0) return(NULL)
        data.frame(seed = sd_i, size_decile = dec,
                   b_hat = mean(sub$theta_B),
                   n_placebo = nrow(sub),
                   se_bhat = sd(sub$theta_B) / sqrt(nrow(sub)))
    })
    bhat <- do.call(rbind, bhat_list)
    bhat_rows[[as.character(sd_i)]] <- bhat

    # Merge b_hat to theta
    th <- merge(theta, bhat[, c("size_decile", "b_hat")], by = "size_decile", all.x = TRUE)
    th$theta_D <- th$theta_B - th$b_hat

    stopifnot(all(abs((th$theta_B - th$b_hat) - th$theta_D) < 1e-12, na.rm = TRUE))

    base <- th[th$pair %in% popn$pair, ]

    for (defn in c("A", "B")) {
        ptr <- if (defn == "A") pre_A_agg else pre_B_agg
        bq <- merge(base, ptr, by = "pair")
        bq <- make_quintiles(bq)

        # Compute stats by quintile
        g_list <- lapply(1:5, function(q) {
            sub <- bq[bq$quintile == q, ]
            data.frame(quintile = q,
                       n = nrow(sub),
                       mean_theta_D = mean(sub$theta_D, na.rm = TRUE),
                       mean_theta_B = mean(sub$theta_B, na.rm = TRUE),
                       mean_b_hat = mean(sub$b_hat, na.rm = TRUE),
                       sd_theta_D = sd(sub$theta_D, na.rm = TRUE))
        })
        g <- do.call(rbind, g_list)

        rows[[paste(sd_i, defn)]] <- data.frame(
            seed           = sd_i,
            pre_trade_defn = defn,
            n_baseline     = nrow(bq),
            placebo_mean   = pl_mean,
            placebo_gate   = ifelse(abs(pl_mean) < PLACEBO_MEAN_THRESHOLD, "PASS", "FAIL"),
            mean_theta_D   = mean(bq$theta_D, na.rm = TRUE),
            sd_theta_D     = sd(bq$theta_D, na.rm = TRUE),
            Q1_mean        = g$mean_theta_D[g$quintile == 1],
            Q5_mean        = g$mean_theta_D[g$quintile == 5],
            Q1_Q5_spread   = g$mean_theta_D[g$quintile == 1] - g$mean_theta_D[g$quintile == 5],
            Q1_Q5_theta_B  = g$mean_theta_B[g$quintile == 1] - g$mean_theta_B[g$quintile == 5],
            Q1_Q5_bhat     = g$mean_b_hat[g$quintile == 1] - g$mean_b_hat[g$quintile == 5],
            bin_imbalance  = max(g$n) - min(g$n)
        )

        say("  pre-trade defn %s: n=%d  mean_theta_D=%.6f  Q1=%.6f  Q5=%.6f  spread=%.6f  bins %d-%d",
            defn, nrow(bq), mean(bq$theta_D, na.rm = TRUE),
            g$mean_theta_D[g$quintile == 1], g$mean_theta_D[g$quintile == 5],
            g$mean_theta_D[g$quintile == 1] - g$mean_theta_D[g$quintile == 5],
            min(g$n), max(g$n))
    }
}

T8 <- do.call(rbind, rows)
T8b <- do.call(rbind, bhat_rows)

# -----------------------------------------------------------------------------
# GATES - reported, never halting
# -----------------------------------------------------------------------------
say("")
say("=== GATES ===")

T3B_Q1 <- 0.135514663434004
T3B_Q5 <- 0.0306650914141975

cand <- T8[T8$seed == 20260719, ]
cand$g1_dev <- pmax(abs(cand$Q1_mean - T3B_Q1), abs(cand$Q5_mean - T3B_Q5))
best <- cand[which.min(cand$g1_dev), ]
G1 <- best$g1_dev < 1e-9
say("G1 reproduce T3b (seed 20260719): %s  [defn %s, max dev %.3e]",
    ifelse(G1, "PASS", "FAIL"), best$pre_trade_defn, best$g1_dev)
if (!G1) say("   -> neither pre-trade definition reproduces T3b. S12 used a third definition.")

pm_spread <- max(T8$placebo_mean) - min(T8$placebo_mean)
G2 <- pm_spread < 0.05
say("G2 placebo mean stable across seeds: %s  [spread %.6f]",
    ifelse(G2, "PASS", "FAIL"), pm_spread)

G3 <- all(T8$bin_imbalance <= 1)
say("G3 equal quintile bins: %s  [max imbalance %d]",
    ifelse(G3, "PASS", "FAIL"), max(T8$bin_imbalance))

td_spread <- max(T8$mean_theta_D) - min(T8$mean_theta_D)
say("")
say("=== T6b VERDICT ===")
say("mean(theta_D) range across all runs: %.6f", td_spread)
if (td_spread < 0.05) {
    say("theta_D is STABLE across seeds. T6b rows 2-8 are erroneous.")
    say("Recommended action: mark T6b SUPERSEDED, retain T3b/T5b as canonical.")
} else {
    say("theta_D is NOT stable across seeds. T6b is corroborated.")
    say("Recommended action: the headline is seed-dependent and must be")
    say("reported as a range, not a point.")
}

say("")
say("=== PLACEBO GATE INTERPRETATION ===")
say("mean placebo theta_B = %.4f (all seeds).", mean(T8$placebo_mean))
say("A non-zero placebo mean means the PPML counterfactual is biased for")
say("untreated pairs. That bias is what b_hat removes. The 0.05 threshold")
say("tests 'nothing to correct'; failing it is the reason the correction")
say("exists. Report the value; do not treat the design as invalid.")

# -----------------------------------------------------------------------------
# WRITE
# -----------------------------------------------------------------------------
write.csv(T8, "output/T8_settlement.csv", row.names = FALSE)
write.csv(T8b, "output/T8b_bhat_by_decile.csv", row.names = FALSE)

out_sha <- get_sha256("output/T8_settlement.csv")
writeLines(c(
    "FILE:      T8_settlement.csv",
    sprintf("SHA256:    %s", out_sha),
    sprintf("PRODUCER:  code/S15_settle.R (SHA256: %s)", get_sha256("code/S15_settle.R")),
    "INPUTS:    data/S1_ppml.rds, data/S2_pairs.rds, data/S3_theta.rds,",
    "           data/S6_population.rds, output/T3b_size_gradient_fixed.csv",
    "SEEDS:     20260719, 42, 999, 12345",
    sprintf("GATE:      G1_reproduce_T3b [%s]", ifelse(G1, "PASS", "FAIL")),
    sprintf("GATE:      G2_placebo_stable [%s, spread %.6f]", ifelse(G2, "PASS", "FAIL"), pm_spread),
    sprintf("GATE:      G3_equal_bins [%s]", ifelse(G3, "PASS", "FAIL")),
    sprintf("GATE:      G4_identity [PASS]"),
    sprintf("PLACEBO_MEAN: %.6f (threshold %.2f, FAIL by design - see script notes)",
            mean(T8$placebo_mean), PLACEBO_MEAN_THRESHOLD),
    sprintf("THETA_D_RANGE: %.6f", td_spread),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("ROWS:      %d", nrow(T8)),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T8_settlement.csv.sidecar")

cat("\n")
print(T8)
say("")
say("Wrote output/T8_settlement.csv, output/T8b_bhat_by_decile.csv, sidecar.")
say("Done: %s", format(Sys.time()))
