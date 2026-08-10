# S48_environment.R — Record the R environment
# Writes meta/ENVIRONMENT.txt and its sidecar
RTA_ROOT <- Sys.getenv("RTA_ROOT", unset = ".")
stopifnot(file.exists(file.path(RTA_ROOT, "meta", "FILE_REGISTRY.csv")))

# Derive package list from code/*.R
code_files <- list.files(file.path(RTA_ROOT, "code"), pattern = "\\.R$",
                         full.names = TRUE, recursive = TRUE)
code_text <- unlist(lapply(code_files, readLines, warn = FALSE))
lib_pat <- "(?:library|require)\\s*\\(\\s*[\"']?([A-Za-z0-9.]+)[\"']?\\s*\\)"
lib_matches <- regmatches(code_text, gregexpr(lib_pat, code_text, perl = TRUE))
lib_pkgs <- unique(unlist(lapply(unlist(lib_matches), function(x)
  sub(".*\\(\\s*[\"']?([A-Za-z0-9.]+)[\"']?\\s*\\).*", "\\1", x))))
ns_pat <- "([A-Za-z][A-Za-z0-9.]*)::"
ns_matches <- regmatches(code_text, gregexpr(ns_pat, code_text, perl = TRUE))
ns_pkgs <- setdiff(unique(sub("::", "", unlist(ns_matches))), c("", "namespace", "base"))
all_pkgs <- sort(unique(c(lib_pkgs, ns_pkgs)))

# Collect package info
pkg_info <- Filter(Negate(is.null), lapply(all_pkgs, function(p) {
  desc <- tryCatch(packageDescription(p), error = function(e) NULL)
  if (is.null(desc) || !is.list(desc)) return(NULL)
  libp <- tryCatch(dirname(dirname(find.package(p))), error = function(e) NA)
  list(package = p, version = as.character(desc$Version),
       built = if (is.null(desc$Built)) "NA" else as.character(desc$Built),
       libpath = if (is.na(libp)) "NA" else libp)
}))

# Write meta/ENVIRONMENT.txt
out_path <- file.path(RTA_ROOT, "meta", "ENVIRONMENT.txt")
lines <- c(sprintf("R_VERSION:        %s", R.version.string),
           sprintf("PLATFORM:         %s", R.version$platform),
           sprintf("CREATED:          %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")), "")
for (info in pkg_info) {
  lines <- c(lines, sprintf("PACKAGE:          %s", info$package),
             sprintf("  VERSION:        %s", info$version),
             sprintf("  BUILT:          %s", info$built),
             sprintf("  LIBPATH:        %s", info$libpath), "")
}
writeLines(lines, out_path)

# Write sidecar
sidecar_path <- paste0(out_path, ".sidecar")
env_sha <- sub("\\s+.*", "", system2("shasum", c("-a", "256", out_path), stdout = TRUE))
script_path <- file.path(RTA_ROOT, "code", "S48_environment.R")
script_sha <- sub("\\s+.*", "", system2("shasum", c("-a", "256", script_path), stdout = TRUE))
writeLines(c(sprintf("FILE:             %s", "meta/ENVIRONMENT.txt"),
             sprintf("SHA256:           %s", env_sha),
             sprintf("PRODUCER:         %s", "code/S48_environment.R"),
             sprintf("PRODUCER_SHA256:  %s", script_sha),
             sprintf("INPUTS:           %s", "code/*.R"),
             sprintf("SEED:             %s", "none"),
             sprintf("R_VERSION:        %s", R.version.string),
             sprintf("CREATED:          %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"))),
           sidecar_path)
cat("Wrote", out_path, "and", sidecar_path, "\n")
