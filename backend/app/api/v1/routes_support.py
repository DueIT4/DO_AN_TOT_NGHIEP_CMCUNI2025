# app/api/v1/routes_support.py
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from sqlalchemy import select
from pathlib import Path
from typing import List, Optional

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.user import Users
from app.models.role import RoleType
from app.models.support import SupportTicket, SupportMessage, TicketStatus
from app.schemas.support import (
    SupportTicketCreate, SupportTicketOut, SupportTicketWithMessages,
    SupportMessageOut
)
from app.services.permissions import require_perm
from app.services.cloudinary_service import upload_image_to_cloudinary  # ✅ Import service mới

router = APIRouter(prefix="/support", tags=["support"])

# ĐÃ LOẠI BỎ: UPLOAD_ROOT và _save_attachment (Lưu local) để chạy trên Cloud Run

# ===================== TICKETS =====================

@router.post("/tickets/create_ticket", response_model=SupportTicketOut, status_code=status.HTTP_201_CREATED)
async def create_ticket(
    title: str = Form(...),
    description: str = Form(...),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user)
):
    """
    Người dùng đăng nhập tạo phiếu hỗ trợ (Hỗ trợ upload ảnh đính kèm)
    """
    # 1. Tạo Ticket
    ticket = SupportTicket(
        user_id=user.user_id,
        title=title,
        description=description,
        status=TicketStatus.processing
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)

    # 2. Nếu có file đính kèm, tạo ngay 1 message đầu tiên
    if file:
        content = await file.read()
        if content:
            # Upload lên Cloudinary
            attachment_url = upload_image_to_cloudinary(
                content, 
                folder=f"zestguard/support/ticket_{ticket.ticket_id}"
            )
            
            if attachment_url:
                msg = SupportMessage(
                    ticket_id=ticket.ticket_id,
                    sender_id=user.user_id,
                    message="Hình ảnh đính kèm",
                    attachment_url=attachment_url
                )
                db.add(msg)
                db.commit()

    return ticket

@router.get("/tickets/my_list", response_model=List[SupportTicketWithMessages])
def list_my_tickets(db: Session = Depends(get_db), user: Users = Depends(get_current_user)):
    rows = db.scalars(
        select(SupportTicket)
        .where(SupportTicket.user_id == user.user_id)
        .order_by(SupportTicket.created_at.desc())
    ).all()
    return [
        SupportTicketWithMessages(
            ticket_id=r.ticket_id,
            user_id=r.user_id,
            title=r.title,
            description=r.description,
            status=r.status,
            created_at=r.created_at,
            messages_count=len(r.messages)
        )
        for r in rows
    ]

@router.get("/tickets/getlistall_ticket", response_model=List[SupportTicketWithMessages], dependencies=[Depends(require_perm("support:read"))])
def list_all_tickets(db: Session = Depends(get_db)):
    rows = db.scalars(
        select(SupportTicket)
        .order_by(SupportTicket.created_at.desc())
    ).all()
    return [
        SupportTicketWithMessages(
            ticket_id=r.ticket_id,
            user_id=r.user_id,
            title=r.title,
            description=r.description,
            status=r.status,
            created_at=r.created_at,
            messages_count=len(r.messages)
        )
        for r in rows
    ]

@router.get("/tickets/{ticket_id}/read_detail", response_model=SupportTicketOut)
def get_ticket(ticket_id: int, db: Session = Depends(get_db), user: Users = Depends(get_current_user)):
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Không tìm thấy ticket")
    # chỉ chủ sở hữu hoặc người có quyền support:read
    if ticket.user_id != user.user_id:
        try:
            require_perm("support:read")(user)
        except HTTPException:
            raise HTTPException(status_code=403, detail="Không đủ quyền")
    return ticket

@router.delete("/tickets/{ticket_id}/delete", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(require_perm("support:manage"))])
def delete_ticket(ticket_id: int, db: Session = Depends(get_db)):
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Không tìm thấy ticket")
    db.delete(ticket)
    db.commit()
    return {"ok": True}

# ===================== MESSAGES =====================

@router.get("/messages/of/{ticket_id}/getlistall_message", response_model=List[SupportMessageOut])
def list_messages(ticket_id: int, db: Session = Depends(get_db), user: Users = Depends(get_current_user)):
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Không tìm thấy ticket")
    # chủ sở hữu xem hoặc support đọc
    if ticket.user_id != user.user_id:
        try:
            require_perm("support:read")(user)
        except HTTPException:
            raise HTTPException(status_code=403, detail="Không đủ quyền")

    rows = db.scalars(
        select(SupportMessage)
        .where(SupportMessage.ticket_id == ticket_id)
        .order_by(SupportMessage.created_at.asc())
    ).all()
    return rows

@router.post("/messages/create_message", response_model=SupportMessageOut, status_code=status.HTTP_201_CREATED)
async def create_message(
    ticket_id: int = Form(...),
    message: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user)
):
    """
    Tạo tin nhắn:
    - Người dùng: gửi bổ sung vào ticket của chính mình
    - Support/Admin: trả lời vào bất kỳ ticket nào (support:reply)
    - File đính kèm sẽ được lưu lên Cloudinary
    """
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Không tìm thấy ticket")

    is_owner = (ticket.user_id == user.user_id)
    if not is_owner:
        require_perm("support:reply")(user)

    # ✅ THAY ĐỔI: Upload file trực tiếp lên Cloudinary
    attachment_url = None
    if file:
        content = await file.read()
        if content:
            attachment_url = upload_image_to_cloudinary(content, folder=f"zestguard/support/ticket_{ticket_id}")
            if not attachment_url:
                raise HTTPException(status_code=500, detail="Lỗi khi tải file đính kèm lên cloud")

    msg = SupportMessage(
        ticket_id=ticket_id,
        sender_id=user.user_id,
        message=message,
        attachment_url=attachment_url
    )
    db.add(msg)

    # ====== CẬP NHẬT TRẠNG THÁI ======
    role = user.role.role_type if user.role else None
    if role in (RoleType.admin, RoleType.support):
        ticket.status = TicketStatus.processed
    elif is_owner:
        ticket.status = TicketStatus.processing

    db.commit()
    db.refresh(msg)
    return msg

@router.delete("/messages/{message_id}/delete", status_code=status.HTTP_204_NO_CONTENT, dependencies=[Depends(require_perm("support:manage"))])
def delete_message(message_id: int, db: Session = Depends(get_db)):
    msg = db.get(SupportMessage, message_id)
    if not msg:
        raise HTTPException(status_code=404, detail="Không tìm thấy message")
    db.delete(msg)
    db.commit()
    return {"ok": True}