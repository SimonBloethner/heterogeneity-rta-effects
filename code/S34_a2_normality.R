#!/usr/bin/env Rscript
# =============================================================================
# S34: Does (A2) hold? Normality of the log gaps
# =============================================================================
# Tests assumption (A2): log(eta_ijt) = -sigma^2_ij/2 + u_ijt, u ~ N(0, sigma^2_ij)
# Two implications: (1) Normality of within-pair log gaps, (2) Jensen identity
# =============================================================================

cat("========================================================================\n")
cat("S34: DOES (A2) HOLD? NORMALITY OF THE LOG GAPS\n")
cat(sprintf("Start: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("========================================================================\n\n")

set.seed(20260731)
START_TIME <- Sys.time()

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

library(data.table)

# =============================================================================
# LOAD DATA
# =============================================================================

cat("Loading data...\n")

# Use the authoritative S1R_ppml.rds from the enforce chain
INPUT_PATH <- file.path(RTA_ROOT, "data/S1R_ppml.rds")
INPUT_SHA <- "45c937cd78805d7b13b4c43f4bc4888e93a2ff15e787ad4fb41d77b51f837d89"

get_sha256 <- function(p) {
    strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
}

actual_sha <- get_sha256(INPUT_PATH)
if (actual_sha != INPUT_SHA) {
    stop(sprintf("Input SHA mismatch!\nExpected: %s\nActual: %s", INPUT_SHA, actual_sha))
}
cat(sprintf("  Input SHA verified: %s\n", INPUT_SHA))

d <- readRDS(INPUT_PATH)
setDT(d)
cat(sprintf("  Total rows: %d\n", nrow(d)))

# =============================================================================
# FILTER TO UNTREATED CELLS
# =============================================================================

cat("\nFiltering to untreated cells...\n")

# Untreated cells: est_sample == TRUE, in_model == TRUE, trade > 0
untreated <- d[est_sample == TRUE & in_model == TRUE & trade > 0]
cat(sprintf("  Untreated cells: %d\n", nrow(untreated)))

# Compute log gaps: log(eta) = log(trade / y_hat_0)
untreated[, log_eta := log(trade) - log(y_hat_0)]

# Count cells per pair
pair_counts <- untreated[, .N, by = pair]
setnames(pair_counts, "N", "n_cells")

# Minimum 8 cells per pair
MIN_CELLS <- 8
pairs_8plus <- pair_counts[n_cells >= MIN_CELLS, pair]
pairs_excluded <- pair_counts[n_cells < MIN_CELLS, pair]

cat(sprintf("  Pairs with untreated cells: %d\n", nrow(pair_counts)))
cat(sprintf("  Pairs with >= %d cells: %d\n", MIN_CELLS, length(pairs_8plus)))
cat(sprintf("  Pairs excluded (< %d cells): %d\n", MIN_CELLS, length(pairs_excluded)))

# Filter to 8+ cell pairs
unt <- untreated[pair %in% pairs_8plus]
cat(sprintf("  Cells in retained pairs: %d\n", nrow(unt)))

# =============================================================================
# CREATE MATCHED NORMAL CONTROL
# =============================================================================

cat("\nCreating matched normal control (pair-by-pair)...\n")

# For each pair, generate same number of N(0,1) draws
set.seed(20260731)

control_list <- list()
for (p in pairs_8plus) {
    n_i <- sum(unt$pair == p)
    control_list[[p]] <- data.table(
        pair = p,
        year = unt[pair == p, year],
        log_eta_ctrl = rnorm(n_i, 0, 1)
    )
}
control <- rbindlist(control_list)

cat(sprintf("  Control cells: %d\n", nrow(control)))

# Verify pair counts match (G3)
real_pair_counts <- unt[, .N, by = pair]
ctrl_pair_counts <- control[, .N, by = pair]
setkey(real_pair_counts, pair)
setkey(ctrl_pair_counts, pair)
stopifnot(all(real_pair_counts$N == ctrl_pair_counts$N))
cat("  G3 pair-by-pair matching verified: PASS\n")

# =============================================================================
# STANDARDIZE WITHIN PAIRS
# =============================================================================

cat("\nStandardizing within pairs...\n")

# Real data
unt[, `:=`(
    pair_mean = mean(log_eta),
    pair_sd = sd(log_eta)
), by = pair]
unt[, z := (log_eta - pair_mean) / pair_sd]

# Control
control[, `:=`(
    pair_mean = mean(log_eta_ctrl),
    pair_sd = sd(log_eta_ctrl)
), by = pair]
control[, z := (log_eta_ctrl - pair_mean) / pair_sd]

# Remove any pairs with zero SD (all identical values)
bad_pairs_real <- unt[is.na(z) | !is.finite(z), unique(pair)]
bad_pairs_ctrl <- control[is.na(z) | !is.finite(z), unique(pair)]
if (length(bad_pairs_real) > 0 || length(bad_pairs_ctrl) > 0) {
    cat(sprintf("  Warning: %d real pairs and %d control pairs have zero SD\n",
                length(bad_pairs_real), length(bad_pairs_ctrl)))
    unt <- unt[!pair %in% bad_pairs_real]
    control <- control[!pair %in% bad_pairs_ctrl]
}

# =============================================================================
# STATISTIC 1: PER-PAIR REJECTION RATE (SHAPIRO-WILK)
# =============================================================================

cat("\n========================================================================\n")
cat("STATISTIC 1: PER-PAIR NORMALITY REJECTION RATE (SHAPIRO-WILK)\n")
cat("========================================================================\n")

test_normality <- function(x) {
    if (length(x) < 3 || length(x) > 5000) return(NA)
    tryCatch(shapiro.test(x)$p.value, error = function(e) NA)
}

# Real data
real_pvals <- unt[, .(p_value = test_normality(log_eta)), by = pair]
real_pvals[, reject := p_value < 0.05]

# Control
ctrl_pvals <- control[, .(p_value = test_normality(log_eta_ctrl)), by = pair]
ctrl_pvals[, reject := p_value < 0.05]

# Overall rejection rates
real_reject_rate <- mean(real_pvals$reject, na.rm = TRUE)
ctrl_reject_rate <- mean(ctrl_pvals$reject, na.rm = TRUE)

n_pairs_real <- sum(!is.na(real_pvals$reject))
n_pairs_ctrl <- sum(!is.na(ctrl_pvals$reject))

cat(sprintf("  Real rejection rate: %.4f (%d / %d pairs)\n",
            real_reject_rate, sum(real_pvals$reject, na.rm = TRUE), n_pairs_real))
cat(sprintf("  Control rejection rate: %.4f (%d / %d pairs)\n",
            ctrl_reject_rate, sum(ctrl_pvals$reject, na.rm = TRUE), n_pairs_ctrl))

# Difference with binomial SE
diff_rate <- real_reject_rate - ctrl_reject_rate
se_diff <- sqrt(real_reject_rate * (1 - real_reject_rate) / n_pairs_real +
                ctrl_reject_rate * (1 - ctrl_reject_rate) / n_pairs_ctrl)
cat(sprintf("  Difference: %.4f (SE = %.4f)\n", diff_rate, se_diff))

# Gate G1: control rejection rate within 0.02 of 0.05
g1_pass <- abs(ctrl_reject_rate - 0.05) <= 0.02
cat(sprintf("\n*** Gate G1 (control rate within 0.02 of 0.05): %s ***\n",
            ifelse(g1_pass, "PASS", "FAIL")))
cat(sprintf("    Control rate = %.4f, |%.4f - 0.05| = %.4f\n",
            ctrl_reject_rate, ctrl_reject_rate, abs(ctrl_reject_rate - 0.05)))

# Per-year rejection rates
unt_year <- merge(unt, real_pvals[, .(pair, reject)], by = "pair")
real_by_year <- unt_year[, .(
    n_pairs = uniqueN(pair),
    reject_rate = mean(reject[!duplicated(pair)], na.rm = TRUE)
), by = year]

ctrl_year <- merge(control, ctrl_pvals[, .(pair, reject)], by = "pair")
ctrl_by_year <- ctrl_year[, .(
    n_pairs = uniqueN(pair),
    reject_rate = mean(reject[!duplicated(pair)], na.rm = TRUE)
), by = year]

# =============================================================================
# STATISTIC 2: POOLED SHAPE (SKEWNESS AND KURTOSIS)
# =============================================================================

cat("\n========================================================================\n")
cat("STATISTIC 2: POOLED SHAPE (SKEWNESS AND EXCESS KURTOSIS)\n")
cat("========================================================================\n")

skewness <- function(x) {
    n <- length(x)
    m <- mean(x)
    s <- sd(x)
    sum((x - m)^3) / (n * s^3)
}

kurtosis <- function(x) {
    n <- length(x)
    m <- mean(x)
    s <- sd(x)
    sum((x - m)^4) / (n * s^4) - 3
}

# Overall
real_skew <- skewness(unt$z)
real_kurt <- kurtosis(unt$z)
ctrl_skew <- skewness(control$z)
ctrl_kurt <- kurtosis(control$z)

cat(sprintf("  Overall - Real:    skewness = %.4f, excess kurtosis = %.4f\n", real_skew, real_kurt))
cat(sprintf("  Overall - Control: skewness = %.4f, excess kurtosis = %.4f\n", ctrl_skew, ctrl_kurt))

# Per year
real_shape_year <- unt[, .(skewness = skewness(z), kurtosis = kurtosis(z)), by = year]
ctrl_shape_year <- control[, .(skewness = skewness(z), kurtosis = kurtosis(z)), by = year]

# =============================================================================
# STATISTIC 3: UPPER TAIL QUANTILES
# =============================================================================

cat("\n========================================================================\n")
cat("STATISTIC 3: UPPER TAIL QUANTILES\n")
cat("========================================================================\n")

quantile_probs <- c(0.95, 0.99, 0.995, 0.999)

real_quantiles <- quantile(unt$z, quantile_probs)
ctrl_quantiles <- quantile(control$z, quantile_probs)
ratios <- real_quantiles / ctrl_quantiles

cat("  Overall quantiles:\n")
for (i in seq_along(quantile_probs)) {
    cat(sprintf("    p%.3f: Real = %.4f, Control = %.4f, Ratio = %.4f\n",
                quantile_probs[i], real_quantiles[i], ctrl_quantiles[i], ratios[i]))
}

# Per year
real_quant_year <- unt[, as.list(quantile(z, quantile_probs)), by = year]
setnames(real_quant_year, c("year", paste0("q", quantile_probs * 100)))
ctrl_quant_year <- control[, as.list(quantile(z, quantile_probs)), by = year]
setnames(ctrl_quant_year, c("year", paste0("q", quantile_probs * 100)))

# =============================================================================
# STATISTIC 4: JENSEN IDENTITY
# =============================================================================

cat("\n========================================================================\n")
cat("STATISTIC 4: JENSEN IDENTITY\n")
cat("========================================================================\n")

# Per pair: mean and variance of log_eta (unstandardized)
real_jensen <- unt[, .(
    mean_log_eta = mean(log_eta),
    var_log_eta = var(log_eta),
    n_cells = .N
), by = pair]

ctrl_jensen <- control[, .(
    mean_log_eta = mean(log_eta_ctrl),
    var_log_eta = var(log_eta_ctrl),
    n_cells = .N
), by = pair]

# Regression: mean ~ variance
# Under (A2): mean = -0.5 * var + 0, i.e., intercept = 0, slope = -0.5

real_fit <- lm(mean_log_eta ~ var_log_eta, data = real_jensen)
real_coef <- summary(real_fit)$coefficients

ctrl_fit <- lm(mean_log_eta ~ var_log_eta, data = ctrl_jensen)
ctrl_coef <- summary(ctrl_fit)$coefficients

cat("  Real data regression: mean ~ var\n")
cat(sprintf("    Intercept: %.6f (SE = %.6f)\n", real_coef[1, 1], real_coef[1, 2]))
cat(sprintf("    Slope:     %.6f (SE = %.6f)\n", real_coef[2, 1], real_coef[2, 2]))
cat(sprintf("    R-squared: %.6f\n", summary(real_fit)$r.squared))
cat(sprintf("    N pairs:   %d\n", nrow(real_jensen)))

cat("\n  Control regression: mean ~ var\n")
cat(sprintf("    Intercept: %.6f (SE = %.6f)\n", ctrl_coef[1, 1], ctrl_coef[1, 2]))
cat(sprintf("    Slope:     %.6f (SE = %.6f)\n", ctrl_coef[2, 1], ctrl_coef[2, 2]))
cat(sprintf("    R-squared: %.6f\n", summary(ctrl_fit)$r.squared))
cat(sprintf("    N pairs:   %d\n", nrow(ctrl_jensen)))

cat("\n  (Under A2: intercept = 0, slope = -0.5)\n")
cat("  (Control: iid N(0,1) draws, Jensen identity NOT imposed)\n")

# =============================================================================
# GATE G2: CELL AND PAIR ACCOUNTING
# =============================================================================

cat("\n========================================================================\n")
cat("GATE G2: CELL AND PAIR ACCOUNTING\n")
cat("========================================================================\n")

# Check: pairs_used + pairs_excluded = pairs_available
n_pairs_available <- nrow(pair_counts)
n_pairs_used <- length(pairs_8plus)
n_pairs_excl <- length(pairs_excluded)

g2_pairs <- (n_pairs_used + n_pairs_excl == n_pairs_available)
cat(sprintf("  Pairs: used (%d) + excluded (%d) = available (%d) ? %s\n",
            n_pairs_used, n_pairs_excl, n_pairs_available,
            ifelse(g2_pairs, "YES", "NO")))

# Check: cells in used pairs
n_cells_available <- nrow(untreated)
n_cells_used <- nrow(unt)
n_cells_excluded <- sum(pair_counts[n_cells < MIN_CELLS, n_cells])

g2_cells <- (n_cells_used + n_cells_excluded == n_cells_available)
cat(sprintf("  Cells: used (%d) + excluded (%d) = available (%d) ? %s\n",
            n_cells_used, n_cells_excluded, n_cells_available,
            ifelse(g2_cells, "YES", "NO")))

g2_pass <- g2_pairs && g2_cells
cat(sprintf("\n*** Gate G2 (accounting reconciles): %s ***\n", ifelse(g2_pass, "PASS", "FAIL")))

# Gate G3 already verified above (pair-by-pair matching)
g3_pass <- TRUE
cat(sprintf("*** Gate G3 (identical pair counts): %s ***\n", ifelse(g3_pass, "PASS", "FAIL")))

stopifnot(g1_pass)
stopifnot(g2_pass)
stopifnot(g3_pass)

# =============================================================================
# OUTPUT T38: STATISTICS 1-3
# =============================================================================

cat("\n========================================================================\n")
cat("WRITING OUTPUT FILES\n")
cat("========================================================================\n")

# Build long-format table for statistics 1-3
t38_rows <- list()

# Stat 1: rejection rates overall
t38_rows[[length(t38_rows) + 1]] <- data.table(
    panel = "real", year = "overall", statistic = "rejection_rate",
    grid_point = "overall", value = real_reject_rate
)
t38_rows[[length(t38_rows) + 1]] <- data.table(
    panel = "control", year = "overall", statistic = "rejection_rate",
    grid_point = "overall", value = ctrl_reject_rate
)

# Stat 1: rejection rates by year
for (i in 1:nrow(real_by_year)) {
    t38_rows[[length(t38_rows) + 1]] <- data.table(
        panel = "real", year = as.character(real_by_year$year[i]),
        statistic = "rejection_rate", grid_point = "yearly",
        value = real_by_year$reject_rate[i]
    )
}
for (i in 1:nrow(ctrl_by_year)) {
    t38_rows[[length(t38_rows) + 1]] <- data.table(
        panel = "control", year = as.character(ctrl_by_year$year[i]),
        statistic = "rejection_rate", grid_point = "yearly",
        value = ctrl_by_year$reject_rate[i]
    )
}

# Stat 2: skewness and kurtosis overall
t38_rows[[length(t38_rows) + 1]] <- data.table(
    panel = "real", year = "overall", statistic = "skewness",
    grid_point = "pooled", value = real_skew
)
t38_rows[[length(t38_rows) + 1]] <- data.table(
    panel = "real", year = "overall", statistic = "excess_kurtosis",
    grid_point = "pooled", value = real_kurt
)
t38_rows[[length(t38_rows) + 1]] <- data.table(
    panel = "control", year = "overall", statistic = "skewness",
    grid_point = "pooled", value = ctrl_skew
)
t38_rows[[length(t38_rows) + 1]] <- data.table(
    panel = "control", year = "overall", statistic = "excess_kurtosis",
    grid_point = "pooled", value = ctrl_kurt
)

# Stat 2: shape by year
for (i in 1:nrow(real_shape_year)) {
    t38_rows[[length(t38_rows) + 1]] <- data.table(
        panel = "real", year = as.character(real_shape_year$year[i]),
        statistic = "skewness", grid_point = "yearly",
        value = real_shape_year$skewness[i]
    )
    t38_rows[[length(t38_rows) + 1]] <- data.table(
        panel = "real", year = as.character(real_shape_year$year[i]),
        statistic = "excess_kurtosis", grid_point = "yearly",
        value = real_shape_year$kurtosis[i]
    )
}
for (i in 1:nrow(ctrl_shape_year)) {
    t38_rows[[length(t38_rows) + 1]] <- data.table(
        panel = "control", year = as.character(ctrl_shape_year$year[i]),
        statistic = "skewness", grid_point = "yearly",
        value = ctrl_shape_year$skewness[i]
    )
    t38_rows[[length(t38_rows) + 1]] <- data.table(
        panel = "control", year = as.character(ctrl_shape_year$year[i]),
        statistic = "excess_kurtosis", grid_point = "yearly",
        value = ctrl_shape_year$kurtosis[i]
    )
}

# Stat 3: quantiles overall
for (i in seq_along(quantile_probs)) {
    t38_rows[[length(t38_rows) + 1]] <- data.table(
        panel = "real", year = "overall", statistic = "quantile",
        grid_point = sprintf("p%.3f", quantile_probs[i]),
        value = real_quantiles[i]
    )
    t38_rows[[length(t38_rows) + 1]] <- data.table(
        panel = "control", year = "overall", statistic = "quantile",
        grid_point = sprintf("p%.3f", quantile_probs[i]),
        value = ctrl_quantiles[i]
    )
}

# Stat 3: quantiles by year
for (i in 1:nrow(real_quant_year)) {
    for (j in seq_along(quantile_probs)) {
        t38_rows[[length(t38_rows) + 1]] <- data.table(
            panel = "real", year = as.character(real_quant_year$year[i]),
            statistic = "quantile",
            grid_point = sprintf("p%.3f", quantile_probs[j]),
            value = as.numeric(real_quant_year[i, j + 1, with = FALSE])
        )
    }
}
for (i in 1:nrow(ctrl_quant_year)) {
    for (j in seq_along(quantile_probs)) {
        t38_rows[[length(t38_rows) + 1]] <- data.table(
            panel = "control", year = as.character(ctrl_quant_year$year[i]),
            statistic = "quantile",
            grid_point = sprintf("p%.3f", quantile_probs[j]),
            value = as.numeric(ctrl_quant_year[i, j + 1, with = FALSE])
        )
    }
}

t38 <- rbindlist(t38_rows)
write.csv(t38, file.path(RTA_ROOT, "output/T38_a2_normality.csv"), row.names = FALSE)
cat(sprintf("  Wrote output/T38_a2_normality.csv (%d rows)\n", nrow(t38)))

# =============================================================================
# OUTPUT T39: JENSEN IDENTITY
# =============================================================================

# Per-pair means and variances, plus summary row
t39_pairs <- rbind(
    real_jensen[, .(panel = "real", pair, mean_log_eta, var_log_eta, n_cells)],
    ctrl_jensen[, .(panel = "control", pair, mean_log_eta, var_log_eta, n_cells)]
)

# Summary rows
t39_summary <- data.table(
    panel = c("real", "control"),
    pair = c("__SUMMARY__", "__SUMMARY__"),
    mean_log_eta = c(real_coef[1, 1], ctrl_coef[1, 1]),  # intercept
    var_log_eta = c(real_coef[2, 1], ctrl_coef[2, 1]),   # slope
    n_cells = c(nrow(real_jensen), nrow(ctrl_jensen))
)
# Add SEs and R-squared as additional columns
t39_summary[, intercept_se := c(real_coef[1, 2], ctrl_coef[1, 2])]
t39_summary[, slope_se := c(real_coef[2, 2], ctrl_coef[2, 2])]
t39_summary[, r_squared := c(summary(real_fit)$r.squared, summary(ctrl_fit)$r.squared)]

# For pairs, add NA placeholders for summary columns
t39_pairs[, `:=`(intercept_se = NA_real_, slope_se = NA_real_, r_squared = NA_real_)]

t39 <- rbind(t39_pairs, t39_summary)
write.csv(t39, file.path(RTA_ROOT, "output/T39_a2_jensen_identity.csv"), row.names = FALSE)
cat(sprintf("  Wrote output/T39_a2_jensen_identity.csv (%d rows)\n", nrow(t39)))

# =============================================================================
# FIGURE F5: QQ PLOT
# =============================================================================

cat("\nGenerating QQ plot...\n")

# Sort z values for QQ plot
real_z_sorted <- sort(unt$z)
ctrl_z_sorted <- sort(control$z)

# If unequal length (shouldn't be), interpolate
if (length(real_z_sorted) != length(ctrl_z_sorted)) {
    n <- min(length(real_z_sorted), length(ctrl_z_sorted))
    real_z_sorted <- quantile(unt$z, seq(0, 1, length.out = n))
    ctrl_z_sorted <- quantile(control$z, seq(0, 1, length.out = n))
}

# PDF
pdf(file.path(RTA_ROOT, "output/F5_a2_normality_qq.pdf"), width = 8, height = 8)
par(mfrow = c(1, 1))

# Main plot
plot(ctrl_z_sorted, real_z_sorted,
     pch = ".", col = rgb(0, 0, 0, 0.1),
     xlab = "Control (standardized)", ylab = "Real (standardized)",
     main = "QQ Plot: Real vs Matched Normal Control",
     xlim = range(c(ctrl_z_sorted, real_z_sorted)),
     ylim = range(c(ctrl_z_sorted, real_z_sorted)))
abline(0, 1, col = "red", lwd = 2)

# Inset: top 1%
par(fig = c(0.55, 0.95, 0.1, 0.5), new = TRUE)
top_1_idx <- which(ctrl_z_sorted >= quantile(ctrl_z_sorted, 0.99))
plot(ctrl_z_sorted[top_1_idx], real_z_sorted[top_1_idx],
     pch = 16, cex = 0.5, col = "blue",
     xlab = "", ylab = "",
     main = "Top 1%")
abline(0, 1, col = "red", lwd = 1)

dev.off()

# PNG (use cairo for headless server)
png(file.path(RTA_ROOT, "output/F5_a2_normality_qq.png"), width = 800, height = 800, type = "cairo")
par(mfrow = c(1, 1))

plot(ctrl_z_sorted, real_z_sorted,
     pch = ".", col = rgb(0, 0, 0, 0.1),
     xlab = "Control (standardized)", ylab = "Real (standardized)",
     main = "QQ Plot: Real vs Matched Normal Control",
     xlim = range(c(ctrl_z_sorted, real_z_sorted)),
     ylim = range(c(ctrl_z_sorted, real_z_sorted)))
abline(0, 1, col = "red", lwd = 2)

par(fig = c(0.55, 0.95, 0.1, 0.5), new = TRUE)
plot(ctrl_z_sorted[top_1_idx], real_z_sorted[top_1_idx],
     pch = 16, cex = 0.5, col = "blue",
     xlab = "", ylab = "",
     main = "Top 1%")
abline(0, 1, col = "red", lwd = 1)

dev.off()

cat("  Wrote output/F5_a2_normality_qq.pdf\n")
cat("  Wrote output/F5_a2_normality_qq.png\n")

# =============================================================================
# FINAL SUMMARY
# =============================================================================

END_TIME <- Sys.time()

cat("\n========================================================================\n")
cat("FINAL SUMMARY\n")
cat("========================================================================\n")

cat("\nSAMPLE:\n")
cat(sprintf("  Pairs available: %d\n", n_pairs_available))
cat(sprintf("  Pairs used (>= %d cells): %d\n", MIN_CELLS, n_pairs_used))
cat(sprintf("  Pairs excluded: %d (%.1f%%)\n", n_pairs_excl, 100 * n_pairs_excl / n_pairs_available))
cat(sprintf("  Cells available: %d\n", n_cells_available))
cat(sprintf("  Cells used: %d\n", n_cells_used))

cat("\nGATES:\n")
cat(sprintf("  G1 (control rate ~ 0.05): %.4f, |diff| = %.4f [%s]\n",
            ctrl_reject_rate, abs(ctrl_reject_rate - 0.05),
            ifelse(g1_pass, "PASS", "FAIL")))
cat(sprintf("  G2 (accounting): [%s]\n", ifelse(g2_pass, "PASS", "FAIL")))
cat(sprintf("  G3 (pair matching): [%s]\n", ifelse(g3_pass, "PASS", "FAIL")))

cat("\nNORMALITY (Shapiro-Wilk):\n")
cat(sprintf("  Real rejection rate: %.4f\n", real_reject_rate))
cat(sprintf("  Control rejection rate: %.4f\n", ctrl_reject_rate))
cat(sprintf("  Difference: %.4f (SE = %.4f)\n", diff_rate, se_diff))

cat("\nPOOLED SHAPE:\n")
cat(sprintf("  Real:    skewness = %.4f, excess kurtosis = %.4f\n", real_skew, real_kurt))
cat(sprintf("  Control: skewness = %.4f, excess kurtosis = %.4f\n", ctrl_skew, ctrl_kurt))

cat("\nUPPER TAIL (ratios real/control):\n")
for (i in seq_along(quantile_probs)) {
    cat(sprintf("  p%.3f: %.4f\n", quantile_probs[i], ratios[i]))
}

cat("\nJENSEN IDENTITY:\n")
cat(sprintf("  Real:    intercept = %.4f (SE %.4f), slope = %.4f (SE %.4f), R² = %.4f\n",
            real_coef[1, 1], real_coef[1, 2], real_coef[2, 1], real_coef[2, 2],
            summary(real_fit)$r.squared))
cat(sprintf("  Control: intercept = %.4f (SE %.4f), slope = %.4f (SE %.4f), R² = %.4f\n",
            ctrl_coef[1, 1], ctrl_coef[1, 2], ctrl_coef[2, 1], ctrl_coef[2, 2],
            summary(ctrl_fit)$r.squared))
cat("  (Under A2: intercept = 0, slope = -0.5)\n")

cat(sprintf("\nWall time: %.1f seconds\n", as.numeric(END_TIME - START_TIME, units = "secs")))
cat(sprintf("S34 COMPLETE: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
