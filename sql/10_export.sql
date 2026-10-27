-- ============================================================
-- 10_export.sql  导出 ADS 到本地目录（节点 10/10 的第一步）
-- 流程：Hive 表 -> HDFS 文本目录 -> getmerge -> MySQL LOAD DATA
-- 用文本中转而非 JDBC，避免在 Spark 里额外挂 JDBC 驱动，导出链路更可控
-- ============================================================
USE tb_dw;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_dau_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, pv, uv, buy_uv, pv_per_uv, new_uv, old_uv, is_weekend FROM ads_dau_1d;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_funnel_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, all_uv, pv_uv, cart_uv, fav_uv, buy_uv, pv2cart_rate, cart2buy_rate, pv2buy_rate, pv2fav_rate FROM ads_funnel_1d;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_retention_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, new_uv, d1_uv, d1_rate, d3_uv, d3_rate, d7_uv, d7_rate FROM ads_retention_1d;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_hour_active_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, `hour`, pv, uv FROM ads_hour_active_1d;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_item_topn_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, rk, item_id, pv, uv, buy_uv FROM ads_item_topn_1d;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_category_topn_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, rk, category_id, pv, uv, buy_uv FROM ads_category_topn_1d;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_buy_freq_dist_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, freq_bucket, user_cnt, ratio FROM ads_buy_freq_dist_1d;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_user_rf_seg_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, r_level, f_level, segment, user_cnt, ratio, avg_recency_day, avg_buy_cnt FROM ads_user_rf_seg_1d;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_path_analysis_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, path, user_cnt, ratio, rk FROM ads_path_analysis_1d;

INSERT OVERWRITE DIRECTORY '/warehouse/tb_dw/export/ads_item_skew_1d'
USING csv OPTIONS ('sep' = '\t', 'header' = 'false', 'nullValue' = '', 'emptyValue' = '')
SELECT dt, item_cnt, pv_total, top1pct_item_cnt, top1pct_pv, top1pct_share, max_item_share FROM ads_item_skew_1d;
