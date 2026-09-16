# SOCOM: Kế hoạch dashboard (4 trang, theo câu hỏi)

> **Đã build xong: file này là bản thiết kế GỐC, không phải mô tả sản phẩm cuối.** Dashboard 4 trang thật nằm ở `Power BI Project/SocomDataAnalysis.Report/` (xem kết quả + screenshot ở `README.md` gốc repo). Giữ file này lại để lưu tư duy thiết kế (archetype/variant/layout contract), nhưng bản build cuối **đã lệch khỏi plan ở vài điểm đáng chú ý**, không chỉnh lại toàn bộ:
> - **Màu:** phần "Hệ thống thiết kế" và `color_map` YAML bên dưới mô tả palette rose-berry/ivory dự kiến ban đầu: bản build thật dùng theme `Power BI Theme by BIBB.json` (dải magenta-tím `#7A0177→#FFF7F3`, chữ xanh đen `#0A2B43`, nền trắng), khác hẳn. Xem màu thật qua screenshot `Imgs/` hoặc mở theme file.
> - **Vài chart:** ví dụ Trang 1 dùng donut + bản đồ tỉnh thay vì 100%-stacked-bar + bar ngang top-8-tỉnh như plan gốc.
> - **Số liệu:** số measure/folder bên dưới (22-24, 6 folder) là snapshot lúc lên kế hoạch; số cuối cùng là **49 measure / 7 folder**, xem `README.md`.
>
> Khung quyết định: **"Tăng doanh thu, không tăng chi marketing"** → 2 đòn bẩy: bịt rò rỉ (hủy đơn) + tăng giá trị giỏ (cross-sell / MBA).
> Data không có COGS/OPEX → **không làm P&L**. Chỉ doanh thu + đơn + giỏ + khách + MBA.
> Bản này đã rà theo skill `powerbi-report-design` (archetype + variant + anti-patterns). Khối `Design Brief:` YAML để dựng tự động nằm ở **cuối file** (§ *Canonical design contract*).

---

## 3 nguyên tắc bắt buộc (mọi trang phải qua được)

1. **Bắt đầu từ câu hỏi kinh doanh, không từ dữ liệu.** Mỗi trang = 1 câu hỏi → 1 quyết định → 1 stakeholder.
2. **Bố cục theo logic đọc: overview → chi tiết → hành động.**
   - Cấp report: Trang 1 overview · Trang 2–3 chi tiết 2 đòn bẩy · Trang 4 hành động (luật cross-sell).
   - Cấp từng trang: 3 tầng từ trên xuống (F-pattern):
     | Tầng | Nội dung | Trả lời |
     | --- | --- | --- |
     | **Đỉnh** | KPI + MoM ▲▼ | "đang ở đâu" |
     | **Giữa** | breakdown theo chiều | "dồn ở đâu / vì sao" |
     | **Đáy** | **1 bảng xếp theo mức ưu tiên** (không phải câu chữ) | "làm gì trước" |
3. **Luôn hỏi: stakeholder này ra quyết định gì sau khi nhìn xong?** Nếu không trả lời được → bỏ visual đó.

> Phân tích "vì sao + đề xuất" **không** viết trên canvas → đi vào báo cáo Word/Canva. Trên dashboard, tầng "hành động" là **object quyết định được** (bảng ưu tiên / hàng đợi).

---

## Hệ thống thiết kế (dùng chung 4 trang)

**Canvas:** 1920×1080 (FHD, mặc định của skill: nét khi chụp screenshot portfolio). Lưới **8px**, gutter 24px, margin 32px. Mỗi trang có **band tiêu đề ~72px**: tiêu đề trang bên trái, slicer bên phải; visual bắt đầu **dưới** band, không đè.

**Màu**: theme `Power BI Theme by BIBB.json` (root repo), nhưng **merge vào bản copy của `assets/base.json`** của skill trước khi đăng ký (giữ safeguard: padding textbox, cardVisual zero-padding, table grow-to-fit, ẩn visual header). Không đăng ký theme tối giản trần.

| Vai trò | Mã | Dùng ở đâu |
| --- | --- | --- |
| Nền trang | `#FBF8F6` (trắng ngà ấm) · card `#FFFFFF` | |
| Chữ / trục | `#2B2724` (nâu-đen) | |
| Không-nhấn / context | `#CFC4BD` taupe · gridline `#EDE6E1` | bar/line không trọng tâm |
| **Nhấn (accent)** | `#C13B6A` rose-berry = `dataColors[0]` | số KPI, series đang nói, bar focus |
| **Cảnh báo** | `#B23A48` (bad) · `#C8763C` (neutral) · `#3E7C5A` (good) | KPI ▲▼ + conditional formatting. Hủy đơn = bad → tự ra đỏ-berry |
| **Ramp heatmap Trang 4** | `#F6E1EA → (tại lift=1) #EDE6E1 → #7A2547` | min → center → max |

> ≤ 3 màu *có nghĩa* / trang (accent + muted + 1 semantic). **Không mã hoá màu cho > 2–3 nhóm**: bar sắp xếp cùng màu + nhấn 1. Trạng thái luôn kèm kênh phụ (mũi tên/icon), không chỉ màu.

**KPI card:** số lớn (28–36pt) · nhãn nhỏ phía trên · dòng dưới = `MoM % + mũi tên ▲▼ + màu` (màu theo **nghĩa từng chỉ số**: hủy đơn giảm là TỐT → xanh) · sparkline 12 tháng. **Mọi thẻ đều có MoM + mũi tên**: không để thẻ trần.

**Tiêu đề visual = KẾT LUẬN** có số, không phải nhãn. Điền **sau** khi có số thật. VD: "44% đơn chỉ mua 1 sản phẩm" thay vì "Số sản phẩm mỗi đơn".

**Alt text** insight-driven trên mọi visual (không để trống).

**Nav trái:** 4 nút (Tổng quan · Hủy đơn · Giỏ hàng · MBA), dùng bookmark + button. Footer mọi trang: *"Nguồn: SOCOM · dữ liệu synthetic 2021 · số minh hoạ phương pháp"*.

**Slicer:** `Tháng` · `Category` · `Kênh`. **Trang 1 chỉ hiện `Tháng` trên canvas**, Category/Kênh vào Filter pane (giữ mục tiêu "quét ≤10s"). Trang 2–3 hiện cả 3, **sync**. Trang 4 slicer riêng (`pair_order_count`, `item_x`).

**Edit interactions:** khai báo có chủ đích mỗi trang: visual nào KHÔNG cross-filter (vd click bar breakdown ở T2 không refilter KPI theo cách gây rối).

**Chống chỉ định:** gauge · donut nhiều lát · 3D · dual-axis · tiêu đề dạng nhãn · bar không bắt đầu từ 0 · mũi tên đỏ khi "giảm" mà giảm là tốt · > 7 visual/trang · slicer ở góc trên-trái (x<200,y<100) · treemap là lựa chọn mã hoá yếu (hạng #6/8): chỉ dùng khi tỷ trọng là thông điệp.

---

## TRANG 1: Tổng quan

**Archetype:** Executive Summary · **Variant B (KPI-Strip)**: 5 KPI ngang nhau, không 1 hero đơn lẻ.
**Stakeholder:** Chủ DN / quản lý chung.
**Quyết định cần ra:** Có cần can thiệp không? Ưu tiên đòn bẩy nào: hủy đơn hay giỏ nhỏ?
**Câu hỏi:** Business đang khoẻ không? Doanh thu đến từ đâu?

- **Đỉnh:** 5 KPI card + MoM ▲▼.
- **Giữa:** doanh thu theo tháng (line) · doanh thu theo category▸sub (composition).
- **Đáy (ở trang này = trỏ đi):** bar nhãn + bar tỉnh cho biết "tiền nằm ở đâu"; kết luận hành động ("siết hủy đơn hay đẩy cross-sell") ra ở Trang 2/3.

```
[Tháng ▼]
┌────────┬────────┬────────┬────────┬────────┐
│ Net Rev│ Đơn    │ AOV    │ Cancel │ Repeat │  ← 5 KPI card, đều có MoM ▲▼
│ ▲5%    │ hoàn▼2%│ ▲3%    │ Rate▲  │ ▲8%    │
├────────┴───┬────┴────────┴───┬────┴────────┤
│ Doanh thu   │ Doanh thu theo category▸sub  │
│ net / tháng │ (100% stacked bar HOẶC       │
│ (line)      │  matrix: xem ghi chú)       │
├─────────────┼─────────────────────────────┤
│ Doanh thu   │ Doanh thu Top 8 tỉnh        │
│ theo nhãn   │ (bar ngang)                 │
│ (bar ngang) │                             │
└─────────────┴─────────────────────────────┘
```

| Ô | Loại | Field / Measure |
| --- | --- | --- |
| KPI 1 | Card | `[Net Revenue]` + `[Net Revenue MoM %]` |
| KPI 2 | Card | `[Completed Orders]` + MoM |
| KPI 3 | Card | `[AOV]` + MoM |
| KPI 4 | Card | `[Cancel Rate]` + MoM (màu: tăng = đỏ) |
| KPI 5 | Card | `[Repeat Customer Rate]` + MoM |
| Trend | Line | `[Net Revenue]` × `Dim_Date[month_name]` (sort theo `month`) |
| Composition | **100% stacked bar** (khuyến nghị) | Trục = `Dim_Category[category_name]` · Legend = `Dim_Category[sub_category_name]` · Giá trị = `[Net Revenue]`. *Thay thế: Matrix rows `category_name`▸`sub_category_name`, values `[Net Revenue]` + `% GT` nếu cần đọc số. Treemap chỉ chọn nếu ưu tiên "một hình thấy cả 2 cấp" hơn độ chính xác.* |
| Bar nhãn | Bar ngang | `[Net Revenue]` × `Dim_Manufacturer[manufacturer_name]` (4 nhãn), sort desc |
| Bar tỉnh | Bar ngang | `[Net Revenue]` × `Dim_Province[province_name]`, Top 8, sort desc |

*(Nếu muốn 3 slicer đồng nhất cả 3 trang → Trang 1 thành Analytical Canvas / Variant B; chấp nhận đánh đổi mục tiêu quét-nhanh.)*

---

## TRANG 2: Rò rỉ doanh thu (Hủy đơn)

**Archetype:** Comparative / Benchmark · **Variant A (Side-by-Side)**: headline ranked-Δ bar + small multiples.
**Stakeholder:** Vận hành / CSKH.
**Quyết định cần ra:** Siết quy trình xác nhận đơn ở **nhóm nào** (COD? kênh nào? nhóm hàng nào)?
**Câu hỏi:** Mất bao nhiêu vì hủy? Dồn ở đâu?

- **Đỉnh:** 3 KPI: Cancel Rate, Gross Revenue Lost, Cancelled Orders.
- **Giữa:** Cancel Rate theo 4 chiều: payment_method · traffic_source · sub_category · tháng (small multiples / bar, **sắp desc**, cùng thang %).
- **Đáy (hành động):** **Hàng đợi đơn hủy giá trị cao**: bảng sắp `[Gross Revenue]` desc, Top 20. Dòng trên cùng = đơn cần rà trước.

```
[Tháng ▼] [Category ▼] [Kênh ▼]
┌──────────┬──────────┬──────────┐
│ Cancel   │ Gross Rev│ Đơn hủy  │  ← 3 KPI
│ Rate ▲   │ Lost     │ N        │
├──────────┴────┬─────┴──────────┤
│ Cancel Rate    │ Cancel Rate    │
│ × payment      │ × kênh         │
├────────────────┼────────────────┤
│ Cancel Rate    │ Cancel Rate    │
│ × sub_category │ × tháng (line) │
├────────────────┴────────────────┤
│ HÀNG ĐỢI: đơn hủy giá trị cao   │
│ order_id·kênh·pttt·tỉnh·gross   │
│: sort gross DESC, Top 20       │
└─────────────────────────────────┘
```

| Ô | Loại | Field / Measure | Đi tìm gì |
| --- | --- | --- | --- |
| KPI Cancel Rate | Card | `[Cancel Rate]` + MoM | mức độ + xu hướng |
| KPI Gross Lost | Card | `[Gross Revenue Lost]` | quy ra tiền |
| KPI Đơn hủy | Card | `[Cancelled Orders]` | |
| Hủy × thanh toán | Bar, sort desc | `[Cancel Rate]` × `Dim_Order[payment_method]` | COD thường cao |
| Hủy × kênh | Bar, sort desc | `[Cancel Rate]` × `Dim_Order[traffic_source]` | kênh lead rác |
| Hủy × sub_category | Bar, sort desc | `[Cancel Rate]` × `Dim_Category[sub_category_name]` | nhóm hàng nào hủy nhiều |
| Hủy × tháng | Line | `[Cancel Rate]` × `Dim_Date[month_name]` | mùa vụ / xu hướng |
| **Hàng đợi đơn hủy** | Table, sort `[Gross Revenue]` desc, Top 20 | `Dim_Order[order_id/traffic_source/payment_method]` + `Dim_Province[province_name]` + `[Gross Revenue]`, filter `order_status = "Hủy"` | đơn to bị hủy → xử lý trước; data bar trên cột gross |

> So-what ("hủy dồn ở COD + kênh X → siết xác nhận COD / rà lead kênh X") → **báo cáo Word**, không lên canvas.

---

## TRANG 3: Giỏ hàng nhỏ & Cross-sell

**Archetype:** Analytical Canvas · **Variant B (Inline-Slicers)**: 3 slicer inline, nội dung full-width, câu hỏi tập trung.
**Stakeholder:** Marketing / merchandising.
**Quyết định cần ra:** Đặt **ngưỡng freeship** bao nhiêu? Gợi ý mua kèm **nhóm nào** trước?
**Câu hỏi:** Vì sao giỏ nhỏ? Cái gì kéo giỏ to hơn?

- **Đỉnh:** 4 KPI: AOV, Basket Size, Single-item Order %, AOV có quà vs không quà.
- **Giữa:** phân bố kích thước giỏ (histogram bucket) · AOV × kênh (combo) · hiệu ứng quà (bar).
- **Đáy (hành động):** **Bảng dư địa cross-sell theo sub_category**: sắp theo dư địa giảm dần; dòng đầu = nhóm nên đẩy mua kèm trước.

```
[Tháng ▼] [Category ▼] [Kênh ▼]
┌──────┬──────┬──────┬───────────────┐
│ AOV  │Basket│ %1-SP│ AOV quà vs ko │  ← 4 KPI
├──────┴──┬───┴──────┴───────────────┤
│ Histogram │ AOV (line) + số đơn     │
│ bucket    │ (cột) × kênh           │
│ 1/2/3/4+  │                        │
├───────────┼────────────────────────┤
│ Hiệu ứng  │ (chừa) hoặc mở rộng    │
│ quà (bar) │                        │
├───────────┴────────────────────────┤
│ DƯ ĐỊA CROSS-SELL theo sub_category │
│ %đơn ≥2 SP · AOV · dư địa: desc    │
└────────────────────────────────────┘
```

| Ô | Loại | Field / Measure | Ghi chú |
| --- | --- | --- | --- |
| KPI AOV | Card | `[AOV]` + MoM | |
| KPI Basket Size | Card | `[Basket Size]` | |
| KPI % 1-SP | Card | `[Single-item Order %]` | |
| KPI AOV quà | 2 Card | `[AOV (Gift)]` · `[AOV (No Gift)]` | so sánh cạnh nhau |
| Histogram giỏ | Column theo bucket | `Dim_Order[basket_bucket]` (calc column ✓ đã tạo) · Y = `[Orders]` · cột "1" tô accent | |
| AOV × kênh | Combo | `[AOV]` (line) + `[Completed Orders]` (cột) × `Dim_Order[traffic_source]` | |
| Hiệu ứng quà | Column | `[AOV]` & `[Basket Size]` × `Dim_Order[has_gift]` (calc column ✓) | |
| **Bảng dư địa cross-sell** | Table, sort `[Cross-sell Attach Rate]` **tăng dần** | `Dim_Category[sub_category_name]` · `[Completed Orders]` · `[Cross-sell Attach Rate]` · `[AOV]` | attach rate thấp = dư địa cao = đẩy mua kèm trước |

> So-what ("45% đơn lẻ + đơn có quà +30% AOV → dư địa cross-sell lớn → ngưỡng freeship / gợi ý mua kèm") → **báo cáo Word**.

---

## TRANG 4: MBA (Cross-sell rules)

**Archetype:** Analytical Canvas · **Variant A (Filter-Rail)**: slicer ngưỡng + `item_x` làm rail, heatmap là hero. Khám phá, KHÔNG theo dõi định kỳ.
**Stakeholder:** Merchandising / CRM.
**Quyết định cần ra:** **Combo/bundle cặp nào** làm ngay? Cặp nào để email cá nhân hoá?
**Câu hỏi:** Nên gợi ý mua kèm gì?

- **Đỉnh:** slicer ngưỡng `pair_order_count ≥ 15` + (tùy chọn) KPI `[Avg Lift]`, `[Max Confidence]`.
- **Giữa:** heatmap sub×sub (màu = lift) · bar "mua X → gợi ý" (confidence, nhãn lift).
- **Đáy (hành động):** **Bảng ưu tiên** sắp theo `[Pair Priority Score]` desc = cặp đáng làm trước.

```
[pair_order_count ≥ ══O══ 15]   [item_x ▼]
┌──────────────────────────────┬──────────────────────────┐
│ Heatmap sub × sub            │ Bảng luật (pair≥15,      │
│ (Matrix, màu nền = lift)     │ sort lift desc):        │
│ dùng _MBA_Pairs_Matrix       │ A│B│pair│supp│conf│lift │
├──────────────────────────────┴──────────────────────────┤
│ "Khách mua [item_x] → gợi ý:" bar item_y theo           │
│  confidence, data label = lift   (dùng _MBA_Pairs_Matrix)│
├─────────────────────────────────────────────────────────┤
│ BẢNG ƯU TIÊN: A·B·pair·lift·[Pair Priority Score]: desc │
└─────────────────────────────────────────────────────────┘
```

| Ô | Loại | Field | Ghi chú |
| --- | --- | --- | --- |
| Slicer ngưỡng | Numeric range | `_MBA_Pairs_Matrix[pair_order_count]` | mặc định ≥ 15 |
| Slicer nhóm | List, single-select | `_MBA_Pairs_Matrix[item_x]` | cho bar "mua X → gợi ý" |
| Heatmap | Matrix: `item_x` (rows) × `item_y` (cols), value = `lift` (Average), background gradient | `_MBA_Pairs_Matrix` (✓ đã tạo, ma trận đầy) | gradient `#F6E1EA → #EDE6E1 tại lift=1 → #7A2547` |
| Bảng luật | Table | `gold vw_MBA_SubCategory_Pairs`, sort `lift` desc, filter `pair_order_count ≥ 15` | tam giác (không trùng cặp) |
| Bar gợi ý | Bar ngang | `_MBA_Pairs_Matrix` filter `item_x` = slicer, trục `item_y`, sort `confidence` desc, tooltip/label `lift` | |
| **Bảng ưu tiên** | Table, sort `[Pair Priority Score]` desc | `gold vw_MBA_SubCategory_Pairs` + `[Pair Priority Score]`, filter `pair_order_count ≥ 15` | cột: A·B·pair·lift·score |

**Khung ưu tiên (2 trục: quy mô × lift):**
| | lift cao | lift ≈ 1 |
| --- | --- | --- |
| quy mô cao | **làm ngay** (bundle) | ngưỡng freeship / bundle mặc định |
| quy mô thấp | gợi ý cá nhân hoá / email | bỏ |

**Textbox diễn giải** (ngoại lệ được phép: định nghĩa, KHÔNG phải phân tích; đủ cao để không ra scrollbar):
- `support` = % giỏ có cả A và B · `confidence(A→B)` = trong đơn mua A, % cũng mua B (**có hướng**)
- `lift` > 1 bổ trợ · = 1 độc lập · < 1 thay thế (**đối xứng**) · chỉ tin cặp `pair_order_count ≥ 15`

---

## Trạng thái model (snapshot lúc lên kế hoạch: số cuối cùng: 49 measure / 7 folder, xem `README.md`)

| Hạng mục | Trạng thái |
| --- | --- |
| `_Measures` (22 measure / 6 folder lúc lên kế hoạch) | ✅ |
| `gold Dim_Date` Mark as Date Table | ✅ |
| `gold Dim_Order` calc columns: `distinct_products` · `basket_bucket` · `has_gift` | ✅ |
| `_MBA_Pairs_Matrix` (heatmap đầy) | ✅ |
| Hierarchy `Category ▸ Sub-category` | ⬜ (tùy chọn, làm tay 30s) |
| Tắt Auto date/time | ⬜ |

**Measure theo trang:**

| Trang | Measure |
| --- | --- |
| 1 | Net Revenue · Net Revenue MoM % · Completed Orders · AOV · Cancel Rate · Repeat Customer Rate |
| 2 | Cancel Rate · Gross Revenue Lost · Cancelled Orders |
| 3 | AOV · Basket Size · Single-item Order % · AOV (Gift) · AOV (No Gift) · Completed Orders |
| 4 | cột view + `Pair Priority Score` · Avg Lift · Max Confidence |

---

## Thứ tự build

1. ✅ (qua MCP) Mark Date table · measure (lúc lên kế hoạch: 22, cuối cùng: 49) · calc column · `_MBA_Pairs_Matrix`.
2. **Design contract**: khối `Design Brief:` YAML ở cuối file này (§ *Canonical design contract*): archetype + variant + `layout_contract` từng trang. Hợp đồng cho `powerbi-report-authoring`.
3. **Theme**: merge màu `Power BI Theme by BIBB.json` vào bản copy `assets/base.json`, đăng ký vào PBIP.
4. **Dựng PBIR**: skill `powerbi-report-authoring` + CLI `powerbi-report-author` ghi trang/visual vào `Power BI Project/SocomDataAnalysis.Report/`; `validate` sau mỗi batch.
5. **Verify**: mở Power BI Desktop (`powerbi-desktop` bridge) reload + screenshot; đối chiếu `preflight`.
6. **Chạy phân tích trên số thật** → điền **tiêu đề visual = kết luận**. Phát hiện/đề xuất → báo cáo Word, KHÔNG lên canvas.

> **Dựng tay (không dùng skill):** mở PBIP trong Power BI Desktop, làm theo `layout_contract` từng trang: mỗi `placement` = 1 visual (`kind` = loại visual · `region` = ô lưới · `field_bindings` = field vào well). Import theme, thêm nav bookmark + footer, rồi đối chiếu `preflight`.

## 2 deliverable: 2 kỹ năng tách bạch

| Deliverable | Công cụ | Vai trò |
| --- | --- | --- |
| **Dashboard** (PBIP 4 trang) | Power BI Project (`Power BI Project/`) | Monitoring: số + xu hướng. Showcase **build** (model, DAX, design) |
| **Báo cáo phân tích** | Word (đầy đủ) hoặc Canva (slide) | 3–4 phát hiện + 3 đề xuất map 1-1 + định lượng cơ hội + bằng chứng + caveat "synthetic 2021". Showcase **tư duy** |

Báo cáo cấu trúc: bối cảnh & câu hỏi → cách làm (1 đoạn) → mỗi phát hiện = *số + hình dạng dữ liệu + "vậy thì sao"* → đề xuất map 1-1 → caveat. Ảnh dashboard chỉ làm minh chứng.

---

## Canonical design contract

Khối `Design Brief:` YAML dưới đây là **authoritative** cho việc dựng PBIR: `powerbi-report-authoring` đọc trực tiếp. Prose phía trên để người duyệt; YAML để tool.
Region ghi theo `[col_start, row_start, col_end_excl, row_end_excl]` trên lưới 12×12 (cột 1..13, hàng 1..13). Model đã có sẵn: xem `DATA_CATALOG.md` (SQL) hoặc mở model trong Power BI Desktop.

```yaml
Design Brief:
  generated_by: powerbi-report-design
  contract_version: 1
  mode: greenfield
  design_identity:
    tone: >-
      Refined retail: calm and editorial. Warm ivory ground (#FBF8F6), one
      rose-berry accent (#C13B6A), generous whitespace, Segoe UI Semibold titles
      written as one-sentence numeric conclusions. Muted taupe for context marks.
    signature: >-
      Rose-berry left accent bar on every KPI card and section header; every
      visual title is a numeric conclusion, not a label.
  archetype: Executive + Drill (multi-domain)  # P1 Executive, P2 Comparative, P3+P4 Analytical
  theme_base: assets/base.json  # merge "Power BI Theme by BIBB.json" dataColors/tokens INTO a copy; keep base safeguards
  page_background: "#FBF8F6"
  color_map:
    - measure: "'_Measures'[Net Revenue]"
      color: "#C13B6A"
      tint: "#F6E1EA"
    - measure: "'_Measures'[AOV]"
      color: "#C13B6A"
      tint: "#F6E1EA"
    - measure: "'_Measures'[Completed Orders]"
      color: "#8C6D62"
      tint: "#EDE6E1"
    - measure: "'_Measures'[Cancel Rate]"
      color: "#B23A48"        # semantic bad: cancel up = red
      tint: "#F3D9DC"
    - measure: "'_Measures'[Gross Revenue Lost]"
      color: "#B23A48"
      tint: "#F3D9DC"
    - measure: "'_Measures'[Repeat Customer Rate]"
      color: "#3E7C5A"
      tint: "#DDE9E1"
    - measure: "'_Measures'[Basket Size]"
      color: "#C13B6A"
      tint: "#F6E1EA"
    - measure: "'_MBA_Pairs_Matrix'[lift]"
      color: "#7A2547"        # gradient max for heatmap
      tint: "#F6E1EA"
  slicers:
    sync_group: soc_main            # Tháng / Category / Kênh: synced P1..P3
    controls:
      - field: "'gold Dim_Date'[month_name]"
        type: dropdown
        sort_by: "'gold Dim_Date'[month]"
        pages: [p1, p2, p3]         # p1 shows ONLY this on canvas
      - field: "'gold Dim_Category'[category_name]"
        type: dropdown
        pages: [p2, p3]             # p1: Filter pane only
      - field: "'gold Dim_Order'[traffic_source]"
        type: dropdown
        pages: [p2, p3]
  navigation:
    kind: bookmark_buttons
    items: ["Tổng quan", "Hủy đơn", "Giỏ hàng", "MBA"]
    placement: top-left of header band, left of page title is footer nav strip
  footer_text: "Nguồn: SOCOM · dữ liệu synthetic 2021 · số minh hoạ phương pháp"

  pages:

    - name: "Tổng quan: doanh thu ổn định, đòn bẩy nằm ở hủy đơn và giỏ nhỏ"
      id: p1
      role: landing
      archetype: Executive
      layout_variant: B          # KPI-Strip: 5 KPIs of comparable weight, no single hero
      variant_rationale: "5 KPI ngang tầm quan trọng, không có 1 hero metric: KPI strip IS the message."
      stakeholder: "Chủ DN / quản lý chung"
      decision: "Có cần can thiệp không? Ưu tiên đòn bẩy nào: hủy đơn hay giỏ nhỏ?"
      layout_contract:
        canvas: { width: 1920, height: 1080, margin: 32, gutter: 24, snap: 8 }
        grid:
          columns: 12
          rows: 12
          regions:
            header:   [1, 1, 10, 2]
            filters:  [10, 1, 13, 2]
            kpi:      [1, 2, 13, 4]
            mid_left: [1, 4, 7, 8]
            mid_right:[7, 4, 13, 8]
            low_left: [1, 8, 7, 13]
            low_right:[7, 8, 13, 13]
        placements:
          - { id: page_title, region: header, kind: textbox, text: "Tổng quan: doanh thu ổn định, đòn bẩy nằm ở hủy đơn và giỏ nhỏ" }
          - { id: slicer_month, region: filters, kind: slicer, field_bindings: "'gold Dim_Date'[month_name]", purpose: "Kỳ xem" }
          - { id: kpi_net_rev,   region: kpi, kind: cardVisual, purpose: "Doanh thu net + MoM", field_bindings: ["'_Measures'[Net Revenue]", "'_Measures'[Net Revenue MoM %]"] }
          - { id: kpi_completed, region: kpi, kind: cardVisual, purpose: "Đơn hoàn tất + MoM", field_bindings: ["'_Measures'[Completed Orders]", "'_Measures'[Completed Orders MoM %]"] }
          - { id: kpi_aov,       region: kpi, kind: cardVisual, purpose: "AOV + MoM", field_bindings: ["'_Measures'[AOV]", "'_Measures'[Net Revenue MoM %]"] }
          - { id: kpi_cancel,    region: kpi, kind: cardVisual, purpose: "Cancel Rate + MoM (tăng = đỏ)", field_bindings: ["'_Measures'[Cancel Rate]"] }
          - { id: kpi_repeat,    region: kpi, kind: cardVisual, purpose: "Repeat Customer Rate + MoM", field_bindings: ["'_Measures'[Repeat Customer Rate]"] }
          - { id: trend_revenue, region: mid_left, kind: lineChart, purpose: "Doanh thu net theo tháng", field_bindings: { axis: "'gold Dim_Date'[month_name]", values: "'_Measures'[Net Revenue]" } }
          - { id: composition_cat_sub, region: mid_right, kind: hundredPercentStackedBarChart, purpose: "Cơ cấu doanh thu theo category▸sub_category", field_bindings: { axis: "'gold Dim_Category'[category_name]", legend: "'gold Dim_Category'[sub_category_name]", values: "'_Measures'[Net Revenue]" } }
          - { id: bar_manufacturer, region: low_left, kind: barChart, purpose: "Doanh thu theo nhãn (4)", field_bindings: { axis: "'gold Dim_Manufacturer'[manufacturer_name]", values: "'_Measures'[Net Revenue]" } }
          - { id: bar_province_top8, region: low_right, kind: barChart, purpose: "Top 8 tỉnh theo doanh thu", field_bindings: { axis: "'gold Dim_Province'[province_name]", values: "'_Measures'[Net Revenue]" } }
        space_audit:
          content_cell_count: 120
          placed_cell_count: 120
          empty_cell_pct: 0
          unplaced_regions: []
          largest_region: { name: kpi, pct_of_content: 20 }
          balance_rationale: "KPI strip = message; 4 supporting visuals equal weight below."

    - name: "Hủy đơn: 27% đơn mất, dồn ở [nhóm điền sau]"
      id: p2
      role: detail
      archetype: Comparative
      layout_variant: A          # Side-by-Side: rank cancel-rate across segments + small multiples
      variant_rationale: "Câu hỏi là 'cancel rate relative to what': xếp hạng segment theo tỷ lệ hủy; small multiples 4 chiều."
      stakeholder: "Vận hành / CSKH"
      decision: "Siết quy trình xác nhận đơn ở nhóm nào (COD? kênh nào? nhóm hàng nào)?"
      layout_contract:
        canvas: { width: 1920, height: 1080, margin: 32, gutter: 24, snap: 8 }
        grid:
          columns: 12
          rows: 12
          regions:
            header:  [1, 1, 9, 2]
            filters: [9, 1, 13, 2]
            kpi:     [1, 2, 13, 4]
            bd_tl:   [1, 4, 7, 7]
            bd_tr:   [7, 4, 13, 7]
            bd_bl:   [1, 7, 7, 10]
            bd_br:   [7, 7, 13, 10]
            action:  [1, 10, 13, 13]
        placements:
          - { id: page_title, region: header, kind: textbox, text: "Hủy đơn: 27% đơn mất, dồn ở [nhóm điền sau]" }
          - { id: slicers_p2, region: filters, kind: slicer, field_bindings: ["'gold Dim_Date'[month_name]", "'gold Dim_Category'[category_name]", "'gold Dim_Order'[traffic_source]"], purpose: "3 slicer synced" }
          - { id: kpi_cancel_rate, region: kpi, kind: cardVisual, purpose: "Cancel Rate + MoM", field_bindings: ["'_Measures'[Cancel Rate]"] }
          - { id: kpi_gross_lost,  region: kpi, kind: cardVisual, purpose: "Gross Revenue Lost", field_bindings: ["'_Measures'[Gross Revenue Lost]"] }
          - { id: kpi_cancelled,   region: kpi, kind: cardVisual, purpose: "Số đơn bị hủy", field_bindings: ["'_Measures'[Cancelled Orders]"] }
          - { id: cancel_by_payment, region: bd_tl, kind: barChart, purpose: "Cancel Rate theo phương thức thanh toán (sort desc)", field_bindings: { axis: "'gold Dim_Order'[payment_method]", values: "'_Measures'[Cancel Rate]" } }
          - { id: cancel_by_channel, region: bd_tr, kind: barChart, purpose: "Cancel Rate theo kênh (sort desc)", field_bindings: { axis: "'gold Dim_Order'[traffic_source]", values: "'_Measures'[Cancel Rate]" } }
          - { id: cancel_by_subcat, region: bd_bl, kind: barChart, purpose: "Cancel Rate theo sub_category (sort desc)", field_bindings: { axis: "'gold Dim_Category'[sub_category_name]", values: "'_Measures'[Cancel Rate]" } }
          - { id: cancel_by_month, region: bd_br, kind: lineChart, purpose: "Cancel Rate theo tháng", field_bindings: { axis: "'gold Dim_Date'[month_name]", values: "'_Measures'[Cancel Rate]" } }
          - { id: cancel_queue, region: action, kind: tableEx, purpose: "Hàng đợi đơn hủy giá trị cao: xử lý trước", field_bindings: { columns: ["'gold Dim_Order'[order_id]", "'gold Dim_Order'[traffic_source]", "'gold Dim_Order'[payment_method]", "'gold Dim_Province'[province_name]", "'_Measures'[Gross Revenue]"] }, sort: "'_Measures'[Gross Revenue] desc", filter: "'gold Dim_Order'[order_status] = \"Hủy\"", top_n: 20, notes: "data bar trên cột Gross Revenue" }
        space_audit:
          content_cell_count: 120
          placed_cell_count: 120
          empty_cell_pct: 0
          unplaced_regions: []
          largest_region: { name: action, pct_of_content: 20 }
          balance_rationale: "4 breakdown ngang tầm ở giữa; hàng đợi hành động chiếm đáy full-width."

    - name: "Giỏ hàng: 44% đơn mua 1 SP, đơn có quà +30% AOV"
      id: p3
      role: detail
      archetype: Analytical
      layout_variant: B          # Inline-Slicers: 3 slicers, focused question, content full-width
      variant_rationale: "3 slicer (< 4) → không cần rail; câu hỏi tập trung 'cái gì kéo giỏ to hơn'."
      stakeholder: "Marketing / merchandising"
      decision: "Đặt ngưỡng freeship bao nhiêu? Gợi ý mua kèm nhóm nào trước?"
      layout_contract:
        canvas: { width: 1920, height: 1080, margin: 32, gutter: 24, snap: 8 }
        grid:
          columns: 12
          rows: 12
          regions:
            header:  [1, 1, 8, 2]
            filters: [8, 1, 13, 2]
            kpi:     [1, 2, 13, 4]
            mid_left:  [1, 4, 7, 8]
            mid_right: [7, 4, 13, 8]
            low_left:  [1, 8, 7, 13]
            low_right: [7, 8, 13, 13]
        placements:
          - { id: page_title, region: header, kind: textbox, text: "Giỏ hàng: 44% đơn mua 1 SP, đơn có quà +30% AOV" }
          - { id: slicers_p3, region: filters, kind: slicer, field_bindings: ["'gold Dim_Date'[month_name]", "'gold Dim_Category'[category_name]", "'gold Dim_Order'[traffic_source]"], purpose: "3 slicer synced" }
          - { id: kpi_aov,        region: kpi, kind: cardVisual, purpose: "AOV + MoM", field_bindings: ["'_Measures'[AOV]"] }
          - { id: kpi_basket,     region: kpi, kind: cardVisual, purpose: "Basket Size", field_bindings: ["'_Measures'[Basket Size]"] }
          - { id: kpi_single,     region: kpi, kind: cardVisual, purpose: "Single-item Order %", field_bindings: ["'_Measures'[Single-item Order %]"] }
          - { id: kpi_aov_gift,   region: kpi, kind: cardVisual, purpose: "AOV có quà vs không quà", field_bindings: ["'_Measures'[AOV (Gift)]", "'_Measures'[AOV (No Gift)]"] }
          - { id: basket_histogram, region: mid_left, kind: columnChart, purpose: "Phân bố kích thước giỏ (bucket)", field_bindings: { axis: "'gold Dim_Order'[basket_bucket]", values: "'_Measures'[Orders]" }, notes: "cột '1' tô accent, còn lại taupe" }
          - { id: aov_by_channel, region: mid_right, kind: lineClusteredColumnComboChart, purpose: "AOV (line) + số đơn (cột) theo kênh", field_bindings: { axis: "'gold Dim_Order'[traffic_source]", column_values: "'_Measures'[Completed Orders]", line_values: "'_Measures'[AOV]" } }
          - { id: gift_effect, region: low_left, kind: columnChart, purpose: "AOV & Basket Size: có quà vs không quà", field_bindings: { axis: "'gold Dim_Order'[has_gift]", values: ["'_Measures'[AOV]", "'_Measures'[Basket Size]"] } }
          - { id: crosssell_headroom, region: low_right, kind: tableEx, purpose: "Dư địa cross-sell theo sub_category: nhóm nên đẩy trước", field_bindings: { columns: ["'gold Dim_Category'[sub_category_name]", "'_Measures'[Completed Orders]", "'_Measures'[Cross-sell Attach Rate]", "'_Measures'[AOV]"] }, sort: "'_Measures'[Cross-sell Attach Rate] asc", notes: "attach rate thấp = dư địa cao" }
        space_audit:
          content_cell_count: 120
          placed_cell_count: 120
          empty_cell_pct: 0
          unplaced_regions: []
          largest_region: { name: kpi, pct_of_content: 20 }
          balance_rationale: "KPI hàng trên; 2 hàng phân tích 2-up; bảng dư địa = tầng hành động ở đáy phải."

    - name: "MBA: combo nên làm: [cặp điền sau] (lift cao × quy mô lớn)"
      id: p4
      role: detail
      archetype: Analytical
      layout_variant: A          # Filter-Rail: threshold + item_x rail, heatmap hero
      variant_rationale: "Khám phá luật; 2 slicer điều khiển (ngưỡng + nhóm) → rail trái; heatmap là hero."
      stakeholder: "Merchandising / CRM"
      decision: "Combo/bundle cặp nào làm ngay? Cặp nào để email cá nhân hoá?"
      layout_contract:
        canvas: { width: 1920, height: 1080, margin: 32, gutter: 24, snap: 8 }
        grid:
          columns: 12
          rows: 12
          regions:
            header:  [1, 1, 13, 2]
            rail:    [1, 2, 3, 11]
            defs:    [1, 11, 3, 13]
            heatmap: [3, 2, 9, 8]
            rules:   [9, 2, 13, 8]
            reco:    [3, 8, 13, 11]
            priority:[3, 11, 13, 13]
        placements:
          - { id: page_title, region: header, kind: textbox, text: "MBA: combo nên làm: [cặp điền sau] (lift cao × quy mô lớn)" }
          - { id: slicer_paircount, region: rail, kind: slicer, field_bindings: "'_MBA_Pairs_Matrix'[pair_order_count]", purpose: "Ngưỡng độ tin cậy", notes: "Between/numeric range, mặc định min = 15" }
          - { id: slicer_item_x, region: rail, kind: slicer, field_bindings: "'_MBA_Pairs_Matrix'[item_x]", purpose: "Nhóm khách đã mua", notes: "List, single-select" }
          - { id: mba_definitions, region: defs, kind: textbox, purpose: "Định nghĩa support/confidence/lift (không phải phân tích)", notes: "đủ cao tránh scrollbar: max(18, ceil(fontSize*25/16)) + padding" }
          - { id: mba_heatmap, region: heatmap, kind: pivotTable, purpose: "Lift theo cặp sub_category × sub_category", field_bindings: { rows: "'_MBA_Pairs_Matrix'[item_x]", columns: "'_MBA_Pairs_Matrix'[item_y]", values: "'_MBA_Pairs_Matrix'[lift]" }, notes: "background gradient #F6E1EA → #EDE6E1 (center=1) → #7A2547; ẩn subtotals" }
          - { id: mba_rules_table, region: rules, kind: tableEx, purpose: "Bảng luật (tam giác, không trùng cặp)", field_bindings: { columns: ["'gold vw_MBA_SubCategory_Pairs'[item_a]", "'gold vw_MBA_SubCategory_Pairs'[item_b]", "'gold vw_MBA_SubCategory_Pairs'[pair_order_count]", "'gold vw_MBA_SubCategory_Pairs'[support]", "'gold vw_MBA_SubCategory_Pairs'[confidence_a_to_b]", "'gold vw_MBA_SubCategory_Pairs'[lift]"] }, sort: "lift desc", filter: "pair_order_count >= 15" }
          - { id: mba_reco_bar, region: reco, kind: barChart, purpose: "Khách mua [item_x] → gợi ý item_y theo confidence", field_bindings: { axis: "'_MBA_Pairs_Matrix'[item_y]", values: "'_MBA_Pairs_Matrix'[confidence]" }, sort: "confidence desc", notes: "filter item_x = slicer; data label / tooltip = lift" }
          - { id: mba_priority_table, region: priority, kind: tableEx, purpose: "Bảng ưu tiên: cặp đáng làm trước", field_bindings: { columns: ["'gold vw_MBA_SubCategory_Pairs'[item_a]", "'gold vw_MBA_SubCategory_Pairs'[item_b]", "'gold vw_MBA_SubCategory_Pairs'[pair_order_count]", "'gold vw_MBA_SubCategory_Pairs'[lift]", "'_Measures'[Pair Priority Score]"] }, sort: "'_Measures'[Pair Priority Score] desc", filter: "pair_order_count >= 15" }
        space_audit:
          content_cell_count: 132
          placed_cell_count: 132
          empty_cell_pct: 0
          unplaced_regions: []
          largest_region: { name: heatmap, pct_of_content: 27 }
          balance_rationale: "Heatmap hero trên-trái; rules table cạnh phải để đọc số; reco bar + priority table = tầng hành động dưới."

  edit_interactions:
    p1: "KPI cards không bị filter bởi treemap/bar bên dưới (chỉ 1 chiều: slicer → tất cả)."
    p2: "Click bar breakdown → cross-filter bảng hàng đợi + line tháng; KHÔNG refilter 3 KPI (giữ mẫu số toàn kỳ)."
    p3: "Click bucket histogram → cross-filter bảng dư địa; KHÔNG refilter KPI AOV/Basket."
    p4: "slicer item_x → chỉ reco bar; heatmap + 2 table chỉ theo slicer pair_order_count."

  preflight:
    - "≤ 7 nhóm visual / trang"
    - "Mọi toạ độ chia hết 8; gutter 24; margin 32"
    - "Bar bắt đầu từ 0; không dual-axis; không donut/gauge/3D"
    - "≤ 3 màu có nghĩa/trang; trạng thái kèm mũi tên/icon (không chỉ màu)"
    - "Tiêu đề mọi visual = câu kết luận có số (điền sau khi lọc thật)"
    - "Alt text insight-driven mọi visual"
    - "KPI: absolute + MoM + mũi tên trên MỌI thẻ"
    - "Contrast WCAG AA (≥4.5:1 body); test CVD cho ramp heatmap"
    - "Footer synthetic 4 trang; nav buttons hoạt động 4 trang"
    - "Textbox T4 đủ cao: không scrollbar"
```
