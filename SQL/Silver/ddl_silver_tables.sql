USE SocomDataWarehouse;
GO

-- Silver physical tables (run once or when schema changes)

IF OBJECT_ID('silver.Transaction_Data', 'U') IS NULL
BEGIN
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
END
GO

IF OBJECT_ID('silver.Gift_Data', 'U') IS NULL
BEGIN
    CREATE TABLE silver.Gift_Data (
        order_id  INT           NOT NULL,
        gift_name NVARCHAR(255) NOT NULL
    );
END
GO

IF OBJECT_ID('silver.Shipping_Data', 'U') IS NULL
BEGIN
    CREATE TABLE silver.Shipping_Data (
        order_id     INT           NOT NULL,
        shipping_fee DECIMAL(18,2) NOT NULL
    );
END
GO
