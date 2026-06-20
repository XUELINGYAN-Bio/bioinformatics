#!/usr/bin/env Rscript

# This is an offline teaching example of over-representation analysis.
# The gene sets are simulated and must not be interpreted biologically.

command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)

if (length(file_argument) != 1) {
  stop("Cannot determine the script path. Run with Rscript.")
}

script_path <- normalizePath(sub("^--file=", "", file_argument))
project_dir <- normalizePath(file.path(dirname(script_path), ".."))
data_dir <- file.path(project_dir, "data")
results_dir <- file.path(project_dir, "results")
figures_dir <- file.path(project_dir, "figures")

dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(figures_dir, showWarnings = FALSE, recursive = TRUE)

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Missing R package: ggplot2")
}

all_results_file <- file.path(results_dir, "all_deseq2_results.csv")
deg_file <- file.path(results_dir, "deg_results.csv")

if (!file.exists(all_results_file) || !file.exists(deg_file)) {
  stop("Run scripts/01_deseq2_analysis.R before enrichment analysis.")
}

all_results <- read.csv(all_results_file, stringsAsFactors = FALSE)
deg_results <- read.csv(deg_file, stringsAsFactors = FALSE)
gene_sets <- read.csv(
  file.path(data_dir, "gene_sets.csv"),
  stringsAsFactors = FALSE
)

universe <- unique(all_results$gene_id[!is.na(all_results$padj)])
selected_genes <- unique(deg_results$gene_id)
gene_sets <- gene_sets[gene_sets$gene_id %in% universe, ]

if (length(selected_genes) == 0) {
  stop("No DEG passed the current thresholds, so enrichment cannot be run.")
}

set_names <- sort(unique(gene_sets$gene_set))

enrichment_list <- lapply(set_names, function(set_name) {
  members <- unique(gene_sets$gene_id[gene_sets$gene_set == set_name])

  overlap_genes <- intersect(selected_genes, members)
  overlap_count <- length(overlap_genes)
  set_size <- length(members)
  selected_size <- length(selected_genes)
  universe_size <- length(universe)

  # P(X >= overlap_count) from a hypergeometric distribution.
  p_value <- phyper(
    overlap_count - 1,
    set_size,
    universe_size - set_size,
    selected_size,
    lower.tail = FALSE
  )

  data.frame(
    gene_set = set_name,
    overlap_count = overlap_count,
    set_size = set_size,
    selected_size = selected_size,
    universe_size = universe_size,
    pvalue = p_value,
    overlap_genes = paste(overlap_genes, collapse = ";"),
    stringsAsFactors = FALSE
  )
})

enrichment <- do.call(rbind, enrichment_list)
enrichment$padj <- p.adjust(enrichment$pvalue, method = "BH")
enrichment <- enrichment[order(enrichment$padj, enrichment$pvalue), ]

write.csv(
  enrichment,
  file.path(results_dir, "enrichment_results.csv"),
  row.names = FALSE
)

plot_data <- enrichment[enrichment$overlap_count > 0, ]

if (nrow(plot_data) > 0) {
  plot_data$minus_log10_padj <- -log10(pmax(plot_data$padj, 1e-300))
  plot_data$gene_set <- factor(
    plot_data$gene_set,
    levels = rev(plot_data$gene_set)
  )

  enrichment_plot <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(x = gene_set, y = minus_log10_padj, fill = overlap_count)
  ) +
    ggplot2::geom_col() +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = "Teaching example: gene-set enrichment",
      x = "Simulated gene set",
      y = "-log10 adjusted p-value",
      fill = "DEG overlap"
    ) +
    ggplot2::theme_bw(base_size = 12)

  ggplot2::ggsave(
    file.path(figures_dir, "enrichment_barplot.png"),
    enrichment_plot,
    width = 7,
    height = 5,
    dpi = 300
  )
}

cat("Enrichment demo finished.\n")
cat("Important: gene sets are simulated and results are not biological claims.\n")

