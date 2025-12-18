# app/api/v1/routes_support_admin.py
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Body
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.services.permissions import require_perm
from app.schemas.support_admin import (
    AdminTicketList,
    AdminTicketDetail,
    AdminSupportMessageOut,
)
from app.services.support_admin_service import (
    list_tickets_admin,
    get_ticket_detail_admin,
    add_admin_message,
    update_ticket_status,
    TicketNotFoundError,
)

router = APIRouter(
    prefix="/support/admin",
    tags=["Support"],
    dependencies=[Depends(require_perm("support:manage"))],  # tuỳ quyền bạn đặt
)


@router.get("/tickets", response_model=AdminTicketList)
def list_tickets(
    db: Session = Depends(get_db),
    status: Optional[str] = Query(None, description="processing/processed"),
    search: Optional[str] = Query(None, min_length=1),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
):
    return list_tickets_admin(
        db=db,
        status=status,
        search=search,
        skip=skip,
        limit=limit,
    )


@router.get("/tickets/{ticket_id}", response_model=AdminTicketDetail)
def ticket_detail(
    ticket_id: int,
    db: Session = Depends(get_db),
):
    try:
        return get_ticket_detail_admin(db, ticket_id)
    except TicketNotFoundError:
        raise HTTPException(status_code=404, detail="Ticket không tồn tại")


@router.post("/tickets/{ticket_id}/messages", response_model=AdminSupportMessageOut)
def send_admin_message(
    ticket_id: int,
    payload: dict = Body(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    message = (payload.get("message") or "").strip()
    attachment_url = payload.get("attachment_url")

    if not message:
        raise HTTPException(status_code=400, detail="Nội dung tin nhắn trống")

    try:
        return add_admin_message(
            db=db,
            ticket_id=ticket_id,
            admin_user_id=current_user.user_id,
            message=message,
            attachment_url=attachment_url,
        )
    except TicketNotFoundError:
        raise HTTPException(status_code=404, detail="Ticket không tồn tại")


@router.patch("/tickets/{ticket_id}/status", response_model=AdminTicketDetail)
def change_ticket_status(
    ticket_id: int,
    payload: dict = Body(...),
    db: Session = Depends(get_db),
):
    status = payload.get("status")
    if status not in ("processing", "processed"):
        raise HTTPException(status_code=400, detail="Trạng thái không hợp lệ")

    try:
        return update_ticket_status(db, ticket_id, status=status)
    except TicketNotFoundError:
        raise HTTPException(status_code=404, detail="Ticket không tồn tại")
