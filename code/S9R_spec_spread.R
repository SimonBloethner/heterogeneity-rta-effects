#!/usr/bin/env Rscript
# =============================================================================
# S9R_spec_spread.R - Four-Specification Comparison (FIXED CHAIN)
# =============================================================================
# OUTPUTS: data/S9R_spec.rds, output/T1R_spec_spread.csv
# INPUTS:  data/ITPDE_total.rds (full panel with zeros)
# SEED:    none
# NOTE: Under S1R (untreated-only), the FULL spec will NOT match because
#       S1R excludes treated cells from estimation. The spec spread measures
#       attenuation from pooled estimation, which is separate from the
#       heterogeneity analysis.
# =============================================================================

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(fixest))

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S9R: SPECIFICATION SPREAD (FIXED CHAIN)")
say("Start: %s", format(Sys.time()))
say("================================================================")

# Load full panel with zeros
data_path <- file.path(RTA_ROOT, "data/ITPDE_total.rds")
df <- readRDS(data_path)

# Exclude domestic
df <- df[df$exporter != df$importer, ]
df$pair <- paste(df$exporter, df$importer, sep = "_")

say("Observations: %d", nrow(df))
say("Positive flows: %d", sum(df$trade > 0))
say("Zero flows: %d", sum(df$trade == 0))

# =============================================================================
# FOUR SPECIFICATIONS
# =============================================================================
say("")
say("=== FOUR SPECIFICATIONS ===")

results <- data.frame(
  spec = c("(B) Bilateral", "(C) Country", "(CY) Country-Year", "(FULL) Full"),
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
say("")
say("(B) Bilateral FE: trade ~ rta | exporter^importer")
m_B <- fepois(trade ~ rta | exporter^importer, data = df)
r <- get_rta_coef(m_B)
results$estimate[1] <- r["coef"]
results$se[1] <- r["se"]
say("    RTA = %.4f (SE: %.4f)", r["coef"], r["se"])
rm(m_B); gc()

# (C) Country FE
say("")
say("(C) Country FE: trade ~ log(distance) + rta | exporter + importer")
m_C <- fepois(trade ~ log(distance) + rta | exporter + importer, data = df)
r <- get_rta_coef(m_C)
results$estimate[2] <- r["coef"]
results$se[2] <- r["se"]
say("    RTA = %.4f (SE: %.4f)", r["coef"], r["se"])
rm(m_C); gc()

# (CY) Country-Year FE
say("")
say("(CY) Country-Year FE: trade ~ log(distance) + rta | exporter^year + importer^year")
m_CY <- fepois(trade ~ log(distance) + rta | exporter^year + importer^year, data = df)
r <- get_rta_coef(m_CY)
results$estimate[3] <- r["coef"]
results$se[3] <- r["se"]
say("    RTA = %.4f (SE: %.4f)", r["coef"], r["se"])
rm(m_CY); gc()

# (FULL) Full FE
say("")
say("(FULL) Full FE: trade ~ rta | exporter^importer + exporter^year + importer^year")
m_FULL <- fepois(trade ~ rta | exporter^importer + exporter^year + importer^year, data = df)
r <- get_rta_coef(m_FULL)
results$estimate[4] <- r["coef"]
results$se[4] <- r["se"]
say("    RTA = %.4f (SE: %.4f)", r["coef"], r["se"])
rm(m_FULL); gc()

# =============================================================================
# GATES
# =============================================================================
say("")
say("=== GATES ===")

# GATE A: Monotonic decrease B > C > CY > FULL
b_gt_c <- results$estimate[1] > results$estimate[2]
c_gt_cy <- results$estimate[2] > results$estimate[3]
cy_gt_full <- results$estimate[3] > results$estimate[4]
monotonic <- b_gt_c && c_gt_cy && cy_gt_full

say("GATE A: Monotonic decrease B > C > CY > FULL")
say("  B > C: %.4f > %.4f = %s", results$estimate[1], results$estimate[2], b_gt_c)
say("  C > CY: %.4f > %.4f = %s", results$estimate[2], results$estimate[3], c_gt_cy)
say("  CY > FULL: %.4f > %.4f = %s", results$estimate[3], results$estimate[4], cy_gt_full)
say("  GATE A: %s", ifelse(monotonic, "PASS", "FAIL"))
stopifnot("GATE A failed: not monotonic" = monotonic)

# =============================================================================
# RESULTS
# =============================================================================
say("")
say("=== RESULTS ===")

results$diff_vs_pack <- results$estimate - results$published
print(as.data.frame(results))

spread <- results$estimate[1] - results$estimate[4]
pack_spread <- results$published[1] - results$published[4]

say("")
say("Spread (B - FULL): %.4f", spread)
say("Pack spread:       %.3f", pack_spread)
say("Deviation:         %+.4f", spread - pack_spread)

# NOTE: The spec spread may differ from the pack because this is the POOLED
# RTA coefficient. Under S1R, theta_D is computed differently (untreated-only
# counterfactual), but the spec spread is about the POOLED estimate.

say("")
say("NOTE: Spec spread uses pooled RTA estimator on all cells.")
say("      It measures attenuation from FE inclusion, separate from")
say("      the heterogeneity analysis which uses S1R untreated-only.")

# =============================================================================
# OUTPUT
# =============================================================================
output <- list(
    results = results,
    spread = spread,
    pack_spread = pack_spread,
    deviation = spread - pack_spread,
    gates = list(A_monotonic = monotonic)
)

saveRDS(output, file.path(RTA_ROOT, "data/S9R_spec.rds"))
osha <- get_sha256(file.path(RTA_ROOT, "data/S9R_spec.rds"))

# CSV output
write.csv(results, file.path(RTA_ROOT, "output/T1R_spec_spread.csv"), row.names = FALSE)

writeLines(c(
    "FILE:      S9R_spec.rds",
    sprintf("SHA256:    %s", osha),
    sprintf("PRODUCER:  code/S9R_spec_spread.R (SHA256: %s)", get_sha256(file.path(RTA_ROOT, "code/S9R_spec_spread.R"))),
    "INPUTS:    data/ITPDE_total.rds (full panel)",
    "SEED:      NONE",
    "CONFIG:    pooled RTA estimator (NOT untreated-only)",
    "GATE:      A_monotonic [PASS]",
    sprintf("B_BILATERAL:   %.4f", results$estimate[1]),
    sprintf("C_COUNTRY:     %.4f", results$estimate[2]),
    sprintf("CY_COUNTRY_YR: %.4f", results$estimate[3]),
    sprintf("FULL:          %.4f", results$estimate[4]),
    sprintf("SPREAD:        %.4f (pack %.3f, dev %+.4f)", spread, pack_spread, spread - pack_spread),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/S9R_spec.rds.sidecar"))

say("")
say("Wrote data/S9R_spec.rds and output/T1R_spec_spread.csv")
say("Done: %s", format(Sys.time()))
