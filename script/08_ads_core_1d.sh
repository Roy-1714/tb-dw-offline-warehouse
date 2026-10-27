#!/bin/bash
# 节点 8/10：ADS 核心指标（DAU/漏斗/留存/分时）
set -e
source "$(dirname "$0")/00_env.sh"
DO_DATE=${1:?请传入日期，如 2017-11-25}
run_sql_date "$SQL_DIR/08_ads_core.sql" "$DO_DATE"
