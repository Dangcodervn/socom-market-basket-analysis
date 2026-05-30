# SOCOM Market Basket Analysis — Data Warehouse Project

## Giới thiệu dự án

Dự án xây dựng Data Warehouse theo kiến trúc **Medallion (Bronze → Silver → Gold)** cho **SOCOM** — một nhà phân phối mỹ phẩm tại Việt Nam. Mục tiêu là phân tích giỏ hàng (Market Basket Analysis) và xây dựng nền tảng báo cáo doanh thu.

---

## Kiến trúc tổng quan

```
Raw Data (CSV/XLSX)
      │
      ▼
┌─────────────┐     BULK INSERT      ┌─────────────┐     Cleanse & Dedup     ┌─────────────┐
│   BRONZE    │ ──────────────────▶  │   SILVER    │ ───────────────────────▶ │    GOLD     │
│  (Raw Tables│                      │ (Flat Tables│                           │  (Views)    │
│   No Transform)                    │  Cleaned)   │                           │ Star Schema │
└─────────────┘                      └─────────────┘                           └─────────────┘
```

| Layer  | Loại object               | Mục đích                                |
| ------ | ------------------------- | --------------------------------------- |
| Bronze | Tables + Stored Procedure | Nạp dữ liệu thô từ CSV, không transform |
| Silver | Tables + Stored Procedure | Làm sạch, chuẩn hóa, dedup              |
| Gold   | Views only                | Star Schema cho BI & MBA                |

---

## Cấu trúc thư mục

```
├── SQL/
│   ├── init_database.sql         # Tạo DB + 3 schema (bronze, silver, gold)
│   ├── Bronze/
│   │   └── sp_load_bronze.sql    # BULK INSERT CSV → Bronze tables
│   ├── Silver/
│   │   ├── sp_load_silver.sql    # Bronze → Silver (cleanse, dedup)
│   │   └── check_silver_quality.sql  # 12 data quality checks
│   └── Gold/
│       └── ddl_gold_views.sql    # 12 Gold views (Star Schema + Fact + MBA)
├── Docs/
│   ├── README.md                 # File này
│   ├── DATA_CATALOG.md           # Mô tả chi tiết từng bảng/view
│   └── Demo Diagram.drawio       # Sơ đồ kiến trúc
├── SocomDataPreprocess.ipynb     # Python ETL: Raw XLSX → Cleaned CSV
└── .gitignore                    # Bỏ qua Raw Data (PII) và Cleaned_Data
```

---

## Hướng dẫn chạy pipeline

### Bước 1 — Chuẩn bị dữ liệu (Python)

```bash
# Mở và chạy toàn bộ SocomDataPreprocess.ipynb
# Output: Cleaned_Data/Transaction_Data.csv, Gift_Data.csv, Shipping_Data.csv
```

### Bước 2 — Khởi tạo Database

```sql
-- Chạy 1 lần duy nhất
-- SQL/init_database.sql
CREATE DATABASE SocomDataWarehouse;
CREATE SCHEMA bronze / silver / gold;
```

### Bước 3 — Tạo Bronze SP và nạp dữ liệu

```sql
-- SQL/Bronze/sp_load_bronze.sql
EXEC bronze.sp_load_bronze;
```

### Bước 4 — Tạo Silver SP và làm sạch dữ liệu

```sql
-- SQL/Silver/sp_load_silver.sql
EXEC silver.sp_load_silver;
```

### Bước 5 — Kiểm tra chất lượng Silver

```sql
-- SQL/Silver/check_silver_quality.sql
-- Chạy thủ công, kiểm tra 12 chỉ số
```

### Bước 6 — Tạo Gold Views

```sql
-- SQL/Gold/ddl_gold_views.sql
-- Chạy 1 lần — views tự cập nhật khi Silver thay đổi
```

---

## Data Model (Gold Layer)

```
Dim_Date ──────────────────┐
Dim_Customer ───────────── │
Dim_Product ─────────────  ├──▶ Fact_Transaction ◀── Shipping_Data
  ├── Dim_Category          │
  └── Dim_Manufacturer      │
Dim_District               │
  └── Dim_Province          │
       └── Dim_Region ──────┘

Dim_Gift ──────────────────▶ Fact_Gift
                              (JOIN Fact_Transaction on order_id)

Order_Products  (Subset của Fact_Transaction — dùng cho MBA)
```

---

## Các chỉ số chất lượng dữ liệu (sau khi làm sạch)

| Metric                             | Trạng thái                  |
| ---------------------------------- | --------------------------- |
| NULL ở cột quan trọng              | ✅ 0                        |
| Exact duplicate rows               | ✅ 0                        |
| Duplicate (order_id, product_name) | ✅ 0                        |
| Revenue âm                         | ✅ 0                        |
| Shipping fee âm                    | ✅ 0                        |
| Quantity <= 0                      | ✅ Chỉ ở đơn "Hủy" (hợp lệ) |

---

## Công nghệ sử dụng

| Công cụ            | Mục đích                           |
| ------------------ | ---------------------------------- |
| SQL Server (T-SQL) | Database, Stored Procedures, Views |
| Python / Pandas    | Tiền xử lý dữ liệu thô             |
| Jupyter Notebook   | ETL pipeline Python                |
| Git / GitHub       | Version control                    |

---

## Tác giả

**Tran Hoang Long** — Data Analyst  
GitHub: [Dangcodervn/socom-market-basket-analysis](https://github.com/Dangcodervn/socom-market-basket-analysis)
