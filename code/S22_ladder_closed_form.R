#!/usr/bin/env Rscript
# S22_ladder_closed_form.R  (v2, capped)
# OUTPUTS: output/T19_pleq0_bracket.csv, meta/T19_pleq0_bracket.csv.sidecar
# INPUTS:  data/S5R_bhat.rds, output/T21_arms.csv
# SEED:    NONE
# EXPECTED_N: 4182
# GATES:   G1 n == 4182; G2 theta_D present; G3 mean matches ledger;
#          G4 normal form at the noise-only arm vs the raw share
#             (documents the normality violation, does not halt);
#          G5 reported bracket strictly ordered
#
# WHY THE CAP.  P(theta_true <= 0) needs a SHAPE, not just a mean and an
# SD. Shape is unidentified (INV-029: K=3 returned duplicate components
# at the SD floor, k=2 mean 0.190 sd 0.100, k=3 mean 0.213 sd 0.100).
# The normal form fills the gap by assumption, and the assumption is
# wrong in a known direction: the distribution is right-skewed, so a
# normal of the same SD must place the mass it cannot put in the right
# tail on the LEFT, fabricating downside.
# The observed share of non-positive ESTIMATES is an assumption-free
# upper bound: observed = true + noise, and noise moves mass into both
# tails, so deconvolution can only reduce the share. A normal-form value
# above that share is therefore inadmissible as an endpoint.
#
# INV-030 NOTE. theta_D does NOT exist in data/S6R_population.rds, which
# holds (pair, adoption_year, theta_A, theta_B, se_B, n_pre, n_post,
# pre_trade). theta_D = theta_B - b_hat is created in S5R and lives in
# data/S5R_bhat.rds$baseline. Earlier raw-share figures computed from a
# file named S6R_population.rds were reading a stray W1 copy, since
# renamed STRAY_W1_COPY_DO_NOT_USE.rds. This script reads S5R.

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(data.table))

EXPECTED_N  <- 4182
MEAN_LEDGER <- 0.2473

# Read SD_true values from T21_arms.csv (not hardcoded)
arms <- fread(file.path(RTA_ROOT, "output/T21_arms.csv"))
SD_TRUE_LO <- arms[arm == "C_OOS", SD_true]
SD_TRUE_HI <- arms[arm == "A_noise_only", SD_true]

# Values read from T21 - no hardcoded pins
cat(sprintf("SD_TRUE_LO = %.4f (from T21_arms.csv, arm C_OOS)\n", SD_TRUE_LO))
cat(sprintf("SD_TRUE_HI = %.4f (from T21_arms.csv, arm A_noise_only)\n", SD_TRUE_HI))

S5R  <- readRDS(file.path(RTA_ROOT, "data/S5R_bhat.rds"))
base <- as.data.table(S5R$baseline)

stopifnot(nrow(base) == EXPECTED_N)
stopifnot("theta_D" %in% names(base))

MEAN_THETA_D <- mean(base$theta_D, na.rm = TRUE)
SD_THETA_D   <- sd(base$theta_D,   na.rm = TRUE)
SE_MEAN      <- SD_THETA_D / sqrt(EXPECTED_N)
stopifnot(abs(MEAN_THETA_D - MEAN_LEDGER) < 5e-4)

n_ok      <- sum(!is.na(base$theta_D))
RAW_SHARE <- sum(base$theta_D <= 0, na.rm = TRUE) / n_ok

p_norm_lo <- pnorm(-MEAN_THETA_D / SD_TRUE_LO)
p_norm_hi <- pnorm(-MEAN_THETA_D / SD_TRUE_HI)

violation <- p_norm_hi > RAW_SHARE
cat(sprintf("G4 normal form at noise-only arm %.4f vs raw share %.4f : %s\n",
            p_norm_hi, RAW_SHARE,
            ifelse(violation, "EXCEEDS (normality overstates left tail)",
                              "within bound")))

P_LO <- p_norm_lo
P_HI <- min(p_norm_hi, RAW_SHARE)

# If this halts, the bracket is incoherent: the raw share sits below the
# hardened-arm normal form, meaning normality overstates the left tail at
# BOTH arms. Report the halt; do not adjust SD_TRUE_LO to rescue it.
stopifnot(P_LO < P_HI, P_LO > 0, P_HI < 1)

out <- data.frame(
  arm            = c("C_hardened", "A_noise_only"),
  SD_true        = c(SD_TRUE_LO, SD_TRUE_HI),
  mean           = MEAN_THETA_D,
  P_normal_form  = c(p_norm_lo, p_norm_hi),
  P_reported     = c(P_LO, P_HI),
  basis          = c("normal form (shape unidentified)",
                     ifelse(violation,
                            "capped at empirical share of non-positive estimates",
                            "normal form (shape unidentified)")),
  raw_share      = RAW_SHARE
)
print(out)
cat(sprintf("\nRAW_SHARE = %.4f (n = %d, from S5R_bhat.rds$baseline)\n",
            RAW_SHARE, n_ok))
cat(sprintf("P(theta <= 0) reported bracket: [%.3f, %.3f]\n", P_LO, P_HI))

write.csv(out, file.path(RTA_ROOT, "output/T19_pleq0_bracket.csv"), row.names = FALSE)
