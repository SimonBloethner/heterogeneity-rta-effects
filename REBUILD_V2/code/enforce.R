#!/usr/bin/env Rscript
# enforce.R - REBUILD_V2 Manifest Enforcement
#
# OUTPUTS: console report; halts on violation
# INPUTS:  meta/FILE_REGISTRY.csv, all files in tree
# SEED:    NONE
# GATES:   violations == 0

cat("================================================================\n")
cat("ENFORCE.R - Manifest Discipline Check\n")
cat("================================================================\n\n")

REBUILD_DIR <- "/scratch/bt307958/REBUILD_V2"
setwd(REBUILD_DIR)

library(tools)
library(data.table)

violations <- 0
violation_details <- character(0)

add_violation <- function(msg) {
    violations <<- violations + 1
    violation_details <<- c(violation_details, sprintf("[V%d] %s", violations, msg))
    cat(sprintf("VIOLATION %d: %s\n", violations, msg))
}

get_sha256 <- function(path) {
    result <- system2("sha256sum", args = shQuote(path), stdout = TRUE)
    sha <- strsplit(result, " ")[[1]][1]
    return(sha)
}

registry_path <- file.path(REBUILD_DIR, "meta/FILE_REGISTRY.csv")
if (!file.exists(registry_path)) {
    stop("FATAL: FILE_REGISTRY.csv does not exist")
}

registry <- fread(registry_path)
cat(sprintf("Registry entries: %d\n", nrow(registry)))

declared_files <- registry$file_path

all_files <- list.files(REBUILD_DIR, recursive = TRUE, all.files = FALSE)
all_files <- all_files[!grepl("^\\.git", all_files)]
all_files <- all_files[!grepl("\\.gitkeep$", all_files)]

cat(sprintf("Files in tree: %d\n\n", length(all_files)))

cat("=== CHECK: Undeclared Files ===\n")
for (f in all_files) {
    if (!(f %in% declared_files)) {
        add_violation(sprintf("Undeclared file: %s", f))
    }
}
if (violations == 0) cat("No undeclared files. PASS\n")
cat("\n")

cat("=== CHECK: Data File Sidecars ===\n")
data_files <- registry[kind == "data"]$file_path
sidecar_violations_start <- violations

for (df in data_files) {
    full_path <- file.path(REBUILD_DIR, df)
    if (!file.exists(full_path)) {
        next
    }
    
    basename_f <- basename(df)
    sidecar_path <- file.path(REBUILD_DIR, "meta", paste0(basename_f, ".sidecar"))
    
    if (!file.exists(sidecar_path)) {
        add_violation(sprintf("Data file exists but no sidecar: %s (expected %s)", 
                              df, sidecar_path))
    }
}
if (violations == sidecar_violations_start) cat("All existing data files have sidecars. PASS\n")
cat("\n")

cat("=== CHECK: Sidecar SHA256 Integrity ===\n")
sha_violations_start <- violations

sidecars <- list.files(file.path(REBUILD_DIR, "meta"), pattern = "\\.sidecar$", 
                       full.names = TRUE)

for (sc in sidecars) {
    sc_content <- readLines(sc)
    sha_line <- sc_content[grepl("^SHA256:", sc_content)]
    file_line <- sc_content[grepl("^FILE:", sc_content)]
    
    if (length(sha_line) == 0 || length(file_line) == 0) {
        add_violation(sprintf("Malformed sidecar (missing SHA256 or FILE): %s", sc))
        next
    }
    
    recorded_sha <- trimws(sub("^SHA256:\\s*", "", sha_line[1]))
    recorded_file <- trimws(sub("^FILE:\\s*", "", file_line[1]))
    
    actual_path <- NULL
    for (d in c("data", "output")) {
        test_path <- file.path(REBUILD_DIR, d, recorded_file)
        if (file.exists(test_path)) {
            actual_path <- test_path
            break
        }
    }
    
    if (is.null(actual_path)) {
        add_violation(sprintf("Sidecar references nonexistent file: %s -> %s", 
                              basename(sc), recorded_file))
        next
    }
    
    actual_sha <- get_sha256(actual_path)
    
    if (actual_sha != recorded_sha) {
        add_violation(sprintf("SHA256 mismatch for %s: recorded=%s actual=%s",
                              recorded_file, recorded_sha, actual_sha))
    }
}
if (violations == sha_violations_start) cat("All sidecar SHA256 values match. PASS\n")
cat("\n")

cat("=== CHECK: Status Progression ===\n")
status_counts <- registry[, .N, by = status]
cat("Status counts:\n")
print(status_counts)
cat("\n")

cat("================================================================\n")
cat("ENFORCEMENT SUMMARY\n")
cat("================================================================\n")
cat(sprintf("Total violations: %d\n", violations))

if (violations > 0) {
    cat("\nViolation details:\n")
    for (v in violation_details) {
        cat(sprintf("  %s\n", v))
    }
}

cat("\n")
stopifnot(violations == 0)
cat("ENFORCEMENT PASSED\n")
