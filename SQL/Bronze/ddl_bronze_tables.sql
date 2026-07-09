USE SocomDataWarehouse;
GO

-- Bronze physical tables (run once or when schema changes)

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
GO

IF OBJECT_ID('bronze.Gift_Data', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.Gift_Data (
        order_id  INT           NOT NULL,
        gift_name NVARCHAR(255) NOT NULL
    );
END
GO

IF OBJECT_ID('bronze.Shipping_Data', 'U') IS NULL
BEGIN
    CREATE TABLE bronze.Shipping_Data (
        order_id     INT NOT NULL,
        shipping_fee INT NOT NULL
    );
END
GO
