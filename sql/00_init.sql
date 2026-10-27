-- ============================================================
-- 00_init.sql  建库
-- 数仓：tb_dw（淘宝用户行为离线数仓）
-- 说明：旧项目 gmall 库保留不动，本项目使用独立库名与独立 HDFS 根目录
-- ============================================================
CREATE DATABASE IF NOT EXISTS tb_dw
  COMMENT '淘宝用户行为离线数仓（ODS/DIM/DWD/DWS/ADS）'
  LOCATION '/warehouse/tb_dw';

USE tb_dw;
SHOW DATABASES;
