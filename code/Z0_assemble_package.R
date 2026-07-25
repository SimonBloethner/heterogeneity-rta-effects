#!/usr/bin/env Rscript
# Z0_assemble_package.R: Assemble replication package from gates directory
# Copies validated artefacts from flat gates/ directory into repository layout
# Regenerates MANIFEST.txt as final act
#
# J3: Reads inventory from docs/package_contents.txt (hand-maintained)
# J4b: Verifies code/ files match between git and gates/

cat("========================================================================\n")
cat("Z0: ASSEMBLE REPLICATION PACKAGE\n")
cat("Start:", format(Sys.time()), "\n")
cat("========================================================================\n\n")

suppressPackageStartupMessages({
    library(digest)
})

# -----------------------------------------------------------------------------
# PATH CONSTANTS
# -----------------------------------------------------------------------------
GATES_DIR <- "/groups/m-larch/bt307958/gates"
STAGING_DIR <- "/groups/m-larch/bt307958/replication_package"
GIT_CODE_DIR <- "/groups/m-larch/bt307958/replication_package/code"

cat("PATHS:\n")
cat("  GATES_DIR:   ", GATES_DIR, "\n")
cat("  STAGING_DIR: ", STAGING_DIR, "\n")
cat("  GIT_CODE_DIR:", GIT_CODE_DIR, "\n\n")

# -----------------------------------------------------------------------------
# DIRECTORY GUARDS - directories must exist, we do NOT create them
# -----------------------------------------------------------------------------
if (!dir.exists(GATES_DIR)) {
    stop("FATAL: Gates directory does not exist: ", GATES_DIR)
}
cat("GATES_DIR exists: PASS\n")

if (!dir.exists(STAGING_DIR)) {
    stop("FATAL: Staging directory does not exist: ", STAGING_DIR)
}
cat("STAGING_DIR exists: PASS\n")

# Verify subdirectories exist
for (subdir in c("code", "data", "docs", "output")) {
    path <- file.path(STAGING_DIR, subdir)
    if (!dir.exists(path)) {
        stop("FATAL: Staging subdirectory does not exist: ", path,
             "\nRepository structure must be pre-existing. Do NOT create directories.")
    }
}
cat("All staging subdirectories exist: PASS\n\n")

# -----------------------------------------------------------------------------
# J3: READ INVENTORY FROM docs/package_contents.txt
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 1: Read inventory from docs/package_contents.txt\n")
cat("========================================================================\n")

INVENTORY_PATH <- file.path(STAGING_DIR, "docs", "package_contents.txt")
if (!file.exists(INVENTORY_PATH)) {
    stop("FATAL: Inventory file does not exist: ", INVENTORY_PATH,
         "\nThis file must be hand-maintained and present before Z0 runs.")
}

inventory_lines <- readLines(INVENTORY_PATH)
# Parse: skip comments and empty lines
inventory <- character(0)
for (line in inventory_lines) {
    line <- trimws(line)
    if (nzchar(line) && !grepl("^#", line)) {
        inventory <- c(inventory, line)
    }
}
cat("  Inventory entries:", length(inventory), "\n\n")

# -----------------------------------------------------------------------------
# CATEGORIZE INVENTORY ENTRIES
# -----------------------------------------------------------------------------
# Files that come from gates/ (data artefacts, outputs)
# vs files that are version-controlled (code/, README.md, docs/)

GATES_PREFIXES <- c("data/O5_", "data/P4_", "data/Q4_", "data/W1_", "data/X1_",
                    "data/X5_", "data/filtered_", "data/G2c_", "output/")
VCS_PREFIXES <- c("code/", "README.md", "docs/")
PROVIDED_DATA <- c("data/ITPDE_total.rds", "data/N0_data.rds",
                   "data/N0_pair_trade.rds", "data/N0_rta_pairs.rds")
HUMAN_CURATED <- c("output/canonical_facts.md", "output/invalidation_register.md")

is_from_gates <- function(path) {
    if (path %in% PROVIDED_DATA) return(FALSE)
    if (path %in% HUMAN_CURATED) return(FALSE)
    for (prefix in GATES_PREFIXES) {
        if (startsWith(path, prefix)) return(TRUE)
    }
    return(FALSE)
}

is_code_file <- function(path) {
    startsWith(path, "code/")
}

gates_files <- inventory[sapply(inventory, is_from_gates)]
code_files <- inventory[sapply(inventory, is_code_file)]

cat("  Files from gates/:", length(gates_files), "\n")
cat("  Code files (to verify):", length(code_files), "\n\n")

# -----------------------------------------------------------------------------
# J4b: VERIFY CODE FILES MATCH BETWEEN GIT AND GATES
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 2: Verify code/ files match (git vs gates)\n")
cat("========================================================================\n")

code_mismatch <- FALSE
for (code_path in code_files) {
    filename <- basename(code_path)
    git_path <- file.path(GIT_CODE_DIR, filename)
    gates_path <- file.path(GATES_DIR, filename)

    # Git version must exist
    if (!file.exists(git_path)) {
        cat("  MISSING (git):", git_path, "\n")
        code_mismatch <- TRUE
        next
    }

    # Gates version must exist (if we're supposed to verify it)
    if (!file.exists(gates_path)) {
        cat("  MISSING (gates):", gates_path, "\n")
        code_mismatch <- TRUE
        next
    }

    git_sha <- digest(file = git_path, algo = "sha256")
    gates_sha <- digest(file = gates_path, algo = "sha256")

    if (git_sha != gates_sha) {
        cat("  MISMATCH:", filename, "\n")
        cat("    git:  ", git_sha, "\n")
        cat("    gates:", gates_sha, "\n")
        code_mismatch <- TRUE
    } else {
        cat("  MATCH:", filename, "\n")
    }
}

if (code_mismatch) {
    stop("FATAL: Code files diverge between git and gates. Halting.\n",
         "Either sync gates/ from git or commit the gates/ versions.")
}
cat("\nAll code files match: PASS\n\n")

# -----------------------------------------------------------------------------
# PHASE 3: VERIFY ALL GATES SOURCE FILES EXIST
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 3: Verify gates/ source files exist\n")
cat("========================================================================\n")

# Map inventory paths to gates filenames
# gates/ uses flat structure, so we need the basename
gates_to_copy <- list()
missing_files <- character(0)

for (inv_path in gates_files) {
    # For output/ files, the gates name is just the basename
    # For data/ files, same
    gates_name <- basename(inv_path)
    gates_full <- file.path(GATES_DIR, gates_name)

    if (!file.exists(gates_full)) {
        missing_files <- c(missing_files, gates_name)
        cat("  MISSING:", gates_name, "\n")
    } else {
        gates_to_copy[[gates_name]] <- inv_path
        cat("  FOUND:  ", gates_name, "->", inv_path, "\n")
    }
}

if (length(missing_files) > 0) {
    stop("FATAL: ", length(missing_files), " files missing from gates/:\n  ",
         paste(missing_files, collapse = "\n  "),
         "\n\nHalting. No files have been copied.")
}
cat("\nAll", length(gates_to_copy), "gates/ files present: PASS\n\n")

# -----------------------------------------------------------------------------
# J3: CHECK FOR UNEXPECTED FILES IN GATES
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 4: Check for unexpected files in gates/\n")
cat("========================================================================\n")

gates_actual <- list.files(GATES_DIR, all.files = FALSE)
gates_expected <- names(gates_to_copy)
# Also expect code files
for (code_path in code_files) {
    gates_expected <- c(gates_expected, basename(code_path))
}

unexpected <- setdiff(gates_actual, gates_expected)
if (length(unexpected) > 0) {
    cat("UNEXPECTED FILES IN GATES:\n")
    for (f in unexpected) {
        cat("  ", f, "\n")
    }
    stop("FATAL: Unexpected files in gates/. Either add to inventory or remove from gates/.")
}
cat("  No unexpected files: PASS\n\n")

# -----------------------------------------------------------------------------
# PHASE 5: COPY FILES FROM GATES
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 5: Copy files to staging\n")
cat("========================================================================\n")

copy_results <- list()
for (gates_name in names(gates_to_copy)) {
    src_path <- file.path(GATES_DIR, gates_name)
    dst_path <- file.path(STAGING_DIR, gates_to_copy[[gates_name]])

    # Verify destination directory exists (should, per guards above)
    dst_dir <- dirname(dst_path)
    if (!dir.exists(dst_dir)) {
        stop("FATAL: Destination directory missing: ", dst_dir)
    }

    # Compute source SHA256
    src_sha <- digest(file = src_path, algo = "sha256")

    # Check if destination already exists and matches (skip copy if so)
    if (file.exists(dst_path)) {
        dst_sha <- digest(file = dst_path, algo = "sha256")
        if (src_sha == dst_sha) {
            copy_results[[gates_name]] <- list(
                dst = gates_to_copy[[gates_name]],
                sha256 = dst_sha
            )
            cat("  VERIFIED:", gates_name, "->", gates_to_copy[[gates_name]], "(already matches)\n")
            next
        }
    }

    # Copy with overwrite
    success <- file.copy(src_path, dst_path, overwrite = TRUE)
    if (!success) {
        stop("FATAL: Failed to copy ", gates_name, " to ", dst_path)
    }

    # Verify integrity
    dst_sha <- digest(file = dst_path, algo = "sha256")
    if (src_sha != dst_sha) {
        stop("FATAL: SHA256 mismatch after copy for ", gates_name)
    }

    copy_results[[gates_name]] <- list(
        dst = gates_to_copy[[gates_name]],
        sha256 = dst_sha
    )
    cat("  COPIED:", gates_name, "->", gates_to_copy[[gates_name]], "\n")
}

cat("\nAll", length(gates_to_copy), "files copied and verified: PASS\n\n")

# -----------------------------------------------------------------------------
# FINAL ASSERTION: HUMAN-CURATED FILES UNTOUCHED
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 6: Assert human-curated files untouched\n")
cat("========================================================================\n")

for (hc_file in HUMAN_CURATED) {
    full_path <- file.path(STAGING_DIR, hc_file)
    if (file.exists(full_path)) {
        cat("  EXISTS (untouched):", hc_file, "\n")
    } else {
        cat("  ABSENT:", hc_file, "\n")
    }
    # Verify it wasn't in our copy list
    if (basename(hc_file) %in% names(gates_to_copy)) {
        stop("FATAL: Human-curated file was in copy list: ", hc_file)
    }
}
cat("  Z0 did NOT write human-curated files: PASS (by design)\n\n")

# -----------------------------------------------------------------------------
# PHASE 7: REGENERATE MANIFEST.txt
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 7: Regenerate MANIFEST.txt\n")
cat("========================================================================\n")

# Compute SHA256 for all inventory files
manifest_entries <- list()
for (inv_path in inventory) {
    full_path <- file.path(STAGING_DIR, inv_path)
    if (file.exists(full_path) && !dir.exists(full_path)) {
        sha <- digest(file = full_path, algo = "sha256")
        manifest_entries[[inv_path]] <- sha
    }
}

cat("  Files in manifest:", length(manifest_entries), "\n")

# Build MANIFEST.txt content with section headers
manifest_lines <- c(
    "# MANIFEST - SHA256 checksums for replication package",
    paste0("# Generated: ", format(Sys.Date()), " (Z0_assemble_package.R)"),
    paste0("# Inventory: docs/package_contents.txt"),
    ""
)

# Group by directory
add_section <- function(title, pattern) {
    entries <- grep(pattern, names(manifest_entries), value = TRUE)
    if (length(entries) > 0) {
        manifest_lines <<- c(manifest_lines, paste0("# ", title))
        for (e in sort(entries)) {
            manifest_lines <<- c(manifest_lines, paste(manifest_entries[[e]], "", e))
        }
        manifest_lines <<- c(manifest_lines, "")
    }
}

add_section("README", "^README\\.md$")
add_section("Code files", "^code/")
add_section("Data files", "^data/")
add_section("Documentation", "^docs/")
add_section("Exhibit Pack - Output", "^output/[^.]")
add_section("Sidecars", "^output/\\.")

# Footer
manifest_lines <- c(manifest_lines, paste0("# Total files: ", length(manifest_entries)))
manifest_lines <- c(manifest_lines, "")

# Write MANIFEST.txt
manifest_path <- file.path(STAGING_DIR, "MANIFEST.txt")
writeLines(manifest_lines, manifest_path)
cat("  Written:", manifest_path, "\n")

manifest_sha <- digest(file = manifest_path, algo = "sha256")
cat("  MANIFEST SHA256:", manifest_sha, "\n\n")

cat("========================================================================\n")
cat("Z0 ASSEMBLY COMPLETE\n")
cat("========================================================================\n")
cat("Files copied from gates/:", length(gates_to_copy), "\n")
cat("Code files verified:     ", length(code_files), "\n")
cat("MANIFEST.txt regenerated\n")
cat("End:", format(Sys.time()), "\n")
