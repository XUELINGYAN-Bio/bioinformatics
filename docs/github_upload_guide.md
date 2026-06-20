# GitHub 上传指南

## 1. 在 GitHub 新建空仓库

在 GitHub 网页中新建仓库：

- Repository name：`bioinformatics-portfolio`
- Visibility：建议先选择 Public
- 不要再次添加 README、`.gitignore` 或 License，因为本地已经存在

## 2. 在本地初始化 Git

先进入本项目目录：

```bash
cd bioinformatics-portfolio
```

初始化 Git 仓库：

```bash
git init
```

解释：

- `git` 是版本管理工具。
- `init` 表示把当前目录初始化为一个 Git 仓库。

检查将要提交的文件：

```bash
git status
```

加入全部项目文件：

```bash
git add .
```

创建第一次提交：

```bash
git commit -m "Initial bioinformatics portfolio"
```

## 3. 连接 GitHub 仓库

把下面的 `YOUR_USERNAME` 替换成自己的 GitHub 用户名：

```bash
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/bioinformatics-portfolio.git
git push -u origin main
```

解释：

- `git branch -M main`：把当前主分支命名为 `main`。
- `git remote add origin ...`：把本地仓库连接到 GitHub 地址。
- `git push -u origin main`：第一次上传，并记录默认远程分支。

## 4. 后续更新

修改项目后依次运行：

```bash
git status
git add .
git commit -m "Describe the update"
git push
```

提交信息应说明做了什么，例如：

```bash
git commit -m "Add DESeq2 volcano plot"
git commit -m "Update NAC20 literature notes"
```

## 上传前检查

- README 中没有夸大项目结论
- 没有上传 FASTQ、BAM 等大文件
- 没有上传密码、token、私人邮箱等敏感信息
- 所有脚本至少完整运行过一次
- 图片和结果表可以在 GitHub 中直接查看

