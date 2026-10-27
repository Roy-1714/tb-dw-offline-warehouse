-- ============================================================
-- 00_reset.sql  重建派生层用（不动 ODS、不动旧 gmall 库）
-- 只在需要从零重跑 DIM/DWD/DWS/ADS 时执行，日常调度不要跑
-- ============================================================
USE tb_dw;

DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_item;
DROP TABLE IF EXISTS dwd_user_behavior_detail;
DROP TABLE IF EXISTS dwd_dq_stat;
DROP TABLE IF EXISTS dws_user_action_1d;
DROP TABLE IF EXISTS dws_item_action_1d;
DROP TABLE IF EXISTS dws_category_action_1d;
DROP TABLE IF EXISTS dws_user_action_nd;
DROP TABLE IF EXISTS dws_user_action_td;
DROP TABLE IF EXISTS ads_dau_1d;
DROP TABLE IF EXISTS ads_funnel_1d;
DROP TABLE IF EXISTS ads_retention_1d;
DROP TABLE IF EXISTS ads_hour_active_1d;
DROP TABLE IF EXISTS ads_item_topn_1d;
DROP TABLE IF EXISTS ads_category_topn_1d;
DROP TABLE IF EXISTS ads_buy_freq_dist_1d;
DROP TABLE IF EXISTS ads_user_rf_seg_1d;
DROP TABLE IF EXISTS ads_path_analysis_1d;
DROP TABLE IF EXISTS ads_item_skew_1d;
