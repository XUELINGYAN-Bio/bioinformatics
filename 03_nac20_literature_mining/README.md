# 03 NAC20 Literature Mining

## 项目目的

这个项目演示如何围绕植物 NAC20 相关关键词完成一个可复现的小型文献整理流程：

1. 保存并解释检索式。
2. 通过 NCBI Entrez API 获取少量 PubMed 元数据。
3. 整理 PMID、题目、年份、期刊、作者、DOI 和摘要。
4. 统计发文年份与常见研究关键词。
5. 生成文献阅读笔记模板，供后续人工精读。

这里的“文献挖掘”主要是元数据整理和初步筛选，不能代替对论文全文的认真阅读。

## 为什么保存检索式

只在网页中搜索但不记录关键词，会导致以后无法准确复现。项目将检索式保存在：

```text
data/search_query.txt
```

当前检索式围绕：

- `NAC20`
- `ANAC020`
- `OsNAC20`
- `TaNAC20`

检索字段限定为 PubMed 的标题或摘要。不同物种可能采用不同基因命名方式，因此检索后仍需要人工判断文章是否真正相关。

## 使用工具

- Python 3 标准库：请求和解析 NCBI Entrez 数据
- PubMed / NCBI Entrez E-utilities：公开文献元数据来源
- R：整理结果并统计关键词
- ggplot2：绘制年份和关键词图

下载脚本不需要安装额外 Python 包。

## 数据来源与边界

- 来源：NCBI PubMed
- 默认最多下载 20 条记录
- 只保存公开元数据，不下载论文全文
- `data/pubmed_records.csv` 可以重新生成
- 数据库记录会更新，因此不同日期运行结果可能略有变化

## 分析流程

### 第一步：进入项目目录

```bash
cd 03_nac20_literature_mining
```

### 第二步：查看检索式

```bash
cat data/search_query.txt
```

`cat` 会把文本文件内容显示在终端中。

### 第三步：从 PubMed 获取小型元数据表

```bash
python3 scripts/01_fetch_pubmed.py
```

这条命令会：

1. 读取 `data/search_query.txt`。
2. 调用 PubMed `esearch` 获取文献编号。
3. 调用 PubMed `efetch` 获取文献元数据。
4. 写出 `data/pubmed_records.csv`。

默认最多获取 20 条。若只想获取 10 条：

```bash
python3 scripts/01_fetch_pubmed.py --retmax 10
```

如果希望按 NCBI 建议提供联系邮箱：

```bash
python3 scripts/01_fetch_pubmed.py --email your_email@example.com
```

邮箱只作为本次 API 请求参数，不会被写入结果表。上传 GitHub 前不要把私人邮箱硬编码到脚本。

### 第四步：运行关键词和年份统计

```bash
Rscript scripts/02_text_mining.R data/pubmed_records.csv
```

脚本会把标题和摘要合并为一个文本字段，然后统计每个关键词出现在多少篇文献中。

这里统计的是“包含关键词的文章数”，不是词语出现的总次数。

### 第五步：生成阅读笔记表

```bash
Rscript scripts/03_make_notes_template.R data/pubmed_records.csv
```

生成的 `results/literature_notes_template.csv` 包含：

- 文献基本信息
- 研究问题
- 物种
- 实验或分析方法
- 主要结论
- 局限性
- 与 NAC20 主题的关系
- 阅读状态

后面的解释列需要阅读题目、摘要和全文后人工填写。脚本不会自动编造论文结论。

## 预期结果

```text
data/
├── pubmed_records.csv
└── search_query.txt

results/
├── keyword_counts.csv
├── literature_notes_template.csv
└── publication_year_counts.csv

figures/
├── keyword_counts.png
└── publication_years.png
```

结果可以回答：

- 当前检索式找到多少篇 PubMed 记录？
- 记录主要集中在哪些年份？
- rice、wheat、stress、drought 等关键词分别出现于多少篇记录？
- 哪些文章应优先人工精读？

这些统计只描述检索结果，不能直接证明 NAC20 的功能。

## 如何进行人工文献整理

建议每篇文献至少记录：

1. 研究对象是什么物种和材料？
2. NAC20 是目标基因、相关基因，还是只在背景中被提及？
3. 使用了哪些实验或组学方法？
4. 主要证据支持什么结论？
5. 是否存在过表达、敲除、互补或表型验证？
6. 结论有哪些边界和不足？
7. 这篇文献如何帮助设计后续生信项目？

## 我学到了什么

- 文献检索式本身也是可复现研究流程的一部分。
- 同一个基因家族在不同物种中可能有不同命名。
- API 能把重复的复制粘贴过程转换为结构化数据处理。
- 标题和摘要关键词只能用于初筛，不能替代人工判断。
- 文献表中应区分“论文原文信息”和“自己的解释”。
- 可靠的文献综述需要记录数据来源、检索日期、筛选标准和排除原因。

## 下一步

- 增加同义词和不同物种的基因名称。
- 记录检索日期和纳入/排除标准。
- 对每篇入选论文填写阅读笔记。
- 将文献结果与真实 RNA-seq DEG 或富集结果联系起来。
- 在形成生物学结论前，核对全文、补充材料和原始数据。

