#!/bin/bash
# 续跑：补 DWD 最后一天 -> 商品维 -> DWS 9 天 -> ADS 9 天 -> 导出
set -e
source "$(dirname "$0")/00_env.sh"
S=$(dirname "$0")
LOG=$LOG_DIR/resume_$(date +%H%M).log
echo "日志: $LOG"

bash "$S/03_dwd_detail_1d.sh" 2017-12-03 >> "$LOG" 2>&1
bash "$S/00_backfill_tail.sh" >> "$LOG" 2>&1
echo "续跑完成: $LOG"
