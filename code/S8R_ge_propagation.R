#!/usr/bin/env Rscript
# =============================================================================
# S8R_ge_propagation.R - GE Trade Cost Change Quantiles (FIXED CHAIN)
# =============================================================================
# OUTPUTS: data/S8R_ge.rds
# INPUTS:  data/S5R_bhat.rds (theta_D values), gravity_functions.R, ITPDE_total.rds
# EXPECTED_N: 4182
# SEED:    20260719
# GATES:   A (plumbing), B (market clearing), C (convergence)
# NOTE:    Uses dplyr (no data.table) for Festus compatibility.
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(fixest))
suppressPackageStartupMessages(library(parallel))
setFixest_nthreads(1)

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEED <- 20260719
N_DRAWS <- 500
set.seed(SEED)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S8R: GE PROPAGATION QUANTILES (FIXED CHAIN)")
say("Start: %s", format(Sys.time()))
say("================================================================")

N_CORES <- detectCores()
say("Available cores: %d", N_CORES)

# =============================================================================
# LOAD SOLVER
# =============================================================================
say("")
say("=== LOAD SOLVER ===")
solver_path <- "/groups/m-larch/bt307958/tails/programs/gravity_functions.R"
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
say("BASELINE theta_D: n=%d, mean=%.4f, sd=%.4f", length(theta_D), mean(theta_D), sd(theta_D))

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
# DEFINE MEDIAN DYAD
# =============================================================================
non_rta_dyads <- df_2019 %>%
    filter(intl == 1, rta == 0, trade > 0) %>%
    mutate(pair = paste(pmin(iso_x, iso_i), pmax(iso_x, iso_i), sep = "_"))

pair_trade <- non_rta_dyads %>%
    group_by(pair) %>%
    summarise(two_way = sum(trade), n_dir = n(), .groups = "drop") %>%
    filter(n_dir == 2) %>%
    arrange(two_way)

median_idx <- ceiling(nrow(pair_trade) / 2)
DYAD_MED <- strsplit(pair_trade$pair[median_idx], "_")[[1]]
say("Median dyad: %s - %s", DYAD_MED[1], DYAD_MED[2])

# =============================================================================
# BASELINE SOLVE & GATES
# =============================================================================
say("")
say("=== BASELINE SOLVE ===")
params <- list(sig = 5)

# Convert df_2019 to data.frame for solver compatibility
df_2019_df <- as.data.frame(df_2019)

baseline_result <- solve_gravity_single_year(cost_eq = cost_eq_clean, df_year = df_2019_df,
                                              params = params, verbose = TRUE, return_equilibrium = TRUE)
baseline_trade <- baseline_result$trade
baseline_eq <- baseline_result$equilibrium
dict <- baseline_eq$dict

# Gate A: Plumbing (zero shock reproduces baseline)
cf_zero <- solve_gravity_single_year(cost_eq = cost_eq_clean, df_year = df_2019_df,
                                      params = params, verbose = FALSE, return_equilibrium = TRUE)
merged <- merge(baseline_trade, cf_zero$trade, by = c("year", "exporter", "importer"), suffixes = c(".base", ".cf"))
max_diff <- max(abs(merged$trade.base - merged$trade.cf))
say("GATE A (plumbing): %.2e - %s", max_diff, ifelse(max_diff < 1e-8, "PASS", "FAIL"))
stopifnot("GATE A failed" = max_diff < 1e-8)

# Gate B: Market clearing
trade_matrix <- reshape2::dcast(baseline_trade, exporter ~ importer, value.var = "trade", fill = 0)
exporters <- trade_matrix$exporter
trade_mat <- as.matrix(trade_matrix[, -1])
Y_ordered <- baseline_eq$Y[match(exporters, dict$iso)]
E_ordered <- baseline_eq$E[match(colnames(trade_mat), dict$iso)]
max_row_diff <- max(abs(rowSums(trade_mat) - Y_ordered) / Y_ordered, na.rm = TRUE)
max_col_diff <- max(abs(colSums(trade_mat) - E_ordered) / E_ordered, na.rm = TRUE)
say("GATE B (market clearing): row=%.4f%%, col=%.4f%% - %s",
    max_row_diff*100, max_col_diff*100, ifelse(max_row_diff < 0.001 && max_col_diff < 0.001, "PASS", "FAIL"))
stopifnot("GATE B failed" = max_row_diff < 0.001 && max_col_diff < 0.001)

# =============================================================================
# PARALLEL COUNTERFACTUAL SIMULATION
# =============================================================================
say("")
say("=== PARALLEL COUNTERFACTUAL SIMULATION ===")

set.seed(SEED)
draws <- sample(theta_D, N_DRAWS, replace = TRUE)
say("Draws: n=%d, mean=%.4f, sd=%.4f", N_DRAWS, mean(draws), sd(draws))

dyad <- DYAD_MED
idx1 <- which(df_2019$iso_x == dyad[1] & df_2019$iso_i == dyad[2])
idx2 <- which(df_2019$iso_x == dyad[2] & df_2019$iso_i == dyad[1])

base_trade_1 <- baseline_trade[baseline_trade$exporter == dyad[1] & baseline_trade$importer == dyad[2], ]$trade
base_trade_2 <- baseline_trade[baseline_trade$exporter == dyad[2] & baseline_trade$importer == dyad[1], ]$trade
base_two_way <- base_trade_1 + base_trade_2
say("Baseline two-way trade: %.4f", base_two_way)

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

t_start <- Sys.time()
n_use <- min(N_CORES, 8)
say("Running %d counterfactuals on %d cores...", N_DRAWS, n_use)
results <- mclapply(1:N_DRAWS, run_cf, mc.cores = n_use)
trade_changes <- unlist(results)
t_end <- Sys.time()
elapsed <- as.numeric(difftime(t_end, t_start, units = "secs"))
say("Completed in %.1f seconds (%.3f sec/draw)", elapsed, elapsed/N_DRAWS)

# Gate C: Convergence
n_failed <- sum(is.na(trade_changes))
fail_rate <- n_failed / N_DRAWS
say("GATE C (convergence): %d/%d failed (%.1f%%) - %s",
    n_failed, N_DRAWS, fail_rate*100, ifelse(fail_rate < 0.02, "PASS", "FAIL"))
stopifnot("GATE C failed: too many non-convergent draws" = fail_rate < 0.02)

# =============================================================================
# RESULTS
# =============================================================================
say("")
say("=== RESULTS ===")
tc <- trade_changes[!is.na(trade_changes)]
q10 <- quantile(tc, 0.10)
q25 <- quantile(tc, 0.25)
q50 <- quantile(tc, 0.50)
q75 <- quantile(tc, 0.75)
q90 <- quantile(tc, 0.90)
range_1090 <- (1 + q90) / (1 + q10)

say("Trade change quantiles (sigma=5):")
say("  q10: %+.4f, q25: %+.4f, q50: %+.4f, q75: %+.4f, q90: %+.4f", q10, q25, q50, q75, q90)
say("  Range (1+q90)/(1+q10): %.4f", range_1090)

# Normal comparison
set.seed(SEED)
theta_normal <- rnorm(N_DRAWS, mean = mean(theta_D), sd = sd(theta_D))
tc_normal <- exp(theta_normal) - 1
range_normal <- (1 + quantile(tc_normal, 0.90)) / (1 + quantile(tc_normal, 0.10))
say("  Normal range: %.4f", range_normal)

# =============================================================================
# OUTPUT
# =============================================================================
output <- list(
  dyad = DYAD_MED,
  sigma = 5,
  n_draws = N_DRAWS,
  n_valid = sum(!is.na(trade_changes)),
  trade_changes = tc,
  quantiles = c(q10 = q10, q25 = q25, q50 = q50, q75 = q75, q90 = q90),
  range_1090 = range_1090,
  range_normal = range_normal,
  theta_D_summary = list(n = length(theta_D), mean = mean(theta_D), sd = sd(theta_D)),
  gates = list(
    A_plumbing = max_diff,
    B_market_clearing = c(row = max_row_diff, col = max_col_diff),
    C_convergence = fail_rate
  ),
  seed = SEED,
  solver_sha = solver_sha
)

saveRDS(output, "data/S8R_ge.rds")
osha <- get_sha256("data/S8R_ge.rds")

writeLines(c(
    "FILE:      S8R_ge.rds",
    sprintf("SHA256:    %s", osha),
    sprintf("PRODUCER:  code/S8R_ge_propagation.R (SHA256: %s)", get_sha256("code/S8R_ge_propagation.R")),
    "INPUTS:    data/S5R_bhat.rds, gravity_functions.R, ITPDE_total.rds",
    sprintf("SEED:      %d", SEED),
    sprintf("N_DRAWS:   %d", N_DRAWS),
    "SIGMA:     5",
    sprintf("DYAD:      %s-%s", DYAD_MED[1], DYAD_MED[2]),
    "GATE:      A_plumbing [PASS]",
    "GATE:      B_market_clearing [PASS]",
    "GATE:      C_convergence [PASS]",
    sprintf("Q10:       %+.4f", q10),
    sprintf("Q50:       %+.4f", q50),
    sprintf("Q90:       %+.4f", q90),
    sprintf("RANGE_1090: %.4f", range_1090),
    sprintf("RANGE_NORMAL: %.4f", range_normal),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/S8R_ge.rds.sidecar")

say("")
say("Wrote data/S8R_ge.rds  SHA %s", osha)
say("Done: %s", format(Sys.time()))
