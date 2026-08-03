#!/usr/bin/env Rscript
# =============================================================================
# S46_ge_twodyad.R - Two-Dyad Arm-Indexed GE Propagation
# =============================================================================
# OUTPUTS: data/S46_ge_twodyad.rds
# INPUTS:  data/S5R_bhat.rds, code/vendor/gravity_functions.R, data/ITPDE_total.rds
# SEED:    20260803
# GATES:   G1 (plumbing), G2 (market clearing), G3 (convergence), G4 (arm monotonicity)
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
set.seed(SEED)

# Arm-indexed SD_true from canonical_facts.md
SD_TRUE_LO <- 0.74
SD_TRUE_HI <- 1.48

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S46: TWO-DYAD ARM-INDEXED GE PROPAGATION")
say("Start: %s", format(Sys.time()))
say("================================================================")

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

# =============================================================================
# LOAD THETA_D FROM S5R
# =============================================================================
say("")
say("=== LOAD THETA_D ===")
S5R <- readRDS("data/S5R_bhat.rds")
base <- S5R$baseline
stopifnot(nrow(base) == 4182)
theta_D <- base$theta_D
MEAN_THETA_D <- mean(theta_D)
say("BASELINE theta_D: n=%d, mean=%.4f, sd=%.4f", length(theta_D), MEAN_THETA_D, sd(theta_D))

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
# DEFINE TWO DYADS (MEDIAN AND 25TH PERCENTILE BY TRADE)
# =============================================================================
say("")
say("=== SELECT TWO DYADS ===")
non_rta_dyads <- df_2019 %>%
    filter(intl == 1, rta == 0, trade > 0) %>%
    mutate(pair = paste(pmin(iso_x, iso_i), pmax(iso_x, iso_i), sep = "_"))

pair_trade <- non_rta_dyads %>%
    group_by(pair) %>%
    summarise(two_way = sum(trade), n_dir = n(), .groups = "drop") %>%
    filter(n_dir == 2) %>%
    arrange(two_way)

# Median dyad (50th percentile)
median_idx <- ceiling(nrow(pair_trade) / 2)
DYAD_MED <- strsplit(pair_trade$pair[median_idx], "_")[[1]]
say("Median dyad (q50): %s - %s", DYAD_MED[1], DYAD_MED[2])

# 25th percentile dyad (smaller trade volume)
q25_idx <- ceiling(nrow(pair_trade) / 4)
DYAD_Q25 <- strsplit(pair_trade$pair[q25_idx], "_")[[1]]
say("Q25 dyad: %s - %s", DYAD_Q25[1], DYAD_Q25[2])

DYADS <- list(
    list(name = "median", iso = DYAD_MED),
    list(name = "q25", iso = DYAD_Q25)
)

# =============================================================================
# BASELINE SOLVE & GATES
# =============================================================================
say("")
say("=== BASELINE SOLVE ===")
params <- list(sig = 5)
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
# ARM-INDEXED COUNTERFACTUAL SIMULATION
# =============================================================================
say("")
say("=== ARM-INDEXED COUNTERFACTUAL SIMULATION ===")

ARMS <- list(
    list(name = "lo", sd_true = SD_TRUE_LO),
    list(name = "hi", sd_true = SD_TRUE_HI)
)

results_all <- list()

for (dyad_info in DYADS) {
    dyad <- dyad_info$iso
    dyad_name <- dyad_info$name

    idx1 <- which(df_2019$iso_x == dyad[1] & df_2019$iso_i == dyad[2])
    idx2 <- which(df_2019$iso_x == dyad[2] & df_2019$iso_i == dyad[1])

    base_trade_1 <- baseline_trade[baseline_trade$exporter == dyad[1] & baseline_trade$importer == dyad[2], ]$trade
    base_trade_2 <- baseline_trade[baseline_trade$exporter == dyad[2] & baseline_trade$importer == dyad[1], ]$trade
    base_two_way <- base_trade_1 + base_trade_2
    say("Dyad %s baseline two-way trade: %.4f", dyad_name, base_two_way)

    for (arm in ARMS) {
        arm_name <- arm$name
        sd_true <- arm$sd_true

        say("  Running arm=%s (SD_true=%.2f)...", arm_name, sd_true)

        set.seed(SEED)
        draws <- rnorm(N_DRAWS, mean = MEAN_THETA_D, sd = sd_true)

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
            arm = arm_name,
            sd_true = sd_true,
            n_draws = N_DRAWS,
            n_valid = sum(!is.na(trade_changes)),
            fail_rate = fail_rate,
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
# For each dyad, range_hi should be >= range_lo
g4_pass <- TRUE
for (dyad_info in DYADS) {
    dyad_name <- dyad_info$name
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
# OUTPUT
# =============================================================================
say("")
say("=== OUTPUT ===")

# Create summary table
summary_table <- do.call(rbind, lapply(results_all, function(x) {
    data.frame(
        dyad = x$dyad,
        arm = x$arm,
        sd_true = x$sd_true,
        n_valid = x$n_valid,
        q10 = x$q10,
        q50 = x$q50,
        q90 = x$q90,
        range_1090 = x$range_1090,
        stringsAsFactors = FALSE
    )
}))
rownames(summary_table) <- NULL
print(summary_table)

output <- list(
    dyads = list(
        median = DYAD_MED,
        q25 = DYAD_Q25
    ),
    arms = list(
        lo = SD_TRUE_LO,
        hi = SD_TRUE_HI
    ),
    sigma = 5,
    n_draws = N_DRAWS,
    mean_theta_D = MEAN_THETA_D,
    results = results_all,
    summary_table = summary_table,
    gates = list(
        G1_plumbing = max_diff,
        G2_market_clearing = c(row = max_row_diff, col = max_col_diff),
        G3_convergence = max_fail_rate,
        G4_arm_monotonicity = g4_pass
    ),
    seed = SEED,
    solver_sha = solver_sha
)

saveRDS(output, "data/S46_ge_twodyad.rds")
osha <- get_sha256("data/S46_ge_twodyad.rds")

writeLines(c(
    "FILE:      S46_ge_twodyad.rds",
    sprintf("SHA256:    %s", osha),
    sprintf("PRODUCER:  code/S46_ge_twodyad.R (SHA256: %s)", get_sha256("code/S46_ge_twodyad.R")),
    "INPUTS:    data/S5R_bhat.rds, gravity_functions.R, ITPDE_total.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("N_DRAWS:   %d", N_DRAWS),
    "SIGMA:     5",
    sprintf("DYADS:     median(%s-%s), q25(%s-%s)", DYAD_MED[1], DYAD_MED[2], DYAD_Q25[1], DYAD_Q25[2]),
    sprintf("ARMS:      lo(SD=%.2f), hi(SD=%.2f)", SD_TRUE_LO, SD_TRUE_HI),
    "GATE:      G1_plumbing [PASS]",
    "GATE:      G2_market_clearing [PASS]",
    "GATE:      G3_convergence [PASS]",
    "GATE:      G4_arm_monotonicity [PASS]",
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/S46_ge_twodyad.rds.sidecar")

say("")
say("Wrote data/S46_ge_twodyad.rds  SHA %s", osha)
say("Done: %s", format(Sys.time()))
