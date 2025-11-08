# app/api/v1/routes_support.py
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from sqlalchemy import select
from pathlib import Path
from uuid import uuid4
import shutil

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

router = APIRouter(prefix="/support", tags=["support"])

# ====== cấu hình nơi lưu file đính kèm ======
UPLOAD_ROOT = Path("uploads") / "support"
UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)

def _save_attachment(ticket_id: int, file: UploadFile) -> str:
    ticket_dir = UPLOAD_ROOT / str(ticket_id)
    ticket_dir.mkdir(parents=True, exist_ok=True)
    ext = Path(file.filename).suffix.lower()
    safe_name = f"{uuid4().hex}{ext}"
    save_path = ticket_dir / safe_name
    with save_path.open("wb") as f:
        shutil.copyfileobj(file.file, f)
    return f"/uploads/support/{ticket_id}/{safe_name}"

# ===================== TICKETS =====================

@router.post("/tickets/create_ticket", response_model=SupportTicketOut, status_code=status.HTTP_201_CREATED)
def create_ticket(payload: SupportTicketCreate, db: Session = Depends(get_db), user: Users = Depends(get_current_user)):
    """Người dùng đăng nhập tạo phiếu hỗ trợ"""
    ticket = SupportTicket(
        user_id=user.user_id,
        title=payload.title,
        description=payload.description,
        status=TicketStatus.processing
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)
    return ticket

@router.get("/tickets/my_list", response_model=list[SupportTicketWithMessages])
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

@router.get("/tickets/getlistall_ticket", response_model=list[SupportTicketWithMessages], dependencies=[Depends(require_perm("support:read"))])
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

@router.get("/messages/of/{ticket_id}/getlistall_message", response_model=list[SupportMessageOut])
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
    message: str = Form(...),
    file: UploadFile | None = File(None),
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user)
):
    """
    Tạo tin nhắn:
    - Người dùng: gửi bổ sung vào ticket của chính mình
    - Support/Admin: trả lời vào bất kỳ ticket nào (support:reply)
    - Nếu Support/Admin trả lời => ticket.status = processed
    - Nếu User (chủ ticket) phản hồi => ticket.status = processing
    """
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Không tìm thấy ticket")

    is_owner = (ticket.user_id == user.user_id)
    if not is_owner:
        require_perm("support:reply")(user)

    attachment_url = None
    if file:
        attachment_url = _save_attachment(ticket_id, file)

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
