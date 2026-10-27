#!/bin/bash
# 节点 7/10：滚动 7 日 + 历史累计（快照增量合并）
# 注意：必须按日期顺序逐日执行，td 依赖前一日快照
set -e
source "$(dirname "$0")/00_env.sh"
DO_DATE=${1:?请传入日期，如 2017-11-25}
run_sql_date "$SQL_DIR/06_dws_nd_td.sql" "$DO_DATE"
