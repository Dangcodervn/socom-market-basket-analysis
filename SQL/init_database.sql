-- ============================================================
-- init_database.sql
-- Chạy MỘT LẦN để khởi tạo database và schemas
-- ============================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SocomDataWarehouse')
BEGIN
    CREATE DATABASE SocomDataWarehouse;
    PRINT 'Database SocomDataWarehouse created.';
END
ELSE
    PRINT 'Database SocomDataWarehouse already exists.';
GO

USE SocomDataWarehouse;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze') EXEC('CREATE SCHEMA bronze');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver') EXEC('CREATE SCHEMA silver');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')   EXEC('CREATE SCHEMA gold');
GO

PRINT 'Schemas ready: bronze | silver | gold';
GO
