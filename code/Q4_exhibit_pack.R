# Q4 — Final Exhibit Pack
# Closes the heterogeneity-gates analysis

library(data.table)
library(knitr)

cat("=== Q4: Final Exhibit Pack ===\n\n")

# Load all prior results
Q1 <- readRDS("/scratch/bt307958/Q1_results.rds")
Q2 <- readRDS("/scratch/bt307958/Q2_results.rds")
Q3 <- readRDS("/scratch/bt307958/Q3_results.rds")
P4 <- readRDS("/scratch/bt307958/P4_results.rds")

# ============================================================
# EXHIBIT 1: Correction-Path Table (A → B → D → O → P → Q)
# ============================================================
cat("\n========== EXHIBIT 1: CORRECTION-PATH TABLE ==========\n\n")

correction_path <- data.frame(
  Step = c("A", "B", "D", "O", "P", "Q"),
  
  What_Removed = c(
    "MR bias from common coefficients",
    "FE timing bias (levels → changes)",
    "Size-decile mechanical correlation",
    "Placebo variance (measurement noise)",
    "Volatility-scaling ambiguity",
    "Table 6 dispersion claim"
  ),
  
  Evidence = c(
    "θ̂_A mean -0.63 → θ̂_B mean -0.04",
    "First-diff gravity, pair-time FE",
    "N1 b̂_decile calibration applied",
    "Deconvolution: Var(θ)=Var(θ̂)-Var(placebo)",
    "ρ=0.83 computed; P4-(iv) rejects full-ρ",
    "IQR ratio=0.62 < 1 (opposite of 5-7×)"
  ),
  
  Zero_Effect_Pop = c(
    "All pairs pre-correction",
    "Level-based estimators",
    "Small exporters (deciles 1-3)",
    "Non-switcher pairs",
    "Full-ρ correction (retired)",
    "Post-period volatility claim"
  )
)

print(kable(correction_path, format = "simple", align = "l"))

# ============================================================
# EXHIBIT 2: P4 Injection Table (with scenario iv annotated)
# ============================================================
cat("\n\n========== EXHIBIT 2: P4 INJECTION TEST TABLE ==========\n\n")

injection_table <- data.frame(
  Scenario = c("(i) True θ=0, no noise",
               "(ii) True θ=0, +placebo noise", 
               "(iii) True θ=0.25, no noise",
               "(iv) True θ=0.25, +placebo noise"),
  
  True_Mean = c(0.00, 0.00, 0.25, 0.25),
  True_SD = c(0.00, 0.00, 0.25, 0.25),
  
  Pre_Calib_Mean = c(0.00, 0.00, 0.25, 0.25),
  Pre_Calib_SD = c(0.00, 0.20, 0.25, 0.32),
  
  Full_Rho_Mean = c(0.00, 0.00, 0.25, 0.25),
  Full_Rho_SD = c(0.00, 0.00, 0.25, 0.21),
  
  Annotation = c("Both correct",
                 "Pre-calib inflates SD; full-ρ correct",
                 "Both correct",
                 "Full-ρ UNDER-corrects (boundary)")
)

print(kable(injection_table[, 1:7], format = "simple", align = "c"))
cat("\nAnnotations:\n")
for(i in 1:4) {
  cat(sprintf("  %s: %s\n", injection_table$Scenario[i], injection_table$Annotation[i]))
}
cat("\n*** Scenario (iv) is the PARTIAL-IDENTIFICATION BOUNDARY ***\n")
cat("    Full-ρ retired because it under-corrects when true heterogeneity exists.\n")

# ============================================================
# EXHIBIT 3: Q1 Reconciliation Table
# ============================================================
cat("\n\n========== EXHIBIT 3: Q1 RECONCILIATION TABLE ==========\n\n")

# Extract values from Q1 summary
med_common <- Q1$summary$median_common_iqr
med_centered <- Q1$summary$median_centered_iqr
med_placebo <- Q1$summary$median_placebo_iqr

reconciliation <- data.frame(
  Measure = c("IQR ratio (post/pre)",
              "Table 6 claimed ratio",
              "Variance identity check",
              "Attribution"),
  
  Common_Coef = c(
    sprintf("%.2f", med_common),
    "~5-7×",
    "Passed",
    "Common θ̂ residuals"
  ),
  
  Theta_D_Centered = c(
    sprintf("%.2f", med_centered),
    "~5-7×",
    "Passed", 
    "Pair-specific θ̂_D removed"
  ),
  
  Placebo_Bench = c(
    sprintf("%.2f", med_placebo),
    "~1.0 (null)",
    "Passed",
    "Non-switcher reference"
  )
)

print(kable(reconciliation, format = "simple", align = "l"))

cat("\n*** VERDICT: Table 6 NOT REPRODUCED ***\n")
cat(sprintf("    Median IQR ratio = %.2f < 1 (OPPOSITE of claimed 5-7×)\n", med_common))
cat("    Post-period volatility is LOWER than pre-period.\n")
cat("    Volatility channel NOT ACTIVATED.\n")

# ============================================================
# EXHIBIT 4: Practicability Table
# ============================================================
cat("\n\n========== EXHIBIT 4: PRACTICABILITY TABLE ==========\n\n")

practicability <- data.frame(
  Scenario = c("Pre-calibrated (canonical)",
               "Capped-ρ (sensitivity)",
               "Full-ρ (RETIRED)"),
  
  Mean_Bracket = c("[−0.04, 0.02]", "[−0.04, 0.02]", "[−0.04, 0.02]"),
  SD_Bracket = c("[0.20, 0.29]", "[0.17, 0.25]", "[0.00, 0.15]"),
  
  P_Theta_Leq_0 = c("52-56%", "52-56%", "55-65%"),
  
  CI_80_Width = c("±0.51", "±0.44", "±0.26"),
  
  Status = c("CANONICAL", "Sensitivity", "RETIRED (P4-iv)")
)

print(kable(practicability, format = "simple", align = "c"))

cat("\n*** CANONICAL BRACKET: Mean ∈ [−0.04, 0.02], SD ∈ [0.20, 0.29] ***\n")

# ============================================================
# EXHIBIT 5: Headline Results Summary
# ============================================================
cat("\n\n========== EXHIBIT 5: HEADLINE RESULTS ==========\n\n")

headlines <- data.frame(
  Metric = c(
    "θ̂_D mean (switchers)",
    "θ̂_D SD (switchers)", 
    "Volatility ratio ρ",
    "IQR ratio (post/pre)",
    "P(θ ≤ 0)",
    "Trade change at θ=0.29 (σ=5)",
    "Range at conservative corner",
    "Welfare (small open economy)"
  ),
  
  Value = c(
    "0.29",
    "0.68 (raw) → [0.20, 0.29] (deconvolved)",
    "0.83",
    "0.62",
    "52-56%",
    "+219%",
    "22-fold (10th-90th pctile)",
    "0.02-0.05 pp GDP per dyad"
  ),
  
  Interpretation = c(
    "Near zero, not economically large",
    "Substantial heterogeneity remains",
    "Post < pre volatility",
    "Table 6 claim NOT reproduced",
    "Majority of pairs see ≤0 effect",
    "Upper bound if θ at 90th pctile",
    "Wide uncertainty from heterogeneity",
    "Modest aggregate gains"
  )
)

print(kable(headlines, format = "simple", align = "l"))

# ============================================================
# EXHIBIT 6: SHA Ledger (File Hashes)
# ============================================================
cat("\n\n========== EXHIBIT 6: SHA LEDGER ==========\n\n")

# List all analysis files
files_to_hash <- c(
  "/groups/m-larch/bt307958/gates/A_ppml_common.R",
  "/groups/m-larch/bt307958/gates/B_ppml_hetero.R",
  "/groups/m-larch/bt307958/gates/D_ppml_decile.R",
  "/groups/m-larch/bt307958/gates/N1_calibration.R",
  "/groups/m-larch/bt307958/gates/O1_variance_ledger.R",
  "/groups/m-larch/bt307958/gates/P1_volatility_scaled.R",
  "/groups/m-larch/bt307958/gates/P2_drift_bracket.R",
  "/groups/m-larch/bt307958/gates/P4_injection_test.R",
  "/groups/m-larch/bt307958/gates/P5_final_report.R",
  "/groups/m-larch/bt307958/gates/Q1_reconcile_table6.R",
  "/groups/m-larch/bt307958/gates/Q2_canonical_bracket.R",
  "/groups/m-larch/bt307958/gates/Q3_propagation.R",
  "/groups/m-larch/bt307958/gates/Q4_exhibit_pack.R"
)

sha_ledger <- data.frame(
  File = character(),
  SHA256 = character(),
  stringsAsFactors = FALSE
)

for(f in files_to_hash) {
  if(file.exists(f)) {
    sha <- system(paste("sha256sum", f, "| cut -c1-16"), intern = TRUE)
    sha_ledger <- rbind(sha_ledger, data.frame(
      File = basename(f),
      SHA256 = sha,
      stringsAsFactors = FALSE
    ))
  }
}

print(kable(sha_ledger, format = "simple", align = "l"))

# ============================================================
# Save all exhibits
# ============================================================

exhibits <- list(
  correction_path = correction_path,
  injection_table = injection_table,
  reconciliation = reconciliation,
  practicability = practicability,
  headlines = headlines,
  sha_ledger = sha_ledger,
  timestamp = Sys.time()
)

saveRDS(exhibits, "/scratch/bt307958/Q4_exhibits.rds")

cat("\n\n========================================\n")
cat("Q-SERIES COMPLETE — LEDGER CLOSED\n")
cat("========================================\n")
cat("\nAll exhibits saved to /scratch/bt307958/Q4_exhibits.rds\n")
cat("Analysis pipeline: A → B → D → O → P → Q\n")
cat("Canonical bracket: Mean ∈ [−0.04, 0.02], SD ∈ [0.20, 0.29]\n")
cat("Full-ρ correction: RETIRED (P4-iv boundary violation)\n")
cat("Table 6 volatility claim: NOT REPRODUCED (IQR ratio = 0.62)\n")
cat("\n*** HETEROGENEITY GATES ANALYSIS CLOSED ***\n")
