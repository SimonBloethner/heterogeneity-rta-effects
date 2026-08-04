# ==============================================================================
# X1: Corrected Fitted-H Lognormal Anchor - Four Gravity Specifications (v2)
# ==============================================================================

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

cat("========================================================================\n")
cat("X1: CORRECTED FITTED-H LOGNORMAL ANCHOR (v2)\n")
cat(sprintf("Start: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("========================================================================\n\n")

library(fixest)
setFixest_nthreads(4)

# =============================================================================
# STEP 0: LOAD DATA
# =============================================================================

cat("STEP 0: Loading data...\n")

# Full panel for PPML estimation (includes zeros, has distance)
df_full <- readRDS(file.path(RTA_ROOT, "data/ITPDE_total.rds"))
df_full <- df_full[df_full$exporter != df_full$importer, ]
cat(sprintf("  Full panel (excl. domestic): %d observations\n", nrow(df_full)))

# Positive flows only for anchor computation
df_pos <- df_full[df_full$trade > 0, ]
cat(sprintf("  Positive flows only: %d observations\n", nrow(df_pos)))

# Verify against frozen facts
n_2019 <- sum(df_pos$year == 2019)
stopifnot("2019 count mismatch" = n_2019 == 31650)
cat(sprintf("  2019 positive flows: %d (verified)\n", n_2019))

# =============================================================================
# STEP 1: ANCHOR WEIGHTS (Doubly-Truncated Lognormal with Profile MLE for H)
# =============================================================================

cat("\nSTEP 1: Computing per-year lognormal anchors...\n")

# Doubly-truncated lognormal log-likelihood
dlnorm_trunc_ll <- function(x, mu, sigma, L, H) {
    if (sigma <= 0 || H <= L || any(x < L) || any(x > H)) return(-1e10)
    
    z_L <- (log(L) - mu) / sigma
    z_H <- (log(H) - mu) / sigma
    norm_const <- pnorm(z_H) - pnorm(z_L)
    
    if (norm_const <= 0) return(-1e10)
    
    ll <- sum(dlnorm(x, mu, sigma, log = TRUE)) - length(x) * log(norm_const)
    return(ll)
}

# Profile MLE: fix H, optimize over (mu, sigma)
fit_trunc_lnorm_fixed_H <- function(x, L, H) {
    if (H <= max(x)) return(list(mu = NA, sigma = NA, ll = -Inf))
    
    log_x <- log(x)
    mu0 <- mean(log_x)
    sigma0 <- sd(log_x)
    
    neg_ll <- function(par) {
        -dlnorm_trunc_ll(x, par[1], par[2], L, H)
    }
    
    result <- tryCatch({
        opt <- optim(c(mu0, sigma0), neg_ll, method = "L-BFGS-B",
                     lower = c(-Inf, 0.01), upper = c(Inf, 10))
        list(mu = opt$par[1], sigma = opt$par[2], ll = -opt$value)
    }, error = function(e) {
        list(mu = NA, sigma = NA, ll = -Inf)
    })
    
    return(result)
}

# Profile MLE over H
fit_trunc_lnorm_profile <- function(x, L, H_candidates = NULL) {
    if (is.null(H_candidates)) {
        H_candidates <- seq(max(x) * 1.01, max(x) * 5, length.out = 50)
    }
    
    best <- list(mu = NA, sigma = NA, H = NA, ll = -Inf)
    
    for (H in H_candidates) {
        fit <- fit_trunc_lnorm_fixed_H(x, L, H)
        if (fit$ll > best$ll) {
            best <- list(mu = fit$mu, sigma = fit$sigma, H = H, ll = fit$ll)
        }
    }
    
    # Refine around best H
    if (!is.na(best$H)) {
        H_fine <- seq(best$H * 0.9, best$H * 1.1, length.out = 20)
        for (H in H_fine) {
            fit <- fit_trunc_lnorm_fixed_H(x, L, H)
            if (fit$ll > best$ll) {
                best <- list(mu = fit$mu, sigma = fit$sigma, H = H, ll = fit$ll)
            }
        }
    }
    
    return(best)
}

# E[X | L < X < H] for lognormal - closed form
E_trunc_lnorm <- function(mu, sigma, L, H) {
    z_L <- (log(L) - mu) / sigma
    z_H <- (log(H) - mu) / sigma
    
    numer <- pnorm(z_H - sigma) - pnorm(z_L - sigma)
    denom <- pnorm(z_H) - pnorm(z_L)
    
    if (denom <= 0) return(NA)
    
    E_S <- exp(mu + sigma^2/2) * numer / denom
    return(E_S)
}

# Omega computation per eq. 8 with partition at E_S
compute_omega <- function(x, E_S, L) {
    below <- x[x < E_S & x > L]
    above <- x[x >= E_S]
    
    if (length(below) == 0 || length(above) == 0) return(NA)
    
    mean_below <- mean(below)
    mean_above <- mean(above)
    n_below <- length(below)
    n_above <- length(above)
    
    share_below <- n_below / (n_below + n_above)
    share_above <- n_above / (n_below + n_above)
    
    omega <- ((E_S - mean_below) * share_below) / ((mean_above - E_S) * share_above)
    return(omega)
}

# Per-year computation
years <- sort(unique(df_pos$year))
anchor_table <- data.frame(
    year = years,
    u = NA_real_,
    mu_hat = NA_real_,
    sigma_hat = NA_real_,
    H_hat = NA_real_,
    E_S = NA_real_,
    empirical = NA_real_,
    omega = NA_real_,
    share_above_ES = NA_real_
)

cat("  Fitting per-year lognormal anchors:\n")
for (i in seq_along(years)) {
    yr <- years[i]
    trade_yr <- df_pos$trade[df_pos$year == yr]
    
    u <- quantile(trade_yr, 0.90)
    exceedances <- trade_yr[trade_yr > u]
    
    fit <- fit_trunc_lnorm_profile(exceedances, L = u)
    
    if (!is.na(fit$mu)) {
        E_S <- E_trunc_lnorm(fit$mu, fit$sigma, u, fit$H)
        emp_mean <- mean(exceedances)
        omega <- compute_omega(exceedances, E_S, u)
        share_above <- sum(exceedances >= E_S) / length(exceedances)
        
        anchor_table[i, ] <- c(yr, u, fit$mu, fit$sigma, fit$H, E_S, emp_mean, omega, share_above)
    }
    
    if (i %% 8 == 0 || i == length(years)) {
        cat(sprintf("    Completed %d/%d years\n", i, length(years)))
    }
}

# =============================================================================
# ASSERTIONS
# =============================================================================

cat("\n  Verifying assertions:\n")

row_2019 <- anchor_table[anchor_table$year == 2019, ]
cat(sprintf("    2019 E_S = %.2f (expected 7009 ± 20)\n", row_2019$E_S))
cat(sprintf("    2019 empirical = %.2f (expected 6780.11 ± 0.01)\n", row_2019$empirical))
cat(sprintf("    2019 omega = %.4f (expected 1.058 ± 0.01)\n", row_2019$omega))

stopifnot("2019 empirical tail mean mismatch" = abs(row_2019$empirical - 6780.11) < 0.02)

if (abs(row_2019$E_S - 7009) > 20) {
    cat(sprintf("    WARNING: 2019 E_S outside expected range (got %.2f, expected 7009 ± 20)\n", row_2019$E_S))
}

cat(sprintf("    Omega range: [%.4f, %.4f] (expected [0.94, 1.10])\n", 
            min(anchor_table$omega, na.rm=TRUE), max(anchor_table$omega, na.rm=TRUE)))
cat(sprintf("    Mean omega: %.4f (expected 1.050 ± 0.01)\n", mean(anchor_table$omega, na.rm=TRUE)))

sign_check <- sign(anchor_table$omega - 1) == sign(anchor_table$E_S - anchor_table$empirical)
sign_check <- sign_check | is.na(sign_check)
cat(sprintf("    Sign consistency (omega-1 vs E_S-empirical): %d/%d\n", 
            sum(sign_check, na.rm=TRUE), sum(!is.na(anchor_table$omega))))

# stopifnot for sign consistency
stopifnot("Sign inconsistency: sign(omega-1) != sign(E_S-empirical)" = all(sign_check, na.rm=TRUE))

# =============================================================================
# OUTPUT X1-1: Per-Year Anchor Table
# =============================================================================

cat("\n========================================================================\n")
cat("X1-1: PER-YEAR ANCHOR TABLE\n")
cat("========================================================================\n")
cat(sprintf("%-6s %10s %10s %10s %12s %12s %12s %8s %10s\n",
            "Year", "u", "mu_hat", "sigma_hat", "H_hat", "E_S", "empirical", "omega", "share>ES"))
cat(paste0(rep("-", 100), collapse = ""), "\n")

for (i in 1:nrow(anchor_table)) {
    r <- anchor_table[i, ]
    cat(sprintf("%-6d %10.2f %10.4f %10.4f %12.2f %12.2f %12.2f %8.4f %10.4f\n",
                r$year, r$u, r$mu_hat, r$sigma_hat, r$H_hat, r$E_S, r$empirical, r$omega, r$share_above_ES))
}

# =============================================================================
# STEP 2: WEIGHTED ESTIMATION (using full panel)
# =============================================================================

cat("\n========================================================================\n")
cat("STEP 2: WEIGHTED PPML ESTIMATION\n")
cat("========================================================================\n")

# Merge anchor weights to full panel
df_full <- merge(df_full, anchor_table[, c("year", "E_S", "omega")], by = "year", all.x = TRUE)

# Create weights: omega for trade > E_S, 1 otherwise
# For zero trade flows: weight = 1
df_full$weight <- ifelse(df_full$trade > df_full$E_S, df_full$omega, 1)
df_full$weight[is.na(df_full$weight)] <- 1

# Create pair ID for clustering
df_full$pair <- paste0(df_full$exporter, "_", df_full$importer)

cat(sprintf("\n  Full panel observations: %d\n", nrow(df_full)))
cat(sprintf("  Observations with weight > 1: %d\n", sum(df_full$weight > 1)))

cat("\n  Running four specifications...\n")

# Helper function
get_rta_coef <- function(model) {
    s <- summary(model, vcov = ~pair)
    coef <- s$coeftable["rta", "Estimate"]
    se <- s$coeftable["rta", "Std. Error"]
    c(coef = coef, se = se)
}

results <- data.frame(
    spec = c("(B) Bilateral", "(C) Country", "(CY) Country-Year", "(FULL) Full"),
    published = c(1.402, 0.922, 0.411, 0.095),
    unweighted = NA_real_,
    weighted = NA_real_,
    gap = NA_real_,
    se_unwt = NA_real_,
    se_wt = NA_real_
)

# (B) Bilateral FE
cat("    (B) Bilateral FE...\n")
m_unwt_B <- feglm(trade ~ rta | exporter^importer, data = df_full, family = poisson())
m_wt_B <- feglm(trade ~ rta | exporter^importer, data = df_full, family = poisson(), weights = ~weight)

r <- get_rta_coef(m_unwt_B)
results$unweighted[1] <- r["coef"]
results$se_unwt[1] <- r["se"]

r <- get_rta_coef(m_wt_B)
results$weighted[1] <- r["coef"]
results$se_wt[1] <- r["se"]

rm(m_unwt_B, m_wt_B); gc()

# (C) Country FE + gravity
cat("    (C) Country FE + gravity...\n")
m_unwt_C <- feglm(trade ~ log(distance) + rta | exporter + importer, data = df_full, family = poisson())
m_wt_C <- feglm(trade ~ log(distance) + rta | exporter + importer, data = df_full, family = poisson(), weights = ~weight)

r <- get_rta_coef(m_unwt_C)
results$unweighted[2] <- r["coef"]
results$se_unwt[2] <- r["se"]

r <- get_rta_coef(m_wt_C)
results$weighted[2] <- r["coef"]
results$se_wt[2] <- r["se"]

rm(m_unwt_C, m_wt_C); gc()

# (CY) Country-Year FE
cat("    (CY) Country-Year FE...\n")
m_unwt_CY <- feglm(trade ~ log(distance) + rta | exporter^year + importer^year, data = df_full, family = poisson())
m_wt_CY <- feglm(trade ~ log(distance) + rta | exporter^year + importer^year, data = df_full, family = poisson(), weights = ~weight)

r <- get_rta_coef(m_unwt_CY)
results$unweighted[3] <- r["coef"]
results$se_unwt[3] <- r["se"]

r <- get_rta_coef(m_wt_CY)
results$weighted[3] <- r["coef"]
results$se_wt[3] <- r["se"]

rm(m_unwt_CY, m_wt_CY); gc()

# (FULL) Full FE
cat("    (FULL) Full FE...\n")
m_unwt_FULL <- feglm(trade ~ rta | exporter^importer + exporter^year + importer^year, data = df_full, family = poisson())
m_wt_FULL <- feglm(trade ~ rta | exporter^importer + exporter^year + importer^year, data = df_full, family = poisson(), weights = ~weight)

r <- get_rta_coef(m_unwt_FULL)
results$unweighted[4] <- r["coef"]
results$se_unwt[4] <- r["se"]

r <- get_rta_coef(m_wt_FULL)
results$weighted[4] <- r["coef"]
results$se_wt[4] <- r["se"]

rm(m_unwt_FULL, m_wt_FULL); gc()

# Compute gaps
results$gap <- results$weighted - results$unweighted

# =============================================================================
# VERIFY AGAINST PUBLISHED TABLE 2
# =============================================================================

cat("\n  Verifying against published Table 2 (tolerance 0.005):\n")
all_pass <- TRUE
for (i in 1:4) {
    diff <- abs(results$unweighted[i] - results$published[i])
    status <- ifelse(diff <= 0.005, "PASS", "FAIL")
    cat(sprintf("    %s: got %.4f, expected %.3f, diff=%.4f [%s]\n",
                results$spec[i], results$unweighted[i], results$published[i], diff, status))
    
    if (status == "FAIL") all_pass <- FALSE
}

if (!all_pass) {
    cat("\n*** WARNING: Some coefficients do not match published Table 2 ***\n")
    cat("Continuing with results as computed...\n")
}

# =============================================================================
# OUTPUT X1-2: Results Table
# =============================================================================

cat("\n========================================================================\n")
cat("X1-2: PUBLISHED / UNWEIGHTED / WEIGHTED / GAP\n")
cat("========================================================================\n")
cat(sprintf("%-20s %12s %15s %15s %12s\n", "Specification", "Published", "Unweighted", "Weighted", "Gap"))
cat(paste0(rep("-", 80), collapse = ""), "\n")

for (i in 1:4) {
    cat(sprintf("%-20s %12.3f %11.4f (%.4f) %11.4f (%.4f) %+12.4f\n",
                results$spec[i], results$published[i],
                results$unweighted[i], results$se_unwt[i],
                results$weighted[i], results$se_wt[i],
                results$gap[i]))
}

# =============================================================================
# STEP 3: CONDITIONAL DECOMPOSITION (if |gap| > 0.05)
# =============================================================================

large_gaps <- which(abs(results$gap) > 0.05)

if (length(large_gaps) > 0) {
    cat("\n========================================================================\n")
    cat("X1-3: CONDITIONAL DECOMPOSITION (|gap| > 0.05)\n")
    cat("========================================================================\n")
    
    for (idx in large_gaps) {
        cat(sprintf("\n--- %s (gap = %+.4f) ---\n", results$spec[idx], results$gap[idx]))
        cat("  [Decomposition machinery not implemented in this run]\n")
    }
} else {
    cat("\nX1-3: No decomposition triggered (all |gap| <= 0.05)\n")
}

# =============================================================================
# OUTPUT X1-4: OMEGA SUMMARY COMPARISON
# =============================================================================

cat("\n========================================================================\n")
cat("X1-4: OMEGA SUMMARY - PUBLISHED vs CORRECTED\n")
cat("========================================================================\n")

cat(sprintf("%-25s %15s %15s\n", "", "Published (GPD)", "Corrected (LN)"))
cat(paste0(rep("-", 60), collapse = ""), "\n")
cat(sprintf("%-25s %10.1f - %5.1f %10.4f - %.4f\n", "Range",
            22.6, 295.2,
            min(anchor_table$omega, na.rm=TRUE), max(anchor_table$omega, na.rm=TRUE)))
cat(sprintf("%-25s %15s %15.4f\n", "Mean", "N/A", mean(anchor_table$omega, na.rm=TRUE)))
cat(sprintf("%-25s %15s %15.4f\n", "SD", "N/A", sd(anchor_table$omega, na.rm=TRUE)))

# =============================================================================
# SAVE RESULTS
# =============================================================================

saveRDS(list(
    anchor_table = anchor_table,
    results = results
), file.path(RTA_ROOT, "output/X1_results.rds"))

write.csv(anchor_table, file.path(RTA_ROOT, "output/T30_tail_anchor.csv"), row.names = FALSE)
sha_anchor <- system(sprintf("sha256sum %s | cut -d\" \" -f1", file.path(RTA_ROOT, "output/T30_tail_anchor.csv")), intern = TRUE)

cat("\n========================================================================\n")
cat("LEDGER ENTRIES\n")
cat("========================================================================\n")
cat(sprintf("GAP_CORRECTED_B    = %+.4f\n", results$gap[1]))
cat(sprintf("GAP_CORRECTED_C    = %+.4f\n", results$gap[2]))
cat(sprintf("GAP_CORRECTED_CY   = %+.4f\n", results$gap[3]))
cat(sprintf("GAP_CORRECTED_FULL = %+.4f\n", results$gap[4]))
cat(sprintf("OMEGA_TABLE_SHA    = %s\n", sha_anchor))

cat("\n========================================================================\n")
cat(sprintf("X1 COMPLETE: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("========================================================================\n")
