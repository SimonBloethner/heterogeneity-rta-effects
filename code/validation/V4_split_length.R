#!/usr/bin/env Rscript
# =============================================================================
# V4_split_length.R - Split-Length Sensitivity Analysis (S1-S4)
# =============================================================================
# OUTPUT:  output/V4_split_length.csv
# INPUTS:  data/S1R_ppml.rds, data/S5R_bhat.rds
# PURPOSE: Document split-length bias in pseudo null
#          S1: Variance by split fraction (0.5, 0.6, 0.7, 0.8)
#          S2: Regression of variance on n_early
#          S3: Extrapolation to full pre-period
#          S4: Cohort ratio extrapolation
# NOTE:    INV-027 - variance discrepancy between this and S18
# =============================================================================

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(dplyr))

SEED <- 20260719
set.seed(SEED)

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(file.path(RTA_ROOT, p)), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("V4: SPLIT-LENGTH SENSITIVITY (S1-S4)")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load data
S1R <- readRDS(file.path(RTA_ROOT, "data/S1R_ppml.rds"))
S5R <- readRDS(file.path(RTA_ROOT, "data/S5R_bhat.rds"))
baseline <- S5R$baseline

# Identify switcher pairs
switcher_info <- S1R %>%
    filter(!is.na(adoption_year)) %>%
    select(pair, adoption_year) %>%
    distinct()

# Pre-period cells
pre_cells <- S1R %>%
    filter(pair %in% switcher_info$pair, rta == 0, trade > 0) %>%
    select(pair, year, trade, y_hat_0) %>%
    inner_join(switcher_info, by = "pair")

# Pair pre-period stats
pair_pre <- pre_cells %>%
    group_by(pair, adoption_year) %>%
    summarise(
        min_year = min(year),
        max_year = max(year),
        n_pre = n(),
        .groups = "drop"
    )

say("Pairs with pre-periods: %d", nrow(pair_pre))

# =============================================================================
# S1: VARIANCE BY SPLIT FRACTION
# =============================================================================
say("")
say("=== S1: VARIANCE BY SPLIT FRACTION ===")

compute_pseudo_at_split <- function(split_frac) {
    pp <- pair_pre %>%
        mutate(
            split_year = min_year + floor((max_year - min_year) * split_frac),
            n_early = split_year - min_year + 1,
            n_late = max_year - split_year
        ) %>%
        filter(n_early >= 2, n_late >= 2)

    late_cells <- pre_cells %>%
        inner_join(pp %>% select(pair, split_year), by = "pair") %>%
        filter(year > split_year, y_hat_0 > 0)

    pseudo <- late_cells %>%
        group_by(pair) %>%
        summarise(
            n_late = n(),
            pseudo_theta_B = log(sum(trade) / sum(y_hat_0)),
            .groups = "drop"
        ) %>%
        inner_join(pp %>% select(pair, n_early, n_pre), by = "pair") %>%
        mutate(horizon_bin = case_when(
            n_late <= 3 ~ "2-3",
            n_late <= 5 ~ "4-5",
            n_late <= 10 ~ "6-10",
            TRUE ~ "11+"
        ))

    # b_hat correction
    mean_bhat <- mean(baseline$theta_B - baseline$theta_D)
    pseudo$pseudo_theta_D <- pseudo$pseudo_theta_B - mean_bhat

    list(split_frac = split_frac, n_pairs = nrow(pseudo),
         mean_n_early = mean(pseudo$n_early), pseudo = pseudo)
}

splits <- c(0.5, 0.6, 0.7, 0.8)
results_list <- lapply(splits, compute_pseudo_at_split)

# Aggregate variance by split and bin
agg_var <- bind_rows(lapply(results_list, function(r) {
    r$pseudo %>%
        group_by(horizon_bin) %>%
        summarise(
            n = n(),
            var_pseudo_D = var(pseudo_theta_D, na.rm = TRUE),
            mean_n_early = mean(n_early),
            .groups = "drop"
        ) %>%
        mutate(split_frac = r$split_frac)
}))

say("")
print(as.data.frame(agg_var %>% arrange(horizon_bin, split_frac)))

# =============================================================================
# S2: REGRESSION
# =============================================================================
say("")
say("=== S2: REGRESSION ===")

fit <- lm(var_pseudo_D ~ mean_n_early, data = agg_var, weights = n)
say("var ~ mean_n_early")
say("Intercept:    %.4f (SE: %.4f)", coef(fit)[1], summary(fit)$coef[1,2])
say("mean_n_early: %.4f (SE: %.4f)", coef(fit)[2], summary(fit)$coef[2,2])
say("R-squared: %.3f", summary(fit)$r.squared)

beta_early <- coef(fit)[2]
se_early <- summary(fit)$coef[2,2]

# =============================================================================
# S3: EXTRAPOLATION
# =============================================================================
say("")
say("=== S3: EXTRAPOLATION ===")

# At split=0.5, get variance by bin
var_split5 <- agg_var %>%
    filter(split_frac == 0.5) %>%
    select(horizon_bin, var_pseudo_D, mean_n_early)

# Get treated mean n_pre by bin
adopt_lookup <- baseline %>% select(pair, adopt_yr = adoption_year) %>% distinct()
treated_stats <- S1R %>%
    filter(pair %in% baseline$pair) %>%
    inner_join(adopt_lookup, by = "pair") %>%
    group_by(pair) %>%
    summarise(
        n_pre = sum(rta == 0 & trade > 0),
        n_post_sym = sum(rta == 1 & trade > 0 & year > adopt_yr + 1),
        .groups = "drop"
    ) %>%
    mutate(horizon_bin = case_when(
        n_post_sym <= 3 ~ "2-3",
        n_post_sym <= 5 ~ "4-5",
        n_post_sym <= 10 ~ "6-10",
        TRUE ~ "11+"
    )) %>%
    group_by(horizon_bin) %>%
    summarise(mean_n_pre = mean(n_pre), .groups = "drop")

# Extrapolate: var_treated = var_pseudo + beta * (n_pre - n_early)
extrap <- var_split5 %>%
    left_join(treated_stats, by = "horizon_bin") %>%
    mutate(
        delta_n = mean_n_pre - mean_n_early,
        var_extrap = pmax(0.01, var_pseudo_D + beta_early * delta_n)
    )

say("")
print(as.data.frame(extrap))

# =============================================================================
# S4: COHORT RATIO EXTRAPOLATION
# =============================================================================
say("")
say("=== S4: COHORT RATIO EXTRAPOLATION ===")

# Cohort ratios from V3 (hardcoded from prior analysis)
cohort_ratios <- data.frame(
    horizon_bin = c("2-3", "4-5", "6-10"),
    ratio = c(0.67, 0.53, 0.47),
    horizon_mid = c(2.5, 4.5, 8)
)

fit_cohort <- lm(log(ratio) ~ horizon_mid, data = cohort_ratios)
say("Log-linear fit: log(ratio) ~ horizon_mid")
say("Intercept: %.4f", coef(fit_cohort)[1])
say("Slope: %.4f", coef(fit_cohort)[2])

# Extrapolate to 11+ (horizon ~ 15)
ratio_11plus <- exp(predict(fit_cohort, newdata = data.frame(horizon_mid = 15)))
say("")
say("Extrapolated ratio for 11+ (horizon=15): %.4f", ratio_11plus)

# =============================================================================
# INV-027: VARIANCE DISCREPANCY
# =============================================================================
say("")
say("=== INV-027a: IN-SAMPLE vs OOS NULL ===")

# V4 at split=0.5, 11+ bin (IN-SAMPLE: reuses S1R$y_hat_0)
var_11plus_V4 <- agg_var$var_pseudo_D[agg_var$split_frac == 0.5 & agg_var$horizon_bin == "11+"]
n_V4 <- sum(agg_var$n[agg_var$split_frac == 0.5])

# N1b value (OOS: refits PPML excluding LATE cells)
var_11plus_N1b <- 1.23  # From N1b OOS null (T12_N1b_horizon.csv)

say("")
say("V4 (in-sample, 11+ bin): Var = %.4f", var_11plus_V4)
say("N1b (OOS, 11+ bin):      Var = %.4f", var_11plus_N1b)
say("")
say("NOT A DISCREPANCY:")
say("  V4/S18: In-sample (reuses S1R$y_hat_0 fitted on LATE cells)")
say("  N1b:    OOS (refits PPML excluding LATE cells)")
say("")
say("INV-027a: CLOSED - Arm C uses N1b (OOS) variances")

# =============================================================================
# OUTPUT
# =============================================================================
say("")

output <- bind_rows(
    agg_var %>%
        mutate(item = paste0("var_", horizon_bin, "_split", split_frac * 100)) %>%
        select(item, value = var_pseudo_D),
    data.frame(
        item = c("beta_early", "se_early", "r_squared",
                 "ratio_11plus_extrap", "var_11plus_V4", "var_11plus_N1b"),
        value = c(beta_early, se_early, summary(fit)$r.squared,
                  ratio_11plus, var_11plus_V4, var_11plus_N1b)
    )
)

write.csv(output, file.path(RTA_ROOT, "output/V4_split_length.csv"), row.names = FALSE)

# Sidecar
code_sha <- get_sha256("code/validation/V4_split_length.R")
writeLines(c(
    "FILE:      V4_split_length.csv",
    sprintf("SHA256:    %s", get_sha256("output/V4_split_length.csv")),
    sprintf("PRODUCER:  code/validation/V4_split_length.R (SHA256: %s)", code_sha),
    "INPUTS:    data/S1R_ppml.rds, data/S5R_bhat.rds",
    sprintf("SEED:      %d", SEED),
    "",
    "S2: REGRESSION",
    sprintf("  beta_early: %.4f (SE: %.4f)", beta_early, se_early),
    "",
    "S4: COHORT EXTRAPOLATION",
    sprintf("  Extrapolated 11+ ratio: %.4f", ratio_11plus),
    "",
    "INV-027a: IN-SAMPLE vs OOS NULL (CLOSED)",
    sprintf("  V4 (in-sample, 11+ bin): %.4f", var_11plus_V4),
    sprintf("  N1b (OOS, 11+ bin):      %.4f", var_11plus_N1b),
    "  V4/S18 measure in-sample null (reuses S1R$y_hat_0)",
    "  N1b measures OOS null (refits excluding LATE cells)",
    "  Arm C uses N1b. No discrepancy.",
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/V4_split_length.csv.sidecar"))

say("")
say("Wrote output/V4_split_length.csv")
say("Done: %s", format(Sys.time()))
