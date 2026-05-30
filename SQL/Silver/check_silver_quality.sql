-- ============================================================
-- Silver/check_silver_quality.sql
-- Kiểm tra chất lượng dữ liệu Silver trước khi chạy Gold DDL
-- Chạy thủ công sau EXEC silver.sp_load_silver;
-- ============================================================

USE SocomDataWarehouse;
GO

PRINT '====================================================';
PRINT ' SILVER DATA QUALITY CHECKS';
PRINT ' Run time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '====================================================';

-- ============================================================
-- 1. ROW COUNT — So sánh Silver vs Bronze
-- ============================================================
PRINT '';
PRINT '--- [1] ROW COUNT: Silver vs Bronze ---';

SELECT
    'Transaction_Data' AS [table],
    (SELECT COUNT(*) FROM bronze.Transaction_Data)                    AS bronze_rows,
    (SELECT COUNT(*) FROM silver.Transaction_Data)                    AS silver_rows,
    (SELECT COUNT(*) FROM bronze.Transaction_Data)
      - (SELECT COUNT(*) FROM silver.Transaction_Data)                AS rows_filtered_out;

SELECT
    'Gift_Data' AS [table],
    (SELECT COUNT(*) FROM bronze.Gift_Data)                           AS bronze_rows,
    (SELECT COUNT(*) FROM silver.Gift_Data)                           AS silver_rows,
    (SELECT COUNT(*) FROM bronze.Gift_Data)
      - (SELECT COUNT(*) FROM silver.Gift_Data)                       AS rows_filtered_out;

SELECT
    'Shipping_Data' AS [table],
    (SELECT COUNT(*) FROM bronze.Shipping_Data)                       AS bronze_rows,
    (SELECT COUNT(*) FROM silver.Shipping_Data)                       AS silver_rows,
    (SELECT COUNT(*) FROM bronze.Shipping_Data)
      - (SELECT COUNT(*) FROM silver.Shipping_Data)                   AS rows_filtered_out;

-- ============================================================
-- 2. NULL CHECK — Các cột quan trọng không được NULL
-- ============================================================
PRINT '';
PRINT '--- [2] NULL CHECK: Critical columns ---';
PRINT '  (Kết quả mong đợi: null_count = 0 cho tất cả)';

SELECT 'order_id'       AS column_name, COUNT(*) AS null_count FROM silver.Transaction_Data WHERE order_id IS NULL
UNION ALL
SELECT 'date',                          COUNT(*)              FROM silver.Transaction_Data WHERE [date] IS NULL
UNION ALL
SELECT 'product_name',                  COUNT(*)              FROM silver.Transaction_Data WHERE product_name IS NULL OR LEN(LTRIM(RTRIM(product_name))) = 0
UNION ALL
SELECT 'customer_email',               COUNT(*)              FROM silver.Transaction_Data WHERE customer_email IS NULL OR LEN(LTRIM(RTRIM(customer_email))) = 0
UNION ALL
SELECT 'product_category',             COUNT(*)              FROM silver.Transaction_Data WHERE product_category IS NULL OR LEN(LTRIM(RTRIM(product_category))) = 0
UNION ALL
SELECT 'order_status',                 COUNT(*)              FROM silver.Transaction_Data WHERE order_status IS NULL OR LEN(LTRIM(RTRIM(order_status))) = 0
UNION ALL
SELECT 'traffic_source',               COUNT(*)              FROM silver.Transaction_Data WHERE traffic_source IS NULL OR LEN(LTRIM(RTRIM(traffic_source))) = 0;

-- ============================================================
-- 3. DUPLICATE CHECK — tách rõ duplicate theo cặp và full-record
-- ============================================================
PRINT '';
PRINT '--- [3] DUPLICATE CHECK: order_id + product_name ---';
PRINT '  duplicate_pairs: số cặp (order_id, product_name) bị trùng';
PRINT '  duplicate_extra_rows: tổng số dòng dư = SUM(cnt - 1) theo cặp';
PRINT '  exact_duplicate_extra_rows: tổng số dòng dư khi trùng TOAN BO cot';

WITH pair_counts AS (
    SELECT order_id, product_name, COUNT(*) AS cnt
    FROM silver.Transaction_Data
    GROUP BY order_id, product_name
),
full_row_counts AS (
    SELECT
        manufacturer, customer, customer_email, [date],
        order_year, order_month, order_quarter,
        traffic_source, branch, product_category,
        province, order_id, product_name, district,
        version, order_status, payment_method,
        revenue, discount_amount, total_invoice,
        amount_received, quantity, shipping_fee,
        COUNT(*) AS cnt
    FROM silver.Transaction_Data
    GROUP BY
        manufacturer, customer, customer_email, [date],
        order_year, order_month, order_quarter,
        traffic_source, branch, product_category,
        province, order_id, product_name, district,
        version, order_status, payment_method,
        revenue, discount_amount, total_invoice,
        amount_received, quantity, shipping_fee
)
SELECT 'duplicate_pairs (order_id + product_name)' AS metric,
       COUNT(*) AS metric_value
FROM pair_counts
WHERE cnt > 1
UNION ALL
SELECT 'duplicate_extra_rows (order_id + product_name)',
       ISNULL(SUM(cnt - 1), 0)
FROM pair_counts
WHERE cnt > 1
UNION ALL
SELECT 'exact_duplicate_extra_rows (full record)',
       ISNULL(SUM(cnt - 1), 0)
FROM full_row_counts
WHERE cnt > 1;

-- ============================================================
-- 3b. DUPLICATE PAIR DEEP DIVE — cột nào khác nhau trong các cặp trùng?
--     Mục tiêu: xác định 4,081 dòng dư là do nghiệp vụ hay lỗi dữ liệu
-- ============================================================
PRINT '';
PRINT '--- [3b] DUPLICATE PAIR DEEP DIVE: cot nao khac nhau ---';
PRINT '  count_diff_X: số cặp mà cột X có giá trị khác nhau giữa các dòng';

SELECT
    SUM(CASE WHEN version_diff       = 1 THEN 1 ELSE 0 END) AS count_diff_version,
    SUM(CASE WHEN status_diff        = 1 THEN 1 ELSE 0 END) AS count_diff_order_status,
    SUM(CASE WHEN revenue_diff       = 1 THEN 1 ELSE 0 END) AS count_diff_revenue,
    SUM(CASE WHEN quantity_diff      = 1 THEN 1 ELSE 0 END) AS count_diff_quantity,
    SUM(CASE WHEN discount_diff      = 1 THEN 1 ELSE 0 END) AS count_diff_discount_amount,
    SUM(CASE WHEN invoice_diff       = 1 THEN 1 ELSE 0 END) AS count_diff_total_invoice,
    SUM(CASE WHEN payment_diff       = 1 THEN 1 ELSE 0 END) AS count_diff_payment_method,
    SUM(CASE WHEN traffic_diff       = 1 THEN 1 ELSE 0 END) AS count_diff_traffic_source
FROM (
    SELECT
        order_id,
        product_name,
        CASE WHEN COUNT(DISTINCT version)        > 1 THEN 1 ELSE 0 END AS version_diff,
        CASE WHEN COUNT(DISTINCT order_status)   > 1 THEN 1 ELSE 0 END AS status_diff,
        CASE WHEN COUNT(DISTINCT revenue)        > 1 THEN 1 ELSE 0 END AS revenue_diff,
        CASE WHEN COUNT(DISTINCT quantity)       > 1 THEN 1 ELSE 0 END AS quantity_diff,
        CASE WHEN COUNT(DISTINCT discount_amount)> 1 THEN 1 ELSE 0 END AS discount_diff,
        CASE WHEN COUNT(DISTINCT total_invoice)  > 1 THEN 1 ELSE 0 END AS invoice_diff,
        CASE WHEN COUNT(DISTINCT payment_method) > 1 THEN 1 ELSE 0 END AS payment_diff,
        CASE WHEN COUNT(DISTINCT traffic_source) > 1 THEN 1 ELSE 0 END AS traffic_diff
    FROM silver.Transaction_Data
    GROUP BY order_id, product_name
    HAVING COUNT(*) > 1
) AS pair_diff;

-- ============================================================
-- 4. DATA RANGE CHECK — Số tiền và số lượng hợp lệ
-- ============================================================
PRINT '';
PRINT '--- [4] DATA RANGE CHECK: revenue, quantity ---';
PRINT '  (Kết quả mong đợi: invalid_count = 0)';

SELECT 'revenue < 0'      AS issue, COUNT(*) AS invalid_count FROM silver.Transaction_Data WHERE revenue < 0
UNION ALL
SELECT 'quantity <= 0',              COUNT(*)                 FROM silver.Transaction_Data WHERE quantity <= 0
UNION ALL
SELECT 'total_invoice < 0',          COUNT(*)                 FROM silver.Transaction_Data WHERE total_invoice < 0
UNION ALL
SELECT 'shipping_fee < 0 (silver)',  COUNT(*)                 FROM silver.Shipping_Data    WHERE shipping_fee < 0;

-- ============================================================
-- 5. DERIVED COLUMN CHECK — order_year, order_month, order_quarter
-- ============================================================
PRINT '';
PRINT '--- [5] DERIVED COLUMN CHECK: year/month/quarter ---';
PRINT '  (Kết quả mong đợi: mismatch_count = 0 cho tất cả)';

SELECT
    'order_year mismatch'    AS issue,
    COUNT(*) AS mismatch_count
FROM silver.Transaction_Data
WHERE order_year <> YEAR([date])
UNION ALL
SELECT
    'order_month mismatch',
    COUNT(*)
FROM silver.Transaction_Data
WHERE order_month <> MONTH([date])
UNION ALL
SELECT
    'order_quarter mismatch',
    COUNT(*)
FROM silver.Transaction_Data
WHERE order_quarter <> DATEPART(QUARTER, [date]);

-- ============================================================
-- 6. REFERENTIAL INTEGRITY — Gift/Shipping order_id có trong Transaction
-- ============================================================
PRINT '';
PRINT '--- [6] REFERENTIAL INTEGRITY: Gift & Shipping → Transaction ---';
PRINT '  (Kết quả mong đợi: orphan_count = 0)';

SELECT
    'Gift_Data orphan order_id' AS issue,
    COUNT(*) AS orphan_count
FROM silver.Gift_Data g
WHERE NOT EXISTS (
    SELECT 1 FROM silver.Transaction_Data t WHERE t.order_id = g.order_id
)
UNION ALL
SELECT
    'Shipping_Data orphan order_id',
    COUNT(*)
FROM silver.Shipping_Data s
WHERE NOT EXISTS (
    SELECT 1 FROM silver.Transaction_Data t WHERE t.order_id = s.order_id
);

-- ============================================================
-- 7. CATEGORY DISTRIBUTION — Kiểm tra có category lạ không
-- ============================================================
PRINT '';
PRINT '--- [7] CATEGORY DISTRIBUTION ---';

SELECT
    product_category,
    COUNT(*) AS row_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct
FROM silver.Transaction_Data
GROUP BY product_category
ORDER BY row_count DESC;

-- ============================================================
-- 8. TRAFFIC SOURCE DISTRIBUTION
-- ============================================================
PRINT '';
PRINT '--- [8] TRAFFIC SOURCE DISTRIBUTION ---';

SELECT
    traffic_source,
    COUNT(*) AS row_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct
FROM silver.Transaction_Data
GROUP BY traffic_source
ORDER BY row_count DESC;

-- ============================================================
-- 9. ORDER STATUS DISTRIBUTION
-- ============================================================
PRINT '';
PRINT '--- [9] ORDER STATUS DISTRIBUTION ---';

SELECT
    order_status,
    COUNT(*) AS row_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct
FROM silver.Transaction_Data
GROUP BY order_status
ORDER BY row_count DESC;

-- ============================================================
-- 10. DATE RANGE — Kiểm tra khoảng thời gian dữ liệu
-- ============================================================
PRINT '';
PRINT '--- [10] DATE RANGE ---';

SELECT
    MIN([date])   AS earliest_date,
    MAX([date])   AS latest_date,
    COUNT(DISTINCT [date]) AS distinct_dates,
    DATEDIFF(DAY, MIN([date]), MAX([date])) AS date_span_days
FROM silver.Transaction_Data;

-- ============================================================
-- 11. QUANTITY <= 0 — Phân tích theo order_status
-- ============================================================
PRINT '';
PRINT '--- [11] QUANTITY <= 0: BREAKDOWN BY ORDER_STATUS ---';

SELECT
    order_status,
    COUNT(*)                                                             AS row_count,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))     AS pct
FROM silver.Transaction_Data
WHERE quantity <= 0
GROUP BY order_status
ORDER BY row_count DESC;

-- ============================================================
-- 12. GIFT vs PRODUCT NAME MATCH
--     Kiểm tra gift_name có trùng với product_name không
-- ============================================================
PRINT '';
PRINT '--- [12] GIFT vs PRODUCT NAME MATCH ---';

SELECT
    g.gift_name,
    IIF(p.product_name IS NOT NULL, 'MATCHED', 'NO MATCH') AS status
FROM (SELECT DISTINCT gift_name FROM silver.Gift_Data) g
LEFT JOIN (SELECT DISTINCT product_name FROM silver.Transaction_Data) p
       ON g.gift_name = p.product_name
ORDER BY status, g.gift_name;

-- Tỉ lệ khớp tổng hợp
SELECT
    COUNT(*)                                                        AS total_distinct_gifts,
    SUM(IIF(p.product_name IS NOT NULL, 1, 0))                     AS matched,
    SUM(IIF(p.product_name IS NULL, 1, 0))                         AS no_match,
    CAST(SUM(IIF(p.product_name IS NOT NULL, 1, 0)) * 100.0
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,1))                    AS match_pct
FROM (SELECT DISTINCT gift_name FROM silver.Gift_Data) g
LEFT JOIN (SELECT DISTINCT product_name FROM silver.Transaction_Data) p
       ON g.gift_name = p.product_name;

PRINT '';
PRINT '====================================================';
PRINT ' QUALITY CHECK COMPLETE';
PRINT '====================================================';

-- Tỉ lệ khớp tổng hợp
SELECT
    COUNT(*)                                                        AS total_distinct_gifts,
    SUM(IIF(p.product_name IS NOT NULL, 1, 0))                     AS matched,
    SUM(IIF(p.product_name IS NULL, 1, 0))                         AS no_match,
    CAST(SUM(IIF(p.product_name IS NOT NULL, 1, 0)) * 100.0
         / NULLIF(COUNT(*), 0) AS DECIMAL(5,1))                    AS match_pct,
    IIF(SUM(IIF(p.product_name IS NOT NULL, 1, 0)) * 100.0
        / NULLIF(COUNT(*), 0) >= 80,
        'GỘP vào Dim_Product',
        'GIỮ Dim_Gift RIÊNG')                                      AS recommendation
FROM (SELECT DISTINCT gift_name FROM silver.Gift_Data) g
LEFT JOIN (SELECT DISTINCT product_name FROM silver.Transaction_Data) p
       ON g.gift_name = p.product_name;
