-- ============================================================
-- 03_dwd.sql  DWD 层 - 行为明细（按天增量，分区 dt）
-- 清洗规则（每条都有数据依据，见 docs/01-数据探查.md）：
--   R1 只取 ODS 合法日分区，dt='invalid'（5.5 万行越界/负值时间戳）不进入明细
--   R2 behavior_type 限定 pv/cart/fav/buy
--   R3 类型规范化：id 转 BIGINT、ts 转秒
--   R4 完全重复事件（同 user+item+behavior+ts）按 rn=1 保留一条
--       代价：一次按用户分区的 shuffle；按天增量后每天 ≤1.4 千万行，可接受
--   R5 派生 event_time / hour / is_weekend，避免下游反复解析时间
-- 同时产出数据质量统计表 dwd_dq_stat，把"洗掉了多少"变成可核查指标
-- ============================================================
USE tb_dw;

-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS dwd_user_behavior_detail (
  user_id       BIGINT COMMENT '用户ID',
  item_id       BIGINT COMMENT '商品ID',
  category_id   BIGINT COMMENT '类目ID',
  behavior_type STRING COMMENT '行为类型 pv/cart/fav/buy',
  `ts`          BIGINT COMMENT '事件时间戳(秒)',
  event_time    STRING COMMENT '事件时间 yyyy-MM-dd HH:mm:ss(北京时)',
  `hour`        INT    COMMENT '小时 0-23',
  is_weekend    INT    COMMENT '是否周末 1是 0否'
)
COMMENT '用户行为明细事实表'
PARTITIONED BY (dt STRING COMMENT '日期 yyyy-MM-dd')
STORED AS ORC
LOCATION '/warehouse/tb_dw/dwd/dwd_user_behavior_detail'
TBLPROPERTIES ('orc.compress' = 'snappy');

-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS dwd_dq_stat (
  src_rows     BIGINT COMMENT '当日源行数',
  kept_rows    BIGINT COMMENT '去重后保留行数',
  dup_rows     BIGINT COMMENT '完全重复行数',
  bad_behavior BIGINT COMMENT '非法行为类型行数'
)
COMMENT 'DWD 数据质量统计'
PARTITIONED BY (dt STRING COMMENT '日期')
STORED AS ORC
LOCATION '/warehouse/tb_dw/dwd/dwd_dq_stat';

-- ------------------------------------------------------------
-- 当日明细装载（@DO_DATE@ 由调度脚本渲染）
-- ------------------------------------------------------------
INSERT OVERWRITE TABLE dwd_user_behavior_detail PARTITION (dt = '@DO_DATE@')
SELECT
  user_id,
  item_id,
  category_id,
  behavior_type,
  ts,
  from_unixtime(ts, 'yyyy-MM-dd HH:mm:ss')            AS event_time,
  hour(from_unixtime(ts))                             AS `hour`,
  CASE WHEN dayofweek(from_unixtime(ts, 'yyyy-MM-dd')) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM (
  SELECT
    CAST(user_id AS BIGINT)     AS user_id,
    CAST(item_id AS BIGINT)     AS item_id,
    CAST(category_id AS BIGINT) AS category_id,
    behavior_type,
    `ts`,
    row_number() OVER (PARTITION BY user_id, item_id, behavior_type, `ts` ORDER BY `ts`) AS rn
  FROM ods_user_behavior
  WHERE dt = '@DO_DATE@'
    AND behavior_type IN ('pv', 'cart', 'fav', 'buy')
) t
WHERE rn = 1;

-- ------------------------------------------------------------
-- 当日数据质量统计
-- ------------------------------------------------------------
INSERT OVERWRITE TABLE dwd_dq_stat PARTITION (dt = '@DO_DATE@')
SELECT
  count(*)                                               AS src_rows,
  sum(CASE WHEN rn = 1 THEN 1 ELSE 0 END)                AS kept_rows,
  sum(CASE WHEN rn > 1 THEN 1 ELSE 0 END)                AS dup_rows,
  sum(CASE WHEN behavior_type IN ('pv','cart','fav','buy') THEN 0 ELSE 1 END) AS bad_behavior
FROM (
  SELECT
    behavior_type,
    row_number() OVER (PARTITION BY user_id, item_id, behavior_type, `ts` ORDER BY `ts`) AS rn
  FROM ods_user_behavior
  WHERE dt = '@DO_DATE@'
) t;
