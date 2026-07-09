USE SocomDataWarehouse;
GO

CREATE OR ALTER PROCEDURE gold.sp_load_gold
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @start DATETIME = GETDATE();

    PRINT '====================================================';
    PRINT '[Gold] sp_load_gold START: ' + CONVERT(VARCHAR, @start, 120);
    PRINT '====================================================';

    BEGIN TRY
        BEGIN TRAN;

        -- 1) Dim_Region
        MERGE gold.Dim_Region AS tgt
        USING (
            SELECT DISTINCT
                LTRIM(RTRIM(
                    CASE
                        WHEN CHARINDEX(NCHAR(8211), branch) > 0 THEN LEFT(branch, CHARINDEX(NCHAR(8211), branch) - 1)
                        WHEN CHARINDEX('-',  branch) > 0 THEN LEFT(branch, CHARINDEX('-',  branch) - 1)
                        ELSE branch
                    END
                )) AS region_name
            FROM silver.Transaction_Data
            WHERE branch IS NOT NULL
        ) AS src
        ON tgt.region_name = src.region_name
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (region_name) VALUES (src.region_name);

        -- 2) Dim_Province
        MERGE gold.Dim_Province AS tgt
        USING (
            SELECT DISTINCT
                t.province AS province_name,
                r.region_id
            FROM silver.Transaction_Data t
            JOIN gold.Dim_Region r
              ON r.region_name = LTRIM(RTRIM(
                    CASE
                        WHEN CHARINDEX(NCHAR(8211), t.branch) > 0 THEN LEFT(t.branch, CHARINDEX(NCHAR(8211), t.branch) - 1)
                        WHEN CHARINDEX('-',  t.branch) > 0 THEN LEFT(t.branch, CHARINDEX('-',  t.branch) - 1)
                        ELSE t.branch
                    END
              ))
            WHERE t.province IS NOT NULL
        ) AS src
        ON tgt.province_name = src.province_name AND tgt.region_id = src.region_id
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (province_name, region_id) VALUES (src.province_name, src.region_id);

        -- 3) Dim_District
        MERGE gold.Dim_District AS tgt
        USING (
            SELECT DISTINCT
                t.district AS district_name,
                p.province_id
            FROM silver.Transaction_Data t
            JOIN gold.Dim_Province p
              ON p.province_name = t.province
            WHERE t.district IS NOT NULL
              AND t.province IS NOT NULL
        ) AS src
        ON tgt.district_name = src.district_name AND tgt.province_id = src.province_id
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (district_name, province_id) VALUES (src.district_name, src.province_id);

        -- 4) Dim_Customer
        MERGE gold.Dim_Customer AS tgt
        USING (
            SELECT
                LTRIM(RTRIM(customer_email)) AS customer_email,
                MAX(LTRIM(RTRIM(customer))) AS customer_name
            FROM silver.Transaction_Data
            WHERE customer_email IS NOT NULL
              AND LEN(LTRIM(RTRIM(customer_email))) > 0
              AND LTRIM(RTRIM(customer_email)) <> N'--'
            GROUP BY LTRIM(RTRIM(customer_email))
        ) AS src
        ON tgt.customer_email = src.customer_email
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (customer_email, customer_name) VALUES (src.customer_email, src.customer_name)
        WHEN MATCHED AND ISNULL(tgt.customer_name, N'') <> ISNULL(src.customer_name, N'') THEN
            UPDATE SET customer_name = src.customer_name;

        -- 5) Dim_Manufacturer
        MERGE gold.Dim_Manufacturer AS tgt
        USING (
            SELECT DISTINCT manufacturer AS manufacturer_name
            FROM silver.Transaction_Data
            WHERE manufacturer IS NOT NULL
              AND manufacturer <> N'--'
        ) AS src
        ON tgt.manufacturer_name = src.manufacturer_name
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (manufacturer_name) VALUES (src.manufacturer_name);

        -- 6) Dim_Category
        MERGE gold.Dim_Category AS tgt
        USING (
            SELECT DISTINCT product_category AS category_name
            FROM silver.Transaction_Data
            WHERE product_category IS NOT NULL
        ) AS src
        ON tgt.category_name = src.category_name
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (category_name) VALUES (src.category_name);

        -- 7) Dim_Date (insert missing days only)
        ;WITH
        digits(n) AS (
            SELECT n FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS d(n)
        ),
        series(n) AS (
            SELECT a.n + b.n*10 + c.n*100 + d.n*1000
            FROM digits a
            CROSS JOIN digits b
            CROSS JOIN digits c
            CROSS JOIN digits d
        ),
        bounds AS (
            SELECT MIN([date]) AS min_date, MAX([date]) AS max_date
            FROM silver.Transaction_Data
            WHERE [date] IS NOT NULL
        ),
        calendar AS (
            SELECT DATEADD(DAY, s.n, b.min_date) AS [date]
            FROM series s
            CROSS JOIN bounds b
            WHERE DATEADD(DAY, s.n, b.min_date) <= b.max_date
        )
        INSERT INTO gold.Dim_Date (
            date_id, [date], [year], [quarter], quarter_name, [month], month_name, [day], week_day, week_day_name
        )
        SELECT
            CAST(FORMAT(c.[date], 'yyyyMMdd') AS INT) AS date_id,
            c.[date],
            YEAR(c.[date]) AS [year],
            DATEPART(QUARTER, c.[date]) AS [quarter],
            CONCAT(N'Q', DATEPART(QUARTER, c.[date])) AS quarter_name,
            MONTH(c.[date]) AS [month],
            DATENAME(MONTH, c.[date]) AS month_name,
            DAY(c.[date]) AS [day],
            DATEPART(WEEKDAY, c.[date]) AS week_day,
            DATENAME(WEEKDAY, c.[date]) AS week_day_name
        FROM calendar c
        WHERE NOT EXISTS (
            SELECT 1
            FROM gold.Dim_Date d
            WHERE d.[date] = c.[date]
        );

        -- 8) Dim_Product
        MERGE gold.Dim_Product AS tgt
        USING (
            SELECT
                t.product_name,
                ISNULL(t.version, N'') AS version,
                c.category_id,
                m.manufacturer_id,
                ROW_NUMBER() OVER (
                    PARTITION BY t.product_name, ISNULL(t.version, N'')
                    ORDER BY COUNT(*) DESC
                ) AS rn
            FROM silver.Transaction_Data t
            JOIN gold.Dim_Category c ON c.category_name = t.product_category
            JOIN gold.Dim_Manufacturer m ON m.manufacturer_name = t.manufacturer
            WHERE t.quantity > 0
              AND t.revenue > 0
              AND t.manufacturer <> N'--'
            GROUP BY t.product_name, ISNULL(t.version, N''), c.category_id, m.manufacturer_id
        ) AS src
        ON tgt.product_name = src.product_name
           AND tgt.version = src.version
        WHEN NOT MATCHED BY TARGET AND src.rn = 1 THEN
            INSERT (product_name, version, category_id, manufacturer_id)
            VALUES (src.product_name, src.version, src.category_id, src.manufacturer_id)
        WHEN MATCHED AND src.rn = 1 AND (
               tgt.category_id <> src.category_id
            OR tgt.manufacturer_id <> src.manufacturer_id
        ) THEN
            UPDATE SET
                category_id = src.category_id,
                manufacturer_id = src.manufacturer_id;

        -- 9) Dim_Order
        MERGE gold.Dim_Order AS tgt
        USING (
            SELECT
                t.order_id,
                CAST(FORMAT(t.[date], 'yyyyMMdd') AS INT) AS date_id,
                c.customer_id,
                dd.district_id,
                t.traffic_source,
                t.order_status,
                t.payment_method
            FROM (
                SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY product_name) AS rn
                FROM silver.Transaction_Data
                WHERE order_id IS NOT NULL
            ) t
            LEFT JOIN gold.Dim_Customer c ON c.customer_email = t.customer_email
            OUTER APPLY (
                SELECT TOP 1 d.district_id
                FROM gold.Dim_District d
                JOIN gold.Dim_Province p
                  ON p.province_id = d.province_id
                WHERE d.district_name = t.district
                  AND p.province_name = t.province
                ORDER BY d.district_id
            ) dd
            WHERE t.rn = 1
        ) AS src
        ON tgt.order_id = src.order_id
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (order_id, date_id, customer_id, district_id, traffic_source, order_status, payment_method)
            VALUES (src.order_id, src.date_id, src.customer_id, src.district_id, src.traffic_source, src.order_status, src.payment_method)
        WHEN MATCHED AND (
               tgt.date_id <> src.date_id
            OR ISNULL(tgt.customer_id, -1) <> ISNULL(src.customer_id, -1)
            OR ISNULL(tgt.district_id, -1) <> ISNULL(src.district_id, -1)
            OR ISNULL(tgt.traffic_source, N'') <> ISNULL(src.traffic_source, N'')
            OR ISNULL(tgt.order_status, N'') <> ISNULL(src.order_status, N'')
            OR ISNULL(tgt.payment_method, N'') <> ISNULL(src.payment_method, N'')
        ) THEN
            UPDATE SET
                date_id = src.date_id,
                customer_id = src.customer_id,
                district_id = src.district_id,
                traffic_source = src.traffic_source,
                order_status = src.order_status,
                payment_method = src.payment_method;

        -- 10) Dim_Gift
        MERGE gold.Dim_Gift AS tgt
        USING (
            SELECT DISTINCT gift_name
            FROM silver.Gift_Data
            WHERE gift_name IS NOT NULL
              AND LEN(LTRIM(RTRIM(gift_name))) > 0
        ) AS src
        ON tgt.gift_name = src.gift_name
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (gift_name) VALUES (src.gift_name);

        -- 11) Fact_OrderLine (full refresh)
        TRUNCATE TABLE gold.Fact_OrderLine;

        INSERT INTO gold.Fact_OrderLine (order_id, product_id, quantity, revenue, discount_amount, amount_received)
        SELECT
            t.order_id,
            p.product_id,
            t.quantity,
            t.revenue,
            t.discount_amount,
            t.amount_received
        FROM silver.Transaction_Data t
        JOIN gold.Dim_Product p
          ON p.product_name = t.product_name
         AND p.version = ISNULL(t.version, N'')
        JOIN gold.Dim_Order o
          ON o.order_id = t.order_id;

        -- 12) Fact_Gift (full refresh)
        TRUNCATE TABLE gold.Fact_Gift;

        INSERT INTO gold.Fact_Gift (order_id, gift_id)
        SELECT
            g.order_id,
            dg.gift_id
        FROM silver.Gift_Data g
        JOIN gold.Dim_Gift dg ON dg.gift_name = g.gift_name
        JOIN gold.Dim_Order o ON o.order_id = g.order_id;

        -- 13) MBA kept as VIEW only (no materialized table)

        COMMIT TRAN;

        PRINT '====================================================';
        PRINT '[Gold] COMPLETED in ' + CAST(DATEDIFF(SECOND, @start, GETDATE()) AS VARCHAR) + 's';
        PRINT '====================================================';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        PRINT '!!! [Gold] ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO


