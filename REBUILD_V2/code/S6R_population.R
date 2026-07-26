#!/usr/bin/env Rscript
# =============================================================================
# S6R_population.R - Estimating population under the symmetric window
# =============================================================================
# NOTE: Uses dplyr (no data.table) for Festus compatibility.
# =============================================================================

.libPaths(c("/groups/m-larch/bt307958/Rlibs", .libPaths()))

suppressPackageStartupMessages(library(dplyr))

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

MIN_PRE  <- 3
MIN_POST <- 3
ADOPT_LO <- 1991
ADOPT_HI <- 2016
PACK_N   <- 4182

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S6R: POPULATION CENSUS, SYMMETRIC WINDOW")
say("================================================================")

d     <- readRDS("data/S1R_ppml.rds")
theta <- readRDS("data/S3R_theta.rds")

all_pairs <- unique(d$pair)
census <- list()
add <- function(rule, desc, keep) {
    census[[length(census) + 1]] <<- data.frame(rule = rule, description = desc,
                                                 pairs_remaining = length(keep))
    keep
}

k <- add("R0", "All pairs in data", all_pairs)

sw <- unique(d$pair[d$classification == "single_switcher"])
k <- add("R1", "Single switchers (one 0->1 transition)", intersect(k, sw))

ay <- d %>% filter(classification == "single_switcher", adoption_year >= ADOPT_LO, adoption_year <= ADOPT_HI) %>%
    pull(pair) %>% unique()
k <- add("R2", sprintf("Adoption year in [%d, %d]", ADOPT_LO, ADOPT_HI), intersect(k, ay))

pred_ok <- unique(d$pair[d$is_post == TRUE & d$in_model == TRUE])
k <- add("R3", "Usable counterfactual for >=1 post cell", intersect(k, pred_ok))

pre_ok <- theta$pair[theta$n_pre >= MIN_PRE]
k <- add("R4", sprintf(">= %d pre years (year < adopt-1, trade>0)", MIN_PRE), intersect(k, pre_ok))

post_ok <- theta$pair[theta$n_post >= MIN_POST]
k <- add("R5", sprintf(">= %d post years (year > adopt+1, trade>0)", MIN_POST), intersect(k, post_ok))

TD1R <- bind_rows(census)
TD1R$pairs_dropped <- c(0, diff(-TD1R$pairs_remaining))

stopifnot(all(diff(TD1R$pairs_remaining) <= 0))
say("G1 monotone census: PASS")
stopifnot(!any(duplicated(k)))
say("G2 no duplicate pairs: PASS")

popn <- theta %>% filter(pair %in% k)
stopifnot(nrow(popn) == length(k))
say("G3 population size matches census: PASS")

say("")
print(TD1R)
say("")
say("FINAL n = %d      ledgered exhibit pack = %d      residual = %+d",
    length(k), PACK_N, length(k) - PACK_N)

saveRDS(popn, "data/S6R_population.rds")
write.csv(TD1R, "output/TD1R_population_census.csv", row.names = FALSE)
osha <- get_sha256("data/S6R_population.rds")

writeLines(c(
    "FILE:      S6R_population.rds",
    sprintf("SHA256:    %s", osha),
    sprintf("PRODUCER:  code/S6R_population.R (SHA256: %s)", get_sha256("code/S6R_population.R")),
    sprintf("INPUTS:    data/S1R_ppml.rds, data/S3R_theta.rds"),
    "SEED:      NONE",
    "RULES:     R1 single switchers; R2 adoption in [1991,2016];",
    "           R3 usable counterfactual; R4 >=3 pre; R5 >=3 post",
    "GATE:      G1_monotone_census [PASS]",
    "GATE:      G2_no_duplicates [PASS]",
    "GATE:      G3_size_matches [PASS]",
    sprintf("N:         %d  (ledgered pack %d, residual %+d)", length(k), PACK_N, length(k) - PACK_N),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("CREATED:   %s", format(Sys.time()))
), "meta/S6R_population.rds.sidecar")

say("Wrote data/S6R_population.rds and output/TD1R_population_census.csv")
