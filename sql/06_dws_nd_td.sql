-- ============================================================
-- 06_dws_nd_td.sql  DWS - 滚动/累计（节点 7/10）
-- 4.4 近 7 日滚动：直接从 1d 汇总表重算，避免扫描明细
-- 4.5 历史累计：读「前一日快照」+「当日 1d 增量」合并，增量而非全量重算
-- ============================================================
USE tb_dw;

-- ---------- 4.4 用户滚动 7 日 ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS dws_user_action_nd (
  user_id        BIGINT COMMENT '用户ID',
  pv_7d          BIGINT COMMENT '近7日浏览量',
  buy_7d         BIGINT COMMENT '近7日购买数',
  cart_7d        BIGINT COMMENT '近7日加购数',
  active_days_7d BIGINT COMMENT '近7日活跃天数'
)
COMMENT '用户近7日滚动汇总'
PARTITIONED BY (dt STRING COMMENT '日期')
STORED AS ORC
LOCATION '/warehouse/tb_dw/dws/dws_user_action_nd'
TBLPROPERTIES ('orc.compress' = 'snappy');

INSERT OVERWRITE TABLE dws_user_action_nd PARTITION (dt = '@DO_DATE@')
SELECT
  user_id,
  sum(pv_cnt)   AS pv_7d,
  sum(buy_cnt)  AS buy_7d,
  sum(cart_cnt) AS cart_7d,
  count(1)      AS active_days_7d
FROM dws_user_action_1d
WHERE dt BETWEEN date_format(date_sub(to_date('@DO_DATE@'), 6), 'yyyy-MM-dd') AND '@DO_DATE@'
GROUP BY user_id;

-- ---------- 4.5 用户历史累计（按日快照，从 1d 汇总重算） ----------
-- 说明：最初写成「读前一日快照 + 当日增量」合并，Spark 报
--       Cannot overwrite a path that is also being read from（同一张表既读又写）。
--       改为从 dws_user_action_1d 汇总截止当日的数据重算：
--       1d 表每天仅约 100 万行（用户粒度），9 天累计不足千万，重算成本远低于
--       维护「快照合并」所需的中间表与路径规避，且逻辑更不易出错。
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS dws_user_action_td (
  user_id     BIGINT COMMENT '用户ID',
  first_dt    STRING COMMENT '首次活跃日',
  last_dt     STRING COMMENT '末次活跃日',
  pv_all      BIGINT COMMENT '累计浏览量',
  buy_all     BIGINT COMMENT '累计购买数',
  cart_all    BIGINT COMMENT '累计加购数',
  fav_all     BIGINT COMMENT '累计收藏数',
  active_days BIGINT COMMENT '累计活跃天数'
)
COMMENT '用户历史累计（每日快照）'
PARTITIONED BY (dt STRING COMMENT '快照日期')
STORED AS ORC
LOCATION '/warehouse/tb_dw/dws/dws_user_action_td'
TBLPROPERTIES ('orc.compress' = 'snappy');

INSERT OVERWRITE TABLE dws_user_action_td PARTITION (dt = '@DO_DATE@')
SELECT
  user_id,
  min(dt)     AS first_dt,
  max(dt)     AS last_dt,
  sum(pv_cnt) AS pv_all,
  sum(buy_cnt) AS buy_all,
  sum(cart_cnt) AS cart_all,
  sum(fav_cnt)  AS fav_all,
  count(1)    AS active_days
FROM dws_user_action_1d
WHERE dt <= '@DO_DATE@'
GROUP BY user_id;
