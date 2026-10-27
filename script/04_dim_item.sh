#!/bin/bash
# 节点 4/10：商品维表（全量刷新，需 DWD 已完成）
# 设计说明：商品维是「全量重算型」静态维（要跨全部历史算主类目与累计行为），
#   每次调度都重算代价大且会与其他节点争内存，因此加缓存标记：
#   首次或商品属性变化时刷新，日常调度命中标记直接跳过。
#   强制刷新：hdfs dfs -rm /warehouse/tb_dw/dim/dim_item/_REFRESHED
set -e
source "$(dirname "$0")/00_env.sh"

MARK=/warehouse/tb_dw/dim/dim_item/_REFRESHED

if [ "${FORCE_DIM_ITEM}" != "1" ] && hdfs dfs -test -e "$MARK"; then
  echo "[$(date '+%F %T')] 商品维已有标记，跳过全量刷新"
  echo "强制刷新：FORCE_DIM_ITEM=1 bash 04_dim_item.sh  或 hdfs dfs -rm $MARK"
  exit 0
fi

run_sql "$SQL_DIR/07_dim_item.sql"
hdfs dfs -touchz "$MARK"
echo "[$(date '+%F %T')] 商品维刷新完成并写入标记 $MARK"
