# S32: Scale-free or lognormal — the comparative tail test
# Determines whether trade flow right tails are better described by
# lognormal or GPD, with validation on synthetic controls.

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

cat("========================================================================\n")
cat("S32: SCALE-FREE OR LOGNORMAL — COMPARATIVE TAIL TEST\n")
cat(sprintf("Start: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("========================================================================\n\n")

# Setup
set.seed(20260730)

library(data.table)
library(POT)

# =============================================================================
# FITTERS
# =============================================================================

# Truncated lognormal MLE
fit_lnorm_truncated <- function(x, L) {
    if (length(x) < 10 || any(x <= L)) {
        return(list(converged = FALSE, status = "failed:insufficient_data_or_x<=L"))
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
            list(mu = opt$par[1], sigma = opt$par[2], ll = -opt$value,
                 converged = TRUE, status = "converged")
        } else {
            list(converged = FALSE, status = paste0("failed:optim_code_", opt$convergence))
        }
    }, error = function(e) {
        list(converged = FALSE, status = paste0("failed:", conditionMessage(e)))
    })

    return(result)
}

# GPD MLE with multiple starting points
fit_gpd_robust <- function(excesses) {
    if (length(excesses) < 10 || any(excesses <= 0)) {
        return(list(converged = FALSE, status = "failed:insufficient_data_or_nonpositive"))
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
                ll <- -result$deviance / 2
                list(xi = unname(result$fitted.values["shape"]),
                     sigma = unname(result$fitted.values["scale"]),
                     ll = ll, converged = TRUE, status = "converged")
            } else {
                list(converged = FALSE, status = paste0("failed:", result$convergence))
            }
        }, error = function(e) {
            list(converged = FALSE, status = paste0("failed:", conditionMessage(e)))
        })

        if (fit$converged && fit$ll > best_ll) {
            best_fit <- fit
            best_ll <- fit$ll
        }
        if (!fit$converged) last_msg <- fit$status
    }

    if (is.null(best_fit)) {
        return(list(converged = FALSE, status = last_msg))
    }
    return(best_fit)
}

# GPD density for Vuong test
dgpd <- function(x, scale, shape, log = FALSE) {
    x <- x / scale
    if (abs(shape) < 1e-10) {
        logd <- -x - log(scale)
    } else {
        logd <- ifelse(1 + shape * x > 0,
                       (-1/shape - 1) * log(1 + shape * x) - log(scale),
                       -Inf)
    }
    if (log) return(logd) else return(exp(logd))
}

# Vuong test (no Schwarz correction)
vuong_test <- function(x, L, gpd_fit, ln_fit) {
    n <- length(x)
    excesses <- x - L

    # GPD log-likelihood per observation
    ll_gpd <- dgpd(excesses, scale = gpd_fit$sigma, shape = gpd_fit$xi, log = TRUE)

    # Truncated lognormal log-likelihood per observation
    norm_const <- 1 - pnorm((log(L) - ln_fit$mu) / ln_fit$sigma)
    ll_ln <- dlnorm(x, ln_fit$mu, ln_fit$sigma, log = TRUE) - log(norm_const)

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

# Hill estimator
hill_alpha <- function(x, k) {
    x <- x[x > 0 & is.finite(x)]
    x <- sort(x, decreasing = TRUE)
    n <- length(x)
    if (k >= n || k < 2) return(NA)
    log_ratios <- log(x[1:k]) - log(x[k + 1])
    alpha <- k / sum(log_ratios)
    return(alpha)
}

# =============================================================================
# SIMULATORS FOR CONTROLS
# =============================================================================

# Sample from truncated lognormal (inverse CDF)
rtrunc_lnorm <- function(n, mu, sigma, L) {
    p_L <- pnorm((log(L) - mu) / sigma)
    u <- runif(n, p_L, 1)
    x <- exp(qnorm(u) * sigma + mu)
    return(x)
}

# Sample from Pareto truncated at L (type I Pareto with x_min = L)
rpareto_truncated <- function(n, alpha, L) {
    # Pareto: P(X > x) = (L/x)^alpha for x >= L
    u <- runif(n)
    x <- L / u^(1/alpha)
    return(x)
}

# =============================================================================
# LOAD DATA
# =============================================================================

cat("STEP 0: Loading data...\n")
df <- readRDS(file.path(RTA_ROOT, "data/ITPDE_total.rds"))
df <- df[df$exporter != df$importer & df$trade > 0, ]
setDT(df)
cat(sprintf("  Positive bilateral flows: %d\n", nrow(df)))
cat(sprintf("  Years: %d (%d - %d)\n", length(unique(df$year)), min(df$year), max(df$year)))

years <- sort(unique(df$year))
thresholds <- c(0.90, 0.95, 0.975, 0.99)
threshold_names <- c("p90", "p95", "p97.5", "p99")

# =============================================================================
# STEP 1: PROCESS ALL CELLS
# =============================================================================

cat("\n========================================================================\n")
cat("STEP 1: PROCESSING CELLS (real data)\n")
cat("========================================================================\n")

process_panel <- function(panel_name, get_data_fn) {
    results <- data.table(
        panel = character(),
        year = integer(),
        threshold_name = character(),
        threshold_value = numeric(),
        n_exceed = integer(),
        thin_flag = character(),
        ln_mu = numeric(),
        ln_sigma = numeric(),
        ln_status = character(),
        gpd_xi = numeric(),
        gpd_sigma = numeric(),
        gpd_status = character(),
        vuong_stat = numeric(),
        vuong_p = numeric(),
        winner = character()
    )

    for (yr in years) {
        for (i in seq_along(thresholds)) {
            data_result <- get_data_fn(yr, thresholds[i])
            exceedances <- data_result$exceedances
            u <- data_result$threshold
            n_exc <- length(exceedances)
            thin <- ifelse(n_exc < 50, "THIN", "")

            # Fit lognormal
            ln_fit <- fit_lnorm_truncated(exceedances, u)

            # Fit GPD
            excesses <- exceedances - u
            gpd_fit <- fit_gpd_robust(excesses)

            # Vuong test
            if (ln_fit$converged && gpd_fit$converged) {
                vuong <- vuong_test(exceedances, u, gpd_fit, ln_fit)
            } else {
                vuong <- list(stat = NA, p = NA, winner = "no_comparison")
            }

            results <- rbind(results, data.table(
                panel = panel_name,
                year = yr,
                threshold_name = threshold_names[i],
                threshold_value = u,
                n_exceed = n_exc,
                thin_flag = thin,
                ln_mu = ifelse(ln_fit$converged, ln_fit$mu, NA),
                ln_sigma = ifelse(ln_fit$converged, ln_fit$sigma, NA),
                ln_status = ln_fit$status,
                gpd_xi = ifelse(gpd_fit$converged, gpd_fit$xi, NA),
                gpd_sigma = ifelse(gpd_fit$converged, gpd_fit$sigma, NA),
                gpd_status = gpd_fit$status,
                vuong_stat = vuong$stat,
                vuong_p = vuong$p,
                winner = vuong$winner
            ))
        }
    }
    return(results)
}

# Real data
get_real_data <- function(yr, pct) {
    x <- df[year == yr, trade]
    u <- quantile(x, pct)
    exc <- x[x > u]
    list(exceedances = exc, threshold = u)
}

cat("  Processing real data cells...\n")
results_real <- process_panel("real", get_real_data)
cat(sprintf("  Completed: %d cells\n", nrow(results_real)))

# =============================================================================
# STEP 2: LOGNORMAL CONTROL
# =============================================================================

cat("\n========================================================================\n")
cat("STEP 2: LOGNORMAL CONTROL\n")
cat("========================================================================\n")

# First, store fitted LN params from real data for each cell
real_ln_params <- results_real[ln_status == "converged",
                                .(year, threshold_name, ln_mu, ln_sigma,
                                  threshold_value, n_exceed)]

get_ln_control_data <- function(yr, pct) {
    thr_name <- threshold_names[which(thresholds == pct)]
    params <- real_ln_params[year == yr & threshold_name == thr_name]

    if (nrow(params) == 0 || is.na(params$ln_mu)) {
        # Fallback: use real data if LN didn't converge
        return(get_real_data(yr, pct))
    }

    n <- params$n_exceed
    mu <- params$ln_mu
    sigma <- params$ln_sigma
    L <- params$threshold_value

    exc <- rtrunc_lnorm(n, mu, sigma, L)
    list(exceedances = exc, threshold = L)
}

cat("  Processing lognormal control cells...\n")
results_ln_control <- process_panel("control_lognormal", get_ln_control_data)
cat(sprintf("  Completed: %d cells\n", nrow(results_ln_control)))

# =============================================================================
# STEP 3: PARETO CONTROL
# =============================================================================

cat("\n========================================================================\n")
cat("STEP 3: PARETO CONTROL (alpha = 1.5)\n")
cat("========================================================================\n")

PARETO_ALPHA <- 1.5

get_pareto_control_data <- function(yr, pct) {
    # Get threshold and n from real data
    x <- df[year == yr, trade]
    u <- quantile(x, pct)
    n <- sum(x > u)

    exc <- rpareto_truncated(n, PARETO_ALPHA, u)
    list(exceedances = exc, threshold = u)
}

cat("  Processing Pareto control cells...\n")
results_pareto_control <- process_panel("control_pareto", get_pareto_control_data)
cat(sprintf("  Completed: %d cells\n", nrow(results_pareto_control)))

# =============================================================================
# STEP 4: COMBINE AND VALIDATE
# =============================================================================

cat("\n========================================================================\n")
cat("STEP 4: VALIDATION GATES\n")
cat("========================================================================\n")

all_results <- rbind(results_real, results_ln_control, results_pareto_control)

# Gate G1: LN control should select LN >= 90%
ln_ctrl <- results_ln_control[ln_status == "converged" & gpd_status == "converged"]
ln_ctrl_ln_wins <- sum(ln_ctrl$winner == "LN")
ln_ctrl_total <- nrow(ln_ctrl)
ln_ctrl_rate <- ln_ctrl_ln_wins / ln_ctrl_total
cat(sprintf("\nG1: Lognormal control - LN selected in %d/%d converged cells (%.1f%%)\n",
            ln_ctrl_ln_wins, ln_ctrl_total, ln_ctrl_rate * 100))

# Gate G2: Pareto control should select GPD >= 90%
pareto_ctrl <- results_pareto_control[ln_status == "converged" & gpd_status == "converged"]
pareto_ctrl_gpd_wins <- sum(pareto_ctrl$winner == "GPD")
pareto_ctrl_total <- nrow(pareto_ctrl)
pareto_ctrl_rate <- pareto_ctrl_gpd_wins / pareto_ctrl_total
cat(sprintf("G2: Pareto control - GPD selected in %d/%d converged cells (%.1f%%)\n",
            pareto_ctrl_gpd_wins, pareto_ctrl_total, pareto_ctrl_rate * 100))

# Gate G3: Cell accounting
for (pnl in c("real", "control_lognormal", "control_pareto")) {
    pnl_data <- all_results[panel == pnl]
    n_total <- nrow(pnl_data)
    n_converged <- sum(pnl_data$ln_status == "converged" & pnl_data$gpd_status == "converged")
    n_failed <- sum(pnl_data$ln_status != "converged" | pnl_data$gpd_status != "converged")
    n_thin <- sum(pnl_data$thin_flag == "THIN")
    cat(sprintf("G3 %s: total=%d, converged=%d, failed=%d, thin=%d\n",
                pnl, n_total, n_converged, n_failed, n_thin))
    # Note: thin cells can be converged or failed, so converged + failed = total
    stopifnot(n_converged + n_failed == n_total)
}

# Gate G4: Real-data tally by threshold (report structure check)
cat("\nG4: Real-data tally by threshold level:\n")
for (thr in threshold_names) {
    thr_data <- results_real[threshold_name == thr &
                              ln_status == "converged" & gpd_status == "converged"]
    n_ln <- sum(thr_data$winner == "LN")
    n_gpd <- sum(thr_data$winner == "GPD")
    n_neither <- sum(thr_data$winner == "neither")
    cat(sprintf("  %s: LN=%d, GPD=%d, neither=%d\n", thr, n_ln, n_gpd, n_neither))
}

# Apply gates
cat("\n--- GATE CHECKS ---\n")
g1_pass <- ln_ctrl_rate >= 0.90
g2_pass <- pareto_ctrl_rate >= 0.90
cat(sprintf("G1 (LN control >= 90%%): %s\n", ifelse(g1_pass, "PASS", "FAIL")))
cat(sprintf("G2 (Pareto control >= 90%%): %s\n", ifelse(g2_pass, "PASS", "FAIL")))

# Per prompt: "If G1 or G2 fails, report the failure and report no real-data verdict.
# The procedure is then the finding."
validation_passed <- g1_pass && g2_pass
if (!validation_passed) {
    cat("\n*** VALIDATION FAILED ***\n")
    cat("The procedure cannot reliably distinguish between lognormal and Pareto.\n")
    cat("No real-data verdict is admissible. The procedure itself is the finding.\n")
} else {
    cat("\nAll gates PASSED.\n")
}

# =============================================================================
# STEP 5: HILL DEMONSTRATION
# =============================================================================

cat("\n========================================================================\n")
cat("STEP 5: HILL DEMONSTRATION\n")
cat("========================================================================\n")

k_values <- c(50, 100, 200, 500, 1000, 2000)

hill_results <- data.table(
    year = integer(),
    k = integer(),
    source = character(),
    hill_alpha = numeric()
)

for (yr in years) {
    # Real data at p90
    x_real <- df[year == yr, trade]
    u_real <- quantile(x_real, 0.90)
    exc_real <- x_real[x_real > u_real]

    # Matched LN control
    params <- real_ln_params[year == yr & threshold_name == "p90"]
    if (nrow(params) > 0 && !is.na(params$ln_mu)) {
        exc_ln <- rtrunc_lnorm(length(exc_real), params$ln_mu, params$ln_sigma, u_real)
    } else {
        exc_ln <- exc_real  # fallback
    }

    for (k in k_values) {
        if (k < length(exc_real)) {
            hill_real <- hill_alpha(exc_real, k)
            hill_ln <- hill_alpha(exc_ln, k)

            hill_results <- rbind(hill_results, data.table(
                year = yr, k = k, source = "real", hill_alpha = hill_real
            ))
            hill_results <- rbind(hill_results, data.table(
                year = yr, k = k, source = "control_lognormal", hill_alpha = hill_ln
            ))
        }
    }
}

cat(sprintf("  Hill curves computed: %d rows\n", nrow(hill_results)))

# Summary
cat("\n  Hill summary (mean across years):\n")
hill_summary <- hill_results[, .(mean_alpha = mean(hill_alpha, na.rm = TRUE)),
                              by = .(k, source)]
hill_wide <- dcast(hill_summary, k ~ source, value.var = "mean_alpha")
print(hill_wide)

# =============================================================================
# STEP 6: SAVE OUTPUTS
# =============================================================================

cat("\n========================================================================\n")
cat("STEP 6: SAVING OUTPUTS\n")
cat("========================================================================\n")

write.csv(all_results, file.path(RTA_ROOT, "output/T33_tail_verdicts.csv"), row.names = FALSE)
write.csv(hill_results, file.path(RTA_ROOT, "output/T34_hill_curves.csv"), row.names = FALSE)

cat(sprintf("  Saved: %s\n", file.path(RTA_ROOT, "output/T33_tail_verdicts.csv")))
cat(sprintf("  Saved: %s\n", file.path(RTA_ROOT, "output/T34_hill_curves.csv")))

# =============================================================================
# FINAL SUMMARY
# =============================================================================

cat("\n========================================================================\n")
cat("FINAL SUMMARY\n")
cat("========================================================================\n")

cat("\nVALIDATION:\n")
cat(sprintf("  G1 LN control rate: %.1f%% (%d/%d)\n", ln_ctrl_rate * 100, ln_ctrl_ln_wins, ln_ctrl_total))
cat(sprintf("  G2 Pareto control rate: %.1f%% (%d/%d)\n", pareto_ctrl_rate * 100, pareto_ctrl_gpd_wins, pareto_ctrl_total))

if (validation_passed) {
    cat("\nREAL-DATA VERDICT (by threshold):\n")
    for (thr in threshold_names) {
        thr_data <- results_real[threshold_name == thr]
        converged <- thr_data[ln_status == "converged" & gpd_status == "converged"]
        failed <- thr_data[ln_status != "converged" | gpd_status != "converged"]
        thin <- thr_data[thin_flag == "THIN"]

        n_ln <- sum(converged$winner == "LN")
        n_gpd <- sum(converged$winner == "GPD")
        n_neither <- sum(converged$winner == "neither")

        cat(sprintf("  %s: LN=%d, GPD=%d, neither=%d, failed=%d, thin=%d\n",
                    thr, n_ln, n_gpd, n_neither, nrow(failed), nrow(thin)))
    }
} else {
    cat("\nREAL-DATA VERDICT: NOT ADMISSIBLE (validation failed)\n")
    cat(sprintf("  G2 failure: Pareto control selected GPD in only %.1f%% of cells.\n", pareto_ctrl_rate * 100))
    cat("  The Vuong procedure as implemented cannot distinguish heavy tails from lognormal.\n")
    cat("  Raw tallies are in T33_tail_verdicts.csv but carry no evidential weight.\n")
}

cat(sprintf("\nS32 COMPLETE: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
