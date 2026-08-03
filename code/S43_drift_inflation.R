# S43_drift_inflation.R — Gate drift-inflation arithmetic from INV-041
#
# Verifies that the level-route and slope-route derivations of the drift
# inflation factor agree, and that the Control C disattenuation recovers
# the true -0.5 slope.
#
# Inputs:
#   output/T39_a2_jensen_identity.csv  (per-pair mean_log_eta, var_log_eta)
#   output/T40_jensen_control.csv      (panel-level slopes and reliability)
#
# Output:
#   output/T41_drift_inflation.csv
#
# Gates:
#   B1: |w_level - w_slope| / w_level < 0.05  (relative agreement)
#   B2: |disatt_slope_ctrlc + 0.5| < 0.10     (control recovers -0.5)
#   B3: |predicted - observed| < 0.01         (slope prediction)

library(data.table)

cat("========================================\n")
cat("S43_drift_inflation.R\n")
cat("========================================\n\n")

# =============================================================================
# 1. READ INPUTS
# =============================================================================

T39 <- fread("output/T39_a2_jensen_identity.csv")
T40 <- fread("output/T40_jensen_control.csv")

cat("T39 loaded:", nrow(T39), "rows\n")
cat("T40 loaded:", nrow(T40), "rows\n\n")

# T39 has panel column with values "real" and "normal" (control)
# Filter to real panel only
T39_real <- T39[panel == "real"]
n_real <- nrow(T39_real)
cat("T39 real panel pairs:", n_real, "\n")
stopifnot(n_real == 27782 || n_real == 27783)  # Accept either count

# T40 has panel column with "real", "normal", "ctrlc"
T40_real <- T40[panel == "real"]
T40_ctrlc <- T40[panel == "control_c"]

stopifnot(nrow(T40_real) == 1)
stopifnot(nrow(T40_ctrlc) == 1)

# =============================================================================
# 2. LEVEL-ROUTE CALCULATION
# =============================================================================

# Under (A2): E[mean_i] = -E[sigma^2]/2, so E[var] should equal -2*E[mean]
# With drift: E[var_i] = E[sigma^2] + drift, so E[var] = -2*E[mean] + drift
# => w_level = E[var] / (-2 * E[mean]) = 1 + drift/E[sigma^2]

E_mean <- mean(T39_real$mean_log_eta)
E_var <- mean(T39_real$var_log_eta)

cat("\n--- Level-route ---\n")
cat("E[mean_i] =", round(E_mean, 4), "\n")
cat("E[var_i] =", round(E_var, 4), "\n")

# Under (A2), these should satisfy: E[var] = -2 * E[mean]
# The ratio gives the inflation factor
w_level <- E_var / (-2 * E_mean)
cat("w_level = E[var] / (-2 * E[mean]) =", round(w_level, 4), "\n")

# =============================================================================
# 3. SLOPE-ROUTE CALCULATION
# =============================================================================

cat("\n--- Slope-route ---\n")

# Real panel slope and reliability
slope_real <- T40_real$slope
var_rel_real <- T40_real$var_reliability

cat("slope_real =", round(slope_real, 4), "\n")
cat("var_reliability_real =", round(var_rel_real, 4), "\n")

# Disattenuated slope
disatt_slope_real <- slope_real / var_rel_real
cat("disatt_slope_real =", round(disatt_slope_real, 4), "\n")

# Under (A2) with drift: var_i = sigma^2_i * w where w = 1 + drift/sigma^2
# The slope of mean on var should be -0.5/w (since mean = -sigma^2/2 = -var/(2w))
# So w = -0.5 / disatt_slope
w_slope <- -0.5 / disatt_slope_real
cat("w_slope = 0.5 / |disatt_slope| =", round(w_slope, 4), "\n")

# =============================================================================
# 4. CONTROL C VERIFICATION
# =============================================================================

cat("\n--- Control C verification ---\n")

slope_ctrlc <- T40_ctrlc$slope
var_rel_ctrlc <- T40_ctrlc$var_reliability

cat("slope_ctrlc =", round(slope_ctrlc, 4), "\n")
cat("var_reliability_ctrlc =", round(var_rel_ctrlc, 4), "\n")

disatt_slope_ctrlc <- slope_ctrlc / var_rel_ctrlc
cat("disatt_slope_ctrlc =", round(disatt_slope_ctrlc, 4), "\n")

# Control C has the identity imposed exactly, so disatt_slope should be -0.5
deviation_ctrlc <- disatt_slope_ctrlc - (-0.5)
cat("Deviation from -0.5:", round(deviation_ctrlc, 4), "\n")

# =============================================================================
# 5. PREDICTED SLOPE
# =============================================================================

cat("\n--- Slope prediction ---\n")

# At w_level, the predicted slope is -0.5/w_level
predicted_slope <- -0.5 / w_level
cat("Predicted slope at w_level:", round(predicted_slope, 4), "\n")
cat("Observed disatt_slope_real:", round(disatt_slope_real, 4), "\n")
slope_prediction_error <- predicted_slope - disatt_slope_real
cat("Prediction error:", round(slope_prediction_error, 4), "\n")

# =============================================================================
# 6. GATES
# =============================================================================

cat("\n========================================\n")
cat("GATES\n")
cat("========================================\n")

# B1: relative agreement of w_level and w_slope
rel_diff <- abs(w_level - w_slope) / w_level
cat("B1: |w_level - w_slope| / w_level =", round(rel_diff, 4), "< 0.05?", rel_diff < 0.05, "\n")
if (rel_diff < 0.05) {
  cat("  B1 PASS\n")
} else {
  stop("B1 FAIL: relative diff ", rel_diff, " >= 0.05")
}

# B2: control C recovers -0.5
cat("B2: |disatt_slope_ctrlc + 0.5| =", round(abs(deviation_ctrlc), 4), "< 0.10?", abs(deviation_ctrlc) < 0.10, "\n")
if (abs(deviation_ctrlc) < 0.10) {
  cat("  B2 PASS\n")
} else {
  stop("B2 FAIL: deviation ", deviation_ctrlc, " >= 0.10")
}

# B3: slope prediction
cat("B3: |predicted - observed| =", round(abs(slope_prediction_error), 4), "< 0.01?", abs(slope_prediction_error) < 0.01, "\n")
if (abs(slope_prediction_error) < 0.01) {
  cat("  B3 PASS\n")
} else {
  stop("B3 FAIL: prediction error ", slope_prediction_error, " >= 0.01")
}

# =============================================================================
# 7. OUTPUT
# =============================================================================

out <- data.table(
  quantity = c(
    "E_mean", "E_var", "w_level",
    "slope_real", "var_reliability_real", "disatt_slope_real", "w_slope",
    "slope_ctrlc", "var_reliability_ctrlc", "disatt_slope_ctrlc",
    "predicted_slope", "slope_prediction_error",
    "B1_rel_diff", "B2_deviation", "B3_error"
  ),
  value = c(
    E_mean, E_var, w_level,
    slope_real, var_rel_real, disatt_slope_real, w_slope,
    slope_ctrlc, var_rel_ctrlc, disatt_slope_ctrlc,
    predicted_slope, slope_prediction_error,
    rel_diff, deviation_ctrlc, slope_prediction_error
  ),
  pass = c(
    NA, NA, NA,
    NA, NA, NA, NA,
    NA, NA, NA,
    NA, NA,
    rel_diff < 0.05, abs(deviation_ctrlc) < 0.10, abs(slope_prediction_error) < 0.01
  )
)

fwrite(out, "output/T41_drift_inflation.csv")
cat("\nWritten: output/T41_drift_inflation.csv\n")

cat("\n========================================\n")
cat("S43_drift_inflation.R COMPLETE\n")
cat("========================================\n")
