-- ============================================================
-- Gold/ddl_gold_views.sql
-- DDL: Tạo tất cả Gold Views (Object Type: Views, No Load)
-- Data Model: Star Schema + Flat Table + Aggregated Table
-- Source: Tất cả derive từ silver.Transaction_Data & silver.Shipping_Data
-- Chạy một lần — views tự cập nhật khi Silver thay đổi
-- ============================================================

USE SocomDataWarehouse;
GO

-- ============================================================
-- DIMENSION VIEWS (Star Schema)
-- Tất cả Dim derive từ silver.Transaction_Data (DISTINCT + natural key)
-- ============================================================

-- 1. Dim_Region
CREATE OR ALTER VIEW gold.Dim_Region AS
SELECT DISTINCT
    LTRIM(RTRIM(
        CASE
            WHEN CHARINDEX(N'–', branch) > 0 THEN LEFT(branch, CHARINDEX(N'–', branch) - 1)
            WHEN CHARINDEX('-',  branch) > 0 THEN LEFT(branch, CHARINDEX('-',  branch) - 1)
            ELSE branch
        END
    )) AS region_name
FROM silver.Transaction_Data
WHERE branch IS NOT NULL;
GO

-- 2. Dim_Province
CREATE OR ALTER VIEW gold.Dim_Province AS
SELECT DISTINCT
    province AS province_name,
    LTRIM(RTRIM(
        CASE
            WHEN CHARINDEX(N'–', branch) > 0 THEN LEFT(branch, CHARINDEX(N'–', branch) - 1)
            WHEN CHARINDEX('-',  branch) > 0 THEN LEFT(branch, CHARINDEX('-',  branch) - 1)
            ELSE branch
        END
    )) AS region_name
FROM silver.Transaction_Data
WHERE province IS NOT NULL;
GO

-- 3. Dim_District
CREATE OR ALTER VIEW gold.Dim_District AS
SELECT DISTINCT
    district AS district_name,
    province AS province_name
FROM silver.Transaction_Data
WHERE district IS NOT NULL AND province IS NOT NULL;
GO

-- 4. Dim_Customer
CREATE OR ALTER VIEW gold.Dim_Customer AS
SELECT DISTINCT
    customer      AS customer_name,
    customer_email
FROM silver.Transaction_Data
WHERE customer_email IS NOT NULL;
GO

-- 5. Dim_Manufacturer
CREATE OR ALTER VIEW gold.Dim_Manufacturer AS
SELECT DISTINCT
    manufacturer AS manufacturer_name
FROM silver.Transaction_Data
WHERE manufacturer IS NOT NULL AND manufacturer <> N'--';
GO

-- 6. Dim_Date
--    Sinh dãy ngày LIÊN TỤC từ MIN → MAX date trong Silver
--    (tránh mất ngày không có giao dịch khi dùng DISTINCT)
--    Dùng tally table (cross join chữ số 0-9) → 0..9999 ngày (~27 năm)
--    Không dùng recursive CTE vì view không cho MAXRECURSION
CREATE OR ALTER VIEW gold.Dim_Date AS
WITH
digits(n) AS (
    SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS t(n)
),
series(n) AS (
    -- Generates 0 … 9,999
    SELECT a.n + b.n*10 + c.n*100 + d.n*1000
    FROM digits a
    CROSS JOIN digits b
    CROSS JOIN digits c
    CROSS JOIN digits d
),
bounds AS (
    SELECT MIN([date]) AS min_date,
           MAX([date]) AS max_date
    FROM silver.Transaction_Data
    WHERE [date] IS NOT NULL
),
calendar AS (
    SELECT DATEADD(DAY, s.n, b.min_date) AS [date]
    FROM series s
    CROSS JOIN bounds b
    WHERE DATEADD(DAY, s.n, b.min_date) <= b.max_date
)
SELECT
    CAST(FORMAT([date], 'yyyyMMdd') AS INT)  AS date_id,
    [date],
    YEAR([date])                             AS [year],
    DATEPART(QUARTER, [date])                AS [quarter],
    CONCAT(N'Q', DATEPART(QUARTER, [date]))  AS quarter_name,
    MONTH([date])                            AS [month],
    DATENAME(MONTH, [date])                  AS month_name,
    DAY([date])                              AS [day],
    DATEPART(WEEKDAY, [date])                AS week_day,
    DATENAME(WEEKDAY, [date])                AS week_day_name
FROM calendar;
GO

-- 7. Dim_Category
CREATE OR ALTER VIEW gold.Dim_Category AS
SELECT DISTINCT
    product_category AS category_name
FROM silver.Transaction_Data
WHERE product_category IS NOT NULL;
GO

-- 8. Dim_Product
--    GROUP BY để tính avg_price trên nhiều giao dịch
CREATE OR ALTER VIEW gold.Dim_Product AS
SELECT
    product_name,
    product_category                                               AS category_name,
    manufacturer                                                   AS manufacturer_name,
    AVG(revenue / NULLIF(CAST(quantity AS DECIMAL(18,2)), 0))      AS avg_price
FROM silver.Transaction_Data
WHERE quantity > 0 AND revenue > 0
  AND manufacturer <> N'--'
GROUP BY product_name, product_category, manufacturer;
GO

-- ============================================================
-- FACT VIEW (Flat Table — trung tâm Star Schema)
-- ============================================================

-- 9. Fact_Transaction
--    Flat view: join Silver.Transaction_Data + Silver.Shipping_Data
--    Bao gồm tất cả natural keys của Dim + measures
CREATE OR ALTER VIEW gold.Fact_Transaction AS
SELECT
    t.order_id,
    CAST(FORMAT(t.[date], 'yyyyMMdd') AS INT) AS date_id,
    t.[date],
    t.order_year,
    t.order_month,
    t.order_quarter,
    t.customer_email,
    t.customer         AS customer_name,
    t.product_name,
    t.product_category AS category_name,
    t.manufacturer     AS manufacturer_name,
    t.district,
    t.province,
    t.branch,
    t.traffic_source,
    t.order_status,
    t.payment_method,
    t.version,
    t.quantity,
    t.revenue,
    t.discount_amount,
    t.total_invoice,
    t.amount_received,
    ISNULL(s.shipping_fee, 0) AS shipping_fee
FROM silver.Transaction_Data t
LEFT JOIN silver.Shipping_Data s ON t.order_id = s.order_id;
GO

-- 10. Order_Products
--     Flat view cho Market Basket Association Analysis
--     Chỉ lấy đơn hàng hoàn thành (bỏ Đã hủy / Hoàn hàng)
CREATE OR ALTER VIEW gold.Order_Products AS
SELECT
    order_id,
    product_name,
    category_name,
    manufacturer_name,
    [date],
    order_year   AS [year],
    DATENAME(MONTH, [date]) AS month_name
FROM gold.Fact_Transaction
WHERE order_status NOT IN (N'Đã hủy', N'Hoàn hàng');
GO

-- ============================================================
-- GIFT VIEWS
-- Tách riêng vì gift_name ≠ product_name (91.7% không khớp):
--   - Quà là hàng mini/sample (20ml, 4.5ml...) không có trong catalog
--   - Quà là phụ kiện (túi tote, băng đô, bình nước, khẩu trang)
--   - Tên viết khác nhau (L'Oreal vs L'ORÉAL)
-- ============================================================

-- 11. Dim_Gift
--     Danh sách tất cả quà tặng (distinct)
--     Nguồn: silver.Gift_Data
CREATE OR ALTER VIEW gold.Dim_Gift AS
SELECT DISTINCT
    gift_name
FROM silver.Gift_Data
WHERE gift_name IS NOT NULL
  AND LEN(LTRIM(RTRIM(gift_name))) > 0;
GO

-- 12. Fact_Gift
--     Map đơn hàng ↔ quà tặng (1 order có thể có nhiều quà)
--     JOIN sang Fact_Transaction trên order_id để phân tích
--     "đơn hàng nào được tặng quà gì"
CREATE OR ALTER VIEW gold.Fact_Gift AS
SELECT
    g.order_id,
    g.gift_name,
    CAST(FORMAT(t.[date], 'yyyyMMdd') AS INT) AS date_id,
    t.[date],
    t.order_year,
    t.order_month,
    t.customer_email,
    t.traffic_source,
    t.branch,
    t.order_status
FROM silver.Gift_Data g
LEFT JOIN silver.Transaction_Data t
       ON g.order_id = t.order_id;
GO

