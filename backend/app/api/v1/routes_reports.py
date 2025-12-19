from datetime import datetime, timedelta
from pathlib import Path
from typing import List

import pdfkit
from fastapi import APIRouter, Depends, Query
from fastapi.responses import Response
from jinja2 import Environment, FileSystemLoader, select_autoescape
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.services.permissions import require_perm
from app.services.dashboard_service import build_dashboard_summary_between


router = APIRouter(
    prefix="/admin/reports",
    tags=["Reports"],
    dependencies=[Depends(require_perm("admin:read"))],
)

BASE_DIR = Path(__file__).resolve().parents[2]  # .../app
TEMPLATE_DIR = BASE_DIR / "templates" / "reports"

env = Environment(
    loader=FileSystemLoader(str(TEMPLATE_DIR)),
    autoescape=select_autoescape(["html", "xml"]),
)


def _days(range_str: str) -> int:
    return {"7d": 7, "30d": 30, "90d": 90}.get(range_str, 7)


def _range_label(r: str) -> str:
    return {"7d": "7 ngày", "30d": "30 ngày", "90d": "90 ngày"}.get(r, r)


def _delta(curr: int, prev: int) -> str:
    curr = curr or 0
    prev = prev or 0
    d = curr - prev
    return f"+{d}" if d > 0 else str(d)


def _pct(curr, prev, min_base: int = 10) -> str:
    """
    % thay đổi so với kỳ trước (chuẩn trình sếp):
    - prev = 0  -> '—' hoặc 'từ 0 lên X'
    - prev < min_base -> '—' (tránh % phóng đại khi nền nhỏ)
    """
    curr = 0 if curr is None else float(curr)
    prev = 0 if prev is None else float(prev)

    if prev == 0:
        return "—" if curr == 0 else f"từ 0 lên {int(curr)}"

    if prev < min_base:
        return "—"

    v = (curr - prev) / prev * 100.0
    return f"{'+' if v > 0 else ''}{v:.1f}%"


def _product_insights_from_top_disease(name: str, count: int, total: int) -> List[str]:
    if not name or name == "—" or count == 0:
        return ["Chưa đủ dữ liệu dự đoán theo bệnh trong kỳ để rút ra xu hướng đáng tin cậy."]

    share = (count / total * 100.0) if total else 0.0
    notes: List[str] = []

    notes.append(
        f"Nhóm bệnh được dự đoán nhiều nhất là “{name}” ({count} lượt, ~{share:.1f}%). "
        "Đây là tín hiệu nhu cầu người dùng đang tập trung vào nhóm vấn đề này."
    )
    notes.append(
        "Ưu tiên sản phẩm: tối ưu trải nghiệm cho nhóm bệnh này (hướng dẫn chụp ảnh, giải thích kết quả, FAQ, cảnh báo mức độ)."
    )
    notes.append(
        "Ưu tiên tăng trưởng: xây nội dung/chiến dịch theo nhóm bệnh phổ biến để tăng chuyển đổi và giữ chân."
    )
    notes.append(
        "Ưu tiên vận hành: bổ sung kịch bản support & triage cho nhóm bệnh này để giảm ticket và tăng hài lòng."
    )
    return notes


def _insights(curr, prev) -> List[str]:
    notes: List[str] = []

    # Detections trend
    if prev.total_detections == 0 and curr.total_detections > 0:
        notes.append(f"Lượt dự đoán tăng từ 0 lên {curr.total_detections}, hệ thống bắt đầu có mức sử dụng.")
    elif prev.total_detections > 0:
        rate = (curr.total_detections - prev.total_detections) / prev.total_detections
        if rate >= 0.2:
            notes.append("Lượt dự đoán tăng đáng kể (>= 20%) so với kỳ trước.")
        elif rate <= -0.2:
            notes.append("Lượt dự đoán giảm đáng kể (<= -20%), cần kiểm tra mức độ sử dụng / lỗi thiết bị.")

    # Tickets
    if curr.open_tickets > prev.open_tickets:
        notes.append("Số ticket đang mở tăng, cần ưu tiên xử lý để tránh tồn đọng.")
    elif curr.open_tickets == 0:
        notes.append("Không có ticket đang mở trong kỳ này.")

    # Devices
    if curr.inactive_devices > prev.inactive_devices:
        notes.append("Thiết bị offline tăng, cần kiểm tra kết nối/nguồn các thiết bị.")

    if not notes:
        notes.append("Các chỉ số ổn định, không ghi nhận biến động bất thường.")

    return notes


@router.get("/summary")
def export_summary_pdf(
    range: str = Query("7d", pattern="^(7d|30d|90d)$"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    now = datetime.now()
    days = _days(range)

    current_end = now
    current_start = now - timedelta(days=days)
    prev_end = current_start
    prev_start = prev_end - timedelta(days=days)

    curr = build_dashboard_summary_between(db, current_start, current_end)
    prev = build_dashboard_summary_between(db, prev_start, prev_end)

    # ===== Top disease (Top 1 + share) =====
    top1 = curr.top_diseases[0] if getattr(curr, "top_diseases", None) else None
    top_disease_name = top1.disease_name if top1 else "—"
    top_disease_count = int(top1.count) if top1 else 0
    top_disease_share = (
        (top_disease_count / curr.total_detections) * 100.0
        if curr.total_detections else 0.0
    )

    # ===== Insights (kết hợp insight hệ thống + ý nghĩa sản phẩm) =====
    insights = _insights(curr, prev) + _product_insights_from_top_disease(
        top_disease_name, top_disease_count, curr.total_detections
    )

    tpl = env.get_template("summary_compare.html")
    html_str = tpl.render(
        range_label=_range_label(range),
        cur_from=current_start.strftime("%d/%m/%Y"),
        cur_to=current_end.strftime("%d/%m/%Y"),
        prev_from=prev_start.strftime("%d/%m/%Y"),
        prev_to=prev_end.strftime("%d/%m/%Y"),
        day=now.day, month=now.month, year=now.year,

        curr_new_users=curr.new_users,
        prev_new_users=prev.new_users,
        d_new_users=_delta(curr.new_users, prev.new_users),
        # p_new_users=_pct(curr.new_users, prev.new_users),

        curr_total_detections=curr.total_detections,
        prev_total_detections=prev.total_detections,
        d_total_detections=_delta(curr.total_detections, prev.total_detections),
        # p_total_detections=_pct(curr.total_detections, prev.total_detections),

        curr_open_tickets=curr.open_tickets,
        prev_open_tickets=prev.open_tickets,
        d_open_tickets=_delta(curr.open_tickets, prev.open_tickets),
        # p_open_tickets=_pct(curr.open_tickets, prev.open_tickets),

        curr_inactive_devices=curr.inactive_devices,
        prev_inactive_devices=prev.inactive_devices,
        d_inactive_devices=_delta(curr.inactive_devices, prev.inactive_devices),
        # p_inactive_devices=_pct(curr.inactive_devices, prev.inactive_devices),

        # new blocks for report
        top_disease_name=top_disease_name,
        top_disease_count=top_disease_count,
        top_disease_share=(f"{top_disease_share:.1f}%" if top1 and curr.total_detections else "—"),
        top_diseases=curr.top_diseases,

        insights=insights,
    )

    options = {
        "enable-local-file-access": "",
        "page-size": "A4",
        "encoding": "UTF-8",
        "margin-top": "18mm",
        "margin-right": "16mm",
        "margin-bottom": "18mm",
        "margin-left": "16mm",
        "disable-smart-shrinking": "",
    }

    pdf_bytes = pdfkit.from_string(html_str, False, options=options)

    filename = f"report_summary_{range}.pdf"
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
