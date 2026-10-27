#!/bin/bash
# 00_full_rebuild.sh  清派生层 -> 9 天全链路 -> 导出（ODS 保持不动）
set -e
source "$(dirname "$0")/00_env.sh"
S=$(dirname "$0")
LOG=$LOG_DIR/full_$(date +%H%M).log
echo "日志: $LOG"

echo "########## 0. 清空派生层（保留 ODS 与原始数据）##########"
spark-sql --master yarn --name tb_dw_reset \
  --conf spark.yarn.archive=$SPARK_YARN_ARCHIVE \
  --conf spark.hadoop.hive.metastore.uris=$HIVE_METASTORE_URI \
  --conf spark.sql.warehouse.dir=/warehouse/tb_dw \
  --conf spark.executor.instances=1 --conf spark.executor.memory=1g --conf spark.driver.memory=1g \
  -f "$SQL_DIR/00_reset.sql" >> "$LOG" 2>&1

echo "########## 1-10. 全链路 ##########"
SKIP_ODS=1 bash "$S/00_backfill.sh" >> "$LOG" 2>&1
echo "完成: $LOG"
