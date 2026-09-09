-- ============================================================
-- Bronze/sp_load_bronze.sql
-- Stored Procedure: Load raw CSV data vào Bronze layer
-- Pattern: Truncate & Insert | Không có transformation
--
-- Gọi:
--   EXEC bronze.sp_load_bronze;                        -- dùng thư mục mặc định
--   EXEC bronze.sp_load_bronze @data_dir = N'E:\...\Cleaned_Data';  -- override
-- ============================================================

USE SocomDataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.sp_load_bronze
    @data_dir NVARCHAR(4000) = NULL   -- thư mục chứa *.csv; NULL = dùng DEFAULT_DIR bên dưới
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start    DATETIME = GETDATE();
    DECLARE @rowcount INT;
    DECLARE @sql      NVARCHAR(MAX);

    -- >>> Sửa 1 chỗ này nếu đổi máy / đổi vị trí project <<<
    DECLARE @DEFAULT_DIR NVARCHAR(4000) =
        N'D:\Data Self Learning\Tran Hoang Long _ Data Analyst Course\Data Analyst\Market basket Association\Cleaned_Data';

    IF @data_dir IS NULL OR LEN(LTRIM(RTRIM(@data_dir))) = 0
        SET @data_dir = @DEFAULT_DIR;
    SET @data_dir = LTRIM(RTRIM(@data_dir));
    IF RIGHT(@data_dir, 1) <> N'\'
        SET @data_dir = @data_dir + N'\';

    PRINT '====================================================';
    PRINT '[Bronze] sp_load_bronze START: ' + CONVERT(VARCHAR, @start, 120);
    PRINT '[Bronze] data_dir = ' + @data_dir;
    PRINT '====================================================';

    BEGIN TRY

        -- DDL tách riêng: SQL/Bronze/ddl_bronze_tables.sql
        IF OBJECT_ID('bronze.Transaction_Data', 'U') IS NULL
           OR OBJECT_ID('bronze.Gift_Data', 'U') IS NULL
           OR OBJECT_ID('bronze.Shipping_Data', 'U') IS NULL
        BEGIN
            THROW 51001, 'Bronze tables are missing. Run SQL/Bronze/ddl_bronze_tables.sql first.', 1;
        END

        -- CSV do notebook (pandas trên Windows) sinh ra: UTF-8 BOM + xuống dòng CRLF
        -- -> ROWTERMINATOR = '0x0d0a' (không dùng '\n' vì '\r' thừa lọt vào cột cuối, RTRIM không xóa được)
        -- Các tùy chọn BULK INSERT dùng chung cho cả 3 file:
        DECLARE @opts NVARCHAR(400) =
            N'WITH (FIRSTROW = 2, FIELDTERMINATOR = '','', ROWTERMINATOR = ''0x0d0a'', TABLOCK, CODEPAGE = ''65001'', FORMAT = ''CSV'')';

        -- ------------------------------------------------
        -- 1. Transaction_Data
        -- ------------------------------------------------
        PRINT '>> Loading bronze.Transaction_Data...';
        TRUNCATE TABLE bronze.Transaction_Data;

        SET @sql = N'BULK INSERT bronze.Transaction_Data FROM ''' + @data_dir + N'Transaction_Data.csv'' ' + @opts + N';';
        EXEC sp_executesql @sql;
        SET @rowcount = @@ROWCOUNT;
        PRINT '   bronze.Transaction_Data loaded: ' + CAST(@rowcount AS VARCHAR) + ' rows';

        -- ------------------------------------------------
        -- 2. Gift_Data
        -- ------------------------------------------------
        PRINT '>> Loading bronze.Gift_Data...';
        TRUNCATE TABLE bronze.Gift_Data;

        SET @sql = N'BULK INSERT bronze.Gift_Data FROM ''' + @data_dir + N'Gift_Data.csv'' ' + @opts + N';';
        EXEC sp_executesql @sql;
        SET @rowcount = @@ROWCOUNT;
        PRINT '   bronze.Gift_Data loaded: ' + CAST(@rowcount AS VARCHAR) + ' rows';

        -- ------------------------------------------------
        -- 3. Shipping_Data
        -- ------------------------------------------------
        PRINT '>> Loading bronze.Shipping_Data...';
        TRUNCATE TABLE bronze.Shipping_Data;

        SET @sql = N'BULK INSERT bronze.Shipping_Data FROM ''' + @data_dir + N'Shipping_Data.csv'' ' + @opts + N';';
        EXEC sp_executesql @sql;
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
