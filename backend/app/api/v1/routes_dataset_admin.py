import os
import shutil
import tempfile
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.role import RoleType
from app.core.config import settings
from app.services.cloudinary_service import upload_dataset_to_cloudinary

router = APIRouter(prefix="/dataset", tags=["Dataset Admin"])

@router.get("/admin/download")
async def download_dataset_zip(
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
):
    """
    API dành cho Admin:
    1. Nén toàn bộ ảnh trong DATASET_ROOT thành file ZIP.
    2. Gửi file cho người dùng tải về.
    3. Chạy Background Task: Upload ZIP lên Cloudinary và DỌN DẸP folder gốc.
    """
    # 1. Kiểm tra quyền Admin/Support
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới được phép tải dataset",
        )

    # 2. Xác định đường dẫn gốc của Dataset
    dataset_root = Path(settings.DATASET_ROOT)
    if not dataset_root.exists() or not any(dataset_root.iterdir()):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Không có dữ liệu ảnh nào trong thư mục dataset để tải",
        )

    # 3. Tạo file ZIP tạm với tên kèm Timestamp
    # Định dạng: dataset_20250124_153045.zip
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    zip_filename = f"dataset_{timestamp}_{uuid.uuid4().hex[:6]}"
    tmp_dir = Path(tempfile.gettempdir())
    zip_base_path = tmp_dir / zip_filename
    
    # Thực hiện nén toàn bộ thư mục dataset_root
    zip_path_str = shutil.make_archive(
        base_name=str(zip_base_path),
        format="zip",
        root_dir=str(dataset_root),
    )

    # 4. Hàm dọn dẹp và Backup chạy ngầm
    def archive_and_cleanup_task(file_path: str, folder_to_clean: str):
        """
        Hàm này sẽ làm trống folder dataset sau khi đã nén xong đợt này.
        """
        try:
            # A. Upload file ZIP lên Cloudinary (Dạng raw file)
            with open(file_path, "rb") as f:
                upload_dataset_to_cloudinary(
                    f.read(), 
                    filename=f"dataset_{timestamp}.zip"
                )
            
            # B. Xóa file ZIP tạm trong thư mục /tmp của server
            if os.path.exists(file_path):
                os.remove(file_path)
                
            # C. LÀM TRỐNG DỮ LIỆU GỐC (Kích hoạt chế độ tải theo đợt)
            # Sau lệnh này, folder 'dataset' sẽ rỗng để chờ các đợt export mới
            if os.path.exists(folder_to_clean):
                shutil.rmtree(folder_to_clean)
                Path(folder_to_clean).mkdir(parents=True, exist_ok=True)
            
            print(f"--- LOG: Đã nén, upload Cloudinary và làm trống đợt dữ liệu {timestamp} ---")
        except Exception as e:
            print(f"--- ERROR: Lỗi trong quá trình dọn dẹp dataset: {e} ---")

    # Đăng ký task chạy ngầm
    background_tasks.add_task(archive_and_cleanup_task, zip_path_str, str(dataset_root))

    # 5. Trả file về cho Frontend
    return FileResponse(
        path=zip_path_str,
        media_type="application/zip",
        filename=f"dataset_{timestamp}.zip",
    )