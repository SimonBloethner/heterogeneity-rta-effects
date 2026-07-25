# =============================================================================
# gates_lib.R — Heterogeneity Gates Analysis Function Library
# Created: 2026-07-19
# Updated: 2026-07-19 (v2 - Jensen correction)
# 
# DISCIPLINE: Each estimator/transformation is defined ONCE here.
#             All analysis scripts source this file and call these functions.
#             Never re-implement a computation inline.
#
# VERSION: 2 (Definition B as canonical; Definition A deprecated)
# =============================================================================

library(data.table)

# =============================================================================
# CONFIGURATION CONSTANTS
# =============================================================================

GATES_SEED <- 20260719
GATES_LIB_VERSION <- 2

# Use source file directly since filtered version has filesystem issues
DATA_SOURCE_PATH <- "/groups/m-larch/bt307958/tails/data/ITPDE_total.rds"

FROZEN_FACTS <- list(
    n_obs = 794720,
    year_min = 1988,
    year_max = 2019,
    n_2019 = 31650,
    u_90_2019 = 454.27,
    n_above_u_2019 = 3165,
    mean_above_u_2019 = 6780.11,
    total_2019 = 2.228e7,
    max_2019 = 483909
)

# Baseline cell: (3,3) pre/post years with ±1 anticipation window
BASELINE <- list(
    min_pre = 3,
    min_post = 3,
    anticipation_exclude = 1,
    adoption_range = c(1991, 2016)
)

# Placebo validity threshold (halt rule)
PLACEBO_MEAN_THRESHOLD <- 0.05

# =============================================================================
# DATA LOADING
# =============================================================================

load_filtered_data <- function() {
    d <- setDT(readRDS(DATA_SOURCE_PATH))
    d <- d[exporter != importer & trade > 0]
    return(d)
}

# =============================================================================
# STARTUP ASSERTIONS
# =============================================================================

verify_frozen_facts <- function(d) {
    cat("\n=== FROZEN FACTS VERIFICATION ===\n")
    
    if (nrow(d) != FROZEN_FACTS$n_obs) {
        stop(sprintf("n_obs mismatch: %d != %d", nrow(d), FROZEN_FACTS$n_obs))
    }
    cat(sprintf("n_obs: %d [OK]\n", nrow(d)))
    
    if (min(d$year) != FROZEN_FACTS$year_min || max(d$year) != FROZEN_FACTS$year_max) {
        stop(sprintf("Year range mismatch: %d-%d != %d-%d", 
                     min(d$year), max(d$year), FROZEN_FACTS$year_min, FROZEN_FACTS$year_max))
    }
    cat(sprintf("Years: %d-%d [OK]\n", min(d$year), max(d$year)))
    
    d19 <- d[year == 2019]
    
    if (nrow(d19) != FROZEN_FACTS$n_2019) {
        stop(sprintf("2019 n mismatch: %d != %d", nrow(d19), FROZEN_FACTS$n_2019))
    }
    cat(sprintf("2019 n: %d [OK]\n", nrow(d19)))
    
    u <- quantile(d19$trade, 0.90)
    if (abs(u - FROZEN_FACTS$u_90_2019) > 0.01) {
        stop(sprintf("2019 u_90 mismatch: %.2f != %.2f", u, FROZEN_FACTS$u_90_2019))
    }
    cat(sprintf("2019 u_90: %.2f [OK]\n", u))
    
    n_above <- sum(d19$trade > u)
    if (n_above != FROZEN_FACTS$n_above_u_2019) {
        stop(sprintf("2019 n_above_u mismatch: %d != %d", n_above, FROZEN_FACTS$n_above_u_2019))
    }
    cat(sprintf("2019 n_above_u: %d [OK]\n", n_above))
    
    mean_above <- mean(d19[trade > u]$trade)
    if (abs(mean_above - FROZEN_FACTS$mean_above_u_2019) > 0.01) {
        stop(sprintf("2019 mean_above_u mismatch: %.2f != %.2f", mean_above, FROZEN_FACTS$mean_above_u_2019))
    }
    cat(sprintf("2019 mean_above_u: %.2f [OK]\n", mean_above))
    
    total <- sum(d19$trade)
    rel_err <- abs(total - FROZEN_FACTS$total_2019) / FROZEN_FACTS$total_2019
    if (rel_err > 0.001) {
        stop(sprintf("2019 total mismatch: %.4e != %.4e", total, FROZEN_FACTS$total_2019))
    }
    cat(sprintf("2019 total: %.4e [OK]\n", total))
    
    max_flow <- max(d19$trade)
    if (abs(max_flow - FROZEN_FACTS$max_2019) > 1) {
        stop(sprintf("2019 max mismatch: %.0f != %.0f", max_flow, FROZEN_FACTS$max_2019))
    }
    cat(sprintf("2019 max: %.0f [OK]\n", max_flow))
    
    cat("=== ALL FROZEN FACTS VERIFIED ===\n\n")
    invisible(TRUE)
}

# =============================================================================
# SWITCHER IDENTIFICATION
# =============================================================================

identify_switchers <- function(d) {
    setDT(d)
    d[, pair := paste(exporter, importer, sep = "_")]
    
    pair_rta <- d[, .(
        first_rta_year = if (any(rta == 1)) min(year[rta == 1]) else NA_integer_,
        last_no_rta_year = if (any(rta == 0)) max(year[rta == 0]) else NA_integer_,
        n_transitions_01 = sum(diff(rta) == 1),
        n_transitions_10 = sum(diff(rta) == -1),
        always_rta = all(rta == 1),
        never_rta = all(rta == 0),
        n_years = .N,
        min_year = min(year),
        max_year = max(year)
    ), by = pair]
    
    pair_rta[, classification := fcase(
        always_rta, "always_treated",
        never_rta, "never_treated",
        n_transitions_01 == 1 & n_transitions_10 == 0, "single_switcher",
        n_transitions_01 > 1 | n_transitions_10 > 0, "multi_switcher",
        default = "other"
    )]
    
    pair_rta[classification == "single_switcher", adoption_year := first_rta_year]
    
    return(pair_rta)
}

# =============================================================================
# PAIR EFFECT COMPUTATION — DEFINITION B (CANONICAL)
# =============================================================================
# Definition B: θ̂_ij = log(Σ_post y_ijt / Σ_post ŷ⁰_ijt)
# Avoids Jensen inequality bias by summing before taking logs.
# =============================================================================

compute_pair_effect_B <- function(y, y_hat) {
    # Definition B: log of ratio of sums
    sum_y <- sum(y, na.rm = TRUE)
    sum_y_hat <- sum(y_hat, na.rm = TRUE)
    if (sum_y <= 0 || sum_y_hat <= 0) return(NA_real_)
    return(log(sum_y / sum_y_hat))
}

compute_pair_se_B <- function(y, y_hat, n_boot = 500, seed = NULL) {
    # SE by within-pair block bootstrap over post years
    if (length(y) < 2) return(NA_real_)
    
    if (!is.null(seed)) set.seed(seed)
    
    boot_theta <- replicate(n_boot, {
        idx <- sample(length(y), replace = TRUE)
        compute_pair_effect_B(y[idx], y_hat[idx])
    })
    
    return(sd(boot_theta, na.rm = TRUE))
}

compute_pair_effects_B <- function(dt, y_col = "trade", y_hat_col = "y_hat_0", 
                                   pair_col = "pair", n_boot = 500, seed = GATES_SEED) {
    # Compute Definition B effects for all pairs in dt
    set.seed(seed)
    
    results <- dt[, {
        y <- get(y_col)
        y_hat <- get(y_hat_col)
        valid <- !is.na(y) & !is.na(y_hat) & y > 0 & y_hat > 0
        y <- y[valid]
        y_hat <- y_hat[valid]
        
        theta_B <- compute_pair_effect_B(y, y_hat)
        se_B <- compute_pair_se_B(y, y_hat, n_boot = n_boot)
        
        list(
            theta_hat_B = theta_B,
            se_B = se_B,
            sum_y = sum(y),
            sum_y_hat = sum(y_hat),
            T_ij = length(y)
        )
    }, by = pair_col]
    
    return(results)
}

# =============================================================================
# PAIR EFFECT COMPUTATION — DEFINITION A (DEPRECATED)
# =============================================================================
# Definition A: θ̂_ij = mean(log(y) - log(ŷ⁰))
# WARNING: Subject to Jensen inequality bias. Use Definition B instead.
# =============================================================================

compute_pair_effect_A <- function(log_gaps) {
    # DEPRECATED: Use compute_pair_effect_B instead
    warning("Definition A is deprecated due to Jensen bias. Use compute_pair_effect_B.")
    return(mean(log_gaps, na.rm = TRUE))
}

compute_pair_se_A <- function(log_gaps) {
    # DEPRECATED: Use compute_pair_se_B instead
    warning("Definition A is deprecated due to Jensen bias.")
    T_ij <- sum(!is.na(log_gaps))
    if (T_ij < 2) return(NA_real_)
    return(sd(log_gaps, na.rm = TRUE) / sqrt(T_ij))
}

# Legacy aliases (deprecated)
compute_pair_effect <- compute_pair_effect_A
compute_pair_se <- compute_pair_se_A

# =============================================================================
# SPLIT-HALF RELIABILITY — DEFINITION B
# =============================================================================

compute_split_half_B <- function(pair_dt, y_col = "trade", y_hat_col = "y_hat_0",
                                 pair_col = "pair", year_col = "year",
                                 min_years = 4, seed = GATES_SEED) {
    # Split-half reliability for Definition B
    # Splits post years into two halves, computes θ_B on each half
    
    set.seed(seed)
    
    # Filter pairs with enough years
    pair_counts <- pair_dt[, .N, by = pair_col]
    eligible_pairs <- pair_counts[N >= min_years][[pair_col]]
    
    if (length(eligible_pairs) == 0) {
        return(list(n_pairs = 0, pearson = NA, spearman = NA))
    }
    
    dt <- pair_dt[get(pair_col) %in% eligible_pairs]
    
    # Random assignment of years to halves within each pair
    dt[, half := sample(c("A", "B"), .N, replace = TRUE), by = pair_col]
    
    # Compute θ_B for each half
    half_effects <- dt[, {
        y <- get(y_col)
        y_hat <- get(y_hat_col)
        h <- half
        
        # Half A
        yA <- y[h == "A"]
        yhatA <- y_hat[h == "A"]
        theta_A <- if (length(yA) > 0 && sum(yA) > 0 && sum(yhatA) > 0) {
            log(sum(yA) / sum(yhatA))
        } else NA_real_
        
        # Half B
        yB <- y[h == "B"]
        yhatB <- y_hat[h == "B"]
        theta_B <- if (length(yB) > 0 && sum(yB) > 0 && sum(yhatB) > 0) {
            log(sum(yB) / sum(yhatB))
        } else NA_real_
        
        list(theta_A = theta_A, theta_B = theta_B)
    }, by = pair_col]
    
    half_effects <- half_effects[!is.na(theta_A) & !is.na(theta_B)]
    
    return(list(
        n_pairs = nrow(half_effects),
        pearson = cor(half_effects$theta_A, half_effects$theta_B, method = "pearson"),
        spearman = cor(half_effects$theta_A, half_effects$theta_B, method = "spearman"),
        data = half_effects
    ))
}

# =============================================================================
# PLACEBO ASSIGNMENT WITH MATCHING
# =============================================================================

assign_placebo_matched <- function(d, pair_rta, real_qualifying,
                                   min_pre = BASELINE$min_pre, 
                                   min_post = BASELINE$min_post,
                                   anticipation_exclude = BASELINE$anticipation_exclude,
                                   min_consecutive = 8,
                                   seed = GATES_SEED) {
    # Assign placebo adoption years to never-treated pairs
    # Matched version: match to real switchers on pre-period trade decile
    
    set.seed(seed)
    setDT(d)
    d[, pair := paste(exporter, importer, sep = "_")]
    
    # Get pre-period trade for real switchers
    real_pre_trade <- d[pair %in% real_qualifying$pair][
        pair_rta[pair %in% real_qualifying$pair], on = "pair"][
        year < adoption_year - anticipation_exclude, 
        .(pre_trade = sum(trade)), by = pair]
    real_pre_trade[, decile := cut(pre_trade, 
                                    breaks = quantile(pre_trade, probs = 0:10/10, na.rm = TRUE),
                                    labels = FALSE, include.lowest = TRUE)]
    
    # Get never-treated pairs
    never_treated <- pair_rta[classification == "never_treated"]
    
    # Unmatched placebo assignment (for comparison)
    placebo_unmatched <- rbindlist(lapply(never_treated$pair, function(p) {
        pair_data <- d[pair == p][order(year)]
        
        pos_years <- pair_data[trade > 0]$year
        if (length(pos_years) < min_consecutive) return(NULL)
        
        diffs <- diff(pos_years)
        run_starts <- c(1, which(diffs != 1) + 1)
        run_ends <- c(which(diffs != 1), length(pos_years))
        run_lengths <- run_ends - run_starts + 1
        
        max_run_idx <- which.max(run_lengths)
        if (run_lengths[max_run_idx] < min_consecutive) return(NULL)
        
        run_years <- pos_years[run_starts[max_run_idx]:run_ends[max_run_idx]]
        
        earliest <- run_years[1] + min_pre + anticipation_exclude
        latest <- run_years[length(run_years)] - min_post - anticipation_exclude
        
        if (earliest > latest) return(NULL)
        
        valid_years <- run_years[run_years >= earliest & run_years <= latest]
        if (length(valid_years) == 0) return(NULL)
        
        pseudo_adopt <- sample(valid_years, 1)
        
        # Compute pre-period trade for this placebo pair
        pre_trade <- sum(pair_data[year < pseudo_adopt - anticipation_exclude]$trade)
        
        return(data.table(
            pair = p,
            pseudo_adoption_year = pseudo_adopt,
            run_start = run_years[1],
            run_end = run_years[length(run_years)],
            run_length = length(run_years),
            pre_trade = pre_trade
        ))
    }))
    
    if (nrow(placebo_unmatched) == 0) {
        return(list(unmatched = NULL, matched = NULL))
    }
    
    # Assign deciles to placebo pairs based on real distribution
    breaks <- quantile(real_pre_trade$pre_trade, probs = 0:10/10, na.rm = TRUE)
    placebo_unmatched[, decile := cut(pre_trade, breaks = breaks, labels = FALSE, include.lowest = TRUE)]
    placebo_unmatched[is.na(decile), decile := 1]  # Handle edge cases
    
    # Matched sample: sample from each decile to match real distribution
    real_decile_counts <- real_pre_trade[, .N, by = decile]
    
    placebo_matched <- rbindlist(lapply(1:10, function(dec) {
        n_real <- real_decile_counts[decile == dec]$N
        if (length(n_real) == 0 || n_real == 0) return(NULL)
        
        available <- placebo_unmatched[decile == dec]
        if (nrow(available) == 0) return(NULL)
        
        n_sample <- min(n_real, nrow(available))
        available[sample(.N, n_sample)]
    }))
    
    return(list(
        unmatched = placebo_unmatched,
        matched = placebo_matched
    ))
}

# Legacy function (unmatched only)
assign_placebo <- function(d, pair_rta, 
                           min_pre = BASELINE$min_pre, 
                           min_post = BASELINE$min_post,
                           anticipation_exclude = BASELINE$anticipation_exclude,
                           min_consecutive = 8,
                           seed = GATES_SEED) {
    result <- assign_placebo_matched(d, pair_rta, 
                                      real_qualifying = data.table(pair = character(0)),
                                      min_pre = min_pre, min_post = min_post,
                                      anticipation_exclude = anticipation_exclude,
                                      min_consecutive = min_consecutive, seed = seed)
    return(result$unmatched)
}

# =============================================================================
# PLACEBO VALIDITY ASSERTION
# =============================================================================

assert_placebo_validity <- function(placebo_effects, threshold = PLACEBO_MEAN_THRESHOLD) {
    # HALT RULE: Assert |mean(θ̂_placebo)| < threshold
    # This is the pipeline's validity certificate
    
    mean_placebo <- mean(placebo_effects$theta_hat_B, na.rm = TRUE)
    
    cat(sprintf("\n=== PLACEBO VALIDITY CHECK ===\n"))
    cat(sprintf("Mean placebo θ̂_B: %.6f\n", mean_placebo))
    cat(sprintf("Threshold: |mean| < %.4f\n", threshold))
    
    if (abs(mean_placebo) >= threshold) {
        cat(sprintf("\n*** HALT: PLACEBO VALIDITY FAILED ***\n"))
        cat(sprintf("Placebo mean %.6f exceeds threshold %.4f\n", mean_placebo, threshold))
        stop(sprintf("Placebo validity assertion failed: |%.6f| >= %.4f", 
                     mean_placebo, threshold))
    }
    
    cat(sprintf("PASSED: |%.6f| < %.4f\n", abs(mean_placebo), threshold))
    invisible(TRUE)
}

# =============================================================================
# VARIANCE DECOMPOSITION
# =============================================================================

variance_decomposition <- function(theta_hat, se, trim_pct = 0) {
    if (trim_pct > 0) {
        lower <- quantile(theta_hat, trim_pct, na.rm = TRUE)
        upper <- quantile(theta_hat, 1 - trim_pct, na.rm = TRUE)
        keep <- theta_hat >= lower & theta_hat <= upper
        theta_hat <- theta_hat[keep]
        se <- se[keep]
    }
    
    var_theta_hat <- var(theta_hat, na.rm = TRUE)
    mean_se_sq <- mean(se^2, na.rm = TRUE)
    var_theta <- var_theta_hat - mean_se_sq
    
    sd_theta <- if (var_theta > 0) sqrt(var_theta) else 0
    reliability <- if (var_theta_hat > 0) var_theta / var_theta_hat else NA_real_
    
    return(list(
        var_theta_hat = var_theta_hat,
        mean_se_sq = mean_se_sq,
        var_theta = var_theta,
        sd_theta = sd_theta,
        reliability = reliability,
        n = sum(!is.na(theta_hat)),
        trim_pct = trim_pct
    ))
}

# =============================================================================
# BOOTSTRAP CI FOR SD(θ)
# =============================================================================

bootstrap_sd_theta_ci <- function(pair_effects, n_reps = 500, seed = GATES_SEED) {
    set.seed(seed)
    
    n_pairs <- nrow(pair_effects)
    
    boot_sd <- replicate(n_reps, {
        idx <- sample(n_pairs, replace = TRUE)
        boot_theta <- pair_effects$theta_hat_B[idx]
        boot_se <- pair_effects$se_B[idx]
        
        var_theta_hat <- var(boot_theta, na.rm = TRUE)
        mean_se_sq <- mean(boot_se^2, na.rm = TRUE)
        var_theta <- var_theta_hat - mean_se_sq
        
        if (var_theta > 0) sqrt(var_theta) else 0
    })
    
    # Point estimate
    var_theta_hat <- var(pair_effects$theta_hat_B, na.rm = TRUE)
    mean_se_sq <- mean(pair_effects$se_B^2, na.rm = TRUE)
    var_theta <- var_theta_hat - mean_se_sq
    sd_theta <- if (var_theta > 0) sqrt(var_theta) else 0
    
    return(list(
        sd_theta = sd_theta,
        se = sd(boot_sd, na.rm = TRUE),
        ci_lower = quantile(boot_sd, 0.025, na.rm = TRUE),
        ci_upper = quantile(boot_sd, 0.975, na.rm = TRUE)
    ))
}

# =============================================================================
# WITHIN-PAIR VARIANCE DECOMPOSITION
# =============================================================================

compute_within_pair_variance <- function(dt, y_col = "trade", y_hat_col = "y_hat_0",
                                         pair_col = "pair") {
    # Compute within-pair variance of log-ratio for each pair
    # Used for Jensen diagnosis and variance decomposition
    
    dt[, log_ratio := log(get(y_col)) - log(get(y_hat_col))]
    
    result <- dt[, .(
        v_ij = var(log_ratio, na.rm = TRUE),
        mean_log_ratio = mean(log_ratio, na.rm = TRUE),
        T_ij = .N
    ), by = pair_col]
    
    return(result)
}

# =============================================================================
# CONFIGURATION ECHO
# =============================================================================

print_config <- function(task_id, 
                         min_pre = BASELINE$min_pre,
                         min_post = BASELINE$min_post,
                         anticipation = BASELINE$anticipation_exclude,
                         adoption_range = BASELINE$adoption_range,
                         seed = GATES_SEED,
                         extra = list()) {
    cat("\n")
    cat("================================================================\n")
    cat(sprintf("CONFIGURATION ECHO — Task %s\n", task_id))
    cat("================================================================\n")
    cat(sprintf("Date: %s\n", Sys.time()))
    cat(sprintf("gates_lib.R version: %d\n", GATES_LIB_VERSION))
    cat(sprintf("Estimand: Definition B (Jensen-corrected)\n"))
    cat(sprintf("Data source: %s\n", DATA_SOURCE_PATH))
    cat(sprintf("Min pre-years: %d\n", min_pre))
    cat(sprintf("Min post-years: %d\n", min_post))
    cat(sprintf("Anticipation window: +/- %d years\n", anticipation))
    cat(sprintf("Adoption range: %d-%d\n", adoption_range[1], adoption_range[2]))
    cat(sprintf("Random seed: %d\n", seed))
    cat(sprintf("Placebo mean threshold: %.4f\n", PLACEBO_MEAN_THRESHOLD))
    
    if (length(extra) > 0) {
        cat("Additional parameters:\n")
        for (nm in names(extra)) {
            cat(sprintf("  %s: %s\n", nm, as.character(extra[[nm]])))
        }
    }
    cat("================================================================\n\n")
}

cat("gates_lib.R (v2) loaded successfully\n")
cat(sprintf("GATES_SEED = %d\n", GATES_SEED))
cat(sprintf("GATES_LIB_VERSION = %d\n", GATES_LIB_VERSION))
cat(sprintf("DATA_SOURCE_PATH = %s\n", DATA_SOURCE_PATH))
cat(sprintf("Estimand: Definition B (Jensen-corrected)\n"))
