-- ============================================================
-- Bronze/sp_load_bronze.sql
-- Stored Procedure: Load raw CSV data vào Bronze layer
-- Pattern: Truncate & Insert | Không có transformation
-- Gọi: EXEC bronze.sp_load_bronze;
-- ============================================================

USE SocomDataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.sp_load_bronze
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start    DATETIME = GETDATE();
    DECLARE @rowcount INT;

    PRINT '====================================================';
    PRINT '[Bronze] sp_load_bronze START: ' + CONVERT(VARCHAR, @start, 120);
    PRINT '====================================================';

    BEGIN TRY

        -- ------------------------------------------------
        -- 1. Transaction_Data
        -- ------------------------------------------------
        PRINT '>> Loading bronze.Transaction_Data...';

        IF OBJECT_ID('bronze.Transaction_Data', 'U') IS NULL
        BEGIN
            CREATE TABLE bronze.Transaction_Data (
                manufacturer     NVARCHAR(255),
                customer         NVARCHAR(255),
                customer_email   NVARCHAR(255),
                [date]           DATE,
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
                revenue          INT,
                discount_amount  FLOAT,
                total_invoice    FLOAT,
                amount_received  FLOAT,
                quantity         INT,
                shipping_fee     INT
            );
        END

        TRUNCATE TABLE bronze.Transaction_Data;

        BULK INSERT bronze.Transaction_Data
        FROM 'D:\Data Self Learning\Tran Hoang Long _ Data Analyst Course\Data Analyst\Market basket Association\Cleaned_Data\Transaction_Data.csv'
        WITH (
            FIRSTROW       = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR  = '\n',
            TABLOCK,
            CODEPAGE       = '65001',
            FORMAT         = 'CSV'
        );
        SET @rowcount = @@ROWCOUNT;
        PRINT '   bronze.Transaction_Data loaded: ' + CAST(@rowcount AS VARCHAR) + ' rows';

        -- ------------------------------------------------
        -- 2. Gift_Data
        -- ------------------------------------------------
        PRINT '>> Loading bronze.Gift_Data...';

        IF OBJECT_ID('bronze.Gift_Data', 'U') IS NULL
        BEGIN
            CREATE TABLE bronze.Gift_Data (
                order_id  INT           NOT NULL,
                gift_name NVARCHAR(255) NOT NULL
            );
        END

        TRUNCATE TABLE bronze.Gift_Data;

        BULK INSERT bronze.Gift_Data
        FROM 'D:\Data Self Learning\Tran Hoang Long _ Data Analyst Course\Data Analyst\Market basket Association\Cleaned_Data\Gift_Data.csv'
        WITH (
            FIRSTROW        = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR   = '\n',
            TABLOCK,
            CODEPAGE        = '65001',
            FORMAT          = 'CSV'
        );
        SET @rowcount = @@ROWCOUNT;
        PRINT '   bronze.Gift_Data loaded: ' + CAST(@rowcount AS VARCHAR) + ' rows';

        -- ------------------------------------------------
        -- 3. Shipping_Data
        -- ------------------------------------------------
        PRINT '>> Loading bronze.Shipping_Data...';

        IF OBJECT_ID('bronze.Shipping_Data', 'U') IS NULL
        BEGIN
            CREATE TABLE bronze.Shipping_Data (
                order_id     INT NOT NULL,
                shipping_fee INT NOT NULL
            );
        END

        TRUNCATE TABLE bronze.Shipping_Data;

        BULK INSERT bronze.Shipping_Data
        FROM 'D:\Data Self Learning\Tran Hoang Long _ Data Analyst Course\Data Analyst\Market basket Association\Cleaned_Data\Shipping_Data.csv'
        WITH (
            FIRSTROW        = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR   = '\n',
            TABLOCK,
            CODEPAGE        = '65001',
            FORMAT          = 'CSV'
        );
        SET @rowcount = @@ROWCOUNT;
        PRINT '   bronze.Shipping_Data loaded: ' + CAST(@rowcount AS VARCHAR) + ' rows';

        PRINT '====================================================';
        PRINT '[Bronze] COMPLETED in ' + CAST(DATEDIFF(SECOND, @start, GETDATE()) AS VARCHAR) + 's';
        PRINT '====================================================';

    END TRY
    BEGIN CATCH
        PRINT '!!! [Bronze] ERROR: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END;
GO
