# T3 — Variance Identity (by hand)
# Test if dispersion activation = revealed heterogeneity

library(data.table)
library(fixest)

cat("=== T3: Variance Identity ===\n\n")

# Load T2 canonical population
T2 <- readRDS("/scratch/bt307958/T2_results.rds")
theta_canonical <- readRDS("/scratch/bt307958/T2_canonical_theta.rds")

cat(sprintf("Canonical population: %d pairs\n", T2$n_intersection))

# Load main data
main <- readRDS("/scratch/bt307958/N0_data.rds")
setDT(main)

# Filter to canonical pairs
main_can <- main[pair %in% T2$canonical_pairs]
cat(sprintf("Canonical observations: %d\n", nrow(main_can)))

# ============================================================
# FIT BASE MODEL FOR RESIDUALS
# ============================================================
cat("\n========== BASE MODEL ==========\n\n")

# Fit PPML on full data to get residuals (matching paper's approach)
cat("Fitting PPML on full panel...\n")
fit <- fepois(trade ~ rta | pair + exp_year + imp_year, data = main, 
              glm.iter = 100, glm.tol = 1e-10)

# Get fitted values
main[, yhat := fitted(fit)]
main[, r_raw := trade - yhat]
main[, r_pearson := r_raw / sqrt(pmax(yhat, 1e-10))]

# Log-transform for variance identity
main[, log_r_pearson := log(abs(r_pearson) + 1)]
main[, log_r_raw := log(abs(r_raw) + 1)]

# Merge theta_D
main <- merge(main, theta_canonical[, .(pair, theta_D)], by = "pair", all.x = TRUE)

# Filter to canonical pairs with theta
main_can <- main[!is.na(theta_D)]
cat(sprintf("Canonical pairs with residuals: %d pairs, %d obs\n", 
            uniqueN(main_can$pair), nrow(main_can)))

# ============================================================
# COMPUTE θ̂_D-CENTERED RESIDUALS
# ============================================================
cat("\n========== θ̂_D-CENTERED RESIDUALS ==========\n\n")

# The θ̂_D-centered gap removes the pair-specific heterogeneous effect
# Gap_centered = log|r| - |θ̂_D × post|
# More precisely: adjust the residual for the estimated treatment effect

main_can[, post := as.integer(year >= adoption_year)]

# Centered residual: remove the heterogeneous effect
# y_centered = y - yhat * (exp(theta_D * post) - 1)
# This is the residual after accounting for pair-specific theta
main_can[, yhat_adj := yhat * exp(theta_D * post)]
main_can[, r_centered := trade - yhat_adj]
main_can[, r_pearson_centered := r_centered / sqrt(pmax(yhat_adj, 1e-10))]
main_can[, log_r_centered := log(abs(r_pearson_centered) + 1)]

# ============================================================
# VARIANCE TABLE
# ============================================================
cat("\n========== VARIANCE TABLE (log scale) ==========\n\n")

# Compute variances by pre/post
var_table <- main_can[, .(
  var_common = var(log_r_pearson, na.rm = TRUE),
  var_centered = var(log_r_centered, na.rm = TRUE),
  n = .N
), by = post]

setorder(var_table, post)

cat("                     Common-coef gap    θ̂_D-centered gap\n")
cat("                     (log|r_pearson|)   (log|r_centered|)\n")
cat("-------------------------------------------------------------\n")
cat(sprintf("Var_pre  (post=0)    %.4f             %.4f    (n=%d)\n",
            var_table[post == 0, var_common],
            var_table[post == 0, var_centered],
            var_table[post == 0, n]))
cat(sprintf("Var_post (post=1)    %.4f             %.4f    (n=%d)\n",
            var_table[post == 1, var_common],
            var_table[post == 1, var_centered],
            var_table[post == 1, n]))

# Var(θ̂_D) across pairs
var_theta <- var(theta_canonical$theta_D, na.rm = TRUE)
cat(sprintf("\nVar(θ̂_D) across pairs: %.4f\n", var_theta))

# ============================================================
# VARIANCE IDENTITY TEST
# ============================================================
cat("\n========== VARIANCE IDENTITY TEST ==========\n\n")

# LHS: Var_post(common) - Var_pre(common)
LHS <- var_table[post == 1, var_common] - var_table[post == 0, var_common]

# RHS: [Var_post(centered) - Var_pre(centered)] + Var(θ̂_D)
var_change_centered <- var_table[post == 1, var_centered] - var_table[post == 0, var_centered]
RHS <- var_change_centered + var_theta

# Gap
gap <- LHS - RHS
pct_gap <- 100 * gap / abs(LHS)

cat("VARIANCE DECOMPOSITION:\n")
cat(sprintf("  LHS: Var_post(common) - Var_pre(common) = %.4f - %.4f = %.4f\n",
            var_table[post == 1, var_common],
            var_table[post == 0, var_common],
            LHS))
cat(sprintf("  RHS: [Var_post(centered) - Var_pre(centered)] + Var(θ̂_D)\n"))
cat(sprintf("       = [%.4f - %.4f] + %.4f\n",
            var_table[post == 1, var_centered],
            var_table[post == 0, var_centered],
            var_theta))
cat(sprintf("       = %.4f + %.4f = %.4f\n",
            var_change_centered, var_theta, RHS))

cat(sprintf("\n  LHS = %.4f\n", LHS))
cat(sprintf("  RHS = %.4f\n", RHS))
cat(sprintf("  Gap = %.4f (%.1f%% of LHS)\n", gap, pct_gap))

# ============================================================
# INTERPRETATION
# ============================================================
cat("\n========== INTERPRETATION ==========\n\n")

cat("Pearson-vs-log caveat: The variance identity is computed on\n")
cat("log|Pearson residual| for stability, not raw Pearson residuals.\n\n")

if(abs(pct_gap) < 20) {
  cat(">>> CLOSES WITHIN 20%: Dispersion activation ≈ revealed heterogeneity <<<\n\n")
  cat("INTERPRETATION:\n")
  cat("  The post-adoption dispersion increase is almost entirely explained\n")
  cat("  by the variance in θ̂_D. The two results FUSE:\n")
  cat("  - Table 6's dispersion finding\n")
  cat("  - The heterogeneous effects analysis\n")
  cat("  are measuring the SAME phenomenon from different angles.\n")
  cat("  Section 5.4 should be rewritten to reflect this unification.\n")
  outcome <- "CLOSES"
} else if(abs(pct_gap) < 50) {
  cat(">>> CLOSES PARTIALLY: Both channels real <<<\n\n")
  het_share <- 100 * var_theta / LHS
  vol_share <- 100 * var_change_centered / LHS
  cat(sprintf("  Heterogeneity channel: %.1f%% of dispersion increase\n", het_share))
  cat(sprintf("  Volatility channel: %.1f%% of dispersion increase\n", vol_share))
  cat("\nINTERPRETATION:\n")
  cat("  Both heterogeneity and volatility contribute to post-adoption\n")
  cat("  dispersion. This is arguably the richest version — two distinct\n")
  cat("  mechanisms, each with a measured share.\n")
  outcome <- "PARTIAL"
} else {
  cat(">>> DOESN'T CLOSE: Volatility activation dominant <<<\n\n")
  cat("INTERPRETATION:\n")
  cat("  A substantial residual remains after removing heterogeneity.\n")
  cat("  This residual is volatility activation — dispersion increases\n")
  cat("  even after accounting for pair-specific θ̂_D.\n")
  cat("  P1's ρ needs re-reconciling before shipping.\n")
  outcome <- "NO_CLOSE"
}

# Component shares
cat("\n========== COMPONENT SHARES ==========\n\n")

het_component <- var_theta
vol_component <- var_change_centered
total <- LHS

cat(sprintf("Total dispersion increase (LHS): %.4f\n", total))
cat(sprintf("  Heterogeneity component (Var θ̂_D): %.4f (%.1f%%)\n", 
            het_component, 100 * het_component / total))
cat(sprintf("  Volatility component (Δ centered): %.4f (%.1f%%)\n",
            vol_component, 100 * vol_component / total))
cat(sprintf("  Unexplained gap: %.4f (%.1f%%)\n",
            gap, 100 * gap / total))

# Save
T3 <- list(
  var_table = var_table,
  var_theta = var_theta,
  LHS = LHS,
  RHS = RHS,
  gap = gap,
  pct_gap = pct_gap,
  het_component = het_component,
  vol_component = vol_component,
  outcome = outcome
)

saveRDS(T3, "/scratch/bt307958/T3_results.rds")
cat("\n\nT3 results saved.\n")
