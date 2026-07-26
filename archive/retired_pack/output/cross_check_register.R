# cross_check_register.R
# Verifies:
# 1. No superseded value appears as canonical
# 2. T1 cells match canonical_facts values (with t1_val comparison, mismatches = errors)
# 3. T1 gate assertions pass

library(stringr)

# Read files
canonical <- readLines("canonical_facts.md")
register <- readLines("invalidation_register.md")
t1 <- read.csv("T1_correction_path.csv", stringsAsFactors = FALSE)

# =============================================================================
# PART 1: Register vs Facts cross-check
# =============================================================================
cat("=== PART 1: REGISTER VS FACTS ===\n\n")

# Extract canonical values (from table rows)
canonical_values <- c()
for (line in canonical) {
  if (grepl("^\\|\\s*[A-Z_]+\\s*\\|", line) && !grepl("^\\|\\s*ID\\s*\\|", line)) {
    parts <- str_split(line, "\\|")[[1]]
    if (length(parts) >= 4) {
      id <- str_trim(parts[2])
      value <- str_trim(parts[4])
      canonical_values <- c(canonical_values, setNames(value, id))
    }
  }
}

# Extract superseded values from register
superseded_values <- c()
for (line in register) {
  if (grepl("^\\|\\s*INV-", line)) {
    parts <- str_split(line, "\\|")[[1]]
    if (length(parts) >= 8) {
      original <- str_trim(parts[3])  # Original Value column
      superseded_values <- c(superseded_values, original)
    }
  }
}

# Cross-check: no superseded value should appear as canonical
errors_p1 <- 0
for (sv in superseded_values) {
  for (cv_name in names(canonical_values)) {
    cv <- canonical_values[cv_name]
    if (grepl(sv, cv, fixed = TRUE) && !grepl("OBSERVED|_RAW", cv_name)) {
      cat(sprintf("ERROR: Superseded value '%s' appears in canonical %s\n", sv, cv_name))
      errors_p1 <- errors_p1 + 1
    }
  }
}

if (errors_p1 == 0) {
  cat("PASS: No superseded value appears as canonical.\n")
} else {
  cat(sprintf("FAIL: %d conflicts found.\n", errors_p1))
}
cat("Superseded values checked:", length(superseded_values), "\n")
cat("Canonical entries checked:", length(canonical_values), "\n\n")

# =============================================================================
# PART 2: T1 cells vs canonical_facts (t1_val comparison, mismatches = errors)
# =============================================================================
cat("=== PART 2: T1 VS CANONICAL_FACTS ===\n\n")

errors_p2 <- 0

# Define expected mappings: T1 row -> column -> expected numeric value -> fact name
t1_checks <- list(
  list(row = "A (log-ratio)", col = "Mean", expected = -0.2738, fact = "THETA_A_CANONICAL"),
  list(row = "A (log-ratio)", col = "SD", expected = 1.6641, fact = "THETA_A_CANONICAL"),
  list(row = "A (log-ratio)", col = "SplitHalf_r", expected = 0.9720, fact = "SPLITHALF_A_FRESH"),
  list(row = "A (log-ratio)", col = "Placebo_Mean", expected = -0.7121, fact = "PLACEBO_A_CANONICAL"),
  list(row = "A (log-ratio)", col = "Placebo_SD", expected = 1.1165, fact = "PLACEBO_A_CANONICAL"),
  list(row = "D (canonical)", col = "Mean", expected = 0.2138, fact = "MEAN_THETA"),
  list(row = "D (canonical)", col = "SD", expected = 0.5950, fact = "SD_RAW"),
  list(row = "D (canonical)", col = "SplitHalf_r", expected = NA, fact = "D_SPLITHALF (NA expected)")
)

for (check in t1_checks) {
  t1_row <- t1[t1$Definition == check$row, ]
  if (nrow(t1_row) == 0) {
    cat(sprintf("ERROR: T1 row '%s' not found\n", check$row))
    errors_p2 <- errors_p2 + 1
    next
  }

  t1_val <- t1_row[[check$col]][1]
  expected_val <- check$expected

  # Handle NA comparison
  if (is.na(expected_val) && is.na(t1_val)) {
    cat(sprintf("PASS: T1[%s,%s] = NA matches %s\n", check$row, check$col, check$fact))
  } else if (is.na(expected_val) || is.na(t1_val)) {
    cat(sprintf("ERROR: T1[%s,%s] = %s vs expected %s (%s)\n",
                check$row, check$col, t1_val, expected_val, check$fact))
    errors_p2 <- errors_p2 + 1
  } else if (abs(t1_val - expected_val) < 1e-4) {
    cat(sprintf("PASS: T1[%s,%s] = %s matches %s\n", check$row, check$col, t1_val, check$fact))
  } else {
    cat(sprintf("ERROR: T1[%s,%s] = %s vs expected %s (%s)\n",
                check$row, check$col, t1_val, expected_val, check$fact))
    errors_p2 <- errors_p2 + 1
  }
}

cat("\n")

# =============================================================================
# PART 3: T1 Gate Assertions
# =============================================================================
cat("=== PART 3: T1 GATE ASSERTIONS ===\n\n")

errors_p3 <- 0

# T1_A_mean in [-0.284, -0.264]
t1_a <- t1[t1$Definition == "A (log-ratio)", ]
t1_a_mean <- t1_a$Mean[1]
if (t1_a_mean >= -0.284 && t1_a_mean <= -0.264) {
  cat(sprintf("PASS: T1_A_mean = %.4f in [-0.284, -0.264]\n", t1_a_mean))
} else {
  cat(sprintf("FAIL: T1_A_mean = %.4f NOT in [-0.284, -0.264]\n", t1_a_mean))
  errors_p3 <- errors_p3 + 1
}

# T1_A_sd in [1.61, 1.71]
t1_a_sd <- t1_a$SD[1]
if (t1_a_sd >= 1.61 && t1_a_sd <= 1.71) {
  cat(sprintf("PASS: T1_A_sd = %.4f in [1.61, 1.71]\n", t1_a_sd))
} else {
  cat(sprintf("FAIL: T1_A_sd = %.4f NOT in [1.61, 1.71]\n", t1_a_sd))
  errors_p3 <- errors_p3 + 1
}

cat("\n")

# =============================================================================
# SUMMARY
# =============================================================================
cat("=== SUMMARY ===\n\n")
total_errors <- errors_p1 + errors_p2 + errors_p3
cat(sprintf("Part 1 (Register vs Facts): %d errors\n", errors_p1))
cat(sprintf("Part 2 (T1 vs Facts): %d errors\n", errors_p2))
cat(sprintf("Part 3 (T1 Gates): %d errors\n", errors_p3))
cat(sprintf("Total: %d errors\n\n", total_errors))

stopifnot(total_errors == 0)
cat("All cross-checks PASSED.\n")
