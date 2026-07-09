-- ============================================================
-- Bronze/check_bronze_quality.sql
-- Kiểm tra chất lượng dữ liệu Bronze trước khi thiết kế Silver
-- Mục tiêu: Phát hiện các vấn đề cần xử lý ở Silver layer
-- Chạy thủ công sau EXEC bronze.sp_load_bronze;
-- ============================================================

USE SocomDataWarehouse;
GO

PRINT '====================================================';
PRINT ' BRONZE DATA QUALITY CHECKS';
PRINT ' Run time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '====================================================';

-- ============================================================
-- 1. ROW COUNT — Kiểm tra số dòng nạp vào Bronze
-- ============================================================
PRINT '';
PRINT '--- [1] ROW COUNT ---';

SELECT 'Transaction_Data' AS [table], COUNT(*) AS row_count FROM bronze.Transaction_Data
UNION ALL
SELECT 'Gift_Data',                   COUNT(*)              FROM bronze.Gift_Data
UNION ALL
SELECT 'Shipping_Data',               COUNT(*)              FROM bronze.Shipping_Data;

-- ============================================================
-- 2. NULL CHECK — Các cột quan trọng
--    → Quyết định: cột nào cần WHERE IS NOT NULL ở Silver?
-- ============================================================
PRINT '';
PRINT '--- [2] NULL CHECK: Critical columns ---';
PRINT '  Cột có null_count > 0 → cần filter ở Silver';

SELECT 'order_id'         AS column_name, COUNT(*) AS null_count FROM bronze.Transaction_Data WHERE order_id IS NULL
UNION ALL
SELECT 'date',                            COUNT(*)              FROM bronze.Transaction_Data WHERE [date] IS NULL
UNION ALL
SELECT 'product_name',                    COUNT(*)              FROM bronze.Transaction_Data WHERE product_name IS NULL OR LEN(LTRIM(RTRIM(product_name))) = 0
UNION ALL
SELECT 'customer_email',                  COUNT(*)              FROM bronze.Transaction_Data WHERE customer_email IS NULL OR LEN(LTRIM(RTRIM(customer_email))) = 0
UNION ALL
SELECT 'product_category',               COUNT(*)              FROM bronze.Transaction_Data WHERE product_category IS NULL OR LEN(LTRIM(RTRIM(product_category))) = 0
UNION ALL
SELECT 'order_status',                   COUNT(*)              FROM bronze.Transaction_Data WHERE order_status IS NULL OR LEN(LTRIM(RTRIM(order_status))) = 0
UNION ALL
SELECT 'revenue',                         COUNT(*)              FROM bronze.Transaction_Data WHERE revenue IS NULL
UNION ALL
SELECT 'quantity',                        COUNT(*)              FROM bronze.Transaction_Data WHERE quantity IS NULL
UNION ALL
SELECT 'manufacturer',                   COUNT(*)              FROM bronze.Transaction_Data WHERE manufacturer IS NULL OR LEN(LTRIM(RTRIM(manufacturer))) = 0
UNION ALL
SELECT 'district',                        COUNT(*)              FROM bronze.Transaction_Data WHERE district IS NULL OR LEN(LTRIM(RTRIM(district))) = 0
UNION ALL
SELECT 'province',                        COUNT(*)              FROM bronze.Transaction_Data WHERE province IS NULL OR LEN(LTRIM(RTRIM(province))) = 0;

-- ============================================================
-- 3. WHITESPACE CHECK — Cột text có khoảng trắng thừa không?
--    → Quyết định: cột nào cần LTRIM/RTRIM ở Silver?
-- ============================================================
PRINT '';
PRINT '--- [3] WHITESPACE CHECK: LTRIM/RTRIM cần thiết ---';
PRINT '  dirty_count > 0 → cần LTRIM/RTRIM ở Silver';

SELECT 'product_name'   AS column_name, COUNT(*) AS dirty_count FROM bronze.Transaction_Data WHERE product_name     <> LTRIM(RTRIM(product_name))
UNION ALL
SELECT 'manufacturer',                  COUNT(*)              FROM bronze.Transaction_Data WHERE manufacturer      <> LTRIM(RTRIM(manufacturer))
UNION ALL
SELECT 'customer',                      COUNT(*)              FROM bronze.Transaction_Data WHERE customer           <> LTRIM(RTRIM(customer))
UNION ALL
SELECT 'customer_email',               COUNT(*)              FROM bronze.Transaction_Data WHERE customer_email     <> LTRIM(RTRIM(customer_email))
UNION ALL
SELECT 'product_category',             COUNT(*)              FROM bronze.Transaction_Data WHERE product_category   <> LTRIM(RTRIM(product_category))
UNION ALL
SELECT 'order_status',                 COUNT(*)              FROM bronze.Transaction_Data WHERE order_status       <> LTRIM(RTRIM(order_status))
UNION ALL
SELECT 'traffic_source',               COUNT(*)              FROM bronze.Transaction_Data WHERE traffic_source     <> LTRIM(RTRIM(traffic_source))
UNION ALL
SELECT 'branch',                        COUNT(*)              FROM bronze.Transaction_Data WHERE branch             <> LTRIM(RTRIM(branch))
UNION ALL
SELECT 'district',                      COUNT(*)              FROM bronze.Transaction_Data WHERE district           <> LTRIM(RTRIM(district))
UNION ALL
SELECT 'province',                      COUNT(*)              FROM bronze.Transaction_Data WHERE province           <> LTRIM(RTRIM(province))
UNION ALL
SELECT 'version',                       COUNT(*)              FROM bronze.Transaction_Data WHERE version            <> LTRIM(RTRIM(version));

-- ============================================================
-- 4. DUPLICATE CHECK — Trùng ở Bronze là lỗi ETL hay nghiệp vụ?
--    → Quyết định: cần ROW_NUMBER() dedup ở Silver?
-- ============================================================
PRINT '';
PRINT '--- [4] DUPLICATE CHECK ---';

-- 4a. Trùng theo (order_id, product_name) — grain mong đợi
SELECT
    'duplicate_pairs (order_id + product_name)' AS metric,
    COUNT(*)                                     AS metric_value
FROM (
    SELECT order_id, product_name
    FROM bronze.Transaction_Data
    WHERE order_id IS NOT NULL
    GROUP BY order_id, product_name
    HAVING COUNT(*) > 1
) pairs
UNION ALL
SELECT
    'duplicate_extra_rows (order_id + product_name)',
    ISNULL(SUM(cnt - 1), 0)
FROM (
    SELECT COUNT(*) AS cnt
    FROM bronze.Transaction_Data
    WHERE order_id IS NOT NULL
    GROUP BY order_id, product_name
    HAVING COUNT(*) > 1
) extra
UNION ALL
-- 4b. Trùng hoàn toàn tất cả cột (exact duplicate → lỗi ETL)
SELECT
    'exact_duplicate_extra_rows (full record)',
    ISNULL(SUM(cnt - 1), 0)
FROM (
    SELECT COUNT(*) AS cnt
    FROM bronze.Transaction_Data
    GROUP BY
        manufacturer, customer, customer_email, [date],
        traffic_source, branch, product_category,
        province, order_id, product_name, district,
        version, order_status, payment_method,
        revenue, discount_amount, total_invoice,
        amount_received, quantity, shipping_fee
    HAVING COUNT(*) > 1
) exact_extra;

-- ============================================================
-- 5. DATA RANGE CHECK — Giá trị số có hợp lệ không?
--    → Quyết định: cần CASE WHEN hoặc ISNULL ở Silver?
-- ============================================================
PRINT '';
PRINT '--- [5] DATA RANGE CHECK ---';
PRINT '  invalid_count > 0 → cần xử lý ở Silver';

SELECT 'revenue < 0'              AS issue, COUNT(*) AS invalid_count FROM bronze.Transaction_Data WHERE revenue < 0
UNION ALL
SELECT 'revenue = 0',                        COUNT(*)                 FROM bronze.Transaction_Data WHERE revenue = 0
UNION ALL
SELECT 'quantity <= 0',                      COUNT(*)                 FROM bronze.Transaction_Data WHERE quantity <= 0
UNION ALL
SELECT 'quantity IS NULL',                   COUNT(*)                 FROM bronze.Transaction_Data WHERE quantity IS NULL
UNION ALL
SELECT 'discount_amount > 0 (unexpected)',   COUNT(*)                 FROM bronze.Transaction_Data WHERE discount_amount > 0
UNION ALL
SELECT 'total_invoice < 0',                  COUNT(*)                 FROM bronze.Transaction_Data WHERE total_invoice < 0
UNION ALL
SELECT 'amount_received < 0',                COUNT(*)                 FROM bronze.Transaction_Data WHERE amount_received < 0
UNION ALL
SELECT 'shipping_fee < 0 (bronze)',          COUNT(*)                 FROM bronze.Shipping_Data    WHERE shipping_fee < 0;

-- ============================================================
-- 6. DATE CHECK — Ngày có hợp lệ không?
--    → Quyết định: có cần filter date IS NOT NULL ở Silver?
-- ============================================================
PRINT '';
PRINT '--- [6] DATE RANGE CHECK ---';

SELECT
    MIN([date])              AS earliest_date,
    MAX([date])              AS latest_date,
    COUNT(DISTINCT [date])   AS distinct_dates,
    SUM(CASE WHEN [date] IS NULL THEN 1 ELSE 0 END) AS null_dates,
    DATEDIFF(DAY, MIN([date]), MAX([date])) AS date_span_days
FROM bronze.Transaction_Data;

-- ============================================================
-- 7. CARDINALITY CHECK — Số lượng giá trị distinct mỗi cột
--    → Quyết định: cột nào sẽ thành Dimension? Có bất thường không?
-- ============================================================
PRINT '';
PRINT '--- [7] CARDINALITY CHECK: Số giá trị distinct ---';

SELECT 'order_id'         AS column_name, COUNT(DISTINCT order_id)         AS distinct_values FROM bronze.Transaction_Data
UNION ALL
SELECT 'product_name',                    COUNT(DISTINCT product_name)     FROM bronze.Transaction_Data
UNION ALL
SELECT 'customer_email',                  COUNT(DISTINCT customer_email)   FROM bronze.Transaction_Data
UNION ALL
SELECT 'product_category',               COUNT(DISTINCT product_category) FROM bronze.Transaction_Data
UNION ALL
SELECT 'manufacturer',                   COUNT(DISTINCT manufacturer)     FROM bronze.Transaction_Data
UNION ALL
SELECT 'order_status',                   COUNT(DISTINCT order_status)     FROM bronze.Transaction_Data
UNION ALL
SELECT 'traffic_source',                 COUNT(DISTINCT traffic_source)   FROM bronze.Transaction_Data
UNION ALL
SELECT 'payment_method',                 COUNT(DISTINCT payment_method)   FROM bronze.Transaction_Data
UNION ALL
SELECT 'province',                        COUNT(DISTINCT province)         FROM bronze.Transaction_Data
UNION ALL
SELECT 'district',                        COUNT(DISTINCT district)         FROM bronze.Transaction_Data
UNION ALL
SELECT 'version',                         COUNT(DISTINCT version)          FROM bronze.Transaction_Data;

-- ============================================================
-- 8. CATEGORY DISTRIBUTION — Có tên danh mục lạ/viết sai không?
--    → Quyết định: cần REPLACE/CASE WHEN chuẩn hóa tên ở Silver?
-- ============================================================
PRINT '';
PRINT '--- [8] CATEGORY DISTRIBUTION ---';
PRINT '  Kiểm tra tên bất thường, viết hoa/thường không nhất quán';

SELECT
    product_category,
    COUNT(*)                                                                    AS row_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))            AS pct
FROM bronze.Transaction_Data
GROUP BY product_category
ORDER BY row_count DESC;

-- ============================================================
-- 9. ORDER STATUS DISTRIBUTION
--    → Quyết định: các status hợp lệ cần whitelist ở Silver?
-- ============================================================
PRINT '';
PRINT '--- [9] ORDER STATUS DISTRIBUTION ---';

SELECT
    order_status,
    COUNT(*)                                                                    AS row_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))            AS pct
FROM bronze.Transaction_Data
GROUP BY order_status
ORDER BY row_count DESC;

-- ============================================================
-- 10. TRAFFIC SOURCE DISTRIBUTION
-- ============================================================
PRINT '';
PRINT '--- [10] TRAFFIC SOURCE DISTRIBUTION ---';

SELECT
    traffic_source,
    COUNT(*)                                                                    AS row_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))            AS pct
FROM bronze.Transaction_Data
GROUP BY traffic_source
ORDER BY row_count DESC;

-- ============================================================
-- 11. MANUFACTURER — Kiểm tra giá trị đặc biệt ('--', NULL, rỗng)
--    → Quyết định: cần filter manufacturer <> '--' ở Dim_Product?
-- ============================================================
PRINT '';
PRINT '--- [11] MANUFACTURER: Giá trị đặc biệt ---';

SELECT
    manufacturer,
    COUNT(*) AS row_count
FROM bronze.Transaction_Data
WHERE manufacturer IS NULL
   OR LEN(LTRIM(RTRIM(manufacturer))) = 0
   OR manufacturer = N'--'
GROUP BY manufacturer
ORDER BY row_count DESC;

-- Tổng số distinct manufacturer hợp lệ
SELECT COUNT(DISTINCT manufacturer) AS valid_manufacturers
FROM bronze.Transaction_Data
WHERE manufacturer IS NOT NULL
  AND LEN(LTRIM(RTRIM(manufacturer))) > 0
  AND manufacturer <> N'--';

-- ============================================================
-- 12. REFERENTIAL INTEGRITY — Gift/Shipping → Transaction
--    → Quyết định: có orphan order_id cần filter ở Silver?
-- ============================================================
PRINT '';
PRINT '--- [12] REFERENTIAL INTEGRITY: Gift & Shipping → Transaction ---';
PRINT '  orphan_count > 0 → cần xem xét filter ở Silver';

SELECT
    'Gift_Data orphan order_id'     AS issue,
    COUNT(*)                        AS orphan_count
FROM bronze.Gift_Data g
WHERE NOT EXISTS (
    SELECT 1 FROM bronze.Transaction_Data t WHERE t.order_id = g.order_id
)
UNION ALL
SELECT
    'Shipping_Data orphan order_id',
    COUNT(*)
FROM bronze.Shipping_Data s
WHERE NOT EXISTS (
    SELECT 1 FROM bronze.Transaction_Data t WHERE t.order_id = s.order_id
);

-- ============================================================
-- 13. TOTAL_INVOICE FORMULA CHECK
--    → Xác nhận: total_invoice = revenue + discount_amount?
--    → Quyết định: có bỏ total_invoice ở Gold không?
-- ============================================================
PRINT '';
PRINT '--- [13] TOTAL_INVOICE FORMULA CHECK ---';
PRINT '  Kỳ vọng: formula_match ≈ 100%, mismatch chỉ do làm tròn';

SELECT
    COUNT(*)                                                                AS total_rows,
    SUM(CASE WHEN ABS(total_invoice - (revenue + discount_amount)) < 1
             THEN 1 ELSE 0 END)                                            AS formula_match,
    SUM(CASE WHEN ABS(total_invoice - (revenue + discount_amount)) >= 1
             THEN 1 ELSE 0 END)                                            AS formula_mismatch,
    MAX(ABS(total_invoice - (revenue + discount_amount)))                  AS max_diff
FROM bronze.Transaction_Data
WHERE revenue IS NOT NULL AND total_invoice IS NOT NULL;

PRINT '';
PRINT '====================================================';
PRINT ' BRONZE QUALITY CHECK COMPLETE';
PRINT ' → Xem kết quả để quyết định transformation ở Silver';
PRINT '====================================================';
