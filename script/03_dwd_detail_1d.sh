#!/bin/bash
# 节点 3/10：DWD 明细清洗（按天增量）
# 用法：03_dwd_detail_1d.sh 2017-11-25
set -e
source "$(dirname "$0")/00_env.sh"
DO_DATE=${1:?请传入日期，如 2017-11-25}
run_sql_date "$SQL_DIR/03_dwd.sql" "$DO_DATE"
