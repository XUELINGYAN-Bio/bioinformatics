#!/usr/bin/env Rscript

# ----------------------------
# 0. Locate project directories
# ----------------------------
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

# ----------------------------
# 1. Check required R packages
# ----------------------------
required_packages <- c("DESeq2", "ggplot2", "pheatmap")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Missing R packages: ",
    paste(missing_packages, collapse = ", "),
    "\nRun: Rscript setup/install_r_packages.R from the repository root."
  )
}

suppressPackageStartupMessages({
  library(DESeq2)
  library(ggplot2)
  library(pheatmap)
})

# ----------------------------
# 2. Read and validate input data
# ----------------------------
counts <- read.csv(
  file.path(data_dir, "counts.csv"),
  row.names = 1,
  check.names = FALSE
)

metadata <- read.csv(
  file.path(data_dir, "metadata.csv"),
  stringsAsFactors = FALSE
)

if (anyDuplicated(rownames(counts))) {
  stop("Duplicated gene IDs were found in counts.csv.")
}

if (any(counts < 0) || any(counts %% 1 != 0)) {
  stop("All count values must be non-negative integers.")
}

if (!all(colnames(counts) %in% metadata$sample)) {
  stop("Some count-matrix sample names are missing from metadata.csv.")
}

# Reorder metadata so its rows exactly match the count-matrix columns.
metadata <- metadata[match(colnames(counts), metadata$sample), ]
rownames(metadata) <- metadata$sample

if (!identical(colnames(counts), rownames(metadata))) {
  stop("The count matrix and metadata could not be aligned.")
}

metadata$condition <- factor(
  metadata$condition,
  levels = c("control", "stress")
)

if (any(is.na(metadata$condition))) {
  stop("Condition must contain only 'control' and 'stress'.")
}

# ----------------------------
# 3. Create and filter the DESeq2 object
# ----------------------------
dds <- DESeqDataSetFromMatrix(
  countData = round(as.matrix(counts)),
  colData = metadata,
  design = ~ condition
)

# Very low-count genes carry little information in this small demonstration.
keep <- rowSums(counts(dds)) >= 10
dds <- dds[keep, ]

cat("Genes before filtering:", nrow(counts), "\n")
cat("Genes after filtering:", nrow(dds), "\n")

# ----------------------------
# 4. Fit the model and extract results
# ----------------------------
dds <- DESeq(dds, quiet = TRUE)

res <- results(
  dds,
  contrast = c("condition", "stress", "control"),
  alpha = 0.05
)

res_df <- as.data.frame(res)
res_df$gene_id <- rownames(res_df)
res_df <- res_df[
  order(res_df$padj, -abs(res_df$log2FoldChange), na.last = TRUE),
]

res_df$status <- "Not_significant"
res_df$status[
  !is.na(res_df$padj) &
    res_df$padj < 0.05 &
    res_df$log2FoldChange >= 1
] <- "Up"
res_df$status[
  !is.na(res_df$padj) &
    res_df$padj < 0.05 &
    res_df$log2FoldChange <= -1
] <- "Down"

deg_df <- res_df[res_df$status %in% c("Up", "Down"), ]

write.csv(
  res_df,
  file.path(results_dir, "all_deseq2_results.csv"),
  row.names = FALSE
)

write.csv(
  deg_df,
  file.path(results_dir, "deg_results.csv"),
  row.names = FALSE
)

normalized_counts <- counts(dds, normalized = TRUE)
write.csv(
  data.frame(gene_id = rownames(normalized_counts), normalized_counts),
  file.path(results_dir, "normalized_counts.csv"),
  row.names = FALSE
)

# ----------------------------
# 5. PCA plot
# ----------------------------
vsd <- varianceStabilizingTransformation(dds, blind = TRUE)
pca_model <- prcomp(t(assay(vsd)))

percent_variance <- 100 * (pca_model$sdev^2 / sum(pca_model$sdev^2))
pca_df <- data.frame(
  sample = rownames(pca_model$x),
  PC1 = pca_model$x[, 1],
  PC2 = pca_model$x[, 2],
  condition = metadata[rownames(pca_model$x), "condition"]
)

pca_plot <- ggplot(
  pca_df,
  aes(x = PC1, y = PC2, color = condition, label = sample)
) +
  geom_point(size = 4) +
  geom_text(vjust = -0.8, show.legend = FALSE) +
  labs(
    title = "PCA of variance-stabilized counts",
    x = sprintf("PC1 (%.1f%%)", percent_variance[1]),
    y = sprintf("PC2 (%.1f%%)", percent_variance[2])
  ) +
  theme_bw(base_size = 12)

ggsave(
  file.path(figures_dir, "pca.png"),
  pca_plot,
  width = 7,
  height = 5,
  dpi = 300
)

# ----------------------------
# 6. Volcano plot
# ----------------------------
volcano_df <- res_df
volcano_df$minus_log10_padj <- -log10(pmax(volcano_df$padj, 1e-300))

volcano_plot <- ggplot(
  volcano_df,
  aes(x = log2FoldChange, y = minus_log10_padj, color = status)
) +
  geom_point(alpha = 0.8, size = 2.2, na.rm = TRUE) +
  geom_vline(xintercept = c(-1, 1), linetype = "dashed", color = "grey50") +
  geom_hline(
    yintercept = -log10(0.05),
    linetype = "dashed",
    color = "grey50"
  ) +
  scale_color_manual(
    values = c(
      "Down" = "#377EB8",
      "Not_significant" = "grey70",
      "Up" = "#E41A1C"
    )
  ) +
  labs(
    title = "DESeq2 differential expression",
    x = "log2 fold change: stress / control",
    y = "-log10 adjusted p-value",
    color = "Status"
  ) +
  theme_bw(base_size = 12)

ggsave(
  file.path(figures_dir, "volcano_plot.png"),
  volcano_plot,
  width = 7,
  height = 5,
  dpi = 300
)

# ----------------------------
# 7. Heatmap of top genes
# ----------------------------
ordered_genes <- res_df$gene_id[!is.na(res_df$padj)]
top_genes <- head(ordered_genes, 20)

if (length(top_genes) >= 2) {
  heatmap_matrix <- assay(vsd)[top_genes, , drop = FALSE]
  heatmap_matrix <- t(scale(t(heatmap_matrix)))

  annotation_col <- data.frame(condition = metadata$condition)
  rownames(annotation_col) <- rownames(metadata)

  png(
    file.path(figures_dir, "top_genes_heatmap.png"),
    width = 1800,
    height = 1500,
    res = 220
  )
  pheatmap(
    heatmap_matrix,
    annotation_col = annotation_col,
    main = "Top genes by adjusted p-value",
    border_color = NA,
    fontsize_row = 9
  )
  dev.off()
}

# ----------------------------
# 8. Save software versions
# ----------------------------
capture.output(
  sessionInfo(),
  file = file.path(results_dir, "session_info.txt")
)

cat("Significant up-regulated genes:", sum(deg_df$status == "Up"), "\n")
cat("Significant down-regulated genes:", sum(deg_df$status == "Down"), "\n")
cat("Analysis finished. See results/ and figures/.\n")

