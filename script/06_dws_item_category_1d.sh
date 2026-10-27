#!/bin/bash
# 节点 6/10：商品/类目日粒度 DWS
set -e
source "$(dirname "$0")/00_env.sh"
DO_DATE=${1:?请传入日期，如 2017-11-25}
run_sql_date "$SQL_DIR/05_dws_item_category.sql" "$DO_DATE"
