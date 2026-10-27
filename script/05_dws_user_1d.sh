#!/bin/bash
# 节点 5/10：用户日粒度 DWS
set -e
source "$(dirname "$0")/00_env.sh"
DO_DATE=${1:?请传入日期，如 2017-11-25}
run_sql_date "$SQL_DIR/04_dws_user.sql" "$DO_DATE"
