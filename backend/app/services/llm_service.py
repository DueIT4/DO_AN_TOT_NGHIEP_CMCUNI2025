# ============================================
#  llm_service.py – FULL WORKING VERSION (SDK mới)
# ============================================

import os
import logging
from collections import Counter
from typing import List, Dict, Any, Tuple, Optional

# SDK MỚI – Google GenAI
from google import genai 
from dotenv import load_dotenv

# Setup logging để theo dõi lỗi trên Cloud Run dễ hơn
logger = logging.getLogger(__name__)

# Load .env
load_dotenv()

# =====================================================
# 1. LẤY API KEY + MODEL TỪ .env
# =====================================================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") 
# Sửa lại thành 2.0-flash để đảm bảo chạy được
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")

# =====================================================
# 2. TẠO CLIENT
# =====================================================
client = None
if GEMINI_API_KEY:
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        logger.info(f"[LLM] Gemini client initialized OK with model: {GEMINI_MODEL}")
    except Exception as e:
        logger.error(f"[LLM] ERROR initializing Gemini client: {e}")
else:
    logger.warning("[LLM] ❌ GEMINI_API_KEY missing! LLM disabled.")


# =====================================================
# 3. DANH SÁCH PHÂN LOẠI (Giữ nguyên của bạn)
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
# 4. TẠO PROMPT TỰ ĐỘNG (Giữ nguyên logic của bạn)
# =====================================================
def _build_prompt_from_detections(detections: List[Dict[str, Any]]) -> str:
    """Sinh prompt dựa trên kết quả AI phát hiện được."""
    
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

    if not disease_items:
        return (
            "AI nhận thấy các vùng quét đều thuộc nhóm khoẻ mạnh.\n\n"
            "Hãy trả lời theo đúng cấu trúc:\n\n"
            "[DISEASE_SUMMARY]\n"
            "- Nêu rõ cây đang khỏe.\n\n"
            "[CARE_INSTRUCTIONS]\n"
            "- Hướng dẫn bảo dưỡng, chăm sóc, phòng ngừa.\n"
        )

    disease_counts = Counter(disease_items)
    lines = [f"- {name}: {cnt} vùng" for name, cnt in disease_counts.items()]

    return f"""
Bạn là chuyên gia bệnh cây bưởi.

AI phát hiện các dấu hiệu sau:
{chr(10).join(lines)}

YÊU CẦU BẮT BUỘC:
- Chỉ dùng văn bản thuần
- Không dùng Markdown
- Không dùng ký hiệu *, **, -, #

FORMAT TRẢ LỜI (KHÔNG ĐƯỢC SAI):

BEGIN_DISEASE_SUMMARY
Giải thích cây đang bị bệnh gì, mức độ, triệu chứng.
END_DISEASE_SUMMARY

BEGIN_CARE_INSTRUCTIONS
Hướng dẫn xử lý chi tiết: sinh học, cắt tỉa, vệ sinh, phòng ngừa.
END_CARE_INSTRUCTIONS
""".strip()

def _extract_block(text: str, start: str, end: str):
    if start not in text or end not in text:
        return None
    return text.split(start, 1)[1].split(end, 1)[0].strip()

# =====================================================
# 5. GỌI LLM + TÁCH KẾT QUẢ
# =====================================================
def summarize_detections_with_llm(
    detections: List[Dict[str, Any]]
) -> Tuple[Optional[str], Optional[str]]:
    """
    Trả về: (disease_summary, care_instructions)
    """

    if client is None:
        return None, None

    prompt = _build_prompt_from_detections(detections)

    try:
        # Gọi Gemini Model
        response = client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt,
        )

        full_text = (response.text or "").strip()
        if not full_text:
            return None, None

        # Tách hai phần dựa trên tag
        disease_summary = _extract_block(
            full_text,
            "BEGIN_DISEASE_SUMMARY",
            "END_DISEASE_SUMMARY"
        )

        care_instructions = _extract_block(
            full_text,
            "BEGIN_CARE_INSTRUCTIONS",
            "END_CARE_INSTRUCTIONS"
        )

        return disease_summary, care_instructions

    except Exception as e:
        logger.error(f"LLM ERROR: {e}")
        return None, None