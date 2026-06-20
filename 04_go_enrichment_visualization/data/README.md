# Input data

将 GO 富集结果放在此目录时，推荐命名为：

```text
go_enrich_stat.xls
```

本项目没有复制原始分析文件，避免在未确认数据共享范围时直接上传实验结果。

脚本也可以直接读取任意绝对路径：

```bash
Rscript scripts/01_plot_go_bubble.R "/absolute/path/go_enrich_stat.xls"
```

如果准备上传 GitHub，请先确认原始数据和结果表是否允许公开。

