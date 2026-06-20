# 04 GO Enrichment Visualization

## 项目目的

本项目使用 R 读取 GO 富集分析结果，筛选显著条目，并绘制适合报告、论文初稿和 GitHub 展示的 GO 气泡图。

图中编码关系为：

| 图形元素 | 数据字段 | 含义 |
|---|---|---|
| 横轴 | `enrich_factor` | Rich factor，即该 GO 条目中差异基因所占比例 |
| 纵轴 | `discription` + `go_id` | GO 条目名称和编号 |
| 点大小 | `study_count` | 富集到该条目的差异基因数 |
| 点颜色 | `-log10(p_corrected)` | 校正后显著性，值越大越显著 |
| 分面 | `go_type` | BP、CC 和 MF 三类 GO ontology |

## 输入文件的真实格式

原始文件名是 `go_enrich_stat.xls`，但它并不是真正的 Excel 二进制工作簿，而是以制表符分隔的纯文本文件。

因此使用：

```r
read.delim(..., sep = "\t")
```

而不是：

```r
readxl::read_excel(...)
```

仅凭文件扩展名选择读取函数容易报错。正式分析前应先检查文件真实格式和列名。

## 使用工具

- R
- ggplot2：绘图
- dplyr：筛选、排序和分组
- stringr：长 GO 名称自动换行
- scales：坐标轴格式

## 目录结构

```text
04_go_enrichment_visualization/
├── README.md
├── data/
│   └── README.md
├── scripts/
│   └── 01_plot_go_bubble.R
├── results/
│   └── top_go_terms.csv
└── figures/
    ├── go_bubble_plot.pdf
    └── go_bubble_plot.png
```

## 运行方法

进入项目目录：

```bash
cd bioinformatics-portfolio/04_go_enrichment_visualization
```

运行脚本，并将输入文件路径放在命令最后：

```bash
Rscript scripts/01_plot_go_bubble.R \
  "/path/to/go_enrich_stat.xls"
```

解释：

- `Rscript`：从终端运行 R 脚本。
- `scripts/01_plot_go_bubble.R`：绘图脚本。
- 最后一部分：要读取的 GO 富集结果文件。
- 路径放在双引号中，可以正确处理中文、空格和括号。

也可以指定每个 GO 分类展示多少个条目：

```bash
Rscript scripts/01_plot_go_bubble.R "输入文件路径" 8
```

这里的 `8` 表示 BP、CC、MF 每类最多展示 8 个条目。默认值为 10。

## 代码逐步解释

### 1. 定位项目目录

```r
command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)
script_path <- normalizePath(sub("^--file=", "", file_argument))
project_dir <- normalizePath(file.path(dirname(script_path), ".."))
```

作用：

- 找到当前 R 脚本所在位置。
- 根据脚本位置推导项目目录。
- 这样无论从哪个目录运行，结果都会写入本项目的 `results/` 和 `figures/`。

### 2. 读取命令行参数

```r
args <- commandArgs(trailingOnly = TRUE)
input_file <- normalizePath(args[1], mustWork = TRUE)
top_n <- if (length(args) >= 2) as.integer(args[2]) else 10L
```

作用：

- `args[1]` 是输入文件路径。
- `args[2]` 是可选的每类展示数量。
- 如果不提供第二个参数，就使用默认值 10。

### 3. 检查所需 R 包

```r
required_packages <- c("ggplot2", "dplyr", "stringr", "scales")
```

脚本会逐个检查软件包。缺少软件包时会停止，并给出安装命令，而不是运行到中途才出现难以理解的报错。

### 4. 读取制表符文本

```r
go_raw <- read.delim(
  input_file,
  header = TRUE,
  sep = "\t",
  quote = "",
  comment.char = "",
  check.names = FALSE,
  stringsAsFactors = FALSE
)
```

重要参数：

- `header = TRUE`：第一行是列名。
- `sep = "\t"`：列之间使用制表符分隔。
- `quote = ""`：不把引号视为特殊包裹字符。
- `comment.char = ""`：不把任何字符后的内容当作注释丢弃。
- `check.names = FALSE`：保留原始列名。
- `stringsAsFactors = FALSE`：文本保持为字符型。

### 5. 检查必需字段

```r
required_columns <- c(
  "go_id", "go_type", "discription",
  "p_corrected", "enrich_factor", "study_count"
)
```

这些列分别提供 GO 编号、GO 分类、名称、FDR、Rich factor 和差异基因数。若缺少任何一列，脚本会明确指出。

原文件使用了拼写 `discription`，虽然标准英文应为 `description`，脚本仍按原始列名读取。

### 6. 清洗数据

```r
go_clean <- go_raw |>
  dplyr::mutate(
    go_type = toupper(trimws(go_type)),
    p_corrected = as.numeric(p_corrected),
    enrich_factor = as.numeric(enrich_factor),
    study_count = as.numeric(study_count)
  ) |>
  dplyr::filter(
    go_type %in% c("BP", "CC", "MF"),
    is.finite(p_corrected),
    p_corrected > 0,
    p_corrected <= 1,
    is.finite(enrich_factor),
    enrich_factor >= 0,
    is.finite(study_count),
    study_count > 0
  )
```

作用：

- 统一 BP、CC、MF 的大小写。
- 把统计字段转换为数值。
- 删除缺失、无限或不符合范围的记录。
- `p_corrected > 0` 是因为后续要计算 `-log10(FDR)`，而 `log10(0)` 没有有限值。

### 7. 筛选显著条目并选择 Top 10

```r
go_selected <- go_clean |>
  dplyr::filter(p_corrected < 0.05) |>
  dplyr::group_by(go_type) |>
  dplyr::arrange(
    p_corrected,
    dplyr::desc(enrich_factor),
    dplyr::desc(study_count),
    .by_group = TRUE
  ) |>
  dplyr::slice_head(n = top_n) |>
  dplyr::ungroup()
```

筛选逻辑：

1. 只保留 FDR 小于 0.05 的条目。
2. BP、CC、MF 分别排序。
3. 优先选择 FDR 更小的条目。
4. FDR 相同时，优先 Rich factor 更高的条目。
5. 仍相同时，优先差异基因数更多的条目。

每类单独选择，避免 BP 条目数量较多而完全遮盖 CC 或 MF。

### 8. 计算颜色变量

```r
neg_log10_fdr = -log10(p_corrected)
```

FDR 越小，`-log10(FDR)` 越大。例如：

- FDR = 0.05，`-log10(FDR)` 约为 1.30。
- FDR = 0.001，`-log10(FDR)` 为 3。
- 因此颜色越深表示统计显著性越强。

### 9. 设置纵轴顺序

脚本先把长名称换行，再将条目设为有顺序的因子。这样每个分面中 Rich factor 较高的条目会显示在较上方，而不是按字母顺序排列。

### 10. 绘制气泡图

核心映射：

```r
ggplot2::ggplot(
  go_selected,
  ggplot2::aes(
    x = enrich_factor,
    y = term_panel,
    size = study_count,
    fill = neg_log10_fdr
  )
)
```

随后使用：

```r
ggplot2::geom_point(shape = 21)
```

`shape = 21` 支持独立设置点的填充色和边框色，可在浅色与深色区域中保持清晰轮廓。

### 11. 使用分面显示 BP、CC 和 MF

```r
ggplot2::facet_wrap(
  ggplot2::vars(go_type_label),
  ncol = 1,
  scales = "free_y",
  strip.position = "top"
)
```

- 每类 GO 使用一个独立面板。
- `free_y` 允许每个面板只显示自己的 GO 条目。
- `ncol = 1` 将三个分类纵向排列。
- 分类标题放在各面板上方，避免右侧分面条占用过多绘图宽度。

### 12. 导出结果

```r
ggplot2::ggsave(..., dpi = 600, bg = "white")
```

输出：

- PNG：600 dpi，适合报告、Word 和 GitHub 预览。
- PDF：矢量格式，适合后续排版和无损缩放。
- CSV：保存实际进入图片的 GO 条目，方便复核。

## 如何解释结果

- 越靠右：该 GO 条目的 Rich factor 越高。
- 点越大：富集到该条目的差异基因越多。
- 颜色越深：FDR 越小，统计显著性越强。
- BP、CC、MF 应分别解读，不能只根据点大小判断“最重要”。

图中同时使用了显著性、Rich factor 和基因数。三者代表不同信息：

- 显著性受背景基因数、条目大小和差异基因数共同影响。
- Rich factor 高不一定代表涉及的基因很多。
- 点很大不一定代表富集比例高。

## 结果边界

- GO 富集反映差异基因在注释条目中的统计过度代表，不直接证明因果关系。
- 相近 GO 条目常共享大量基因，因此图中多项结果可能不是独立生物学过程。
- 需要结合上调/下调方向、基因列表、实验设计和文献进行解释。
- 当前输入目录名中的 `G` 具体代表什么，应根据原分析分组说明确认后再写入论文图注。
