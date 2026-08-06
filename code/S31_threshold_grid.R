#!/usr/bin/env Rscript
# =============================================================================
# S31_threshold_grid.R - Threshold Grid Robustness (T30)
# =============================================================================
# OUTPUTS: output/T30_threshold_grid.csv, output/T30_threshold_grid.csv.sidecar
# INPUTS:  data/S1R_ppml.rds, data/S3R_theta.rds
# SEED:    20260719 (same as canonical pipeline)
# EXPECTED_N: NA (varies by cell)
#
# Varies MIN_PRE and MIN_POST over {2,3,4,5} (16 cells).
# Holds everything else fixed: exclusion band, counterfactual, Definition D.
# Does NOT modify any existing script; reimplements the filtering and
# drift-correction logic with parameterised thresholds.
# =============================================================================

# Login node guard
stopifnot(!grepl("login", Sys.info()[["nodename"]]))

cat("=============================================================================\n")
cat("S31_threshold_grid.R - Threshold Grid Robustness\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat(sprintf("Node: %s\n", Sys.info()[["nodename"]]))
cat("=============================================================================\n\n")

suppressPackageStartupMessages(library(dplyr))

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
DATA_ROOT <- Sys.getenv("DATA_ROOT", unset = file.path(RTA_ROOT, "data"))
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

SEED      <- 20260719
ANTICIP   <- 1
ADOPT_LO  <- 1991
ADOPT_HI  <- 2016

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

# =============================================================================
# LOAD BASE DATA (once)
# =============================================================================
say("=== LOADING BASE DATA ===")

d     <- readRDS(file.path(DATA_ROOT, "S1R_ppml.rds"))
theta <- readRDS(file.path(DATA_ROOT, "S3R_theta.rds"))

sha_d     <- get_sha256(file.path(DATA_ROOT, "S1R_ppml.rds"))
sha_theta <- get_sha256(file.path(DATA_ROOT, "S3R_theta.rds"))

say("S1R_ppml.rds:   %s  (%d rows)", sha_d, nrow(d))
say("S3R_theta.rds:  %s  (%d rows)", sha_theta, nrow(theta))

# Size deciles (computed once on full data, same as S5R_bhat_split.R)
pair_trade <- d %>%
    filter(in_model == TRUE) %>%
    group_by(pair) %>%
    summarise(total_trade = sum(trade), .groups = "drop")

br <- unique(quantile(pair_trade$total_trade, probs = seq(0, 1, 0.1), na.rm = TRUE))
pair_trade$size_decile <- as.integer(cut(pair_trade$total_trade, breaks = br,
                                         include.lowest = TRUE, labels = FALSE))
say("Size deciles built on %d pairs", nrow(pair_trade))

# Pre-trade for quintile assignment (same as S28_gradient_B.R)
theta <- theta %>% left_join(pair_trade %>% select(pair, size_decile, total_trade), by = "pair")

# =============================================================================
# PLACEBO POPULATION (computed once with pseudo-adoption dates)
# =============================================================================
say("\n=== BUILDING PLACEBO POPULATION ===")

never <- d %>% filter(classification == "never_treated")
stopifnot(all(never$rta == 0))
say("Never-treated pairs: %d", length(unique(never$pair)))

# Assign pseudo-adoption years (same logic as S5R_bhat_split.R)
set.seed(SEED)

# For each never-treated pair, find valid pseudo-adoption years
# This is threshold-dependent, so we compute the MAXIMUM possible window
# and then filter per-cell
assign_base <- never %>%
    filter(trade > 0) %>%
    group_by(pair) %>%
    summarise(
        years = list(sort(unique(year))),
        .groups = "drop"
    ) %>%
    left_join(pair_trade %>% select(pair, size_decile), by = "pair")

# Function to assign pseudo-adoption for a given threshold
assign_pseudo <- function(years_list, min_pre, min_post, anticip) {
    ys <- unlist(years_list)
    need <- min_pre + min_post + 2 * anticip + 1
    if (length(ys) < need) return(NA_integer_)

    # Find longest contiguous run
    dif <- diff(ys)
    brk <- which(dif != 1)
    if (length(brk) == 0) {
        best <- ys
    } else {
        st <- c(1, brk + 1)
        en <- c(brk, length(ys))
        i <- which.max(en - st + 1)
        best <- ys[st[i]:en[i]]
    }

    if (length(best) < need) return(NA_integer_)

    lo <- best[min_pre + anticip + 1]
    hi <- best[length(best) - min_post - anticip]
    if (lo > hi) return(NA_integer_)

    vy <- best[best >= lo & best <= hi]
    if (length(vy) == 0) return(NA_integer_)

    sample(vy, 1)
}

# =============================================================================
# FUNCTION: Compute one cell of the grid
# =============================================================================
compute_cell <- function(min_pre, min_post) {
    say("\n--- Cell (min_pre=%d, min_post=%d) ---", min_pre, min_post)

    # 1. Filter treated population (same as S6R_population.R rules R4-R5)
    sw <- unique(d$pair[d$classification == "single_switcher"])
    ay <- d %>%
        filter(classification == "single_switcher",
               adoption_year >= ADOPT_LO,
               adoption_year <= ADOPT_HI) %>%
        pull(pair) %>% unique()
    pred_ok <- unique(d$pair[d$is_post == TRUE & d$in_model == TRUE])
    pre_ok  <- theta$pair[theta$n_pre >= min_pre]
    post_ok <- theta$pair[theta$n_post >= min_post]

    k <- Reduce(intersect, list(sw, ay, pred_ok, pre_ok, post_ok))
    n_pairs <- length(k)
    say("  Treated pairs: %d", n_pairs)

    if (n_pairs == 0) {
        return(data.frame(
            min_pre = min_pre, min_post = min_post, n_pairs = 0,
            mean_theta_D = NA, se_mean = NA, sd_theta_D = NA,
            gradient_q1_mean = NA, gradient_q5_mean = NA, gradient_spread = NA
        ))
    }

    # 2. Build placebo b_hat with this threshold
    set.seed(SEED)
    pl_assign <- assign_base %>%
        rowwise() %>%
        mutate(pseudo = assign_pseudo(years, min_pre, min_post, ANTICIP)) %>%
        ungroup() %>%
        filter(!is.na(pseudo))

    say("  Placebo pairs with valid pseudo: %d", nrow(pl_assign))

    # Compute placebo theta_B
    pl_theta <- pl_assign %>%
        left_join(never %>% select(pair, year, trade, y_hat_0, in_model), by = "pair") %>%
        filter(in_model == TRUE, trade > 0) %>%
        group_by(pair, size_decile, pseudo) %>%
        summarise(
            n_post_pl = sum(year > pseudo + ANTICIP),
            n_pre_pl = sum(year < pseudo - ANTICIP),
            theta_B_pl = if (sum(year > pseudo + ANTICIP) < min_post ||
                             sum(year < pseudo - ANTICIP) < min_pre) NA_real_
                         else log(sum(trade[year > pseudo + ANTICIP]) /
                                  sum(y_hat_0[year > pseudo + ANTICIP])),
            .groups = "drop"
        ) %>%
        filter(!is.na(theta_B_pl))

    say("  Placebo pairs with theta_B: %d", nrow(pl_theta))

    if (nrow(pl_theta) < 10) {
        say("  WARNING: Too few placebo pairs for reliable b_hat")
    }

    # 50/50 split for b_hat (same as S5R)
    set.seed(SEED)
    pl_theta$half <- sample(c("CAL", "VAL"), nrow(pl_theta), replace = TRUE)

    # Compute b_hat by size decile from CAL half
    bhat <- pl_theta %>%
        filter(half == "CAL") %>%
        group_by(size_decile) %>%
        summarise(b_hat = mean(theta_B_pl), .groups = "drop")

    # 3. Apply drift correction to treated population
    popn <- theta %>%
        filter(pair %in% k) %>%
        left_join(bhat, by = "size_decile") %>%
        mutate(theta_D = theta_B - b_hat)

    # Handle pairs with missing b_hat (decile not in placebo)
    if (any(is.na(popn$theta_D))) {
        n_missing <- sum(is.na(popn$theta_D))
        say("  WARNING: %d pairs missing b_hat (decile not in placebo)", n_missing)
        popn <- popn %>% filter(!is.na(theta_D))
    }

    n_pairs_final <- nrow(popn)
    mean_theta_D <- mean(popn$theta_D, na.rm = TRUE)
    sd_theta_D <- sd(popn$theta_D, na.rm = TRUE)
    se_mean <- sd_theta_D / sqrt(n_pairs_final)

    say("  Final n: %d  mean_theta_D: %.6f  se: %.6f", n_pairs_final, mean_theta_D, se_mean)

    # 4. Compute gradient by pre-trade quintile (same as S28_gradient_B.R)
    popn$quintile <- as.integer(cut(rank(popn$pre_trade), breaks = 5, labels = FALSE))

    by_q <- popn %>%
        group_by(quintile) %>%
        summarise(mean_D = mean(theta_D, na.rm = TRUE), .groups = "drop")

    q1_mean <- by_q$mean_D[by_q$quintile == 1]
    q5_mean <- by_q$mean_D[by_q$quintile == 5]
    gradient_spread <- q1_mean - q5_mean

    say("  Q1: %.6f  Q5: %.6f  spread: %.6f", q1_mean, q5_mean, gradient_spread)

    data.frame(
        min_pre = min_pre,
        min_post = min_post,
        n_pairs = n_pairs_final,
        mean_theta_D = mean_theta_D,
        se_mean = se_mean,
        sd_theta_D = sd_theta_D,
        gradient_q1_mean = q1_mean,
        gradient_q5_mean = q5_mean,
        gradient_spread = gradient_spread
    )
}

# =============================================================================
# COMPUTE THE GRID
# =============================================================================
say("\n=== COMPUTING 16-CELL GRID ===")

grid_values <- c(2, 3, 4, 5)
results <- list()
idx <- 0

for (mp in grid_values) {
    for (mpo in grid_values) {
        idx <- idx + 1
        results[[idx]] <- compute_cell(mp, mpo)
    }
}

T30 <- bind_rows(results) %>% arrange(min_pre, min_post)

say("\n=== GRID RESULTS ===")
print(as.data.frame(T30))

# =============================================================================
# C1 BASELINE GATE
# =============================================================================
say("\n=== C1 BASELINE GATE ===")

baseline_row <- T30 %>% filter(min_pre == 3, min_post == 3)

say("Baseline cell (3,3):")
say("  n_pairs:      %d  (expected 4182)", baseline_row$n_pairs)
say("  mean_theta_D: %.4f  (expected 0.2473)", baseline_row$mean_theta_D)
say("  se_mean:      %.4f  (expected 0.0241)", baseline_row$se_mean)

# C1 assertions with stopifnot (not prose)
# Note: SE 0.0241 is the canonical value per canonical_facts.md MEAN_THETA_D row
stopifnot(baseline_row$n_pairs == 4182)
stopifnot(abs(baseline_row$mean_theta_D - 0.2473) < 0.0001)
stopifnot(abs(baseline_row$se_mean - 0.0241) < 0.0001)

say("C1 BASELINE GATE: PASS")

# =============================================================================
# WRITE OUTPUT
# =============================================================================
say("\n=== WRITING OUTPUT ===")

write.csv(T30, file.path(RTA_ROOT, "output/T30_threshold_grid.csv"), row.names = FALSE)
osha <- get_sha256(file.path(RTA_ROOT, "output/T30_threshold_grid.csv"))

say("Wrote output/T30_threshold_grid.csv  SHA256: %s", osha)

# Sidecar
writeLines(c(
    "FILE:      T30_threshold_grid.csv",
    sprintf("SHA256:    %s", osha),
    sprintf("PRODUCER:  code/S31_threshold_grid.R (SHA256: %s)",
            get_sha256(file.path(RTA_ROOT, "code/S31_threshold_grid.R"))),
    "INPUTS:    data/S1R_ppml.rds, data/S3R_theta.rds",
    sprintf("SEED:      %d", SEED),
    "GRID:      min_pre x min_post in {2,3,4,5} x {2,3,4,5}",
    "HELD FIXED: ANTICIP=1, ADOPT_LO=1991, ADOPT_HI=2016, size-decile b_hat",
    "GATE:      C1_baseline [PASS, n=4182, mean=0.2473, se=0.0241]",
    sprintf("N_MIN:     %d", min(T30$n_pairs)),
    sprintf("N_MAX:     %d", max(T30$n_pairs)),
    sprintf("MEAN_MIN:  %.4f", min(T30$mean_theta_D)),
    sprintf("MEAN_MAX:  %.4f", max(T30$mean_theta_D)),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "output/T30_threshold_grid.csv.sidecar"))

say("Wrote output/T30_threshold_grid.csv.sidecar")
say("\nDone: %s", format(Sys.time()))
