# S9_spec_spread.R: Four-Specification Comparison
# OUTPUTS: data/S9_spec.rds
# INPUTS: N0_data.rds (full panel with zeros)
# SEED: none
# GATES:
#   A: FULL spec matches S1_ppml (within 0.005)
#   B: Monotonic decrease B > C > CY > FULL

cat("========================================================================\n")
cat("S9: SPECIFICATION SPREAD\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat("========================================================================\n\n")

library(fixest)
setFixest_nthreads(4)

BASE <- "/scratch/bt307958/REBUILD_V2"

# ============================================================================
# LOAD DATA
# ============================================================================
cat("=== LOAD DATA ===\n\n")

# Need full panel with zeros for proper PPML
# Use the original ITPDE_total.rds which has zeros
data_path <- "/groups/m-larch/bt307958/tails/data/ITPDE_total.rds"
df <- readRDS(data_path)

# Exclude domestic
df <- df[df$exporter != df$importer, ]

# Create pair ID
df$pair <- paste(df$exporter, df$importer, sep = "_")

cat(sprintf("Observations: %d\n", nrow(df)))
cat(sprintf("Positive flows: %d\n", sum(df$trade > 0)))
cat(sprintf("Zero flows: %d\n", sum(df$trade == 0)))

# ============================================================================
# FOUR SPECIFICATIONS
# ============================================================================
cat("\n=== FOUR SPECIFICATIONS ===\n\n")

results <- data.frame(
  spec = c("(B) Bilateral", "(C) Country", "(CY) Country-Year", "(FULL) Full"),
  formula = c(
    "trade ~ rta | exporter^importer",
    "trade ~ log(distance) + rta | exporter + importer",
    "trade ~ log(distance) + rta | exporter^year + importer^year",
    "trade ~ rta | exporter^importer + exporter^year + importer^year"
  ),
  published = c(1.402, 0.922, 0.411, 0.095),
  estimate = NA_real_,
  se = NA_real_
)

get_rta_coef <- function(model) {
  s <- summary(model, vcov = ~pair)
  coef <- s$coeftable["rta", "Estimate"]
  se <- s$coeftable["rta", "Std. Error"]
  c(coef = coef, se = se)
}

# (B) Bilateral FE
cat("(B) Bilateral FE: trade ~ rta | exporter^importer\n")
m_B <- fepois(trade ~ rta | exporter^importer, data = df)
r <- get_rta_coef(m_B)
results$estimate[1] <- r["coef"]
results$se[1] <- r["se"]
cat(sprintf("    RTA = %.4f (SE: %.4f)\n", r["coef"], r["se"]))
rm(m_B); gc()

# (C) Country FE
cat("\n(C) Country FE: trade ~ log(distance) + rta | exporter + importer\n")
m_C <- fepois(trade ~ log(distance) + rta | exporter + importer, data = df)
r <- get_rta_coef(m_C)
results$estimate[2] <- r["coef"]
results$se[2] <- r["se"]
cat(sprintf("    RTA = %.4f (SE: %.4f)\n", r["coef"], r["se"]))
rm(m_C); gc()

# (CY) Country-Year FE
cat("\n(CY) Country-Year FE: trade ~ log(distance) + rta | exporter^year + importer^year\n")
m_CY <- fepois(trade ~ log(distance) + rta | exporter^year + importer^year, data = df)
r <- get_rta_coef(m_CY)
results$estimate[3] <- r["coef"]
results$se[3] <- r["se"]
cat(sprintf("    RTA = %.4f (SE: %.4f)\n", r["coef"], r["se"]))
rm(m_CY); gc()

# (FULL) Full FE
cat("\n(FULL) Full FE: trade ~ rta | exporter^importer + exporter^year + importer^year\n")
m_FULL <- fepois(trade ~ rta | exporter^importer + exporter^year + importer^year, data = df)
r <- get_rta_coef(m_FULL)
results$estimate[4] <- r["coef"]
results$se[4] <- r["se"]
cat(sprintf("    RTA = %.4f (SE: %.4f)\n", r["coef"], r["se"]))
rm(m_FULL); gc()

# ============================================================================
# GATES
# ============================================================================
cat("\n=== GATES ===\n\n")

# GATE A: FULL matches S1_ppml
# Load S1 result
S1 <- readRDS(file.path(BASE, "data/S1_ppml.rds"))
s1_rta <- S1$coefficients["rta"]
full_rta <- results$estimate[4]
diff_s1 <- abs(full_rta - s1_rta)

cat(sprintf("GATE A: FULL spec vs S1_ppml\n"))
cat(sprintf("  S1 RTA: %.6f\n", s1_rta))
cat(sprintf("  FULL RTA: %.6f\n", full_rta))
cat(sprintf("  Difference: %.6f\n", diff_s1))
cat(sprintf("  GATE A: %s\n", ifelse(diff_s1 < 0.005, "PASS", "FAIL")))
stopifnot("GATE A failed: FULL != S1" = diff_s1 < 0.005)

# GATE B: Monotonic decrease
cat("\nGATE B: Monotonic decrease B > C > CY > FULL\n")
b_gt_c <- results$estimate[1] > results$estimate[2]
c_gt_cy <- results$estimate[2] > results$estimate[3]
cy_gt_full <- results$estimate[3] > results$estimate[4]

cat(sprintf("  B > C: %.4f > %.4f = %s\n", 
            results$estimate[1], results$estimate[2], b_gt_c))
cat(sprintf("  C > CY: %.4f > %.4f = %s\n", 
            results$estimate[2], results$estimate[3], c_gt_cy))
cat(sprintf("  CY > FULL: %.4f > %.4f = %s\n", 
            results$estimate[3], results$estimate[4], cy_gt_full))

monotonic <- b_gt_c && c_gt_cy && cy_gt_full
cat(sprintf("  GATE B: %s\n", ifelse(monotonic, "PASS", "FAIL")))
stopifnot("GATE B failed: not monotonic" = monotonic)

# ============================================================================
# RESULTS TABLE
# ============================================================================
cat("\n=== RESULTS TABLE ===\n\n")

results$diff_published <- results$estimate - results$published

cat(sprintf("%-20s %10s %10s %10s %10s\n", 
            "Specification", "Published", "Estimate", "SE", "Diff"))
cat(paste0(rep("-", 65), collapse = ""), "\n")

for (i in 1:4) {
  cat(sprintf("%-20s %10.3f %10.4f %10.4f %+10.4f\n",
              results$spec[i], results$published[i], 
              results$estimate[i], results$se[i], results$diff_published[i]))
}

# ============================================================================
# SPECIFICATION SPREAD
# ============================================================================
cat("\n=== SPECIFICATION SPREAD ===\n\n")

spread <- results$estimate[1] - results$estimate[4]
cat(sprintf("Spread (B - FULL): %.4f\n", spread))
cat(sprintf("Published spread: %.3f\n", results$published[1] - results$published[4]))

# The spread shows how much of the "RTA effect" is absorbed by FEs
cat(sprintf("\nInterpretation:\n"))
cat(sprintf("  Adding country-year FE reduces estimate by %.1f%%\n", 
            (1 - results$estimate[4]/results$estimate[1]) * 100))

# ============================================================================
# SAVE OUTPUT
# ============================================================================

output <- list(
  results = results,
  spread = spread,
  gates = list(
    A_full_vs_s1 = diff_s1,
    B_monotonic = monotonic
  )
)

output_path <- file.path(BASE, "data/S9_spec.rds")
saveRDS(output, output_path)

sha <- strsplit(system(sprintf("sha256sum %s", output_path), intern = TRUE), " ")[[1]][1]
cat(sprintf("\nOutput: %s\n", output_path))
cat(sprintf("SHA256: %s\n", sha))

# Write sidecar
sidecar <- sprintf("file: S9_spec.rds
sha256: %s
created: %s
script: S9_spec_spread.R
description: Four-specification comparison (B, C, CY, FULL)
gates:
  A_full_vs_s1: PASS (diff=%.6f)
  B_monotonic: PASS
summary:
  B_bilateral: %.4f
  C_country: %.4f
  CY_country_year: %.4f
  FULL_full: %.4f
  spread_B_minus_FULL: %.4f
", sha, format(Sys.time()), diff_s1, 
   results$estimate[1], results$estimate[2], results$estimate[3], results$estimate[4], spread)

writeLines(sidecar, file.path(BASE, "meta/S9_spec.rds.sidecar"))

cat("\n========================================================================\n")
cat(sprintf("S9 COMPLETE: %s\n", format(Sys.time())))
cat("========================================================================\n")
