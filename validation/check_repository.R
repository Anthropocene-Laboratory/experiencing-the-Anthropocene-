#!/usr/bin/env Rscript

# Fast repository checks. This script downloads no data and runs no analysis.

find_root <- function() {
  args <- commandArgs(trailingOnly=FALSE)
  hit <- grep("^--file=", args, value=TRUE)
  candidate <- if (length(hit)) {
    dirname(normalizePath(sub("^--file=", "", hit[1]), winslash="/"))
  } else {
    normalizePath(getwd(), winslash="/")
  }
  while (!file.exists(file.path(candidate, ".here"))) {
    parent <- dirname(candidate)
    if (identical(parent, candidate)) stop("Repository root not found: no .here marker.")
    candidate <- parent
  }
  normalizePath(candidate, winslash="/")
}

root <- find_root()
setwd(root)

failures <- character()
record_failure <- function(...) failures <<- c(failures, paste0(...))

required <- c(
  "README.md", "AGENTS.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md",
  "LICENSE", "LICENSING.md", "CITATION.cff", "data_sources.md",
  "docs/README.md", "docs/getting-started.md", "docs/workflows.md",
  "docs/troubleshooting.md", "docs/reproducibility.md",
  ".github/ISSUE_TEMPLATE/bug_report.yml",
  ".github/ISSUE_TEMPLATE/data_or_provenance.yml",
  ".github/ISSUE_TEMPLATE/method_question.yml",
  ".github/ISSUE_TEMPLATE/usage_question.yml",
  ".github/ISSUE_TEMPLATE/config.yml",
  ".github/workflows/repository-checks.yml",
  ".github/pull_request_template.md"
)
missing_required <- required[!file.exists(required)]
if (length(missing_required)) {
  record_failure("Missing required repository file(s): ",
                 paste(missing_required, collapse=", "))
}

git <- Sys.which("git")
if (!nzchar(git)) stop("git is required for repository validation.")
rel <- system2(unname(git),
               c("-C", shQuote(root), "ls-files", "--cached", "--others",
                 "--exclude-standard"), stdout=TRUE)
rel <- gsub("\\\\", "/", rel)
rel <- rel[nzchar(rel) & file.exists(file.path(root, rel))]
all_files <- file.path(root, rel)

r_files <- all_files[grepl("[.]R$", rel, ignore.case=TRUE)]
for (file in r_files) {
  tryCatch(
    parse(file=file, encoding="UTF-8"),
    error=function(e) record_failure("R parse failure in ",
                                     substring(normalizePath(file, winslash="/"), nchar(root)+2L),
                                     ": ", conditionMessage(e))
  )
}

script_files <- all_files[grepl("[.](R|py)$", rel, ignore.case=TRUE)]
personal_path_patterns <- c(
  "[A-Za-z]:[/\\\\]Users[/\\\\][A-Za-z0-9._-]+",
  "/Users/[A-Za-z0-9._-]+",
  "/home/[A-Za-z0-9._-]+",
  "OneDrive[ ]-[ ][^/\\\\\"']+"
)
for (file in script_files) {
  lines <- readLines(file, warn=FALSE, encoding="UTF-8")
  for (pattern in personal_path_patterns) {
    hit <- grep(pattern, lines, perl=TRUE)
    if (length(hit)) {
      rel_file <- substring(normalizePath(file, winslash="/"), nchar(root)+2L)
      record_failure("Personal path in executable file ", rel_file, ":",
                     paste(hit, collapse=","))
    }
  }
}

markdown_files <- all_files[grepl("[.]md$", rel, ignore.case=TRUE)]
for (file in markdown_files) {
  lines <- readLines(file, warn=FALSE, encoding="UTF-8")
  text <- paste(lines, collapse="\n")
  match_pos <- gregexpr("!?\\[[^]]*\\]\\(([^)]+)\\)", text, perl=TRUE)[[1]]
  if (identical(match_pos[1], -1L)) next
  links <- regmatches(text, list(match_pos))[[1]]
  targets <- sub("^!?\\[[^]]*\\]\\(([^)]+)\\)$", "\\1", links, perl=TRUE)
  targets <- trimws(targets)
  targets <- sub("[[:space:]]+['\"].*['\"]$", "", targets)
  targets <- sub("^<|>$", "", targets)
  targets <- targets[!grepl("^(https?://|mailto:|#)", targets, ignore.case=TRUE)]
  targets <- sub("#.*$", "", targets)
  targets <- utils::URLdecode(targets[nzchar(targets)])
  for (target in unique(targets)) {
    resolved <- normalizePath(file.path(dirname(file), target), winslash="/", mustWork=FALSE)
    if (!file.exists(resolved)) {
      rel_file <- substring(normalizePath(file, winslash="/"), nchar(root)+2L)
      record_failure("Broken local Markdown link in ", rel_file, ": ", target)
    }
  }
}

tracked <- system2(unname(git), c("-C", shQuote(root), "ls-files"), stdout=TRUE)
tracked_raw <- tracked[grepl("(^|/)data_raw/", tracked)]
if (length(tracked_raw)) {
  record_failure("Raw data tracked by git: ", paste(tracked_raw, collapse=", "))
}

if (length(failures)) {
  cat("Repository checks FAILED\n\n")
  for (failure in unique(failures)) cat("- ", failure, "\n", sep="")
  quit(status=1L)
}

cat("Repository checks passed\n")
cat("  required files : ", length(required), "\n", sep="")
cat("  R files parsed : ", length(r_files), "\n", sep="")
cat("  scripts scanned: ", length(script_files), "\n", sep="")
cat("  Markdown files : ", length(markdown_files), "\n", sep="")
