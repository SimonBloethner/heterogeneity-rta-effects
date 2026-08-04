#!/usr/bin/env Rscript
# =============================================================================
# S47_ge_gradient.R - Quintile-Conditional GE Propagation (Gradient Propagated)
# =============================================================================
# OUTPUTS: data/S47_ge_gradient.rds, output/T43_ge_gradient.csv
# INPUTS:  data/S5R_bhat.rds, code/vendor/gravity_functions.R, data/ITPDE_total.rds
#          meta/canonical_facts.md (GRADIENT_Q1, GRADIENT_Q5)
# SEED:    20260803
# GATES:   G1 (plumbing), G2 (market clearing), G3 (convergence), G4 (arm monotonicity),
#          E (draw SD), G5 (Q1 vs Q5 q50 difference)
# EXPECTED_N: 4182 (adopting population from S5R_bhat.rds$baseline)
# SCENARIO: Conditional GE (Y, E held at data values; see solver lines 43-44, 72-74)
# NOTE:    SD_THETA_TRUE is the identified set for the *population*; within-quintile
#          dispersion is not ledgered. Using the population set quintile-wise is an
#          assumption, not a measurement.
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(fixest))
suppressPackageStartupMessages(library(parallel))
setFixest_nthreads(1)

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEED <- 20260803
N_DRAWS <- 500
SIGMA <- 5
set.seed(SEED)

# Arm-indexed SD_true from canonical_facts.md [SD_THETA_TRUE]
SD_TRUE_LO <- 0.74
SD_TRUE_HI <- 1.48

# Quintile-specific means from canonical_facts.md [GRADIENT_Q1, GRADIENT_Q5]
# Parse from canonical_facts.md using positional split (matches S45_ledger_constants.R)
parse_ledger_value <- function(id) {
    facts <- readLines("meta/canonical_facts.md")
    row   <- grep(sprintf("^\\|\\s*%s\\s*\\|", id), facts, value = TRUE)
    stopifnot("ID must match exactly one ledger row" = length(row) == 1L)
    parts <- trimws(strsplit(row[1], "\\|")[[1]])
    val   <- suppressWarnings(as.numeric(parts[4]))
    stopifnot("Value column must parse to a number" = !is.na(val))
    val
}

GRADIENT_Q1 <- parse_ledger_value("GRADIENT_Q1")
GRADIENT_Q5 <- parse_ledger_value("GRADIENT_Q5")

# Gates: verify parsed values match expected (would have caught greedy-regex bug)
stopifnot(
    "GRADIENT_Q1 must parse to 0.8554"  = abs(GRADIENT_Q1 - 0.8554)  < 1e-9,
    "GRADIENT_Q5 must parse to -0.0583" = abs(GRADIENT_Q5 - (-0.0583)) < 1e-9,
    "Q5 mean must be negative"          = GRADIENT_Q5 < 0
)

# Draw SD tolerance for Gate E
DRAW_SD_TOL <- 0.05

# Monte Carlo noise tolerance for Gate G5 (Q1 vs Q5 q50 difference)
Q50_DIFF_TOL <- 0.05  # Minimum expected difference based on gradient

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S47: QUINTILE-CONDITIONAL GE PROPAGATION (GRADIENT PROPAGATED)")
say("Start: %s", format(Sys.time()))
say("================================================================")

say("GRADIENT_Q1 (from ledger): %.4f", GRADIENT_Q1)
say("GRADIENT_Q5 (from ledger): %.4f", GRADIENT_Q5)

N_CORES <- detectCores()
say("Available cores: %d", N_CORES)

# =============================================================================
# LOAD SOLVER
# =============================================================================
say("")
say("=== LOAD SOLVER ===")
solver_path <- file.path(REBUILD_DIR, "code/vendor/gravity_functions.R")
source(solver_path)
solver_sha <- get_sha256(solver_path)
say("Solver SHA: %s", solver_sha)
SOLVER_SHA_EXPECTED <- "859408d8770e0e3657d38d4ec82ac3b3095ebeb615120ed5cf5ced912fa91783"
stopifnot("solver hash does not match the vendored copy" =
              identical(solver_sha, SOLVER_SHA_EXPECTED))

# =============================================================================
# LOAD THETA_D AND PRE-ADOPTION TRADE FROM S5R
# =============================================================================
say("")
say("=== LOAD ADOPTING POPULATION ===")
S5R <- readRDS("data/S5R_bhat.rds")
base <- S5R$baseline
stopifnot("Adopting population must be n=4182" = nrow(base) == 4182)

theta_D <- base$theta_D
MEAN_THETA_D <- mean(theta_D)
say("BASELINE theta_D: n=%d, mean=%.4f, sd=%.4f", length(theta_D), MEAN_THETA_D, sd(theta_D))

# Pre-adoption trade for quintile assignment
pre_trade <- base$pre_trade
say("Pre-adoption trade: min=%.2f, median=%.2f, max=%.2f", min(pre_trade), median(pre_trade), max(pre_trade))

# =============================================================================
# QUINTILE PARTITION (LEDGERED RULE)
# =============================================================================
say("")
say("=== QUINTILE PARTITION ===")
# Ledgered rule from canonical_facts.md Note (partition) and code/S28_gradient_B.R
quintile <- as.integer(cut(rank(pre_trade), breaks = 5, labels = FALSE))

# Assert expected cell sizes: 837 / 836 / 836 / 836 / 837
cell_sizes <- table(quintile)
say("Cell sizes: %s", paste(cell_sizes, collapse = " / "))
stopifnot(
    "Quintile 1 must have 837 pairs" = cell_sizes[1] == 837,
    "Quintile 2 must have 836 pairs" = cell_sizes[2] == 836,
    "Quintile 3 must have 836 pairs" = cell_sizes[3] == 836,
    "Quintile 4 must have 836 pairs" = cell_sizes[4] == 836,
    "Quintile 5 must have 837 pairs" = cell_sizes[5] == 837
)
say("Cell size assertion: PASS")

# =============================================================================
# SELECT MEDIAN PAIRS WITHIN Q1 AND Q5
# =============================================================================
say("")
say("=== SELECT CALIBRATION DYADS ===")

# Attach quintile assignment (pair column already exists in baseline)
base$quintile <- quintile

# Q1: smallest pre-trade
q1_pairs <- base[base$quintile == 1, ]
q1_pairs <- q1_pairs[order(q1_pairs$pre_trade), ]
q1_median_idx <- ceiling(nrow(q1_pairs) / 2)
dyad_lo_row <- q1_pairs[q1_median_idx, ]
dyad_lo <- dyad_lo_row$pair
dyad_lo_iso <- strsplit(dyad_lo, "_")[[1]]
say("Q1 median dyad: %s (pre_trade=%.4f)", dyad_lo, dyad_lo_row$pre_trade)

# Q5: largest pre-trade
q5_pairs <- base[base$quintile == 5, ]
q5_pairs <- q5_pairs[order(q5_pairs$pre_trade), ]
q5_median_idx <- ceiling(nrow(q5_pairs) / 2)
dyad_hi_row <- q5_pairs[q5_median_idx, ]
dyad_hi <- dyad_hi_row$pair
dyad_hi_iso <- strsplit(dyad_hi, "_")[[1]]
say("Q5 median dyad: %s (pre_trade=%.4f)", dyad_hi, dyad_hi_row$pre_trade)

# Binding assertions - must reproduce T42 dyads
stopifnot(
    "Q1 dyad must reproduce T42" = identical(dyad_lo, "LUX_ATG"),
    "Q5 dyad must reproduce T42" = identical(dyad_hi, "NLD_CRI"),
    "dyad_lo must be in quintile 1" = base$quintile[match(dyad_lo, base$pair)] == 1L,
    "dyad_hi must be in quintile 5" = base$quintile[match(dyad_hi, base$pair)] == 5L
)
say("Dyad assertions (T42 reproduction): PASS")

# =============================================================================
# LOAD 2019 DATA & CONSTRUCT COST_EQ
# =============================================================================
say("")
say("=== PREPARE DATA ===")
df_full <- readRDS("/groups/m-larch/bt307958/tails/data/ITPDE_total.rds")
df_full <- df_full %>% rename(iso_x = exporter, iso_i = importer)
df_2019 <- df_full %>% filter(year == 2019)
df_2019 <- df_2019 %>%
    mutate(log_dist = log(distance),
           intl = as.integer(iso_x != iso_i))

df_pos <- df_2019 %>% filter(trade > 0)
fit <- fepois(trade ~ log_dist + intl + rta | iso_x + iso_i, data = df_pos)
coefs <- coef(fit)
df_2019 <- df_2019 %>%
    mutate(cost_eq = exp(coefs["log_dist"] * log_dist + coefs["intl"] * intl + coefs["rta"] * rta))
df_2019$cost_eq[is.na(df_2019$cost_eq)] <- 1
cost_eq_clean <- df_2019$cost_eq

# =============================================================================
# BASELINE SOLVE & GATES G1, G2
# =============================================================================
say("")
say("=== BASELINE SOLVE ===")
params <- list(sig = SIGMA)
df_2019_df <- as.data.frame(df_2019)

baseline_result <- solve_gravity_single_year(cost_eq = cost_eq_clean, df_year = df_2019_df,
                                              params = params, verbose = TRUE, return_equilibrium = TRUE)
baseline_trade <- baseline_result$trade
baseline_eq <- baseline_result$equilibrium
dict <- baseline_eq$dict

# Gate G1: Plumbing (zero shock reproduces baseline)
cf_zero <- solve_gravity_single_year(cost_eq = cost_eq_clean, df_year = df_2019_df,
                                      params = params, verbose = FALSE, return_equilibrium = TRUE)
merged <- merge(baseline_trade, cf_zero$trade, by = c("year", "exporter", "importer"), suffixes = c(".base", ".cf"))
max_diff <- max(abs(merged$trade.base - merged$trade.cf))
say("GATE G1 (plumbing): %.2e - %s", max_diff, ifelse(max_diff < 1e-8, "PASS", "FAIL"))
stopifnot("GATE G1 failed" = max_diff < 1e-8)

# Gate G2: Market clearing
trade_matrix <- reshape2::dcast(baseline_trade, exporter ~ importer, value.var = "trade", fill = 0)
exporters <- trade_matrix$exporter
trade_mat <- as.matrix(trade_matrix[, -1])
Y_ordered <- baseline_eq$Y[match(exporters, dict$iso)]
E_ordered <- baseline_eq$E[match(colnames(trade_mat), dict$iso)]
max_row_diff <- max(abs(rowSums(trade_mat) - Y_ordered) / Y_ordered, na.rm = TRUE)
max_col_diff <- max(abs(colSums(trade_mat) - E_ordered) / E_ordered, na.rm = TRUE)
say("GATE G2 (market clearing): row=%.4f%%, col=%.4f%% - %s",
    max_row_diff*100, max_col_diff*100, ifelse(max_row_diff < 0.001 && max_col_diff < 0.001, "PASS", "FAIL"))
stopifnot("GATE G2 failed" = max_row_diff < 0.001 && max_col_diff < 0.001)

# =============================================================================
# QUINTILE-CONDITIONAL COUNTERFACTUAL SIMULATION
# =============================================================================
say("")
say("=== QUINTILE-CONDITIONAL COUNTERFACTUAL SIMULATION ===")

ARMS <- list(
    list(name = "lo", sd_true = SD_TRUE_LO),
    list(name = "hi", sd_true = SD_TRUE_HI)
)

# KEY DIFFERENCE FROM S46: Each dyad draws from its own quintile mean
DYADS <- list(
    list(name = "Q1", iso = dyad_lo_iso, quintile = 1, pair = dyad_lo, pre_trade = dyad_lo_row$pre_trade, mean_theta = GRADIENT_Q1),
    list(name = "Q5", iso = dyad_hi_iso, quintile = 5, pair = dyad_hi, pre_trade = dyad_hi_row$pre_trade, mean_theta = GRADIENT_Q5)
)

results_all <- list()

for (dyad_info in DYADS) {
    dyad <- dyad_info$iso
    dyad_name <- dyad_info$name
    dyad_mean <- dyad_info$mean_theta

    idx1 <- which(df_2019$iso_x == dyad[1] & df_2019$iso_i == dyad[2])
    idx2 <- which(df_2019$iso_x == dyad[2] & df_2019$iso_i == dyad[1])

    base_trade_1 <- baseline_trade[baseline_trade$exporter == dyad[1] & baseline_trade$importer == dyad[2], ]$trade
    base_trade_2 <- baseline_trade[baseline_trade$exporter == dyad[2] & baseline_trade$importer == dyad[1], ]$trade
    base_two_way <- base_trade_1 + base_trade_2
    say("Dyad %s (%s) baseline two-way trade: %.4f, MEAN_THETA=%.4f", dyad_name, dyad_info$pair, base_two_way, dyad_mean)

    for (arm in ARMS) {
        arm_name <- arm$name
        sd_true <- arm$sd_true

        say("  Running arm=%s (SD_true=%.2f, MEAN=%.4f)...", arm_name, sd_true, dyad_mean)

        set.seed(SEED)
        # QUINTILE-CONDITIONAL: Draw from N(GRADIENT_Qi, SD_true), not N(MEAN_THETA_D, SD_true)
        draws <- rnorm(N_DRAWS, mean = dyad_mean, sd = sd_true)

        # Gate E: Draw SD must match target
        draw_sd <- sd(draws)
        say("    Draw SD: %.4f (target: %.2f, diff: %.4f)", draw_sd, sd_true, abs(draw_sd - sd_true))
        stopifnot("GATE E failed: draw SD deviates from SD_true" = abs(draw_sd - sd_true) < DRAW_SD_TOL)

        # Worker function
        run_cf <- function(d) {
            theta <- draws[d]
            shock <- exp(theta)
            shocked_cost <- cost_eq_clean
            shocked_cost[idx1] <- shocked_cost[idx1] * shock
            shocked_cost[idx2] <- shocked_cost[idx2] * shock

            cf <- tryCatch({
                solve_gravity_single_year(cost_eq = shocked_cost, df_year = df_2019_df,
                                           params = params, verbose = FALSE, return_equilibrium = TRUE)
            }, error = function(e) list(trade = NULL))

            if (!is.null(cf$trade)) {
                cf_trade_1 <- cf$trade[cf$trade$exporter == dyad[1] & cf$trade$importer == dyad[2], ]$trade
                cf_trade_2 <- cf$trade[cf$trade$exporter == dyad[2] & cf$trade$importer == dyad[1], ]$trade
                return((cf_trade_1 + cf_trade_2 - base_two_way) / base_two_way)
            }
            return(NA)
        }

        n_use <- min(N_CORES, 8)
        t_start <- Sys.time()
        cf_results <- mclapply(1:N_DRAWS, run_cf, mc.cores = n_use)
        trade_changes <- unlist(cf_results)
        t_end <- Sys.time()
        elapsed <- as.numeric(difftime(t_end, t_start, units = "secs"))
        say("    Completed in %.1f seconds", elapsed)

        tc <- trade_changes[!is.na(trade_changes)]
        n_failed <- sum(is.na(trade_changes))
        fail_rate <- n_failed / N_DRAWS

        q10 <- quantile(tc, 0.10)
        q50 <- quantile(tc, 0.50)
        q90 <- quantile(tc, 0.90)
        range_1090 <- (1 + q90) / (1 + q10)

        results_all[[paste(dyad_name, arm_name, sep = "_")]] <- list(
            dyad = dyad_name,
            dyad_pair = dyad_info$pair,
            dyad_quintile = dyad_info$quintile,
            mean_theta = dyad_mean,
            arm = arm_name,
            sd_true = sd_true,
            n_draws = N_DRAWS,
            n_valid = sum(!is.na(trade_changes)),
            fail_rate = fail_rate,
            draw_sd = draw_sd,
            q10 = as.numeric(q10),
            q50 = as.numeric(q50),
            q90 = as.numeric(q90),
            range_1090 = range_1090,
            trade_changes = tc
        )

        say("    q10=%.4f, q50=%.4f, q90=%.4f, RANGE=%.4f, fail_rate=%.3f",
            q10, q50, q90, range_1090, fail_rate)
    }
}

# =============================================================================
# GATE G3: CONVERGENCE (all cells)
# =============================================================================
say("")
say("=== GATE G3: CONVERGENCE ===")
all_fail_rates <- sapply(results_all, function(x) x$fail_rate)
max_fail_rate <- max(all_fail_rates)
say("Max fail rate across cells: %.3f - %s", max_fail_rate, ifelse(max_fail_rate < 0.02, "PASS", "FAIL"))
stopifnot("GATE G3 failed: too many non-convergent draws" = max_fail_rate < 0.02)

# =============================================================================
# GATE G4: ARM MONOTONICITY (higher SD_true => wider range)
# =============================================================================
say("")
say("=== GATE G4: ARM MONOTONICITY ===")
g4_pass <- TRUE
for (dyad_name in c("Q1", "Q5")) {
    range_lo <- results_all[[paste(dyad_name, "lo", sep = "_")]]$range_1090
    range_hi <- results_all[[paste(dyad_name, "hi", sep = "_")]]$range_1090
    mono_ok <- range_hi >= range_lo
    say("  Dyad %s: range_lo=%.4f, range_hi=%.4f - %s",
        dyad_name, range_lo, range_hi, ifelse(mono_ok, "MONO", "ANTI-MONO"))
    if (!mono_ok) g4_pass <- FALSE
}
say("GATE G4 (arm monotonicity): %s", ifelse(g4_pass, "PASS", "FAIL"))
stopifnot("GATE G4 failed: arm monotonicity violated" = g4_pass)

# =============================================================================
# GATE G5: Q1 VS Q5 Q50 DIFFERENCE (quintile-conditional draw took effect)
# =============================================================================
say("")
say("=== GATE G5: Q1 VS Q5 Q50 DIFFERENCE ===")
# Compare within same arm - the higher mean (Q1=0.8554) should produce higher q50
# than the lower mean (Q5=-0.0583)
q50_Q1_lo <- results_all[["Q1_lo"]]$q50
q50_Q5_lo <- results_all[["Q5_lo"]]$q50
q50_Q1_hi <- results_all[["Q1_hi"]]$q50
q50_Q5_hi <- results_all[["Q5_hi"]]$q50

q50_diff_lo <- q50_Q1_lo - q50_Q5_lo
q50_diff_hi <- q50_Q1_hi - q50_Q5_hi

say("  Arm lo: Q1_q50=%.4f, Q5_q50=%.4f, diff=%.4f", q50_Q1_lo, q50_Q5_lo, q50_diff_lo)
say("  Arm hi: Q1_q50=%.4f, Q5_q50=%.4f, diff=%.4f", q50_Q1_hi, q50_Q5_hi, q50_diff_hi)

# Q1 mean (0.8554) is higher than Q5 mean (-0.0583), so Q1 q50 should be higher
# The difference should be substantial (> Monte Carlo noise)
g5_pass <- (q50_diff_lo > Q50_DIFF_TOL) && (q50_diff_hi > Q50_DIFF_TOL)
say("GATE G5 (Q1 vs Q5 q50 difference): %s (min_diff=%.4f, threshold=%.4f)",
    ifelse(g5_pass, "PASS", "FAIL"), min(q50_diff_lo, q50_diff_hi), Q50_DIFF_TOL)
stopifnot("GATE G5 failed: Q1 vs Q5 q50 difference not significant - quintile-conditional draw did not take effect" = g5_pass)

# =============================================================================
# OUTPUT
# =============================================================================
say("")
say("=== OUTPUT ===")

# Create summary table for CSV
summary_table <- do.call(rbind, lapply(results_all, function(x) {
    data.frame(
        arm = x$arm,
        sd_true = x$sd_true,
        dyad = x$dyad_pair,
        dyad_quintile = x$dyad_quintile,
        mean_theta = x$mean_theta,
        sigma = SIGMA,
        q10 = x$q10,
        q50 = x$q50,
        q90 = x$q90,
        RANGE_1090 = x$range_1090,
        stringsAsFactors = FALSE
    )
}))
rownames(summary_table) <- NULL
print(summary_table)

# Write CSV
if (!dir.exists("output")) dir.create("output")
write.csv(summary_table, "output/T43_ge_gradient.csv", row.names = FALSE)
csv_sha <- get_sha256("output/T43_ge_gradient.csv")
say("Wrote output/T43_ge_gradient.csv  SHA %s", csv_sha)

# Full output object
output <- list(
    dyads = list(
        Q1 = list(pair = dyad_lo, iso = dyad_lo_iso, quintile = 1, pre_trade = dyad_lo_row$pre_trade, mean_theta = GRADIENT_Q1),
        Q5 = list(pair = dyad_hi, iso = dyad_hi_iso, quintile = 5, pre_trade = dyad_hi_row$pre_trade, mean_theta = GRADIENT_Q5)
    ),
    arms = list(
        lo = SD_TRUE_LO,
        hi = SD_TRUE_HI
    ),
    gradient = list(
        Q1 = GRADIENT_Q1,
        Q5 = GRADIENT_Q5
    ),
    sigma = SIGMA,
    n_draws = N_DRAWS,
    results = results_all,
    summary_table = summary_table,
    scenario = "Conditional GE (Y, E held at data values; solver lines 43-44, 72-74)",
    gates = list(
        G1_plumbing = max_diff,
        G2_market_clearing = c(row = max_row_diff, col = max_col_diff),
        G3_convergence = max_fail_rate,
        G4_arm_monotonicity = g4_pass,
        G5_q50_difference = c(lo = q50_diff_lo, hi = q50_diff_hi),
        E_draw_sd = sapply(results_all, function(x) x$draw_sd)
    ),
    seed = SEED,
    solver_sha = solver_sha
)

saveRDS(output, "data/S47_ge_gradient.rds")
rds_sha <- get_sha256("data/S47_ge_gradient.rds")
say("Wrote data/S47_ge_gradient.rds  SHA %s", rds_sha)

# Sidecar for CSV
writeLines(c(
    "FILE:      T43_ge_gradient.csv",
    sprintf("SHA256:    %s", csv_sha),
    sprintf("PRODUCER:  code/S47_ge_gradient.R (SHA256: %s)", get_sha256("code/S47_ge_gradient.R")),
    "INPUTS:    data/S5R_bhat.rds, code/vendor/gravity_functions.R, ITPDE_total.rds, meta/canonical_facts.md",
    sprintf("SEED:      %d", SEED),
    sprintf("N_DRAWS:   %d", N_DRAWS),
    sprintf("SIGMA:     %d", SIGMA),
    sprintf("DYAD_Q1:   %s (quintile 1, pre_trade=%.4f, mean_theta=%.4f)", dyad_lo, dyad_lo_row$pre_trade, GRADIENT_Q1),
    sprintf("DYAD_Q5:   %s (quintile 5, pre_trade=%.4f, mean_theta=%.4f)", dyad_hi, dyad_hi_row$pre_trade, GRADIENT_Q5),
    sprintf("ARMS:      lo(SD=%.2f), hi(SD=%.2f)", SD_TRUE_LO, SD_TRUE_HI),
    "SCENARIO:  Conditional GE (Y, E held at data values)",
    "GATE:      G1_plumbing [PASS]",
    "GATE:      G2_market_clearing [PASS]",
    "GATE:      G3_convergence [PASS]",
    "GATE:      G4_arm_monotonicity [PASS]",
    "GATE:      G5_q50_difference [PASS]",
    "GATE:      E_draw_sd [PASS]",
    "ASSUMPTION: SD_THETA_TRUE is the identified set for the *population*; within-quintile",
    "            dispersion is not ledgered. Using the population set quintile-wise is an",
    "            assumption, not a measurement. The resulting ranges are therefore conditional",
    "            on this assumption in addition to the arm.",
    "NOTE:      cost_eq is built from PPML coefficients, already in tau^(1-sigma) units.",
    "           Multiplying by exp(theta) adds a log TRADE effect to log trade-equivalent",
    "           resistance, which is dimensionally correct.",
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/T43_ge_gradient.csv.sidecar")

# Sidecar for RDS
writeLines(c(
    "FILE:      S47_ge_gradient.rds",
    sprintf("SHA256:    %s", rds_sha),
    sprintf("PRODUCER:  code/S47_ge_gradient.R (SHA256: %s)", get_sha256("code/S47_ge_gradient.R")),
    "INPUTS:    data/S5R_bhat.rds, code/vendor/gravity_functions.R, ITPDE_total.rds, meta/canonical_facts.md",
    sprintf("SEED:      %d", SEED),
    sprintf("N_DRAWS:   %d", N_DRAWS),
    sprintf("SIGMA:     %d", SIGMA),
    sprintf("DYAD_Q1:   %s (quintile 1, pre_trade=%.4f, mean_theta=%.4f)", dyad_lo, dyad_lo_row$pre_trade, GRADIENT_Q1),
    sprintf("DYAD_Q5:   %s (quintile 5, pre_trade=%.4f, mean_theta=%.4f)", dyad_hi, dyad_hi_row$pre_trade, GRADIENT_Q5),
    sprintf("ARMS:      lo(SD=%.2f), hi(SD=%.2f)", SD_TRUE_LO, SD_TRUE_HI),
    "SCENARIO:  Conditional GE (Y, E held at data values)",
    "GATE:      G1_plumbing [PASS]",
    "GATE:      G2_market_clearing [PASS]",
    "GATE:      G3_convergence [PASS]",
    "GATE:      G4_arm_monotonicity [PASS]",
    "GATE:      G5_q50_difference [PASS]",
    "GATE:      E_draw_sd [PASS]",
    "ASSUMPTION: SD_THETA_TRUE is the identified set for the *population*; within-quintile",
    "            dispersion is not ledgered. Using the population set quintile-wise is an",
    "            assumption, not a measurement. The resulting ranges are therefore conditional",
    "            on this assumption in addition to the arm.",
    "NOTE:      cost_eq is built from PPML coefficients, already in tau^(1-sigma) units.",
    "           Multiplying by exp(theta) adds a log TRADE effect to log trade-equivalent",
    "           resistance, which is dimensionally correct.",
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/S47_ge_gradient.rds.sidecar")

say("")
say("=== ALL GATES PASSED ===")
say("Done: %s", format(Sys.time()))
