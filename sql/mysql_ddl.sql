-- ============================================================
-- mysql_ddl.sql  报表库建表（MySQL 8.0.31 / hadoop102:3306）
-- 与 ADS 一一对应，供导出与 Superset 直连
-- ============================================================
CREATE DATABASE IF NOT EXISTS tb_dw_report DEFAULT CHARACTER SET utf8mb4;
USE tb_dw_report;

DROP TABLE IF EXISTS ads_dau_1d;
CREATE TABLE ads_dau_1d (
  dt VARCHAR(20) COMMENT '日期',
  pv BIGINT, uv BIGINT, buy_uv BIGINT, pv_per_uv DOUBLE,
  new_uv BIGINT, old_uv BIGINT, is_weekend INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='日活核心';

DROP TABLE IF EXISTS ads_funnel_1d;
CREATE TABLE ads_funnel_1d (
  dt VARCHAR(20), all_uv BIGINT, pv_uv BIGINT, cart_uv BIGINT, fav_uv BIGINT, buy_uv BIGINT,
  pv2cart_rate DOUBLE, cart2buy_rate DOUBLE, pv2buy_rate DOUBLE, pv2fav_rate DOUBLE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='行为漏斗';

DROP TABLE IF EXISTS ads_retention_1d;
CREATE TABLE ads_retention_1d (
  dt VARCHAR(20), new_uv BIGINT, d1_uv BIGINT, d1_rate DOUBLE,
  d3_uv BIGINT, d3_rate DOUBLE, d7_uv BIGINT, d7_rate DOUBLE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='新增留存';

DROP TABLE IF EXISTS ads_hour_active_1d;
CREATE TABLE ads_hour_active_1d (
  dt VARCHAR(20), `hour` INT, pv BIGINT, uv BIGINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='分时活跃';

DROP TABLE IF EXISTS ads_item_topn_1d;
CREATE TABLE ads_item_topn_1d (
  dt VARCHAR(20), rk INT, item_id BIGINT, pv BIGINT, uv BIGINT, buy_uv BIGINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品TopN';

DROP TABLE IF EXISTS ads_category_topn_1d;
CREATE TABLE ads_category_topn_1d (
  dt VARCHAR(20), rk INT, category_id BIGINT, pv BIGINT, uv BIGINT, buy_uv BIGINT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='类目TopN';

DROP TABLE IF EXISTS ads_buy_freq_dist_1d;
CREATE TABLE ads_buy_freq_dist_1d (
  dt VARCHAR(20), freq_bucket VARCHAR(32), user_cnt BIGINT, ratio DOUBLE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='购买频次分布';

DROP TABLE IF EXISTS ads_user_rf_seg_1d;
CREATE TABLE ads_user_rf_seg_1d (
  dt VARCHAR(20), r_level VARCHAR(32), f_level VARCHAR(32), segment VARCHAR(64),
  user_cnt BIGINT, ratio DOUBLE, avg_recency_day DOUBLE, avg_buy_cnt DOUBLE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='RF分层';

DROP TABLE IF EXISTS ads_path_analysis_1d;
CREATE TABLE ads_path_analysis_1d (
  dt VARCHAR(20), path VARCHAR(200), user_cnt BIGINT, ratio DOUBLE, rk INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='行为路径TopN';

DROP TABLE IF EXISTS ads_item_skew_1d;
CREATE TABLE ads_item_skew_1d (
  dt VARCHAR(20), item_cnt BIGINT, pv_total BIGINT, top1pct_item_cnt BIGINT,
  top1pct_pv BIGINT, top1pct_share DOUBLE, max_item_share DOUBLE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品访问集中度';
