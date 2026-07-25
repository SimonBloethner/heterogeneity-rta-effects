#!/usr/bin/env Rscript
# Z0_assemble_package.R: Generate MANIFEST from git working tree
#
# M1: Git tree is authoritative for all distributed files.
# FINAL: Not-distributed files (gitignored, regenerable) use pinned hashes.
#
# Workflow:
#   1. Read inventory from docs/package_contents.txt
#   2. Verify all distributed files exist in git working tree
#   3. Not-distributed files: use pinned hash, do not require existence
#   4. Generate MANIFEST.txt from git tree hashes + pinned hashes

cat("========================================================================\n")
cat("Z0: GENERATE MANIFEST FROM GIT TREE\n")
cat("Start:", format(Sys.time()), "\n")
cat("========================================================================\n\n")

suppressPackageStartupMessages({
    library(digest)
})

# -----------------------------------------------------------------------------
# PATH CONSTANTS
# -----------------------------------------------------------------------------
REPO_DIR <- "/Users/Simon/replication_package"

# Not-distributed files: gitignored, regenerable from source
# These use pinned hashes and are not required to exist
NOT_DISTRIBUTED <- list(
    "data/N0_data.rds" = list(
        sha = "329721092fff490ab2c7825052cbf73bc0384698dd780689760aceb20325fd73",
        note = "not distributed - regenerate via N0_setup.R"
    )
)

cat("PATHS:\n")
cat("  REPO_DIR:", REPO_DIR, "\n")
cat("  Not-distributed files:", paste(names(NOT_DISTRIBUTED), collapse = ", "), "\n\n")

# -----------------------------------------------------------------------------
# DIRECTORY GUARDS
# -----------------------------------------------------------------------------
if (!dir.exists(REPO_DIR)) {
    stop("FATAL: Repository directory does not exist: ", REPO_DIR)
}
cat("REPO_DIR exists: PASS\n")

for (subdir in c("code", "data", "docs", "output")) {
    path <- file.path(REPO_DIR, subdir)
    if (!dir.exists(path)) {
        stop("FATAL: Subdirectory does not exist: ", path)
    }
}
cat("All subdirectories exist: PASS\n\n")

# -----------------------------------------------------------------------------
# PHASE 1: READ INVENTORY
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 1: Read inventory from docs/package_contents.txt\n")
cat("========================================================================\n")

INVENTORY_PATH <- file.path(REPO_DIR, "docs", "package_contents.txt")
if (!file.exists(INVENTORY_PATH)) {
    stop("FATAL: Inventory file does not exist: ", INVENTORY_PATH)
}

inventory_lines <- readLines(INVENTORY_PATH)
inventory <- character(0)
for (line in inventory_lines) {
    line <- trimws(line)
    if (nzchar(line) && !grepl("^#", line)) {
        inventory <- c(inventory, line)
    }
}
cat("  Inventory entries:", length(inventory), "\n\n")

# -----------------------------------------------------------------------------
# PHASE 2: VERIFY DISTRIBUTED FILES EXIST
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 2: Verify distributed files exist in git tree\n")
cat("========================================================================\n")

missing_files <- character(0)

for (inv_path in inventory) {
    full_path <- file.path(REPO_DIR, inv_path)

    if (inv_path %in% names(NOT_DISTRIBUTED)) {
        # Not-distributed: do not require existence, use pinned hash
        cat("  NOT-DISTRIBUTED:", inv_path, "(pinned hash)\n")
    } else {
        # Regular files: must exist in git tree
        if (!file.exists(full_path)) {
            missing_files <- c(missing_files, inv_path)
            cat("  MISSING:", inv_path, "\n")
        } else {
            cat("  EXISTS:", inv_path, "\n")
        }
    }
}

if (length(missing_files) > 0) {
    stop("FATAL: ", length(missing_files), " files missing from git tree:\n  ",
         paste(missing_files, collapse = "\n  "))
}
cat("\nAll distributed files verified: PASS\n\n")

# -----------------------------------------------------------------------------
# PHASE 3: GENERATE MANIFEST FROM GIT TREE + PINNED HASHES
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 3: Generate MANIFEST.txt\n")
cat("========================================================================\n")

manifest_entries <- list()
manifest_notes <- list()

for (inv_path in inventory) {
    if (inv_path %in% names(NOT_DISTRIBUTED)) {
        # Use pinned hash for not-distributed files
        manifest_entries[[inv_path]] <- NOT_DISTRIBUTED[[inv_path]]$sha
        manifest_notes[[inv_path]] <- NOT_DISTRIBUTED[[inv_path]]$note
    } else {
        # Compute hash from git tree
        full_path <- file.path(REPO_DIR, inv_path)
        if (file.exists(full_path) && !dir.exists(full_path)) {
            sha <- digest(file = full_path, algo = "sha256")
            manifest_entries[[inv_path]] <- sha
        }
    }
}

cat("  Files in manifest:", length(manifest_entries), "\n")

# Build MANIFEST.txt content
manifest_lines <- c(
    "# MANIFEST - SHA256 checksums for replication package",
    paste0("# Generated: ", format(Sys.Date()), " (Z0_assemble_package.R)"),
    paste0("# Inventory: docs/package_contents.txt"),
    paste0("# Source: git working tree (gitignored files noted)"),
    ""
)

# Group by directory
add_section <- function(title, pattern) {
    entries <- grep(pattern, names(manifest_entries), value = TRUE)
    if (length(entries) > 0) {
        manifest_lines <<- c(manifest_lines, paste0("# ", title))
        for (e in sort(entries)) {
            line <- paste(manifest_entries[[e]], "", e)
            if (e %in% names(manifest_notes)) {
                line <- paste0(line, "  # ", manifest_notes[[e]])
            }
            manifest_lines <<- c(manifest_lines, line)
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

manifest_lines <- c(manifest_lines, paste0("# Total files: ", length(manifest_entries)))
manifest_lines <- c(manifest_lines, "")

# Write MANIFEST.txt
manifest_path <- file.path(REPO_DIR, "MANIFEST.txt")
writeLines(manifest_lines, manifest_path)
cat("  Written:", manifest_path, "\n")

manifest_sha <- digest(file = manifest_path, algo = "sha256")
cat("  MANIFEST SHA256:", manifest_sha, "\n\n")

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("Z0 MANIFEST GENERATION COMPLETE\n")
cat("========================================================================\n")
cat("Files in manifest:", length(manifest_entries), "\n")
cat("Not-distributed files:", length(NOT_DISTRIBUTED), "(pinned hashes)\n")
cat("End:", format(Sys.time()), "\n")
