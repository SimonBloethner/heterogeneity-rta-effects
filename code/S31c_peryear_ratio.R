#!/usr/bin/env Rscript
# X3: Per-Year Ratio Simulation (Close Caveat)
# Task: Use each year's own fitted parameters instead of pooling 2019

cat("========================================================================\n")
cat("X3: PER-YEAR RATIO SIMULATION\n")
cat("Start:", format(Sys.time()), "\n")
cat("========================================================================\n\n")

suppressPackageStartupMessages({
    library(data.table)
})

set.seed(20260721)

# -----------------------------------------------------------------------------
# STEP 0: Load X1 anchors and SHA-check
# -----------------------------------------------------------------------------
cat("STEP 0: Loading X1 anchor file and data...\n")

x1_file <- "output/X1_results.rds"
x1_sha <- system(paste("sha256sum", x1_file), intern = TRUE)
x1_sha <- strsplit(x1_sha, " ")[[1]][1]
cat("  X1 SHA:", x1_sha, "\n")

x1 <- readRDS(x1_file)
anchors <- as.data.table(x1$anchor_table)
cat("  Anchor years:", min(anchors$year), "-", max(anchors$year), "\n")
cat("  Columns:", paste(names(anchors), collapse = ", "), "\n")

# Load data to get n_u per year
data_file <- "/groups/m-larch/bt307958/tails/outData/filtered_trade.rds"
data_sha <- system(paste("sha256sum", data_file), intern = TRUE)
data_sha <- strsplit(data_sha, " ")[[1]][1]
cat("  Data SHA:", data_sha, "\n")

trade <- as.data.table(readRDS(data_file))
cat("  Total observations:", nrow(trade), "\n")

# Compute n_u per year (count above p90)
# Note: column is "trade", not "trade_value"
trade[, u_yr := quantile(trade, 0.90), by = year]
trade[, above_u := trade > u_yr]
n_u_table <- trade[above_u == TRUE, .N, by = year]
setnames(n_u_table, "N", "n_u")
anchors <- merge(anchors, n_u_table, by = "year")

cat("  Added n_u column; sample: n_u[2019] =", anchors[year == 2019, n_u], "\n\n")

# Compute observed ratios
anchors[, obs_ratio := E_S / empirical]

# Assertion: 2019 ratio = 1.034 ± 0.005
obs_2019 <- anchors[year == 2019, obs_ratio]
cat("ASSERTION: 2019 observed ratio =", round(obs_2019, 4), "\n")
if (abs(obs_2019 - 1.034) > 0.005) {
    cat("  WARNING: 2019 ratio outside [1.029, 1.039] range\n")
} else {
    cat("  PASS: Within ±0.005 of 1.034\n")
}
cat("\n")

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

# Sample from truncated lognormal using inverse CDF
rtrunc_lnorm <- function(n, mu, sigma, u, H) {
    p_u <- pnorm((log(u) - mu) / sigma)
    p_H <- pnorm((log(H) - mu) / sigma)
    if (p_H <= p_u) return(rep(NA, n))
    p_unif <- runif(n, p_u, p_H)
    x <- exp(qnorm(p_unif) * sigma + mu)
    return(x)
}

# MLE for truncated lognormal with profile likelihood for H
fit_trunc_lnorm_profile <- function(x, u) {
    x <- x[x > u & is.finite(x)]
    n <- length(x)
    if (n < 10) return(list(mu = NA, sigma = NA, H = NA, converged = FALSE))
    
    obs_max <- max(x)
    log_x <- log(x)
    
    # Inner optimization: given H, optimize (mu, sigma)
    fit_given_H <- function(H) {
        if (H <= obs_max) return(list(ll = -Inf, mu = NA, sigma = NA))
        
        nll <- function(par) {
            mu <- par[1]
            sigma <- exp(par[2])  # ensure positive
            if (sigma < 0.01) return(1e10)
            
            a_u <- (log(u) - mu) / sigma
            a_H <- (log(H) - mu) / sigma
            norm_const <- pnorm(a_H) - pnorm(a_u)
            if (norm_const < 1e-10) return(1e10)
            
            ll <- sum(dnorm(log_x, mu, sigma, log = TRUE)) - n * log(norm_const)
            return(-ll)
        }
        
        init <- c(mean(log_x), log(sd(log_x)))
        opt <- tryCatch(
            optim(init, nll, method = "BFGS", control = list(maxit = 500)),
            error = function(e) list(convergence = 1)
        )
        
        if (opt$convergence != 0) return(list(ll = -Inf, mu = NA, sigma = NA))
        
        return(list(ll = -opt$value, mu = opt$par[1], sigma = exp(opt$par[2])))
    }
    
    # Profile over H: search from obs_max to 5x obs_max
    H_grid <- obs_max * seq(1.0001, 5, length.out = 30)
    best_ll <- -Inf
    best_fit <- NULL
    
    for (H in H_grid) {
        fit <- fit_given_H(H)
        if (fit$ll > best_ll) {
            best_ll <- fit$ll
            best_fit <- list(mu = fit$mu, sigma = fit$sigma, H = H, ll = fit$ll)
        }
    }
    
    if (is.null(best_fit)) {
        return(list(mu = NA, sigma = NA, H = NA, converged = FALSE))
    }
    
    best_fit$converged <- TRUE
    return(best_fit)
}

# E_S for doubly-truncated lognormal
E_trunc_lnorm <- function(mu, sigma, u, H) {
    a_u <- (log(u) - mu) / sigma
    a_H <- (log(H) - mu) / sigma
    numer <- pnorm(a_H - sigma) - pnorm(a_u - sigma)
    denom <- pnorm(a_H) - pnorm(a_u)
    if (denom < 1e-10) return(NA)
    E_S <- exp(mu + sigma^2/2) * numer / denom
    return(E_S)
}

# -----------------------------------------------------------------------------
# STEP 1: Per-year simulation
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("STEP 1: PER-YEAR RATIO SIMULATION (1000 reps each)\n")
cat("========================================================================\n\n")

n_sim <- 1000
results <- data.table(
    year = integer(),
    obs_ratio = numeric(),
    null_mean = numeric(),
    null_sd = numeric(),
    percentile = numeric()
)

for (i in 1:nrow(anchors)) {
    yr <- anchors$year[i]
    mu <- anchors$mu_hat[i]
    sigma <- anchors$sigma_hat[i]
    H <- anchors$H_hat[i]
    n_u <- anchors$n_u[i]
    u <- anchors$u[i]  # lower threshold (p90)
    obs_r <- anchors$obs_ratio[i]
    
    cat(sprintf("  Year %d: n_u=%d, mu=%.3f, sigma=%.3f, H=%.0f\n", yr, n_u, mu, sigma, H))
    
    # Simulate ratio distribution
    sim_ratios <- numeric(n_sim)
    n_valid <- 0
    
    for (s in 1:n_sim) {
        # Sample from this year's fitted distribution
        x_sim <- rtrunc_lnorm(n_u, mu, sigma, u, H)
        
        if (any(is.na(x_sim))) next
        
        # Refit
        fit <- fit_trunc_lnorm_profile(x_sim, u)
        
        if (!fit$converged) next
        
        # Compute E_S and empirical mean
        E_S_sim <- E_trunc_lnorm(fit$mu, fit$sigma, u, fit$H)
        emp_mean_sim <- mean(x_sim)
        
        if (is.na(E_S_sim) || emp_mean_sim <= 0) next
        
        n_valid <- n_valid + 1
        sim_ratios[n_valid] <- E_S_sim / emp_mean_sim
    }
    
    sim_ratios <- sim_ratios[1:n_valid]
    
    if (n_valid < 100) {
        cat(sprintf("    WARNING: Only %d valid simulations\n", n_valid))
    }
    
    # Compute percentile of observed ratio
    null_mean <- mean(sim_ratios)
    null_sd <- sd(sim_ratios)
    pctile <- mean(sim_ratios <= obs_r) * 100
    
    results <- rbind(results, data.table(
        year = yr,
        obs_ratio = obs_r,
        null_mean = null_mean,
        null_sd = null_sd,
        percentile = pctile
    ))
    
    cat(sprintf("    Obs=%.4f, Null: mean=%.4f, sd=%.4f, percentile=%.1f%%\n",
                obs_r, null_mean, null_sd, pctile))
}

# -----------------------------------------------------------------------------
# STEP 2: Output tables
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("X3-1: PER-YEAR RATIO TABLE\n")
cat("========================================================================\n")
cat(sprintf("%-6s %10s %10s %10s %10s\n", "Year", "Obs_Ratio", "Null_Mean", "Null_SD", "Pctile"))
cat(paste(rep("-", 50), collapse = ""), "\n")
for (i in 1:nrow(results)) {
    cat(sprintf("%-6d %10.4f %10.4f %10.4f %10.1f\n",
                results$year[i], results$obs_ratio[i], results$null_mean[i],
                results$null_sd[i], results$percentile[i]))
}

cat("\n========================================================================\n")
cat("X3-2: UNIFORMITY TEST\n")
cat("========================================================================\n")

# KS test of percentiles against U(0,100) [equivalent to U(0,1) scaled]
pctiles <- results$percentile / 100  # Convert to [0,1]
ks_test <- ks.test(pctiles, "punif", 0, 1)

cat(sprintf("KS statistic: %.4f\n", ks_test$statistic))
cat(sprintf("KS p-value: %.4f\n", ks_test$p.value))

n_above_90 <- sum(results$percentile > 90)
cat(sprintf("Years above 90th percentile: %d / %d\n", n_above_90, nrow(results)))

# Quartile distribution
cat("\nQuartile distribution:\n")
q1 <- sum(pctiles < 0.25)
q2 <- sum(pctiles >= 0.25 & pctiles < 0.50)
q3 <- sum(pctiles >= 0.50 & pctiles < 0.75)
q4 <- sum(pctiles >= 0.75)
cat(sprintf("  [0, 25): %d (expected 8)\n", q1))
cat(sprintf("  [25, 50): %d (expected 8)\n", q2))
cat(sprintf("  [50, 75): %d (expected 8)\n", q3))
cat(sprintf("  [75, 100]: %d (expected 8)\n", q4))

# -----------------------------------------------------------------------------
# LEDGER
# -----------------------------------------------------------------------------
cat("\n========================================================================\n")
cat("LEDGER ENTRIES\n")
cat("========================================================================\n")
cat(sprintf("RATIO_PERYEAR_KS = %.4f (p=%.4f)\n", ks_test$statistic, ks_test$p.value))
cat("PERCENTILE_VECTOR =", paste(round(results$percentile, 1), collapse = ", "), "\n")

# Save results
saveRDS(list(
    results = results,
    ks_stat = ks_test$statistic,
    ks_pvalue = ks_test$p.value,
    x1_sha = x1_sha,
    data_sha = data_sha
), "output/X3_results.rds")

cat("\nX3 COMPLETE:", format(Sys.time()), "\n")
