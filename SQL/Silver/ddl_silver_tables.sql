USE SocomDataWarehouse;
GO

-- ============================================================
-- Silver physical tables — DROP & CREATE.
-- Chạy lại file này là làm mới hoàn toàn schema Silver.
-- Silver luôn được nạp lại từ Bronze (sp_load_silver) nên drop không mất gì.
-- ============================================================

DROP TABLE IF EXISTS silver.Transaction_Data;
GO
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
    version          NVARCHAR(100) NOT NULL,   -- sp_load_silver: ISNULL(...,'') -> không bao giờ NULL
    order_status     NVARCHAR(100),
    payment_method   NVARCHAR(100),
    revenue          DECIMAL(18,2),
    discount_amount  DECIMAL(18,2),
    total_invoice    DECIMAL(18,2),
    amount_received  DECIMAL(18,2),
    quantity         INT,
    shipping_fee     DECIMAL(18,2),
    sub_category     NVARCHAR(100)
);
GO

DROP TABLE IF EXISTS silver.Gift_Data;
GO
CREATE TABLE silver.Gift_Data (
    order_id  INT           NOT NULL,
    gift_name NVARCHAR(255) NOT NULL
);
GO

DROP TABLE IF EXISTS silver.Shipping_Data;
GO
CREATE TABLE silver.Shipping_Data (
    order_id     INT           NOT NULL,
    shipping_fee DECIMAL(18,2) NOT NULL
);
GO
