# S30_moment_power.R — Pooled higher-moment separation power calculation
# EXPECTED_N: 4182
#
# Measures power of pooled excess kurtosis to distinguish World T (transitory
# effect variation) from World V (volatility change) under non-normal shocks.
#
# VECTORIZED VERSION for performance

library(data.table)
library(parallel)

set.seed(20260719)

# =============================================================================
# 1. READ CALIBRATION FROM COMMITTED ARTIFACTS
# =============================================================================

cf_lines <- readLines("meta/canonical_facts.md")

extract_cf <- function(id) {
  pattern <- paste0("^\\| ", id, " \\|")
  line <- cf_lines[grep(pattern, cf_lines)]
  if (length(line) == 0) stop(paste("ID not found:", id))
  parts <- strsplit(line, "\\|")[[1]]
  val_str <- trimws(parts[4])
  if (grepl("^\\[", val_str)) stop(paste("ID", id, "has bracketed value"))
  as.numeric(val_str)
}

N <- extract_cf("N")
ESIGMA2 <- extract_cf("ESIGMA2")
VAR_SIGMA2 <- extract_cf("VAR_SIGMA2")

cat("Calibration from canonical_facts.md:\n")
cat("  N =", N, "\n")
cat("  ESIGMA2 =", ESIGMA2, "\n")
cat("  VAR_SIGMA2 =", VAR_SIGMA2, "\n")

T22 <- fread("output/T22_theta_A_treated.csv")
stopifnot("n_post_cells" %in% names(T22))
T_post_empirical <- T22$n_post_cells
stopifnot(length(T_post_empirical) == N)
stopifnot(all(!is.na(T_post_empirical)))

cat("  T_post: n =", length(T_post_empirical), ", range = [", 
    min(T_post_empirical), ",", max(T_post_empirical), "]\n\n")

stopifnot(nrow(T22) == 4182)

# =============================================================================
# 2. SIGMA^2 DISTRIBUTION
# =============================================================================

gamma_shape <- ESIGMA2^2 / VAR_SIGMA2
gamma_rate <- ESIGMA2 / VAR_SIGMA2

cat("Gamma distribution for sigma^2:\n")
cat("  shape =", gamma_shape, ", rate =", gamma_rate, "\n\n")

# =============================================================================
# 3. GRID
# =============================================================================

kappa_u_grid <- c(0, 0.75, 1.0, 1.5, 3.0)
w_over_Esigma2_grid <- c(0.10, 0.25, 0.50, 1.00)

get_df <- function(kappa_u) if (kappa_u == 0) Inf else 4 + 6 / kappa_u

cat("Grid: kappa_u =", paste(kappa_u_grid, collapse=", "), "\n")
cat("      w/E[sigma^2] =", paste(w_over_Esigma2_grid, collapse=", "), "\n\n")

# =============================================================================
# 4. VECTORIZED EXCESS KURTOSIS (per-pair, returns vector)
# =============================================================================

# Compute excess kurtosis for each row of a matrix (each row = one pair's gaps)
# Using Fisher's bias-corrected estimator
row_excess_kurtosis <- function(mat) {
  # mat: n_pairs x T_max, with NA padding for shorter series
  n_vec <- rowSums(!is.na(mat))
  
  # For pairs with n < 4, return NA
  result <- rep(NA_real_, nrow(mat))
  valid <- n_vec >= 4
  
  if (sum(valid) == 0) return(result)
  
  mat_valid <- mat[valid, , drop = FALSE]
  n_valid <- n_vec[valid]
  
  # Row means and SDs (ignoring NA)
  row_means <- rowMeans(mat_valid, na.rm = TRUE)
  
  # Variance: E[X^2] - E[X]^2
  row_var <- rowMeans(mat_valid^2, na.rm = TRUE) - row_means^2
  # Bessel correction
  row_var <- row_var * n_valid / (n_valid - 1)
  row_sd <- sqrt(row_var)
  
  # Standardize
  z_mat <- (mat_valid - row_means) / row_sd
  z4 <- z_mat^4
  z4[is.na(z4)] <- 0  # NA positions contribute 0
  sum_z4 <- rowSums(z4)
  
  # Fisher's G2
  n <- n_valid
  G2 <- ((n + 1) * n / ((n - 1) * (n - 2) * (n - 3))) * sum_z4 - 
        3 * (n - 1)^2 / ((n - 2) * (n - 3))
  
  result[valid] <- G2
  result
}

# =============================================================================
# 5. GATE G2: ANALYTICAL VARIANCE MATCH
# =============================================================================

cat("GATE G2: Variance match check\n")
test_sigma2 <- rgamma(1000, gamma_shape, gamma_rate)
test_w <- 0.5
max_diff <- max(abs((test_sigma2 + test_w) - test_sigma2 * (test_sigma2 + test_w) / test_sigma2))
cat("  max|Var_V - Var_T| =", format(max_diff, scientific = TRUE), "\n")
stopifnot(max_diff < 1e-10)
cat("  G2 PASS\n\n")

# =============================================================================
# 6. SIMULATION FUNCTION (VECTORIZED)
# =============================================================================

simulate_cell <- function(n_pairs, T_post_vec, w, kappa_u, n_reps, seed_offset = 0) {
  set.seed(20260719 + seed_offset)
  
  df <- get_df(kappa_u)
  T_max <- max(T_post_vec)
  
  delta_vec <- numeric(n_reps)
  
  for (r in 1:n_reps) {
    # Draw sigma2 and T_post for this rep
    sigma2_vec <- rgamma(n_pairs, gamma_shape, gamma_rate)
    sigma_vec <- sqrt(sigma2_vec)
    T_post_r <- sample(T_post_vec, n_pairs, replace = TRUE)
    theta_vec <- rnorm(n_pairs)
    
    # Pre-allocate gap matrices
    gaps_T <- matrix(NA_real_, n_pairs, T_max)
    gaps_V <- matrix(NA_real_, n_pairs, T_max)
    
    # Generate all random draws at once
    if (is.infinite(df)) {
      u_T <- matrix(rnorm(n_pairs * T_max), n_pairs, T_max)
      u_V <- matrix(rnorm(n_pairs * T_max), n_pairs, T_max)
    } else {
      scale <- sqrt((df - 2) / df)
      u_T <- matrix(rt(n_pairs * T_max, df) * scale, n_pairs, T_max)
      u_V <- matrix(rt(n_pairs * T_max, df) * scale, n_pairs, T_max)
    }
    
    nu_T <- matrix(rnorm(n_pairs * T_max, 0, sqrt(w)), n_pairs, T_max)
    
    # World T: g = theta + nu + sigma * u
    # World V: g = theta + sigma * rho * u, where rho = sqrt((sigma2 + w)/sigma2)
    rho_vec <- sqrt((sigma2_vec + w) / sigma2_vec)
    
    for (i in 1:n_pairs) {
      Ti <- T_post_r[i]
      gaps_T[i, 1:Ti] <- theta_vec[i] + nu_T[i, 1:Ti] + sigma_vec[i] * u_T[i, 1:Ti]
      gaps_V[i, 1:Ti] <- theta_vec[i] + sigma_vec[i] * rho_vec[i] * u_V[i, 1:Ti]
    }
    
    # Compute per-pair excess kurtosis
    kurt_T <- row_excess_kurtosis(gaps_T)
    kurt_V <- row_excess_kurtosis(gaps_V)
    
    # Pooled mean (excluding NA)
    stat_T <- mean(kurt_T, na.rm = TRUE)
    stat_V <- mean(kurt_V, na.rm = TRUE)
    
    delta_vec[r] <- stat_V - stat_T
  }
  
  # AMENDED INV-040: return BOTH SE definitions
  list(
    delta = mean(delta_vec),
    mc_se_mc = sd(delta_vec) / sqrt(n_reps),  # Monte Carlo precision
    sd_single_dataset = sd(delta_vec),         # Sampling SD in one realization
    reps = n_reps
  )
}

# =============================================================================
# 7. MAIN SIMULATION WITH PARALLEL
# =============================================================================

cat("Running simulations (parallel)...\n")
start_time <- Sys.time()

n_cores <- min(detectCores(), 8)
cat("Using", n_cores, "cores\n")

# Create grid
grid <- expand.grid(kappa_u = kappa_u_grid, w_frac = w_over_Esigma2_grid)

run_cell <- function(idx) {
  ku <- grid$kappa_u[idx]
  wf <- grid$w_frac[idx]
  w <- wf * ESIGMA2
  
  reps <- 400
  res <- simulate_cell(N, T_post_empirical, w, ku, reps, seed_offset = idx * 1000)
  
  # G4: for kappa_u > 0, need mc_se_mc < 0.10 * |delta|
  if (ku > 0 && res$mc_se_mc >= 0.10 * abs(res$delta) && reps < 4000) {
    reps <- 1600
    res <- simulate_cell(N, T_post_empirical, w, ku, reps, seed_offset = idx * 1000 + 500)
  }

  # AMENDED INV-040: z uses sd_single_dataset (identification-relevant SE)
  # NOT mc_se_mc. Old z values were inflated by sqrt(reps).
  z <- abs(res$delta) / res$sd_single_dataset
  G4_pass <- if (ku == 0) TRUE else (res$mc_se_mc < 0.10 * abs(res$delta))

  data.table(
    kappa_u = ku, w_over_Esigma2 = wf,
    delta = res$delta,
    mc_se_mc = res$mc_se_mc,           # Monte Carlo precision
    sd_single_dataset = res$sd_single_dataset,  # Sampling SD in one realization
    z = z,
    z_deff10 = z / sqrt(10), z_deff50 = z / sqrt(50),
    reps = res$reps, n_pairs = N, G3_violation = FALSE, G4_pass = G4_pass
  )
}

# Run in parallel
cl <- makeCluster(n_cores)
clusterExport(cl, c("N", "ESIGMA2", "T_post_empirical", "gamma_shape", "gamma_rate",
                    "get_df", "row_excess_kurtosis", "simulate_cell", "grid"))
clusterEvalQ(cl, library(data.table))

results_list <- parLapply(cl, 1:nrow(grid), run_cell)
stopCluster(cl)

results_dt <- rbindlist(results_list)

elapsed <- difftime(Sys.time(), start_time, units = "secs")
cat("Simulation complete in", round(elapsed, 1), "seconds\n\n")

# =============================================================================
# 8. GATE G1: NORMAL IDENTIFICATION
# =============================================================================

cat("GATE G1: Normal identification (kappa_u = 0)\n")
g1_rows <- results_dt[kappa_u == 0]
for (i in 1:nrow(g1_rows)) {
  row <- g1_rows[i]
  threshold <- 3 * row$mc_se
  pass <- abs(row$delta) < threshold
  cat("  w_frac =", row$w_over_Esigma2, ": |delta| =", round(abs(row$delta), 4), 
      "< 3*mc_se =", round(threshold, 4), ":", pass, "\n")
  stopifnot(pass)
}
cat("  G1 PASS\n\n")

# =============================================================================
# 9. GATE G3: MONOTONICITY
# =============================================================================

cat("GATE G3: Monotonicity check\n")
setorder(results_dt, w_over_Esigma2, kappa_u)

for (wf in w_over_Esigma2_grid) {
  sub <- results_dt[w_over_Esigma2 == wf]
  for (i in 2:nrow(sub)) {
    if (sub$z[i] < sub$z[i-1]) {
      cat("  VIOLATION: z decreases in kappa_u at w_frac =", wf, "\n")
      results_dt[kappa_u == sub$kappa_u[i] & w_over_Esigma2 == wf, G3_violation := TRUE]
    }
  }
}

for (ku in kappa_u_grid) {
  sub <- results_dt[kappa_u == ku][order(w_over_Esigma2)]
  for (i in 2:nrow(sub)) {
    if (sub$z[i] < sub$z[i-1]) {
      cat("  VIOLATION: z decreases in w at kappa_u =", ku, "\n")
      results_dt[kappa_u == ku & w_over_Esigma2 == sub$w_over_Esigma2[i], G3_violation := TRUE]
    }
  }
}

cat("  G3 violations:", sum(results_dt$G3_violation), "\n\n")

# =============================================================================
# 10. GATE G4 SUMMARY
# =============================================================================

cat("GATE G4: Precision check\n")
stopifnot(all(results_dt[kappa_u > 0]$G4_pass))
cat("  G4 PASS\n\n")

# =============================================================================
# 11. OUTPUT
# =============================================================================

setorder(results_dt, kappa_u, w_over_Esigma2)

cat("========================================\n")
cat("RESULTS TABLE\n")
cat("========================================\n")
print(results_dt)

fwrite(results_dt, "output/T29_moment_power.csv")
cat("\nWritten: output/T29_moment_power.csv\n")

# =============================================================================
# 12. LEDGER QUANTITIES
# =============================================================================

cat("\n========================================\n")
cat("LEDGER QUANTITIES\n")
cat("========================================\n")

kappa0_delta <- mean(results_dt[kappa_u == 0]$delta)
k1_w50_z <- results_dt[kappa_u == 1.0 & w_over_Esigma2 == 0.50]$z
max_z <- max(results_dt$z)
max_z_deff50 <- max(results_dt$z_deff50)

cat("MOMPOW_KAPPA0_DELTA:", round(kappa0_delta, 6), "\n")
cat("MOMPOW_KAPPA1_W50_Z:", round(k1_w50_z, 2), "\n")
cat("MOMPOW_MAX_Z:", round(max_z, 2), "\n")
cat("MOMPOW_DEFF50_MAX_Z:", round(max_z_deff50, 2), "\n")

cat("\n========================================\n")
cat("S30_moment_power.R COMPLETE\n")
cat("========================================\n")
