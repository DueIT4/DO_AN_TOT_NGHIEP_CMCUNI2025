# app/services/support_admin_service.py
from typing import Optional, List
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.models.support import SupportTicket, SupportMessage
from app.models.user import Users
from app.schemas.support_admin import (
    AdminTicketList,
    AdminTicketListItem,
    AdminTicketDetail,
    AdminSupportMessageOut,
)


class TicketNotFoundError(Exception):
    pass


def list_tickets_admin(
    db: Session,
    status: Optional[str],
    search: Optional[str],
    skip: int,
    limit: int,
) -> AdminTicketList:
    q = (
        db.query(SupportTicket, Users)
        .join(Users, SupportTicket.user_id == Users.user_id)
        .order_by(desc(SupportTicket.created_at))
    )

    if status:
        q = q.filter(SupportTicket.status == status)

    if search:
        like = f"%{search}%"
        q = q.filter(
            (SupportTicket.title.ilike(like))
            | (SupportTicket.description.ilike(like))
            | (Users.username.ilike(like))
        )

    total = q.count()
    rows = q.offset(skip).limit(limit).all()

    items: List[AdminTicketListItem] = []
    # app/services/support_admin_service.py
    for ticket, user in rows:
        items.append(
        AdminTicketListItem(
            ticket_id=ticket.ticket_id,
            user_id=ticket.user_id,
            username=user.username,
            title=ticket.title,
            description=ticket.description,   # 👈 THÊM DÒNG NÀY
            status=ticket.status,
            created_at=ticket.created_at,
        )
    )


    return AdminTicketList(total=total, items=items)


def get_ticket_detail_admin(
    db: Session,
    ticket_id: int,
) -> AdminTicketDetail:
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket:
        raise TicketNotFoundError

    user = db.get(Users, ticket.user_id)

    msgs = (
        db.query(SupportMessage, Users)
        .outerjoin(Users, SupportMessage.sender_id == Users.user_id)
        .filter(SupportMessage.ticket_id == ticket_id)
        .order_by(SupportMessage.created_at.asc())
        .all()
    )

    msg_items: List[AdminSupportMessageOut] = []
    for msg, sender in msgs:
        msg_items.append(
            AdminSupportMessageOut(
                message_id=msg.message_id,
                ticket_id=msg.ticket_id,
                sender_id=msg.sender_id,
                sender_name=sender.username if sender else "Hệ thống",
                message=msg.message,
                attachment_url=msg.attachment_url,
                created_at=msg.created_at,
            )
        )

    return AdminTicketDetail(
        ticket_id=ticket.ticket_id,
        user_id=ticket.user_id,
        username=user.username if user else None,
        title=ticket.title,
        description=ticket.description,
        status=ticket.status,
        created_at=ticket.created_at,
        messages=msg_items,
    )


def add_admin_message(
    db: Session,
    ticket_id: int,
    admin_user_id: int,
    message: str,
    attachment_url: Optional[str] = None,
) -> AdminSupportMessageOut:
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket:
        raise TicketNotFoundError

    msg = SupportMessage(
        ticket_id=ticket_id,
        sender_id=admin_user_id,
        message=message,
        attachment_url=attachment_url,
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)

    sender = db.get(Users, admin_user_id)

    return AdminSupportMessageOut(
        message_id=msg.message_id,
        ticket_id=msg.ticket_id,
        sender_id=msg.sender_id,
        sender_name=sender.username if sender else "Admin",
        message=msg.message,
        attachment_url=msg.attachment_url,
        created_at=msg.created_at,
    )


def update_ticket_status(
    db: Session,
    ticket_id: int,
    status: str,
) -> AdminTicketDetail:
    ticket = db.get(SupportTicket, ticket_id)
    if not ticket:
        raise TicketNotFoundError

    ticket.status = status
    db.commit()
    db.refresh(ticket)

    # trả về detail luôn
    return get_ticket_detail_admin(db, ticket_id)
