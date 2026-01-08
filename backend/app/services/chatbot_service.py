import logging
import time
from typing import Optional, List, Dict
from datetime import datetime
from sqlalchemy.orm import Session

# SỬ DỤNG SDK MỚI ĐỂ ĐỒNG NHẤT VỚI llm_service.py
from google import genai
from app.core.config import settings
from app.models.chatbot import Chatbot, ChatbotDetail, ChatbotStatus

logger = logging.getLogger(__name__)

# =====================================================
# 1. KHỞI TẠO CLIENT (Dùng chung một Client duy nhất)
# =====================================================
client = None
if settings.GEMINI_API_KEY:
    try:
        # Sử dụng đúng cú pháp SDK google-genai
        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        logger.info(f"[Chatbot] Gemini client initialized OK: {settings.GEMINI_MODEL}")
    except Exception as e:
        logger.error(f"[Chatbot] ERROR initializing Gemini client: {e}")
else:
    logger.warning("[Chatbot] ❌ GEMINI_API_KEY missing!")

# =====================================================
# 2. LOGIC AI (Gửi nhận tin nhắn)
# =====================================================
def send_message_to_gemini(question: str, chat_history: Optional[List[Dict[str, str]]] = None) -> str:
    """
    Gửi câu hỏi đến Gemini và nhận câu trả lời.
    Có retry logic tự động nếu bị 429 (rate limit).
    
    OPTIMIZATION: Chỉ dùng 2-3 message gần nhất để giảm prompt size
    """
    if not client:
        raise ValueError("AI chưa được cấu hình. Kiểm tra GEMINI_API_KEY.")
    
    # System Instruction định hướng phong cách trả lời
    system_instruction = (
        "Bạn là trợ lý nông nghiệp thân thiện ZestGuard. "
        "Hãy trả lời ngắn gọn, dễ hiểu và ưu tiên tiếng Việt. "
        "Tập trung tư vấn về cây trồng, bệnh hại và kỹ thuật chăm sóc."
    )
    
    # Xây dựng Prompt tổng hợp từ lịch sử chat
    prompt_parts = [system_instruction]
    
    # ⭐ OPTIMIZATION: Chỉ lấy 2 message gần nhất (thay vì 5)
    if chat_history:
        recent_history = chat_history[-2:] if len(chat_history) > 2 else chat_history
        for msg in recent_history:
            prompt_parts.append(f"Người dùng: {msg['question']}")
            prompt_parts.append(f"Trợ lý: {msg['answer']}")
    
    prompt_parts.append(f"Người dùng: {question}")
    prompt_parts.append("Trợ lý:")
    
    full_prompt = "\n".join(prompt_parts)

    # Retry logic - tối đa 3 lần nếu bị 429
    max_retries = 3
    for attempt in range(max_retries):
        try:
            # Gọi API qua SDK mới (client.models.generate_content)
            response = client.models.generate_content(
                model=settings.GEMINI_MODEL,
                contents=full_prompt
            )
            
            answer = (response.text or "").strip()
            if not answer:
                raise ValueError("AI không trả về kết quả.")
                
            return answer
        
        except Exception as e:
            err_msg = str(e)
            logger.error(f"[Chatbot] Gemini API Error (Attempt {attempt+1}/{max_retries}): {err_msg}")
            
            # Nếu lỗi 429 (rate limit) và còn retry
            if "429" in err_msg and attempt < max_retries - 1:
                wait_time = 2 ** (attempt + 1)  # 2s, 4s, 8s
                logger.warning(f"[Chatbot] Rate limited. Waiting {wait_time}s before retry...")
                time.sleep(wait_time)
                continue
            
            # Nếu là lần cuối hoặc không phải lỗi 429
            if "429" in err_msg:
                return "Hệ thống AI đang tạm thời quá tải. Vui lòng đợi 1-2 phút và thử lại."
            
            raise ValueError(f"Lỗi AI: {err_msg}")

# =====================================================
# 3. LOGIC DATABASE (Lưu trữ và lấy lịch sử)
# =====================================================
def get_or_create_chatbot_session(user_id: int, chatbot_id: Optional[int], db: Session) -> Chatbot:
    if chatbot_id:
        chatbot = db.query(Chatbot).filter(
            Chatbot.chatbot_id == chatbot_id,
            Chatbot.user_id == user_id,
            Chatbot.status == ChatbotStatus.active
        ).first()
        if chatbot:
            return chatbot
    
    chatbot = Chatbot(user_id=user_id, status=ChatbotStatus.active)
    db.add(chatbot)
    db.commit()
    db.refresh(chatbot)
    return chatbot

def save_chat_message(chatbot_id: int, question: str, answer: str, db: Session) -> ChatbotDetail:
    detail = ChatbotDetail(chatbot_id=chatbot_id, question=question, answer=answer)
    db.add(detail)
    db.commit()
    db.refresh(detail)
    return detail

def get_chat_history(chatbot_id: int, db: Session, limit: int = 5) -> List[Dict[str, str]]:
    # Lấy 5 message gần nhất (DESC) để giảm prompt size và tránh 429 quota
    details = db.query(ChatbotDetail).filter(
        ChatbotDetail.chatbot_id == chatbot_id
    ).order_by(ChatbotDetail.created_at.desc()).limit(limit).all()
    
    # Reverse để hiển thị theo thứ tự chronological (cũ → mới)
    return [{"question": d.question, "answer": d.answer} for d in reversed(details)]

def end_chatbot_session(chatbot_id: int, user_id: int, db: Session) -> Chatbot:
    chatbot = db.query(Chatbot).filter(
        Chatbot.chatbot_id == chatbot_id,
        Chatbot.user_id == user_id
    ).first()
    
    if not chatbot:
        raise ValueError("Không tìm thấy session.")
    
    chatbot.status = ChatbotStatus.ended
    chatbot.end_at = datetime.utcnow()
    db.commit()
    db.refresh(chatbot)
    return chatbot