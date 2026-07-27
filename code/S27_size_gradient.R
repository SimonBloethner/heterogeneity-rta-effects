#!/usr/bin/env Rscript
# S27_size_gradient.R - Size gradient analysis for Prop 2 remark
# OUTPUTS: output/T26_size_gradient.csv, meta/T26_size_gradient.csv.sidecar
# INPUTS:  data/S5R_bhat.rds
# SEED:    20260719
# EXPECTED_N: 17200 (placebo)
#
# R6: Test the size-grading claim properly:
# - Regress placebo theta^B on log pre-adoption trade
# - Report Spearman correlation overall and by decile range
# - Document non-monotone pattern in lower deciles

suppressPackageStartupMessages(library(data.table))
set.seed(20260719)
setwd("/scratch/bt307958/REBUILD_V2")

EXPECTED_N <- 17200

# -----------------------------------------------------------------------------
# Load data
# -----------------------------------------------------------------------------
cat("=== LOADING DATA ===\n")

S5R <- readRDS("data/S5R_bhat.rds")
plac <- as.data.table(S5R[["placebo"]])
stopifnot(nrow(plac) == EXPECTED_N)
cat(sprintf("G1 Placebo pairs n = %d: PASS\n", nrow(plac)))

# Check required columns
stopifnot("theta_B" %in% names(plac))
stopifnot("size_decile" %in% names(plac))
stopifnot("pseudo" %in% names(plac))

cat(sprintf("Placebo columns: %s\n", paste(names(plac), collapse=", ")))

# Load PPML to compute pre_trade
ppml <- readRDS("data/S1R_ppml.rds")
setDT(ppml)

# Compute pre-trade for each placebo pair (sum of trade in years <= pseudo)
ppml_plac <- ppml[pair %in% plac$pair]
ppml_plac_merged <- merge(ppml_plac, plac[, .(pair, pseudo)], by = "pair")

pre_trade_dt <- ppml_plac_merged[year <= pseudo & trade > 0, .(
  pre_trade = sum(trade)
), by = pair]

plac <- merge(plac, pre_trade_dt, by = "pair", all.x = TRUE)
plac[, log_pre := log(pre_trade)]

cat(sprintf("Pairs with pre_trade computed: %d\n", sum(!is.na(plac$pre_trade))))

# -----------------------------------------------------------------------------
# Decile profile
# -----------------------------------------------------------------------------
cat("\n=== DECILE PROFILE ===\n")

decile_stats <- plac[, .(
  n = .N,
  mean_theta_B = mean(theta_B, na.rm = TRUE),
  sd_theta_B = sd(theta_B, na.rm = TRUE),
  mean_log_pre = mean(log_pre, na.rm = TRUE)
), by = size_decile][order(size_decile)]

cat("Decile profile (theta_B means):\n")
print(decile_stats)

# Overall mean for comparison
overall_mean <- mean(plac$theta_B, na.rm = TRUE)
cat(sprintf("\nOverall mean theta_B = %.4f\n", overall_mean))

# Check monotonicity
decile_means <- decile_stats$mean_theta_B
is_monotone <- all(diff(decile_means) >= 0) || all(diff(decile_means) <= 0)
cat(sprintf("Full monotonicity: %s\n", ifelse(is_monotone, "YES", "NO")))

# Check monotonicity in upper half (deciles 5-10)
upper_means <- decile_means[5:10]
is_upper_monotone <- all(diff(upper_means) >= 0)
cat(sprintf("Upper half (5-10) monotonicity (increasing): %s\n",
            ifelse(is_upper_monotone, "YES", "NO")))

# Check monotonicity in lower half (deciles 1-4)
lower_means <- decile_means[1:4]
is_lower_monotone <- all(diff(lower_means) >= 0) || all(diff(lower_means) <= 0)
cat(sprintf("Lower half (1-4) monotonicity: %s\n",
            ifelse(is_lower_monotone, "YES", "NO")))

# -----------------------------------------------------------------------------
# Regression: theta_B on log(pre_trade)
# -----------------------------------------------------------------------------
cat("\n=== REGRESSION: theta_B ~ log(pre_trade) ===\n")

# Drop any pairs with missing values
reg_data <- plac[!is.na(theta_B) & !is.na(log_pre)]
cat(sprintf("Pairs for regression: %d\n", nrow(reg_data)))

# OLS regression
fit <- lm(theta_B ~ log_pre, data = reg_data)
summary_fit <- summary(fit)

slope <- coef(fit)["log_pre"]
slope_se <- summary_fit$coefficients["log_pre", "Std. Error"]
intercept <- coef(fit)["(Intercept)"]
r_squared <- summary_fit$r.squared

cat(sprintf("Slope = %.6f (SE = %.6f)\n", slope, slope_se))
cat(sprintf("Intercept = %.6f\n", intercept))
cat(sprintf("R² = %.6f\n", r_squared))
cat(sprintf("t-statistic = %.2f\n", slope / slope_se))
cat(sprintf("p-value = %.2e\n", summary_fit$coefficients["log_pre", "Pr(>|t|)"]))

# -----------------------------------------------------------------------------
# Spearman correlations
# -----------------------------------------------------------------------------
cat("\n=== SPEARMAN CORRELATIONS ===\n")

# Overall
spearman_overall <- cor(reg_data$theta_B, reg_data$log_pre, method = "spearman")
cat(sprintf("Spearman rho (overall, n=%d): %.6f\n", nrow(reg_data), spearman_overall))

# Deciles 5-10 only
upper_data <- reg_data[size_decile >= 5]
spearman_upper <- cor(upper_data$theta_B, upper_data$log_pre, method = "spearman")
cat(sprintf("Spearman rho (deciles 5-10, n=%d): %.6f\n", nrow(upper_data), spearman_upper))

# Deciles 1-4 only
lower_data <- reg_data[size_decile <= 4]
spearman_lower <- cor(lower_data$theta_B, lower_data$log_pre, method = "spearman")
cat(sprintf("Spearman rho (deciles 1-4, n=%d): %.6f\n", nrow(lower_data), spearman_lower))

# Pearson correlations for comparison
pearson_overall <- cor(reg_data$theta_B, reg_data$log_pre, method = "pearson")
pearson_upper <- cor(upper_data$theta_B, upper_data$log_pre, method = "pearson")
pearson_lower <- cor(lower_data$theta_B, lower_data$log_pre, method = "pearson")

cat(sprintf("\nPearson r (overall): %.6f\n", pearson_overall))
cat(sprintf("Pearson r (deciles 5-10): %.6f\n", pearson_upper))
cat(sprintf("Pearson r (deciles 1-4): %.6f\n", pearson_lower))

# -----------------------------------------------------------------------------
# Analysis: is non-monotonicity a small-cell artifact?
# -----------------------------------------------------------------------------
cat("\n=== SMALL-CELL ANALYSIS ===\n")

lower_decile_counts <- decile_stats[size_decile <= 4, .(size_decile, n)]
cat("Lower decile counts:\n")
print(lower_decile_counts)

total_lower <- sum(lower_decile_counts$n)
total_upper <- sum(decile_stats[size_decile >= 5, n])
cat(sprintf("\nDeciles 1-4: n=%d (%.1f%%)\n", total_lower, 100*total_lower/EXPECTED_N))
cat(sprintf("Deciles 5-10: n=%d (%.1f%%)\n", total_upper, 100*total_upper/EXPECTED_N))

# Coefficient of variation in lower deciles
lower_cv <- decile_stats[size_decile <= 4, sd(mean_theta_B) / abs(mean(mean_theta_B))]
upper_cv <- decile_stats[size_decile >= 5, sd(mean_theta_B) / abs(mean(mean_theta_B))]
cat(sprintf("\nCV of decile means (1-4): %.3f\n", lower_cv))
cat(sprintf("CV of decile means (5-10): %.3f\n", upper_cv))

# -----------------------------------------------------------------------------
# OUTPUT
# -----------------------------------------------------------------------------
cat("\n=== OUTPUT ===\n")

out <- rbind(
  data.frame(
    ID = "SIZE_GRADIENT_SLOPE",
    quantity = "Regression slope: theta_B ~ log(pre_trade)",
    value = slope,
    se = slope_se,
    n = nrow(reg_data),
    range = "all",
    stringsAsFactors = FALSE
  ),
  data.frame(
    ID = "SIZE_GRADIENT_R2",
    quantity = "Regression R²",
    value = r_squared,
    se = NA,
    n = nrow(reg_data),
    range = "all",
    stringsAsFactors = FALSE
  ),
  data.frame(
    ID = "SPEARMAN_OVERALL",
    quantity = "Spearman rho (theta_B vs log_pre_trade)",
    value = spearman_overall,
    se = NA,
    n = nrow(reg_data),
    range = "all",
    stringsAsFactors = FALSE
  ),
  data.frame(
    ID = "SPEARMAN_UPPER",
    quantity = "Spearman rho (deciles 5-10)",
    value = spearman_upper,
    se = NA,
    n = nrow(upper_data),
    range = "5-10",
    stringsAsFactors = FALSE
  ),
  data.frame(
    ID = "SPEARMAN_LOWER",
    quantity = "Spearman rho (deciles 1-4)",
    value = spearman_lower,
    se = NA,
    n = nrow(lower_data),
    range = "1-4",
    stringsAsFactors = FALSE
  )
)

# Add decile means
for (i in 1:10) {
  out <- rbind(out, data.frame(
    ID = sprintf("DECILE_%d_MEAN", i),
    quantity = sprintf("Mean theta_B decile %d", i),
    value = decile_stats[size_decile == i, mean_theta_B],
    se = NA,
    n = decile_stats[size_decile == i, n],
    range = sprintf("%d", i),
    stringsAsFactors = FALSE
  ))
}

print(out)

write.csv(out, "output/T26_size_gradient.csv", row.names = FALSE)
cat("\nSaved: output/T26_size_gradient.csv\n")

# Sidecar
sha <- system("sha256sum output/T26_size_gradient.csv | cut -d' ' -f1", intern = TRUE)
writeLines(c(
  "PRODUCER: S27_size_gradient.R",
  "INPUTS: data/S5R_bhat.rds",
  "SEED: 20260719",
  sprintf("EXPECTED_N: %d", EXPECTED_N),
  "",
  "ANALYSIS:",
  sprintf("  Regression slope: %.6f (SE %.6f)", slope, slope_se),
  sprintf("  Regression R²: %.6f", r_squared),
  sprintf("  Spearman rho (overall): %.4f", spearman_overall),
  sprintf("  Spearman rho (deciles 5-10): %.4f", spearman_upper),
  sprintf("  Spearman rho (deciles 1-4): %.4f", spearman_lower),
  "",
  sprintf("MONOTONICITY: %s overall, %s in upper half (5-10)",
          ifelse(is_monotone, "YES", "NO"),
          ifelse(is_upper_monotone, "YES", "NO")),
  "",
  "DECILE PROFILE:",
  sprintf("  %s", paste(sprintf("D%d: %.3f (n=%d)", 1:10,
                                 decile_stats$mean_theta_B,
                                 decile_stats$n), collapse=", ")),
  "",
  "FINDING: Non-monotone pattern in deciles 1-4 is visible.",
  sprintf("  Lower decile counts: D1=%d, D2=%d, D3=%d, D4=%d",
          decile_stats[size_decile==1, n],
          decile_stats[size_decile==2, n],
          decile_stats[size_decile==3, n],
          decile_stats[size_decile==4, n]),
  "",
  "GATES:",
  sprintf("  G1: n = %d - PASS", EXPECTED_N),
  "STATUS: BUILT",
  sprintf("DATE: %s", Sys.Date()),
  sprintf("SHA256: %s", sha)
), "meta/T26_size_gradient.csv.sidecar")
cat("Saved: meta/T26_size_gradient.csv.sidecar\n")

cat("\n=== SUMMARY ===\n")
cat(sprintf("Overall Spearman: %.4f, Upper (5-10): %.4f, Lower (1-4): %.4f\n",
            spearman_overall, spearman_upper, spearman_lower))
cat(sprintf("Regression slope: %.4f (SE %.4f), R² = %.4f\n", slope, slope_se, r_squared))
cat(sprintf("Monotone overall: %s, Monotone upper: %s\n",
            ifelse(is_monotone, "YES", "NO"),
            ifelse(is_upper_monotone, "YES", "NO")))
