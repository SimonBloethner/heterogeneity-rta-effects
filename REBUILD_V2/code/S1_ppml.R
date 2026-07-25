#!/usr/bin/env Rscript
# =============================================================================
# S1_ppml.R - PPML Estimation with Counterfactual
# =============================================================================
# OUTPUTS: data/S1_ppml.rds
# INPUTS:  data/ITPDE_total.rds (external: /groups/m-larch/bt307958/tails/data/)
# SEED:    NONE
# GATES:   nrow == 794720
#          year range == 1988-2019
#          nobs recorded and matches expectation
#          no NA in y_hat or y_hat_0 in retained set
# =============================================================================

cat("================================================================\n")
cat("S1: PPML ESTIMATION\n")
cat("Start:", format(Sys.time()), "\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

suppressPackageStartupMessages({
    library(data.table)
    library(fixest)
    library(tools)
})

source(file.path(REBUILD_DIR, "code/gates_lib_v2.R"))

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    sha <- strsplit(result, " ")[[1]][1]
    return(sha)
}

cat("=== INPUT VERIFICATION ===\n")

INPUT_PATH <- "/groups/m-larch/bt307958/tails/data/ITPDE_total.rds"
INPUT_SHA_EXPECTED <- "e488c36afdf7c9fd1d38667a18b7855eb39e4085430ef96eab946e2d89fe4c01"

input_sha_actual <- get_sha256(INPUT_PATH)

cat(sprintf("Input: %s\n", INPUT_PATH))
cat(sprintf("Expected SHA256: %s\n", INPUT_SHA_EXPECTED))
cat(sprintf("Actual SHA256:   %s\n", input_sha_actual))

if (input_sha_actual != INPUT_SHA_EXPECTED) {
    stop("HALT: Input SHA256 mismatch")
}
cat("Input SHA256: VERIFIED\n\n")

cat("=== LOAD DATA ===\n")
d <- load_filtered_data()
verify_frozen_facts(d)

cat(sprintf("Loaded rows: %d\n", nrow(d)))
cat(sprintf("Year range: %d - %d\n", min(d$year), max(d$year)))

stopifnot(nrow(d) == 794720)
cat("GATE: nrow == 794720 [PASS]\n")

stopifnot(min(d$year) == 1988 && max(d$year) == 2019)
cat("GATE: year range 1988-2019 [PASS]\n\n")

cat("=== PREPARE DATA ===\n")
d[, pair := paste(exporter, importer, sep = "_")]
d[, pair_fe := as.factor(pair)]
d[, exp_year := as.factor(paste(exporter, year, sep = "_"))]
d[, imp_year := as.factor(paste(importer, year, sep = "_"))]
d[, row_id := .I]

cat(sprintf("Unique pairs: %d\n", uniqueN(d$pair)))
cat(sprintf("Unique exporter-years: %d\n", uniqueN(d$exp_year)))
cat(sprintf("Unique importer-years: %d\n", uniqueN(d$imp_year)))
cat("\n")

cat("=== FIT PPML MODEL ===\n")
cat("Model: trade ~ rta | pair_fe + exp_year + imp_year\n")
cat("Cluster: pair_fe\n\n")

fit <- fepois(trade ~ rta | pair_fe + exp_year + imp_year, 
              data = d, 
              cluster = ~pair_fe,
              combine.quick = FALSE)

cat("Model summary:\n")
print(summary(fit))

rta_coef <- coef(fit)["rta"]
rta_se <- sqrt(vcov(fit)["rta", "rta"])
nobs_model <- fit$nobs

cat(sprintf("\n=== PPML RESULTS ===\n"))
cat(sprintf("RTA coefficient: %.6f\n", rta_coef))
cat(sprintf("RTA std. error:  %.6f\n", rta_se))
cat(sprintf("Observations:    %d\n", nobs_model))
cat(sprintf("Rows in data:    %d\n", nrow(d)))

stopifnot(!is.na(nobs_model) && nobs_model > 0)
cat("GATE: nobs recorded and positive [PASS]\n\n")

cat("=== COMPUTE COUNTERFACTUAL ===\n")

d[, y_hat := predict(fit, newdata = d, type = "response")]
d[, in_model := !is.na(y_hat)]
n_in_model <- sum(d$in_model)
n_dropped <- nrow(d) - n_in_model

cat(sprintf("Rows with predictions: %d\n", n_in_model))
cat(sprintf("Rows without predictions: %d\n", n_dropped))

d[, y_hat_0 := y_hat]
d[rta == 1 & !is.na(y_hat), y_hat_0 := y_hat * exp(-rta_coef)]

cat(sprintf("y_hat range (valid): [%.2f, %.2f]\n", 
            min(d[in_model == TRUE]$y_hat, na.rm=TRUE), 
            max(d[in_model == TRUE]$y_hat, na.rm=TRUE)))
cat(sprintf("y_hat_0 range (valid): [%.2f, %.2f]\n", 
            min(d[in_model == TRUE]$y_hat_0, na.rm=TRUE), 
            max(d[in_model == TRUE]$y_hat_0, na.rm=TRUE)))

n_na_yhat <- sum(is.na(d[in_model == TRUE]$y_hat))
n_na_yhat0 <- sum(is.na(d[in_model == TRUE]$y_hat_0))

cat(sprintf("NA in y_hat (in model): %d\n", n_na_yhat))
cat(sprintf("NA in y_hat_0 (in model): %d\n", n_na_yhat0))

stopifnot(n_na_yhat == 0)
stopifnot(n_na_yhat0 == 0)
cat("GATE: no NA in y_hat or y_hat_0 in retained set [PASS]\n\n")

cat("=== PREPARE OUTPUT ===\n")

output_cols <- c("exporter", "importer", "pair", "year", "trade", "rta", 
                 "y_hat", "y_hat_0", "in_model")
out <- d[, ..output_cols]

cat(sprintf("Output rows: %d\n", nrow(out)))
cat(sprintf("Output cols: %s\n", paste(output_cols, collapse = ", ")))
cat(sprintf("Rows in model: %d\n", sum(out$in_model)))

OUTPUT_PATH <- file.path(REBUILD_DIR, "data/S1_ppml.rds")
saveRDS(out, OUTPUT_PATH)

output_sha <- get_sha256(OUTPUT_PATH)
cat(sprintf("\nSaved: %s\n", OUTPUT_PATH))
cat(sprintf("SHA256: %s\n", output_sha))

SIDECAR_PATH <- file.path(REBUILD_DIR, "meta/S1_ppml.rds.sidecar")
script_sha <- get_sha256(file.path(REBUILD_DIR, "code/S1_ppml.R"))

sidecar_lines <- c(
    sprintf("FILE:      S1_ppml.rds"),
    sprintf("SHA256:    %s", output_sha),
    sprintf("PRODUCER:  code/S1_ppml.R (SHA256: %s)", script_sha),
    sprintf("INPUTS:    %s (SHA256: %s)", INPUT_PATH, INPUT_SHA_EXPECTED),
    sprintf("SEED:      NONE"),
    sprintf("GATE:      nrow == 794720 [PASS, %s]", format(Sys.time())),
    sprintf("GATE:      year_range == 1988-2019 [PASS, %s]", format(Sys.time())),
    sprintf("GATE:      nobs_recorded == %d [PASS, %s]", nobs_model, format(Sys.time())),
    sprintf("GATE:      no_NA_yhat_in_model [PASS, %s]", format(Sys.time())),
    sprintf("GATE:      no_NA_yhat0_in_model [PASS, %s]", format(Sys.time())),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("ROWS:      %d", nrow(out)),
    sprintf("ROWS_IN_MODEL: %d", sum(out$in_model)),
    sprintf("COLS:      %s", paste(output_cols, collapse = ", ")),
    sprintf("CREATED:   %s", format(Sys.time())),
    "",
    "=== MODEL RESULTS ===",
    sprintf("RTA coefficient: %.6f", rta_coef),
    sprintf("RTA std. error:  %.6f", rta_se),
    sprintf("Observations (fit nobs): %d", nobs_model),
    sprintf("Rows with predictions: %d", n_in_model),
    sprintf("Rows dropped: %d", n_dropped)
)

writeLines(sidecar_lines, SIDECAR_PATH)
cat(sprintf("\nSidecar written: %s\n", SIDECAR_PATH))

cat("\n================================================================\n")
cat("S1 PPML ESTIMATION COMPLETE\n")
cat("================================================================\n")
cat(sprintf("RTA coefficient: %.6f (SE: %.6f)\n", rta_coef, rta_se))
cat(sprintf("fit nobs: %d\n", nobs_model))
cat(sprintf("Rows with predictions: %d\n", n_in_model))
cat(sprintf("Output: %s\n", OUTPUT_PATH))
cat(sprintf("End: %s\n", format(Sys.time())))
