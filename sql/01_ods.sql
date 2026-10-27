-- ============================================================
-- 01_ods.sql  ODS 层
-- 原始数据：/origin_data/tb_dw/UserBehavior/UserBehavior.csv（100,150,807 行，3.5G）
-- 字段：user_id,item_id,category_id,behavior_type,ts(秒级时间戳)
--
-- 设计要点：
-- 1. 外部表 + TextFile：保留原始列、可回溯，不做格式改造
-- 2. 分区 dt 按【北京时间】切分（原始 ts 是 UTC 秒，from_unixtime 依赖会话时区）
-- 3. 时间戳越界（含负值）的行不丢，统一进 dt='invalid' 分区，便于审计与复算
-- ============================================================
USE tb_dw;

DROP TABLE IF EXISTS ods_user_behavior_ext;
CREATE EXTERNAL TABLE ods_user_behavior_ext (
  user_id       STRING COMMENT '用户ID',
  item_id       STRING COMMENT '商品ID',
  category_id   STRING COMMENT '类目ID',
  behavior_type STRING COMMENT '行为类型 pv/cart/fav/buy',
  `ts`          STRING COMMENT '事件时间戳(秒)'
)
COMMENT '用户行为原始CSV外部表（无分区，直读 /origin_data）'
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/origin_data/tb_dw/UserBehavior';

DROP TABLE IF EXISTS ods_user_behavior;
CREATE EXTERNAL TABLE ods_user_behavior (
  user_id       STRING COMMENT '用户ID',
  item_id       STRING COMMENT '商品ID',
  category_id   STRING COMMENT '类目ID',
  behavior_type STRING COMMENT '行为类型 pv/cart/fav/buy',
  `ts`          BIGINT COMMENT '事件时间戳(秒)'
)
COMMENT '用户行为ODS层：按北京时间日分区'
PARTITIONED BY (dt STRING COMMENT '日期(yyyy-MM-dd)，越界数据为 invalid')
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE
LOCATION '/warehouse/tb_dw/ods/ods_user_behavior';

-- ------------------------------------------------------------
-- 装载：动态分区
-- 合法时间窗：2017-11-25 00:00:00 ~ 2017-12-03 23:59:59 (UTC+8)
--   注意：时间戳是 UTC 秒，边界必须按 UTC 换算成北京时零点
--   下限 1511539200 = 2017-11-24 16:00:00 UTC = 2017-11-25 00:00:00 +08
--   上限 1512316799 = 2017-12-03 15:59:59 UTC = 2017-12-03 23:59:59 +08
--   （曾误用 1511568000/1512345599，导致 11-25 前 8 小时 118 万行被误判越界）
-- ------------------------------------------------------------
SET spark.sql.sources.partitionOverwriteMode=dynamic;
SET spark.sql.session.timeZone=Asia/Shanghai;
-- 动态分区必须显式放开 nonstrict，否则只允许「静态分区 + 动态分区」混用
SET hive.exec.dynamic.partition.mode=nonstrict;

INSERT OVERWRITE TABLE ods_user_behavior PARTITION (dt)
SELECT
  user_id,
  item_id,
  category_id,
  behavior_type,
  CAST(`ts` AS BIGINT) AS ts,
  CASE
    WHEN CAST(`ts` AS BIGINT) BETWEEN 1511539200 AND 1512316799
      THEN from_unixtime(CAST(`ts` AS BIGINT), 'yyyy-MM-dd')
    ELSE 'invalid'
  END AS dt
FROM ods_user_behavior_ext;

-- 清理历史错误边界可能留下的越界分区（幂等）
ALTER TABLE ods_user_behavior DROP IF EXISTS PARTITION (dt = '2017-12-04');
