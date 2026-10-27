#!/bin/bash
# 节点 10/10：ADS 导出到 MySQL（文本中转 + LOAD DATA）
# 链路：Hive 表 -> HDFS 文本目录 -> getmerge -> MySQL LOAD DATA
set -e
source "$(dirname "$0")/00_env.sh"

TABLES="ads_dau_1d ads_funnel_1d ads_retention_1d ads_hour_active_1d ads_item_topn_1d \
ads_category_topn_1d ads_buy_freq_dist_1d ads_user_rf_seg_1d ads_path_analysis_1d ads_item_skew_1d"

MYSQL="mysql --local-infile=1 -uroot -p000000"

echo "[$(date '+%F %T')] 1) Hive -> HDFS 文本"
run_sql "$SQL_DIR/10_export.sql"

echo "[$(date '+%F %T')] 2) MySQL 建库建表"
$MYSQL -e "SET GLOBAL local_infile = 1;" 2>/dev/null || echo "(local_infile 已是 ON)"
$MYSQL < "$SQL_DIR/mysql_ddl.sql" 2>/dev/null

echo "[$(date '+%F %T')] 3) 逐表导出"
for t in $TABLES; do
  hdfs dfs -getmerge "/warehouse/tb_dw/export/$t" "/tmp/export_$t.tsv" 2>/dev/null
  rows=$(wc -l < "/tmp/export_$t.tsv")
  $MYSQL -e "TRUNCATE TABLE tb_dw_report.$t;" 2>/dev/null
  if [ "$rows" -gt 0 ]; then
    $MYSQL -e "LOAD DATA LOCAL INFILE '/tmp/export_$t.tsv' INTO TABLE tb_dw_report.$t FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';" 2>/dev/null
  fi
  cnt=$($MYSQL -N -e "SELECT count(*) FROM tb_dw_report.$t;" 2>/dev/null)
  echo "  $t -> 文件 $rows 行 / MySQL $cnt 行"
done
echo "[$(date '+%F %T')] 导出完成"
