from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy.exc import SQLAlchemyError
from math import ceil

# -----------------------------
# 📦 Helper chung cho mọi service
# -----------------------------

class NotFoundError(Exception):
    """Custom exception khi không tìm thấy bản ghi"""
    def __init__(self, message: str):
        self.message = message
        super().__init__(message)

# -----------------------------
# ✅ GET hoặc 404
# -----------------------------
def get_or_404(db: Session, model, id: int):
    """
    Truy vấn 1 bản ghi theo ID, nếu không thấy thì raise 404.
    """
    obj = db.get(model, id)
    if not obj:
        raise HTTPException(status_code=404, detail=f"{model.__tablename__.capitalize()} ID={id} không tồn tại.")
    return obj

# -----------------------------
# ✅ Commit + refresh tiện dụng
# -----------------------------
def commit_refresh(db: Session, instance):
    """
    Commit phiên SQLAlchemy, rollback nếu lỗi, refresh đối tượng.
    """
    try:
        db.add(instance)
        db.commit()
        db.refresh(instance)
        return instance
    except SQLAlchemyError as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi CSDL: {e}")

# -----------------------------
# ✅ Phân trang kết quả (paginate)
# -----------------------------
def paginate(query, page: int = 1, size: int = 10):
    """
    Trả về dict phân trang gồm:
    {
        'page': int,
        'size': int,
        'total': int,
        'pages': int,
        'items': list
    }
    """
    total = query.count()
    items = query.offset((page - 1) * size).limit(size).all()
    pages = ceil(total / size) if size > 0 else 1
    return {
        "page": page,
        "size": size,
        "total": total,
        "pages": pages,
        "items": items,
    }
