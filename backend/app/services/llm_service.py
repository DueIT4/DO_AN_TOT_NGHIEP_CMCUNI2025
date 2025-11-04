# file: app/services/llm_service.py (hoặc nơi bạn đặt)
import os, requests, json
from typing import Optional
from app.utils.logger import logger

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL   = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
API_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

def _extract_text_from_gemini_response(data: dict) -> Optional[str]:
    """
    Try multiple known shapes of Gemini/Vertex style responses.
    Return first usable text or None.
    """
    # Candidate location 1: 'candidates' -> [ { 'content': { 'parts': [ {'text': '...'} ] } } ]
    try:
        cands = data.get("candidates") or []
        if cands:
            parts = cands[0].get("content", {}).get("parts") or []
            if parts and isinstance(parts, list) and "text" in parts[0]:
                return parts[0]["text"]
    except Exception:
        logger.debug("No text in candidates shape")

    # Candidate location 2: newer Vertex-like: data['output'][0]['content'][0]['text'] or data['output'][0]['text']
    try:
        output = data.get("output") or []
        if output and isinstance(output, list):
            # try nested content
            first = output[0]
            if isinstance(first, dict) and "content" in first:
                content = first.get("content") or []
                if content and isinstance(content, list) and "text" in content[0]:
                    return content[0]["text"]
            # fallback to direct text
            if "text" in first:
                return first["text"]
    except Exception:
        logger.debug("No text in output shape")

    # Candidate location 3: top-level 'text'
    if isinstance(data.get("text"), str):
        return data.get("text")

    return None

def explain_disease_with_llm(
    disease_name: str,
    confidence: float,
    db_description: Optional[str] = None,
    db_guideline: Optional[str] = None
) -> str:
    # Fallback khi chưa cấu hình key
    if not GEMINI_API_KEY:
        parts = [f"**Bệnh:** {disease_name}", f"**Độ tin cậy:** {confidence:.2%}"]
        if db_description: parts.append(f"**Mô tả:** {db_description}")
        if db_guideline:   parts.append(f"**Khuyến nghị xử lý:** {db_guideline}")
        return "\n\n".join(parts)

    system_prompt = (
        "Bạn là chuyên gia bệnh hại cây trồng. Hãy giải thích ngắn gọn, rõ ràng, "
        "đưa ra triệu chứng thường gặp, điều kiện phát sinh, và các bước xử lý an toàn, thực tế. "
        "Định dạng đầu ra **Markdown**, có tiêu đề và gạch đầu dòng."
    )
    user_context = (
        f"Bệnh phát hiện: {disease_name}\n"
        f"Độ tin cậy mô hình: {confidence:.2%}\n"
        f"Mô tả từ DB: {db_description or 'N/A'}\n"
        f"Hướng dẫn từ DB: {db_guideline or 'N/A'}\n\n"
        "Yêu cầu:\n"
        "1) # Tóm tắt ngắn (1–2 câu)\n"
        "2) ## Triệu chứng thường gặp (bullet)\n"
        "3) ## Nguyên nhân & điều kiện bùng phát (bullet)\n"
        "4) ## Các bước xử lý & phòng ngừa (bullet, ưu tiên an toàn/THỰC TẾ)\n"
    )

    payload = {
        "contents": [{
            "role": "user",
            "parts": [{"text": f"{system_prompt}\n\n{user_context}"}]
        }],
        "safetySettings": [
            {"category": "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold": "BLOCK_NONE"}
        ],
        "generationConfig": {
            "response_mime_type": "text/markdown"
        }
    }

    try:
        resp = requests.post(
            API_URL,
            params={"key": GEMINI_API_KEY},
            json=payload,
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
        logger.debug(f"LLM raw response: {data}")

        text = _extract_text_from_gemini_response(data)
        if not text:
            raise RuntimeError("Không tìm thấy text trong phản hồi LLM (schema không như mong đợi).")

        return text

    except Exception as e:
        logger.error(f"LLM call/parse failed: {e} - raw_resp={locals().get('data', None)}")
        fallback = [
            f"**Bệnh:** {disease_name}",
            f"**Độ tin cậy:** {confidence:.2%}",
            f"_LLM lỗi: {e}_"
        ]
        if db_description: fallback.append(f"**Mô tả:** {db_description}")
        if db_guideline:   fallback.append(f"**Khuyến nghị xử lý:** {db_guideline}")
        return "\n\n".join(fallback)
