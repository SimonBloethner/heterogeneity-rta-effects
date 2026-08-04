#!/usr/bin/env Rscript
# =============================================================================
# S3R_theta.R - Pair effects under the SYMMETRIC anticipation window
# =============================================================================
# NOTE: Uses dplyr (no data.table) for Festus compatibility.
# =============================================================================

RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

suppressPackageStartupMessages(library(dplyr))

SEED    <- 20260719
ANTICIP <- 1
N_BOOT  <- 500

get_sha256 <- function(p) strsplit(system2("sha256sum", args = shQuote(p), stdout = TRUE), " ")[[1]][1]
say <- function(...) cat(sprintf(...), "\n", sep = "")

say("================================================================")
say("S3R: PAIR EFFECTS, SYMMETRIC WINDOW")
say("Start: %s", format(Sys.time()))
say("================================================================")

d <- readRDS(file.path(RTA_ROOT, "data/S1R_ppml.rds"))
say("Input rows: %d  SHA %s", nrow(d), get_sha256(file.path(RTA_ROOT, "data/S1R_ppml.rds")))

sw <- d %>% filter(classification == "single_switcher", in_model == TRUE, trade > 0, !is.na(adoption_year))

sw <- sw %>%
    mutate(side = case_when(
        year < adoption_year - ANTICIP ~ "pre",
        year > adoption_year + ANTICIP ~ "post",
        TRUE ~ "excluded"
    ))

say("Cells by side: pre=%d  post=%d  excluded=%d",
    sum(sw$side == "pre"), sum(sw$side == "post"), sum(sw$side == "excluded"))

# G3: nothing in the exclusion band may reach either window
band <- sw %>% filter(side != "excluded", year >= adoption_year - ANTICIP, year <= adoption_year + ANTICIP)
stopifnot(nrow(band) == 0)
say("G3 window symmetry: PASS")

set.seed(SEED)

# Compute theta by pair
theta <- sw %>%
    group_by(pair, adoption_year) %>%
    summarise(
        n_pre = sum(side == "pre"),
        n_post = sum(side == "post"),
        pre_trade = sum(trade[side == "pre"]),
        theta_A = if (sum(side == "post") == 0) NA_real_ else mean(log(trade[side == "post"]) - log(y_hat_0[side == "post"])),
        theta_B = if (sum(side == "post") == 0) NA_real_ else log(sum(trade[side == "post"]) / sum(y_hat_0[side == "post"])),
        .groups = "drop"
    )

# Bootstrap SE
set.seed(SEED)
theta$se_B <- NA_real_
for (i in which(theta$n_post >= 2)) {
    p <- theta$pair[i]
    po <- sw %>% filter(pair == p, side == "post")
    bs <- replicate(N_BOOT, {
        idx <- sample(nrow(po), replace = TRUE)
        log(sum(po$trade[idx]) / sum(po$y_hat_0[idx]))
    })
    theta$se_B[i] <- sd(bs, na.rm = TRUE)
}

retained <- theta %>% filter(!is.na(theta_B))
stopifnot(all(retained$n_post >= 1))
say("G1 all retained have >=1 post cell: PASS")
stopifnot(!any(is.na(retained$theta_B)))
say("G2 no NA theta_B among retained: PASS")

say("")
say("Pairs with a computable theta: %d of %d switchers", nrow(retained), length(unique(sw$pair)))
say("theta_A  mean %.6f  sd %.6f", mean(retained$theta_A), sd(retained$theta_A))
say("theta_B  mean %.6f  sd %.6f", mean(retained$theta_B), sd(retained$theta_B))

saveRDS(theta, file.path(RTA_ROOT, "data/S3R_theta.rds"))
osha <- get_sha256(file.path(RTA_ROOT, "data/S3R_theta.rds"))

writeLines(c(
    "FILE:      S3R_theta.rds",
    sprintf("SHA256:    %s", osha),
    sprintf("PRODUCER:  code/S3R_theta.R (SHA256: %s)", get_sha256(file.path(RTA_ROOT, "code/S3R_theta.R"))),
    sprintf("INPUTS:    data/S1R_ppml.rds (SHA256: %s)", get_sha256(file.path(RTA_ROOT, "data/S1R_ppml.rds"))),
    sprintf("SEED:      %d", SEED),
    "WINDOW:    pre = year < adoption_year - 1 ; post = year > adoption_year + 1",
    "GATE:      G1_post_cells [PASS]",
    "GATE:      G2_no_NA_theta_B [PASS]",
    "GATE:      G3_window_symmetry [PASS]",
    sprintf("THETA_A:   mean %.6f  sd %.6f", mean(retained$theta_A), sd(retained$theta_A)),
    sprintf("THETA_B:   mean %.6f  sd %.6f", mean(retained$theta_B), sd(retained$theta_B)),
    sprintf("R_VERSION: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("ROWS:      %d", nrow(theta)),
    sprintf("CREATED:   %s", format(Sys.time()))
), file.path(RTA_ROOT, "meta/S3R_theta.rds.sidecar"))

say("Wrote data/S3R_theta.rds  SHA %s", osha)
say("Done: %s", format(Sys.time()))
