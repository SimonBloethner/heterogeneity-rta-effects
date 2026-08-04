#!/usr/bin/env Rscript
# test_check_i.R - Discrimination test for check (i) registry existence
#
# This test verifies that check_registry_existence correctly:
# - PASSES when an absent file is allowlisted
# - FAILS when an absent file is not allowlisted
#
# Added for SYNC-25 / INV-046: check (i) verifies all registry rows exist

cat("=== CHECK (i) EXISTENCE FIXTURE DISCRIMINATION TEST ===\n\n")

library(data.table)

# Source the check function
source("code/enforce.R", local = TRUE)

# Setup: create temporary test environment
setup_test_env <- function() {
    tmp_dir <- tempdir()
    tmp_meta <- file.path(tmp_dir, "meta")
    dir.create(tmp_meta, showWarnings = FALSE, recursive = TRUE)
    return(tmp_dir)
}

# Test 1: PASS - allowlisted absent file
test_pass <- function() {
    cat("Test 1: Allowlisted absent file (should PASS)\n")

    tmp_dir <- setup_test_env()
    tmp_meta <- file.path(tmp_dir, "meta")

    # Read the pass fixture
    fixture <- fread("tests/fixtures/check_i_existence_pass.csv")
    fwrite(fixture, file.path(tmp_meta, "FILE_REGISTRY.csv"))

    # Create allowlist with the fixture path
    writeLines(c(
        "# Test allowlist",
        "data/FIXTURE_ALLOWLISTED_ABSENT.rds"
    ), file.path(tmp_meta, "EXISTENCE_ALLOWLIST.txt"))

    # Run check - should pass (no violations)
    v <- check_registry_existence(tmp_dir, report = TRUE)

    if (length(v) == 0) {
        cat("  PASS: No violations (allowlisted file correctly skipped)\n\n")
        return(TRUE)
    } else {
        cat("  FAIL: Unexpected violations:\n")
        for (x in v) cat("    ", x, "\n")
        return(FALSE)
    }
}

# Test 2: FAIL - non-allowlisted absent file
test_fail <- function() {
    cat("Test 2: Non-allowlisted absent file (should FAIL)\n")

    tmp_dir <- setup_test_env()
    tmp_meta <- file.path(tmp_dir, "meta")

    # Read the fail fixture
    fixture <- fread("tests/fixtures/check_i_existence_fail.csv")
    fwrite(fixture, file.path(tmp_meta, "FILE_REGISTRY.csv"))

    # Create empty allowlist (no exemptions)
    writeLines(c("# Empty allowlist"), file.path(tmp_meta, "EXISTENCE_ALLOWLIST.txt"))

    # Run check - should fail (violation for missing file)
    v <- check_registry_existence(tmp_dir, report = TRUE)

    if (length(v) > 0 && any(grepl("FIXTURE_NONEXISTENT_SCRIPT", v))) {
        cat("  PASS: Violation correctly fired for non-allowlisted absent file\n\n")
        return(TRUE)
    } else {
        cat("  FAIL: Expected violation not fired\n")
        return(FALSE)
    }
}

# Run tests
cat("Running discrimination tests...\n\n")

pass1 <- test_pass()
pass2 <- test_fail()

cat("=== RESULTS ===\n")
cat(sprintf("Test 1 (allowlisted pass): %s\n", if (pass1) "PASS" else "FAIL"))
cat(sprintf("Test 2 (non-allowlisted fail): %s\n", if (pass2) "PASS" else "FAIL"))

if (pass1 && pass2) {
    cat("\n=== ALL DISCRIMINATION TESTS PASS ===\n")
} else {
    stop("Discrimination tests failed")
}
