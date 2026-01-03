import logging
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
    """
    if not client:
        raise ValueError("AI chưa được cấu hình. Kiểm tra GEMINI_API_KEY.")
    
    # System Instruction định hướng phong cách trả lời
    system_instruction = (
        "Bạn là trợ lý nông nghiệp thân thiện ZestGuard. "
        "Hãy trả lời ngắn gọn, dễ hiểu và ưu tiên tiếng Việt. "
        "Tập trung tư vấn về cây trồng, bệnh hại và kỹ thuật chăm sóc."
    )
    
    try:
        # Xây dựng Prompt tổng hợp từ lịch sử chat (Logic Stateless)
        prompt_parts = [system_instruction]
        
        if chat_history:
            for msg in chat_history:
                prompt_parts.append(f"Người dùng: {msg['question']}")
                prompt_parts.append(f"Trợ lý: {msg['answer']}")
        
        prompt_parts.append(f"Người dùng: {question}")
        prompt_parts.append("Trợ lý:")
        
        full_prompt = "\n".join(prompt_parts)

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
        logger.error(f"[Chatbot] Gemini API Error: {err_msg}")
        
        # Xử lý lỗi Quota (429) thường gặp trên bản 2.0 Flash
        if "429" in err_msg:
            return "Hệ thống AI đang tạm thời quá tải (429). Bạn vui lòng đợi 60 giây và thử lại nhé."
        
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

def get_chat_history(chatbot_id: int, db: Session, limit: int = 20) -> List[Dict[str, str]]:
    details = db.query(ChatbotDetail).filter(
        ChatbotDetail.chatbot_id == chatbot_id
    ).order_by(ChatbotDetail.created_at.asc()).limit(limit).all()
    
    return [{"question": d.question, "answer": d.answer} for d in details]

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