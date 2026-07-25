# X2: Re-adjudicate Residual Tail Family Without Hill (v5 - FIXED)

cat("========================================================================\n")
cat("X2: RESIDUAL TAIL FAMILY RE-ADJUDICATION (v5)\n")
cat(sprintf("Start: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("========================================================================\n\n")

if (!grepl("Simon", getwd())) .libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))

library(fixest)
library(POT)
library(data.table)
setFixest_nthreads(1)

# Correct Hill estimator - returns ALPHA (tail index)
hill_alpha <- function(x, k = NULL) {
    x <- x[x > 0 & is.finite(x)]
    x <- sort(x, decreasing = TRUE)
    n <- length(x)
    if (n < 20) return(NA)
    if (is.null(k)) k <- floor(sqrt(n))
    if (k >= n) k <- n - 1
    log_ratios <- log(x[1:k]) - log(x[k+1])
    alpha <- k / sum(log_ratios)
    return(alpha)
}

fit_gpd_robust <- function(excesses, n_starts = 3) {
    if (length(excesses) < 10) return(list(converged = FALSE))
    best_fit <- NULL; best_ll <- -Inf
    starts <- list(c(0.1, sd(excesses)), c(0.5, mean(excesses)), c(-0.1, median(excesses)))
    for (start in starts[1:n_starts]) {
        fit <- tryCatch({
            result <- POT::fitgpd(excesses, threshold = 0, est = "mle", start = list(scale = start[2], shape = start[1]))
            list(xi = unname(result$fitted.values["shape"]), sigma = unname(result$fitted.values["scale"]),
                 ll = -result$deviance/2, converged = result$convergence == "successful",
                 se_xi = unname(result$std.err["shape"]))
        }, error = function(e) list(converged = FALSE))
        if (fit$converged && fit$ll > best_ll) { best_fit <- fit; best_ll <- fit$ll }
    }
    if (is.null(best_fit)) return(list(converged = FALSE))
    return(best_fit)
}

fit_lnorm_truncated <- function(x, L) {
    if (length(x) < 10 || any(x <= L)) return(list(converged = FALSE))
    neg_ll <- function(par) {
        if (par[2] <= 0) return(1e10)
        norm_const <- 1 - pnorm((log(L) - par[1]) / par[2])
        if (norm_const <= 0) return(1e10)
        -sum(dlnorm(x, par[1], par[2], log = TRUE)) + length(x) * log(norm_const)
    }
    result <- tryCatch({
        opt <- optim(c(mean(log(x)), sd(log(x))), neg_ll, method = "L-BFGS-B", lower = c(-Inf, 0.01), upper = c(Inf, 20), hessian = TRUE)
        se <- tryCatch(sqrt(diag(solve(opt$hessian))), error = function(e) c(NA, NA))
        list(mu = opt$par[1], sigma = opt$par[2], ll = -opt$value, converged = opt$convergence == 0, se_mu = se[1], se_sigma = se[2])
    }, error = function(e) list(converged = FALSE))
    return(result)
}

dgpd <- function(x, loc = 0, scale = 1, shape = 0, log = FALSE) {
    x <- (x - loc) / scale
    if (abs(shape) < 1e-10) logd <- -x - log(scale)
    else logd <- ifelse(1 + shape * x > 0, (-1/shape - 1) * log(1 + shape * x) - log(scale), -Inf)
    if (log) return(logd) else return(exp(logd))
}

vuong_test <- function(x, L, gpd_fit, ln_fit) {
    n <- length(x); excesses <- x - L
    ll_gpd <- dgpd(excesses, loc = 0, scale = gpd_fit$sigma, shape = gpd_fit$xi, log = TRUE)
    norm_const <- 1 - pnorm((log(L) - ln_fit$mu) / ln_fit$sigma)
    ll_ln <- dlnorm(x, ln_fit$mu, ln_fit$sigma, log = TRUE) - log(norm_const)
    diff <- ll_ln - ll_gpd; m <- mean(diff); s <- sd(diff)
    if (s == 0) return(list(stat = NA, p = NA, winner = "tie"))
    vuong_stat <- sqrt(n) * m / s; p_value <- 2 * pnorm(-abs(vuong_stat))
    winner <- if (vuong_stat > 1.96) "LN" else if (vuong_stat < -1.96) "GPD" else "neither"
    return(list(stat = vuong_stat, p = p_value, winner = winner))
}

# Load data exactly as reference script
cat("STEP 0: Loading data...\n")
df <- readRDS("/groups/m-larch/bt307958/tails/data/ITPDE_total.rds")
df <- df[df$exporter != df$importer, ]
df$pair <- paste0(df$exporter, "_", df$importer)
df$orig_year <- paste0(df$exporter, "_", df$year)
df$dest_year <- paste0(df$importer, "_", df$year)
df$logdist <- log(df$distance)
setDT(df)
cat(sprintf("  Full panel: %d observations\n", nrow(df)))

# STEP 1: Fit models
cat("\n========================================================================\n")
cat("STEP 1: OBJECT REPRODUCTION\n")
cat("========================================================================\n")

cat("\n  Fitting Spec3 (Country-Year FE)...\n")
m3 <- fepois(trade ~ rta + logdist | orig_year + dest_year, data = df, glm.iter = 500, glm.tol = 1e-12)
yhat3 <- fitted(m3)
eta3 <- df$trade / yhat3
abs3 <- abs(df$trade - yhat3)
cat(sprintf("    Spec3 RTA coef: %.4f\n", coef(m3)["rta"]))

cat("  Fitting Spec4 (Full FE)...\n")
m4 <- fepois(trade ~ rta | pair + orig_year + dest_year, data = df, glm.iter = 500, glm.tol = 1e-12)
yhat4 <- fitted(m4)
eta4 <- df$trade / yhat4
abs4 <- abs(df$trade - yhat4)
cat(sprintf("    Spec4 RTA coef: %.4f\n", coef(m4)["rta"]))

rm(m3, m4); gc()

# Hill estimates
cat("\n  Computing Hill alpha at k = sqrt(n):\n")
results_hill <- data.frame(
    spec = c("Spec3", "Spec3", "Spec4", "Spec4"),
    residual = c("eta", "absolute", "eta", "absolute"),
    n = NA, k = NA, hill_alpha = NA,
    expected = c(0.539, 1.804, 0.566, 1.778),
    tolerance = c(0.02, 0.05, 0.02, 0.05), status = NA)

eta3_pos <- eta3[eta3 > 0 & is.finite(eta3)]
abs3_pos <- abs3[abs3 > 0 & is.finite(abs3)]
eta4_pos <- eta4[eta4 > 0 & is.finite(eta4)]
abs4_pos <- abs4[abs4 > 0 & is.finite(abs4)]

results_hill[1, c("n", "k", "hill_alpha")] <- c(length(eta3_pos), floor(sqrt(length(eta3_pos))), hill_alpha(eta3_pos))
results_hill[2, c("n", "k", "hill_alpha")] <- c(length(abs3_pos), floor(sqrt(length(abs3_pos))), hill_alpha(abs3_pos))
results_hill[3, c("n", "k", "hill_alpha")] <- c(length(eta4_pos), floor(sqrt(length(eta4_pos))), hill_alpha(eta4_pos))
results_hill[4, c("n", "k", "hill_alpha")] <- c(length(abs4_pos), floor(sqrt(length(abs4_pos))), hill_alpha(abs4_pos))

for (i in 1:4) results_hill$status[i] <- ifelse(abs(results_hill$hill_alpha[i] - results_hill$expected[i]) <= results_hill$tolerance[i], "PASS", "FAIL")

cat("\n========================================================================\n")
cat("X2-1: REPRODUCTION CHECK (Hill alpha at k=sqrt(n)) - REPRODUCTION ONLY\n")
cat("========================================================================\n")
cat(sprintf("%-8s %-10s %10s %8s %10s %10s %8s %8s\n", "Spec", "Residual", "n", "k", "Hill_alpha", "Expected", "Tol", "Status"))
cat(paste0(rep("-", 80), collapse = ""), "\n")
for (i in 1:4) {
    r <- results_hill[i, ]
    cat(sprintf("%-8s %-10s %10d %8d %10.4f %10.3f %8.3f %8s\n", r$spec, r$residual, r$n, r$k, r$hill_alpha, r$expected, r$tolerance, r$status))
}

all_pass <- all(results_hill$status == "PASS")
if (all_pass) { cat("\nAll reproduction checks PASSED.\n") 
} else { cat("\n*** WARNING: Some reproduction checks FAILED ***\n") }

# STEP 2: Verdicts
cat("\n========================================================================\n")
cat("STEP 2: TAIL FAMILY VERDICTS (GPD vs LN)\n")
cat("========================================================================\n")

objects <- list(list(name = "Spec3_eta", data = eta3_pos), list(name = "Spec3_abs", data = abs3_pos),
                list(name = "Spec4_eta", data = eta4_pos), list(name = "Spec4_abs", data = abs4_pos))

verdict_table <- data.frame(object = character(), n_exceed = integer(), threshold = numeric(),
    gpd_xi = numeric(), ln_mu = numeric(), ln_sigma = numeric(),
    vuong_stat = numeric(), vuong_p = numeric(), winner = character(), stringsAsFactors = FALSE)

stability_results <- list()

for (obj in objects) {
    cat(sprintf("\n  Processing %s...\n", obj$name))
    x <- obj$data
    u90 <- quantile(x, 0.90); exceedances <- x[x > u90]; excesses <- exceedances - u90
    cat(sprintf("    n=%d, p90=%.4f, n_exceed=%d\n", length(x), u90, length(exceedances)))
    
    gpd_fit <- fit_gpd_robust(excesses, 3)
    if (gpd_fit$converged) cat(sprintf("    GPD: xi=%.4f (SE=%.4f), sigma=%.4f\n", gpd_fit$xi, gpd_fit$se_xi, gpd_fit$sigma))
    
    ln_fit <- fit_lnorm_truncated(exceedances, u90)
    if (ln_fit$converged) cat(sprintf("    LN: mu=%.4f, sigma=%.4f\n", ln_fit$mu, ln_fit$sigma))
    
    vuong <- if (gpd_fit$converged && ln_fit$converged) vuong_test(exceedances, u90, gpd_fit, ln_fit) else list(stat=NA, p=NA, winner="N/A")
    if (!is.na(vuong$stat)) cat(sprintf("    Vuong: stat=%.4f, p=%.4f, winner=%s\n", vuong$stat, vuong$p, vuong$winner))
    
    verdict_table <- rbind(verdict_table, data.frame(object = obj$name, n_exceed = length(exceedances),
        threshold = u90, gpd_xi = ifelse(gpd_fit$converged, gpd_fit$xi, NA),
        ln_mu = ifelse(ln_fit$converged, ln_fit$mu, NA), ln_sigma = ifelse(ln_fit$converged, ln_fit$sigma, NA),
        vuong_stat = vuong$stat, vuong_p = vuong$p, winner = vuong$winner, stringsAsFactors = FALSE))
    
    cat("    Threshold stability:\n")
    thresholds <- c(0.85, 0.90, 0.95, 0.975, 0.99)
    stability <- data.frame(pct = thresholds*100, threshold = NA, n = NA, xi = NA, xi_se = NA)
    for (j in seq_along(thresholds)) {
        u <- quantile(x, thresholds[j]); exc <- x[x > u] - u
        fit <- fit_gpd_robust(exc, 3)
        stability[j, 2:5] <- c(u, length(exc), ifelse(fit$converged, fit$xi, NA), ifelse(fit$converged, fit$se_xi, NA))
        cat(sprintf("      p%.1f: n=%d, xi=%.4f\n", thresholds[j]*100, length(exc), stability$xi[j]))
    }
    stability_results[[obj$name]] <- stability
}

cat("\n========================================================================\n")
cat("X2-2: VERDICT TABLE\n")
cat("========================================================================\n")
cat(sprintf("%-12s %8s %10s %8s %10s %10s %8s %8s\n", "Object", "n_exc", "GPD_xi", "LN_mu", "LN_sigma", "Vuong", "p-value", "Winner"))
cat(paste0(rep("-", 85), collapse = ""), "\n")
for (i in 1:nrow(verdict_table)) {
    r <- verdict_table[i, ]
    cat(sprintf("%-12s %8d %10.4f %8.4f %10.4f %10.4f %8.4f %8s\n",
                r$object, r$n_exceed, r$gpd_xi, r$ln_mu, r$ln_sigma, r$vuong_stat, r$vuong_p, r$winner))
}

cat("\n========================================================================\n")
cat("X2-3: THRESHOLD STABILITY GRID (GPD xi)\n")
cat("========================================================================\n")
cat(sprintf("%-12s %8s %8s %8s %8s %8s\n", "Object", "p85", "p90", "p95", "p97.5", "p99"))
cat(paste0(rep("-", 60), collapse = ""), "\n")
for (nm in names(stability_results)) {
    s <- stability_results[[nm]]
    cat(sprintf("%-12s %8.4f %8.4f %8.4f %8.4f %8.4f\n", nm, s$xi[1], s$xi[2], s$xi[3], s$xi[4], s$xi[5]))
}

cat("\n========================================================================\n")
cat("LEDGER ENTRIES\n")
cat("========================================================================\n")
for (i in 1:nrow(verdict_table)) {
    r <- verdict_table[i, ]
    cat(sprintf("RESID_TAIL_VERDICT_%s = %s (Vuong=%.3f, p=%.4f)\n", toupper(r$object), r$winner, r$vuong_stat, r$vuong_p))
}

saveRDS(list(hill = results_hill, verdict = verdict_table, stability = stability_results), "/scratch/bt307958/X2_results.rds")
cat(sprintf("\nX2 COMPLETE: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
