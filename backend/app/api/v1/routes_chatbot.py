# app/api/v1/routes_chatbot.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, func

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.user import Users
from app.models.chatbot import Chatbot, ChatbotDetail, ChatbotStatus
from app.schemas.chatbot import (
    ChatbotOut, ChatbotMessageCreate, ChatbotMessageOut,
    ChatbotSessionWithMessages
)
from app.services.chatbot_service import (
    get_or_create_chatbot_session,
    send_message_to_gemini,
    save_chat_message,
    get_chat_history,
    end_chatbot_session
)
from app.services.permissions import require_perm

router = APIRouter(prefix="/chatbot", tags=["chatbot"])

# ===================== SESSIONS =====================

@router.post("/sessions", response_model=ChatbotOut, status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(require_perm("self:read"))])
def create_chatbot_session(
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user)
):
    """Tạo session chatbot mới"""
    chatbot = Chatbot(
        user_id=user.user_id,
        status=ChatbotStatus.active
    )
    db.add(chatbot)
    db.commit()
    db.refresh(chatbot)
    
    # Đếm số messages
    count = db.query(func.count(ChatbotDetail.detail_id)).filter(
        ChatbotDetail.chatbot_id == chatbot.chatbot_id
    ).scalar()
    
    result = ChatbotOut(
        chatbot_id=chatbot.chatbot_id,
        user_id=chatbot.user_id,
        created_at=chatbot.created_at,
        end_at=chatbot.end_at,
        status=chatbot.status,
        details_count=count
    )
    return result

@router.get("/sessions", response_model=list[ChatbotOut],
            dependencies=[Depends(require_perm("self:read"))])
def list_chatbot_sessions(
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
    status_filter: ChatbotStatus | None = None
):
    """Lấy danh sách các session chatbot của user"""
    query = db.query(Chatbot).filter(Chatbot.user_id == user.user_id)
    
    if status_filter:
        query = query.filter(Chatbot.status == status_filter)
    
    chatbots = query.order_by(Chatbot.created_at.desc()).all()
    
    result = []
    for cb in chatbots:
        count = db.query(func.count(ChatbotDetail.detail_id)).filter(
            ChatbotDetail.chatbot_id == cb.chatbot_id
        ).scalar()
        
        # Chỉ thêm session có ít nhất 1 tin nhắn
        if count > 0:
            result.append(ChatbotOut(
                chatbot_id=cb.chatbot_id,
                user_id=cb.user_id,
                created_at=cb.created_at,
                end_at=cb.end_at,
                status=cb.status,
                details_count=count
            ))
    
    return result

@router.get("/sessions/{chatbot_id}", response_model=ChatbotSessionWithMessages,
            dependencies=[Depends(require_perm("self:read"))])
def get_chatbot_session(
    chatbot_id: int,
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user)
):
    """Lấy thông tin session và toàn bộ lịch sử chat"""
    chatbot = db.query(Chatbot).filter(
        Chatbot.chatbot_id == chatbot_id,
        Chatbot.user_id == user.user_id
    ).first()
    
    if not chatbot:
        raise HTTPException(status_code=404, detail="Không tìm thấy session chatbot")
    
    # Lấy tất cả messages
    details = db.query(ChatbotDetail).filter(
        ChatbotDetail.chatbot_id == chatbot_id
    ).order_by(ChatbotDetail.created_at.asc()).all()
    
    messages = [
        ChatbotMessageOut(
            detail_id=d.detail_id,
            chatbot_id=d.chatbot_id,
            question=d.question,
            answer=d.answer,
            created_at=d.created_at
        )
        for d in details
    ]
    
    count = len(messages)
    return ChatbotSessionWithMessages(
        chatbot_id=chatbot.chatbot_id,
        user_id=chatbot.user_id,
        created_at=chatbot.created_at,
        end_at=chatbot.end_at,
        status=chatbot.status,
        details_count=count,
        messages=messages
    )

@router.put("/sessions/{chatbot_id}/end", response_model=ChatbotOut,
            dependencies=[Depends(require_perm("self:update"))])
def end_session(
    chatbot_id: int,
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user)
):
    """Kết thúc session chatbot"""
    try:
        chatbot = end_chatbot_session(chatbot_id, user.user_id, db)
        count = db.query(func.count(ChatbotDetail.detail_id)).filter(
            ChatbotDetail.chatbot_id == chatbot.chatbot_id
        ).scalar()
        return ChatbotOut(
            chatbot_id=chatbot.chatbot_id,
            user_id=chatbot.user_id,
            created_at=chatbot.created_at,
            end_at=chatbot.end_at,
            status=chatbot.status,
            details_count=count
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

# ===================== MESSAGES =====================

@router.post("/messages", response_model=ChatbotMessageOut, status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(require_perm("self:read"))])
def send_message(
    payload: ChatbotMessageCreate,
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user)
):
    """
    Gửi câu hỏi đến chatbot và nhận câu trả lời.
    Nếu chatbot_id không được cung cấp, sẽ tự động tạo session mới.
    """
    # Lấy hoặc tạo session
    chatbot = get_or_create_chatbot_session(
        user_id=user.user_id,
        chatbot_id=payload.chatbot_id,
        db=db
    )
    
    # Lấy lịch sử chat để context
    chat_history = get_chat_history(chatbot.chatbot_id, db)
    
    # Gọi Gemini để lấy câu trả lời
    try:
        answer = send_message_to_gemini(payload.question, chat_history)
    except ValueError as e:
        raise HTTPException(status_code=500, detail=str(e))
    
    # Lưu vào database
    detail = save_chat_message(
        chatbot_id=chatbot.chatbot_id,
        question=payload.question,
        answer=answer,
        db=db
    )
    
    return ChatbotMessageOut(
        detail_id=detail.detail_id,
        chatbot_id=detail.chatbot_id,
        question=detail.question,
        answer=detail.answer,
        created_at=detail.created_at
    )

@router.get("/sessions/{chatbot_id}/messages", response_model=list[ChatbotMessageOut],
            dependencies=[Depends(require_perm("self:read"))])
def list_messages(
    chatbot_id: int,
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
    limit: int = 50
):
    """Lấy danh sách messages trong một session"""
    # Kiểm tra session thuộc về user
    chatbot = db.query(Chatbot).filter(
        Chatbot.chatbot_id == chatbot_id,
        Chatbot.user_id == user.user_id
    ).first()
    
    if not chatbot:
        raise HTTPException(status_code=404, detail="Không tìm thấy session chatbot")
    
    details = db.query(ChatbotDetail).filter(
        ChatbotDetail.chatbot_id == chatbot_id
    ).order_by(ChatbotDetail.created_at.asc()).limit(limit).all()
    
    return [
        ChatbotMessageOut(
            detail_id=d.detail_id,
            chatbot_id=d.chatbot_id,
            question=d.question,
            answer=d.answer,
            created_at=d.created_at
        )
        for d in details
    ]

