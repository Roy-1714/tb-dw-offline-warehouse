-- ============================================================
-- 91_verify_all.sql  全链路验收（跑完后一次性输出各层关键校验）
-- ============================================================
USE tb_dw;

-- 1) ODS 每日行数
SELECT 'ODS' AS layer, dt, count(*) AS cnt
FROM ods_user_behavior
GROUP BY dt ORDER BY dt;

-- 2) DWD 每日明细行数 与 数据质量统计
SELECT 'DWD' AS layer, dt, count(*) AS cnt
FROM dwd_user_behavior_detail
GROUP BY dt ORDER BY dt;

SELECT 'DQ' AS layer, dt, src_rows, kept_rows, dup_rows, bad_behavior
FROM dwd_dq_stat ORDER BY dt;

-- 3) DWS 每日用户数，并与 DWD 当日 pv/buy 次数交叉校验
SELECT
  a.dt,
  count(1)                        AS user_cnt,
  sum(a.pv_cnt)                   AS dws_pv,
  sum(a.buy_cnt)                  AS dws_buy,
  max(b.pv_rows)                  AS dwd_pv,
  max(b.buy_rows)                 AS dwd_buy
FROM dws_user_action_1d a
JOIN (
  SELECT dt,
         sum(CASE WHEN behavior_type = 'pv'  THEN 1 ELSE 0 END) AS pv_rows,
         sum(CASE WHEN behavior_type = 'buy' THEN 1 ELSE 0 END) AS buy_rows
  FROM dwd_user_behavior_detail
  GROUP BY dt
) b ON a.dt = b.dt
GROUP BY a.dt
ORDER BY a.dt;

-- 4) 维度层
SELECT 'DIM_ITEM' AS layer, count(1) AS item_cnt,
       sum(is_multi_category) AS multi_cat_items
FROM dim_item;

SELECT 'DIM_DATE' AS layer, count(1) AS day_cnt,
       sum(is_weekend) AS weekend_days
FROM dim_date;

-- 5) ADS 各表行数
SELECT 'ads_dau_1d' AS t, count(1) AS rows_cnt FROM ads_dau_1d
UNION ALL SELECT 'ads_funnel_1d', count(1) FROM ads_funnel_1d
UNION ALL SELECT 'ads_retention_1d', count(1) FROM ads_retention_1d
UNION ALL SELECT 'ads_hour_active_1d', count(1) FROM ads_hour_active_1d
UNION ALL SELECT 'ads_item_topn_1d', count(1) FROM ads_item_topn_1d
UNION ALL SELECT 'ads_category_topn_1d', count(1) FROM ads_category_topn_1d
UNION ALL SELECT 'ads_buy_freq_dist_1d', count(1) FROM ads_buy_freq_dist_1d
UNION ALL SELECT 'ads_user_rf_seg_1d', count(1) FROM ads_user_rf_seg_1d
UNION ALL SELECT 'ads_path_analysis_1d', count(1) FROM ads_path_analysis_1d
UNION ALL SELECT 'ads_item_skew_1d', count(1) FROM ads_item_skew_1d;

-- 6) 漏斗合理性：各层人数必须单调不增
SELECT dt, all_uv, pv_uv, cart_uv, fav_uv, buy_uv,
       CASE WHEN pv_uv >= cart_uv AND cart_uv >= buy_uv THEN 'OK' ELSE 'CHECK' END AS funnel_order
FROM ads_funnel_1d ORDER BY dt;

-- 7) 倾斜证据
SELECT dt, item_cnt, pv_total, top1pct_share, max_item_share
FROM ads_item_skew_1d ORDER BY dt;
