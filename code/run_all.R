#!/usr/bin/env Rscript
# =============================================================================
# run_all.R - Pipeline orchestrator
# =============================================================================
# Generated from FILE_REGISTRY.csv
# Builds dependency graph, topologically sorts, checks stage consistency
# Usage: Rscript code/run_all.R           # print order only
#        Rscript code/run_all.R --execute # run all scripts
# =============================================================================

library(data.table)

args <- commandArgs(trailingOnly = TRUE)
EXECUTE <- "--execute" %in% args

cat("================================================================\n")
cat("run_all.R - Pipeline Orchestrator\n")
cat(sprintf("Start: %s\n", format(Sys.time())))
cat(sprintf("Mode: %s\n", if (EXECUTE) "EXECUTE" else "DRY RUN"))
cat("================================================================\n\n")

# =============================================================================
# CONFIGURATION
# =============================================================================

# Map ledger IDs to their producer output files
# These are parsed from canonical_facts.md producer columns
LEDGER_PRODUCERS <- list(
    MEAN_THETA_D = "data/S5R_bhat.rds",
    SD_THETA_TRUE = "output/T21_arms.csv",  # S24_arms_canonical.R
    GRADIENT = "output/T27_gradient_B_spread.csv",
    GRADIENT_Q1 = "output/T27_gradient_B.csv",
    GRADIENT_Q5 = "output/T27_gradient_B.csv",
    GRADIENT_B = "output/T27_gradient_B_spread.csv",
    GRADIENT_B_SHARE = "output/T27_gradient_B_spread.csv",
    PLACEBO_A_R = "output/T22_reliability.csv",
    ESIGMA2 = "output/T25_prop_verification.csv",
    VAR_SIGMA2 = "output/T28b_v1c_arm1p.csv",
    MOMPOW_IDENT_MIN_Z = "output/T29_moment_power.csv",
    MOMPOW_IDENT_MAX_Z = "output/T29_moment_power.csv",
    A2_EXKURT = "output/T38_a2_normality.csv",
    A2_EXKURT_CONTROL = "output/T38_a2_normality.csv",
    HOLDOUT_D3_MEAN = "output/T9_placebo_holdout.csv",
    HOLDOUT_D3_N = "output/T9_placebo_holdout.csv",
    HOLDOUT_MAX_ABS_EX_D3 = "output/T9_placebo_holdout.csv"
)

# =============================================================================
# LOAD REGISTRY
# =============================================================================
cat("=== LOADING REGISTRY ===\n")

registry <- fread("meta/FILE_REGISTRY.csv", na.strings = "")
cat(sprintf("Registry rows: %d\n", nrow(registry)))
cat(sprintf("Columns: %s\n", paste(names(registry), collapse = ", ")))

# Filter to BUILT code scripts only (excluding ANCHOR, ARCHIVED, etc.)
scripts <- registry[kind == "code" & status == "BUILT" & grepl("^code/S[0-9]", file_path)]
cat(sprintf("BUILT scripts matching code/S*: %d\n", nrow(scripts)))

# =============================================================================
# BUILD DEPENDENCY GRAPH
# =============================================================================
cat("\n=== BUILDING DEPENDENCY GRAPH ===\n")

# For each script, find its dependencies:
# 1. File inputs (data/*.rds, output/*.csv)
# 2. Ledger inputs -> mapped to producer files

get_dependencies <- function(row) {
    deps <- character(0)

    # File inputs
    if (!is.na(row$inputs) && nchar(row$inputs) > 0) {
        file_deps <- strsplit(row$inputs, ";")[[1]]
        # Filter to data/ and output/ only (not code/, meta/)
        file_deps <- file_deps[grepl("^(data/|output/)", file_deps)]
        deps <- c(deps, file_deps)
    }

    # Ledger inputs
    if (!is.na(row$ledger_inputs) && nchar(row$ledger_inputs) > 0) {
        ledger_ids <- strsplit(row$ledger_inputs, ";")[[1]]
        for (lid in ledger_ids) {
            if (lid %in% names(LEDGER_PRODUCERS)) {
                deps <- c(deps, LEDGER_PRODUCERS[[lid]])
            }
        }
    }

    unique(deps)
}

# Build adjacency list: script -> list of dependency files
# Then map files back to their producer scripts
file_to_producer <- registry[, .(file_path, producer_script)]
setkey(file_to_producer, file_path)

# Build edges: script_a depends on script_b if any of script_a's input files
# are produced by script_b
edges <- list()
for (i in seq_len(nrow(scripts))) {
    script <- scripts$file_path[i]
    deps <- get_dependencies(scripts[i])

    for (dep in deps) {
        # Find producer of this dependency
        producer_rows <- registry[file_path == dep & !is.na(producer_script)]
        if (nrow(producer_rows) > 0) {
            producer <- producer_rows$producer_script[1]
            # Only add edge if producer is a BUILT script we're tracking
            if (producer %in% scripts$file_path) {
                if (is.null(edges[[script]])) edges[[script]] <- character(0)
                edges[[script]] <- c(edges[[script]], producer)
            }
        }
    }
}

cat(sprintf("Scripts with dependencies: %d\n", length(edges)))

# =============================================================================
# TOPOLOGICAL SORT (Kahn's algorithm)
# =============================================================================
cat("\n=== TOPOLOGICAL SORT ===\n")

# Calculate in-degree for each script
in_degree <- setNames(rep(0L, nrow(scripts)), scripts$file_path)
for (script in names(edges)) {
    for (dep in unique(edges[[script]])) {
        in_degree[script] <- in_degree[script] + 1L
    }
}

# Reverse edges for Kahn's algorithm
reverse_edges <- list()
for (script in names(edges)) {
    for (dep in unique(edges[[script]])) {
        if (is.null(reverse_edges[[dep]])) reverse_edges[[dep]] <- character(0)
        reverse_edges[[dep]] <- c(reverse_edges[[dep]], script)
    }
}

# Kahn's algorithm
sorted_order <- character(0)
queue <- names(in_degree)[in_degree == 0]

while (length(queue) > 0) {
    # Pop from queue (take script with lowest stage number for stability)
    stages <- scripts[match(queue, file_path), as.integer(stage)]
    stages[is.na(stages)] <- 999L
    idx <- which.min(stages)
    current <- queue[idx]
    queue <- queue[-idx]

    sorted_order <- c(sorted_order, current)

    # Update in-degrees
    if (!is.null(reverse_edges[[current]])) {
        for (successor in reverse_edges[[current]]) {
            in_degree[successor] <- in_degree[successor] - 1L
            if (in_degree[successor] == 0) {
                queue <- c(queue, successor)
            }
        }
    }
}

# Check for cycle
if (length(sorted_order) < nrow(scripts)) {
    remaining <- setdiff(scripts$file_path, sorted_order)
    cat("ERROR: Cycle detected in dependency graph!\n")
    cat("Scripts not reachable:\n")
    for (s in remaining) cat("  ", s, "\n")
    stop("HALT: Cycle in dependency graph")
}

cat(sprintf("Topological sort complete: %d scripts\n", length(sorted_order)))

# =============================================================================
# STAGE CONSISTENCY CHECK
# =============================================================================
cat("\n=== STAGE CONSISTENCY CHECK ===\n")

# For each edge (A depends on B), check that stage(B) < stage(A)
inversions <- character(0)

for (script in names(edges)) {
    script_stage <- scripts[file_path == script, as.integer(stage)]
    if (length(script_stage) == 0 || is.na(script_stage)) next

    for (dep in unique(edges[[script]])) {
        dep_stage <- scripts[file_path == dep, as.integer(stage)]
        if (length(dep_stage) == 0 || is.na(dep_stage)) next

        # Inversion: consumer at stage N depends on producer at stage > N
        # Same-stage is OK - topological sort resolves the order
        if (dep_stage > script_stage) {
            inv <- sprintf("%s (stage %d) <- %s (stage %d)",
                           script, script_stage, dep, dep_stage)
            inversions <- c(inversions, inv)
        }
    }
}

if (length(inversions) > 0) {
    cat("ERROR: Stage inversions detected!\n")
    for (inv in inversions) cat("  ", inv, "\n")
    stop("HALT: Stage inversions - fix FILE_REGISTRY.csv stages")
}

cat("PASS: No stage inversions\n")

# =============================================================================
# OUTPUT EXECUTION ORDER
# =============================================================================
cat("\n=== EXECUTION ORDER ===\n")

# Add stage info
order_df <- data.frame(
    order = seq_along(sorted_order),
    script = sorted_order,
    stage = scripts[match(sorted_order, file_path), stage]
)

print(order_df, row.names = FALSE)

# =============================================================================
# EXECUTE (if requested)
# =============================================================================

if (EXECUTE) {
    cat("\n=== EXECUTING PIPELINE ===\n")

    log_file <- "output/run_all_log.txt"
    log_con <- file(log_file, open = "wt")

    writeLines(sprintf("run_all.R execution log\nStarted: %s\n", Sys.time()), log_con)

    for (i in seq_along(sorted_order)) {
        script <- sorted_order[i]
        cat(sprintf("\n[%d/%d] %s\n", i, length(sorted_order), script))

        start_time <- Sys.time()
        writeLines(sprintf("\n=== [%d/%d] %s ===", i, length(sorted_order), script), log_con)
        writeLines(sprintf("Start: %s", start_time), log_con)

        # Run script
        result <- system2("Rscript", args = script, stdout = TRUE, stderr = TRUE)
        exit_code <- attr(result, "status")
        if (is.null(exit_code)) exit_code <- 0L

        end_time <- Sys.time()
        writeLines(sprintf("End: %s", end_time), log_con)
        writeLines(sprintf("Exit code: %d", exit_code), log_con)
        writeLines(sprintf("Duration: %.1f seconds", as.numeric(end_time - start_time, units = "secs")), log_con)

        if (exit_code != 0) {
            cat(sprintf("ERROR: Script failed with exit code %d\n", exit_code))
            writeLines("OUTPUT:", log_con)
            writeLines(result, log_con)
            close(log_con)
            stop(sprintf("HALT: %s failed", script))
        }

        cat(sprintf("  OK (%.1f sec)\n", as.numeric(end_time - start_time, units = "secs")))
    }

    writeLines(sprintf("\n=== COMPLETE ===\nFinished: %s", Sys.time()), log_con)
    close(log_con)

    cat(sprintf("\n=== PIPELINE COMPLETE ===\n"))
    cat(sprintf("Log: %s\n", log_file))
}

cat(sprintf("\nDone: %s\n", format(Sys.time())))
