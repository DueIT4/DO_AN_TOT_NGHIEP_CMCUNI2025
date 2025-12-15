# app/api/v1/routes_dashboard.py
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
import io
import csv

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.services.permissions import require_perm
from app.schemas.dashboard import DashboardSummary
from app.services.dashboard_service import build_dashboard_summary

router = APIRouter(
    prefix="/admin/dashboard",
    tags=["Dashboard"],
)


@router.get("", response_model=DashboardSummary,
            dependencies=[Depends(require_perm("admin:read"))])
def get_admin_dashboard(
    range: str = Query("7d", pattern="^(7d|30d|90d)$"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Dashboard tổng hợp cho admin.
    range: 7d | 30d | 90d
    """
    return build_dashboard_summary(db=db, range_str=range)


@router.get("/export", dependencies=[Depends(require_perm("admin:read"))])
def export_admin_dashboard(
    range: str = Query("7d", pattern="^(7d|30d|90d)$"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Xuất báo cáo dashboard dưới dạng CSV.
    Gộp một số phần: detections_over_time, top_diseases, tickets_by_status.
    """
    summary: DashboardSummary = build_dashboard_summary(db=db, range_str=range)

    output = io.StringIO()
    writer = csv.writer(output)

    # Header
    writer.writerow(["section", "col1", "col2", "col3"])

    # 1. Lượt dự đoán theo ngày
    for p in summary.detections_over_time:
        writer.writerow([
            "detections_over_time",
            p.date.isoformat(),
            p.count,
            "",
        ])

    # 2. Top bệnh
    for d in summary.top_diseases:
        writer.writerow([
            "top_diseases",
            d.disease_name,
            d.count,
            "",
        ])

    # 3. Ticket theo trạng thái
    for t in summary.tickets_by_status:
        writer.writerow([
            "tickets_by_status",
            t.status,
            t.count,
            "",
        ])

    # 4. Detection gần đây
    for r in summary.recent_detections:
        writer.writerow([
            "recent_detections",
            r.created_at.isoformat(),
            r.username or "",
            f"{r.disease_name or ''} (conf={r.confidence if r.confidence is not None else ''})",
        ])

    # 5. Ticket gần đây
    for r in summary.recent_tickets:
        writer.writerow([
            "recent_tickets",
            r.created_at.isoformat(),
            r.username or "",
            f"{r.title or ''} [{r.status or ''}]",
        ])

    output.seek(0)
    filename = f"dashboard_report_{range}.csv"

    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        },
    )
