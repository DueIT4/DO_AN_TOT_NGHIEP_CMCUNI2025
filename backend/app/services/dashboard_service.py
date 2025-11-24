from datetime import datetime, timedelta
from typing import List

from sqlalchemy.orm import Session
from sqlalchemy import func, desc

from app.models.devices import Device
from app.models.user import Users
from app.models.image_detection import Img, Detection, Disease
from app.models.support import SupportTicket  # model mapping bảng support_tickets

from app.schemas.dashboard import (
    DashboardSummary,
    DetectionTimePoint,
    DiseaseStat,
    TicketStatusStat,
    RecentDetectionItem,
    RecentTicketItem,
)


def _get_range_dates(range_str: str) -> tuple[datetime, datetime]:
    """
    range_str: '7d' | '30d' | '90d'
    """
    now = datetime.utcnow()
    if range_str == "30d":
        start = now - timedelta(days=30)
    elif range_str == "90d":
        start = now - timedelta(days=90)
    else:  # default 7d
        start = now - timedelta(days=7)
    return start, now


def build_dashboard_summary(db: Session, range_str: str = "7d") -> DashboardSummary:
    start, end = _get_range_dates(range_str)

    # ====================== DEVICES ======================
    # devices: device_id, status ENUM('active','maintain','inactive')
    total_devices = db.query(func.count(Device.device_id)).scalar() or 0

    active_devices = (
        db.query(func.count(Device.device_id))
        .filter(Device.status == "active")
        .scalar()
        or 0
    )
    inactive_devices = (
        db.query(func.count(Device.device_id))
        .filter(Device.status == "inactive")
        .scalar()
        or 0
    )
    # (tùy bạn có dùng hay không, maintain nằm ngoài 2 nhóm trên)

    # ======================== USERS ======================
    total_users = db.query(func.count(Users.user_id)).scalar() or 0
    # users.created_at: TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    new_users = (
        db.query(func.count(Users.user_id))
        .filter(Users.created_at >= start)
        .scalar()
        or 0
    )

    # ===================== DETECTIONS ====================
    # detections: detection_id, img_id, disease_id, confidence, created_at
    detections_range_q = (
        db.query(Detection)
        .filter(Detection.created_at >= start, Detection.created_at <= end)
    )

    total_detections = detections_range_q.count()

    # detections_over_time: group by DATE(created_at)
    detections_over_time_rows = (
        db.query(
            func.date(Detection.created_at).label("d"),
            func.count(Detection.detection_id),
        )
        .filter(Detection.created_at >= start, Detection.created_at <= end)
        .group_by(func.date(Detection.created_at))
        .order_by(func.date(Detection.created_at))
        .all()
    )
    detections_over_time: List[DetectionTimePoint] = [
        DetectionTimePoint(date=row[0], count=row[1])
        for row in detections_over_time_rows
    ]

    # top_diseases: group by disease_id (join bảng diseases)
    top_diseases_rows = (
        db.query(
            Disease.name,
            func.count(Detection.detection_id).label("cnt"),
        )
        .join(Detection, Detection.disease_id == Disease.disease_id)
        .filter(Detection.created_at >= start, Detection.created_at <= end)
        .group_by(Disease.name)
        .order_by(desc("cnt"))
        .limit(5)
        .all()
    )
    top_diseases: List[DiseaseStat] = [
        DiseaseStat(disease_name=name or "Không rõ", count=cnt)
        for name, cnt in top_diseases_rows
    ]

    # ====================== TICKETS ======================
    # support_tickets: ticket_id, user_id, title, description,
    # status ENUM('processing','processed'), created_at
    tickets_range_q = (
        db.query(SupportTicket)
        .filter(SupportTicket.created_at >= start,
                SupportTicket.created_at <= end)
    )

    total_tickets = tickets_range_q.count()

    # "open_tickets" = ticket đang xử lý (processing)
    open_tickets = (
        tickets_range_q.filter(SupportTicket.status == "processing").count()
    )

    tickets_by_status_rows = (
        db.query(
            SupportTicket.status,
            func.count(SupportTicket.ticket_id),
        )
        .filter(SupportTicket.created_at >= start,
                SupportTicket.created_at <= end)
        .group_by(SupportTicket.status)
        .all()
    )
    tickets_by_status: List[TicketStatusStat] = [
        TicketStatusStat(status=status or "unknown", count=count)
        for status, count in tickets_by_status_rows
    ]

    # ============= RECENT DETECTIONS (10 GẦN NHẤT) =============
    recent_detection_rows = (
        db.query(Detection, Img, Users, Disease)
        .join(Img, Detection.img_id == Img.img_id)
        .outerjoin(Users, Img.user_id == Users.user_id)
        .outerjoin(Disease, Detection.disease_id == Disease.disease_id)
        .order_by(desc(Detection.created_at))
        .limit(10)
        .all()
    )

    recent_detections: List[RecentDetectionItem] = []
    for det, img, user, disease in recent_detection_rows:
        recent_detections.append(
            RecentDetectionItem(
                detection_id=det.detection_id,
                user_id=user.user_id if user else None,
                username=user.username if user else None,
                disease_name=disease.name if disease else None,
                confidence=float(det.confidence)
                if det.confidence is not None
                else None,
                created_at=det.created_at,
            )
        )

    # ============= RECENT TICKETS (10 GẦN NHẤT) =============
    recent_tickets_rows = (
        db.query(SupportTicket, Users)
        .outerjoin(Users, SupportTicket.user_id == Users.user_id)
        .order_by(desc(SupportTicket.created_at))
        .limit(10)
        .all()
    )

    recent_tickets: List[RecentTicketItem] = []
    for ticket, user in recent_tickets_rows:
        recent_tickets.append(
            RecentTicketItem(
                ticket_id=ticket.ticket_id,
                user_id=user.user_id if user else None,
                username=user.username if user else None,
                status=ticket.status,
                title=ticket.title,
                created_at=ticket.created_at,
            )
        )

    # ====================== KẾT QUẢ ======================
    return DashboardSummary(
        total_devices=total_devices,
        active_devices=active_devices,
        inactive_devices=inactive_devices,
        total_users=total_users,
        new_users=new_users,
        total_detections=total_detections,
        detections_over_time=detections_over_time,
        top_diseases=top_diseases,
        total_tickets=total_tickets,
        open_tickets=open_tickets,
        tickets_by_status=tickets_by_status,
        recent_detections=recent_detections,
        recent_tickets=recent_tickets,
    )
