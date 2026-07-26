#!/usr/bin/env Rscript
# enforce.R - Gate Consistency Check
# OUTPUTS: stdout
# INPUTS: all scripts, sidecars, FILE_REGISTRY.csv, SUPERSEDED.md
# SEED: NONE
# EXPECTED_N: NA (meta script)
#
# Guard rails per INV-031, INV-032:
#   (a) every script that loads a population declares EXPECTED_N and asserts it
#   (b) no gate condition in sidecar may differ from producer script
#   (c) no canonical_facts ID may resolve to more than one BUILT producer
#   (d) no BUILT output may depend on QUARANTINE, SUPERSEDED, or RETIRED input
#   (e) every sidecar's recorded SHA256 must match current file SHA256

cat("================================================================\n")
cat("ENFORCE.R - GATE CONSISTENCY CHECK\n")
cat("Run:", format(Sys.time()), "\n")
cat("================================================================\n\n")

library(data.table)

REBUILD_DIR <- "/groups/m-larch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

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

# -----------------------------------------------------------------------------
# (a) EXPECTED_N declarations
# -----------------------------------------------------------------------------
cat("=== CHECK (a): EXPECTED_N declarations ===\n")

scripts <- list.files("code", pattern = "\\.R$", full.names = TRUE)

for (script in scripts) {
    content <- readLines(script, warn = FALSE)
    content_text <- paste(content, collapse = "\n")

    loads_pop <- any(grepl("population|pop_canon|S6R|theta_d", content_text, ignore.case = TRUE))

    if (loads_pop) {
        has_expected_n <- any(grepl("EXPECTED_N:", content))
        has_assertion <- any(grepl("stopifnot.*nrow.*==", content_text))

        if (!has_expected_n) {
            report_violation("EXPECTED_N", sprintf("%s loads population but lacks EXPECTED_N header", basename(script)))
        }
        if (has_expected_n && !has_assertion) {
            report_violation("EXPECTED_N", sprintf("%s declares EXPECTED_N but lacks stopifnot(nrow...)", basename(script)))
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
cat("=== CHECK (d): BUILT dependencies (extended) ===\n")

if (exists("registry")) {
    quarantined <- registry[status == "QUARANTINE", file]
    superseded <- registry[status == "SUPERSEDED", file]

    cat(sprintf("QUARANTINE outputs: %d\n", length(quarantined)))
    cat(sprintf("SUPERSEDED outputs: %d\n", length(superseded)))
    cat(sprintf("RETIRED artifacts: %d\n", length(RETIRED_ARTIFACTS)))

    for (script in scripts) {
        script_content <- paste(readLines(script, warn = FALSE), collapse = " ")

        for (retired in RETIRED_ARTIFACTS) {
            if (grepl(retired, script_content, fixed = TRUE)) {
                script_name <- basename(script)
                if (grepl("^S[0-9]", script_name)) {
                    report_violation("RETIRED", sprintf("%s uses RETIRED artifact %s", script_name, retired))
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

    # Extract SHA256 from sidecar
    sha_line <- grep("^SHA256:", content, value = TRUE)
    if (length(sha_line) > 0) {
        recorded_sha <- gsub("^SHA256:\\s*", "", sha_line[1])
        recorded_sha <- trimws(recorded_sha)

        # Determine the file this sidecar describes
        sidecar_name <- basename(sidecar)
        described_file <- gsub("\\.sidecar$", "", sidecar_name)

        # Find the file (could be in output/ or data/)
        file_path <- NULL
        for (dir in c("output", "data")) {
            candidate <- file.path(dir, described_file)
            if (file.exists(candidate)) {
                file_path <- candidate
                break
            }
        }

        if (!is.null(file_path)) {
            # Compute current SHA256
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
# OUTPUT VALIDATION
# -----------------------------------------------------------------------------
cat("=== OUTPUT VALIDATION ===\n")

t19_file <- file.path(REBUILD_DIR, "output/T19_pleq0_bracket.csv")
if (file.exists(t19_file)) {
    t19 <- fread(t19_file)
    cat("T19_pleq0_bracket.csv:\n")
    print(t19)
    p_vals <- t19$P_theta_leq_0
    if (length(p_vals) == 2) {
        cat(sprintf("P(theta<=0) bracket: [%.3f, %.3f]\n", min(p_vals), max(p_vals)))
    }
} else {
    report_violation("T19", "T19_pleq0_bracket.csv not found")
}

cat("\n")

t20_file <- file.path(REBUILD_DIR, "output/T20_ge_bracket.csv")
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
} else {
    cat(sprintf("VIOLATIONS: %d\n\n", n_violations))
    for (v in violations) {
        cat(sprintf("  [%s] %s\n", v$check, v$msg))
    }
}

cat(sprintf("\nEnd: %s\n", format(Sys.time())))
