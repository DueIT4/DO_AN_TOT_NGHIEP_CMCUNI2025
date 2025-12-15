# app/services/chatbot_service.py
from typing import Optional
from sqlalchemy.orm import Session
import google.generativeai as genai
from app.core.config import settings
from app.models.chatbot import Chatbot, ChatbotDetail, ChatbotStatus

# Cấu hình Gemini API
if settings.GEMINI_API_KEY:
    try:
        genai.configure(api_key=settings.GEMINI_API_KEY)
        print("[Chatbot] Gemini configured OK.")
    except Exception as e:
        print("[Chatbot] ERROR configuring Gemini:", e)
else:
    print("[Chatbot] ❌ GEMINI_API_KEY missing! Chatbot disabled.")

def get_or_create_chatbot_session(user_id: int, chatbot_id: Optional[int], db: Session) -> Chatbot:
    """
    Lấy session chatbot hiện tại hoặc tạo mới.
    - Nếu chatbot_id được cung cấp và còn active → dùng session đó
    - Nếu không → tạo session mới
    """
    if chatbot_id:
        chatbot = db.query(Chatbot).filter(
            Chatbot.chatbot_id == chatbot_id,
            Chatbot.user_id == user_id,
            Chatbot.status == ChatbotStatus.active
        ).first()
        if chatbot:
            return chatbot
    
    # Tạo session mới
    chatbot = Chatbot(
        user_id=user_id,
        status=ChatbotStatus.active
    )
    db.add(chatbot)
    db.commit()
    db.refresh(chatbot)
    return chatbot

def send_message_to_gemini(question: str, chat_history: Optional[list] = None) -> str:
    """
    Gửi câu hỏi đến Gemini và nhận câu trả lời.
    
    Args:
        question: Câu hỏi của người dùng
        chat_history: Lịch sử chat (list of dict với 'question' và 'answer')
    
    Returns:
        Câu trả lời từ Gemini
    """
    if not settings.GEMINI_API_KEY:
        raise ValueError("Gemini chưa được cấu hình. Kiểm tra GEMINI_API_KEY.")
    
    # System prompt cho trợ lý nông nghiệp
    system_instruction = (
        "Bạn là trợ lý nông nghiệp thân thiện. "
        "Hãy trả lời ngắn gọn, dễ hiểu và ưu tiên tiếng Việt nếu người dùng dùng tiếng Việt. "
        "Tập trung vào các vấn đề về cây trồng, bệnh tật, chăm sóc cây, và nông nghiệp."
    )
    
    try:
        # Xây dựng prompt với lịch sử chat
        prompt_parts = []
        
        # Thêm system instruction vào đầu
        prompt_parts.append(system_instruction)
        
        # Thêm lịch sử chat nếu có
        if chat_history:
            for msg in chat_history:
                prompt_parts.append(f"Người dùng: {msg['question']}")
                prompt_parts.append(f"Trợ lý: {msg['answer']}")
        
        # Thêm câu hỏi hiện tại
        prompt_parts.append(f"Người dùng: {question}")
        prompt_parts.append("Trợ lý:")
        
        # Gộp thành một prompt
        full_prompt = "\n".join(prompt_parts)
        
        # Tạo model và gọi API (dùng cách đơn giản như llm_service.py)
        model = genai.GenerativeModel(model_name=settings.GEMINI_MODEL)
        response = model.generate_content(full_prompt)
        
        answer = (response.text or "").strip()
        if not answer:
            raise ValueError("Gemini trả về câu trả lời rỗng")
        
        return answer
    
    except Exception as e:
        print(f"[Chatbot] Error calling Gemini: {e}")
        raise ValueError(f"Lỗi khi gọi Gemini AI: {str(e)}")

def save_chat_message(
    chatbot_id: int,
    question: str,
    answer: str,
    db: Session
) -> ChatbotDetail:
    """Lưu câu hỏi và câu trả lời vào database"""
    detail = ChatbotDetail(
        chatbot_id=chatbot_id,
        question=question,
        answer=answer
    )
    db.add(detail)
    db.commit()
    db.refresh(detail)
    return detail

def get_chat_history(chatbot_id: int, db: Session, limit: int = 50) -> list:
    """
    Lấy lịch sử chat từ database.
    Trả về list of dict với 'question' và 'answer'
    """
    details = db.query(ChatbotDetail).filter(
        ChatbotDetail.chatbot_id == chatbot_id
    ).order_by(ChatbotDetail.created_at.asc()).limit(limit).all()
    
    return [
        {"question": d.question, "answer": d.answer}
        for d in details
    ]

def end_chatbot_session(chatbot_id: int, user_id: int, db: Session) -> Chatbot:
    """Kết thúc session chatbot"""
    chatbot = db.query(Chatbot).filter(
        Chatbot.chatbot_id == chatbot_id,
        Chatbot.user_id == user_id
    ).first()
    
    if not chatbot:
        raise ValueError("Không tìm thấy session chatbot")
    
    from datetime import datetime
    chatbot.status = ChatbotStatus.ended
    chatbot.end_at = datetime.utcnow()
    db.commit()
    db.refresh(chatbot)
    return chatbot
