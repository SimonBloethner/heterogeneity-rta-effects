# N2: Placebo-Anchored Deconvolution
library(data.table)

set.seed(20260719)

cat("============================================================\n")
cat("N2: PLACEBO-ANCHORED DECONVOLUTION\n")
cat("============================================================\n\n")

load("/scratch/bt307958/N1_results.RData")

# Add trend terciles
slope_terciles <- quantile(real_slopes$slope, probs = 0:3/3, na.rm = TRUE)

real_slopes[, trend_tercile := cut(slope, breaks = slope_terciles,
    labels = c("Low", "Mid", "High"), include.lowest = TRUE)]

placebo_slopes[, trend_tercile := cut(slope, breaks = slope_terciles,
    labels = c("Low", "Mid", "High"), include.lowest = TRUE)]

# Create cells
real_slopes[, cell := paste(size_decile, trend_tercile, sep = "_")]
placebo_slopes[, cell := paste(size_decile, trend_tercile, sep = "_")]

# Match
cat("=== Matching Process ===\n\n")

matched_pairs <- data.table()

for (c in unique(real_slopes[!is.na(cell)]$cell)) {
    real_c <- real_slopes[cell == c & !is.na(theta_D)]
    plac_c <- placebo_slopes[cell == c & !is.na(theta_D)]
    
    if (nrow(plac_c) == 0 || nrow(real_c) == 0) next
    
    n_real <- nrow(real_c)
    n_plac <- nrow(plac_c)
    plac_idx <- sample(1:n_plac, n_real, replace = (n_real > n_plac))
    
    matched <- data.table(
        real_pair = real_c$pair,
        real_theta_D = real_c$theta_D,
        real_s_hat = real_c$s_hat,
        placebo_pair = plac_c$pair[plac_idx],
        placebo_theta_D = plac_c$theta_D[plac_idx],
        cell = c,
        size_decile = real_c$size_decile,
        trend_tercile = real_c$trend_tercile
    )
    
    matched_pairs <- rbind(matched_pairs, matched)
}

cat("Total matched pairs:", nrow(matched_pairs), "\n\n")

# Deconvolution
var_real <- var(matched_pairs$real_theta_D)
var_placebo <- var(matched_pairs$placebo_theta_D)
var_theta <- var_real - var_placebo

cat("Var(real):", round(var_real, 4), "\n")
cat("Var(placebo):", round(var_placebo, 4), "\n")
cat("Var(theta):", round(var_theta, 4), "\n")
cat("SD(theta):", round(sqrt(max(0, var_theta)), 4), "\n\n")

# Bootstrap CI
n_boot <- 500
boot_var <- numeric(n_boot)

for (b in 1:n_boot) {
    idx <- sample(1:nrow(matched_pairs), replace = TRUE)
    boot_var[b] <- var(matched_pairs$real_theta_D[idx]) - var(matched_pairs$placebo_theta_D[idx])
}

var_ci <- quantile(boot_var, c(0.025, 0.975))
sd_ci <- sqrt(pmax(0, var_ci))

cat("95% CI for SD(theta):", round(sd_ci[1], 4), "-", round(sd_ci[2], 4), "\n\n")

# Placebo pseudo-heterogeneity
sd_placebo_theta_D <- sd(matched_pairs$placebo_theta_D)
mean_s_hat <- mean(matched_pairs$real_s_hat, na.rm = TRUE)
drift_het <- sqrt(max(0, sd_placebo_theta_D^2 - mean_s_hat^2))

cat("SD(placebo theta_D):", round(sd_placebo_theta_D, 4), "\n")
cat("Mean(s_hat):", round(mean_s_hat, 4), "\n")
cat("Drift-het component:", round(drift_het, 4), "\n\n")

# Excluding bottom decile
matched_ex_d1 <- matched_pairs[size_decile != 1]
var_real_ex <- var(matched_ex_d1$real_theta_D)
var_placebo_ex <- var(matched_ex_d1$placebo_theta_D)
var_theta_ex <- var_real_ex - var_placebo_ex

boot_var_ex <- numeric(n_boot)
for (b in 1:n_boot) {
    idx <- sample(1:nrow(matched_ex_d1), replace = TRUE)
    boot_var_ex[b] <- var(matched_ex_d1$real_theta_D[idx]) - var(matched_ex_d1$placebo_theta_D[idx])
}
sd_ci_ex <- sqrt(pmax(0, quantile(boot_var_ex, c(0.025, 0.975))))

cat("Ex-D1: SD(theta) =", round(sqrt(max(0, var_theta_ex)), 4), "\n")

save(matched_pairs, matched_ex_d1, var_real, var_placebo, var_theta,
     var_ci, sd_ci, var_theta_ex, sd_ci_ex, sd_placebo_theta_D,
     mean_s_hat, drift_het, var_real_ex, var_placebo_ex,
     file = "/scratch/bt307958/N2_results.RData")

cat("\nSaved N2_results.RData\n")
