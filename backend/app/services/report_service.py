from datetime import datetime, timedelta, timezone

def _parse_range_days(range_str: str) -> int:
    """Chuyển đổi string range sang số ngày nguyên"""
    return {"7d": 7, "30d": 30, "90d": 90}.get(range_str, 7)

def get_periods(range_str: str):
    """
    Trả về (current_start, current_end, prev_start, prev_end) theo chuẩn UTC.
    current_end = thời điểm hiện tại.
    prev_end = thời điểm bắt đầu của kỳ này.
    """
    days = _parse_range_days(range_str)
    now = datetime.now(timezone.utc)

    current_end = now
    current_start = now - timedelta(days=days)

    prev_end = current_start
    prev_start = prev_end - timedelta(days=days)

    return current_start, current_end, prev_start, prev_end