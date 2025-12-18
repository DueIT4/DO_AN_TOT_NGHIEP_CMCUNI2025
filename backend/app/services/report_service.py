# app/services/report_service.py
from datetime import datetime, timedelta, timezone

def _parse_range_days(range_str: str) -> int:
    return {"7d": 7, "30d": 30, "90d": 90}.get(range_str, 7)

def get_periods(range_str: str):
    """
    Trả về (current_start, current_end, prev_start, prev_end) theo UTC.
    current_end = now
    prev_end = current_start
    """
    days = _parse_range_days(range_str)
    now = datetime.now(timezone.utc)

    current_end = now
    current_start = now - timedelta(days=days)

    prev_end = current_start
    prev_start = prev_end - timedelta(days=days)

    return current_start, current_end, prev_start, prev_end
