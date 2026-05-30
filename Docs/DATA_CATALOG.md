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

| Cột                 | Mô tả            |
| ------------------- | ---------------- |
| customer_email (PK) | Email khách hàng |
| customer_name       | Tên khách hàng   |

---

#### `gold.Dim_Product`

| Cột               | Mô tả                                    |
| ----------------- | ---------------------------------------- |
| product_name (PK) | Tên sản phẩm                             |
| category_name     | Danh mục                                 |
| manufacturer_name | Nhà sản xuất                             |
| avg_price         | Giá trung bình = AVG(revenue / quantity) |

---

#### `gold.Dim_Category`

| Cột                | Mô tả                 |
| ------------------ | --------------------- |
| category_name (PK) | Tên danh mục sản phẩm |

---

#### `gold.Dim_Manufacturer`

| Cột                    | Mô tả                              |
| ---------------------- | ---------------------------------- |
| manufacturer_name (PK) | Tên nhà sản xuất (bỏ giá trị '--') |

---

#### `gold.Dim_Region`

| Cột              | Mô tả                             |
| ---------------- | --------------------------------- |
| region_name (PK) | Vùng địa lý (parse từ cột branch) |

---

#### `gold.Dim_Province`

| Cột                | Mô tả          |
| ------------------ | -------------- |
| province_name (PK) | Tỉnh/Thành phố |
| region_name (FK)   | Vùng địa lý    |

---

#### `gold.Dim_District`

| Cột                | Mô tả          |
| ------------------ | -------------- |
| district_name (PK) | Quận/Huyện     |
| province_name (FK) | Tỉnh/Thành phố |

---

#### `gold.Dim_Gift`

| Cột            | Mô tả        |
| -------------- | ------------ |
| gift_name (PK) | Tên quà tặng |

> Tách riêng khỏi `Dim_Product` vì 91.7% gift_name không khớp với product_name (quà là hàng mini/sample và phụ kiện).

---

### FACT VIEWS

#### `gold.Fact_Transaction`

Bảng trung tâm của Star Schema. JOIN `silver.Transaction_Data` + `silver.Shipping_Data`.

| Cột                                       | Mô tả                                       |
| ----------------------------------------- | ------------------------------------------- |
| order_id                                  | Mã đơn hàng                                 |
| **date_id** (FK → Dim_Date)               | Surrogate key ngày                          |
| date                                      | Ngày đặt hàng                               |
| order_year / order_month / order_quarter  | Thời gian                                   |
| customer_email (FK → Dim_Customer)        | Email khách hàng                            |
| customer_name                             | Tên khách hàng                              |
| product_name (FK → Dim_Product)           | Tên sản phẩm                                |
| category_name (FK → Dim_Category)         | Danh mục                                    |
| manufacturer_name (FK → Dim_Manufacturer) | Nhà sản xuất                                |
| district / province / branch              | Địa lý                                      |
| traffic_source                            | Kênh bán hàng                               |
| order_status                              | Trạng thái đơn                              |
| payment_method                            | Phương thức thanh toán                      |
| version                                   | Phiên bản sản phẩm                          |
| quantity                                  | Số lượng                                    |
| revenue                                   | Doanh thu                                   |
| discount_amount                           | Giảm giá                                    |
| total_invoice                             | Tổng hóa đơn                                |
| amount_received                           | Thực nhận                                   |
| shipping_fee                              | Phí vận chuyển (từ Shipping_Data, NULL → 0) |

---

#### `gold.Fact_Gift`

Map đơn hàng ↔ quà tặng.

| Cột                              | Mô tả              |
| -------------------------------- | ------------------ |
| order_id (FK → Fact_Transaction) | Mã đơn hàng        |
| gift_name (FK → Dim_Gift)        | Tên quà tặng       |
| **date_id** (FK → Dim_Date)      | Surrogate key ngày |
| date                             | Ngày               |
| order_year / order_month         | Thời gian          |
| customer_email                   | Email khách hàng   |
| traffic_source                   | Kênh bán hàng      |
| branch                           | Chi nhánh          |
| order_status                     | Trạng thái đơn     |

---

### FLAT / MBA VIEWS

#### `gold.Order_Products`

Subset của `Fact_Transaction` dùng cho **Market Basket Analysis**.  
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

| Từ               | Đến              | Key                          |
| ---------------- | ---------------- | ---------------------------- |
| Fact_Transaction | Dim_Date         | `date_id`                    |
| Fact_Transaction | Dim_Customer     | `customer_email`             |
| Fact_Transaction | Dim_Product      | `product_name`               |
| Fact_Transaction | Dim_Category     | `category_name`              |
| Fact_Transaction | Dim_Manufacturer | `manufacturer_name`          |
| Fact_Gift        | Dim_Gift         | `gift_name`                  |
| Fact_Gift        | Dim_Date         | `date_id`                    |
| Fact_Gift        | Fact_Transaction | `order_id`                   |
| Dim_Province     | Dim_Region       | `region_name`                |
| Dim_District     | Dim_Province     | `province_name`              |
| Order_Products   | Fact_Transaction | subset (không join, là view) |
