#!/usr/bin/env Rscript
# =============================================================================
# S1R_ppml_untreated.R - Imputation counterfactual, untreated-only estimation
# =============================================================================
# OUTPUTS: data/S1R_ppml.rds
#          meta/S1R_ppml.rds.sidecar
# INPUTS:  data/ITPDE_total.rds (SHA-verified)
# NOTE: Uses dplyr + fixest (no data.table) for Festus compatibility.
# =============================================================================

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages({
    library(dplyr)
    library(fixest)
})

ANTICIP <- 1

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S1R: UNTREATED-ONLY IMPUTATION COUNTERFACTUAL")
say("Start: %s", format(Sys.time()))
say("================================================================")

# ---------------------------------------------------------------- input gate
INPUT_PATH <- file.path(RTA_ROOT, "data/ITPDE_total.rds")
INPUT_SHA  <- "e488c36afdf7c9fd1d38667a18b7855eb39e4085430ef96eab946e2d89fe4c01"
actual <- get_sha256(INPUT_PATH)
if (actual != INPUT_SHA) stop(sprintf("HALT: input SHA mismatch\n  expected %s\n  actual   %s", INPUT_SHA, actual))
say("G1 input SHA: PASS")

d <- readRDS(INPUT_PATH)
say("Raw input: %d rows", nrow(d))

# Filter to non-domestic pairs with positive trade (the estimation-relevant subset)
d <- d[d$exporter != d$importer & d$trade > 0, ]
say("After filter (non-domestic, trade > 0): %d rows", nrow(d))

stopifnot(nrow(d) == 794720, min(d$year) == 1988, max(d$year) == 2019)
say("G2 frozen facts: PASS  (rows %d, years %d-%d)", nrow(d), min(d$year), max(d$year))

# ---------------------------------------------------------------- structure
d <- d %>%
    mutate(pair = paste(exporter, importer, sep = "_"),
           pair_fe = as.factor(pair),
           exp_year = as.factor(paste(exporter, year, sep = "_")),
           imp_year = as.factor(paste(importer, year, sep = "_")))

# Identify switchers
pair_rta <- d %>%
    arrange(pair, year) %>%
    group_by(pair) %>%
    summarise(
        n_up = sum(diff(rta) == 1),
        n_down = sum(diff(rta) == -1),
        first_rta = first(rta),
        last_rta = last(rta),
        .groups = "drop"
    ) %>%
    mutate(classification = case_when(
        n_up == 1 & n_down == 0 & first_rta == 0 & last_rta == 1 ~ "single_switcher",
        first_rta == 0 & last_rta == 0 & n_up == 0 ~ "never_treated",
        TRUE ~ "other"
    ))

# Get adoption year for switchers
adoption_years <- d %>%
    filter(rta == 1) %>%
    group_by(pair) %>%
    summarise(adoption_year = min(year), .groups = "drop")

pair_rta <- pair_rta %>% left_join(adoption_years, by = "pair")

say("Classification: %s",
    paste(sprintf("%s=%d", names(table(pair_rta$classification)),
                  as.numeric(table(pair_rta$classification))), collapse = "  "))

d <- d %>% left_join(pair_rta %>% select(pair, classification, adoption_year), by = "pair")
say("After merge: nrow = %d", nrow(d))
stopifnot(nrow(d) == 794720)
say("G2b row count after merge: PASS (no inflation)")

# ------------------------------------------------- estimation sample (untreated)
d <- d %>%
    mutate(est_sample = case_when(
        classification == "never_treated" ~ TRUE,
        classification == "single_switcher" & year < adoption_year - ANTICIP ~ TRUE,
        TRUE ~ FALSE
    ))

est <- d %>% filter(est_sample == TRUE)

# G3: no treated cell may enter the estimation sample
n_treated_in_est <- sum(est$rta == 1)
if (n_treated_in_est != 0) {
    say("G3 FAIL: %d treated cells in estimation sample", n_treated_in_est)
    stop("HALT: estimation sample is contaminated by treated cells")
}
say("G3 no treated cell in estimation sample: PASS  (n_est = %d)", nrow(est))
say("   never-treated rows: %d", sum(est$classification == "never_treated"))
say("   switcher pre rows:  %d", sum(est$classification == "single_switcher"))

# ---------------------------------------------------------------------- fit
say("")
say("Model: trade ~ 1 | pair_fe + exp_year + imp_year   (no rta regressor)")
fit <- fepois(trade ~ 1 | pair_fe + exp_year + imp_year,
              data = est, cluster = ~pair_fe, combine.quick = FALSE)
say("G4 fit converged: %s   (nobs = %d)", ifelse(fit$convStatus, "PASS", "FAIL"), fit$nobs)
if (!isTRUE(fit$convStatus)) stop("HALT: fit did not converge")

# --------------------------------------------------------------- prediction
d$y_hat_0 <- as.numeric(predict(fit, newdata = d))
d <- d %>% mutate(in_model = !is.na(y_hat_0) & y_hat_0 > 0)

# post-window cells for switchers under the SYMMETRIC rule
d <- d %>%
    mutate(is_post = classification == "single_switcher" &
                     !is.na(adoption_year) & year > adoption_year + ANTICIP & trade > 0)

n_post     <- sum(d$is_post)
n_post_bad <- sum(d$is_post & !d$in_model)
say("Switcher post-window cells: %d", n_post)
say("   of which unpredicted or non-positive: %d", n_post_bad)

if (n_post_bad > 0) {
    say("G5 PARTIAL: %d post cells lack a usable counterfactual.", n_post_bad)
} else {
    say("G5 y_hat_0 usable for all post cells: PASS")
}

# ------------------------------------------------------------------- output
out <- d %>% select(exporter, importer, pair, year, trade, rta,
                    classification, adoption_year, y_hat_0, in_model, est_sample, is_post)

saveRDS(out, file.path(RTA_ROOT, "data/S1R_ppml.rds"))
osha <- get_sha256(file.path(RTA_ROOT, "data/S1R_ppml.rds"))

writeLines(c(
    "FILE:      S1R_ppml.rds",
    sprintf("SHA256:    %s", osha),
    sprintf("PRODUCER:  code/S1R_ppml_untreated.R (SHA256: %s)", get_sha256(file.path(RTA_ROOT, "code/S1R_ppml_untreated.R"))),
    sprintf("INPUTS:    data/ITPDE_total.rds (SHA256: %s)", INPUT_SHA),
    "SEED:      NONE",
    "ESTIMATION SAMPLE:",
    "  never_treated pairs: all years",
    "  single_switcher pairs: years < adoption_year - 1",
    "  no treated cell included; verified by gate G3",
    "MODEL:     trade ~ 1 | pair_fe + exp_year + imp_year (fixest fepois)",
    sprintf("GATE:      G1_input_sha [PASS]"),
    sprintf("GATE:      G2_frozen_facts [PASS]"),
    sprintf("GATE:      G3_no_treated_in_est [PASS, n_est=%d]", nrow(est)),
    sprintf("GATE:      G4_converged [PASS, nobs=%d]", fit$nobs),
    sprintf("GATE:      G5_post_predictable [%s, %d of %d unusable]",
            ifelse(n_post_bad == 0, "PASS", "PARTIAL"), n_post_bad, n_post),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("ROWS:      %d", nrow(out)),
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/S1R_ppml.rds.sidecar"))

say("")
say("Wrote data/S1R_ppml.rds  SHA %s", osha)
say("Done: %s", format(Sys.time()))
