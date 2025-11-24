# app/api/v1/routes_dashboard.py
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

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
