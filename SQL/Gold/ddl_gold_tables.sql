USE SocomDataWarehouse;
GO

-- ============================================================
-- Gold physical tables — DROP & CREATE.
-- Chạy lại file này RESET toàn bộ surrogate key (IDENTITY) và bảng Gold.
-- Sau khi chạy phải EXEC gold.sp_load_gold để nạp lại dữ liệu.
-- Load hằng ngày dùng sp_load_gold (MERGE) — không đụng file này.
-- ============================================================

-- Drop theo thứ tự phụ thuộc FK (con -> cha)
DROP VIEW  IF EXISTS gold.vw_MBA_SubCategory_Pairs;
DROP VIEW  IF EXISTS gold.vw_MBA_Product_Pairs;
DROP TABLE IF EXISTS gold.Fact_Gift;
DROP TABLE IF EXISTS gold.Fact_OrderLine;
DROP TABLE IF EXISTS gold.Dim_Order;
DROP TABLE IF EXISTS gold.Dim_Product;
DROP TABLE IF EXISTS gold.Dim_Gift;
DROP TABLE IF EXISTS gold.Dim_District;
DROP TABLE IF EXISTS gold.Dim_Province;
DROP TABLE IF EXISTS gold.Dim_Date;
DROP TABLE IF EXISTS gold.Dim_Customer;
DROP TABLE IF EXISTS gold.Dim_Manufacturer;
DROP TABLE IF EXISTS gold.Dim_Category;

-- ============================================================
-- Dimensions (tạo cha trước, con sau)
-- ============================================================

-- Hierarchy địa lý: District -> Province (KHÔNG có Region — branch là kho/gian hàng, không phải vùng).
CREATE TABLE gold.Dim_Province (
    province_id   INT IDENTITY(1,1) PRIMARY KEY,
    province_name NVARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE gold.Dim_District (
    district_id   INT IDENTITY(1,1) PRIMARY KEY,
    district_name NVARCHAR(100) NOT NULL,
    province_id   INT NOT NULL,
    CONSTRAINT UQ_Dim_District UNIQUE (district_name, province_id),
    CONSTRAINT FK_Dim_District_Province FOREIGN KEY (province_id) REFERENCES gold.Dim_Province(province_id)
);
GO

CREATE TABLE gold.Dim_Customer (
    customer_id    INT IDENTITY(1,1) PRIMARY KEY,
    customer_email NVARCHAR(255) NOT NULL UNIQUE,
    customer_name  NVARCHAR(255) NULL
);
GO

CREATE TABLE gold.Dim_Manufacturer (
    manufacturer_id   INT IDENTITY(1,1) PRIMARY KEY,
    manufacturer_name NVARCHAR(255) NOT NULL UNIQUE
);
GO

-- Grain = (category_name, sub_category_name). Dim_Product.category_id trỏ tới đúng cặp này.
CREATE TABLE gold.Dim_Category (
    category_id       INT IDENTITY(1,1) PRIMARY KEY,
    category_name     NVARCHAR(100) NOT NULL,
    sub_category_name NVARCHAR(100) NOT NULL,
    CONSTRAINT UQ_Dim_Category UNIQUE (category_name, sub_category_name)
);
GO

CREATE TABLE gold.Dim_Date (
    date_id       INT PRIMARY KEY,
    [date]        DATE NOT NULL UNIQUE,
    [year]        INT NOT NULL,
    [quarter]     INT NOT NULL,
    quarter_name  NVARCHAR(5) NOT NULL,
    [month]       INT NOT NULL,
    month_name    NVARCHAR(20) NOT NULL,
    [day]         INT NOT NULL,
    week_day      INT NOT NULL,
    week_day_name NVARCHAR(20) NOT NULL
);
GO

CREATE TABLE gold.Dim_Product (
    product_id      INT IDENTITY(1,1) PRIMARY KEY,
    product_name    NVARCHAR(255) NOT NULL,
    version         NVARCHAR(100) NOT NULL,
    category_id     INT NOT NULL,
    manufacturer_id INT NOT NULL,
    CONSTRAINT UQ_Dim_Product UNIQUE (product_name, version),
    CONSTRAINT FK_Dim_Product_Category     FOREIGN KEY (category_id)     REFERENCES gold.Dim_Category(category_id),
    CONSTRAINT FK_Dim_Product_Manufacturer FOREIGN KEY (manufacturer_id) REFERENCES gold.Dim_Manufacturer(manufacturer_id)
);
GO

CREATE TABLE gold.Dim_Order (
    order_id       INT PRIMARY KEY,
    date_id        INT NOT NULL,
    customer_id    INT NULL,
    district_id    INT NULL,
    traffic_source NVARCHAR(100) NULL,
    order_status   NVARCHAR(100) NULL,
    payment_method NVARCHAR(100) NULL,
    CONSTRAINT FK_Dim_Order_Date     FOREIGN KEY (date_id)     REFERENCES gold.Dim_Date(date_id),
    CONSTRAINT FK_Dim_Order_Customer FOREIGN KEY (customer_id) REFERENCES gold.Dim_Customer(customer_id),
    CONSTRAINT FK_Dim_Order_District FOREIGN KEY (district_id) REFERENCES gold.Dim_District(district_id)
);
GO

CREATE TABLE gold.Dim_Gift (
    gift_id   INT IDENTITY(1,1) PRIMARY KEY,
    gift_name NVARCHAR(255) NOT NULL UNIQUE
);
GO

-- ============================================================
-- Facts
-- ============================================================

CREATE TABLE gold.Fact_OrderLine (
    order_id        INT NOT NULL,
    product_id      INT NOT NULL,
    quantity        INT NOT NULL,
    revenue         DECIMAL(18,2) NOT NULL,
    discount_amount DECIMAL(18,2) NOT NULL,
    amount_received DECIMAL(18,2) NOT NULL,
    CONSTRAINT PK_Fact_OrderLine PRIMARY KEY (order_id, product_id),
    CONSTRAINT FK_Fact_OrderLine_Order   FOREIGN KEY (order_id)   REFERENCES gold.Dim_Order(order_id),
    CONSTRAINT FK_Fact_OrderLine_Product FOREIGN KEY (product_id) REFERENCES gold.Dim_Product(product_id)
);
GO

-- Grain = 1 quà / 1 đơn. PK (order_id, gift_id) chốt grain (bỏ surrogate fact_gift_id).
CREATE TABLE gold.Fact_Gift (
    order_id INT NOT NULL,
    gift_id  INT NOT NULL,
    CONSTRAINT PK_Fact_Gift PRIMARY KEY (order_id, gift_id),
    CONSTRAINT FK_Fact_Gift_Order FOREIGN KEY (order_id) REFERENCES gold.Dim_Order(order_id),
    CONSTRAINT FK_Fact_Gift_Gift  FOREIGN KEY (gift_id)  REFERENCES gold.Dim_Gift(gift_id)
);
GO

-- ============================================================
-- Market Basket Analysis — 2 VIEW (không materialize)
--
-- vw_MBA_SubCategory_Pairs : item = sub_category_name (~10 giá trị -> ma trận đặc,
--                            số ổn định). ĐÂY là output MBA đáng tin.
-- vw_MBA_Product_Pairs     : item = 3 từ đầu của product_name (gộp thô biến thể SKU).
--                            Giữ thô CỐ Ý để cặp còn đủ đơn (data mỏng ~4.3K giỏ).
--                            Dùng để gợi ý theo hướng, KHÔNG coi là con số chắc.
--
-- Cả 2: chỉ đơn "Không hủy" (LEN(order_status) > 3).
--   confidence_a_to_b = P(mua B | đã mua A) = pair_order_count / (#đơn có A).
--   lift = pair_order_count * total_orders / (a_orders * b_orders)   (đối xứng -> 1 cột).
--   -> LỌC pair_order_count >= ~15-20 trước khi tin support / confidence / lift.
-- ============================================================
CREATE OR ALTER VIEW gold.vw_MBA_Product_Pairs
AS
WITH base AS (
    SELECT DISTINCT
        ol.order_id,
        CASE
            WHEN p3.space_pos_3 > 0 THEN LEFT(n.clean_name, p3.space_pos_3 - 1)
            ELSE n.clean_name
        END AS product_name
    FROM gold.Fact_OrderLine ol
    INNER JOIN gold.Dim_Product p
        ON p.product_id = ol.product_id
    INNER JOIN gold.Dim_Order o
        ON o.order_id = ol.order_id
    CROSS APPLY (
        SELECT REPLACE(REPLACE(REPLACE(
                   LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(p.product_name, CHAR(9), ' '), CHAR(10), ' '), CHAR(13), ' '))),
                   '  ', ' '),
                   '  ', ' '),
                   '  ', ' ') AS clean_name
    ) n
    CROSS APPLY (
        SELECT CHARINDEX(' ', n.clean_name) AS space_pos_1
    ) p1
    CROSS APPLY (
        SELECT CASE WHEN p1.space_pos_1 > 0
                    THEN CHARINDEX(' ', n.clean_name, p1.space_pos_1 + 1)
                    ELSE 0 END AS space_pos_2
    ) p2
    CROSS APPLY (
        SELECT CASE WHEN p2.space_pos_2 > 0
                    THEN CHARINDEX(' ', n.clean_name, p2.space_pos_2 + 1)
                    ELSE 0 END AS space_pos_3
    ) p3
        WHERE p.product_name IS NOT NULL
            AND LEN(LTRIM(RTRIM(o.order_status))) > 3
      AND LEN(n.clean_name) > 0
),
pair_base AS (
    SELECT
        a.order_id,
        a.product_name AS product_a,
        b.product_name AS product_b
    FROM base a
    INNER JOIN base b
        ON a.order_id = b.order_id
       AND a.product_name < b.product_name
),
pair_counts AS (
    SELECT
        product_a,
        product_b,
        COUNT(*) AS pair_order_count
    FROM pair_base
    GROUP BY product_a, product_b
),
product_counts AS (
    SELECT
        product_name,
        COUNT(DISTINCT order_id) AS product_order_count
    FROM base
    GROUP BY product_name
),
order_stats AS (
    SELECT COUNT(DISTINCT order_id) AS total_orders
    FROM base
)
SELECT
    pc.product_a,
    pc.product_b,
    pc.pair_order_count,
    ca.product_order_count AS product_a_orders,
    cb.product_order_count AS product_b_orders,
    CAST(pc.pair_order_count * 1.0 / NULLIF(os.total_orders, 0) AS DECIMAL(18,6)) AS support,
    CAST(pc.pair_order_count * 1.0 / NULLIF(ca.product_order_count, 0) AS DECIMAL(18,6)) AS confidence_a_to_b,
    CAST(pc.pair_order_count * 1.0 / NULLIF(cb.product_order_count, 0) AS DECIMAL(18,6)) AS confidence_b_to_a,
    CAST(
        pc.pair_order_count * 1.0 * os.total_orders
        / NULLIF(ca.product_order_count * cb.product_order_count, 0)
        AS DECIMAL(18,6)
    ) AS lift
FROM pair_counts pc
INNER JOIN product_counts ca
    ON ca.product_name = pc.product_a
INNER JOIN product_counts cb
    ON cb.product_name = pc.product_b
CROSS JOIN order_stats os;
GO

-- ------------------------------------------------------------
-- MBA theo sub_category (item = sub_category_name, ~10 giá trị)
-- ------------------------------------------------------------
CREATE OR ALTER VIEW gold.vw_MBA_SubCategory_Pairs
AS
WITH base AS (
    SELECT DISTINCT
        ol.order_id,
        cat.sub_category_name AS item
    FROM gold.Fact_OrderLine ol
    INNER JOIN gold.Dim_Product  p   ON p.product_id   = ol.product_id
    INNER JOIN gold.Dim_Category cat ON cat.category_id = p.category_id
    INNER JOIN gold.Dim_Order    o   ON o.order_id     = ol.order_id
    WHERE LEN(LTRIM(RTRIM(o.order_status))) > 3      -- chỉ đơn "Không hủy"
),
pair_base AS (
    SELECT a.order_id, a.item AS item_a, b.item AS item_b
    FROM base a
    INNER JOIN base b
        ON a.order_id = b.order_id
       AND a.item < b.item
),
pair_counts AS (
    SELECT item_a, item_b, COUNT(*) AS pair_order_count
    FROM pair_base
    GROUP BY item_a, item_b
),
item_counts AS (
    SELECT item, COUNT(DISTINCT order_id) AS item_order_count
    FROM base
    GROUP BY item
),
order_stats AS (
    SELECT COUNT(DISTINCT order_id) AS total_orders
    FROM base
)
SELECT
    pc.item_a,
    pc.item_b,
    pc.pair_order_count,
    ca.item_order_count AS item_a_orders,
    cb.item_order_count AS item_b_orders,
    CAST(pc.pair_order_count * 1.0 / NULLIF(os.total_orders, 0)     AS DECIMAL(18,6)) AS support,
    CAST(pc.pair_order_count * 1.0 / NULLIF(ca.item_order_count, 0) AS DECIMAL(18,6)) AS confidence_a_to_b,
    CAST(pc.pair_order_count * 1.0 / NULLIF(cb.item_order_count, 0) AS DECIMAL(18,6)) AS confidence_b_to_a,
    CAST(
        pc.pair_order_count * 1.0 * os.total_orders
        / NULLIF(ca.item_order_count * cb.item_order_count, 0)
        AS DECIMAL(18,6)
    ) AS lift
FROM pair_counts pc
INNER JOIN item_counts ca ON ca.item = pc.item_a
INNER JOIN item_counts cb ON cb.item = pc.item_b
CROSS JOIN order_stats os;
GO
