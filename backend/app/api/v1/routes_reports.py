import platform
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

# Thiết lập đường dẫn template
BASE_DIR = Path(__file__).resolve().parents[2]  # Trỏ về thư mục app
TEMPLATE_DIR = BASE_DIR / "templates" / "reports"

env = Environment(
    loader=FileSystemLoader(str(TEMPLATE_DIR)),
    autoescape=select_autoescape(["html", "xml"]),
)

# --- CẤU HÌNH WKHTMLTOPDF CHUẨN ---
def get_pdfkit_config():
    """Tự động phát hiện OS để chọn path wkhtmltopdf phù hợp"""
    if platform.system() == "Windows":
        # Đường dẫn mặc định trên Windows, hãy sửa nếu bạn cài chỗ khác
        path_wkhtmltopdf = r'C:\Program Files\wkhtmltopdf\bin\wkhtmltopdf.exe'
    else:
        # Đường dẫn mặc định trong Docker (Linux) sau khi cài qua apt-get
        path_wkhtmltopdf = '/usr/bin/wkhtmltopdf'
    
    return pdfkit.configuration(wkhtmltopdf=path_wkhtmltopdf)

# --- CÁC HÀM HELPER GIỮ NGUYÊN ---
def _days(range_str: str) -> int:
    return {"7d": 7, "30d": 30, "90d": 90}.get(range_str, 7)

def _range_label(r: str) -> str:
    return {"7d": "7 ngày", "30d": "30 ngày", "90d": "90 ngày"}.get(r, r)

def _delta(curr: int, prev: int) -> str:
    curr, prev = (curr or 0), (prev or 0)
    d = curr - prev
    return f"+{d}" if d > 0 else str(d)

def _product_insights_from_top_disease(name: str, count: int, total: int) -> List[str]:
    if not name or name == "—" or count == 0:
        return ["Chưa đủ dữ liệu dự đoán theo bệnh trong kỳ để rút ra xu hướng đáng tin cậy."]
    share = (count / total * 100.0) if total else 0.0
    return [
        f"Nhóm bệnh được dự đoán nhiều nhất là “{name}” ({count} lượt, ~{share:.1f}%).",
        "Ưu tiên sản phẩm: tối ưu trải nghiệm cho nhóm bệnh này (hướng dẫn chụp ảnh, giải thích kết quả).",
        "Ưu tiên vận hành: bổ sung kịch bản support cho nhóm bệnh phổ biến."
    ]

def _insights(curr, prev) -> List[str]:
    notes = []
    if prev.total_detections == 0 and curr.total_detections > 0:
        notes.append(f"Hệ thống bắt đầu có lượt dự đoán ({curr.total_detections}).")
    elif prev.total_detections > 0:
        rate = (curr.total_detections - prev.total_detections) / prev.total_detections
        if rate >= 0.2: notes.append("Lượt dự đoán tăng mạnh (>20%).")
        elif rate <= -0.2: notes.append("Lượt dự đoán giảm mạnh (>20%), cần kiểm tra thiết bị.")
    
    if curr.open_tickets > prev.open_tickets: notes.append("Ticket đang mở tăng, cần xử lý tồn đọng.")
    if curr.inactive_devices > prev.inactive_devices: notes.append("Số thiết bị offline tăng, cần kiểm tra kết nối.")
    
    return notes or ["Các chỉ số ổn định, không ghi nhận biến động bất thường."]

# --- ENDPOINT CHÍNH ---
@router.get("/summary")
def export_summary_pdf(
    range: str = Query("7d", pattern="^(7d|30d|90d)$"),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    now = datetime.now()
    days = _days(range)

    current_end, current_start = now, now - timedelta(days=days)
    prev_end, prev_start = current_start, current_start - timedelta(days=days)

    curr = build_dashboard_summary_between(db, current_start, current_end)
    prev = build_dashboard_summary_between(db, prev_start, prev_end)

    top1 = curr.top_diseases[0] if getattr(curr, "top_diseases", None) else None
    top_disease_name = top1.disease_name if top1 else "—"
    top_disease_count = int(top1.count) if top1 else 0
    top_disease_share = (top_disease_count / curr.total_detections * 100) if curr.total_detections else 0

    insights = _insights(curr, prev) + _product_insights_from_top_disease(
        top_disease_name, top_disease_count, curr.total_detections
    )

    # Render HTML từ template
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
        curr_total_detections=curr.total_detections,
        prev_total_detections=prev.total_detections,
        d_total_detections=_delta(curr.total_detections, prev.total_detections),
        curr_open_tickets=curr.open_tickets,
        prev_open_tickets=prev.open_tickets,
        d_open_tickets=_delta(curr.open_tickets, prev.open_tickets),
        curr_inactive_devices=curr.inactive_devices,
        prev_inactive_devices=prev.inactive_devices,
        d_inactive_devices=_delta(curr.inactive_devices, prev.inactive_devices),
        top_disease_name=top_disease_name,
        top_disease_count=top_disease_count,
        top_disease_share=(f"{top_disease_share:.1f}%" if top1 and curr.total_detections else "—"),
        top_diseases=curr.top_diseases,
        insights=insights,
    )

    # Cấu hình PDF options
    options = {
        "page-size": "A4",
        "encoding": "UTF-8",
        "margin-top": "15mm",
        "margin-right": "15mm",
        "margin-bottom": "15mm",
        "margin-left": "15mm",
        "enable-local-file-access": "",
        "quiet": ""
    }

    try:
        # Gọi PDFKit với configuration đã lấy ở trên
        config = get_pdfkit_config()
        pdf_bytes = pdfkit.from_string(html_str, False, options=options, configuration=config)
        
        filename = f"report_summary_{range}_{now.strftime('%Y%m%d')}.pdf"
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )
    except Exception as e:
        # Log lỗi chi tiết nếu render thất bại
        print(f"LỖI XUẤT PDF: {str(e)}")
        return Response(content=f"Lỗi tạo PDF: {str(e)}", status_code=500)