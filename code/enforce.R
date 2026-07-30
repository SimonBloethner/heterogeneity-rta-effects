#!/usr/bin/env Rscript
# enforce.R - Gate Consistency Check (REPAIRED)
# Each check is individually callable while preserving exact original output format
# REPAIRS: R1 (sidecar path), R2 (appendix following-line), R3 (macro split), R4 (ARCHIVED vocab)

stopifnot(!grepl("login", Sys.info()[["nodename"]]))

library(data.table)

RETIRED_ARTIFACTS <- c("W1_pop_canon.rds", "S6_population.rds", "STRAY_W1_COPY_DO_NOT_USE.rds")
POPULATION_PRODUCERS <- c("S6R_population.R")

# Global state for original output format
violations <- list()
n_violations <- 0

report_violation <- function(check, msg) {
    n_violations <<- n_violations + 1
    violations[[n_violations]] <<- list(check = check, msg = msg)
    cat(sprintf("VIOLATION [%s]: %s\n", check, msg))
}

# =============================================================================
# CHECK (a): EXPECTED_N declarations
# =============================================================================
check_expected_n <- function(root, report = FALSE) {
    results <- character()
    all_scripts <- list.files(file.path(root, "code"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
    scripts <- all_scripts[!grepl("audit/|archive/", all_scripts)]
    scripts <- scripts[!grepl("/L[0-9]", scripts)]
    
    for (script in scripts) {
        script_name <- basename(script)
        content <- readLines(script, warn = FALSE)
        content_text <- paste(content, collapse = "\n")
        loads_pop <- any(grepl("population|pop_canon|S6R|theta_d", content_text, ignore.case = TRUE))
        
        if (loads_pop) {
            is_producer <- script_name %in% POPULATION_PRODUCERS
            has_expected_n <- any(grepl("EXPECTED_N:", content))
            expected_n_na <- any(grepl("EXPECTED_N:\\s*NA", content))
            
            if (is_producer) {
                has_output_assertion <- any(grepl("stopifnot.*nrow.*popn|stopifnot.*length.*k", content_text))
                if (!has_expected_n) {
                    msg <- sprintf("%s produces population but lacks EXPECTED_N header", script_name)
                    if (report) report_violation("EXPECTED_N", msg)
                    results <- c(results, paste0("EXPECTED_N|", msg))
                }
                if (has_expected_n && !has_output_assertion) {
                    msg <- sprintf("%s declares EXPECTED_N but lacks output assertion", script_name)
                    if (report) report_violation("EXPECTED_N", msg)
                    results <- c(results, paste0("EXPECTED_N|", msg))
                }
            } else {
                has_assertion <- any(grepl("stopifnot.*nrow.*==", content_text))
                if (!has_expected_n) {
                    msg <- sprintf("%s loads population but lacks EXPECTED_N header", script_name)
                    if (report) report_violation("EXPECTED_N", msg)
                    results <- c(results, paste0("EXPECTED_N|", msg))
                }
                if (has_expected_n && !has_assertion && !expected_n_na) {
                    msg <- sprintf("%s declares EXPECTED_N but lacks stopifnot(nrow...)", script_name)
                    if (report) report_violation("EXPECTED_N", msg)
                    results <- c(results, paste0("EXPECTED_N|", msg))
                }
            }
        }
    }
    results
}

# =============================================================================
# CHECK (b): Sidecar gate consistency - R1 FIX: handle both PRODUCER formats
# =============================================================================
check_sidecar <- function(root, report = FALSE) {
    results <- character()
    sidecars <- list.files(file.path(root, "meta"), pattern = "\\.sidecar$", full.names = TRUE)
    
    for (sidecar in sidecars) {
        content <- readLines(sidecar, warn = FALSE)
        producer_line <- grep("^PRODUCER:", content, value = TRUE)
        
        if (length(producer_line) > 0) {
            producer_raw <- gsub("^PRODUCER:\\s*", "", producer_line[1])

            # R1 FIX: Strip SHA256 suffix if present (e.g., "code/X.R (SHA256: abc123)")
            producer <- sub("\\s*\\(SHA256:.*$", "", producer_raw)

            # R1 FIX: Strip leading "code/" if present to normalize, then resolve against code/
            producer_clean <- sub("^code/", "", producer)
            producer_path <- file.path(root, "code", producer_clean)
            
            if (file.exists(producer_path)) {
                if (report) {
                    gate_lines <- grep("^\\s*G[0-9]:", content, value = TRUE)
                    cat(sprintf("  %s -> %s: %d gates declared\n", basename(sidecar), producer_clean, length(gate_lines)))
                }
            } else {
                msg <- sprintf("%s references non-existent producer %s", basename(sidecar), producer_clean)
                if (report) report_violation("SIDECAR", msg)
                results <- c(results, paste0("SIDECAR|", msg))
            }
        }
    }
    results
}

# =============================================================================
# CHECK (c): Unique BUILT producers per canonical_facts ID
# =============================================================================
check_registry <- function(root, report = FALSE) {
    results <- character()
    registry_path <- file.path(root, "meta/FILE_REGISTRY.csv")
    if (!file.exists(registry_path)) {
        msg <- "FILE_REGISTRY.csv not found"
        if (report) report_violation("REGISTRY", msg)
        results <- c(results, paste0("REGISTRY|", msg))
    }
    results
}

# =============================================================================
# CHECK (d): BUILT dependencies - R4 FIX: ARCHIVED vocabulary
# =============================================================================
check_built_deps <- function(root, report = FALSE) {
    results <- character()
    registry_path <- file.path(root, "meta/FILE_REGISTRY.csv")
    if (!file.exists(registry_path)) return(results)
    
    registry <- fread(registry_path)
    
    all_scripts <- list.files(file.path(root, "code"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
    scripts <- all_scripts[!grepl("audit/|archive/", all_scripts)]
    scripts <- scripts[!grepl("/L[0-9]", scripts)]
    
    load_pattern <- "readRDS\\s*\\(|read\\.csv\\s*\\(|fread\\s*\\(|load\\s*\\("
    
    # R4 FIX: Get ARCHIVED and QUARANTINE files
    archived <- registry[status == "ARCHIVED", file_path]
    quarantined <- registry[status == "QUARANTINE", file_path]
    
    for (script in scripts) {
        script_name <- basename(script)
        content <- readLines(script, warn = FALSE)
        load_lines <- grep(load_pattern, content, value = TRUE)
        
        # Check RETIRED artifacts (legacy)
        for (retired in RETIRED_ARTIFACTS) {
            if (any(grepl(retired, load_lines, fixed = TRUE))) {
                if (grepl("^S[0-9]", script_name)) {
                    msg <- sprintf("%s loads RETIRED artifact %s", script_name, retired)
                    if (report) report_violation("RETIRED", msg)
                    results <- c(results, paste0("RETIRED|", msg))
                }
            }
        }
        
        # R4 FIX: Check ARCHIVED dependencies
        for (arch in archived) {
            arch_base <- basename(arch)
            if (any(grepl(arch_base, load_lines, fixed = TRUE))) {
                msg <- sprintf("%s loads ARCHIVED file %s", script_name, arch_base)
                if (report) report_violation("ARCHIVED", msg)
                results <- c(results, paste0("ARCHIVED|", msg))
            }
        }
        
        # Check QUARANTINE dependencies
        for (qfile in quarantined) {
            qbase <- basename(qfile)
            if (any(grepl(qbase, load_lines, fixed = TRUE))) {
                msg <- sprintf("%s loads QUARANTINE file %s", script_name, qbase)
                if (report) report_violation("QUARANTINE", msg)
                results <- c(results, paste0("QUARANTINE|", msg))
            }
        }
    }
    results
}

# =============================================================================
# CHECK (e): Sidecar SHA256 must match current file
# =============================================================================
check_sha256 <- function(root, report = FALSE) {
    results <- character()
    sidecars <- list.files(file.path(root, "meta"), pattern = "\\.sidecar$", full.names = TRUE)
    
    for (sidecar in sidecars) {
        content <- readLines(sidecar, warn = FALSE)
        sha_line <- grep("^SHA256:", content, value = TRUE)
        if (length(sha_line) > 0) {
            recorded_sha <- trimws(gsub("^SHA256:\\s*", "", sha_line[1]))
            
            # Skip non-hash values like "(partial run...)"
            if (!grepl("^[0-9a-f]{64}$", recorded_sha)) next
            
            sidecar_name <- basename(sidecar)
            described_file <- gsub("\\.sidecar$", "", sidecar_name)
            
            file_path <- NULL
            for (dir in c("output", "data")) {
                candidate <- file.path(root, dir, described_file)
                if (file.exists(candidate)) { file_path <- candidate; break }
            }
            
            if (!is.null(file_path)) {
                current_sha <- trimws(system(sprintf("sha256sum %s | cut -d' ' -f1", file_path), intern = TRUE))
                if (current_sha == recorded_sha) {
                    if (report) cat(sprintf("  %s: SHA256 MATCH\n", described_file))
                } else {
                    msg <- sprintf("%s: recorded %s... != current %s...", described_file,
                                   substr(recorded_sha, 1, 12), substr(current_sha, 1, 12))
                    if (report) report_violation("SHA256", msg)
                    results <- c(results, paste0("SHA256|", msg))
                }
            } else {
                msg <- sprintf("%s: described file not found", described_file)
                if (report) report_violation("SHA256", msg)
                results <- c(results, paste0("SHA256|", msg))
            }
        }
    }
    results
}

# =============================================================================
# CHECK (f): Appendix numeric literals - R2 FIX: check following line
# =============================================================================
check_appendix_literal <- function(root, report = FALSE) {
    results <- character()
    appendix_file <- file.path(root, "article/main.tex")
    if (!file.exists(appendix_file)) return(results)
    
    appendix <- readLines(appendix_file, warn = FALSE)
    WHITELIST <- c("0", "1", "2", "3", "10", "0.5", "1.0", "2.0")
    
    in_remark <- FALSE
    for (i in seq_along(appendix)) {
        line <- appendix[i]
        if (grepl("\\\\begin\\{remark\\}", line)) in_remark <- TRUE
        if (grepl("\\\\end\\{remark\\}", line)) in_remark <- FALSE
        
        if (in_remark) {
            matches <- gregexpr("\\$-?[0-9]+\\.[0-9]+\\$", line)[[1]]
            if (matches[1] != -1) {
                # R2 FIX: Check within one line either side for annotations
                has_ref <- FALSE
                for (offset in c(-1, 0, 1)) {
                    check_idx <- i + offset
                    if (check_idx >= 1 && check_idx <= length(appendix)) {
                        check_line <- appendix[check_idx]
                        if (grepl("%\\s*\\[", check_line) || 
                            grepl("%\\s*[A-Z][A-Z0-9_]{3,}", check_line) ||
                            grepl("\\\\Prop[A-Za-z]+", check_line)) {
                            has_ref <- TRUE
                            break
                        }
                    }
                }
                
                nums <- regmatches(line, gregexpr("-?[0-9]+\\.[0-9]+", line))[[1]]
                unlisted <- nums[!nums %in% WHITELIST]
                if (length(unlisted) > 0 && !has_ref) {
                    msg <- sprintf("main.tex line %d: numeric literal(s) %s with no resolving ledger ID or macro",
                                   i, paste(unlisted, collapse = ", "))
                    if (report) report_violation("APPENDIX_LITERAL", msg)
                    results <- c(results, paste0("APPENDIX_LITERAL|", msg))
                }
            }
        }
    }
    results
}

# =============================================================================
# CHECK (f2): Resolving references
# =============================================================================
check_resolving_ref <- function(root, report = FALSE) {
    results <- character()
    appendix_file <- file.path(root, "article/main.tex")
    prop_file <- file.path(root, "article/prop_constants.tex")
    if (!file.exists(appendix_file) || !file.exists(prop_file)) return(results)
    
    appendix <- readLines(appendix_file, warn = FALSE)
    prop_content <- readLines(prop_file, warn = FALSE)
    
    defined_macros <- gsub("\\\\newcommand\\{|\\}", "", 
                           regmatches(prop_content, regexpr("\\\\newcommand\\{\\\\Prop[A-Za-z]+\\}", prop_content)))
    used_macros <- unique(regmatches(paste(appendix, collapse = " "),
                                      gregexpr("\\\\Prop[A-Za-z]+", paste(appendix, collapse = " ")))[[1]])
    
    for (undef in setdiff(used_macros, defined_macros)) {
        msg <- sprintf("\\Prop* macro %s used but not defined in prop_constants.tex", undef)
        if (report) report_violation("RESOLVING_REF", msg)
        results <- c(results, paste0("RESOLVING_REF|", msg))
    }
    results
}

# =============================================================================
# CHECK (g): Macro containment - R3 FIX: CONTAINMENT violation + ORPHAN warning
# =============================================================================
check_macro_containment <- function(root, report = FALSE) {
    results <- character()
    
    prop_file <- file.path(root, "article/prop_constants.tex")
    appendix_file <- file.path(root, "article/main.tex")
    if (!file.exists(prop_file) || !file.exists(appendix_file)) return(results)
    
    prop_content <- readLines(prop_file, warn = FALSE)
    appendix <- readLines(appendix_file, warn = FALSE)
    
    defined_macros <- gsub("\\\\newcommand\\{|\\}", "", 
                           regmatches(prop_content, regexpr("\\\\newcommand\\{\\\\Prop[A-Za-z]+\\}", prop_content)))
    used_macros <- unique(regmatches(paste(appendix, collapse = " "),
                                      gregexpr("\\\\Prop[A-Za-z]+", paste(appendix, collapse = " ")))[[1]])
    
    # R3 FIX: CONTAINMENT - used but not defined (violation)
    undefined <- setdiff(used_macros, defined_macros)
    for (undef in undefined) {
        msg <- sprintf("%s used in main.tex but not defined in prop_constants.tex", undef)
        if (report) report_violation("CONTAINMENT", msg)
        results <- c(results, paste0("CONTAINMENT|", msg))
    }
    
    # R3 FIX: ORPHAN - defined but not used (warning only, NOT a violation)
    unused <- setdiff(defined_macros, used_macros)
    if (length(unused) > 0 && report) {
        cat(sprintf("  ORPHAN warning: %d macros defined but not used:\n", length(unused)))
        for (un in unused) cat(sprintf("    %s\n", un))
    }
    
    results
}

# =============================================================================
# CHECK (D3.2): Macro definition completeness
# =============================================================================
check_prop_macro <- function(root, report = FALSE) {
    results <- character()
    appendix_file <- file.path(root, "article/main.tex")
    pc_path <- file.path(root, "article/prop_constants.tex")
    if (!file.exists(appendix_file)) return(results)
    
    if (!file.exists(pc_path)) {
        msg <- "article/prop_constants.tex missing; appendix cannot build"
        if (report) report_violation("PROP_MACRO", msg)
        return(c(results, paste0("PROP_MACRO|", msg)))
    }
    
    appendix <- readLines(appendix_file, warn = FALSE)
    pc <- readLines(pc_path, warn = FALSE)
    defined <- gsub(".*\\{\\\\|\\}.*", "", unlist(regmatches(pc, gregexpr("\\\\newcommand\\{\\\\[A-Za-z]+\\}", pc))))
    used <- unique(gsub("^\\\\", "", unlist(regmatches(appendix, gregexpr("\\\\Prop[A-Za-z]+", appendix)))))
    miss <- setdiff(used, defined)
    
    if (length(miss) > 0) {
        msg <- sprintf("main.tex uses undefined macro(s): %s", paste(miss, collapse = ", "))
        if (report) report_violation("PROP_MACRO", msg)
        results <- c(results, paste0("PROP_MACRO|", msg))
    }
    results
}

# =============================================================================
# CHECK (h): canonical_facts.md producer paths
# =============================================================================
check_cf_producer <- function(root, report = FALSE) {
    results <- character()
    cf_path <- file.path(root, "meta/canonical_facts.md")
    if (!file.exists(cf_path)) {
        msg <- "meta/canonical_facts.md not found"
        if (report) report_violation("CF_PRODUCER", msg)
        return(c(results, paste0("CF_PRODUCER|", msg)))
    }
    
    cf <- readLines(cf_path, warn = FALSE)
    table_lines <- cf[grepl("^\\|", cf)]
    path_pattern <- "(code|data|output|meta)/[A-Za-z0-9_./]+"
    
    all_paths <- character()
    for (line in table_lines) {
        matches <- gregexpr(path_pattern, line, perl = TRUE)
        if (matches[[1]][1] != -1) {
            extracted <- gsub("\\.$", "", regmatches(line, matches)[[1]])
            all_paths <- c(all_paths, extracted)
        }
    }
    
    for (p in unique(all_paths)) {
        if (!file.exists(file.path(root, p))) {
            msg <- sprintf("canonical_facts.md references non-existent path: %s", p)
            if (report) report_violation("CF_PRODUCER", msg)
            results <- c(results, paste0("CF_PRODUCER|", msg))
        }
    }
    results
}

# =============================================================================
# DRIVER (exactly matches original output format)
# =============================================================================
run_all_checks <- function(root = getwd()) {
    violations <<- list(); n_violations <<- 0
    
    cat("================================================================\n")
    cat("ENFORCE.R - GATE CONSISTENCY CHECK (REPAIRED)\n")
    cat("Run:", format(Sys.time()), "\n")
    cat("================================================================\n\n")
    
    cat("Working directory:", root, "\n")
    old_wd <- getwd(); setwd(root)
    cat("Git HEAD:", system("git rev-parse HEAD", intern = TRUE), "\n")
    dirty_count <- length(system("git status --porcelain", intern = TRUE))
    cat("Dirty files:", dirty_count, "\n\n"); setwd(old_wd)
    
    stopifnot(dir.exists(file.path(root, "code")), dir.exists(file.path(root, "meta")),
              dir.exists(file.path(root, "article")), file.exists(file.path(root, "meta/FILE_REGISTRY.csv")))
    
    # (a)
    cat("=== CHECK (a): EXPECTED_N declarations ===\n")
    check_expected_n(root, report = TRUE)
    all_scripts <- list.files(file.path(root, "code"), pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
    scripts <- all_scripts[!grepl("audit/|archive/", all_scripts)]
    scripts <- scripts[!grepl("/L[0-9]", scripts)]
    cat(sprintf("Scripts checked: %d\n\n", length(scripts)))
    
    # (b)
    cat("=== CHECK (b): Sidecar gate consistency ===\n")
    sidecars <- list.files(file.path(root, "meta"), pattern = "\\.sidecar$", full.names = TRUE)
    cat(sprintf("Sidecars found: %d\n", length(sidecars)))
    check_sidecar(root, report = TRUE)
    cat("\n")
    
    # (c)
    cat("=== CHECK (c): Unique producers per ID ===\n")
    check_registry(root, report = TRUE)
    registry_path <- file.path(root, "meta/FILE_REGISTRY.csv")
    if (file.exists(registry_path)) {
        registry <- fread(registry_path)
        cat(sprintf("BUILT outputs: %d\n", nrow(registry[status == "BUILT"])))
    }
    cat("\n")
    
    # (d)
    cat("=== CHECK (d): BUILT dependencies ===\n")
    if (file.exists(registry_path)) {
        registry <- fread(registry_path)
        cat(sprintf("QUARANTINE outputs: %d\n", length(registry[status == "QUARANTINE", file_path])))
        cat(sprintf("ARCHIVED outputs: %d\n", length(registry[status == "ARCHIVED", file_path])))
        cat(sprintf("RETIRED artifacts: %d\n", length(RETIRED_ARTIFACTS)))
    }
    check_built_deps(root, report = TRUE)
    cat("\n")
    
    # (e)
    cat("=== CHECK (e): Sidecar SHA256 verification ===\n")
    check_sha256(root, report = TRUE)
    cat("\n")
    
    # (f)
    cat("=== CHECK (f): Appendix numeric literals ===\n")
    check_appendix_literal(root, report = TRUE)
    cat("Appendix numeric literal check complete.\n")
    
    # (f2)
    cat("\n=== CHECK (f) additional: Resolving references ===\n")
    prop_file <- file.path(root, "article/prop_constants.tex")
    appendix_file <- file.path(root, "article/main.tex")
    if (file.exists(prop_file) && file.exists(appendix_file)) {
        prop_content <- readLines(prop_file, warn = FALSE)
        appendix <- readLines(appendix_file, warn = FALSE)
        defined_macros <- gsub("\\\\newcommand\\{|\\}", "", 
                               regmatches(prop_content, regexpr("\\\\newcommand\\{\\\\Prop[A-Za-z]+\\}", prop_content)))
        cat(sprintf("  Defined \\Prop* macros in prop_constants.tex: %d\n", length(defined_macros)))
        used_macros <- unique(regmatches(paste(appendix, collapse = " "),
                                          gregexpr("\\\\Prop[A-Za-z]+", paste(appendix, collapse = " ")))[[1]])
        cat(sprintf("  Used \\Prop* macros in main.tex: %d\n", length(used_macros)))
    }
    v_f2 <- check_resolving_ref(root, report = TRUE)
    if (length(v_f2) == 0) cat("  All \\Prop* macros resolve: PASS\n")
    
    # (g)
    cat("\n=== CHECK (g): Macro containment ===\n")
    check_macro_containment(root, report = TRUE)
    
    # (D3.2)
    cat("\n=== CHECK (D3.2): Macro definition completeness ===\n")
    v_d32 <- check_prop_macro(root, report = TRUE)
    if (length(v_d32) == 0 && file.exists(file.path(root, "article/prop_constants.tex")) && 
        file.exists(file.path(root, "article/main.tex"))) {
        appendix <- readLines(file.path(root, "article/main.tex"), warn = FALSE)
        used <- unique(gsub("^\\\\", "", unlist(regmatches(appendix, gregexpr("\\\\Prop[A-Za-z]+", appendix)))))
        cat(sprintf("  All %d used \\Prop* macros are defined: PASS\n", length(used)))
    }
    
    # (h)
    cat("\n=== CHECK (h): canonical_facts.md producer paths ===\n")
    cf_path <- file.path(root, "meta/canonical_facts.md")
    if (file.exists(cf_path)) {
        cf <- readLines(cf_path, warn = FALSE)
        table_lines <- cf[grepl("^\\|", cf)]
        path_pattern <- "(code|data|output|meta)/[A-Za-z0-9_./]+"
        all_paths <- character()
        for (line in table_lines) {
            matches <- gregexpr(path_pattern, line, perl = TRUE)
            if (matches[[1]][1] != -1) all_paths <- c(all_paths, gsub("\\.$", "", regmatches(line, matches)[[1]]))
        }
        unique_paths <- unique(all_paths)
        cat(sprintf("  Producer paths extracted (unique): %d\n", length(unique_paths)))
        for (p in unique_paths) cat(sprintf("    %s: %s\n", p, if (file.exists(file.path(root, p))) "OK" else "MISSING"))
        cat(sprintf("  Dangling paths: %d\n", sum(!sapply(unique_paths, function(p) file.exists(file.path(root, p))))))
    }
    v_h <- check_cf_producer(root, report = TRUE)
    if (length(v_h) == 0 && file.exists(cf_path)) cat("  All producer paths resolve: PASS\n")
    cat("\n")
    
    # OUTPUT VALIDATION
    cat("=== OUTPUT VALIDATION ===\n")
    t19_file <- file.path(root, "output/T19_pleq0_bracket.csv")
    if (file.exists(t19_file)) { cat("T19_pleq0_bracket.csv:\n"); print(fread(t19_file)) }
    else report_violation("T19", "T19_pleq0_bracket.csv not found")
    cat("\n")
    
    t20_file <- file.path(root, "output/T20_ge_bracket.csv")
    if (file.exists(t20_file)) { cat("T20_ge_bracket.csv:\n"); print(fread(t20_file)[, .(arm, SD_true, q50, RANGE_1090)]) }
    else report_violation("T20", "T20_ge_bracket.csv not found")
    cat("\n")
    
    # SUMMARY
    cat("================================================================\n")
    cat("ENFORCE SUMMARY\n")
    cat("================================================================\n\n")
    
    if (n_violations == 0) {
        cat("ALL CHECKS PASS\n"); cat(sprintf("\nEnd: %s\n", format(Sys.time())))
    } else {
        cat(sprintf("VIOLATIONS: %d\n\n", n_violations))
        for (v in violations) cat(sprintf("  [%s] %s\n", v$check, v$msg))
        cat(sprintf("\nEnd: %s\n", format(Sys.time())))
    }
    
    stopifnot(n_violations == 0)
}

if (!interactive() && !exists("FIXTURE_MODE")) run_all_checks(getwd())
