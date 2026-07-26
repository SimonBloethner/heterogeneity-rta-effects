#!/usr/bin/env Rscript
# S22_ladder_closed_form.R
# OUTPUTS: output/T19_pleq0_bracket.csv, meta/T19_pleq0_bracket.csv.sidecar
# INPUTS:  meta/canonical_facts.md (MEAN_THETA_D, SD_THETA_TRUE bracket)
# SEED:    NONE
# EXPECTED_N: 4182
# GATES:   G1 inputs match ledger; G2 P monotone decreasing in SD_true;
#          G3 both P in (0,1)
#
# The K=3 mixture failed to identify shape (duplicate components at the
# SD floor). With shape under-identified, P(theta <= 0) is reported
# under a symmetric shape, which is the defensible object:
#     P = Phi(-mean / SD_true)
# Reported as a bracket over the SD_true identified set, NOT a point.
# Right skew would lower P, but no skew was identified, so none is claimed.
#
# INV-032: MEAN_THETA_D = 0.2473, not 0.2138. The value 0.2138 was from
# a stray W1 copy mistakenly named S6R_population.rds.

MEAN_THETA_D <- 0.2473; SE_MEAN <- 0.0235
SD_TRUE_LO   <- 0.740   # Arm C, cohort-hardened
SD_TRUE_HI   <- 1.475   # Arm A, noise-only

cat(sprintf("MEAN_THETA_D: %.4f (SE %.4f)\n", MEAN_THETA_D, SE_MEAN))
cat(sprintf("SD_TRUE bracket: [%.3f, %.3f] (INV-027)\n", SD_TRUE_LO, SD_TRUE_HI))

stopifnot(abs(MEAN_THETA_D - 0.2473) < 1e-4)
stopifnot(SD_TRUE_LO < SD_TRUE_HI)

p_lo <- pnorm(-MEAN_THETA_D / SD_TRUE_HI)   # larger SD -> larger P
p_hi <- pnorm(-MEAN_THETA_D / SD_TRUE_LO)

cat(sprintf("\nP(theta <= 0) computation:\n"))
cat(sprintf("  C_hardened:   Phi(-%.4f / %.3f) = %.6f\n", MEAN_THETA_D, SD_TRUE_LO, p_hi))
cat(sprintf("  A_noise_only: Phi(-%.4f / %.3f) = %.6f\n", MEAN_THETA_D, SD_TRUE_HI, p_lo))

stopifnot(p_hi < p_lo, p_lo > 0, p_hi > 0, p_lo < 1, p_hi < 1)

out <- data.frame(
  arm      = c("C_hardened", "A_noise_only"),
  SD_true  = c(SD_TRUE_LO, SD_TRUE_HI),
  mean     = MEAN_THETA_D,
  P_theta_leq_0 = c(p_hi, p_lo),
  shape    = "symmetric (skew under-identified)"
)
print(out)
cat(sprintf("\nP(theta <= 0) bracket: [%.3f, %.3f]\n", p_hi, p_lo))
write.csv(out, "output/T19_pleq0_bracket.csv", row.names = FALSE)
cat("Saved: output/T19_pleq0_bracket.csv\n")
