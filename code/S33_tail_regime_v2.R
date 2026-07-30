# S33: The regime question, settled in one round
# Two independent instruments: likelihood comparison + model-free diagnostics

cat("========================================================================\n")
cat("S33: THE REGIME QUESTION — TWO INSTRUMENTS\n")
cat(sprintf("Start: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("========================================================================\n\n")

set.seed(20260730)

if (!grepl("Simon", getwd())) {
    .libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
}

library(data.table)
library(POT)

# =============================================================================
# FITTERS
# =============================================================================

# Truncated lognormal MLE
fit_lnorm_truncated <- function(x, L) {
    if (length(x) < 10 || any(x <= L)) {
        return(list(converged = FALSE, status = "failed:insufficient_data_or_x<=L",
                    mu = NA, sigma = NA, ll = NA, ll_mean = NA))
    }

    neg_ll <- function(par) {
        mu <- par[1]
        sigma <- par[2]
        if (sigma <= 0) return(1e10)
        norm_const <- 1 - pnorm((log(L) - mu) / sigma)
        if (norm_const <= 1e-10) return(1e10)
        -sum(dlnorm(x, mu, sigma, log = TRUE)) + length(x) * log(norm_const)
    }

    init <- c(mean(log(x)), sd(log(x)))
    if (init[2] <= 0) init[2] <- 1

    result <- tryCatch({
        opt <- optim(init, neg_ll, method = "L-BFGS-B",
                     lower = c(-Inf, 0.01), upper = c(Inf, 20))
        if (opt$convergence == 0) {
            ll <- -opt$value
            list(mu = opt$par[1], sigma = opt$par[2], ll = ll,
                 ll_mean = ll / length(x), converged = TRUE, status = "converged")
        } else {
            list(converged = FALSE, status = paste0("failed:optim_code_", opt$convergence),
                 mu = NA, sigma = NA, ll = NA, ll_mean = NA)
        }
    }, error = function(e) {
        list(converged = FALSE, status = paste0("failed:", conditionMessage(e)),
             mu = NA, sigma = NA, ll = NA, ll_mean = NA)
    })

    return(result)
}

# GPD MLE - returns ll for the EXCEEDANCES (X), not excesses
fit_gpd <- function(exceedances, threshold) {
    excesses <- exceedances - threshold

    if (length(excesses) < 10 || any(excesses <= 0)) {
        return(list(converged = FALSE, status = "failed:insufficient_data_or_nonpositive",
                    xi = NA, sigma = NA, ll = NA, ll_mean = NA))
    }

    starts <- list(
        c(shape = 0.1, scale = sd(excesses)),
        c(shape = 0.5, scale = mean(excesses)),
        c(shape = -0.1, scale = median(excesses))
    )

    best_fit <- NULL
    best_ll <- -Inf
    last_msg <- ""

    for (start in starts) {
        fit <- tryCatch({
            result <- POT::fitgpd(excesses, threshold = 0, est = "mle",
                                  start = list(scale = start["scale"], shape = start["shape"]))
            if (result$convergence == "successful") {
                # Compute log-likelihood for exceedances X (not excesses)
                xi <- unname(result$fitted.values["shape"])
                sig <- unname(result$fitted.values["scale"])
                ll <- sum(dgpd_log(excesses, sig, xi))
                list(xi = xi, sigma = sig, ll = ll, ll_mean = ll / length(excesses),
                     converged = TRUE, status = "converged")
            } else {
                list(converged = FALSE, status = paste0("failed:", result$convergence),
                     xi = NA, sigma = NA, ll = NA, ll_mean = NA)
            }
        }, error = function(e) {
            list(converged = FALSE, status = paste0("failed:", conditionMessage(e)),
                 xi = NA, sigma = NA, ll = NA, ll_mean = NA)
        })

        if (fit$converged && fit$ll > best_ll) {
            best_fit <- fit
            best_ll <- fit$ll
        }
        if (!fit$converged) last_msg <- fit$status
    }

    if (is.null(best_fit)) {
        return(list(converged = FALSE, status = last_msg,
                    xi = NA, sigma = NA, ll = NA, ll_mean = NA))
    }
    return(best_fit)
}

# GPD log-density for excesses y = x - u
dgpd_log <- function(y, scale, shape) {
    z <- y / scale
    if (abs(shape) < 1e-10) {
        logd <- -z - log(scale)
    } else {
        logd <- ifelse(1 + shape * z > 0,
                       (-1/shape - 1) * log(1 + shape * z) - log(scale),
                       -Inf)
    }
    return(logd)
}

# Vuong test (no Schwarz correction)
vuong_test <- function(exceedances, threshold, gpd_fit, ln_fit) {
    n <- length(exceedances)
    excesses <- exceedances - threshold

    # GPD log-likelihood per observation (for excesses)
    ll_gpd <- dgpd_log(excesses, gpd_fit$sigma, gpd_fit$xi)

    # Truncated LN log-likelihood per observation (for exceedances)
    norm_const <- 1 - pnorm((log(threshold) - ln_fit$mu) / ln_fit$sigma)
    ll_ln <- dlnorm(exceedances, ln_fit$mu, ln_fit$sigma, log = TRUE) - log(norm_const)

    diff <- ll_ln - ll_gpd
    m <- mean(diff)
    s <- sd(diff)

    if (s == 0 || !is.finite(s)) {
        return(list(stat = NA, p = NA, winner = "indeterminate"))
    }

    vuong_stat <- sqrt(n) * m / s
    p_value <- 2 * pnorm(-abs(vuong_stat))
    winner <- if (vuong_stat > 1.96) "LN" else if (vuong_stat < -1.96) "GPD" else "neither"

    return(list(stat = vuong_stat, p = p_value, winner = winner))
}

# =============================================================================
# SIMULATORS
# =============================================================================

# Pareto Type I: P(X > x) = (scale/x)^alpha for x >= scale
rpareto <- function(n, scale, alpha) {
    u <- runif(n)
    scale / u^(1/alpha)
}

# Truncated lognormal
rtrunc_lnorm <- function(n, mu, sigma, L) {
    p_L <- pnorm((log(L) - mu) / sigma)
    u <- runif(n, p_L, 1)
    exp(qnorm(u) * sigma + mu)
}

# =============================================================================
# STAGE 0: CALIBRATION
# =============================================================================

cat("========================================================================\n")
cat("STAGE 0: FITTER CALIBRATION (no real data)\n")
cat("========================================================================\n\n")

calibration_results <- data.table(
    test = character(),
    true_param = numeric(),
    recovered_param = numeric(),
    abs_error = numeric(),
    status = character()
)

# Pareto calibration at different alpha values
alphas <- c(1.0, 1.5, 2.0, 3.0)
pareto_scale <- 100

cat("Pareto calibration (n=5000, threshold=p50):\n")
for (alpha in alphas) {
    true_xi <- 1 / alpha

    # Generate Pareto data
    x <- rpareto(5000, pareto_scale, alpha)
    threshold <- quantile(x, 0.50)
    exceedances <- x[x > threshold]

    # Fit GPD
    fit <- fit_gpd(exceedances, threshold)

    if (fit$converged) {
        recovered_xi <- fit$xi
        abs_error <- abs(recovered_xi - true_xi)
        cat(sprintf("  alpha=%.1f: true_xi=%.3f, recovered_xi=%.3f, error=%.4f [%s]\n",
                    alpha, true_xi, recovered_xi, abs_error,
                    ifelse(abs_error <= 0.05, "OK", "FAIL")))
    } else {
        recovered_xi <- NA
        abs_error <- NA
        cat(sprintf("  alpha=%.1f: FAILED - %s\n", alpha, fit$status))
    }

    calibration_results <- rbind(calibration_results, data.table(
        test = paste0("Pareto_alpha", alpha),
        true_param = true_xi,
        recovered_param = recovered_xi,
        abs_error = abs_error,
        status = fit$status
    ))
}

# Lognormal calibration
cat("\nLognormal calibration (n=5000, threshold=p50):\n")
true_mu <- 5
true_sigma <- 1.5

x <- rlnorm(5000, true_mu, true_sigma)
threshold <- quantile(x, 0.50)
exceedances <- x[x > threshold]

fit <- fit_lnorm_truncated(exceedances, threshold)

if (fit$converged) {
    mu_error <- abs(fit$mu - true_mu)
    sigma_error <- abs(fit$sigma - true_sigma)
    cat(sprintf("  true_mu=%.3f, recovered_mu=%.3f, error=%.4f [%s]\n",
                true_mu, fit$mu, mu_error, ifelse(mu_error <= 0.05, "OK", "FAIL")))
    cat(sprintf("  true_sigma=%.3f, recovered_sigma=%.3f, error=%.4f [%s]\n",
                true_sigma, fit$sigma, sigma_error, ifelse(sigma_error <= 0.05, "OK", "FAIL")))

    calibration_results <- rbind(calibration_results, data.table(
        test = "LN_mu", true_param = true_mu, recovered_param = fit$mu,
        abs_error = mu_error, status = fit$status
    ))
    calibration_results <- rbind(calibration_results, data.table(
        test = "LN_sigma", true_param = true_sigma, recovered_param = fit$sigma,
        abs_error = sigma_error, status = fit$status
    ))
} else {
    cat(sprintf("  FAILED - %s\n", fit$status))
    calibration_results <- rbind(calibration_results, data.table(
        test = "LN_mu", true_param = true_mu, recovered_param = NA,
        abs_error = NA, status = fit$status
    ))
    calibration_results <- rbind(calibration_results, data.table(
        test = "LN_sigma", true_param = true_sigma, recovered_param = NA,
        abs_error = NA, status = fit$status
    ))
}

# Gate C1
c1_pass <- all(!is.na(calibration_results$abs_error) & calibration_results$abs_error <= 0.05)
cat(sprintf("\n*** Gate C1: %s ***\n", ifelse(c1_pass, "PASS", "FAIL")))

write.csv(calibration_results, "output/T35_fitter_calibration.csv", row.names = FALSE)

# =============================================================================
# LOAD REAL DATA
# =============================================================================

cat("\n========================================================================\n")
cat("LOADING REAL DATA\n")
cat("========================================================================\n")

df <- readRDS("/groups/m-larch/bt307958/tails/data/ITPDE_total.rds")
df <- df[df$exporter != df$importer & df$trade > 0, ]
setDT(df)
cat(sprintf("  Positive bilateral flows: %d\n", nrow(df)))
cat(sprintf("  Years: %d (%d - %d)\n", length(unique(df$year)), min(df$year), max(df$year)))

years <- sort(unique(df$year))
thresholds <- c(0.90, 0.95, 0.975, 0.99)
threshold_names <- c("p90", "p95", "p97.5", "p99")

# =============================================================================
# STAGE 1: LIKELIHOOD COMPARISON (only if C1 passed)
# =============================================================================

if (c1_pass) {
    cat("\n========================================================================\n")
    cat("STAGE 1: LIKELIHOOD COMPARISON\n")
    cat("========================================================================\n")

    process_panel_stage1 <- function(panel_name, get_data_fn) {
        results <- data.table(
            panel = character(), year = integer(), threshold_name = character(),
            threshold_value = numeric(), n_exceed = integer(),
            ln_mu = numeric(), ln_sigma = numeric(), ln_ll = numeric(), ln_ll_mean = numeric(), ln_status = character(),
            gpd_xi = numeric(), gpd_sigma = numeric(), gpd_ll = numeric(), gpd_ll_mean = numeric(), gpd_status = character(),
            vuong_stat = numeric(), vuong_p = numeric(), winner = character()
        )

        for (yr in years) {
            for (i in seq_along(thresholds)) {
                data_result <- get_data_fn(yr, thresholds[i])
                exceedances <- data_result$exceedances
                u <- data_result$threshold
                n_exc <- length(exceedances)

                ln_fit <- fit_lnorm_truncated(exceedances, u)
                gpd_fit <- fit_gpd(exceedances, u)

                if (ln_fit$converged && gpd_fit$converged) {
                    vuong <- vuong_test(exceedances, u, gpd_fit, ln_fit)
                } else {
                    vuong <- list(stat = NA, p = NA, winner = "no_comparison")
                }

                results <- rbind(results, data.table(
                    panel = panel_name, year = yr, threshold_name = threshold_names[i],
                    threshold_value = u, n_exceed = n_exc,
                    ln_mu = ln_fit$mu, ln_sigma = ln_fit$sigma,
                    ln_ll = ln_fit$ll, ln_ll_mean = ln_fit$ll_mean, ln_status = ln_fit$status,
                    gpd_xi = gpd_fit$xi, gpd_sigma = gpd_fit$sigma,
                    gpd_ll = gpd_fit$ll, gpd_ll_mean = gpd_fit$ll_mean, gpd_status = gpd_fit$status,
                    vuong_stat = vuong$stat, vuong_p = vuong$p, winner = vuong$winner
                ))
            }
        }
        return(results)
    }

    # Real data
    get_real_data <- function(yr, pct) {
        x <- df[year == yr, trade]
        u <- quantile(x, pct)
        list(exceedances = x[x > u], threshold = u)
    }

    cat("  Processing real data...\n")
    results_real <- process_panel_stage1("real", get_real_data)

    # Store LN params for controls
    real_ln_params <- results_real[ln_status == "converged",
                                    .(year, threshold_name, ln_mu, ln_sigma, threshold_value, n_exceed)]

    # LN control
    get_ln_control <- function(yr, pct) {
        thr_name <- threshold_names[which(thresholds == pct)]
        params <- real_ln_params[year == yr & threshold_name == thr_name]
        if (nrow(params) == 0 || is.na(params$ln_mu)) {
            return(get_real_data(yr, pct))
        }
        exc <- rtrunc_lnorm(params$n_exceed, params$ln_mu, params$ln_sigma, params$threshold_value)
        list(exceedances = exc, threshold = params$threshold_value)
    }

    cat("  Processing LN control...\n")
    results_ln_ctrl <- process_panel_stage1("control_lognormal", get_ln_control)

    # Pareto control
    PARETO_ALPHA <- 1.5
    get_pareto_control <- function(yr, pct) {
        x <- df[year == yr, trade]
        u <- quantile(x, pct)
        n <- sum(x > u)
        # Generate Pareto with x_min = u
        exc <- rpareto(n, u, PARETO_ALPHA)
        list(exceedances = exc, threshold = u)
    }

    cat("  Processing Pareto control...\n")
    results_pareto_ctrl <- process_panel_stage1("control_pareto", get_pareto_control)

    all_stage1 <- rbind(results_real, results_ln_ctrl, results_pareto_ctrl)

    # Gates C2, C3
    ln_ctrl_conv <- results_ln_ctrl[ln_status == "converged" & gpd_status == "converged"]
    c2_ln_wins <- sum(ln_ctrl_conv$winner == "LN")
    c2_total <- nrow(ln_ctrl_conv)
    c3_rate <- c2_ln_wins / c2_total

    pareto_ctrl_conv <- results_pareto_ctrl[ln_status == "converged" & gpd_status == "converged"]
    c2_gpd_wins <- sum(pareto_ctrl_conv$winner == "GPD")
    c2_pareto_total <- nrow(pareto_ctrl_conv)
    c2_rate <- c2_gpd_wins / c2_pareto_total

    cat(sprintf("\n*** Gate C2 (Pareto ctrl -> GPD): %.1f%% (%d/%d) [%s] ***\n",
                c2_rate * 100, c2_gpd_wins, c2_pareto_total,
                ifelse(c2_rate >= 0.90, "PASS", "FAIL")))
    cat(sprintf("*** Gate C3 (LN ctrl -> LN): %.1f%% (%d/%d) [%s] ***\n",
                c3_rate * 100, c2_ln_wins, c2_total,
                ifelse(c3_rate >= 0.90, "PASS", "FAIL")))

    stage1_valid <- (c2_rate >= 0.90) && (c3_rate >= 0.90)

    write.csv(all_stage1, "output/T36_tail_comparison.csv", row.names = FALSE)

} else {
    cat("\n*** Stage 1 SKIPPED: C1 failed ***\n")
    stage1_valid <- FALSE
    # Create empty placeholder
    all_stage1 <- data.table()
    write.csv(all_stage1, "output/T36_tail_comparison.csv", row.names = FALSE)
}

# =============================================================================
# STAGE 2: MODEL-FREE INSTRUMENTS (always runs)
# =============================================================================

# Define PARETO_ALPHA here so Stage 2 always has it (Stage 1 may be skipped)
PARETO_ALPHA <- 1.5

cat("\n========================================================================\n")
cat("STAGE 2: MODEL-FREE INSTRUMENTS\n")
cat("========================================================================\n")

# Mean excess function
compute_mean_excess <- function(x, threshold_pcts) {
    results <- data.table(
        threshold_pct = numeric(),
        threshold_value = numeric(),
        n_exceed = integer(),
        mean_excess = numeric(),
        normalized_me = numeric()
    )

    for (pct in threshold_pcts) {
        u <- quantile(x, pct)
        exc <- x[x > u]
        if (length(exc) > 0) {
            me <- mean(exc - u)
            results <- rbind(results, data.table(
                threshold_pct = pct,
                threshold_value = u,
                n_exceed = length(exc),
                mean_excess = me,
                normalized_me = me / u
            ))
        }
    }
    return(results)
}

# Max-to-sum ratio
compute_max_to_sum <- function(x, powers) {
    results <- data.table(
        power = integer(),
        max_val = numeric(),
        sum_val = numeric(),
        ratio = numeric()
    )

    for (p in powers) {
        xp <- x^p
        results <- rbind(results, data.table(
            power = p,
            max_val = max(xp),
            sum_val = sum(xp),
            ratio = max(xp) / sum(xp)
        ))
    }
    return(results)
}

# Process all panels
me_grid <- seq(0.80, 0.99, by = 0.01)
powers <- c(1L, 2L, 3L, 4L)

stage2_results <- data.table(
    panel = character(),
    year = integer(),
    instrument = character(),
    grid_point = character(),
    value = numeric(),
    extra = numeric()
)

process_stage2 <- function(panel_name, get_year_data_fn) {
    results <- data.table()

    for (yr in years) {
        x <- get_year_data_fn(yr)

        # Mean excess
        me_res <- compute_mean_excess(x, me_grid)
        for (j in 1:nrow(me_res)) {
            results <- rbind(results, data.table(
                panel = panel_name, year = yr,
                instrument = "mean_excess",
                grid_point = sprintf("p%.0f", me_res$threshold_pct[j] * 100),
                value = me_res$mean_excess[j],
                extra = me_res$normalized_me[j]
            ))
        }

        # Max-to-sum
        ms_res <- compute_max_to_sum(x, powers)
        for (j in 1:nrow(ms_res)) {
            results <- rbind(results, data.table(
                panel = panel_name, year = yr,
                instrument = "max_to_sum",
                grid_point = sprintf("p%d", ms_res$power[j]),
                value = ms_res$ratio[j],
                extra = ms_res$sum_val[j]
            ))
        }
    }
    return(results)
}

# Real data
get_real_year <- function(yr) {
    df[year == yr, trade]
}

cat("  Processing real data...\n")
stage2_real <- process_stage2("real", get_real_year)

# LN control (using p90 params for simplicity, full year samples)
cat("  Processing LN control...\n")
if (exists("real_ln_params") && nrow(real_ln_params) > 0) {
    get_ln_year <- function(yr) {
        params <- real_ln_params[year == yr & threshold_name == "p90"]
        if (nrow(params) == 0 || is.na(params$ln_mu)) {
            return(get_real_year(yr))
        }
        # Generate same size as real positive flows for that year
        n <- nrow(df[year == yr])
        rlnorm(n, params$ln_mu, params$ln_sigma)
    }
} else {
    # Fallback if Stage 1 didn't run
    get_ln_year <- function(yr) {
        x <- get_real_year(yr)
        mu <- mean(log(x))
        sigma <- sd(log(x))
        rlnorm(length(x), mu, sigma)
    }
}
stage2_ln <- process_stage2("control_lognormal", get_ln_year)

# Pareto control
cat("  Processing Pareto control...\n")
get_pareto_year <- function(yr) {
    x <- get_real_year(yr)
    scale <- min(x)
    rpareto(length(x), scale, PARETO_ALPHA)
}
stage2_pareto <- process_stage2("control_pareto", get_pareto_year)

all_stage2 <- rbind(stage2_real, stage2_ln, stage2_pareto)

# Compute mean-excess slopes for top decile (p90-p99)
cat("\n  Mean-excess slopes (p90-p99):\n")
me_slopes <- data.table(panel = character(), slope = numeric(), slope_se = numeric())

for (pnl in c("real", "control_lognormal", "control_pareto")) {
    me_data <- all_stage2[panel == pnl & instrument == "mean_excess" &
                           grid_point %in% c("p90", "p91", "p92", "p93", "p94",
                                             "p95", "p96", "p97", "p98", "p99")]
    # Average across years
    me_avg <- me_data[, .(mean_excess = mean(value), threshold_pct = as.numeric(sub("p", "", grid_point[1])) / 100),
                       by = grid_point]
    me_avg <- me_avg[order(threshold_pct)]

    # Fit linear regression
    if (nrow(me_avg) >= 3) {
        # Need to get threshold values - approximate from the data
        fit <- lm(mean_excess ~ threshold_pct, data = me_avg)
        slope <- coef(fit)[2]
        slope_se <- summary(fit)$coefficients[2, 2]
    } else {
        slope <- NA
        slope_se <- NA
    }

    me_slopes <- rbind(me_slopes, data.table(panel = pnl, slope = slope, slope_se = slope_se))
    cat(sprintf("    %s: slope = %.2f (SE = %.2f)\n", pnl, slope, slope_se))
}

# Check Gates C4, C5
cat("\n  Max-to-sum R(p) by panel (mean across years):\n")
for (pnl in c("real", "control_lognormal", "control_pareto")) {
    ms_data <- all_stage2[panel == pnl & instrument == "max_to_sum"]
    ms_avg <- ms_data[, .(mean_ratio = mean(value)), by = grid_point]
    cat(sprintf("    %s: R(1)=%.4f, R(2)=%.4f, R(3)=%.4f, R(4)=%.4f\n",
                pnl, ms_avg[grid_point == "p1", mean_ratio],
                ms_avg[grid_point == "p2", mean_ratio],
                ms_avg[grid_point == "p3", mean_ratio],
                ms_avg[grid_point == "p4", mean_ratio]))
}

# Gate C4: Pareto control - positive slope, R(2) doesn't vanish
pareto_slope <- me_slopes[panel == "control_pareto", slope]
pareto_r2 <- all_stage2[panel == "control_pareto" & instrument == "max_to_sum" & grid_point == "p2",
                         mean(value)]
c4_pass <- !is.na(pareto_slope) && pareto_slope > 0 && pareto_r2 > 0.01

# Gate C5: LN control - normalized ME declines, R(p) falls
ln_me <- all_stage2[panel == "control_lognormal" & instrument == "mean_excess"]
ln_me_avg <- ln_me[, .(norm_me = mean(extra)), by = grid_point]
ln_me_avg[, pct := as.numeric(sub("p", "", grid_point))]
ln_me_avg <- ln_me_avg[order(pct)]
# Check if declining
ln_me_declining <- all(diff(ln_me_avg$norm_me) <= 0.01)  # Allow small noise

ln_ms <- all_stage2[panel == "control_lognormal" & instrument == "max_to_sum"]
ln_ms_avg <- ln_ms[, .(mean_ratio = mean(value)), by = grid_point]
ln_r_small <- all(ln_ms_avg$mean_ratio < 0.1)  # R(p) should be small

c5_pass <- ln_me_declining && ln_r_small

cat(sprintf("\n*** Gate C4 (Pareto: slope>0, R(2) persists): %s ***\n", ifelse(c4_pass, "PASS", "FAIL")))
cat(sprintf("*** Gate C5 (LN: e/u declines, R(p) small): %s ***\n", ifelse(c5_pass, "PASS", "FAIL")))

write.csv(all_stage2, "output/T37_tail_modelfree.csv", row.names = FALSE)

# =============================================================================
# FINAL SUMMARY
# =============================================================================

cat("\n========================================================================\n")
cat("FINAL SUMMARY\n")
cat("========================================================================\n")

cat("\nSTAGE 0 (Calibration):\n")
print(calibration_results)
cat(sprintf("  C1: %s\n", ifelse(c1_pass, "PASS", "FAIL")))

if (c1_pass) {
    cat("\nSTAGE 1 (Likelihood Comparison):\n")
    cat(sprintf("  C2 (Pareto -> GPD): %.1f%% [%s]\n", c2_rate * 100, ifelse(c2_rate >= 0.90, "PASS", "FAIL")))
    cat(sprintf("  C3 (LN -> LN): %.1f%% [%s]\n", c3_rate * 100, ifelse(c3_rate >= 0.90, "PASS", "FAIL")))

    if (stage1_valid) {
        cat("\n  Real-data tally by threshold:\n")
        for (thr in threshold_names) {
            thr_data <- results_real[threshold_name == thr &
                                      ln_status == "converged" & gpd_status == "converged"]
            n_ln <- sum(thr_data$winner == "LN")
            n_gpd <- sum(thr_data$winner == "GPD")
            n_neither <- sum(thr_data$winner == "neither")
            cat(sprintf("    %s: LN=%d, GPD=%d, neither=%d\n", thr, n_ln, n_gpd, n_neither))
        }
    } else {
        cat("\n  Real-data verdict: NOT ADMISSIBLE (C2 or C3 failed)\n")
    }
}

cat("\nSTAGE 2 (Model-Free):\n")
cat(sprintf("  C4: %s\n", ifelse(c4_pass, "PASS", "FAIL")))
cat(sprintf("  C5: %s\n", ifelse(c5_pass, "PASS", "FAIL")))

cat("\n  Mean-excess slopes:\n")
for (i in 1:nrow(me_slopes)) {
    cat(sprintf("    %s: %.2f (SE %.2f)\n", me_slopes$panel[i], me_slopes$slope[i], me_slopes$slope_se[i]))
}

cat(sprintf("\nS33 COMPLETE: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
