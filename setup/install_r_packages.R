#!/usr/bin/env Rscript

# CRAN 包使用 install.packages() 安装。
cran_packages <- c("ggplot2", "pheatmap")
missing_cran <- cran_packages[
  !vapply(cran_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_cran) > 0) {
  install.packages(missing_cran, repos = "https://cloud.r-project.org")
}

# DESeq2 属于 Bioconductor，因此通过 BiocManager 安装。
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}

if (!requireNamespace("DESeq2", quietly = TRUE)) {
  BiocManager::install("DESeq2", ask = FALSE, update = FALSE)
}

cat("R package setup finished.\n")

