# Fixture: check_d_pass.R
# Expected: PASS (no ARCHIVE_STRUCTURAL violation)
# This script loads only from legitimate paths

data <- readRDS("data/S1R_ppml.rds")
output <- read.csv("output/T21_arms.csv")
# No reference to archive/
