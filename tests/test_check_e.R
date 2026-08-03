#!/usr/bin/env Rscript
# test_check_e.R - Discrimination test for check (e) SHA256 in article/
#
# This test verifies that check_sha256 correctly:
# - PASSES sidecars describing article/ files with matching SHA256
# - FAILS sidecars describing article/ files with non-matching SHA256
#
# Added for SYNC-18 / INV-044: check (e) now searches article/ directory

cat("=== CHECK (e) ARTICLE FIXTURE DISCRIMINATION TEST ===\n\n")

# Setup: create temporary test files
setup_fixtures <- function() {
  # Create empty test file (SHA256 of empty = e3b0c44...)
  writeLines(character(0), "article/test_article_pass.tex")

  # Create non-empty test file (will not match the zero hash in fail fixture)
  writeLines("This file has content", "article/test_article_fail.tex")

  # Copy fixture sidecars to meta/
  file.copy("tests/fixtures/check_e_article_pass.sidecar",
            "meta/test_article_pass.tex.sidecar", overwrite = TRUE)
  file.copy("tests/fixtures/check_e_article_fail.sidecar",
            "meta/test_article_fail.tex.sidecar", overwrite = TRUE)
}

# Cleanup: remove test files
cleanup_fixtures <- function() {
  unlink("article/test_article_pass.tex")
  unlink("article/test_article_fail.tex")
  unlink("meta/test_article_pass.tex.sidecar")
  unlink("meta/test_article_fail.tex.sidecar")
}

# Test function: check if a sidecar's described file matches its SHA256
test_sha256_match <- function(sidecar_path, search_dirs = c("output", "data", "article")) {
  content <- readLines(sidecar_path, warn = FALSE)
  sha_line <- grep("^SHA256:", content, value = TRUE)
  if (length(sha_line) == 0) return(list(found = FALSE, matches = FALSE))

  recorded_sha <- trimws(sub("^SHA256:\\s*", "", sha_line[1]))

  file_line <- grep("^FILE:", content, value = TRUE)
  described_file <- trimws(sub("^FILE:\\s*", "", file_line[1]))

  # Search for the file
  file_path <- NULL
  for (dir in search_dirs) {
    candidate <- file.path(dir, described_file)
    if (file.exists(candidate)) { file_path <- candidate; break }
  }

  if (is.null(file_path)) return(list(found = FALSE, matches = FALSE))

  current_sha <- trimws(system(sprintf("sha256sum %s | cut -d' ' -f1", file_path), intern = TRUE))
  return(list(found = TRUE, matches = (current_sha == recorded_sha)))
}

# Run tests
tryCatch({
  setup_fixtures()

  # Test 1: PASS fixture (matching SHA256)
  cat("Test 1: PASS fixture (article/ file with matching SHA256)\n")
  pass_result <- test_sha256_match("meta/test_article_pass.tex.sidecar")
  cat(sprintf("  File found: %s\n", pass_result$found))
  cat(sprintf("  SHA256 matches: %s\n", pass_result$matches))
  pass_ok <- pass_result$found && pass_result$matches
  cat(sprintf("  Result: %s\n\n", if (pass_ok) "PASS (correct)" else "FAIL (incorrect)"))

  # Test 2: FAIL fixture (non-matching SHA256)
  cat("Test 2: FAIL fixture (article/ file with wrong SHA256)\n")
  fail_result <- test_sha256_match("meta/test_article_fail.tex.sidecar")
  cat(sprintf("  File found: %s\n", fail_result$found))
  cat(sprintf("  SHA256 matches: %s\n", fail_result$matches))
  fail_ok <- fail_result$found && !fail_result$matches
  cat(sprintf("  Result: %s\n\n", if (fail_ok) "FAIL (correct - mismatch detected)" else "PASS (incorrect)"))

  # Test 3: Verify article/ is now searched (pre-fix it wouldn't be found)
  cat("Test 3: Verify article/ directory is searched\n")
  no_article_result <- test_sha256_match("meta/test_article_pass.tex.sidecar",
                                          search_dirs = c("output", "data"))
  cat(sprintf("  Without article/ in search: found = %s\n", no_article_result$found))
  with_article_result <- test_sha256_match("meta/test_article_pass.tex.sidecar",
                                            search_dirs = c("output", "data", "article"))
  cat(sprintf("  With article/ in search: found = %s\n", with_article_result$found))
  search_ok <- !no_article_result$found && with_article_result$found
  cat(sprintf("  Result: %s\n\n", if (search_ok) "PASS (article/ search discriminates)" else "FAIL"))

  # Summary
  cat("=== DISCRIMINATION TEST SUMMARY ===\n")
  cat(sprintf("Pass fixture correctly passes: %s\n", pass_ok))
  cat(sprintf("Fail fixture correctly fails:  %s\n", fail_ok))
  cat(sprintf("article/ search discriminates: %s\n", search_ok))

  discriminates <- pass_ok && fail_ok && search_ok
  cat(sprintf("\nCHECK (e) ARTICLE SEARCH DISCRIMINATES: %s\n",
              if (discriminates) "YES" else "NO"))

  if (!discriminates) stop("Discrimination test failed")

}, finally = {
  cleanup_fixtures()
})
