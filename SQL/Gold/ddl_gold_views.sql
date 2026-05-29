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
CREATE OR ALTER VIEW gold.Dim_Date AS
SELECT DISTINCT
    [date],
    order_year                               AS [year],
    order_quarter                            AS [quarter],
    CONCAT(N'Q', order_quarter)              AS quarter_name,
    order_month                              AS [month],
    DATENAME(MONTH, [date])                  AS month_name,
    DAY([date])                              AS [day],
    DATEPART(WEEKDAY, [date])                AS week_day,
    DATENAME(WEEKDAY, [date])                AS week_day_name
FROM silver.Transaction_Data
WHERE [date] IS NOT NULL;
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

-- ============================================================
-- AGGREGATION VIEWS
-- ============================================================

-- 10. Agg_Revenue_By_Channel
--     Doanh thu theo kênh bán & thời gian
CREATE OR ALTER VIEW gold.Agg_Revenue_By_Channel AS
SELECT
    order_year,
    CONCAT(N'Q', order_quarter) AS quarter_name,
    order_month                 AS [month],
    DATENAME(MONTH, [date])     AS month_name,
    traffic_source,
    COUNT(DISTINCT order_id)    AS total_orders,
    SUM(quantity)               AS total_quantity,
    SUM(revenue)                AS total_revenue,
    SUM(discount_amount)        AS total_discount,
    SUM(total_invoice)          AS total_invoice
FROM gold.Fact_Transaction
GROUP BY
    order_year, order_quarter, order_month, DATENAME(MONTH, [date]),
    traffic_source;
GO

-- 11. Agg_Revenue_By_Product
--     Doanh thu theo sản phẩm & danh mục
CREATE OR ALTER VIEW gold.Agg_Revenue_By_Product AS
SELECT
    category_name,
    product_name,
    manufacturer_name,
    COUNT(DISTINCT order_id)    AS total_orders,
    SUM(quantity)               AS total_quantity,
    SUM(revenue)                AS total_revenue,
    AVG(revenue)                AS avg_revenue_per_line
FROM gold.Fact_Transaction
GROUP BY category_name, product_name, manufacturer_name;
GO

-- 12. Agg_Revenue_By_Region
--     Doanh thu theo địa lý (Region → Province → District)
CREATE OR ALTER VIEW gold.Agg_Revenue_By_Region AS
SELECT
    LTRIM(RTRIM(
        CASE
            WHEN CHARINDEX(N'–', branch) > 0 THEN LEFT(branch, CHARINDEX(N'–', branch) - 1)
            WHEN CHARINDEX('-',  branch) > 0 THEN LEFT(branch, CHARINDEX('-',  branch) - 1)
            ELSE branch
        END
    ))                          AS region_name,
    province                    AS province_name,
    district                    AS district_name,
    COUNT(DISTINCT order_id)    AS total_orders,
    SUM(revenue)                AS total_revenue,
    SUM(total_invoice)          AS total_invoice
FROM gold.Fact_Transaction
GROUP BY
    LTRIM(RTRIM(CASE
        WHEN CHARINDEX(N'–', branch) > 0 THEN LEFT(branch, CHARINDEX(N'–', branch) - 1)
        WHEN CHARINDEX('-',  branch) > 0 THEN LEFT(branch, CHARINDEX('-',  branch) - 1)
        ELSE branch
    END)),
    province,
    district;
GO

-- 13. Order_Products
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

