#!/usr/bin/env Rscript
# S45_ledger_constants.R - Generate main body macros from canonical_facts.md
# Emits: article/ledger_constants.tex (30 macros)
# Gates: G1 (all IDs resolve), G2 (string identity), G3 (no Prop*/Atwo* collision), G4 (round-trip)

# =============================================================================
# Configuration
# =============================================================================
RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot("RTA_ROOT must contain meta/FILE_REGISTRY.csv" =
              file.exists(file.path(RTA_ROOT, "meta/FILE_REGISTRY.csv")))

LEDGER_PATH <- file.path(RTA_ROOT, "meta/canonical_facts.md")
OUTPUT_PATH <- file.path(RTA_ROOT, "article/ledger_constants.tex")

# Macro definitions: name -> (ledger_id, precision, is_integer, is_interval)
# is_integer = TRUE for counts that should render as bare integers
# is_interval = TRUE for [lo, hi] intervals that need extraction of endpoints
MACROS <- list(
    # Population
    LedgerN = list(id = "N", precision = 0, is_integer = TRUE, is_interval = FALSE),

    # Effect distribution
    LedgerMeanThetaD = list(id = "MEAN_THETA_D", precision = 4, is_integer = FALSE, is_interval = FALSE),
    LedgerMeanThetaDSE = list(id = "MEAN_THETA_D", precision = 4, is_integer = FALSE, is_interval = FALSE, extract_se = TRUE),
    LedgerSDTrueLo = list(id = "SD_THETA_TRUE", precision = 2, is_integer = FALSE, is_interval = TRUE, which_endpoint = "lo"),
    LedgerSDTrueHi = list(id = "SD_THETA_TRUE", precision = 2, is_integer = FALSE, is_interval = TRUE, which_endpoint = "hi"),
    LedgerRawShare = list(id = "RAW_SHARE", precision = 4, is_integer = FALSE, is_interval = FALSE),
    LedgerTWMean = list(id = "TW_MEAN", precision = 4, is_integer = FALSE, is_interval = FALSE),

    # P(theta <= 0) bracket
    LedgerPLo = list(id = "P_LO", precision = 3, is_integer = FALSE, is_interval = FALSE),
    LedgerPHi = list(id = "P_HI", precision = 3, is_integer = FALSE, is_interval = FALSE),

    # Specification spread (SPEC_SPREAD is [1.402, 0.922, 0.411, 0.095])
    LedgerSpecB = list(id = "SPEC_SPREAD", precision = 3, is_integer = FALSE, is_interval = TRUE, which_endpoint = 1),
    LedgerSpecC = list(id = "SPEC_SPREAD", precision = 3, is_integer = FALSE, is_interval = TRUE, which_endpoint = 2),
    LedgerSpecCY = list(id = "SPEC_SPREAD", precision = 3, is_integer = FALSE, is_interval = TRUE, which_endpoint = 3),
    LedgerSpecFull = list(id = "SPEC_SPREAD", precision = 3, is_integer = FALSE, is_interval = TRUE, which_endpoint = 4),

    # Gradient
    LedgerGradient = list(id = "GRADIENT", precision = 4, is_integer = FALSE, is_interval = FALSE),
    LedgerGradientSE = list(id = "GRADIENT", precision = 4, is_integer = FALSE, is_interval = FALSE, extract_se = TRUE),
    LedgerGradientB = list(id = "GRADIENT_B", precision = 4, is_integer = FALSE, is_interval = FALSE),
    LedgerGradientBSE = list(id = "GRADIENT_B", precision = 4, is_integer = FALSE, is_interval = FALSE, extract_se = TRUE),
    LedgerGradientQOne = list(id = "GRADIENT_Q1", precision = 4, is_integer = FALSE, is_interval = FALSE),
    LedgerGradientQOneSE = list(id = "GRADIENT_Q1", precision = 4, is_integer = FALSE, is_interval = FALSE, extract_se = TRUE),
    LedgerGradientQFive = list(id = "GRADIENT_Q5", precision = 4, is_integer = FALSE, is_interval = FALSE),
    LedgerGradientQFiveSE = list(id = "GRADIENT_Q5", precision = 4, is_integer = FALSE, is_interval = FALSE, extract_se = TRUE),
    LedgerGradientBShare = list(id = "GRADIENT_B_SHARE", precision = 4, is_integer = FALSE, is_interval = FALSE),

    # Derived percentage macros (exp(x) - 1) * 100
    LedgerMeanThetaDPct = list(id = "MEAN_THETA_D", precision = 1, is_integer = FALSE, is_interval = FALSE, derive_pct = TRUE),
    LedgerTWMeanPct = list(id = "TW_MEAN", precision = 1, is_integer = FALSE, is_interval = FALSE, derive_pct = TRUE),
    LedgerGradientQOnePct = list(id = "GRADIENT_Q1", precision = 0, is_integer = FALSE, is_interval = FALSE, derive_pct = TRUE),
    LedgerGradientQFivePct = list(id = "GRADIENT_Q5", precision = 1, is_integer = FALSE, is_interval = FALSE, derive_pct = TRUE),

    # Reliability
    LedgerSplithalfR = list(id = "SPLITHALF_A_R", precision = 4, is_integer = FALSE, is_interval = FALSE),
    LedgerPlaceboR = list(id = "PLACEBO_A_R", precision = 4, is_integer = FALSE, is_interval = FALSE),

    # Jensen/reliability parameters (not colliding with Prop* in prop_constants.tex)
    LedgerEsigmaSq = list(id = "ESIGMA2", precision = 4, is_integer = FALSE, is_interval = FALSE),
    LedgerSigma = list(id = "SIGMA", precision = 4, is_integer = FALSE, is_interval = FALSE)
)

# Expected values for verification (at stated precision)
EXPECTED <- list(
    LedgerN = 4182,
    LedgerMeanThetaD = 0.2473,
    LedgerMeanThetaDSE = 0.0241,
    LedgerSDTrueLo = 0.74,
    LedgerSDTrueHi = 1.48,
    LedgerRawShare = 0.4211,
    LedgerTWMean = 0.0898,
    LedgerPLo = 0.370,
    LedgerPHi = 0.421,
    LedgerSpecB = 1.402,
    LedgerSpecC = 0.922,
    LedgerSpecCY = 0.411,
    LedgerSpecFull = 0.095,
    LedgerGradient = 0.9137,
    LedgerGradientSE = 0.0809,
    LedgerGradientB = 0.6827,
    LedgerGradientBSE = 0.0821,
    LedgerGradientQOne = 0.8554,
    LedgerGradientQOneSE = 0.0760,
    LedgerGradientQFive = -0.0583,
    LedgerGradientQFiveSE = 0.0277,
    LedgerGradientBShare = 0.7472,
    LedgerMeanThetaDPct = 28.1,
    LedgerTWMeanPct = 9.4,
    LedgerGradientQOnePct = 135,
    LedgerGradientQFivePct = -5.7,
    LedgerSplithalfR = 0.9243,
    LedgerPlaceboR = 0.7463,
    LedgerEsigmaSq = 1.3642,
    LedgerSigma = 1.1680
)

# =============================================================================
# Parse ledger
# =============================================================================
cat("Reading ledger:", LEDGER_PATH, "\n")
ledger <- readLines(LEDGER_PATH)

parse_ledger_value <- function(ledger_id, extract_se = FALSE, is_interval = FALSE, which_endpoint = NULL) {
    # Pattern: | ID | description | value | ... |
    pattern <- sprintf("^\\| %s \\|", ledger_id)
    line <- grep(pattern, ledger, value = TRUE)

    if (length(line) == 0) {
        return(NULL)
    }

    # Split by | and extract columns
    parts <- strsplit(line, "\\|")[[1]]
    # Find the value column index - it's the first numeric-looking field after ID
    value_idx <- NULL
    value_str <- NULL
    for (i in 3:length(parts)) {
        candidate <- trimws(parts[i])
        # Check if this looks like a value (number, interval, or number with SE)
        if (grepl("^[\\[0-9.-]", candidate)) {
            value_idx <- i
            value_str <- candidate
            break
        }
    }

    if (is.null(value_str)) {
        return(NULL)
    }

    # Handle interval [lo, hi]
    if (is_interval) {
        if (grepl("^\\[", value_str)) {
            # Extract numbers from [x, y, z, ...] format
            nums <- as.numeric(regmatches(value_str, gregexpr("[0-9.-]+", value_str))[[1]])
            if (is.character(which_endpoint)) {
                # "lo" or "hi" for 2-element intervals
                if (which_endpoint == "lo") return(nums[1])
                if (which_endpoint == "hi") return(nums[length(nums)])
            } else if (is.numeric(which_endpoint)) {
                # Numeric index for n-element arrays
                return(nums[which_endpoint])
            }
        }
        return(NULL)
    }

    # Handle SE extraction: check the column immediately after the value column
    if (extract_se) {
        # First try parenthetical format: "0.1234 (SE 0.001)"
        se_match <- regmatches(value_str, regexec("\\(SE ([0-9.]+)\\)", value_str))[[1]]
        if (length(se_match) > 1) {
            return(as.numeric(se_match[2]))
        }
        # Check the column immediately after value for SE
        if (!is.null(value_idx) && value_idx + 1 <= length(parts)) {
            se_candidate <- trimws(parts[value_idx + 1])
            # SE is typically 0.0XXX format
            if (grepl("^0\\.[0-9]+$", se_candidate)) {
                return(as.numeric(se_candidate))
            }
        }
        return(NULL)
    }

    # Standard value: strip SE if present
    value_str <- sub("\\s*\\(SE.*$", "", value_str)
    as.numeric(value_str)
}

# =============================================================================
# G1: All IDs must resolve
# =============================================================================
cat("\n=== G1: Parsing ledger IDs ===\n")
parsed_values <- list()
for (macro_name in names(MACROS)) {
    cfg <- MACROS[[macro_name]]
    val <- parse_ledger_value(
        cfg$id,
        extract_se = isTRUE(cfg$extract_se),
        is_interval = isTRUE(cfg$is_interval),
        which_endpoint = cfg$which_endpoint
    )

    if (is.null(val) || is.na(val)) {
        stop(sprintf("G1 FAIL: Ledger ID '%s' (macro \\%s) not found or unparseable", cfg$id, macro_name))
    }

    # Apply derive_pct transformation: (exp(x) - 1) * 100
    if (isTRUE(cfg$derive_pct)) {
        val <- (exp(val) - 1) * 100
    }

    parsed_values[[macro_name]] <- val
    cat(sprintf("  %s -> \\%s = %s\n", cfg$id, macro_name, val))
}
cat("G1: PASS - all 30 IDs resolve\n")
stopifnot("G1: exactly 30 macros defined" = length(parsed_values) == 30)

# =============================================================================
# G2: String identity (not numeric tolerance)
# =============================================================================
cat("\n=== G2: Verifying string identity against expected values ===\n")
for (macro_name in names(EXPECTED)) {
    cfg <- MACROS[[macro_name]]
    parsed <- parsed_values[[macro_name]]
    expected <- EXPECTED[[macro_name]]

    # Round parsed to stated precision
    rounded <- round(parsed, cfg$precision)

    # Format both to string at stated precision for identity comparison
    if (isTRUE(cfg$is_integer) || cfg$precision == 0) {
        parsed_str <- as.character(as.integer(rounded))
        expected_str <- as.character(as.integer(expected))
    } else {
        parsed_str <- format(rounded, nsmall = cfg$precision, scientific = FALSE)
        expected_str <- format(expected, nsmall = cfg$precision, scientific = FALSE)
    }

    # String identity comparison - no tolerance
    if (trimws(parsed_str) != trimws(expected_str)) {
        stop(sprintf(
            "G2 FAIL: \\%s parsed_str='%s' expected_str='%s'. Ledger may have moved.",
            macro_name, trimws(parsed_str), trimws(expected_str)
        ))
    }
    cat(sprintf("  \\%s: '%s' == '%s' OK\n", macro_name, trimws(parsed_str), trimws(expected_str)))
}
cat("G2: PASS - all parsed values match expected (string identity)\n")
stopifnot("G2: all 30 values verified" = length(EXPECTED) == 30)

# =============================================================================
# G3: No Prop*/Atwo* collision
# =============================================================================
cat("\n=== G3: Checking for namespace collisions ===\n")
forbidden_prefixes <- c("^Prop", "^Atwo", "^MomPow", "^Holdout")
for (macro_name in names(MACROS)) {
    for (prefix in forbidden_prefixes) {
        if (grepl(prefix, macro_name)) {
            stop(sprintf("G3 FAIL: Macro \\%s collides with forbidden prefix '%s'", macro_name, prefix))
        }
    }
}
cat("G3: PASS - no Prop*/Atwo*/MomPow*/Holdout* collisions\n")

# =============================================================================
# Ensure article/ directory exists
# =============================================================================
if (!dir.exists(file.path(RTA_ROOT, "article"))) {
    dir.create(file.path(RTA_ROOT, "article"))
    cat("Created article/ directory\n")
}

# =============================================================================
# Generate output file
# =============================================================================
cat("\n=== Generating", OUTPUT_PATH, "===\n")

output_lines <- c(
    "% ledger_constants.tex - Auto-generated by S45_ledger_constants.R",
    sprintf("%% Generated: %s", format(Sys.time())),
    "% Main body constants from meta/canonical_facts.md",
    "% DO NOT EDIT - regenerate with: Rscript code/S45_ledger_constants.R",
    ""
)

emitted_values <- list()
for (macro_name in names(MACROS)) {
    cfg <- MACROS[[macro_name]]
    raw_val <- parsed_values[[macro_name]]
    rounded_val <- round(raw_val, cfg$precision)

    # Format the value string
    if (isTRUE(cfg$is_integer)) {
        val_str <- as.character(as.integer(rounded_val))
    } else {
        val_str <- format(rounded_val, nsmall = cfg$precision, scientific = FALSE)
    }

    output_lines <- c(output_lines, sprintf("\\newcommand{\\%s}{%s}", macro_name, val_str))
    emitted_values[[macro_name]] <- rounded_val
    cat(sprintf("  \\%s{%s}\n", macro_name, val_str))
}

writeLines(output_lines, OUTPUT_PATH)
cat("Written to", OUTPUT_PATH, "\n")

# =============================================================================
# G4: Round-trip verification
# =============================================================================
cat("\n=== G4: Round-trip verification ===\n")
emitted_content <- readLines(OUTPUT_PATH)
for (macro_name in names(MACROS)) {
    cfg <- MACROS[[macro_name]]
    pattern <- sprintf("\\\\newcommand\\{\\\\%s\\}\\{([^}]+)\\}", macro_name)
    line <- grep(pattern, emitted_content, value = TRUE)

    if (length(line) == 0) {
        stop(sprintf("G4 FAIL: Macro \\%s not found in emitted file", macro_name))
    }

    match <- regmatches(line, regexec(pattern, line))[[1]]
    reparsed <- as.numeric(match[2])
    original <- emitted_values[[macro_name]]

    if (abs(reparsed - original) > 1e-9) {
        stop(sprintf("G4 FAIL: \\%s round-trip failed: %.6f != %.6f",
                     macro_name, reparsed, original))
    }
    cat(sprintf("  \\%s: %.4f == %.4f OK\n", macro_name, reparsed, original))
}
cat("G4: PASS - all values round-trip correctly\n")

# =============================================================================
# Final verification
# =============================================================================
newcommand_lines <- grep("^\\\\newcommand", emitted_content, value = TRUE)
n_macros <- length(newcommand_lines)
stopifnot("Exactly 30 macros emitted" = n_macros == 30)

cat("\n=== All gates passed ===\n")
cat(sprintf("Emitted %d macros to %s\n", n_macros, OUTPUT_PATH))
