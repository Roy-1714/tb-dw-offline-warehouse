-- 90_verify_ods.sql  ODS 装载验收
USE tb_dw;

-- 每个分区的行数（应与 awk 画像逐日吻合）
SELECT dt, count(*) AS cnt
FROM ods_user_behavior
GROUP BY dt
ORDER BY dt;

-- 全量行数（应 = 100,150,807）
SELECT count(*) AS total_rows FROM ods_user_behavior;

-- 越界数据（应 ≈ 55,576）
SELECT count(*) AS invalid_rows FROM ods_user_behavior WHERE dt = 'invalid';
