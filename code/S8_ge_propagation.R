# S8_ge_propagation.R: GE Trade Cost Change Quantiles (PARALLEL)
# OUTPUTS: data/S8_ge.rds
# INPUTS: data/S5_bhat.rds (theta_D values), gravity_functions.R, ITPDE_total.rds
# SEED: 20260719
# GATES: A (plumbing), B (market clearing), C (convergence)

cat("========================================================================\n")
cat("S8: GE PROPAGATION QUANTILES (PARALLEL)\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat("========================================================================\n\n")

library(data.table)
library(fixest)
library(parallel)
setFixest_nthreads(1)

SEED <- 20260719
set.seed(SEED)

BASE <- "/scratch/bt307958/REBUILD_V2"
N_CORES <- detectCores()
cat(sprintf("Available cores: %d\n", N_CORES))

# ============================================================================
# LOAD SOLVER
# ============================================================================
cat("\n=== LOAD SOLVER ===\n")
solver_path <- "/groups/m-larch/bt307958/tails/programs/gravity_functions.R"
source(solver_path)
solver_sha <- strsplit(system(sprintf("sha256sum %s", solver_path), intern = TRUE), " ")[[1]][1]
cat(sprintf("Solver SHA: %s\n", solver_sha))

# ============================================================================
# LOAD THETA_D
# ============================================================================
cat("\n=== LOAD THETA_D ===\n")
S5 <- readRDS(file.path(BASE, "data/S5_bhat.rds"))
theta_dt <- S5$theta_d
theta_dt[, baseline := (adoption_year >= 1991 & adoption_year <= 2016 & n_pre >= 3 & n_post >= 3)]
theta_D <- theta_dt[baseline == TRUE]$theta_D
cat(sprintf("BASELINE theta_D: n=%d, mean=%.4f, sd=%.4f\n", length(theta_D), mean(theta_D), sd(theta_D)))

# ============================================================================
# LOAD 2019 DATA & CONSTRUCT COST_EQ
# ============================================================================
cat("\n=== PREPARE DATA ===\n")
df_full <- readRDS("/groups/m-larch/bt307958/tails/data/ITPDE_total.rds")
setDT(df_full)
setnames(df_full, c("exporter", "importer"), c("iso_x", "iso_i"))
df_2019 <- df_full[year == 2019]
df_2019[, log_dist := log(distance)]
df_2019[, intl := as.integer(iso_x != iso_i)]

df_pos <- df_2019[trade > 0]
fit <- fepois(trade ~ log_dist + intl + rta | iso_x + iso_i, data = df_pos)
coefs <- coef(fit)
df_2019[, cost_eq := exp(coefs["log_dist"] * log_dist + coefs["intl"] * intl + coefs["rta"] * rta)]
cost_eq_clean <- df_2019$cost_eq
cost_eq_clean[is.na(cost_eq_clean)] <- 1

# ============================================================================
# DEFINE DYAD
# ============================================================================
non_rta_dyads <- df_2019[intl == 1 & rta == 0 & trade > 0]
non_rta_dyads[, pair := paste(pmin(iso_x, iso_i), pmax(iso_x, iso_i), sep = "_")]
pair_trade <- non_rta_dyads[, .(two_way = sum(trade)), by = pair]
pair_counts <- non_rta_dyads[, .N, by = pair]
pairs_both_dir <- pair_counts[N == 2]$pair
pair_trade_valid <- pair_trade[pair %in% pairs_both_dir][order(two_way)]
median_idx <- ceiling(nrow(pair_trade_valid) / 2)
DYAD_MED <- strsplit(pair_trade_valid$pair[median_idx], "_")[[1]]
cat(sprintf("Median dyad: %s - %s\n", DYAD_MED[1], DYAD_MED[2]))

# ============================================================================
# BASELINE SOLVE & GATES
# ============================================================================
cat("\n=== BASELINE SOLVE ===\n")
params <- list(sig = 5)
baseline_result <- solve_gravity_single_year(cost_eq = cost_eq_clean, df_year = df_2019, 
                                              params = params, verbose = TRUE, return_equilibrium = TRUE)
baseline_trade <- baseline_result$trade
baseline_eq <- baseline_result$equilibrium
dict <- baseline_eq$dict

# Gate A
cf_zero <- solve_gravity_single_year(cost_eq = cost_eq_clean, df_year = df_2019, 
                                      params = params, verbose = FALSE, return_equilibrium = TRUE)
merged <- merge(baseline_trade, cf_zero$trade, by = c("year", "exporter", "importer"), suffixes = c(".base", ".cf"))
max_diff <- max(abs(merged$trade.base - merged$trade.cf))
cat(sprintf("GATE A (plumbing): %.2e - %s\n", max_diff, ifelse(max_diff < 1e-8, "PASS", "FAIL")))

# Gate B
trade_matrix <- reshape2::dcast(baseline_trade, exporter ~ importer, value.var = "trade", fill = 0)
exporters <- trade_matrix$exporter
trade_mat <- as.matrix(trade_matrix[, -1])
Y_ordered <- baseline_eq$Y[match(exporters, dict$iso)]
E_ordered <- baseline_eq$E[match(colnames(trade_mat), dict$iso)]
max_row_diff <- max(abs(rowSums(trade_mat) - Y_ordered) / Y_ordered, na.rm = TRUE)
max_col_diff <- max(abs(colSums(trade_mat) - E_ordered) / E_ordered, na.rm = TRUE)
cat(sprintf("GATE B (market clearing): row=%.4f%%, col=%.4f%% - %s\n", 
            max_row_diff*100, max_col_diff*100, ifelse(max_row_diff < 0.001 && max_col_diff < 0.001, "PASS", "FAIL")))

# ============================================================================
# PARALLEL COUNTERFACTUAL SIMULATION
# ============================================================================
cat("\n=== PARALLEL COUNTERFACTUAL SIMULATION ===\n")

n_draws <- 500
set.seed(SEED)
draws <- sample(theta_D, n_draws, replace = TRUE)
cat(sprintf("Draws: n=%d, mean=%.4f, sd=%.4f\n", n_draws, mean(draws), sd(draws)))

dyad <- DYAD_MED
idx1 <- which(df_2019$iso_x == dyad[1] & df_2019$iso_i == dyad[2])
idx2 <- which(df_2019$iso_x == dyad[2] & df_2019$iso_i == dyad[1])

base_trade_1 <- baseline_trade[baseline_trade$exporter == dyad[1] & baseline_trade$importer == dyad[2], ]$trade
base_trade_2 <- baseline_trade[baseline_trade$exporter == dyad[2] & baseline_trade$importer == dyad[1], ]$trade
base_two_way <- base_trade_1 + base_trade_2
cat(sprintf("Baseline two-way trade: %.4f\n", base_two_way))

# Worker function
run_cf <- function(d) {
  theta <- draws[d]
  shock <- exp(theta)
  shocked_cost <- cost_eq_clean
  shocked_cost[idx1] <- shocked_cost[idx1] * shock
  shocked_cost[idx2] <- shocked_cost[idx2] * shock
  
  cf <- tryCatch({
    solve_gravity_single_year(cost_eq = shocked_cost, df_year = df_2019, 
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
cat(sprintf("Running %d counterfactuals on %d cores...\n", n_draws, min(N_CORES, 8)))
results <- mclapply(1:n_draws, run_cf, mc.cores = min(N_CORES, 8))
trade_changes <- unlist(results)
t_end <- Sys.time()
elapsed <- as.numeric(difftime(t_end, t_start, units = "secs"))
cat(sprintf("Completed in %.1f seconds (%.3f sec/draw)\n", elapsed, elapsed/n_draws))

# Gate C
n_failed <- sum(is.na(trade_changes))
fail_rate <- n_failed / n_draws
cat(sprintf("GATE C (convergence): %d/%d failed (%.1f%%) - %s\n", 
            n_failed, n_draws, fail_rate*100, ifelse(fail_rate < 0.02, "PASS", "FAIL")))

# ============================================================================
# RESULTS
# ============================================================================
cat("\n=== RESULTS ===\n")
tc <- trade_changes[!is.na(trade_changes)]
q10 <- quantile(tc, 0.10); q50 <- quantile(tc, 0.50); q90 <- quantile(tc, 0.90)
range_1090 <- (1 + q90) / (1 + q10)

cat(sprintf("Trade change quantiles (sigma=5):\n"))
cat(sprintf("  q10: %+.4f, q50: %+.4f, q90: %+.4f\n", q10, q50, q90))
cat(sprintf("  Range (1+q90)/(1+q10): %.4f\n", range_1090))

# Normal comparison
theta_normal <- rnorm(n_draws, mean = mean(theta_D), sd = sd(theta_D))
tc_normal <- exp(theta_normal) - 1
range_normal <- (1 + quantile(tc_normal, 0.90)) / (1 + quantile(tc_normal, 0.10))
cat(sprintf("  Normal range: %.4f\n", range_normal))

cat("\nComparison to canonical:\n")
cat(sprintf("  REBUILD q50: %+.4f vs Canonical: +0.2208\n", q50))
cat(sprintf("  REBUILD range: %.4f vs Canonical: 1.3589\n", range_1090))

# ============================================================================
# SAVE
# ============================================================================
output <- list(
  dyad = DYAD_MED, sigma = 5, n_draws = n_draws, n_valid = sum(!is.na(trade_changes)),
  trade_changes = tc, quantiles = c(q10=q10, q50=q50, q90=q90),
  range_1090 = range_1090, range_normal = range_normal,
  theta_D_summary = list(n = length(theta_D), mean = mean(theta_D), sd = sd(theta_D)),
  gates = list(A = max_diff, B = c(row=max_row_diff, col=max_col_diff), C = fail_rate),
  seed = SEED, solver_sha = solver_sha
)
output_path <- file.path(BASE, "data/S8_ge.rds")
saveRDS(output, output_path)
sha <- strsplit(system(sprintf("sha256sum %s", output_path), intern = TRUE), " ")[[1]][1]
cat(sprintf("\nOutput: %s\nSHA256: %s\n", output_path, sha))

sidecar <- sprintf("file: S8_ge.rds\nsha256: %s\ncreated: %s\nscript: S8_ge_propagation.R\nseed: %d\nsummary: q50=%.4f, range=%.4f\n", 
                   sha, format(Sys.time()), SEED, q50, range_1090)
writeLines(sidecar, file.path(BASE, "meta/S8_ge.rds.sidecar"))

cat("\n========================================================================\n")
cat(sprintf("S8 COMPLETE: %s\n", format(Sys.time())))
cat("========================================================================\n")
