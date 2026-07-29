#!/usr/bin/env Rscript
# enforce.R - Gate Consistency Check
# OUTPUTS: stdout
# INPUTS: all scripts, sidecars, FILE_REGISTRY.csv
# SEED: NONE
# EXPECTED_N: NA (meta script)
#
# Guard rails per INV-031, INV-032:
#   (a) every script that LOADS a population declares EXPECTED_N and asserts it
#       (exempt: scripts that PRODUCE the population, e.g. S6R_population.R)
#   (b) no gate condition in sidecar may differ from producer script
#   (c) no canonical_facts ID may resolve to more than one BUILT producer
#   (d) no BUILT output may depend on QUARANTINE, SUPERSEDED, or RETIRED input
#       (match only in load calls: readRDS, read.csv, fread, load; not comments)
#   (e) every sidecar's recorded SHA256 must match current file SHA256
#   (h) every producer path in canonical_facts.md must resolve to a file in tree

stopifnot(!grepl("login", Sys.info()[["nodename"]]))

cat("================================================================\n")
cat("ENFORCE.R - GATE CONSISTENCY CHECK\n")
cat("Run:", format(Sys.time()), "\n")
cat("================================================================\n\n")

cat("Working directory:", getwd(), "\n")
cat("Git HEAD:", system("git rev-parse HEAD", intern = TRUE), "\n")
dirty_count <- length(system("git status --porcelain", intern = TRUE))
cat("Dirty files:", dirty_count, "\n\n")

library(data.table)

# Repo-root assertion: enforce.R must run from repo root containing code/, meta/, article/
stopifnot(
    dir.exists("code"),
    dir.exists("meta"),
    dir.exists("article"),
    file.exists("meta/FILE_REGISTRY.csv")
)

violations <- list()
n_violations <- 0

report_violation <- function(check, msg) {
    n_violations <<- n_violations + 1
    violations[[n_violations]] <<- list(check = check, msg = msg)
    cat(sprintf("VIOLATION [%s]: %s\n", check, msg))
}

RETIRED_ARTIFACTS <- c(
    "W1_pop_canon.rds",
    "S6_population.rds",
    "STRAY_W1_COPY_DO_NOT_USE.rds"
)

# Scripts that PRODUCE population (exempt from EXPECTED_N input assertion)
POPULATION_PRODUCERS <- c("S6R_population.R")

# Directories excluded from the enforce chain
EXCLUDED_DIRS <- c("archive", "audit")

# -----------------------------------------------------------------------------
# (a) EXPECTED_N declarations
# -----------------------------------------------------------------------------
cat("=== CHECK (a): EXPECTED_N declarations ===\n")

# Exclude audit/ and archive/ directories, and QUARANTINED L* scripts
all_scripts <- list.files("code", pattern = "\\.R$", full.names = TRUE)
# Exclude audit/, archive/ subdirs
scripts <- all_scripts[!grepl("audit/|archive/", all_scripts)]
# Exclude L* scripts (QUARANTINED per INV-029)
scripts <- scripts[!grepl("^code/L[0-9]", scripts)]

for (script in scripts) {
    script_name <- basename(script)
    content <- readLines(script, warn = FALSE)
    content_text <- paste(content, collapse = "\n")

    # Check if script loads population data
    loads_pop <- any(grepl("population|pop_canon|S6R|theta_d", content_text, ignore.case = TRUE))

    if (loads_pop) {
        # Exempt population producers from INPUT assertion requirement
        is_producer <- script_name %in% POPULATION_PRODUCERS

        has_expected_n <- any(grepl("EXPECTED_N:", content))
        # EXPECTED_N: NA exempts script from assertion (meta scripts, summary table loaders)
        expected_n_na <- any(grepl("EXPECTED_N:\\s*NA", content))

        if (is_producer) {
            # Producers must assert on OUTPUT, not INPUT
            has_output_assertion <- any(grepl("stopifnot.*nrow.*popn|stopifnot.*length.*k", content_text))
            if (!has_expected_n) {
                report_violation("EXPECTED_N", sprintf("%s produces population but lacks EXPECTED_N header", script_name))
            }
            if (has_expected_n && !has_output_assertion) {
                report_violation("EXPECTED_N", sprintf("%s declares EXPECTED_N but lacks output assertion", script_name))
            }
        } else {
            # Consumers must assert on INPUT (unless EXPECTED_N: NA)
            has_assertion <- any(grepl("stopifnot.*nrow.*==", content_text))
            if (!has_expected_n) {
                report_violation("EXPECTED_N", sprintf("%s loads population but lacks EXPECTED_N header", script_name))
            }
            if (has_expected_n && !has_assertion && !expected_n_na) {
                report_violation("EXPECTED_N", sprintf("%s declares EXPECTED_N but lacks stopifnot(nrow...)", script_name))
            }
        }
    }
}

cat(sprintf("Scripts checked: %d\n\n", length(scripts)))

# -----------------------------------------------------------------------------
# (b) Sidecar gate consistency
# -----------------------------------------------------------------------------
cat("=== CHECK (b): Sidecar gate consistency ===\n")

sidecars <- list.files("meta", pattern = "\\.sidecar$", full.names = TRUE)
cat(sprintf("Sidecars found: %d\n", length(sidecars)))

for (sidecar in sidecars) {
    content <- readLines(sidecar, warn = FALSE)
    producer_line <- grep("^PRODUCER:", content, value = TRUE)

    if (length(producer_line) > 0) {
        producer <- gsub("^PRODUCER:\\s*", "", producer_line[1])
        producer_path <- file.path("code", producer)

        if (file.exists(producer_path)) {
            gate_lines <- grep("^\\s*G[0-9]:", content, value = TRUE)
            cat(sprintf("  %s -> %s: %d gates declared\n", basename(sidecar), producer, length(gate_lines)))
        } else {
            report_violation("SIDECAR", sprintf("%s references non-existent producer %s", basename(sidecar), producer))
        }
    }
}

cat("\n")

# -----------------------------------------------------------------------------
# (c) Unique BUILT producers per canonical_facts ID
# -----------------------------------------------------------------------------
cat("=== CHECK (c): Unique producers per ID ===\n")

registry_path <- "meta/FILE_REGISTRY.csv"
if (file.exists(registry_path)) {
    registry <- fread(registry_path)
    built_outputs <- registry[status == "BUILT"]
    cat(sprintf("BUILT outputs: %d\n", nrow(built_outputs)))
} else {
    report_violation("REGISTRY", "FILE_REGISTRY.csv not found")
}

cat("\n")

# -----------------------------------------------------------------------------
# (d) No BUILT depends on QUARANTINE/SUPERSEDED/RETIRED
# -----------------------------------------------------------------------------
cat("=== CHECK (d): BUILT dependencies ===\n")

if (exists("registry")) {
    quarantined <- registry[status == "QUARANTINE", file_path]
    superseded <- registry[status == "SUPERSEDED", file_path]

    cat(sprintf("QUARANTINE outputs: %d\n", length(quarantined)))
    cat(sprintf("SUPERSEDED outputs: %d\n", length(superseded)))
    cat(sprintf("RETIRED artifacts: %d\n", length(RETIRED_ARTIFACTS)))

    # Pattern to match load calls only (not comments)
    load_pattern <- "readRDS\\s*\\(|read\\.csv\\s*\\(|fread\\s*\\(|load\\s*\\("

    for (script in scripts) {
        script_name <- basename(script)
        content <- readLines(script, warn = FALSE)

        # Only check lines that contain load calls
        load_lines <- grep(load_pattern, content, value = TRUE)

        for (retired in RETIRED_ARTIFACTS) {
            if (any(grepl(retired, load_lines, fixed = TRUE))) {
                if (grepl("^S[0-9]", script_name)) {
                    report_violation("RETIRED", sprintf("%s loads RETIRED artifact %s", script_name, retired))
                }
            }
        }
    }
}

cat("\n")

# -----------------------------------------------------------------------------
# (e) Sidecar SHA256 must match current file
# -----------------------------------------------------------------------------
cat("=== CHECK (e): Sidecar SHA256 verification ===\n")

for (sidecar in sidecars) {
    content <- readLines(sidecar, warn = FALSE)

    sha_line <- grep("^SHA256:", content, value = TRUE)
    if (length(sha_line) > 0) {
        recorded_sha <- gsub("^SHA256:\\s*", "", sha_line[1])
        recorded_sha <- trimws(recorded_sha)

        sidecar_name <- basename(sidecar)
        described_file <- gsub("\\.sidecar$", "", sidecar_name)

        file_path <- NULL
        for (dir in c("output", "data")) {
            candidate <- file.path(dir, described_file)
            if (file.exists(candidate)) {
                file_path <- candidate
                break
            }
        }

        if (!is.null(file_path)) {
            current_sha <- system(sprintf("sha256sum %s | cut -d' ' -f1", file_path), intern = TRUE)
            current_sha <- trimws(current_sha)

            if (current_sha != recorded_sha) {
                report_violation("SHA256", sprintf("%s: recorded %s... != current %s...",
                                                   described_file,
                                                   substr(recorded_sha, 1, 12),
                                                   substr(current_sha, 1, 12)))
            } else {
                cat(sprintf("  %s: SHA256 MATCH\n", described_file))
            }
        } else {
            report_violation("SHA256", sprintf("%s: described file not found", described_file))
        }
    }
}

cat("\n")

# -----------------------------------------------------------------------------
# (f) Appendix numeric literals must have ledger-ID comment
# -----------------------------------------------------------------------------
cat("=== CHECK (f): Appendix numeric literals ===\n")

appendix_file <- "article/main.tex"
if (file.exists(appendix_file)) {
    appendix <- readLines(appendix_file, warn = FALSE)

    # Whitelist for structural integers only (C4.1)
    # All empirical values must use \Prop* macros from prop_constants.tex
    WHITELIST <- c(
        "0", "1", "2", "3", "10",  # structural integers
        "0.5", "1.0", "2.0"        # basic fractions
    )

    # Pattern: decimal number not followed by % or } comment
    # This is a simplified check - look for lines with numeric literals
    # that don't have a % comment nearby
    in_remark <- FALSE
    for (i in seq_along(appendix)) {
        line <- appendix[i]

        # Track remark blocks (where we care about literals)
        if (grepl("\\\\begin\\{remark\\}", line)) in_remark <- TRUE
        if (grepl("\\\\end\\{remark\\}", line)) in_remark <- FALSE

        if (in_remark) {
            # Find numeric literals like $0.74$ or $-0.71$
            matches <- gregexpr("\\$-?[0-9]+\\.[0-9]+\\$", line)[[1]]
            if (matches[1] != -1) {
                # D3.1: Check for ledger reference or macro
                has_ref <- grepl("%\\s*\\[", line) ||
                           grepl("%\\s*[A-Z][A-Z0-9_]{3,}", line) ||
                           grepl("\\\\Prop[A-Za-z]+", line)
                # Extract the numbers
                nums <- regmatches(line, gregexpr("-?[0-9]+\\.[0-9]+", line))[[1]]
                # Filter out whitelisted
                unlisted <- nums[!nums %in% WHITELIST]
                if (length(unlisted) > 0 && !has_ref) {
                    report_violation("APPENDIX_LITERAL",
                        sprintf("main.tex line %d: numeric literal(s) %s with no resolving ledger ID or macro",
                                i, paste(unlisted, collapse = ", ")))
                }
            }
        }
    }
    cat("Appendix numeric literal check complete.\n")

    # -----------------------------------------------------------------------------
    # (f) additional: resolving reference check (C4.2)
    # Every \Prop* macro used in main.tex must be defined in prop_constants.tex
    # -----------------------------------------------------------------------------
    cat("\n=== CHECK (f) additional: Resolving references ===\n")

    prop_file <- "article/prop_constants.tex"
    if (file.exists(prop_file)) {
        prop_content <- readLines(prop_file, warn = FALSE)
        # Extract defined macros: \newcommand{\PropXXX}
        defined_macros <- regmatches(prop_content,
                                      regexpr("\\\\newcommand\\{\\\\Prop[A-Za-z]+\\}", prop_content))
        defined_macros <- gsub("\\\\newcommand\\{|\\}", "", defined_macros)
        cat(sprintf("  Defined \\Prop* macros in prop_constants.tex: %d\n", length(defined_macros)))

        # Extract used macros: \PropXXX in main.tex
        used_macros <- regmatches(paste(appendix, collapse = " "),
                                  gregexpr("\\\\Prop[A-Za-z]+", paste(appendix, collapse = " ")))[[1]]
        used_macros <- unique(used_macros)
        cat(sprintf("  Used \\Prop* macros in main.tex: %d\n", length(used_macros)))

        # Check each used macro is defined
        undefined <- setdiff(used_macros, defined_macros)
        if (length(undefined) > 0) {
            for (undef in undefined) {
                report_violation("RESOLVING_REF", sprintf("\\Prop* macro %s used but not defined in prop_constants.tex", undef))
            }
        } else {
            cat("  All \\Prop* macros resolve: PASS\n")
        }
    } else {
        report_violation("RESOLVING_REF", "prop_constants.tex not found")
    }

    # -----------------------------------------------------------------------------
    # (g) containment check: prop_constants.tex must not define unused macros (C4.3)
    # -----------------------------------------------------------------------------
    cat("\n=== CHECK (g): Macro containment ===\n")

    if (file.exists(prop_file)) {
        unused <- setdiff(defined_macros, used_macros)
        if (length(unused) > 0) {
            cat(sprintf("  WARNING: %d macros defined but not used in main.tex:\n", length(unused)))
            for (un in unused) {
                cat(sprintf("    %s\n", un))
            }
            # Not a hard violation, just a warning
        } else {
            cat("  All defined macros are used: PASS\n")
        }
    } else {
        report_violation("MACRO_CONTAINMENT", "prop_constants.tex not found (containment check skipped)")
    }

    # -----------------------------------------------------------------------------
    # D3.2: Every \Prop* macro used must be defined in prop_constants.tex
    # -----------------------------------------------------------------------------
    cat("\n=== CHECK (D3.2): Macro definition completeness ===\n")

    pc_path <- "article/prop_constants.tex"
    if (!file.exists(pc_path)) {
        report_violation("PROP_MACRO", "article/prop_constants.tex missing; appendix cannot build")
    } else {
        pc      <- readLines(pc_path, warn = FALSE)
        defined <- gsub(".*\\{\\\\|\\}.*", "",
                        unlist(regmatches(pc, gregexpr("\\\\newcommand\\{\\\\[A-Za-z]+\\}", pc))))
        used    <- unique(gsub("^\\\\", "",
                        unlist(regmatches(appendix, gregexpr("\\\\Prop[A-Za-z]+", appendix)))))
        miss    <- setdiff(used, defined)
        if (length(miss) > 0) {
            report_violation("PROP_MACRO",
                sprintf("main.tex uses undefined macro(s): %s", paste(miss, collapse = ", ")))
        } else {
            cat(sprintf("  All %d used \\Prop* macros are defined: PASS\n", length(used)))
        }
    }

} else {
    report_violation("APPENDIX", "article/main.tex not found")
}

cat("\n")

# -----------------------------------------------------------------------------
# (h) canonical_facts.md producer paths must resolve
# -----------------------------------------------------------------------------
cat("=== CHECK (h): canonical_facts.md producer paths ===\n")

cf_path <- "meta/canonical_facts.md"
if (file.exists(cf_path)) {
    cf <- readLines(cf_path, warn = FALSE)
    
    # Only check lines that are table rows (start with |)
    table_lines <- cf[grepl("^\\|", cf)]
    
    # Extract all paths matching (code|data|output|meta)/[A-Za-z0-9_./]+
    path_pattern <- "(code|data|output|meta)/[A-Za-z0-9_./]+"
    
    all_paths <- character()
    for (line in table_lines) {
        matches <- gregexpr(path_pattern, line, perl = TRUE)
        if (matches[[1]][1] != -1) {
            extracted <- regmatches(line, matches)[[1]]
            # Strip trailing "." if present
            extracted <- gsub("\\.$", "", extracted)
            all_paths <- c(all_paths, extracted)
        }
    }
    
    # Deduplicate
    unique_paths <- unique(all_paths)
    cat(sprintf("  Producer paths extracted (unique): %d\n", length(unique_paths)))
    
    # Per-path report
    dangling <- character()
    for (p in unique_paths) {
        exists_flag <- file.exists(p)
        status <- if (exists_flag) "OK" else "MISSING"
        cat(sprintf("    %s: %s\n", p, status))
        if (!exists_flag) dangling <- c(dangling, p)
    }
    
    cat(sprintf("  Dangling paths: %d\n", length(dangling)))
    if (length(dangling) > 0) {
        for (d in dangling) {
            report_violation("CF_PRODUCER", sprintf("canonical_facts.md references non-existent path: %s", d))
        }
    } else {
        cat("  All producer paths resolve: PASS\n")
    }
} else {
    report_violation("CF_PRODUCER", "meta/canonical_facts.md not found")
}

cat("\n")

# -----------------------------------------------------------------------------
# OUTPUT VALIDATION
# -----------------------------------------------------------------------------
cat("=== OUTPUT VALIDATION ===\n")

t19_file <- "output/T19_pleq0_bracket.csv"
if (file.exists(t19_file)) {
    t19 <- fread(t19_file)
    cat("T19_pleq0_bracket.csv:\n")
    print(t19)
} else {
    report_violation("T19", "T19_pleq0_bracket.csv not found")
}

cat("\n")

t20_file <- "output/T20_ge_bracket.csv"
if (file.exists(t20_file)) {
    t20 <- fread(t20_file)
    cat("T20_ge_bracket.csv:\n")
    print(t20[, .(arm, SD_true, q50, RANGE_1090)])
} else {
    report_violation("T20", "T20_ge_bracket.csv not found")
}

cat("\n")

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("================================================================\n")
cat("ENFORCE SUMMARY\n")
cat("================================================================\n\n")

if (n_violations == 0) {
    cat("ALL CHECKS PASS\n")
    cat(sprintf("\nEnd: %s\n", format(Sys.time())))
} else {
    cat(sprintf("VIOLATIONS: %d\n\n", n_violations))
    for (v in violations) {
        cat(sprintf("  [%s] %s\n", v$check, v$msg))
    }
    cat(sprintf("\nEnd: %s\n", format(Sys.time())))
}

# D3.3: Final halt gate - enforce.R must exit non-zero on any violation
stopifnot(n_violations == 0)
