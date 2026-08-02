# Fixture: check_d_itpde_pass.R
# Expected: PASS (no ARCHIVED violation)
# This script loads data/ITPDE_total.rds, the LIVE file, not the archived copy.
# The archived copy is at archive/retired_pack/data/ITPDE_total.rds.
# Check (d) must distinguish these by full path, not basename.

itpde <- readRDS("data/ITPDE_total.rds")
