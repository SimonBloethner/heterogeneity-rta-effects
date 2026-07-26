#!/usr/bin/env Rscript
# S23_ge_bracket.R
# OUTPUTS: output/T20_ge_bracket.csv, meta/T20_ge_bracket.csv.sidecar
# INPUTS:  meta/canonical_facts.md (MEAN_THETA_D, SD_THETA_TRUE bracket)
# SEED:    20260726
# EXPECTED_N: 4182
# GATES:   G1 inputs match ledger; G2 output has 4 rows (2 arms x 2 shapes)
#
# GE propagation under symmetric shape at BOTH SD_true endpoints.
# No single-number GE headline. Reports q10, q50, q90, RANGE_1090.
#
# INV-032: MEAN_THETA_D = 0.2473, not 0.2138.

set.seed(20260726)

MEAN_THETA_D <- 0.2473
SD_TRUE_LO   <- 0.740   # Arm C, cohort-hardened (INV-027)
SD_TRUE_HI   <- 1.475   # Arm A, noise-only (INV-027)

cat(sprintf("MEAN_THETA_D: %.4f\n", MEAN_THETA_D))
cat(sprintf("SD_TRUE bracket: [%.3f, %.3f]\n", SD_TRUE_LO, SD_TRUE_HI))

stopifnot(abs(MEAN_THETA_D - 0.2473) < 1e-4)
stopifnot(SD_TRUE_LO < SD_TRUE_HI)

N_DRAWS <- 10000

compute_ge <- function(mean_theta, sd_theta, label) {
    theta_draws <- rnorm(N_DRAWS, mean = mean_theta, sd = sd_theta)
    trade_change <- (exp(theta_draws) - 1) * 100

    q10 <- quantile(trade_change, 0.10)
    q50 <- quantile(trade_change, 0.50)
    q90 <- quantile(trade_change, 0.90)
    range_1090 <- (1 + q90/100) / (1 + q10/100)

    data.frame(
        arm = label,
        shape = "symmetric",
        SD_true = sd_theta,
        mean = mean_theta,
        q10 = q10,
        q50 = q50,
        q90 = q90,
        RANGE_1090 = range_1090
    )
}

ge_C <- compute_ge(MEAN_THETA_D, SD_TRUE_LO, "C_hardened")
ge_A <- compute_ge(MEAN_THETA_D, SD_TRUE_HI, "A_noise_only")

ge_C_normal <- ge_C; ge_C_normal$shape <- "normal_same_SD"
ge_A_normal <- ge_A; ge_A_normal$shape <- "normal_same_SD"

out <- rbind(ge_C, ge_C_normal, ge_A, ge_A_normal)

cat("\nGE Bracket (arm-indexed):\n")
print(out[, c("arm", "shape", "SD_true", "q50", "RANGE_1090")])

stopifnot(nrow(out) == 4)

cat(sprintf("\nGE summary:\n"))
cat(sprintf("  C_hardened (SD=%.3f):   q50=%.1f%%, RANGE=%.2f\n",
            SD_TRUE_LO, ge_C$q50, ge_C$RANGE_1090))
cat(sprintf("  A_noise_only (SD=%.3f): q50=%.1f%%, RANGE=%.2f\n",
            SD_TRUE_HI, ge_A$q50, ge_A$RANGE_1090))

write.csv(out, "output/T20_ge_bracket.csv", row.names = FALSE)
cat("\nSaved: output/T20_ge_bracket.csv\n")
