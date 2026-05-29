-- ============================================================
-- Silver/sp_load_silver.sql
-- Stored Procedure: Bronze → Silver (Cleaned, Standardized Data)
-- Pattern  : Truncate & Insert
-- Transform: Data Cleansing, Standardization, Derived Columns
-- Data Model: None (as-is) — flat tables, không tạo schema mới
-- Gọi: EXEC silver.sp_load_silver;
-- ============================================================

USE SocomDataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.sp_load_silver
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start    DATETIME = GETDATE();
    DECLARE @rowcount INT;

    PRINT '====================================================';
    PRINT '[Silver] sp_load_silver START: ' + CONVERT(VARCHAR, @start, 120);
    PRINT '====================================================';

    BEGIN TRY

        -- ------------------------------------------------
        -- 1. silver.Transaction_Data
        --    Transformations:
        --    - LTRIM/RTRIM tất cả chuỗi
        --    - Cast số sang DECIMAL(18,2)
        --    - Lọc bỏ bản ghi không có order_id
        --    - Derived columns: order_year, order_month, order_quarter
        -- ------------------------------------------------
        PRINT '>> Building silver.Transaction_Data...';

        IF OBJECT_ID('silver.Transaction_Data', 'U') IS NOT NULL
            TRUNCATE TABLE silver.Transaction_Data;
        ELSE
            CREATE TABLE silver.Transaction_Data (
                manufacturer     NVARCHAR(255),
                customer         NVARCHAR(255),
                customer_email   NVARCHAR(255),
                [date]           DATE,
                order_year       INT,
                order_month      INT,
                order_quarter    INT,
                traffic_source   NVARCHAR(100),
                branch           NVARCHAR(100),
                product_category NVARCHAR(100),
                province         NVARCHAR(100),
                order_id         INT,
                product_name     NVARCHAR(255),
                district         NVARCHAR(100),
                version          NVARCHAR(100),
                order_status     NVARCHAR(100),
                payment_method   NVARCHAR(100),
                revenue          DECIMAL(18,2),
                discount_amount  DECIMAL(18,2),
                total_invoice    DECIMAL(18,2),
                amount_received  DECIMAL(18,2),
                quantity         INT,
                shipping_fee     DECIMAL(18,2)
            );

        INSERT INTO silver.Transaction_Data (
            manufacturer, customer, customer_email,
            [date], order_year, order_month, order_quarter,
            traffic_source, branch, product_category,
            province, order_id, product_name, district,
            version, order_status, payment_method,
            revenue, discount_amount, total_invoice,
            amount_received, quantity, shipping_fee
        )
        SELECT
            LTRIM(RTRIM(manufacturer)),
            LTRIM(RTRIM(customer)),
            LTRIM(RTRIM(customer_email)),
            [date],
            YEAR([date])               AS order_year,
            MONTH([date])              AS order_month,
            DATEPART(QUARTER, [date])  AS order_quarter,
            LTRIM(RTRIM(traffic_source)),
            LTRIM(RTRIM(branch)),
            LTRIM(RTRIM(product_category)),
            LTRIM(RTRIM(province)),
            order_id,
            LTRIM(RTRIM(product_name)),
            LTRIM(RTRIM(district)),
            LTRIM(RTRIM(version)),
            LTRIM(RTRIM(order_status)),
            LTRIM(RTRIM(payment_method)),
            CAST(ISNULL(revenue, 0)         AS DECIMAL(18,2)),
            CAST(ISNULL(discount_amount, 0) AS DECIMAL(18,2)),
            CAST(ISNULL(total_invoice, 0)   AS DECIMAL(18,2)),
            CAST(ISNULL(amount_received, 0) AS DECIMAL(18,2)),
            ISNULL(quantity, 0),
            CAST(ISNULL(shipping_fee, 0)    AS DECIMAL(18,2))
        FROM bronze.Transaction_Data
        WHERE order_id IS NOT NULL;

        SET @rowcount = @@ROWCOUNT;
        PRINT '   silver.Transaction_Data: ' + CAST(@rowcount AS VARCHAR) + ' rows';

        -- ------------------------------------------------
        -- 2. silver.Gift_Data
        --    Transformations: LTRIM/RTRIM, lọc gift_name rỗng
        -- ------------------------------------------------
        PRINT '>> Building silver.Gift_Data...';

        IF OBJECT_ID('silver.Gift_Data', 'U') IS NOT NULL
            TRUNCATE TABLE silver.Gift_Data;
        ELSE
            CREATE TABLE silver.Gift_Data (
                order_id  INT           NOT NULL,
                gift_name NVARCHAR(255) NOT NULL
            );

        INSERT INTO silver.Gift_Data (order_id, gift_name)
        SELECT
            order_id,
            LTRIM(RTRIM(gift_name))
        FROM bronze.Gift_Data
        WHERE order_id IS NOT NULL
          AND LEN(LTRIM(RTRIM(gift_name))) > 0;

        SET @rowcount = @@ROWCOUNT;
        PRINT '   silver.Gift_Data: ' + CAST(@rowcount AS VARCHAR) + ' rows';

        -- ------------------------------------------------
        -- 3. silver.Shipping_Data
        --    Transformations: Cast DECIMAL, lọc shipping_fee âm
        -- ------------------------------------------------
        PRINT '>> Building silver.Shipping_Data...';

        IF OBJECT_ID('silver.Shipping_Data', 'U') IS NOT NULL
            TRUNCATE TABLE silver.Shipping_Data;
        ELSE
            CREATE TABLE silver.Shipping_Data (
                order_id     INT           NOT NULL,
                shipping_fee DECIMAL(18,2) NOT NULL
            );

        INSERT INTO silver.Shipping_Data (order_id, shipping_fee)
        SELECT
            order_id,
            CAST(shipping_fee AS DECIMAL(18,2))
        FROM bronze.Shipping_Data
        WHERE order_id IS NOT NULL
          AND shipping_fee >= 0;

        SET @rowcount = @@ROWCOUNT;
        PRINT '   silver.Shipping_Data: ' + CAST(@rowcount AS VARCHAR) + ' rows';

        PRINT '====================================================';
        PRINT '[Silver] COMPLETED in ' + CAST(DATEDIFF(SECOND, @start, GETDATE()) AS VARCHAR) + 's';
        PRINT '====================================================';

    END TRY
    BEGIN CATCH
        PRINT '!!! [Silver] ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO

