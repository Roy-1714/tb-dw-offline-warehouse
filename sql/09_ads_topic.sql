-- ============================================================
-- 06_ads_topic.sql  ADS 主题指标（5-10 张，按天分区）
-- ============================================================
USE tb_dw;

-- ---------- 5. 商品 TopN ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_item_topn_1d (
  dt      STRING COMMENT '日期',
  rk      INT    COMMENT '排名',
  item_id BIGINT COMMENT '商品ID',
  pv      BIGINT COMMENT '浏览量',
  uv      BIGINT COMMENT '浏览用户数',
  buy_uv  BIGINT COMMENT '购买用户数'
)
COMMENT '商品浏览量TopN'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_item_topn_1d';

INSERT OVERWRITE TABLE ads_item_topn_1d PARTITION (dt_part = '@DO_DATE@')
SELECT '@DO_DATE@' AS dt, rk, item_id, pv, uv, buy_uv
FROM (
  SELECT
    row_number() OVER (ORDER BY pv_cnt DESC, item_id) AS rk,
    item_id, pv_cnt AS pv, uv_cnt AS uv, buy_uv_cnt AS buy_uv
  FROM dws_item_action_1d
  WHERE dt = '@DO_DATE@'
) t
WHERE rk <= 50;

-- ---------- 6. 类目 TopN ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_category_topn_1d (
  dt          STRING COMMENT '日期',
  rk          INT    COMMENT '排名',
  category_id BIGINT COMMENT '类目ID',
  pv          BIGINT COMMENT '浏览量',
  uv          BIGINT COMMENT '浏览用户数',
  buy_uv      BIGINT COMMENT '购买用户数'
)
COMMENT '类目浏览量TopN'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_category_topn_1d';

INSERT OVERWRITE TABLE ads_category_topn_1d PARTITION (dt_part = '@DO_DATE@')
SELECT '@DO_DATE@' AS dt, rk, category_id, pv, uv, buy_uv
FROM (
  SELECT
    row_number() OVER (ORDER BY pv_cnt DESC, category_id) AS rk,
    category_id, pv_cnt AS pv, uv_cnt AS uv, buy_uv_cnt AS buy_uv
  FROM dws_category_action_1d
  WHERE dt = '@DO_DATE@'
) t
WHERE rk <= 30;

-- ---------- 7. 购买频次分布 ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_buy_freq_dist_1d (
  dt          STRING COMMENT '日期',
  freq_bucket STRING COMMENT '购买频次区间',
  user_cnt    BIGINT COMMENT '用户数',
  ratio       DOUBLE COMMENT '占比'
)
COMMENT '当日购买频次分布'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_buy_freq_dist_1d';

INSERT OVERWRITE TABLE ads_buy_freq_dist_1d PARTITION (dt_part = '@DO_DATE@')
SELECT
  '@DO_DATE@' AS dt,
  freq_bucket,
  user_cnt,
  round(user_cnt / sum(user_cnt) OVER (), 4) AS ratio
FROM (
  SELECT
    CASE
      WHEN buy_cnt = 1 THEN '1次'
      WHEN buy_cnt = 2 THEN '2次'
      WHEN buy_cnt BETWEEN 3 AND 5 THEN '3-5次'
      ELSE '6次及以上'
    END AS freq_bucket,
    count(1) AS user_cnt
  FROM dws_user_action_1d
  WHERE dt = '@DO_DATE@' AND buy_cnt > 0
  GROUP BY 1
) t;

-- ---------- 8. RF 分层（无金额，不做 RFM） ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_user_rf_seg_1d (
  dt              STRING COMMENT '日期',
  r_level         STRING COMMENT '最近活跃近度档',
  f_level         STRING COMMENT '累计购买频次档',
  segment         STRING COMMENT 'RF组合分层',
  user_cnt        BIGINT COMMENT '用户数',
  ratio           DOUBLE COMMENT '占比',
  avg_recency_day DOUBLE COMMENT '平均距今天数',
  avg_buy_cnt     DOUBLE COMMENT '平均累计购买次数'
)
COMMENT '用户RF分层（M维度因无金额字段不可得）'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_user_rf_seg_1d';

INSERT OVERWRITE TABLE ads_user_rf_seg_1d PARTITION (dt_part = '@DO_DATE@')
SELECT
  '@DO_DATE@' AS dt,
  r_level, f_level,
  concat(r_level, '-', f_level) AS segment,
  count(1) AS user_cnt,
  round(count(1) / sum(count(1)) OVER (), 4) AS ratio,
  round(avg(recency_day), 2) AS avg_recency_day,
  round(avg(buy_all), 2)     AS avg_buy_cnt
FROM (
  SELECT
    CASE
      WHEN datediff(to_date('@DO_DATE@'), to_date(last_dt)) <= 1 THEN 'R1_近'
      WHEN datediff(to_date('@DO_DATE@'), to_date(last_dt)) <= 3 THEN 'R2_中'
      ELSE 'R3_远'
    END AS r_level,
    CASE
      WHEN buy_all >= 5 THEN 'F1_高频'
      WHEN buy_all >= 1 THEN 'F2_中频'
      ELSE 'F3_未购买'
    END AS f_level,
    datediff(to_date('@DO_DATE@'), to_date(last_dt)) AS recency_day,
    buy_all
  FROM dws_user_action_td
  WHERE dt = '@DO_DATE@'
) t
GROUP BY r_level, f_level;

-- ---------- 9. 用户行为路径（当日前 4 步） ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_path_analysis_1d (
  dt        STRING COMMENT '日期',
  path      STRING COMMENT '行为路径(前4步)',
  user_cnt  BIGINT COMMENT '用户数',
  ratio     DOUBLE COMMENT '占比',
  rk        INT    COMMENT '排名'
)
COMMENT '用户行为路径TopN'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_path_analysis_1d';

INSERT OVERWRITE TABLE ads_path_analysis_1d PARTITION (dt_part = '@DO_DATE@')
SELECT '@DO_DATE@' AS dt, path, user_cnt, ratio, rk
FROM (
  SELECT
    path,
    user_cnt,
    round(user_cnt / sum(user_cnt) OVER (), 4) AS ratio,
    row_number() OVER (ORDER BY user_cnt DESC, path) AS rk
  FROM (
    -- 先把每个用户当日的前 4 步拼成路径，再按路径统计人数
    SELECT
      path,
      count(1) AS user_cnt
    FROM (
      SELECT
        user_id,
        concat_ws('->',
          max(CASE WHEN rn = 1 THEN behavior_type END),
          max(CASE WHEN rn = 2 THEN behavior_type END),
          max(CASE WHEN rn = 3 THEN behavior_type END),
          max(CASE WHEN rn = 4 THEN behavior_type END)
        ) AS path
      FROM (
        SELECT
          user_id, behavior_type,
          row_number() OVER (PARTITION BY user_id ORDER BY `ts`, item_id) AS rn
        FROM dwd_user_behavior_detail
        WHERE dt = '@DO_DATE@'
      ) s
      WHERE rn <= 4
      GROUP BY user_id
    ) u
    GROUP BY path
  ) t
) q
WHERE rk <= 20;

-- ---------- 10. 商品访问集中度（数据倾斜证据） ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS ads_item_skew_1d (
  dt               STRING COMMENT '日期',
  item_cnt         BIGINT COMMENT '有行为商品数',
  pv_total         BIGINT COMMENT '总浏览量',
  top1pct_item_cnt BIGINT COMMENT '前1%商品数',
  top1pct_pv       BIGINT COMMENT '前1%商品浏览量',
  top1pct_share    DOUBLE COMMENT '前1%商品浏览量占比',
  max_item_share   DOUBLE COMMENT '单商品最大浏览量占比'
)
COMMENT '商品访问集中度（为倾斜治理提供量化依据）'
PARTITIONED BY (dt_part STRING)
STORED AS ORC
LOCATION '/warehouse/tb_dw/ads/ads_item_skew_1d';

INSERT OVERWRITE TABLE ads_item_skew_1d PARTITION (dt_part = '@DO_DATE@')
SELECT
  '@DO_DATE@' AS dt,
  count(1) AS item_cnt,
  sum(pv)  AS pv_total,
  sum(CASE WHEN pr >= 0.99 THEN 1 ELSE 0 END) AS top1pct_item_cnt,
  sum(CASE WHEN pr >= 0.99 THEN pv ELSE 0 END) AS top1pct_pv,
  round(sum(CASE WHEN pr >= 0.99 THEN pv ELSE 0 END) / sum(pv), 4) AS top1pct_share,
  round(max(pv) / sum(pv), 4) AS max_item_share
FROM (
  SELECT pv_cnt AS pv, percent_rank() OVER (ORDER BY pv_cnt) AS pr
  FROM dws_item_action_1d
  WHERE dt = '@DO_DATE@'
) t;
