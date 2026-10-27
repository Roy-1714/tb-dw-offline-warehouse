-- ============================================================
-- 02_dim.sql  维度层 - 日期维（静态，可重跑）
-- 覆盖 2017-11 与 2017-12 整月，便于同比/环比与周分布分析
-- ============================================================
USE tb_dw;

DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date (
  dt          STRING COMMENT '日期 yyyy-MM-dd',
  year        INT    COMMENT '年',
  month       INT    COMMENT '月',
  day         INT    COMMENT '日',
  week        INT    COMMENT '年内第几周',
  weekday_num INT    COMMENT '星期几 1=周日 ... 7=周六',
  weekday_cn  STRING COMMENT '星期中文',
  is_weekend  INT    COMMENT '是否周末 1是 0否'
)
COMMENT '日期维度表'
STORED AS ORC
LOCATION '/warehouse/tb_dw/dim/dim_date';

INSERT OVERWRITE TABLE dim_date
SELECT
  date_format(d, 'yyyy-MM-dd')                AS dt,
  year(d)                                     AS year,
  month(d)                                    AS month,
  day(d)                                      AS day,
  weekofyear(d)                               AS week,
  dayofweek(d)                                AS weekday_num,
  date_format(d, 'E')                         AS weekday_cn,
  CASE WHEN dayofweek(d) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM (
  SELECT explode(sequence(to_date('2017-11-01'), to_date('2017-12-31'), interval 1 day)) AS d
) t;
