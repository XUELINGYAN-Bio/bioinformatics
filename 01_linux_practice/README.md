# 01 Linux Practice

## 项目目的

这个项目使用一个很小的基因表达表练习 Linux 中常见的文本处理操作：

- 查看文件
- 统计行数
- 选择列
- 按条件筛选
- 排序
- 按类别计数
- 把多条命令整理成可重复运行的 Shell 脚本

这些操作适用于查看表达矩阵、样本信息表和注释文件。

## 使用工具

- Bash：运行一组 Linux 命令
- `head`：查看文件前几行
- `wc`：统计行数
- `cut`：选择列
- `awk`：按条件处理表格
- `sort`：排序
- `uniq`：去重或计数

## 输入数据

`data/gene_expression.tsv` 是教学用小型模拟数据。

TSV 表示“tab-separated values”，即每一列使用制表符分隔。文件包含：

| 列名 | 含义 |
|---|---|
| gene_id | 模拟基因编号 |
| chromosome | 模拟染色体 |
| condition | control 或 stress |
| expression | 模拟表达量 |

## 分析流程

先进入项目目录：

```bash
cd 01_linux_practice
```

运行完整脚本：

```bash
bash scripts/01_text_processing.sh
```

这里：

- `bash` 表示使用 Bash 解释器。
- `scripts/01_text_processing.sh` 是要运行的脚本路径。

脚本中的主要步骤如下。

### 1. 查看文件前五行

```bash
head -n 5 data/gene_expression.tsv
```

`-n 5` 表示显示五行。

### 2. 统计文件总行数

```bash
wc -l data/gene_expression.tsv
```

结果包含一行表头，因此真实数据行数需要减一。

### 3. 提取基因编号和表达量

```bash
cut -f 1,4 data/gene_expression.tsv
```

`-f 1,4` 表示选择第 1 列和第 4 列。

### 4. 筛选高表达基因

```bash
awk -F '\t' 'NR == 1 || $4 >= 50' data/gene_expression.tsv
```

解释：

- `-F '\t'`：指定输入文件以制表符分列。
- `NR == 1`：保留第一行表头。
- `$4 >= 50`：保留第 4 列大于或等于 50 的行。
- `||`：表示“或者”。

### 5. 按表达量从高到低排序

```bash
{ head -n 1 data/gene_expression.tsv; tail -n +2 data/gene_expression.tsv | sort -t $'\t' -k4,4nr; }
```

解释：

- `head -n 1`：先保留表头。
- `tail -n +2`：从第二行开始读取数据。
- `-t $'\t'`：指定制表符为分隔符。
- `-k4,4nr`：按照第 4 列进行数字反向排序。

## 预期结果

脚本运行后生成：

```text
results/
├── chromosome_counts.tsv
├── high_expression.tsv
├── sorted_expression.tsv
└── summary.txt
```

其中：

- `high_expression.tsv`：表达量不低于 50 的记录。
- `sorted_expression.tsv`：按表达量从高到低排列。
- `chromosome_counts.tsv`：每条染色体包含多少条记录。
- `summary.txt`：数据行数、平均表达量和最高表达基因。

## 我学到了什么

- 理解 Linux 命令通常采用“命令 + 参数 + 输入文件”的结构。
- 可以使用管道符 `|` 把前一个命令的输出交给下一个命令。
- `awk` 适合处理规则清晰的表格数据。
- 写成 Shell 脚本后，相同分析可以重复运行，减少手工操作错误。
- 生物信息分析不仅要得到结果，还要保留生成结果的命令。

## 可继续练习

1. 把高表达阈值从 50 改为 80。
2. 只筛选 `stress` 条件。
3. 计算 control 和 stress 两组的平均表达量。
4. 为脚本增加一个由用户输入的阈值参数。

