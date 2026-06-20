#!/usr/bin/env Rscript

command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)

if (length(file_argument) != 1) {
  stop("Cannot determine the script path. Run with Rscript.")
}

script_path <- normalizePath(sub("^--file=", "", file_argument))
project_dir <- normalizePath(file.path(dirname(script_path), ".."))
results_dir <- file.path(project_dir, "results")
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

args <- commandArgs(trailingOnly = TRUE)
input_argument <- if (length(args) >= 1) args[1] else "data/pubmed_records.csv"

if (grepl("^/", input_argument)) {
  input_file <- input_argument
} else {
  input_file <- file.path(project_dir, input_argument)
}

if (!file.exists(input_file)) {
  stop(
    "Input file not found: ", input_file,
    "\nRun: python3 scripts/01_fetch_pubmed.py"
  )
}

papers <- read.csv(input_file, stringsAsFactors = FALSE, check.names = FALSE)

required_columns <- c("pmid", "title", "year", "journal", "doi")
missing_columns <- setdiff(required_columns, colnames(papers))

if (length(missing_columns) > 0) {
  stop("Missing columns: ", paste(missing_columns, collapse = ", "))
}

notes <- data.frame(
  pmid = papers$pmid,
  title = papers$title,
  year = papers$year,
  journal = papers$journal,
  doi = papers$doi,
  research_question = "",
  species = "",
  methods = "",
  key_evidence = "",
  main_finding = "",
  limitations = "",
  relevance_to_nac20 = "",
  read_status = "not_started",
  stringsAsFactors = FALSE
)

write.csv(
  notes,
  file.path(results_dir, "literature_notes_template.csv"),
  row.names = FALSE,
  na = ""
)

cat("Literature note template created for", nrow(notes), "records.\n")
cat("Fill interpretation columns manually after reading each paper.\n")

