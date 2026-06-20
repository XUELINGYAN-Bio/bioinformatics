#!/usr/bin/env Rscript

# 这个脚本只检查环境，不会安装或修改任何软件。

cat("R version:", R.version.string, "\n\n")

required_packages <- c("DESeq2", "ggplot2", "pheatmap")

for (package_name in required_packages) {
  installed <- requireNamespace(package_name, quietly = TRUE)
  status <- if (installed) "OK" else "MISSING"
  cat(sprintf("%-10s %s\n", package_name, status))
}

cat("\n如果出现 MISSING，请运行：\n")
cat("Rscript setup/install_r_packages.R\n")

