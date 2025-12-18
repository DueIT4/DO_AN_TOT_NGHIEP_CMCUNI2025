from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from pathlib import Path
import shutil
import tempfile
import uuid

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.role import RoleType
from app.core.config import settings

router = APIRouter(
    prefix="/dataset",
    tags=["Dataset Admin"],
)

@router.get("/admin/download")
def download_dataset_zip(
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
):
    # Chỉ cho admin / support_admin
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới được tải dataset",
        )

    dataset_root = Path(settings.DATASET_ROOT)  # vd: "dataset"
    if not dataset_root.exists():
        raise HTTPException(
            status_code=404,
            detail="Dataset chưa tồn tại trên server",
        )

    # Tạo file zip tạm
    tmp_dir = Path(tempfile.gettempdir())
    zip_name = f"dataset_{uuid.uuid4().hex}"
    zip_base = tmp_dir / zip_name  # không có .zip, shutil sẽ tự thêm
    zip_path = shutil.make_archive(
        base_name=str(zip_base),
        format="zip",
        root_dir=str(dataset_root),
    )

    # Trả về file zip
    return FileResponse(
        path=zip_path,
        media_type="application/zip",
        filename="dataset_train.zip",
    )
