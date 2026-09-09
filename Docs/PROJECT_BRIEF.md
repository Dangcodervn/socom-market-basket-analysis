# SOCOM — Bản tóm tắt dự án cho phiên AI mới

> **Đưa file này cho một phiên Claude (Desktop / Code) chưa biết gì về dự án.** Đọc xong là đủ ngữ cảnh để tiếp tục — không cần dò lại code.
> Cập nhật: 2026-09-09. Nếu ngày hôm nay đã xa mốc này, kiểm tra lại trạng thái model bằng MCP trước khi tin số.

---

## 1. Dự án là gì

Portfolio của một người học Data Analyst. Xây **Data Warehouse kiểu Medallion (Bronze → Silver → Gold trên SQL Server)** + **dashboard Power BI** cho **SOCOM** — nhà phân phối mỹ phẩm VN (L'Oréal Paris, Maybelline New York, Garnier).

**Bài toán phân tích:** *Tăng doanh thu, không tăng chi marketing* → 2 đòn bẩy:
1. Bịt rò rỉ — hủy đơn.
2. Tăng giá trị giỏ — cross-sell / Market Basket Analysis.

Data **không có COGS/OPEX** → **không làm P&L**. Chỉ: doanh thu · đơn · giỏ · khách · MBA.

## 2. Caveat bắt buộc nhắc trong mọi kết luận

**Dữ liệu là synthetic (2021).** Các bất thường (tỷ lệ hủy cao, dòng contra, tháng 7–8 cụt) là **artefact của bộ sinh dữ liệu**, không phải hành vi kinh doanh thật. Con số chỉ **minh hoạ phương pháp**, không phải phát hiện business thật. Footer mọi trang dashboard phải ghi điều này.

## 3. Trạng thái pipeline

| Tầng | Trạng thái | File |
| --- | --- | --- |
| Python ETL | ✅ chạy sạch, ra `Cleaned_Data/*.csv` (19,072 dòng Transaction) | `SocomDataPreprocess.ipynb` |
| Mapping sản phẩm → category/sub_category | ✅ review tay, 146 tên | `Cleaned_Data/product_category_map.xlsx` (nguồn chân lý, gitignore giữ lại) |
| Bronze / Silver / Gold SQL | ✅ DROP & CREATE, đã chạy | `SQL/Bronze,Silver,Gold/*.sql` |
| Power BI model | ✅ **đã build measure + calc column + date table + `_MBA_Pairs_Matrix` qua MCP** (xem §5) | `Power BI Project/` (PBIP) |
| Dashboard 4 trang (visual) | ⬜ **chưa dựng** — theo `Design Brief:` YAML cuối `DASHBOARD_PLAN.md`, dựng bằng skill `powerbi-report-authoring` (hoặc tay) | `Power BI Project/SocomDataAnalysis.Report/` |
| Báo cáo phân tích Word/Canva | ⬜ chưa viết | `Docs/Socom Analytic Report.docx` (khung) |

## 4. Bản đồ tài liệu (đọc theo thứ tự này)

| File | Vai trò |
| --- | --- |
| `Docs/README.md` | Entry repo cho người đọc — dự án là gì, kiến trúc, cách chạy pipeline |
| **`Docs/PROJECT_BRIEF.md`** (file này) | Điểm vào cho phiên AI — ngữ cảnh + trạng thái + model Power BI hiện tại + số nền |
| `Docs/DATA_CATALOG.md` | Mô tả từng bảng/cột Bronze/Silver/Gold |
| `Docs/DASHBOARD_PLAN.md` | Thiết kế 4 trang: câu hỏi → quyết định → stakeholder · 3 tầng đọc · archetype/variant · **+ `Design Brief:` YAML (layout_contract) ở cuối** |
| `Docs/socom-beauty-theme.json` | Theme Power BI (rose-berry, ngành làm đẹp) — merge vào `assets/base.json` khi đăng ký |

## 5. Model Power BI hiện tại (đã có sẵn — ĐỪNG tạo lại)

Kết nối: mở `Power BI Project/SocomDataAnalysis.pbip` trong Power BI Desktop; MCP `powerbi-modeling-mcp` → `connection_operations` `ListLocalInstances` → `Connect` tới `localhost:<port>` / catalog `SocomDataAnalysis`.

### 5.1 Bảng & cột (Gold star schema, prefix `gold `)

| Bảng | Cột chính |
| --- | --- |
| `gold Dim_Date` | date_id · **date** (DateTime) · year · quarter · quarter_name · month · month_name · day · week_day · week_day_name — **đã Mark as Date Table (cột `date`)** |
| `gold Dim_Customer` | customer_id (+2) |
| `gold Dim_Manufacturer` | manufacturer_id · manufacturer_name |
| `gold Dim_Category` | category_id · category_name · sub_category_name (grain = cặp category+sub) |
| `gold Dim_Product` | product_id · product_name · version · category_id · manufacturer_id |
| `gold Dim_Province` | province_id · province_name |
| `gold Dim_District` | district_id · province_id (+1) |
| `gold Dim_Gift` | gift_id (+1) |
| `gold Dim_Order` | order_id · date_id · customer_id · district_id · traffic_source · order_status · payment_method  <br>**+ calc columns (thêm qua MCP):** `distinct_products` (int) · `basket_bucket` ("1"/"2"/"3"/"4+") · `has_gift` ("Có quà"/"Không quà") |
| `gold Fact_OrderLine` | order_id · product_id · quantity · revenue · discount_amount · amount_received (grain = dòng đơn) |
| `gold Fact_Gift` | order_id · gift_id |
| `gold vw_MBA_Product_Pairs` | 9 cột — cặp sản phẩm (hack "3 từ đầu") |
| `gold vw_MBA_SubCategory_Pairs` | item_a · item_b · pair_order_count · item_a_orders · item_b_orders · support · confidence_a_to_b · confidence_b_to_a · lift — **tam giác** (a<b, không trùng cặp) |
| `_MBA_Pairs_Matrix` | **calc table (thêm qua MCP)** = view sub_category + bản đảo a↔b. Cột: item_x · item_y · pair_order_count · support · confidence · lift. Dùng cho **heatmap đầy** + bar "mua X → gợi ý" |
| `_Measures` | bảng chứa measure (§5.3) |

⚠ Còn 2 bảng auto date (`DateTableTemplate_…`, `LocalDateTable_…`) do tính năng Auto date/time. Nên tắt: File → Options → Data Load → bỏ tick **Auto date/time** cho file này (đã có Dim_Date chuẩn).

### 5.2 Quan hệ (11, tất cả single-direction, many→one)

```
Fact_OrderLine[order_id]   → Dim_Order[order_id]
Fact_OrderLine[product_id] → Dim_Product[product_id]
Dim_Product[category_id]     → Dim_Category[category_id]
Dim_Product[manufacturer_id] → Dim_Manufacturer[manufacturer_id]
Dim_Order[customer_id] → Dim_Customer[customer_id]
Dim_Order[date_id]     → Dim_Date[date_id]
Dim_Order[district_id] → Dim_District[district_id]
Dim_District[province_id] → Dim_Province[province_id]
Fact_Gift[order_id] → Dim_Order[order_id]
Fact_Gift[gift_id]  → Dim_Gift[gift_id]
Dim_Date[date] → LocalDateTable_… (auto, sẽ biến mất khi tắt Auto date/time)
```

`_Measures`, `vw_MBA_*`, `_MBA_Pairs_Matrix` **không có quan hệ** (bảng tham chiếu rời — đúng thiết kế).

### 5.3 Measure trong `_Measures` (22, chia 6 display folder)

| Folder | Measure (tên · công thức rút gọn) |
| --- | --- |
| **Revenue** | Net Revenue `SUM(Fact_OrderLine[amount_received])` · Gross Revenue `SUM([revenue])` · Discount Amount `SUM([discount_amount])` · Units Sold `SUM([quantity])` · Gross Revenue Lost `CALCULATE([Gross Revenue], Dim_Order[order_status]="Hủy")` |
| **Orders** | Orders `DISTINCTCOUNT(Dim_Order[order_id])` · Cancelled Orders `CALCULATE([Orders],…="Hủy")` · Completed Orders `CALCULATE([Orders],…="Không hủy")` · Cancel Rate `DIVIDE([Cancelled Orders],[Orders])` |
| **Basket & AOV** | AOV `DIVIDE([Net Revenue],[Completed Orders])` · Basket Size (AVERAGEX distinct product_id / đơn, lọc "Không hủy") · Single-item Order % · AOV (Gift) · AOV (No Gift) |
| **Customer** | Customers `DISTINCTCOUNT(Dim_Order[customer_id])` · Repeat Customers (khách ≥2 đơn) · Repeat Customer Rate |
| **Time Intelligence** | Net Revenue PM `CALCULATE([Net Revenue], DATEADD(Dim_Date[date],-1,MONTH))` · Net Revenue MoM % |
| **MBA** | Pair Priority Score `MAX(lift)*LN(MAX(pair_order_count))` · Avg Lift · Max Confidence |

`order_status` chỉ có 2 giá trị: **"Hủy"** và **"Không hủy"**.

## 6. Số nền (đã kiểm bằng DAX 2026-09-09, chưa lọc)

| Chỉ số | Giá trị |
| --- | --- |
| Net Revenue | 1,922,668,633 |
| Gross Revenue | 2,887,525,544 |
| Orders / Completed / Cancelled | 5,908 / 4,294 / 1,614 |
| Cancel Rate (theo đơn) | 27.3% |
| AOV | 447,757 |
| Basket Size | 2.47 |
| Single-item Order % | 44.0% |
| AOV có quà / không quà | 552,321 / 425,485 (**+30%**) |
| Customers / Repeat / Repeat Rate | 2,257 / 422 / 18.7% |
| MBA top lift (pair_order_count ≥ 15) | Color↔Treatment 10.1 (15 đơn) · Cleansing↔Treatment 8.4 (56) · Lip Care↔Khác 5.3 (105) |
| Doanh thu theo tháng | Jan–Jun đầy đủ · **Jul ≈ 0 · Aug cụt** (synthetic) |

## 7. Công cụ Power BI

- **MCP `powerbi-modeling-mcp`** — tầng **model** (table / column / measure / relationship / calc group / RLS / chạy DAX / refresh). KHÔNG tạo visual/trang. Nếu báo *"declined when asked to confirm"*: `.mcp.json` cần `--skipconfirmation` (đã set) + restart.
- **Plugin `powerbi-authoring@fabric-collection`** (đã cài) — skill `powerbi-report-design` (sinh design brief) + `powerbi-report-authoring` (ghi PBIR: trang/visual/theme) qua CLI `powerbi-report-author` + `powerbi-desktop` (đã cài global). **Chỉ chạy trên PBIP**, không chạy `.pbix`.

## 8. Việc còn lại

1. Dựng 4 trang dashboard từ `Design Brief:` YAML cuối `DASHBOARD_PLAN.md` → skill `powerbi-report-authoring` ghi vào `Power BI Project/SocomDataAnalysis.Report/`, `validate` sau mỗi batch, verify bằng `powerbi-desktop` reload+screenshot.
2. Chạy phân tích trên số đã lọc → điền **tiêu đề visual = câu kết luận có số**.
3. Viết báo cáo phân tích (`Docs/Socom Analytic Report.docx` hoặc Canva): 3–4 phát hiện + 3 đề xuất map 1-1 + định lượng cơ hội + caveat synthetic.
4. (tùy chọn) Tạo hierarchy `Category ▸ Sub-category`; tắt Auto date/time; `git rm --cached SocomDataAnalysis.pbix` (đã có PBIP).

## 9. Ràng buộc làm việc

- Git: chỉ commit/push khi được yêu cầu; đang ở nhánh `main`, tạo nhánh trước nếu commit.
- Commit trailer: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. PR body: `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- Email user `dangvn2003@gmail.com` — chỉ để nhận diện tác giả, không gửi đi đâu.
