#!/bin/bash
# 节点 2/10：日期维初始化（静态，可重跑）
set -e
source "$(dirname "$0")/00_env.sh"
run_sql "$SQL_DIR/02_dim_date.sql"
