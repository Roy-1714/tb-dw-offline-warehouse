-- ============================================================
-- 05_dws_item_category.sql  DWS - 商品/类目日粒度（节点 6/10）
-- ============================================================
USE tb_dw;

-- ---------- 商品 × 日 ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS dws_item_action_1d (
  item_id      BIGINT COMMENT '商品ID',
  pv_cnt       BIGINT COMMENT '浏览量',
  uv_cnt       BIGINT COMMENT '浏览用户数(去重)',
  cart_cnt     BIGINT COMMENT '加购数',
  fav_cnt      BIGINT COMMENT '收藏数',
  buy_cnt      BIGINT COMMENT '购买数',
  buy_uv_cnt   BIGINT COMMENT '购买用户数(去重)'
)
COMMENT '商品日粒度行为汇总'
PARTITIONED BY (dt STRING COMMENT '日期')
STORED AS ORC
LOCATION '/warehouse/tb_dw/dws/dws_item_action_1d'
TBLPROPERTIES ('orc.compress' = 'snappy');

INSERT OVERWRITE TABLE dws_item_action_1d PARTITION (dt = '@DO_DATE@')
SELECT
  item_id,
  sum(CASE WHEN behavior_type = 'pv'   THEN 1 ELSE 0 END) AS pv_cnt,
  count(DISTINCT CASE WHEN behavior_type = 'pv'   THEN user_id END) AS uv_cnt,
  sum(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_cnt,
  sum(CASE WHEN behavior_type = 'fav'  THEN 1 ELSE 0 END) AS fav_cnt,
  sum(CASE WHEN behavior_type = 'buy'  THEN 1 ELSE 0 END) AS buy_cnt,
  count(DISTINCT CASE WHEN behavior_type = 'buy'  THEN user_id END) AS buy_uv_cnt
FROM dwd_user_behavior_detail
WHERE dt = '@DO_DATE@'
GROUP BY item_id;

-- ---------- 类目 × 日 ----------
-- （DDL 已改为幂等：CREATE TABLE IF NOT EXISTS；需要重建请跑 sql/00_reset.sql）
CREATE TABLE IF NOT EXISTS dws_category_action_1d (
  category_id  BIGINT COMMENT '类目ID',
  pv_cnt       BIGINT COMMENT '浏览量',
  uv_cnt       BIGINT COMMENT '浏览用户数(去重)',
  cart_cnt     BIGINT COMMENT '加购数',
  fav_cnt      BIGINT COMMENT '收藏数',
  buy_cnt      BIGINT COMMENT '购买数',
  buy_uv_cnt   BIGINT COMMENT '购买用户数(去重)',
  item_cnt     BIGINT COMMENT '涉及商品数(去重)'
)
COMMENT '类目日粒度行为汇总'
PARTITIONED BY (dt STRING COMMENT '日期')
STORED AS ORC
LOCATION '/warehouse/tb_dw/dws/dws_category_action_1d'
TBLPROPERTIES ('orc.compress' = 'snappy');

INSERT OVERWRITE TABLE dws_category_action_1d PARTITION (dt = '@DO_DATE@')
SELECT
  category_id,
  sum(CASE WHEN behavior_type = 'pv'   THEN 1 ELSE 0 END) AS pv_cnt,
  count(DISTINCT CASE WHEN behavior_type = 'pv'   THEN user_id END) AS uv_cnt,
  sum(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_cnt,
  sum(CASE WHEN behavior_type = 'fav'  THEN 1 ELSE 0 END) AS fav_cnt,
  sum(CASE WHEN behavior_type = 'buy'  THEN 1 ELSE 0 END) AS buy_cnt,
  count(DISTINCT CASE WHEN behavior_type = 'buy'  THEN user_id END) AS buy_uv_cnt,
  count(DISTINCT item_id) AS item_cnt
FROM dwd_user_behavior_detail
WHERE dt = '@DO_DATE@'
GROUP BY category_id;
