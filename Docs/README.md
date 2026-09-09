# SOCOM Market Basket Analysis — Medallion DWH + Power BI

Portfolio dự án Data Analyst: **Data Warehouse kiến trúc Medallion (Bronze → Silver → Gold trên SQL Server)** + **dashboard Power BI 4 trang** cho **SOCOM** — nhà phân phối mỹ phẩm tại Việt Nam (L'Oréal Paris, Maybelline New York, Garnier).

Mục tiêu phân tích: *tăng doanh thu không tăng chi marketing* → 2 đòn bẩy: **bịt rò rỉ hủy đơn** + **tăng giá trị giỏ (cross-sell / Market Basket Analysis)**.

> ⚠️ **Dữ liệu là synthetic (2021).** Các số liệu minh hoạ phương pháp, không phải phát hiện kinh doanh thật.

---

## Kiến trúc

```
Raw XLSX ──(Python/pandas)──▶ Cleaned CSV ──(BULK INSERT)──▶ BRONZE ──▶ SILVER ──▶ GOLD ──▶ Power BI
                                                             thô        làm sạch,   star schema   model + dashboard
                                                                        dedup       + MBA views
```

| Tầng | Object | Mục đích |
| --- | --- | --- |
| **Bronze** | Tables + `sp_load_bronze` | Nạp CSV thô, không transform |
| **Silver** | Tables + `sp_load_silver` | Làm sạch, chuẩn hoá, dedup theo `(order_id, product_name, version)` |
| **Gold** | **Tables** + `sp_load_gold` + 2 MBA views | Star schema (Dim/Fact) cho BI + `vw_MBA_Product_Pairs` / `vw_MBA_SubCategory_Pairs` |

Star schema Gold: `Fact_OrderLine` + `Fact_Gift` quanh `Dim_Order` · `Dim_Product` (→ `Dim_Category` gộp category+sub_category, `Dim_Manufacturer`) · `Dim_Date` · `Dim_Customer` · `Dim_District` → `Dim_Province`. Không có `Dim_Region` (branch = kho/gian hàng, không đủ dữ liệu địa lý).

---

## Cấu trúc repo

```
├── SocomDataPreprocess.ipynb        # Python ETL: Raw XLSX → Cleaned CSV
├── mapping_ollama.py                # (thử nghiệm) map product→category bằng LLM local
├── SQL/
│   ├── init_database.sql            # tạo DB + 3 schema
│   ├── jobs_schedule.sql            # SQL Agent jobs
│   ├── Bronze/  ddl_bronze_tables.sql · sp_load_bronze.sql · check_bronze_quality.sql
│   ├── Silver/  ddl_silver_tables.sql · sp_load_silver.sql · check_silver_quality.sql
│   └── Gold/    ddl_gold_tables.sql · sp_load_gold.sql
├── Power BI Project/                # PBIP (TMDL model + PBIR report) — nguồn chân lý dashboard
├── Docs/                            # xem "Tài liệu" bên dưới
├── Raw Data/                        # (gitignored — PII/synthetic)
└── Cleaned_Data/                    # (gitignored trừ product_category_map.xlsx)
```

---

## Chạy pipeline

| # | Bước | Lệnh |
| --- | --- | --- |
| 1 | Tiền xử lý dữ liệu | Chạy toàn bộ `SocomDataPreprocess.ipynb` → `Cleaned_Data/*.csv` |
| 2 | Khởi tạo DB | Chạy `SQL/init_database.sql` (1 lần) |
| 3 | Bronze | `SQL/Bronze/ddl_bronze_tables.sql` → `EXEC bronze.sp_load_bronze @data_dir = N'...\Cleaned_Data'` |
| 4 | Silver | `SQL/Silver/ddl_silver_tables.sql` → `EXEC silver.sp_load_silver` → `check_silver_quality.sql` |
| 5 | Gold | `SQL/Gold/ddl_gold_tables.sql` → `EXEC gold.sp_load_gold` |
| 6 | Dashboard | Mở `Power BI Project/SocomDataAnalysis.pbip` trong Power BI Desktop |

Tất cả DDL là **DROP & CREATE** — chạy lại an toàn. `sp_load_bronze` nhận `@data_dir`, mặc định trỏ `Cleaned_Data/`.

---

## Tài liệu

| File | Đọc khi |
| --- | --- |
| [`PROJECT_BRIEF.md`](PROJECT_BRIEF.md) | Muốn nắm nhanh toàn dự án + trạng thái + **model Power BI hiện tại** (bảng, quan hệ, 22 measure) + số nền |
| [`DATA_CATALOG.md`](DATA_CATALOG.md) | Tra chi tiết từng bảng/cột Bronze / Silver / Gold |
| [`DASHBOARD_PLAN.md`](DASHBOARD_PLAN.md) | Thiết kế dashboard 4 trang: câu hỏi → quyết định → stakeholder, 3 tầng đọc, archetype/variant, + `Design Brief:` YAML (layout_contract) ở cuối |
| [`socom-beauty-theme.json`](socom-beauty-theme.json) | Theme màu (rose-berry, ngành làm đẹp) |
| `Socom Analytic Report.docx` | Báo cáo phân tích (phát hiện + đề xuất) — đang soạn |

---

## Công nghệ

SQL Server (T-SQL, stored procedures, MERGE, dynamic SQL) · Python / pandas / Jupyter · Power BI (semantic model, DAX, PBIP/TMDL/PBIR) · Git.
