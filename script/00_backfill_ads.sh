#!/bin/bash
# 00_backfill_ads.sh  续跑：ADS 逐日 + 导出（DWD/DWS 已完成时使用）
set -e
source "$(dirname "$0")/00_env.sh"
S=${PROJECT_HOME}/script
DAYS=${DAYS:-"2017-11-25 2017-11-26 2017-11-27 2017-11-28 2017-11-29 2017-11-30 2017-12-01 2017-12-02 2017-12-03"}

echo "########## 阶段8-9 ADS 逐日 ##########"
for d in $DAYS; do
  echo "---------- ADS $d ----------"
  bash "$S/08_ads_core_1d.sh" "$d"
  bash "$S/09_ads_topic_1d.sh" "$d"
done

echo "########## 阶段10 导出 MySQL ##########"
bash "$S/10_export_mysql.sh"

echo "########## ADS 续跑完成 ##########"
