#!/usr/bin/env Rscript
# =============================================================================
# S35: Is the Jensen slope real, or a skew artifact?
# =============================================================================
# Adds Control C (skewed, identity imposed) to test whether the Jensen slope
# of -0.20 in the real data is a genuine departure from -0.5, or an artifact
# of skewness + measurement error attenuation.
# =============================================================================

cat("========================================================================\n")
cat("S35: IS THE JENSEN SLOPE REAL, OR A SKEW ARTIFACT?\n")
cat(sprintf("Start: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("========================================================================\n\n")

set.seed(20260731)
START_TIME <- Sys.time()

if (!grepl("Simon", getwd())) {
    .libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))
}

library(data.table)

# =============================================================================
# TARGET MOMENTS FROM S34 AND HELPER FUNCTIONS
# =============================================================================
TARGET_SKEW <- -0.4755
TARGET_KURT <- 0.7840

cat(sprintf("Target pooled moments: skewness=%.4f, excess_kurtosis=%.4f\n",
            TARGET_SKEW, TARGET_KURT))

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

# Sinh-arcsinh transformation for generating skewed/kurtotic data
# Y = sinh(delta * asinh(X) - epsilon) where X ~ N(0,1)
# delta controls kurtosis (delta < 1 = heavy tails, delta > 1 = light tails)
# epsilon controls skewness (epsilon > 0 = left skew)

r_sas <- function(n, epsilon, delta) {
    x <- rnorm(n)
    sinh(delta * asinh(x) - epsilon)
}

# NOTE: We will calibrate SAS parameters AFTER loading data, so we can simulate
# the full pipeline including within-pair standardization with actual pair sizes

# =============================================================================
# LOAD S34 OUTPUTS
# =============================================================================

cat("\nLoading S34 outputs...\n")

# T39: per-pair means and variances
t39 <- fread("output/T39_a2_jensen_identity.csv")
cat(sprintf("  T39: %d rows\n", nrow(t39)))

# Extract real panel data (exclude summary rows)
real_jensen <- t39[panel == "real" & pair != "__SUMMARY__"]
cat(sprintf("  Real pairs: %d\n", nrow(real_jensen)))

# Get S34's normal control data
ctrl_jensen <- t39[panel == "control" & pair != "__SUMMARY__"]

# Get summary row for G4 check
real_summary <- t39[panel == "real" & pair == "__SUMMARY__"]
cat(sprintf("  S34 real slope: %.4f, intercept: %.4f\n",
            real_summary$var_log_eta, real_summary$mean_log_eta))

# =============================================================================
# LOAD ORIGINAL CELL-LEVEL DATA
# =============================================================================

cat("\nLoading original cell-level data...\n")

INPUT_PATH <- "/scratch/bt307958/ENFORCE_ROOT/data/S1R_ppml.rds"
d <- readRDS(INPUT_PATH)
setDT(d)

# Filter to untreated cells (same as S34)
untreated <- d[est_sample == TRUE & in_model == TRUE & trade > 0]
untreated[, log_eta := log(trade) - log(y_hat_0)]

# Count cells per pair
pair_counts <- untreated[, .N, by = pair]
setnames(pair_counts, "N", "n_cells")

# Filter to pairs with >= 8 cells (same as S34)
MIN_CELLS <- 8
pairs_8plus <- pair_counts[n_cells >= MIN_CELLS, pair]
unt <- untreated[pair %in% pairs_8plus]

cat(sprintf("  Cells in retained pairs: %d\n", nrow(unt)))
cat(sprintf("  Pairs retained: %d\n", length(pairs_8plus)))

# Verify this matches S34
stopifnot(nrow(real_jensen) == length(pairs_8plus))
cat("  Pair count matches S34: PASS\n")

# =============================================================================
# REGENERATE S34's NORMAL CONTROL (same seed as S34)
# =============================================================================

cat("\nRegenerating S34's normal control (for consistency)...\n")

set.seed(20260731)  # Same seed as S34

normal_ctrl_list <- list()
for (p in pairs_8plus) {
    n_i <- sum(unt$pair == p)
    normal_ctrl_list[[p]] <- data.table(
        pair = p,
        log_eta_ctrl = rnorm(n_i, 0, 1)
    )
}
normal_ctrl <- rbindlist(normal_ctrl_list)

# Compute mean_i and var_i for normal control
normal_jensen <- normal_ctrl[, .(
    mean_log_eta = mean(log_eta_ctrl),
    var_log_eta = var(log_eta_ctrl),
    n_cells = .N
), by = pair]

# =============================================================================
# GENERATE CONTROL C (SKEWED, IDENTITY IMPOSED)
# =============================================================================
# Strategy: For each pair, we need observations that:
# 1. Have variance v_i (from S34)
# 2. Have mean -v_i/2 (Jensen identity)
# 3. When pooled AND WITHIN-PAIR STANDARDIZED, have shape matching real data
#
# Key insight: within-pair standardization with small samples attenuates shape.
# We must calibrate the generating distribution so that AFTER standardization,
# the pooled z has the target moments.

cat("\nGenerating Control C (skewed, identity imposed)...\n")

# Get pair structure for calibration
pair_n <- unt[, .N, by = pair]
pair_var <- real_jensen[, .(pair, var_log_eta)]

# For calibration, use a random subsample of pairs (much faster)
set.seed(20260731 + 50)
N_CALIB_PAIRS <- min(3000, length(pairs_8plus))
calib_pairs_idx <- sample(seq_along(pairs_8plus), N_CALIB_PAIRS)
calib_pairs <- pairs_8plus[calib_pairs_idx]

cat(sprintf("  Using %d pairs for calibration (of %d total)\n", N_CALIB_PAIRS, length(pairs_8plus)))

# Function to generate Control C with given SAS parameters and compute pooled moments
# Uses subsample for speed during calibration
generate_ctrl_c_moments <- function(epsilon, delta, seed_offset = 0, use_all = FALSE) {
    set.seed(20260731 + 100 + seed_offset)

    pairs_to_use <- if (use_all) pairs_8plus else calib_pairs

    all_z <- numeric(0)

    for (i in seq_along(pairs_to_use)) {
        p <- pairs_to_use[i]
        n_i <- pair_n[pair == p, N]
        v_i <- pair_var[pair == p, var_log_eta]

        # Draw from SAS distribution (standardized form, then scale/shift)
        x <- r_sas(n_i, epsilon, delta)

        # Scale to variance v_i
        x_scaled <- x * sqrt(v_i) / sd(x)

        # Shift to mean = -v_i/2
        target_mean <- -v_i / 2
        x_final <- x_scaled - mean(x_scaled) + target_mean

        # Within-pair standardization (same as real data)
        z <- (x_final - mean(x_final)) / sd(x_final)

        all_z <- c(all_z, z)
    }

    c(skewness(all_z), kurtosis(all_z))
}

# Calibrate SAS parameters to match target moments AFTER standardization
cat("  Calibrating SAS parameters (accounting for within-pair standardization)...\n")

sas_loss_full <- function(params) {
    epsilon <- params[1]
    delta <- params[2]
    if (delta <= 0.1 || delta > 2) return(1e10)
    if (epsilon < 0 || epsilon > 1.5) return(1e10)

    # Single evaluation (calibration subsample provides enough stability)
    moments <- generate_ctrl_c_moments(epsilon, delta, 0)
    (moments[1] - TARGET_SKEW)^2 + (moments[2] - TARGET_KURT)^2
}

# Grid search for good starting point (coarse grid)
cat("  Grid search for starting point...\n")
best_loss <- Inf
best_start <- c(0.3, 0.9)
for (eps in seq(0.2, 0.8, by = 0.2)) {
    for (del in seq(0.7, 1.3, by = 0.2)) {
        loss <- sas_loss_full(c(eps, del))
        if (loss < best_loss) {
            best_loss <- loss
            best_start <- c(eps, del)
            cat(sprintf("    eps=%.2f, del=%.2f -> loss=%.6f\n", eps, del, loss))
        }
    }
}

# Optimize from best grid point
cat(sprintf("  Optimizing from eps=%.2f, del=%.2f...\n", best_start[1], best_start[2]))
opt <- optim(best_start, sas_loss_full, method = "L-BFGS-B",
             lower = c(0.1, 0.3), upper = c(1.2, 1.5),
             control = list(factr = 1e7))

SAS_EPSILON <- opt$par[1]
SAS_DELTA <- opt$par[2]

# Verify with the optimized parameters (on calibration subsample)
test_moments <- generate_ctrl_c_moments(SAS_EPSILON, SAS_DELTA, seed_offset = 999)
cat(sprintf("  Optimized SAS: epsilon=%.4f, delta=%.4f\n", SAS_EPSILON, SAS_DELTA))
cat(sprintf("  Calibration subsample: skew=%.4f, kurt=%.4f\n", test_moments[1], test_moments[2]))
cat(sprintf("  Target:                skew=%.4f, kurt=%.4f\n", TARGET_SKEW, TARGET_KURT))

# Compute population mean and SD of the SAS distribution from a large sample
# This allows us to scale/shift without forcing sample stats to match exactly
set.seed(20260731 + 200)
sas_pop <- r_sas(1e6, SAS_EPSILON, SAS_DELTA)
SAS_POP_MEAN <- mean(sas_pop)
SAS_POP_SD <- sd(sas_pop)
cat(sprintf("  SAS population: mean=%.6f, SD=%.6f\n", SAS_POP_MEAN, SAS_POP_SD))

# Now generate the actual Control C data with final seed
# Key: scale/shift using POPULATION parameters, not sample stats
# This way the identity holds in expectation but not exactly in each sample
cat("\n  Generating Control C data...\n")
set.seed(20260731 + 1)  # Final seed for Control C

ctrl_c_list <- list()
generating_means <- numeric(length(pairs_8plus))
generating_vars <- numeric(length(pairs_8plus))

for (i in seq_along(pairs_8plus)) {
    p <- pairs_8plus[i]
    n_i <- pair_n[pair == p, N]
    v_i <- pair_var[pair == p, var_log_eta]

    # Draw from calibrated SAS distribution
    x <- r_sas(n_i, SAS_EPSILON, SAS_DELTA)

    # Scale using POPULATION SD so expected variance = v_i
    # (sample variance will fluctuate around v_i)
    x_scaled <- (x - SAS_POP_MEAN) * sqrt(v_i) / SAS_POP_SD

    # Shift so expected mean = -v_i/2 (Jensen identity)
    # (sample mean will fluctuate around -v_i/2)
    target_mean <- -v_i / 2
    x_final <- x_scaled + target_mean

    # Record generating parameters (these are exact, not realized)
    generating_means[i] <- target_mean
    generating_vars[i] <- v_i

    ctrl_c_list[[p]] <- data.table(
        pair = p,
        log_eta_c = x_final
    )
}
ctrl_c <- rbindlist(ctrl_c_list)

cat(sprintf("  Control C cells: %d\n", nrow(ctrl_c)))

# Gate G2: Verify identity is imposed exactly
g2_max_error <- max(abs(generating_means + generating_vars / 2))
cat(sprintf("  G2 max|mean + v/2|: %.2e\n", g2_max_error))
stopifnot(g2_max_error < 1e-10)
cat("  G2 (identity imposed exactly): PASS\n")

# Compute mean_i and var_i for Control C FROM THE DRAWN DATA
ctrl_c_jensen <- ctrl_c[, .(
    mean_log_eta = mean(log_eta_c),
    var_log_eta = var(log_eta_c),
    n_cells = .N
), by = pair]

# =============================================================================
# GATE G1: CHECK SHAPE MATCH
# =============================================================================
# The prompt says "shape matched to the real pooled data: skewness -0.4755 and
# excess kurtosis 0.7840 as measured in S34."
#
# S34 measured these on within-pair standardized z. We use the same approach:
# standardize Control C within each pair, then pool and compute shape.

cat("\nChecking Control C shape match (G1)...\n")

# Within-pair standardization for Control C
ctrl_c[, `:=`(
    pair_mean = mean(log_eta_c),
    pair_sd = sd(log_eta_c)
), by = pair]
ctrl_c[, z := (log_eta_c - pair_mean) / pair_sd]

# Compute shape on pooled standardized z (same as S34)
ctrl_c_skew <- skewness(ctrl_c$z)
ctrl_c_kurt <- kurtosis(ctrl_c$z)

cat(sprintf("  Control C pooled z shape: skew=%.4f, kurt=%.4f\n",
            ctrl_c_skew, ctrl_c_kurt))
cat(sprintf("  Target (S34): skew=%.4f, kurt=%.4f\n", TARGET_SKEW, TARGET_KURT))

# G1: Within 0.10 of skewness, within 0.15 of kurtosis
g1_skew_ok <- abs(ctrl_c_skew - TARGET_SKEW) <= 0.10
g1_kurt_ok <- abs(ctrl_c_kurt - TARGET_KURT) <= 0.15
g1_pass <- g1_skew_ok && g1_kurt_ok

cat(sprintf("  Skew diff: %.4f (max 0.10) [%s]\n",
            abs(ctrl_c_skew - TARGET_SKEW), ifelse(g1_skew_ok, "OK", "FAIL")))
cat(sprintf("  Kurt diff: %.4f (max 0.15) [%s]\n",
            abs(ctrl_c_kurt - TARGET_KURT), ifelse(g1_kurt_ok, "OK", "FAIL")))
cat(sprintf("  G1 (shape match): %s\n", ifelse(g1_pass, "PASS", "FAIL")))

stopifnot(g1_pass)

# =============================================================================
# GATE G3: PAIR COUNTS MATCH
# =============================================================================

cat("\nChecking pair counts match (G3)...\n")

n_real <- nrow(real_jensen)
n_normal <- nrow(normal_jensen)
n_ctrl_c <- nrow(ctrl_c_jensen)

cat(sprintf("  Real pairs: %d\n", n_real))
cat(sprintf("  Normal control pairs: %d\n", n_normal))
cat(sprintf("  Control C pairs: %d\n", n_ctrl_c))

g3_pairs <- (n_real == n_normal) && (n_real == n_ctrl_c)

# Check per-pair observation counts
real_n <- unt[, .N, by = pair][order(pair)]
normal_n <- normal_ctrl[, .N, by = pair][order(pair)]
ctrl_c_n <- ctrl_c[, .N, by = pair][order(pair)]

g3_cells <- all(real_n$N == normal_n$N) && all(real_n$N == ctrl_c_n$N)

g3_pass <- g3_pairs && g3_cells
cat(sprintf("  G3 (pair and cell counts match): %s\n", ifelse(g3_pass, "PASS", "FAIL")))
stopifnot(g3_pass)

# =============================================================================
# RECOMPUTE REAL PANEL FROM CELL DATA (for G4)
# =============================================================================

cat("\nRecomputing real panel Jensen regression (for G4)...\n")

real_jensen_recomputed <- unt[, .(
    mean_log_eta = mean(log_eta),
    var_log_eta = var(log_eta),
    n_cells = .N
), by = pair]

real_fit <- lm(mean_log_eta ~ var_log_eta, data = real_jensen_recomputed)
real_coef <- coef(real_fit)
real_se <- summary(real_fit)$coefficients[, 2]

cat(sprintf("  Real intercept: %.4f (S34: -0.2201)\n", real_coef[1]))
cat(sprintf("  Real slope: %.4f (S34: -0.1966)\n", real_coef[2]))

# Gate G4: Must match S34 to 4 decimals
g4_intercept <- round(real_coef[1], 4) == -0.2201
g4_slope <- round(real_coef[2], 4) == -0.1966

g4_pass <- g4_intercept && g4_slope
cat(sprintf("  G4 (matches S34): %s\n", ifelse(g4_pass, "PASS", "FAIL")))
stopifnot(g4_pass)

# =============================================================================
# RUN JENSEN REGRESSIONS FOR ALL THREE PANELS
# =============================================================================

cat("\n========================================================================\n")
cat("JENSEN REGRESSIONS FOR ALL THREE PANELS\n")
cat("========================================================================\n")

# Real panel (already computed above)
real_r2 <- summary(real_fit)$r.squared

# Normal control
normal_fit <- lm(mean_log_eta ~ var_log_eta, data = normal_jensen)
normal_coef <- coef(normal_fit)
normal_se <- summary(normal_fit)$coefficients[, 2]
normal_r2 <- summary(normal_fit)$r.squared

# Control C
ctrl_c_fit <- lm(mean_log_eta ~ var_log_eta, data = ctrl_c_jensen)
ctrl_c_coef <- coef(ctrl_c_fit)
ctrl_c_se <- summary(ctrl_c_fit)$coefficients[, 2]
ctrl_c_r2 <- summary(ctrl_c_fit)$r.squared

cat("\nRegression: mean_i ~ var_i\n")
cat(sprintf("  %-15s %10s %10s %10s %10s %8s %8s\n",
            "Panel", "Intercept", "SE", "Slope", "SE", "R²", "N"))
cat(sprintf("  %-15s %10.4f %10.4f %10.4f %10.4f %8.4f %8d\n",
            "Real", real_coef[1], real_se[1], real_coef[2], real_se[2], real_r2, n_real))
cat(sprintf("  %-15s %10.4f %10.4f %10.4f %10.4f %8.4f %8d\n",
            "Normal", normal_coef[1], normal_se[1], normal_coef[2], normal_se[2], normal_r2, n_normal))
cat(sprintf("  %-15s %10.4f %10.4f %10.4f %10.4f %8.4f %8d\n",
            "Control_C", ctrl_c_coef[1], ctrl_c_se[1], ctrl_c_coef[2], ctrl_c_se[2], ctrl_c_r2, n_ctrl_c))

cat("\n  (Under A2: intercept = 0, slope = -0.5)\n")

# =============================================================================
# ATTENUATION DIAGNOSTICS
# =============================================================================

cat("\n========================================================================\n")
cat("ATTENUATION DIAGNOSTICS\n")
cat("========================================================================\n")

# Correlation between mean_i and var_i
cor_real <- cor(real_jensen_recomputed$mean_log_eta, real_jensen_recomputed$var_log_eta)
cor_normal <- cor(normal_jensen$mean_log_eta, normal_jensen$var_log_eta)
cor_ctrl_c <- cor(ctrl_c_jensen$mean_log_eta, ctrl_c_jensen$var_log_eta)

cat("\nCorrelation(mean_i, var_i):\n")
cat(sprintf("  Real:      %.4f\n", cor_real))
cat(sprintf("  Normal:    %.4f\n", cor_normal))
cat(sprintf("  Control_C: %.4f\n", cor_ctrl_c))

# Split-half reliability of var_i
compute_split_half_reliability <- function(dt, log_eta_col) {
    # For each pair, split cells into odd/even indices
    pairs <- unique(dt$pair)
    var_half1 <- numeric(length(pairs))
    var_half2 <- numeric(length(pairs))

    for (i in seq_along(pairs)) {
        p <- pairs[i]
        x <- dt[pair == p, get(log_eta_col)]
        n <- length(x)

        # Odd indices for half1, even for half2
        idx1 <- seq(1, n, by = 2)
        idx2 <- seq(2, n, by = 2)

        # Need at least 2 obs in each half
        if (length(idx1) >= 2 && length(idx2) >= 2) {
            var_half1[i] <- var(x[idx1])
            var_half2[i] <- var(x[idx2])
        } else {
            var_half1[i] <- NA
            var_half2[i] <- NA
        }
    }

    # Correlation of half-sample variances
    valid <- !is.na(var_half1) & !is.na(var_half2)
    r <- cor(var_half1[valid], var_half2[valid])

    # Spearman-Brown correction
    reliability <- 2 * r / (1 + r)

    return(c(r = r, reliability = reliability, n_valid = sum(valid)))
}

rel_real <- compute_split_half_reliability(unt, "log_eta")
rel_normal <- compute_split_half_reliability(normal_ctrl, "log_eta_ctrl")
rel_ctrl_c <- compute_split_half_reliability(ctrl_c, "log_eta_c")

cat("\nSplit-half reliability of var_i:\n")
cat(sprintf("  Real:      r=%.4f, reliability=%.4f (n=%d)\n",
            rel_real["r"], rel_real["reliability"], rel_real["n_valid"]))
cat(sprintf("  Normal:    r=%.4f, reliability=%.4f (n=%d)\n",
            rel_normal["r"], rel_normal["reliability"], rel_normal["n_valid"]))
cat(sprintf("  Control_C: r=%.4f, reliability=%.4f (n=%d)\n",
            rel_ctrl_c["r"], rel_ctrl_c["reliability"], rel_ctrl_c["n_valid"]))

# =============================================================================
# OUTPUT T40
# =============================================================================

cat("\n========================================================================\n")
cat("WRITING OUTPUT FILES\n")
cat("========================================================================\n")

t40 <- data.table(
    panel = c("real", "normal", "control_c"),
    intercept = c(real_coef[1], normal_coef[1], ctrl_c_coef[1]),
    intercept_se = c(real_se[1], normal_se[1], ctrl_c_se[1]),
    slope = c(real_coef[2], normal_coef[2], ctrl_c_coef[2]),
    slope_se = c(real_se[2], normal_se[2], ctrl_c_se[2]),
    r_squared = c(real_r2, normal_r2, ctrl_c_r2),
    n_pairs = c(n_real, n_normal, n_ctrl_c),
    cor_mean_var = c(cor_real, cor_normal, cor_ctrl_c),
    var_reliability = c(rel_real["reliability"], rel_normal["reliability"], rel_ctrl_c["reliability"])
)

write.csv(t40, "output/T40_jensen_control.csv", row.names = FALSE)
cat(sprintf("  Wrote output/T40_jensen_control.csv (%d rows)\n", nrow(t40)))

# =============================================================================
# GENERATE PNG (S34 couldn't produce it)
# =============================================================================

cat("\nGenerating F5 PNG...\n")

# Read the real and control z values (need to regenerate from S34 logic)
# Real z
unt[, `:=`(
    pair_mean_r = mean(log_eta),
    pair_sd_r = sd(log_eta)
), by = pair]
unt[, z_real := (log_eta - pair_mean_r) / pair_sd_r]

# Normal control z
normal_ctrl[, `:=`(
    pair_mean = mean(log_eta_ctrl),
    pair_sd = sd(log_eta_ctrl)
), by = pair]
normal_ctrl[, z_ctrl := (log_eta_ctrl - pair_mean) / pair_sd]

# Sort for QQ plot
real_z_sorted <- sort(unt$z_real)
ctrl_z_sorted <- sort(normal_ctrl$z_ctrl)

# Try ragg first, then cairo, then pdftoppm
png_success <- FALSE

# Try ragg::agg_png
if (requireNamespace("ragg", quietly = TRUE)) {
    cat("  Using ragg::agg_png\n")
    ragg::agg_png("output/F5_a2_normality_qq.png", width = 800, height = 800)

    par(mfrow = c(1, 1))
    plot(ctrl_z_sorted, real_z_sorted,
         pch = ".", col = rgb(0, 0, 0, 0.1),
         xlab = "Control (standardized)", ylab = "Real (standardized)",
         main = "QQ Plot: Real vs Matched Normal Control",
         xlim = range(c(ctrl_z_sorted, real_z_sorted)),
         ylim = range(c(ctrl_z_sorted, real_z_sorted)))
    abline(0, 1, col = "red", lwd = 2)

    # Inset for top 1%
    par(fig = c(0.55, 0.95, 0.1, 0.5), new = TRUE)
    top_1_idx <- which(ctrl_z_sorted >= quantile(ctrl_z_sorted, 0.99))
    plot(ctrl_z_sorted[top_1_idx], real_z_sorted[top_1_idx],
         pch = 16, cex = 0.5, col = "blue",
         xlab = "", ylab = "",
         main = "Top 1%")
    abline(0, 1, col = "red", lwd = 1)

    dev.off()
    png_success <- TRUE
} else {
    # Try cairo PNG
    tryCatch({
        cat("  Trying png with cairo\n")
        png("output/F5_a2_normality_qq.png", width = 800, height = 800, type = "cairo")

        par(mfrow = c(1, 1))
        plot(ctrl_z_sorted, real_z_sorted,
             pch = ".", col = rgb(0, 0, 0, 0.1),
             xlab = "Control (standardized)", ylab = "Real (standardized)",
             main = "QQ Plot: Real vs Matched Normal Control")
        abline(0, 1, col = "red", lwd = 2)

        dev.off()
        png_success <- TRUE
    }, error = function(e) {
        cat(sprintf("  Cairo PNG failed: %s\n", e$message))
    })
}

# If PNG still not created, use pdftoppm on existing PDF
if (!png_success && file.exists("output/F5_a2_normality_qq.pdf")) {
    cat("  Converting PDF to PNG with pdftoppm\n")
    system("pdftoppm -png -r 100 -singlefile output/F5_a2_normality_qq.pdf output/F5_a2_normality_qq")
    if (file.exists("output/F5_a2_normality_qq.png")) {
        png_success <- TRUE
    }
}

if (png_success) {
    cat("  Wrote output/F5_a2_normality_qq.png\n")
} else {
    cat("  WARNING: Could not generate PNG\n")
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================

END_TIME <- Sys.time()

cat("\n========================================================================\n")
cat("FINAL SUMMARY\n")
cat("========================================================================\n")

cat("\nGATES:\n")
cat(sprintf("  G1 (Control C shape): skew=%.4f (diff %.4f), kurt=%.4f (diff %.4f) [%s]\n",
            ctrl_c_skew, abs(ctrl_c_skew - TARGET_SKEW),
            ctrl_c_kurt, abs(ctrl_c_kurt - TARGET_KURT),
            ifelse(g1_pass, "PASS", "FAIL")))
cat(sprintf("  G2 (identity imposed): max error = %.2e [PASS]\n", g2_max_error))
cat(sprintf("  G3 (counts match): %d pairs each [%s]\n", n_real, ifelse(g3_pass, "PASS", "FAIL")))
cat(sprintf("  G4 (matches S34): intercept=%.4f, slope=%.4f [%s]\n",
            real_coef[1], real_coef[2], ifelse(g4_pass, "PASS", "FAIL")))

cat("\nTHE THREE SLOPES:\n")
cat(sprintf("  %-12s %10s %10s %10s\n", "Panel", "Slope", "SE", "Intercept"))
cat(sprintf("  %-12s %10.4f %10.4f %10.4f\n", "Real", real_coef[2], real_se[2], real_coef[1]))
cat(sprintf("  %-12s %10.4f %10.4f %10.4f\n", "Normal", normal_coef[2], normal_se[2], normal_coef[1]))
cat(sprintf("  %-12s %10.4f %10.4f %10.4f\n", "Control_C", ctrl_c_coef[2], ctrl_c_se[2], ctrl_c_coef[1]))

cat("\nATTENUATION:\n")
cat(sprintf("  %-12s cor(mean,var)=%.4f, var_reliability=%.4f\n", "Real", cor_real, rel_real["reliability"]))
cat(sprintf("  %-12s cor(mean,var)=%.4f, var_reliability=%.4f\n", "Normal", cor_normal, rel_normal["reliability"]))
cat(sprintf("  %-12s cor(mean,var)=%.4f, var_reliability=%.4f\n", "Control_C", cor_ctrl_c, rel_ctrl_c["reliability"]))

cat(sprintf("\nWall time: %.1f seconds\n", as.numeric(END_TIME - START_TIME, units = "secs")))
cat(sprintf("S35 COMPLETE: %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
