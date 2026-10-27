-- ============================================================
-- 04_dws_user.sql  DWS - 用户日粒度（节点 5/10）
-- ============================================================
USE tb_dw;

-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS dws_user_action_1d (
  user_id      BIGINT COMMENT '用户ID',
  pv_cnt       BIGINT COMMENT '浏览量',
  cart_cnt     BIGINT COMMENT '加购数',
  fav_cnt      BIGINT COMMENT '收藏数',
  buy_cnt      BIGINT COMMENT '购买数',
  item_cnt     BIGINT COMMENT '涉及商品数(去重)',
  category_cnt BIGINT COMMENT '涉及类目数(去重)',
  active_hours BIGINT COMMENT '活跃小时数(去重)',
  first_time   STRING COMMENT '当日首次行为时间',
  last_time    STRING COMMENT '当日末次行为时间'
)
COMMENT '用户日粒度行为汇总'
PARTITIONED BY (dt STRING COMMENT '日期')
STORED AS ORC
LOCATION '/warehouse/tb_dw/dws/dws_user_action_1d'
TBLPROPERTIES ('orc.compress' = 'snappy');

INSERT OVERWRITE TABLE dws_user_action_1d PARTITION (dt = '@DO_DATE@')
SELECT
  user_id,
  sum(CASE WHEN behavior_type = 'pv'   THEN 1 ELSE 0 END) AS pv_cnt,
  sum(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_cnt,
  sum(CASE WHEN behavior_type = 'fav'  THEN 1 ELSE 0 END) AS fav_cnt,
  sum(CASE WHEN behavior_type = 'buy'  THEN 1 ELSE 0 END) AS buy_cnt,
  count(DISTINCT item_id)      AS item_cnt,
  count(DISTINCT category_id)  AS category_cnt,
  count(DISTINCT `hour`)       AS active_hours,
  min(event_time)              AS first_time,
  max(event_time)              AS last_time
FROM dwd_user_behavior_detail
WHERE dt = '@DO_DATE@'
GROUP BY user_id;
