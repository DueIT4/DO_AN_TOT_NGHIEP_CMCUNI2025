# ============================================
#  llm_service.py – FULL WORKING VERSION (SDK mới)
# ============================================

import os
import json
from collections import Counter
from typing import List, Dict, Any, Tuple, Optional

# SDK google-generativeai
import google.generativeai as genai  
from dotenv import load_dotenv

# Load .env (đảm bảo chạy dù VSCode không inject)
load_dotenv()

# =====================================================
# 1. LẤY API KEY + MODEL TỪ .env
# =====================================================

# Đọc từ .env (bắt buộc)
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise ValueError("GEMINI_API_KEY không được tìm thấy trong file .env")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-pro")

print("[LLM] HAS API KEY:", bool(GEMINI_API_KEY))
print("[LLM] USING MODEL:", GEMINI_MODEL)

# =====================================================
# 2. TẠO CLIENT
# =====================================================

# Cấu hình Gemini
if GEMINI_API_KEY:
    try:
        genai.configure(api_key=GEMINI_API_KEY)
        print("[LLM] Gemini configured OK.")
    except Exception as e:
        print("[LLM] ERROR configuring Gemini:", e)
else:
    print("[LLM] ❌ GEMINI_API_KEY missing! LLM disabled.")


# =====================================================
# 3. DANH SÁCH BỆNH / KHỎE ĐỂ PHÂN LOẠI DETECTIONS
# =====================================================

DISEASE_CLASS_KEYS = {
    "pomelo_leaf_miner",
    "pomelo_leaf_yellowing",
    "pomelo_fruit_scorch",
}

HEALTHY_CLASS_KEYS = {
    "pomelo_leaf_healthy",
    "pomelo_fruit_healthy",
}


# =====================================================
# 4. TẠO PROMPT TỰ ĐỘNG
# =====================================================

def _build_prompt_from_detections(detections: List[Dict[str, Any]]) -> str:
    """Sinh prompt mô tả bệnh + yêu cầu LLM trả về nội dung dạng 2 phần."""

    # Không phát hiện gì
    if not detections:
        return (
            "Hệ thống AI không phát hiện bệnh rõ ràng.\n\n"
            "Hãy trả lời theo đúng cấu trúc sau:\n\n"
            "[DISEASE_SUMMARY]\n"
            "- Mô tả rằng lá/quả nhìn khỏe, không phát hiện bệnh.\n\n"
            "[CARE_INSTRUCTIONS]\n"
            "- Đưa ra hướng dẫn chăm sóc cơ bản để cây tiếp tục khỏe mạnh.\n"
        )

    disease_items = []
    healthy_items = []

    for det in detections:
        key = det.get("class_key")
        name_vi = det.get("class_name")

        if key in DISEASE_CLASS_KEYS:
            disease_items.append(name_vi)
        elif key in HEALTHY_CLASS_KEYS:
            healthy_items.append(name_vi)

    # Chỉ khỏe
    if len(disease_items) == 0:
        return (
            "AI nhận thấy các vùng quét đều thuộc nhóm khoẻ mạnh.\n\n"
            "Hãy trả lời theo đúng cấu trúc:\n\n"
            "[DISEASE_SUMMARY]\n"
            "- Nêu rõ cây đang khỏe.\n\n"
            "[CARE_INSTRUCTIONS]\n"
            "- Hướng dẫn bảo dưỡng, chăm sóc, phòng ngừa.\n"
        )

    # Có bệnh thật
    disease_counts = Counter(disease_items)
    lines = [f"- {name}: {cnt} vùng" for name, cnt in disease_counts.items()]

    return f"""
Bạn là chuyên gia bệnh cây bưởi.

AI phát hiện các bệnh sau:
{chr(10).join(lines)}

Hãy trả lời theo đúng format:

[DISEASE_SUMMARY]
- Giải thích cây đang bị gì, mức độ nặng nhẹ, triệu chứng.

[CARE_INSTRUCTIONS]
- Hướng dẫn xử lý chi tiết: biện pháp sinh học, cắt tỉa, vệ sinh vườn.
- Nếu cần thuốc: chỉ ghi tên HOẠT CHẤT, không ghi thương hiệu.
- Hướng dẫn phòng ngừa sau này.
""".strip()


# =====================================================
# 5. GỌI LLM + TÁCH KẾT QUẢ THÀNH 2 PHẦN
# =====================================================

def summarize_detections_with_llm(
    detections: List[Dict[str, Any]]
) -> Tuple[Optional[str], Optional[str]]:
    """
    Trả về: (disease_summary, care_instructions)
    KHÔNG ĐỔI INTERFACE → tránh làm lỗi API detect.
    """

    if not GEMINI_API_KEY:
        print("[LLM] GEMINI_API_KEY missing → LLM disabled.")
        return None, None

    prompt = _build_prompt_from_detections(detections)

    try:
        # ===== GỌI GEMINI =====
        model = genai.GenerativeModel(model_name=GEMINI_MODEL)
        response = model.generate_content(prompt)

        full_text = (response.text or "").strip()
        if not full_text:
            return None, None

        # ===== TÁCH HAI PHẦN =====
        text_lower = full_text.lower()

        idx_ds = text_lower.find("[disease_summary]")
        idx_ci = text_lower.find("[care_instructions]")

        if idx_ds == -1 or idx_ci == -1:
            # LLM không theo format → return toàn bộ
            return full_text, None

        disease_summary = full_text[idx_ds + len("[DISEASE_SUMMARY]"): idx_ci].strip()
        care_instructions = full_text[idx_ci + len("[CARE_INSTRUCTIONS]"):].strip()

        disease_summary = disease_summary or None
        care_instructions = care_instructions or None

        return disease_summary, care_instructions

    except Exception as e:
        # In lỗi chi tiết
        print("LLM ERROR:", e)
        return None, None