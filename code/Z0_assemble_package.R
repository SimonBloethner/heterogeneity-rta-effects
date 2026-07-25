#!/usr/bin/env Rscript
# Z0_assemble_package.R: Generate MANIFEST from git working tree
#
# M1: Git tree is authoritative. gates/ is used ONLY for artefacts git cannot
#     hold (gitignored large files like data/N0_data.rds).
#
# Workflow:
#   1. Read inventory from docs/package_contents.txt
#   2. Verify all inventory files exist in git working tree
#   3. For gitignored files, check gates/ - REPORT and HALT on mismatch
#   4. Generate MANIFEST.txt from git tree hashes

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
# When run on Festus, these point to the git working tree
REPO_DIR <- "/groups/m-larch/bt307958/replication_package"
GATES_DIR <- "/groups/m-larch/bt307958/gates"

# Files that are gitignored (too large for git) - sourced from gates/
GITIGNORED_FILES <- c("data/N0_data.rds")

cat("PATHS:\n")
cat("  REPO_DIR: ", REPO_DIR, "\n")
cat("  GATES_DIR:", GATES_DIR, "\n")
cat("  Gitignored files:", paste(GITIGNORED_FILES, collapse = ", "), "\n\n")

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
# PHASE 2: VERIFY ALL FILES EXIST IN GIT TREE
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 2: Verify all inventory files exist in git tree\n")
cat("========================================================================\n")

missing_files <- character(0)
gitignored_missing <- character(0)

for (inv_path in inventory) {
    full_path <- file.path(REPO_DIR, inv_path)

    if (inv_path %in% GITIGNORED_FILES) {
        # Gitignored files: check gates/ instead
        gates_path <- file.path(GATES_DIR, basename(inv_path))
        if (!file.exists(gates_path)) {
            gitignored_missing <- c(gitignored_missing, inv_path)
            cat("  MISSING (gitignored, not in gates):", inv_path, "\n")
        } else {
            gates_info <- file.info(gates_path)
            cat("  GITIGNORED:", inv_path, "(", gates_info$size, "bytes in gates/)\n")
        }
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
if (length(gitignored_missing) > 0) {
    stop("FATAL: ", length(gitignored_missing), " gitignored files missing from gates/:\n  ",
         paste(gitignored_missing, collapse = "\n  "))
}
cat("\nAll", length(inventory), "inventory files verified: PASS\n\n")

# -----------------------------------------------------------------------------
# PHASE 3: GITIGNORED FILE REPORT (M1d)
# For files git cannot arbitrate, report both local and gates hashes
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 3: Gitignored file status (cannot be arbitrated by git)\n")
cat("========================================================================\n")

for (inv_path in GITIGNORED_FILES) {
    cat("\n", inv_path, ":\n")

    local_path <- file.path(REPO_DIR, inv_path)
    gates_path <- file.path(GATES_DIR, basename(inv_path))

    if (file.exists(local_path)) {
        local_sha <- digest(file = local_path, algo = "sha256")
        local_info <- file.info(local_path)
        cat("  LOCAL:  ", local_sha, "\n")
        cat("          size:", local_info$size, "bytes\n")
        cat("          mtime:", format(local_info$mtime), "\n")
    } else {
        cat("  LOCAL:   MISSING\n")
    }

    if (file.exists(gates_path)) {
        gates_sha <- digest(file = gates_path, algo = "sha256")
        gates_info <- file.info(gates_path)
        cat("  GATES:  ", gates_sha, "\n")
        cat("          size:", gates_info$size, "bytes\n")
        cat("          mtime:", format(gates_info$mtime), "\n")
    } else {
        cat("  GATES:   MISSING\n")
    }

    # Report mismatch but DO NOT choose - human decision required
    if (file.exists(local_path) && file.exists(gates_path)) {
        if (local_sha != gates_sha) {
            cat("  STATUS: MISMATCH - human decision required\n")
        } else {
            cat("  STATUS: MATCH\n")
        }
    }
}
cat("\n")

# -----------------------------------------------------------------------------
# PHASE 4: GENERATE MANIFEST FROM GIT TREE
# -----------------------------------------------------------------------------
cat("========================================================================\n")
cat("PHASE 4: Generate MANIFEST.txt from git tree\n")
cat("========================================================================\n")

manifest_entries <- list()
for (inv_path in inventory) {
    if (inv_path %in% GITIGNORED_FILES) {
        # Use gates/ copy for gitignored files
        full_path <- file.path(GATES_DIR, basename(inv_path))
    } else {
        # Use git tree for everything else
        full_path <- file.path(REPO_DIR, inv_path)
    }

    if (file.exists(full_path) && !dir.exists(full_path)) {
        sha <- digest(file = full_path, algo = "sha256")
        manifest_entries[[inv_path]] <- sha
    }
}

cat("  Files in manifest:", length(manifest_entries), "\n")

# Build MANIFEST.txt content
manifest_lines <- c(
    "# MANIFEST - SHA256 checksums for replication package",
    paste0("# Generated: ", format(Sys.Date()), " (Z0_assemble_package.R)"),
    paste0("# Inventory: docs/package_contents.txt"),
    paste0("# Source: git working tree (gitignored files from gates/)"),
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
cat("Gitignored files: ", length(GITIGNORED_FILES), "(sourced from gates/)\n")
cat("End:", format(Sys.time()), "\n")
