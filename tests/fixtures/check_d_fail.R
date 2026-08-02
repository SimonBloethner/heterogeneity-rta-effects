# Fixture: check_d_fail.R
# Expected: FAIL (ARCHIVE_STRUCTURAL violation)
# This script attempts to load from archive/

retired_data <- readRDS("archive/retired_pack/data/W1_pop_canon.rds")
# This load should trigger the structural check
