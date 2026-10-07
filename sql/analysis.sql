-- ============================================================
-- 项目：重庆各区县2024年经济数据分析（38区县）
-- 数据来源：重庆统计年鉴2025（重庆市统计局官方发布）
-- 数据库：MySQL 8.0 | 客户端：DBeaver
-- 作者：崔峻侨
-- ============================================================

-- ---------- ① 建库建表 ----------
CREATE DATABASE IF NOT EXISTS cq_economy DEFAULT CHARSET utf8mb4;
USE cq_economy;

DROP TABLE IF EXISTS district_economy;
CREATE TABLE district_economy (
    id             INT AUTO_INCREMENT PRIMARY KEY COMMENT '自增主键',
    district       VARCHAR(50)        COMMENT '区县名称',
    gdp_wan        DECIMAL(15,2)      COMMENT '地区生产总值（万元）',
    primary_wan    DECIMAL(15,2)      COMMENT '第一产业增加值（万元）',
    secondary_wan  DECIMAL(15,2)      COMMENT '第二产业增加值（万元）',
    tertiary_wan   DECIMAL(15,2)      COMMENT '第三产业增加值（万元）',
    per_capita_yuan INT               COMMENT '人均GDP（元）',
    pop_wan        DECIMAL(10,2)      COMMENT '常住人口（万人）',
    urban_rate_pct DECIMAL(5,2)       COMMENT '城镇化率（%）'
  );

-- ---------- ② 导入CSV（备选，数据已入库） ----------
-- SET GLOBAL local_infile = 1;
-- LOAD DATA LOCAL INFILE 'E:/ETL/cq_data.csv'
-- INTO TABLE district_economy
-- CHARACTER SET utf8mb4
-- FIELDS TERMINATED BY ','
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (district, gdp_wan, primary_wan, secondary_wan, tertiary_wan, per_capita_yuan, pop_wan, urban_rate_pct);

-- ============================================================
-- 分析1：GDP总量 Top10 —— 重庆经济第一梯队
-- 结论：渝北区2769亿第一，九龙坡、江北、涪陵、渝中为第二梯队
-- ============================================================
SELECT district AS 区县,
       ROUND(gdp_wan / 10000, 1) AS GDP_亿元,
       per_capita_yuan AS 人均GDP_元
FROM district_economy
ORDER BY gdp_wan DESC
LIMIT 10;

-- ============================================================
-- 分析2：人均GDP Top10 —— 人均GDP领先区县
-- 结论：渝中区29.4万第一（GDP总量仅第5，人均却第1），江北20.2万第二
-- ============================================================
SELECT district AS 区县,
       per_capita_yuan AS 人均GDP_元,
       ROUND(pop_wan, 1) AS 常住人口_万
FROM district_economy
ORDER BY per_capita_yuan DESC
LIMIT 10;

-- ============================================================
-- 分析3：GDP排名 vs 人均排名差异（窗口函数 RANK）
-- 排名差 = 人均排名 - GDP排名（负值=人均排名靠前于GDP总量排名）
-- 注意：RANK() 返回 BIGINT UNSIGNED，相减为负会溢出，
--       必须用 CAST(... AS SIGNED) 转成有符号整数
-- 结论：渝中区排名差-4（反差最大），渝北区GDP第1但人均掉出前6
-- ============================================================
SELECT district AS 区县,
       ROUND(gdp_wan/10000, 1) AS GDP_亿元,
       RANK() OVER (ORDER BY gdp_wan DESC) AS GDP排名,
       per_capita_yuan AS 人均GDP_元,
       RANK() OVER (ORDER BY per_capita_yuan DESC) AS 人均排名,
       CAST(RANK() OVER (ORDER BY per_capita_yuan DESC) AS SIGNED)
         - CAST(RANK() OVER (ORDER BY gdp_wan DESC) AS SIGNED) AS 排名差
FROM district_economy
ORDER BY 排名差 DESC;

-- ============================================================
-- 分析4：人口>50万但人均GDP低的区县 —— 发展滞后区
-- 结论：酉阳县4.2万最低；开州区117.9万人口（第3大）人均仅6.1万
-- ============================================================
SELECT district AS 区县,
       ROUND(pop_wan, 1) AS 人口_万,
       ROUND(gdp_wan/10000, 1) AS GDP_亿元,
       per_capita_yuan AS 人均GDP_元
FROM district_economy
WHERE pop_wan > 50
ORDER BY per_capita_yuan ASC
LIMIT 10;

-- ============================================================
-- 分析5：城镇化率 Top10 —— 城市化水平
-- 结论：渝中区100%全境城市化，主城核心区97%以上
-- ============================================================
SELECT district AS 区县,
       urban_rate_pct AS 城镇化率_pct,
       ROUND(pop_wan, 1) AS 人口_万
FROM district_economy
ORDER BY urban_rate_pct DESC
LIMIT 10;

-- ============================================================
-- 分析6：三大板块经济差异
-- 主城都市区21区 / 渝东北11县 / 渝东南6县（官方功能区划分）
-- 结论：主城都市区平均人均GDP约为渝东北的1.8倍，区域发展不均衡
-- ============================================================
SELECT CASE
         WHEN district IN ('渝中区','大渡口区','江北区','沙坪坝区','九龙坡区','南岸区','北碚区','渝北区','巴南区','涪陵区','长寿区','江津区','合川区','永川区','南川区','綦江区','大足区','璧山区','铜梁区','潼南区','荣昌区') THEN '主城都市区'
         WHEN district IN ('万州区','开州区','梁平区','城口县','丰都县','垫江县','忠县','云阳县','奉节县','巫山县','巫溪县') THEN '渝东北'
         ELSE '渝东南'
       END AS 板块,
       COUNT(*)              AS 区县数,
       ROUND(AVG(per_capita_yuan))   AS 平均人均GDP_元,
       ROUND(AVG(urban_rate_pct), 1) AS 平均城镇化率_pct
FROM district_economy
GROUP BY 板块
ORDER BY 平均人均GDP_元 DESC;
