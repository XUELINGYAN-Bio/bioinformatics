#!/usr/bin/env bash

# 遇到错误立即停止；未定义变量也视为错误；管道中任一命令失败即停止。
set -euo pipefail

# 无论从哪个目录调用脚本，都先确定项目根目录。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
INPUT_FILE="${PROJECT_DIR}/data/gene_expression.tsv"
RESULTS_DIR="${PROJECT_DIR}/results"

mkdir -p "${RESULTS_DIR}"

echo "1. Preview the first five lines"
head -n 5 "${INPUT_FILE}"

echo
echo "2. Count all lines, including the header"
wc -l "${INPUT_FILE}"

echo
echo "3. Select gene_id and expression columns"
cut -f 1,4 "${INPUT_FILE}"

echo
echo "4. Keep the header and expression values >= 50"
awk -F '\t' 'BEGIN {OFS="\t"} NR == 1 || $4 >= 50' \
  "${INPUT_FILE}" > "${RESULTS_DIR}/high_expression.tsv"

echo
echo "5. Sort records by expression from high to low"
{
  head -n 1 "${INPUT_FILE}"
  tail -n +2 "${INPUT_FILE}" | sort -t $'\t' -k4,4nr
} > "${RESULTS_DIR}/sorted_expression.tsv"

echo
echo "6. Count records on each chromosome"
{
  printf "chromosome\trecord_count\n"
  tail -n +2 "${INPUT_FILE}" |
    cut -f 2 |
    sort |
    uniq -c |
    awk 'BEGIN {OFS="\t"} {print $2, $1}'
} > "${RESULTS_DIR}/chromosome_counts.tsv"

echo
echo "7. Write a short summary"
awk -F '\t' '
  NR == 1 {next}
  {
    count += 1
    total += $4
    if (count == 1 || $4 > maximum) {
      maximum = $4
      maximum_gene = $1
    }
  }
  END {
    printf "Number of records: %d\n", count
    printf "Mean expression: %.2f\n", total / count
    printf "Highest-expression gene: %s (%.0f)\n", maximum_gene, maximum
  }
' "${INPUT_FILE}" > "${RESULTS_DIR}/summary.txt"

echo
echo "Finished. Results were written to: ${RESULTS_DIR}"

