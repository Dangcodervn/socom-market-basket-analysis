# SOCOM Data Warehouse — Data Catalog

> Mô tả chi tiết tất cả bảng và view trong hệ thống Data Warehouse  
> Database: `SocomDataWarehouse`

---

## BRONZE LAYER

Dữ liệu thô nạp trực tiếp từ CSV, **không có transformation**.

### `bronze.Transaction_Data`

| Cột              | Kiểu          | Mô tả                               |
| ---------------- | ------------- | ----------------------------------- |
| manufacturer     | NVARCHAR(255) | Nhà sản xuất                        |
| customer         | NVARCHAR(255) | Tên khách hàng                      |
| customer_email   | NVARCHAR(255) | Email khách hàng                    |
| date             | DATE          | Ngày đặt hàng                       |
| traffic_source   | NVARCHAR(100) | Kênh bán hàng (Facebook, TikTok...) |
| branch           | NVARCHAR(100) | Chi nhánh (Region – Province)       |
| product_category | NVARCHAR(100) | Danh mục sản phẩm                   |
| province         | NVARCHAR(100) | Tỉnh/Thành phố                      |
| order_id         | INT           | Mã đơn hàng                         |
| product_name     | NVARCHAR(255) | Tên sản phẩm                        |
| district         | NVARCHAR(100) | Quận/Huyện                          |
| version          | NVARCHAR(100) | Phiên bản/Dung tích sản phẩm        |
| order_status     | NVARCHAR(100) | Trạng thái đơn hàng                 |
| payment_method   | NVARCHAR(100) | Phương thức thanh toán              |
| revenue          | INT           | Doanh thu (VND)                     |
| discount_amount  | FLOAT         | Số tiền giảm giá                    |
| total_invoice    | FLOAT         | Tổng hóa đơn                        |
| amount_received  | FLOAT         | Số tiền thực nhận                   |
| quantity         | INT           | Số lượng                            |
| shipping_fee     | INT           | Phí vận chuyển                      |

### `bronze.Gift_Data`

| Cột       | Kiểu          | Mô tả                     |
| --------- | ------------- | ------------------------- |
| order_id  | INT           | Mã đơn hàng               |
| gift_name | NVARCHAR(255) | Tên quà tặng kèm theo đơn |

### `bronze.Shipping_Data`

| Cột          | Kiểu    | Mô tả          |
| ------------ | ------- | -------------- |
| order_id     | INT     | Mã đơn hàng    |
| shipping_fee | DECIMAL | Phí vận chuyển |

---

## SILVER LAYER

Dữ liệu đã được **làm sạch, chuẩn hóa và dedup**.  
Transformation: LTRIM/RTRIM, CAST, lọc NULL, loại duplicate theo `(order_id, product_name)`.

### `silver.Transaction_Data`

| Cột               | Kiểu          | Mô tả                  | Transformation                    |
| ----------------- | ------------- | ---------------------- | --------------------------------- |
| manufacturer      | NVARCHAR(255) | Nhà sản xuất           | LTRIM/RTRIM                       |
| customer          | NVARCHAR(255) | Tên khách hàng         | LTRIM/RTRIM                       |
| customer_email    | NVARCHAR(255) | Email khách hàng       | LTRIM/RTRIM                       |
| date              | DATE          | Ngày đặt hàng          | Giữ nguyên                        |
| **order_year**    | INT           | Năm đặt hàng           | YEAR(date) — derived              |
| **order_month**   | INT           | Tháng đặt hàng         | MONTH(date) — derived             |
| **order_quarter** | INT           | Quý đặt hàng           | DATEPART(QUARTER, date) — derived |
| traffic_source    | NVARCHAR(100) | Kênh bán hàng          | LTRIM/RTRIM                       |
| branch            | NVARCHAR(100) | Chi nhánh              | LTRIM/RTRIM                       |
| product_category  | NVARCHAR(100) | Danh mục sản phẩm      | LTRIM/RTRIM                       |
| province          | NVARCHAR(100) | Tỉnh/Thành phố         | LTRIM/RTRIM                       |
| order_id          | INT           | Mã đơn hàng            | Filter NULL                       |
| product_name      | NVARCHAR(255) | Tên sản phẩm           | LTRIM/RTRIM                       |
| district          | NVARCHAR(100) | Quận/Huyện             | LTRIM/RTRIM                       |
| version           | NVARCHAR(100) | Phiên bản sản phẩm     | LTRIM/RTRIM                       |
| order_status      | NVARCHAR(100) | Trạng thái đơn hàng    | LTRIM/RTRIM                       |
| payment_method    | NVARCHAR(100) | Phương thức thanh toán | LTRIM/RTRIM                       |
| revenue           | DECIMAL(18,2) | Doanh thu              | CAST, ISNULL→0                    |
| discount_amount   | DECIMAL(18,2) | Số tiền giảm giá       | CAST, ISNULL→0                    |
| total_invoice     | DECIMAL(18,2) | Tổng hóa đơn           | CAST, ISNULL→0                    |
| amount_received   | DECIMAL(18,2) | Số tiền thực nhận      | CAST, ISNULL→0                    |
| quantity          | INT           | Số lượng               | ISNULL→0                          |
| shipping_fee      | DECIMAL(18,2) | Phí vận chuyển         | CAST, ISNULL→0                    |

**Dedup rule:** `ROW_NUMBER() PARTITION BY (order_id, product_name) ORDER BY revenue DESC` — giữ 1 dòng / sản phẩm / đơn hàng.

### `silver.Gift_Data`

| Cột       | Kiểu          | Mô tả        | Transformation           |
| --------- | ------------- | ------------ | ------------------------ |
| order_id  | INT           | Mã đơn hàng  | Filter NULL              |
| gift_name | NVARCHAR(255) | Tên quà tặng | LTRIM/RTRIM, filter rỗng |

### `silver.Shipping_Data`

| Cột          | Kiểu          | Mô tả          | Transformation  |
| ------------ | ------------- | -------------- | --------------- |
| order_id     | INT           | Mã đơn hàng    | Filter NULL     |
| shipping_fee | DECIMAL(18,2) | Phí vận chuyển | CAST, filter âm |

---

## GOLD LAYER

**Chỉ có Views** — không load dữ liệu. Tự cập nhật khi Silver thay đổi.  
**Data Model: Snowflake Schema (3NF)** — Tất cả Dim có surrogate key INT; Fact chỉ lưu FK IDs + measures.

### DIMENSION VIEWS

#### `gold.Dim_Date`

Dãy ngày **liên tục** từ MIN → MAX date trong Silver (không bỏ ngày thiếu giao dịch).

| Cột              | Mô tả                              |
| ---------------- | ---------------------------------- |
| **date_id** (PK) | Surrogate key dạng INT: `yyyyMMdd` |
| date             | Ngày                               |
| year             | Năm                                |
| quarter          | Quý (số)                           |
| quarter_name     | Quý (Q1, Q2...)                    |
| month            | Tháng (số)                         |
| month_name       | Tháng (chữ)                        |
| day              | Ngày trong tháng                   |
| week_day         | Thứ (số)                           |
| week_day_name    | Thứ (chữ)                          |

---

#### `gold.Dim_Customer`

| Cột                  | Mô tả                                         |
| -------------------- | --------------------------------------------- |
| **customer_id** (PK) | Surrogate key INT (ROW_NUMBER ORDER BY email) |
| customer_email       | Email khách hàng                              |
| customer_name        | Tên khách hàng                                |

---

#### `gold.Dim_Product`

**Granularity = SKU: `(product_name, version)`**

| Cột                                         | Mô tả                                    |
| ------------------------------------------- | ---------------------------------------- |
| **product_id** (PK)                         | Surrogate key INT                        |
| product_name                                | Tên sản phẩm                             |
| version                                     | Phiên bản / dung tích (thuộc tính SKU)   |
| **category_id** (FK → Dim_Category)         | ID danh mục (3NF, bỏ category_name thừa) |
| **manufacturer_id** (FK → Dim_Manufacturer) | ID nhà sản xuất (3NF)                    |
| avg_price                                   | Giá trung bình = AVG(revenue / quantity) |

> Mỗi `(product_name, version)` → 1 dòng duy nhất. Category/Manufacturer chọn theo nhóm xuất hiện nhiều nhất.

---

#### `gold.Dim_Category`

| Cột                  | Mô tả                 |
| -------------------- | --------------------- |
| **category_id** (PK) | Surrogate key INT     |
| category_name        | Tên danh mục sản phẩm |

---

#### `gold.Dim_Manufacturer`

| Cột                      | Mô tả                              |
| ------------------------ | ---------------------------------- |
| **manufacturer_id** (PK) | Surrogate key INT                  |
| manufacturer_name        | Tên nhà sản xuất (bỏ giá trị '--') |

---

#### `gold.Dim_Region`

| Cột                | Mô tả                             |
| ------------------ | --------------------------------- |
| **region_id** (PK) | Surrogate key INT                 |
| region_name        | Vùng địa lý (parse từ cột branch) |

---

#### `gold.Dim_Province`

| Cột                             | Mô tả                |
| ------------------------------- | -------------------- |
| **province_id** (PK)            | Surrogate key INT    |
| province_name                   | Tỉnh/Thành phố       |
| **region_id** (FK → Dim_Region) | Vùng địa lý (3NF FK) |

---

#### `gold.Dim_District`

| Cột                                 | Mô tả                   |
| ----------------------------------- | ----------------------- |
| **district_id** (PK)                | Surrogate key INT       |
| district_name                       | Quận/Huyện              |
| **province_id** (FK → Dim_Province) | Tỉnh/Thành phố (3NF FK) |

---

#### `gold.Dim_Gift`

| Cột              | Mô tả             |
| ---------------- | ----------------- |
| **gift_id** (PK) | Surrogate key INT |
| gift_name        | Tên quà tặng      |

> Tách riêng khỏi `Dim_Product` vì 91.7% gift_name không khớp với product_name (quà là hàng mini/sample và phụ kiện).

---

### FACT VIEWS

#### `gold.Dim_Order`

**Grain = 1 đơn hàng.** Chứa tất cả order-level attributes. Xác nhận: `traffic_source`, `order_status`, `payment_method` không thay đổi trong cùng 1 `order_id`.

| Cột                                 | Mô tả                             |
| ----------------------------------- | --------------------------------- |
| order_id (PK tự nhiên)              | Mã đơn hàng                       |
| **date_id** (FK → Dim_Date)         | Surrogate key ngày (INT yyyyMMdd) |
| **customer_id** (FK → Dim_Customer) | Surrogate key khách hàng          |
| **district_id** (FK → Dim_District) | Surrogate key quận/huyện          |
| traffic_source                      | Kênh bán hàng                     |
| order_status                        | Trạng thái đơn                    |
| payment_method                      | Phương thức thanh toán            |

---

#### `gold.Fact_OrderLine`

**Grain = 1 sản phẩm / 1 đơn hàng.** Chỉ có 2 FK + 4 measures — grain sạch hoàn toàn.

| Cột                               | Mô tả                        |
| --------------------------------- | ---------------------------- |
| **order_id** (FK → Dim_Order)     | Mã đơn hàng                  |
| **product_id** (FK → Dim_Product) | Surrogate key sản phẩm (SKU) |
| quantity                          | Số lượng                     |
| revenue                           | Doanh thu (per line-item)    |
| discount_amount                   | Giảm giá (per line-item)     |
| amount_received                   | Thực nhận (per line-item)    |

> **Bỏ khỏi Fact_OrderLine (3NF):** `date_id`, `customer_id`, `district_id`, `traffic_source`, `order_status`, `payment_method` → lấy qua `Dim_Order`; `total_invoice` → derivable (`revenue + discount_amount`); `shipping_fee` → bỏ (coverage 35.8%, grain sai).

---

#### `gold.Fact_Gift`

Map đơn hàng ↔ quà tặng. **Chỉ giữ 2 FK IDs (3NF thuần)** — date / customer / status lấy qua `Fact_Gift → Dim_Order`.

| Cột                         | Mô tả                  |
| --------------------------- | ---------------------- |
| order_id (FK → Dim_Order)   | Mã đơn hàng            |
| **gift_id** (FK → Dim_Gift) | Surrogate key quà tặng |

---

### FLAT / MBA VIEWS

#### `gold.Order_Products`

Subset của `Fact_OrderLine` dùng cho **Market Basket Analysis**.  
Chỉ gồm đơn hàng **không bị hủy/hoàn trả** (`order_status NOT IN ('Đã hủy', 'Hoàn hàng')`).

| Cột               | Mô tả        |
| ----------------- | ------------ |
| order_id          | Mã đơn hàng  |
| product_name      | Tên sản phẩm |
| category_name     | Danh mục     |
| manufacturer_name | Nhà sản xuất |
| date              | Ngày         |
| year              | Năm          |
| month_name        | Tháng (chữ)  |

---

## Quan hệ giữa các bảng (Join Keys)

| Từ             | Đến              | Key                         |
| -------------- | ---------------- | --------------------------- |
| Dim_Order      | Dim_Date         | `date_id`                   |
| Dim_Order      | Dim_Customer     | `customer_id`               |
| Dim_Order      | Dim_District     | `district_id`               |
| Dim_District   | Dim_Province     | `province_id`               |
| Dim_Province   | Dim_Region       | `region_id`                 |
| Fact_OrderLine | Dim_Order        | `order_id`                  |
| Fact_OrderLine | Dim_Product      | `product_id`                |
| Dim_Product    | Dim_Category     | `category_id`               |
| Dim_Product    | Dim_Manufacturer | `manufacturer_id`           |
| Fact_Gift      | Dim_Order        | `order_id`                  |
| Fact_Gift      | Dim_Gift         | `gift_id`                   |
| Order_Products | Fact_OrderLine   | subset (JOIN qua Dim_Order) |
