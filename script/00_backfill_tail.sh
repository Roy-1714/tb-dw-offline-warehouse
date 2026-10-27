#!/bin/bash
# 00_backfill_tail.sh  续跑：商品维 + DWS + ADS + 导出（DWD 已完成时使用）
set -e
source "$(dirname "$0")/00_env.sh"
S=${PROJECT_HOME}/script
DAYS=${DAYS:-"2017-11-25 2017-11-26 2017-11-27 2017-11-28 2017-11-29 2017-11-30 2017-12-01 2017-12-02 2017-12-03"}

echo "########## 阶段4 商品维 ##########"
bash "$S/04_dim_item.sh"

echo "########## 阶段5-7 DWS 逐日 ##########"
for d in $DAYS; do
  echo "---------- DWS $d ----------"
  bash "$S/05_dws_user_1d.sh" "$d"
  bash "$S/06_dws_item_category_1d.sh" "$d"
  bash "$S/07_dws_nd_td.sh" "$d"
done

echo "########## 阶段8-9 ADS 逐日 ##########"
for d in $DAYS; do
  echo "---------- ADS $d ----------"
  bash "$S/08_ads_core_1d.sh" "$d"
  bash "$S/09_ads_topic_1d.sh" "$d"
done

echo "########## 阶段10 导出 MySQL ##########"
bash "$S/10_export_mysql.sh"

echo "########## 续跑完成 ##########"
