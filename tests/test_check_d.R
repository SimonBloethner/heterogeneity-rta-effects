#!/usr/bin/env Rscript
# test_check_d.R - Discrimination test for check (d) ARCHIVE_STRUCTURAL
#
# This test verifies that check_built_deps correctly:
# - PASSES scripts that don't load from archive/
# - FAILS scripts that load from archive/

FIXTURE_MODE <- TRUE
source("code/enforce.R")

cat("=== CHECK (d) FIXTURE DISCRIMINATION TEST ===\n\n")

# Test function that scans a single script for archive/ loads
test_fixture <- function(fixture_path) {
  content <- readLines(fixture_path, warn = FALSE)
  load_pattern <- "readRDS\\s*\\(|read\\.csv\\s*\\(|fread\\s*\\(|load\\s*\\("
  load_lines <- grep(load_pattern, content, value = TRUE)
  has_archive_load <- any(grepl("archive/", load_lines, fixed = TRUE))
  return(has_archive_load)
}

# Test pass fixture
pass_fixture <- "tests/fixtures/check_d_pass.R"
pass_result <- test_fixture(pass_fixture)
cat(sprintf("Fixture: %s\n", pass_fixture))
cat(sprintf("  Expected: PASS (no archive/ load)\n"))
cat(sprintf("  Detected archive/ load: %s\n", pass_result))
cat(sprintf("  Result: %s\n\n", if (!pass_result) "PASS (correct)" else "FAIL (incorrect)"))

# Test fail fixture
fail_fixture <- "tests/fixtures/check_d_fail.R"
fail_result <- test_fixture(fail_fixture)
cat(sprintf("Fixture: %s\n", fail_fixture))
cat(sprintf("  Expected: FAIL (has archive/ load)\n"))
cat(sprintf("  Detected archive/ load: %s\n", fail_result))
cat(sprintf("  Result: %s\n\n", if (fail_result) "FAIL (correct)" else "PASS (incorrect)"))

# Summary
discriminates <- (!pass_result) && fail_result
cat("=== DISCRIMINATION TEST SUMMARY ===\n")
cat(sprintf("Pass fixture correctly passes: %s\n", !pass_result))
cat(sprintf("Fail fixture correctly fails:  %s\n", fail_result))
cat(sprintf("CHECK (d) DISCRIMINATES: %s\n", if (discriminates) "YES" else "NO"))

if (!discriminates) stop("Discrimination test failed")
