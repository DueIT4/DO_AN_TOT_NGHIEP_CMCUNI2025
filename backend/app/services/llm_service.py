# backend/app/services/llm_service.py
import os
from collections import Counter
from typing import List, Dict, Any, Tuple, Optional

import google.generativeai as genai
GEMINI_API_KEY = "AIzaSyD6NteusFX-hF0KDSFwW4V5Wfg82VdZRdc"
genai.configure(api_key=GEMINI_API_KEY)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-pro")

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

# 🔹 Bệnh thật sự
DISEASE_CLASS_KEYS = {
    "pomelo_leaf_miner",
    "pomelo_leaf_yellowing",
    "pomelo_fruit_scorch",
}

# 🔹 Healthy (không phải bệnh)
HEALTHY_CLASS_KEYS = {
    "pomelo_leaf_healthy",
    "pomelo_fruit_healthy",
}


def _build_prompt_from_detections(detections: List[Dict[str, Any]]) -> str:
    """Sinh prompt cho LLM dựa vào cả bệnh và vùng khỏe"""

    if not detections:
        return (
            "Hệ thống không phát hiện ra triệu chứng bệnh rõ ràng nào trên cây bưởi. "
            "Hãy đưa ra lời khuyên chung về chăm sóc cây khỏe mạnh: tưới nước hợp lý, "
            "bón phân cân đối, giữ vườn thông thoáng, phòng ngừa sâu bệnh."
        )

    disease_items = []
    healthy_items = []

    for det in detections:
        key = det["class_key"]
        name_vi = det["class_name"]

        if key in DISEASE_CLASS_KEYS:
            disease_items.append(name_vi)
        elif key in HEALTHY_CLASS_KEYS:
            healthy_items.append(name_vi)

    # --- Trường hợp chỉ có vùng khỏe (không có bệnh)
    if len(disease_items) == 0:
        return (
            "Hệ thống AI ghi nhận rằng các vùng được phát hiện trong ảnh đều thuộc nhóm KHỎE MẠNH.\n\n"
            "👉 Điều này cho thấy cây bưởi đang trong tình trạng tốt.\n\n"
            "Hãy đưa ra các hướng dẫn ngắn gọn cho nông dân về chăm sóc cây khỏe mạnh:\n"
            "• Giữ chế độ tưới nước phù hợp\n"
            "• Bón phân cân đối, hữu cơ\n"
            "• Giữ vườn thoáng, cắt tỉa lá già\n"
            "• Theo dõi thường xuyên để phát hiện sớm sâu bệnh\n"
            "• Giải thích tại sao dù cây khỏe vẫn cần chăm sóc phòng ngừa"
        )

    # --- Có bệnh thật sự → LLM giải thích chi tiết
    disease_counts = Counter(disease_items)
    lines = [f"- {name}: {cnt} vùng" for name, cnt in disease_counts.items()]

    prompt = f"""
Bạn là chuyên gia nông nghiệp chuyên về bệnh cây bưởi.

Hệ thống AI đã phát hiện các bệnh sau:
{chr(10).join(lines)}

Yêu cầu trả lời:
1. Mô tả triệu chứng đã thấy trong ảnh.
2. Đánh giá mức độ nặng/nhẹ.
3. Hướng dẫn xử lý an toàn:
   • biện pháp sinh học  
   • cắt tỉa, vệ sinh vườn  
   • nhóm hoạt chất thuốc (không nêu thương hiệu)
4. Hướng dẫn phòng ngừa cho giai đoạn sau.
5. Văn phong dễ hiểu cho nông dân Việt Nam.

Nếu ảnh có cả vùng khỏe:
- Nhắc rằng cây vẫn có phần khỏe mạnh, giúp cây hồi phục tốt hơn nếu xử lý đúng cách.
"""

    return prompt.strip()


def summarize_detections_with_llm(
    detections: List[Dict[str, Any]]
) -> Tuple[Optional[str], Optional[str]]:
    if not GEMINI_API_KEY:
        return None, None

    prompt = _build_prompt_from_detections(detections)

    try:
        model = genai.GenerativeModel(GEMINI_MODEL)
        resp = model.generate_content(prompt)
        text = (resp.text or "").strip()
        return text, None
    except Exception as e:
        print("LLM ERROR:", e)
        return None, None
