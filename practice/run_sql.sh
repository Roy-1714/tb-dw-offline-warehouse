#!/bin/bash
# ============================================================
# practice/run_sql.sh  在 tb_dw 上执行任意 SQL 文件（只读练习用）
# 用法：bash practice/run_sql.sh practice/q1.sql
# ============================================================
set -e
SRC_DIR=$(cd "$(dirname "$0")/../script" && pwd)
source "$SRC_DIR/00_env.sh"

if [ -z "$1" ]; then
  echo "用法: bash practice/run_sql.sh <sql文件>"
  exit 1
fi

run_sql "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
