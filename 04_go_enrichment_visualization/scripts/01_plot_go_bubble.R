#!/usr/bin/env Rscript

# ============================================================
# GO enrichment bubble plot
#
# Usage:
# Rscript scripts/01_plot_go_bubble.R "path/to/go_enrich_stat.xls" 10
#
# Argument 1: input GO enrichment table
# Argument 2: optional number of terms per ontology; default = 10
# ============================================================

# ------------------------------------------------------------
# 1. Locate this project
# ------------------------------------------------------------
# commandArgs(trailingOnly = FALSE) contains the --file= argument added by
# Rscript. We use it to find the script and then the project directory.
command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)

if (length(file_argument) != 1) {
  stop("Cannot determine the script path. Please run this file with Rscript.")
}

script_path <- normalizePath(sub("^--file=", "", file_argument))
project_dir <- normalizePath(file.path(dirname(script_path), ".."))
results_dir <- file.path(project_dir, "results")
figures_dir <- file.path(project_dir, "figures")

dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------
# 2. Read command-line arguments
# ------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)

default_input <- file.path(project_dir, "data", "go_enrich_stat.xls")

if (length(args) >= 1) {
  input_file <- normalizePath(args[1], mustWork = TRUE)
} else if (file.exists(default_input)) {
  input_file <- normalizePath(default_input, mustWork = TRUE)
} else {
  stop(
    "No input file was supplied.\n",
    "Run:\n",
    "Rscript scripts/01_plot_go_bubble.R \"path/to/go_enrich_stat.xls\""
  )
}

top_n <- if (length(args) >= 2) as.integer(args[2]) else 10L

if (is.na(top_n) || top_n < 1) {
  stop("The number of terms per ontology must be a positive integer.")
}

fdr_cutoff <- 0.05

# ------------------------------------------------------------
# 3. Check packages before analysis
# ------------------------------------------------------------
required_packages <- c("ggplot2", "dplyr", "stringr", "scales")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Missing R packages: ",
    paste(missing_packages, collapse = ", "),
    "\nInstall them with:\n",
    "install.packages(c(",
    paste(sprintf("\"%s\"", missing_packages), collapse = ", "),
    "))"
  )
}

# ------------------------------------------------------------
# 4. Read the input table
# ------------------------------------------------------------
# Although the file extension is .xls, this specific file is a tab-separated
# plain-text table. read.delim() is therefore the correct reader.
go_raw <- read.delim(
  input_file,
  header = TRUE,
  sep = "\t",
  quote = "",
  comment.char = "",
  check.names = FALSE,
  stringsAsFactors = FALSE
)

# ------------------------------------------------------------
# 5. Validate required columns
# ------------------------------------------------------------
required_columns <- c(
  "go_id",
  "go_type",
  "discription",
  "p_corrected",
  "enrich_factor",
  "study_count"
)

missing_columns <- setdiff(required_columns, colnames(go_raw))

if (length(missing_columns) > 0) {
  stop(
    "The input table is missing required columns: ",
    paste(missing_columns, collapse = ", ")
  )
}

# ------------------------------------------------------------
# 6. Clean and validate analytical fields
# ------------------------------------------------------------
go_clean <- go_raw |>
  dplyr::mutate(
    go_id = trimws(as.character(go_id)),
    go_type = toupper(trimws(as.character(go_type))),
    discription = trimws(as.character(discription)),
    p_corrected = suppressWarnings(as.numeric(p_corrected)),
    enrich_factor = suppressWarnings(as.numeric(enrich_factor)),
    study_count = suppressWarnings(as.numeric(study_count))
  ) |>
  dplyr::filter(
    go_type %in% c("BP", "CC", "MF"),
    nzchar(go_id),
    nzchar(discription),
    is.finite(p_corrected),
    p_corrected > 0,
    p_corrected <= 1,
    is.finite(enrich_factor),
    enrich_factor >= 0,
    is.finite(study_count),
    study_count > 0
  )

if (nrow(go_clean) == 0) {
  stop("No valid GO records remained after data cleaning.")
}

# ------------------------------------------------------------
# 7. Keep significant records and select top terms per ontology
# ------------------------------------------------------------
# Ranking priority:
# 1. smaller adjusted p-value (FDR)
# 2. larger Rich factor when FDR values are tied
# 3. larger DEG count when both above are tied
go_selected <- go_clean |>
  dplyr::filter(p_corrected < fdr_cutoff) |>
  dplyr::group_by(go_type) |>
  dplyr::arrange(
    p_corrected,
    dplyr::desc(enrich_factor),
    dplyr::desc(study_count),
    .by_group = TRUE
  ) |>
  dplyr::slice_head(n = top_n) |>
  dplyr::ungroup()

if (nrow(go_selected) == 0) {
  stop(
    "No GO terms passed FDR < ",
    fdr_cutoff,
    ". Consider checking the input or changing the cutoff."
  )
}

# Warn if an ontology has fewer than the requested number of significant terms.
ontology_counts <- table(go_selected$go_type)
for (ontology in c("BP", "CC", "MF")) {
  selected_count <- if (ontology %in% names(ontology_counts)) {
    unname(ontology_counts[[ontology]])
  } else {
    0L
  }

  if (selected_count < top_n) {
    warning(
      ontology,
      " contains only ",
      selected_count,
      " selected significant terms; requested ",
      top_n,
      "."
    )
  }
}

# ------------------------------------------------------------
# 8. Prepare labels, significance and plotting order
# ------------------------------------------------------------
ontology_labels <- c(
  "BP" = "Biological process (BP)",
  "CC" = "Cellular component (CC)",
  "MF" = "Molecular function (MF)"
)

go_selected <- go_selected |>
  dplyr::mutate(
    neg_log10_fdr = -log10(p_corrected),
    go_type = factor(go_type, levels = c("BP", "CC", "MF")),
    go_type_label = factor(
      ontology_labels[as.character(go_type)],
      levels = unname(ontology_labels)
    ),
    # Long GO descriptions are wrapped onto multiple lines.
    term_label = paste0(
      stringr::str_wrap(discription, width = 46),
      "\n",
      go_id
    )
  ) |>
  # Sorting ascending here puts larger Rich factors nearer the top of each panel.
  dplyr::arrange(go_type, enrich_factor, study_count) |>
  dplyr::mutate(
    term_panel = paste(term_label, go_type, sep = "___"),
    term_panel = factor(term_panel, levels = unique(term_panel))
  )

# Save the exact rows used in the figure for reproducibility.
output_columns <- c(
  "go_id",
  "go_type",
  "discription",
  "p_corrected",
  "neg_log10_fdr",
  "enrich_factor",
  "study_count"
)

write.csv(
  go_selected[, output_columns],
  file.path(results_dir, "top_go_terms.csv"),
  row.names = FALSE,
  na = ""
)

# ------------------------------------------------------------
# 9. Build the publication-style bubble plot
# ------------------------------------------------------------
go_plot <- ggplot2::ggplot(
  go_selected,
  ggplot2::aes(
    x = enrich_factor,
    y = term_panel,
    size = study_count,
    fill = neg_log10_fdr
  )
) +
  ggplot2::geom_point(
    shape = 21,
    color = "#24323D",
    stroke = 0.45,
    alpha = 0.95
  ) +
  ggplot2::facet_wrap(
    facets = ggplot2::vars(go_type_label),
    ncol = 1,
    scales = "free_y",
    strip.position = "top"
  ) +
  ggplot2::scale_y_discrete(
    labels = function(x) sub("___.*$", "", x),
    expand = ggplot2::expansion(add = 0.65)
  ) +
  ggplot2::scale_x_continuous(
    labels = scales::number_format(accuracy = 0.1),
    expand = ggplot2::expansion(mult = c(0.03, 0.08))
  ) +
  ggplot2::scale_size_continuous(
    name = "DEG count",
    range = c(3.2, 10.5),
    breaks = scales::breaks_pretty(n = 4)
  ) +
  ggplot2::scale_fill_gradient(
    name = expression(-log[10]("FDR")),
    low = "#C6DBEF",
    high = "#08306B"
  ) +
  ggplot2::labs(
    title = "GO enrichment analysis: A_vs_B_G",
    subtitle = paste0(
      "Top ",
      top_n,
      " FDR-significant terms per ontology (FDR < ",
      fdr_cutoff,
      ")"
    ),
    x = "Rich factor (DEGs annotated to term / all genes annotated to term)",
    y = NULL,
    caption = paste0(
      "Source: ",
      basename(input_file),
      "  |  Selection: adjusted P value, then Rich factor and DEG count"
    )
  ) +
  ggplot2::guides(
    fill = ggplot2::guide_colorbar(
      order = 1,
      title.position = "top",
      barheight = grid::unit(45, "mm")
    ),
    size = ggplot2::guide_legend(
      order = 2,
      title.position = "top"
    )
  ) +
  ggplot2::theme_minimal(base_size = 11.5, base_family = "sans") +
  ggplot2::theme(
    plot.background = ggplot2::element_rect(fill = "white", color = NA),
    panel.background = ggplot2::element_rect(fill = "white", color = NA),
    panel.grid.major.y = ggplot2::element_line(
      color = "#E6E9EC",
      linewidth = 0.35
    ),
    panel.grid.major.x = ggplot2::element_line(
      color = "#D8DDE2",
      linewidth = 0.35
    ),
    panel.grid.minor = ggplot2::element_blank(),
    axis.title.x = ggplot2::element_text(
      size = 11.5,
      margin = ggplot2::margin(t = 10)
    ),
    axis.text.x = ggplot2::element_text(
      size = 10,
      color = "#28323C"
    ),
    axis.text.y = ggplot2::element_text(
      size = 8.8,
      color = "#28323C",
      lineheight = 0.92
    ),
    axis.ticks = ggplot2::element_line(
      color = "#606A73",
      linewidth = 0.35
    ),
    strip.background = ggplot2::element_rect(
      fill = "#EEF1F4",
      color = "#C4CBD1",
      linewidth = 0.45
    ),
    strip.text = ggplot2::element_text(
      face = "bold",
      size = 10,
      color = "#27333C",
      hjust = 0,
      margin = ggplot2::margin(6, 8, 6, 8)
    ),
    panel.spacing.y = grid::unit(7, "pt"),
    legend.position = "right",
    legend.box = "vertical",
    legend.title = ggplot2::element_text(
      face = "bold",
      size = 10
    ),
    legend.text = ggplot2::element_text(size = 9),
    plot.title = ggplot2::element_text(
      face = "bold",
      size = 16,
      color = "#18242E",
      margin = ggplot2::margin(b = 5)
    ),
    plot.subtitle = ggplot2::element_text(
      size = 10.5,
      color = "#53616D",
      margin = ggplot2::margin(b = 12)
    ),
    plot.caption = ggplot2::element_text(
      size = 8.5,
      color = "#687580",
      hjust = 0,
      margin = ggplot2::margin(t = 10)
    ),
    plot.margin = ggplot2::margin(18, 22, 16, 18)
  )

# ------------------------------------------------------------
# 10. Export a high-resolution PNG and a vector PDF
# ------------------------------------------------------------
png_file <- file.path(figures_dir, "go_bubble_plot.png")
pdf_file <- file.path(figures_dir, "go_bubble_plot.pdf")

ggplot2::ggsave(
  filename = png_file,
  plot = go_plot,
  width = 12.5,
  height = 12,
  units = "in",
  dpi = 600,
  bg = "white"
)

ggplot2::ggsave(
  filename = pdf_file,
  plot = go_plot,
  width = 12.5,
  height = 12,
  units = "in",
  bg = "white"
)

# ------------------------------------------------------------
# 11. Print a compact audit summary
# ------------------------------------------------------------
cat("Input file:", input_file, "\n")
cat("Input rows:", nrow(go_raw), "\n")
cat("Valid rows:", nrow(go_clean), "\n")
cat("Selected rows:", nrow(go_selected), "\n")
cat("Selected by ontology:\n")
print(table(go_selected$go_type))
cat("Saved table:", file.path(results_dir, "top_go_terms.csv"), "\n")
cat("Saved PNG:", png_file, "\n")
cat("Saved PDF:", pdf_file, "\n")
