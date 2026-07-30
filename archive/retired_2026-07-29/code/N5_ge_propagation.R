#!/usr/bin/env Rscript
# =============================================================================
# N5_ge_propagation.R - GE Propagation from Deconvolved Distribution
# =============================================================================
# OUTPUTS: output/T12_N5_ge.csv, data/N5_ge.rds
# INPUTS:  data/N4_distribution.rds, data/N3_deconv.rds, gravity_functions.R,
#          ITPDE_total.rds
# SEED:    20260719
# N_DRAWS: 500
# METHOD:  Full GE solver, same as S8R but using deconvolved theta
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(fixest))
suppressPackageStartupMessages(library(parallel))
suppressPackageStartupMessages(library(reshape2))
setFixest_nthreads(1)

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

SEED <- 20260719
N_DRAWS <- 500
SIGMA <- 5
set.seed(SEED)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("N5: GE PROPAGATION FROM DECONVOLVED DISTRIBUTION")
say("Start: %s", format(Sys.time()))
say("N_DRAWS = %d, sigma = %d", N_DRAWS, SIGMA)
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
# LOAD THETA DISTRIBUTIONS
# =============================================================================
say("")
say("=== LOAD THETA DISTRIBUTIONS ===")

N4 <- readRDS("data/N4_distribution.rds")
N3 <- readRDS("data/N3_deconv.rds")
S5R <- readRDS("data/S5R_bhat.rds")

theta_D <- N4$theta_D          # Raw theta_D
shrunk_C <- N4$shrunk_C        # Deconvolved theta (Arm C)

say("Raw theta_D:      n=%d, mean=%.4f, sd=%.4f", length(theta_D), mean(theta_D), sd(theta_D))
say("Deconvolved (C):  n=%d, mean=%.4f, sd=%.4f", length(shrunk_C), mean(shrunk_C), sd(shrunk_C))

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
say("Cost equation fitted")

# =============================================================================
# DEFINE MEDIAN DYAD (same as S8R)
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
# BASELINE SOLVE
# =============================================================================
say("")
say("=== BASELINE SOLVE ===")
params <- list(sig = SIGMA)
df_2019_df <- as.data.frame(df_2019)

baseline <- solve_gravity_single_year(cost_eq = cost_eq_clean, df_year = df_2019_df,
                                       params = params, verbose = FALSE, return_equilibrium = TRUE)
baseline_trade <- baseline$trade
baseline_eq <- baseline$equilibrium

# Get indices and baseline trade for dyad
dyad <- DYAD_MED
idx1 <- which(df_2019$iso_x == dyad[1] & df_2019$iso_i == dyad[2])
idx2 <- which(df_2019$iso_x == dyad[2] & df_2019$iso_i == dyad[1])

base_trade_1 <- baseline_trade[baseline_trade$exporter == dyad[1] & baseline_trade$importer == dyad[2], ]$trade
base_trade_2 <- baseline_trade[baseline_trade$exporter == dyad[2] & baseline_trade$importer == dyad[1], ]$trade
base_two_way <- base_trade_1 + base_trade_2
say("Baseline two-way trade: %.4f", base_two_way)

# =============================================================================
# COUNTERFACTUAL FUNCTION
# =============================================================================
run_cf <- function(theta) {
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

# =============================================================================
# RUN FOR RAW THETA_D (comparison)
# =============================================================================
say("")
say("=== RAW THETA_D COUNTERFACTUALS ===")

set.seed(SEED)
draws_raw <- sample(theta_D, N_DRAWS, replace = TRUE)
say("Draws (raw): n=%d, mean=%.4f, sd=%.4f", N_DRAWS, mean(draws_raw), sd(draws_raw))

t_start <- Sys.time()
n_use <- min(N_CORES, 8)
say("Running %d counterfactuals on %d cores...", N_DRAWS, n_use)
results_raw <- mclapply(draws_raw, run_cf, mc.cores = n_use)
tc_raw <- unlist(results_raw)
t_end <- Sys.time()
say("Completed in %.1f seconds", as.numeric(difftime(t_end, t_start, units = "secs")))

n_valid_raw <- sum(!is.na(tc_raw))
say("Valid draws: %d/%d", n_valid_raw, N_DRAWS)

q_raw <- quantile(tc_raw, c(0.10, 0.25, 0.50, 0.75, 0.90), na.rm = TRUE)
range_raw <- (1 + q_raw[5]) / (1 + q_raw[1])

say("Raw theta_D quantiles:")
say("  q10=%.4f, q25=%.4f, q50=%.4f, q75=%.4f, q90=%.4f", q_raw[1], q_raw[2], q_raw[3], q_raw[4], q_raw[5])
say("  Range: %.4f", range_raw)

# =============================================================================
# RUN FOR DECONVOLVED THETA (ARM C)
# =============================================================================
say("")
say("=== DECONVOLVED (ARM C) COUNTERFACTUALS ===")

set.seed(SEED)
draws_C <- sample(shrunk_C, N_DRAWS, replace = TRUE)
say("Draws (deconv): n=%d, mean=%.4f, sd=%.4f", N_DRAWS, mean(draws_C), sd(draws_C))

t_start <- Sys.time()
say("Running %d counterfactuals on %d cores...", N_DRAWS, n_use)
results_C <- mclapply(draws_C, run_cf, mc.cores = n_use)
tc_C <- unlist(results_C)
t_end <- Sys.time()
say("Completed in %.1f seconds", as.numeric(difftime(t_end, t_start, units = "secs")))

n_valid_C <- sum(!is.na(tc_C))
say("Valid draws: %d/%d", n_valid_C, N_DRAWS)

q_C <- quantile(tc_C, c(0.10, 0.25, 0.50, 0.75, 0.90), na.rm = TRUE)
range_C <- (1 + q_C[5]) / (1 + q_C[1])

say("Deconvolved (C) quantiles:")
say("  q10=%.4f, q25=%.4f, q50=%.4f, q75=%.4f, q90=%.4f", q_C[1], q_C[2], q_C[3], q_C[4], q_C[5])
say("  Range: %.4f", range_C)

# =============================================================================
# NORMAL BASELINE
# =============================================================================
say("")
say("=== NORMAL BASELINE ===")

set.seed(SEED)
theta_normal_A <- rnorm(N_DRAWS, mean = mean(theta_D), sd = N3$SD_true_A)
theta_normal_C <- rnorm(N_DRAWS, mean = mean(theta_D), sd = N3$SD_true_C)

# Simple PE approximation for normal
tc_normal_A <- exp(theta_normal_A) - 1
tc_normal_C <- exp(theta_normal_C) - 1
range_normal_A <- (1 + quantile(tc_normal_A, 0.90)) / (1 + quantile(tc_normal_A, 0.10))
range_normal_C <- (1 + quantile(tc_normal_C, 0.90)) / (1 + quantile(tc_normal_C, 0.10))

say("Normal baseline (SD_true_A=%.4f): Range=%.4f", N3$SD_true_A, range_normal_A)
say("Normal baseline (SD_true_C=%.4f): Range=%.4f", N3$SD_true_C, range_normal_C)

# =============================================================================
# THREE-POINT HISTORY
# =============================================================================
say("")
say("================================================================")
say("THREE-POINT HISTORY (GE RANGE RATIOS)")
say("================================================================")

range_retired <- 1.36
range_S8R <- 27.25  # From original S8R run

say("1. Retired pack:              %.2fx", range_retired)
say("2. Raw theta_D (S8R):         %.2fx", range_S8R)
say("3. Raw theta_D (N5 rerun):    %.2fx", range_raw)
say("4. Deconvolved (Arm C):       %.2fx", range_C)

# =============================================================================
# OUTPUT
# =============================================================================
say("")

ge_results <- data.frame(
    source = c(rep("raw_theta_D", 5), rep("deconv_C", 5), rep("range_ratio", 5)),
    quantity = c("q10", "q25", "q50", "q75", "q90",
                 "q10", "q25", "q50", "q75", "q90",
                 "retired_pack", "S8R_raw", "N5_raw", "N5_deconv_C", "normal_A"),
    value = c(q_raw[1], q_raw[2], q_raw[3], q_raw[4], q_raw[5],
              q_C[1], q_C[2], q_C[3], q_C[4], q_C[5],
              range_retired, range_S8R, range_raw, range_C, range_normal_A),
    n_valid = c(rep(n_valid_raw, 5), rep(n_valid_C, 5), rep(NA, 5)),
    sigma = SIGMA
)

write.csv(ge_results, "output/T12_N5_ge.csv", row.names = FALSE)

# Save for downstream
saveRDS(list(
    dyad = DYAD_MED,
    sigma = SIGMA,
    n_draws = N_DRAWS,
    # Raw
    tc_raw = tc_raw[!is.na(tc_raw)],
    q_raw = q_raw,
    range_raw = range_raw,
    n_valid_raw = n_valid_raw,
    # Deconvolved
    tc_C = tc_C[!is.na(tc_C)],
    q_C = q_C,
    range_C = range_C,
    n_valid_C = n_valid_C,
    # History
    range_retired = range_retired,
    range_S8R = range_S8R,
    range_normal_A = range_normal_A,
    range_normal_C = range_normal_C,
    seed = SEED,
    solver_sha = solver_sha
), "data/N5_ge.rds")

# Sidecar
code_sha <- get_sha256("code/N5_ge_propagation.R")
writeLines(c(
    "FILE:      T12_N5_ge.csv",
    sprintf("SHA256:    %s", get_sha256("output/T12_N5_ge.csv")),
    sprintf("PRODUCER:  code/N5_ge_propagation.R (SHA256: %s)", code_sha),
    "INPUTS:    data/N4_distribution.rds, data/N3_deconv.rds, gravity_functions.R",
    sprintf("SEED:      %d", SEED),
    sprintf("N_DRAWS:   %d", N_DRAWS),
    sprintf("SIGMA:     %d", SIGMA),
    sprintf("DYAD:      %s-%s", DYAD_MED[1], DYAD_MED[2]),
    "",
    "THREE-POINT HISTORY:",
    sprintf("  1. Retired pack:        %.2fx", range_retired),
    sprintf("  2. S8R raw theta_D:     %.2fx", range_S8R),
    sprintf("  3. N5 raw theta_D:      %.2fx", range_raw),
    sprintf("  4. N5 deconvolved (C):  %.2fx", range_C),
    "",
    sprintf("RAW:      q10=%.4f, q90=%.4f", q_raw[1], q_raw[5]),
    sprintf("DECONV_C: q10=%.4f, q90=%.4f", q_C[1], q_C[5]),
    sprintf("CREATED:  %s", format(Sys.time()))
), "meta/T12_N5_ge.csv.sidecar")

say("")
say("Wrote output/T12_N5_ge.csv")
say("Wrote data/N5_ge.rds")
say("Done: %s", format(Sys.time()))
