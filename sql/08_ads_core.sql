-- ============================================================
-- 05_ads.sql  ADS 层（10 张，按天分区）
-- 指标口径见 docs/03-指标口径.md
-- 注意：本数据集无金额字段，故不做 GMV/客单价/退款率；
--       RF 分层只用 R(最近活跃) 与 F(购买频次) 两维，M 维度不可得
-- ============================================================
USE tb_dw;

-- ---------- 1. 日活核心 ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_dau_1d (
  dt         STRING COMMENT '日期',
  pv         BIGINT COMMENT '浏览量',
  uv         BIGINT COMMENT '活跃用户数',
  buy_uv     BIGINT COMMENT '购买用户数',
  pv_per_uv  DOUBLE COMMENT '人均浏览量',
  new_uv     BIGINT COMMENT '新增用户数',
  old_uv     BIGINT COMMENT '老用户数',
  is_weekend INT    COMMENT '是否周末'
)
COMMENT '日活核心指标'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_dau_1d';

INSERT OVERWRITE TABLE ads_dau_1d PARTITION (dt_part = '@DO_DATE@')
SELECT
  '@DO_DATE@'                                  AS dt,
  sum(u.pv_cnt)                                AS pv,
  count(1)                                     AS uv,
  sum(CASE WHEN u.buy_cnt > 0 THEN 1 ELSE 0 END) AS buy_uv,
  round(sum(u.pv_cnt) / count(1), 4)           AS pv_per_uv,
  sum(CASE WHEN t.first_dt = '@DO_DATE@' THEN 1 ELSE 0 END) AS new_uv,
  sum(CASE WHEN t.first_dt < '@DO_DATE@' THEN 1 ELSE 0 END) AS old_uv,
  max(d.is_weekend)                            AS is_weekend
FROM dws_user_action_1d u
LEFT JOIN dws_user_action_td t
  ON u.user_id = t.user_id AND t.dt = '@DO_DATE@'
LEFT JOIN dim_date d
  ON u.dt = d.dt
WHERE u.dt = '@DO_DATE@'
GROUP BY u.dt;

-- ---------- 2. 行为漏斗 ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_funnel_1d (
  dt            STRING COMMENT '日期',
  all_uv        BIGINT COMMENT '全部活跃用户',
  pv_uv         BIGINT COMMENT '浏览用户',
  cart_uv       BIGINT COMMENT '加购用户',
  fav_uv        BIGINT COMMENT '收藏用户',
  buy_uv        BIGINT COMMENT '购买用户',
  pv2cart_rate  DOUBLE COMMENT '浏览→加购转化率',
  cart2buy_rate DOUBLE COMMENT '加购→购买转化率',
  pv2buy_rate   DOUBLE COMMENT '浏览→购买整体转化率',
  pv2fav_rate   DOUBLE COMMENT '浏览→收藏转化率'
)
COMMENT '行为漏斗转化'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_funnel_1d';

INSERT OVERWRITE TABLE ads_funnel_1d PARTITION (dt_part = '@DO_DATE@')
SELECT
  '@DO_DATE@' AS dt,
  count(1) AS all_uv,
  sum(CASE WHEN pv_cnt   > 0 THEN 1 ELSE 0 END) AS pv_uv,
  sum(CASE WHEN cart_cnt > 0 THEN 1 ELSE 0 END) AS cart_uv,
  sum(CASE WHEN fav_cnt  > 0 THEN 1 ELSE 0 END) AS fav_uv,
  sum(CASE WHEN buy_cnt  > 0 THEN 1 ELSE 0 END) AS buy_uv,
  round(sum(CASE WHEN cart_cnt > 0 THEN 1 ELSE 0 END) / sum(CASE WHEN pv_cnt > 0 THEN 1 ELSE 0 END), 4) AS pv2cart_rate,
  round(sum(CASE WHEN buy_cnt  > 0 THEN 1 ELSE 0 END) / sum(CASE WHEN cart_cnt > 0 THEN 1 ELSE 0 END), 4) AS cart2buy_rate,
  round(sum(CASE WHEN buy_cnt  > 0 THEN 1 ELSE 0 END) / sum(CASE WHEN pv_cnt > 0 THEN 1 ELSE 0 END), 4) AS pv2buy_rate,
  round(sum(CASE WHEN fav_cnt  > 0 THEN 1 ELSE 0 END) / sum(CASE WHEN pv_cnt > 0 THEN 1 ELSE 0 END), 4) AS pv2fav_rate
FROM dws_user_action_1d
WHERE dt = '@DO_DATE@';

-- ---------- 3. 留存 ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_retention_1d (
  dt       STRING COMMENT '首访日',
  new_uv   BIGINT COMMENT '当日新增用户',
  d1_uv    BIGINT COMMENT '次日留存人数',
  d1_rate  DOUBLE COMMENT '次日留存率',
  d3_uv    BIGINT COMMENT '3日留存人数',
  d3_rate  DOUBLE COMMENT '3日留存率',
  d7_uv    BIGINT COMMENT '7日留存人数',
  d7_rate  DOUBLE COMMENT '7日留存率'
)
COMMENT '新增用户留存'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_retention_1d';

INSERT OVERWRITE TABLE ads_retention_1d PARTITION (dt_part = '@DO_DATE@')
SELECT
  '@DO_DATE@' AS dt,
  count(1) AS new_uv,
  sum(CASE WHEN a1.user_id IS NOT NULL THEN 1 ELSE 0 END) AS d1_uv,
  round(sum(CASE WHEN a1.user_id IS NOT NULL THEN 1 ELSE 0 END) / count(1), 4) AS d1_rate,
  sum(CASE WHEN a3.user_id IS NOT NULL THEN 1 ELSE 0 END) AS d3_uv,
  round(sum(CASE WHEN a3.user_id IS NOT NULL THEN 1 ELSE 0 END) / count(1), 4) AS d3_rate,
  sum(CASE WHEN a7.user_id IS NOT NULL THEN 1 ELSE 0 END) AS d7_uv,
  round(sum(CASE WHEN a7.user_id IS NOT NULL THEN 1 ELSE 0 END) / count(1), 4) AS d7_rate
FROM (
  SELECT user_id
  FROM dws_user_action_td
  WHERE dt = '@DO_DATE@' AND first_dt = '@DO_DATE@'
) n
LEFT JOIN (SELECT DISTINCT user_id FROM dws_user_action_1d WHERE dt = date_add(to_date('@DO_DATE@'), 1)) a1
  ON n.user_id = a1.user_id
LEFT JOIN (SELECT DISTINCT user_id FROM dws_user_action_1d WHERE dt = date_add(to_date('@DO_DATE@'), 3)) a3
  ON n.user_id = a3.user_id
LEFT JOIN (SELECT DISTINCT user_id FROM dws_user_action_1d WHERE dt = date_add(to_date('@DO_DATE@'), 7)) a7
  ON n.user_id = a7.user_id;

-- ---------- 4. 分时活跃 ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_hour_active_1d (
  dt   STRING COMMENT '日期',
  `hour` INT  COMMENT '小时',
  pv   BIGINT COMMENT '浏览量',
  uv   BIGINT COMMENT '活跃用户数'
)
COMMENT '分时活跃'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_hour_active_1d';

INSERT OVERWRITE TABLE ads_hour_active_1d PARTITION (dt_part = '@DO_DATE@')
SELECT
  '@DO_DATE@' AS dt,
  `hour`,
  sum(CASE WHEN behavior_type = 'pv' THEN 1 ELSE 0 END) AS pv,
  count(DISTINCT user_id) AS uv
FROM dwd_user_behavior_detail
WHERE dt = '@DO_DATE@'
GROUP BY `hour`;
