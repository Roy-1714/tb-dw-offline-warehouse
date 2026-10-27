#!/bin/bash
# ============================================================
# 节点 1/10：ODS 装载
# 原始 CSV -> HDFS 原始区 -> ODS 分区表（按北京时日、越界进 invalid）
# 用法：01_ods_load.sh
# 幂等：装载成功后写 _LOADED 标记；已标记则跳过（删标记可强制重装）
# ============================================================
set -e
source "$(dirname "$0")/00_env.sh"

RAW_LOCAL=/home/atguigu/data/raw/UserBehavior.csv
RAW_HDFS=/origin_data/tb_dw/UserBehavior
MARK=/warehouse/tb_dw/ods/ods_user_behavior/_LOADED

echo "[$(date '+%F %T')] 1) 原始文件入 HDFS"
hdfs dfs -mkdir -p "$RAW_HDFS"
if hdfs dfs -test -e "$RAW_HDFS/UserBehavior.csv"; then
  echo "已存在，跳过上传"
else
  hdfs dfs -put "$RAW_LOCAL" "$RAW_HDFS/"
fi
hdfs dfs -ls -h "$RAW_HDFS"

if hdfs dfs -test -e "$MARK"; then
  echo "[$(date '+%F %T')] ODS 已装载过（存在 $MARK），跳过装载"
  echo "如需强制重装：hdfs dfs -rm $MARK"
  exit 0
fi

echo "[$(date '+%F %T')] 2) 建库"
run_sql "$SQL_DIR/00_init.sql"

echo "[$(date '+%F %T')] 3) 建表并装载 ODS"
run_sql "$SQL_DIR/01_ods.sql"

hdfs dfs -touchz "$MARK"
echo "[$(date '+%F %T')] 已写入装载标记 $MARK"
