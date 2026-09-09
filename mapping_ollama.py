"""
mapping_ollama.py
-----------------
Nhờ Ollama (local LLM) phân loại tên sản phẩm mỹ phẩm vào (category, sub_category), rồi xuất ra file .xlsx để tự review / sửa tay.

Chuẩn bị:
    ollama serve
    ollama pull qwen2.5:7b-instruct
    pip install openai pandas openpyxl
"""

from __future__ import annotations

import json
import re
import sys
import time
import unicodedata
from pathlib import Path

import pandas as pd

try:
    from openai import OpenAI
except ImportError:
    sys.exit("Thiếu thư viện: pip install openai")

# ------------------------------------------------------------------ config
BASE_URL   = "http://localhost:11434/v1"
API_KEY    = "ollama"
MODEL      = "qwen2.5:7b-instruct"
SEED       = 42
NUM_CTX    = 4096
CHUNK_SIZE = 25                             # số tên / 1 lần gọi
MAX_RETRY  = 3
MAX_NAMES  = None                           # None = tất cả; đặt 10 để test nhanh

PROJECT_DIR = Path(__file__).resolve().parent
INPUT_CSV   = PROJECT_DIR / "Cleaned_Data" / "product_names_distinct.csv"
OUTPUT_XLSX = PROJECT_DIR / "Cleaned_Data" / "product_category_map.xlsx"

# Taxonomy hợp lệ: category -> các sub_category cho phép
ALLOWED: dict[str, set[str]] = {
    "Skincare":  {"Face Care", "Body Care", "Lip Care"},
    "Makeup":    {"Face", "Eyes", "Lips"},
    "Hair Care": {"Cleansing", "Treatment", "Color"},
    "Khác":      {"Khác"},
}
UNKNOWN = "UNKNOWN"


# ------------------------------------------------------------------ helpers
def norm_key(s: str) -> str:
    """Chuẩn hoá: NFC + bỏ zero-width / nbsp + thống nhất dấu nháy + gộp khoảng trắng."""
    s = unicodedata.normalize("NFC", str(s))
    s = s.replace("​", "").replace(" ", " ")
    s = s.replace("’", "'").replace("‘", "'")
    return re.sub(r"\s+", " ", s).strip()


def build_prompt(names: list[str]) -> str:
    numbered = "\n".join(f"{i + 1}. {n}" for i, n in enumerate(names))
    return f"""Bạn là chuyên gia phân loại sản phẩm ngành mỹ phẩm (skincare, makeup, hair care).
Nhiệm vụ: gán mỗi tên sản phẩm vào đúng 1 cặp (category, sub_category).

CHỈ được dùng các giá trị sau (sub_category phải thuộc đúng category):
- Skincare  -> Face Care | Body Care | Lip Care
- Makeup    -> Face | Eyes | Lips
- Hair Care -> Cleansing | Treatment | Color
- Khac      -> Khac

Quy tac goi y nhanh:
- "Dau goi", "Dau xa"                                  -> Hair Care / Cleansing
- "Kem u", "Dau duong toc", "tinh dau toc"             -> Hair Care / Treatment
- "Nhuom", "Excellence", "mau toc"                     -> Hair Care / Color
- "Mascara","Ke mat","Ke mi","Phan mat","Chi ke may","But ke may","Ke may" -> Makeup / Eyes
- "Son" (thoi/kem/tint/li/but chi)                     -> Makeup / Lips
- "Kem nen","Phan nen","Phan phu","Che khuyet diem","Ma hong","Kem lot","BB" -> Makeup / Face
- "Kem chong nang cho da mat" (UV Perfect, UV Defender, chong nang thuan) -> Skincare / Body Care
- "Serum","Sua rua mat","Nuoc tay trang","Micellar","Tay trang mat moi","Toner","Nuoc hoa hong","Kem duong","Mat na","Tinh chat","Essence","Kem duong mat" -> Skincare / Face Care
- "Son duong","Duong moi"                              -> Skincare / Lip Care
- "Tui","Vi","Co trang diem","Bong tay trang"          -> Khac / Khac

LUU Y de tranh nham:
- "Kem nen" / "Phan nen" co SPF / chong nang -> van la Makeup / Face (KHONG phai Body Care)
- "Nuoc hoa hong" la toner -> Skincare / Face Care (KHONG phai nuoc hoa / fragrance)
- "Son duong moi" co SPF -> van la Skincare / Lip Care

Neu KHONG chac chan -> category="UNKNOWN", sub_category="UNKNOWN". Khong doan bua.
Khong giai thich, khong markdown.

Tra ve DUY NHAT 1 JSON object dang:
{{"results": [{{"name": "<ten y het input>", "category": "...", "sub_category": "..."}}]}}

Danh sach can phan loai:
{numbered}
"""


def parse_response(text: str) -> list[dict]:
    text = text.strip()
    text = re.sub(r"^```(?:json)?|```$", "", text, flags=re.MULTILINE).strip()
    start, end = text.find("{"), text.rfind("}")
    if start == -1 or end == -1:
        raise ValueError("không thấy JSON object")
    obj = json.loads(text[start : end + 1])
    rows = obj.get("results", obj if isinstance(obj, list) else [])
    if not isinstance(rows, list):
        raise ValueError("trường 'results' không phải list")
    return rows


def validate(cat: str, sub: str) -> tuple[str, str]:
    cat = (cat or "").strip()
    sub = (sub or "").strip()
    if cat not in ALLOWED:
        return UNKNOWN, UNKNOWN
    if sub not in ALLOWED[cat]:
        return cat, UNKNOWN
    return cat, sub


def classify_chunk(client: OpenAI, names: list[str]) -> dict[str, tuple[str, str]]:
    """Trả {norm_key(name): (category, sub_category)} đã validate cho 1 chunk."""
    prompt = build_prompt(names)
    last_err = None
    for attempt in range(1, MAX_RETRY + 1):
        try:
            resp = client.chat.completions.create(
                model=MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0,
                extra_body={"options": {"seed": SEED, "num_ctx": NUM_CTX}},
                response_format={"type": "json_object"},
            )
            rows = parse_response(resp.choices[0].message.content)
            by_key = {norm_key(r.get("name", "")): r for r in rows if isinstance(r, dict)}

            out: dict[str, tuple[str, str]] = {}
            for name in names:
                k = norm_key(name)
                r = by_key.get(k)
                out[k] = validate(r.get("category", ""), r.get("sub_category", "")) if r else (UNKNOWN, UNKNOWN)
            return out
        except Exception as e:  # noqa: BLE001
            last_err = e
            print(f"    thử lại {attempt}/{MAX_RETRY} ({e})")
            time.sleep(1.5 * attempt)

    print(f"    !! chunk lỗi hẳn: {last_err} -> để UNKNOWN")
    return {norm_key(n): (UNKNOWN, UNKNOWN) for n in names}


# ------------------------------------------------------------------ main
def main() -> None:
    if not INPUT_CSV.exists():
        sys.exit(f"Không thấy {INPUT_CSV.name}. Chạy notebook để tạo file distinct trước.")

    df = pd.read_csv(INPUT_CSV)
    names = [norm_key(n) for n in df["product_name"].dropna()]
    names = list(dict.fromkeys(names))                # distinct, giữ thứ tự
    if MAX_NAMES:
        names = names[:MAX_NAMES]
    print(f"Đọc {len(names)} tên sản phẩm distinct từ {INPUT_CSV.name}")

    client = OpenAI(base_url=BASE_URL, api_key=API_KEY)
    try:
        client.models.list()
    except Exception as e:  # noqa: BLE001
        sys.exit(
            f"Không kết nối được Ollama tại {BASE_URL} ({e}).\n"
            f"  - Đã chạy `ollama serve` chưa?\n"
            f"  - Đã `ollama pull {MODEL}` chưa?"
        )

    result: dict[str, tuple[str, str]] = {}
    chunks = [names[i : i + CHUNK_SIZE] for i in range(0, len(names), CHUNK_SIZE)]
    for idx, chunk in enumerate(chunks, 1):
        print(f"[{idx}/{len(chunks)}] {len(chunk)} tên...")
        result.update(classify_chunk(client, chunk))

    out = pd.DataFrame(
        [
            {
                "product_name": n,
                "category": result.get(n, (UNKNOWN, UNKNOWN))[0],
                "sub_category": result.get(n, (UNKNOWN, UNKNOWN))[1],
            }
            for n in names
        ]
    )

    try:
        out.to_excel(OUTPUT_XLSX, index=False)
    except ModuleNotFoundError:
        sys.exit("Thiếu openpyxl: pip install openpyxl")

    n_unknown = int(((out["category"] == UNKNOWN) | (out["sub_category"] == UNKNOWN)).sum())
    print(f"\nĐã ghi {OUTPUT_XLSX.name} ({len(out)} dòng, {n_unknown} dòng UNKNOWN)")
    print("-> Mở Excel, sửa các dòng UNKNOWN và soát lại phần còn lại.")


if __name__ == "__main__":
    main()
