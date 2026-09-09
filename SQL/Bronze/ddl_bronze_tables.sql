USE SocomDataWarehouse;
GO

-- ============================================================
-- Bronze physical tables — DROP & CREATE.
-- Chạy lại file này là làm mới hoàn toàn schema Bronze.
-- Bronze luôn được nạp lại từ CSV (sp_load_bronze) nên drop không mất gì.
-- ============================================================

DROP TABLE IF EXISTS bronze.Transaction_Data;
GO
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
    shipping_fee     INT,
    sub_category     NVARCHAR(100)
);
GO

DROP TABLE IF EXISTS bronze.Gift_Data;
GO
CREATE TABLE bronze.Gift_Data (
    order_id  INT           NOT NULL,
    gift_name NVARCHAR(255) NOT NULL
);
GO

DROP TABLE IF EXISTS bronze.Shipping_Data;
GO
CREATE TABLE bronze.Shipping_Data (
    order_id     INT NOT NULL,
    shipping_fee INT NOT NULL
);
GO
