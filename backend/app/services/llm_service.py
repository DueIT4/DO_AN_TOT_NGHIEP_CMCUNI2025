import os
import logging
from collections import Counter
from typing import List, Dict, Any, Tuple, Optional

# Sử dụng SDK cũ để khớp với môi trường Docker hiện tại
import google.generativeai as genai 
from dotenv import load_dotenv

logger = logging.getLogger(__name__)
load_dotenv()

# =====================================================
# 1. CẤU HÌNH GEMINI (SDK CŨ)
# =====================================================
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") 
GEMINI_MODEL_NAME = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")

model = None
if GEMINI_API_KEY:
    try:
        genai.configure(api_key=GEMINI_API_KEY) # Cú pháp SDK cũ
        model = genai.GenerativeModel(GEMINI_MODEL_NAME)
        logger.info(f"[LLM] Gemini initialized OK: {GEMINI_MODEL_NAME}")
    except Exception as e:
        logger.error(f"[LLM] ERROR: {e}")
else:
    logger.warning("[LLM] ❌ GEMINI_API_KEY missing!")

# =====================================================
# 2. PHÂN NHÓM NHÃN (ĐÃ THÊM UNKNOWN)
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

# Nhãn unknown sẽ được xử lý riêng để yêu cầu người dùng chụp lại
UNKNOWN_CLASS_KEY = "unknown"

# =====================================================
# 3. TẠO PROMPT (LOGIC ĐẦY ĐỦ)
# =====================================================
def _build_prompt_from_detections(detections: List[Dict[str, Any]]) -> str:
    if not detections:
        return "[DISEASE_SUMMARY]\n- Không phát hiện đối tượng khả nghi.\n\n[CARE_INSTRUCTIONS]\n- Hãy chụp gần và rõ hơn."

    disease_items = []
    healthy_items = []
    has_unknown = False

    for det in detections:
        key = det.get("class_key")
        name_vi = det.get("class_name")

        if key in DISEASE_CLASS_KEYS:
            disease_items.append(name_vi)
        elif key in HEALTHY_CLASS_KEYS:
            healthy_items.append(name_vi)
        elif key == UNKNOWN_CLASS_KEY:
            has_unknown = True

    # Logic ưu tiên: Nếu có bệnh -> báo bệnh. Nếu chỉ có unknown -> báo không xác định.
    if not disease_items and has_unknown:
        return (
            "[DISEASE_SUMMARY]\n"
            "- Hệ thống thấy có dấu hiệu lạ nhưng không xác định được chính xác là bệnh gì.\n\n"
            "[CARE_INSTRUCTIONS]\n"
            "- Vui lòng chụp lại ảnh dưới ánh sáng tốt hơn hoặc lau sạch ống kính.\n"
            "- Kiểm tra xem vùng đó có phải là vết bẩn hoặc côn trùng lạ không."
        )

    if not disease_items:
        return "[DISEASE_SUMMARY]\n- Cây bưởi của bạn đang rất khỏe mạnh.\n\n[CARE_INSTRUCTIONS]\n- Duy trì tưới nước và bón phân định kỳ."

    disease_counts = Counter(disease_items)
    lines = [f"- {name}: {cnt} vùng" for name, cnt in disease_counts.items()]

    return f"""
Bạn là chuyên gia nông nghiệp. AI phát hiện các triệu chứng:
{chr(10).join(lines)}

Hãy phản hồi theo cấu trúc:
[DISEASE_SUMMARY]
- Tóm tắt tình trạng bệnh.
[CARE_INSTRUCTIONS]
- Cách xử lý và phòng ngừa (không dùng tên thương hiệu thuốc).
""".strip()

# =====================================================
# 4. GỌI LLM (CÚ PHÁP SDK CŨ)
# =====================================================
def summarize_detections_with_llm(detections: List[Dict[str, Any]]) -> Tuple[Optional[str], Optional[str]]:
    if model is None: return None, None
    
    prompt = _build_prompt_from_detections(detections)
    try:
        response = model.generate_content(prompt) # Cú pháp SDK cũ
        full_text = (response.text or "").strip()
        
        # Tách chuỗi theo tag (Giữ nguyên logic của bạn)
        idx_ds = full_text.lower().find("[disease_summary]")
        idx_ci = full_text.lower().find("[care_instructions]")

        if idx_ds == -1 or idx_ci == -1: return full_text, None

        summary = full_text[idx_ds + 17 : idx_ci].strip()
        care = full_text[idx_ci + 19 :].strip()
        return summary, care
    except Exception as e:
        logger.error(f"LLM Error: {e}")
        return None, None