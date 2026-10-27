-- ============================================================
-- 07_dim_item.sql  商品维度（节点 4/10，全量重算）
-- 事实依据：数据探查发现 item→category 并非一对一（20M 样本中 600 个商品跨类目），
--          因此维表保存「主类目」与「是否跨类目」标记，不能直接用 item_id 当唯一键
-- 实现注意：Spark 不支持 count(distinct) over(...)，改为两次聚合后 join
--   ① 商品×类目 计数 + 主类目排名
--   ② 商品级 汇总（类目数、首末日期、四类行为累计）
-- ============================================================
USE tb_dw;

DROP TABLE IF EXISTS dim_item;
CREATE TABLE dim_item (
  item_id           BIGINT COMMENT '商品ID',
  category_id       BIGINT COMMENT '主类目ID（出现次数最多）',
  category_cnt      INT    COMMENT '涉及类目数',
  is_multi_category INT    COMMENT '是否跨类目 1是 0否',
  first_dt          STRING COMMENT '首次出现日期',
  last_dt           STRING COMMENT '末次出现日期',
  pv_cnt            BIGINT COMMENT '累计浏览量',
  cart_cnt          BIGINT COMMENT '累计加购数',
  fav_cnt           BIGINT COMMENT '累计收藏数',
  buy_cnt           BIGINT COMMENT '累计购买数'
)
COMMENT '商品维度表（主类目取众数）'
STORED AS ORC
LOCATION '/warehouse/tb_dw/dim/dim_item'
TBLPROPERTIES ('orc.compress' = 'snappy');

INSERT OVERWRITE TABLE dim_item
SELECT
  c.item_id,
  c.category_id,
  i.category_cnt,
  CASE WHEN i.category_cnt > 1 THEN 1 ELSE 0 END AS is_multi_category,
  i.first_dt,
  i.last_dt,
  i.pv_cnt,
  i.cart_cnt,
  i.fav_cnt,
  i.buy_cnt
FROM (
  SELECT item_id, category_id,
         row_number() OVER (PARTITION BY item_id ORDER BY count(1) DESC, category_id) AS rn
  FROM dwd_user_behavior_detail
  GROUP BY item_id, category_id
) c
JOIN (
  SELECT item_id,
         count(DISTINCT category_id) AS category_cnt,
         min(dt) AS first_dt,
         max(dt) AS last_dt,
         sum(CASE WHEN behavior_type = 'pv'   THEN 1 ELSE 0 END) AS pv_cnt,
         sum(CASE WHEN behavior_type = 'cart' THEN 1 ELSE 0 END) AS cart_cnt,
         sum(CASE WHEN behavior_type = 'fav'  THEN 1 ELSE 0 END) AS fav_cnt,
         sum(CASE WHEN behavior_type = 'buy'  THEN 1 ELSE 0 END) AS buy_cnt
  FROM dwd_user_behavior_detail
  GROUP BY item_id
) i
  ON c.item_id = i.item_id
WHERE c.rn = 1;
