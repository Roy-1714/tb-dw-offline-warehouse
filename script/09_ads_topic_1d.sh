#!/bin/bash
# 节点 9/10：ADS 主题指标（TopN/频次/RF/路径/倾斜）
set -e
source "$(dirname "$0")/00_env.sh"
DO_DATE=${1:?请传入日期，如 2017-11-25}
run_sql_date "$SQL_DIR/09_ads_topic.sql" "$DO_DATE"
