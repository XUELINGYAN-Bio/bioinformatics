#!/usr/bin/env Rscript

command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)

if (length(file_argument) != 1) {
  stop("Cannot determine the script path. Run with Rscript.")
}

script_path <- normalizePath(sub("^--file=", "", file_argument))
project_dir <- normalizePath(file.path(dirname(script_path), ".."))
results_dir <- file.path(project_dir, "results")
figures_dir <- file.path(project_dir, "figures")

dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(figures_dir, showWarnings = FALSE, recursive = TRUE)

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

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Missing R package: ggplot2")
}

papers <- read.csv(
  input_file,
  stringsAsFactors = FALSE,
  check.names = FALSE
)

required_columns <- c("pmid", "title", "year", "abstract")
missing_columns <- setdiff(required_columns, colnames(papers))

if (length(missing_columns) > 0) {
  stop("Missing columns: ", paste(missing_columns, collapse = ", "))
}

papers$title[is.na(papers$title)] <- ""
papers$abstract[is.na(papers$abstract)] <- ""
papers$text <- paste(papers$title, papers$abstract)

# Count how many papers contain each keyword at least once.
keywords <- c(
  "NAC20",
  "transcription factor",
  "rice",
  "wheat",
  "Arabidopsis",
  "stress",
  "drought",
  "salt",
  "root",
  "seed"
)

keyword_counts <- data.frame(
  keyword = keywords,
  paper_count = vapply(
    keywords,
    function(keyword) {
      sum(grepl(keyword, papers$text, ignore.case = TRUE, fixed = TRUE))
    },
    integer(1)
  )
)

keyword_counts <- keyword_counts[
  order(keyword_counts$paper_count, decreasing = TRUE),
]

write.csv(
  keyword_counts,
  file.path(results_dir, "keyword_counts.csv"),
  row.names = FALSE
)

# Convert valid years to integers and count papers per year.
paper_years <- suppressWarnings(as.integer(papers$year))
valid_years <- paper_years[!is.na(paper_years)]

if (length(valid_years) > 0) {
  year_counts <- as.data.frame(table(valid_years), stringsAsFactors = FALSE)
  colnames(year_counts) <- c("year", "paper_count")
  year_counts$year <- as.integer(year_counts$year)
  year_counts$paper_count <- as.integer(year_counts$paper_count)
  year_counts <- year_counts[order(year_counts$year), ]
} else {
  year_counts <- data.frame(
    year = integer(),
    paper_count = integer()
  )
}

write.csv(
  year_counts,
  file.path(results_dir, "publication_year_counts.csv"),
  row.names = FALSE
)

keyword_plot_data <- keyword_counts[keyword_counts$paper_count > 0, ]

if (nrow(keyword_plot_data) > 0) {
  keyword_plot_data$keyword <- factor(
    keyword_plot_data$keyword,
    levels = rev(keyword_plot_data$keyword)
  )

  keyword_plot <- ggplot2::ggplot(
    keyword_plot_data,
    ggplot2::aes(x = keyword, y = paper_count)
  ) +
    ggplot2::geom_col(fill = "#2C7FB8") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Keywords in PubMed titles and abstracts",
      x = "Keyword",
      y = "Number of papers"
    ) +
    ggplot2::theme_bw(base_size = 12)

  ggplot2::ggsave(
    file.path(figures_dir, "keyword_counts.png"),
    keyword_plot,
    width = 7,
    height = 5,
    dpi = 300
  )
}

if (nrow(year_counts) > 0) {
  year_plot <- ggplot2::ggplot(
    year_counts,
    ggplot2::aes(x = year, y = paper_count)
  ) +
    ggplot2::geom_col(fill = "#41AB5D") +
    ggplot2::scale_x_continuous(breaks = year_counts$year) +
    ggplot2::labs(
      title = "PubMed records by publication year",
      x = "Year",
      y = "Number of papers"
    ) +
    ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )

  ggplot2::ggsave(
    file.path(figures_dir, "publication_years.png"),
    year_plot,
    width = 8,
    height = 5,
    dpi = 300
  )
}

cat("Number of PubMed records:", nrow(papers), "\n")
cat("Text-mining summary written to results/ and figures/.\n")

