# app/services/llm_service.py
import requests
from typing import Optional
from app.utils.logger import logger
from app.core.config import settings

def _extract_text_from_gemini_response(data: dict) -> Optional[str]:
    # 1) dạng Public Gemini REST
    try:
        cands = data.get("candidates") or []
        if cands:
            parts = cands[0].get("content", {}).get("parts") or []
            if parts and isinstance(parts, list) and "text" in parts[0]:
                return parts[0]["text"]
    except Exception:
        logger.debug("No text in candidates shape")

    # 2) một số SDK/Vertex biến thể
    try:
        output = data.get("output") or []
        if output and isinstance(output, list):
            first = output[0]
            if isinstance(first, dict) and "content" in first:
                content = first.get("content") or []
                if content and isinstance(content, list) and "text" in content[0]:
                    return content[0]["text"]
            if "text" in first:
                return first["text"]
    except Exception:
        logger.debug("No text in output shape")

    if isinstance(data.get("text"), str):
        return data.get("text")
    return None

def explain_disease_with_llm(
    disease_name: str,
    confidence: float,
    db_description: Optional[str] = None,
    db_guideline: Optional[str] = None
) -> str:
    api_key = settings.GEMINI_API_KEY
    model   = settings.GEMINI_MODEL or "gemini-1.5-flash"
    api_url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

    # Fallback khi chưa có key
    if not api_key:
        parts = [
            f"**Bệnh:** {disease_name}",
            f"**Độ tin cậy:** {confidence:.2%}",
        ]
        if db_description:
            parts.append(f"**Mô tả:** {db_description}")
        if db_guideline:
            parts.append(f"**Khuyến nghị xử lý:** {db_guideline}")
        return "\n\n".join(parts)

    system_prompt = (
        "Bạn là **chuyên gia nông nghiệp** về cây có múi (đặc biệt cây bưởi). "
        "Hãy viết bản chẩn đoán & hướng dẫn ngắn gọn, dễ hiểu, an toàn.\n\n"
        "Trả về **Markdown** với cấu trúc:\n"
        "## Tóm tắt\n"
        "- (1–2 câu)\n"
        "## Triệu chứng\n"
        "- ...\n"
        "## Nguyên nhân & Điều kiện phát sinh\n"
        "- ...\n"
        "## Biện pháp xử lý\n"
        "- ... (ưu tiên sinh học, thân thiện môi trường)\n"
        "## Phòng ngừa lâu dài\n"
        "- ...\n"
    )

    user_context = (
        f"### Thông tin từ hệ thống AI\n"
        f"- Bệnh phát hiện: {disease_name}\n"
        f"- Độ tin cậy mô hình: {confidence:.2%}\n"
        f"- Mô tả từ CSDL: {db_description or 'Không có'}\n"
        f"- Hướng dẫn từ CSDL: {db_guideline or 'Không có'}\n"
        "Yêu cầu: ngắn gọn, thực tế, dễ áp dụng cho nông dân trồng bưởi."
    )

    payload = {
        "contents": [{
            "role": "user",
            "parts": [{"text": f"{system_prompt}\n\n{user_context}"}]
        }],
        "generationConfig": {
            "response_mime_type": "text/markdown",
            "temperature": 0.6,
            "top_p": 0.9
        },
        "safetySettings": [
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
        ]
    }

    try:
        resp = requests.post(api_url, params={"key": api_key}, json=payload, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        txt = _extract_text_from_gemini_response(data)
        if not txt:
            raise RuntimeError("Không tìm thấy text trong phản hồi LLM.")
        return txt.strip()
    except Exception as e:
        logger.error(f"❌ LLM call/parse failed: {e}")
        fallback = [
            f"Bệnh: {disease_name}",
            f"Độ tin cậy: {confidence:.2%}",
            f"_LLM lỗi: {e}_"
        ]
        if db_description: fallback.append(f"Mô tả: {db_description}")
        if db_guideline:   fallback.append(f"Khuyến nghị xử lý: {db_guideline}")
        return "\n\n".join(fallback)
