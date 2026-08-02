# Fixture: check_d_itpde_fail.R
# Expected: FAIL (ARCHIVED violation)
# This script loads archive/retired_pack/data/ITPDE_total.rds, the ARCHIVED copy.
# Check (d) must flag this because it matches the full archived path.

itpde <- readRDS("archive/retired_pack/data/ITPDE_total.rds")
