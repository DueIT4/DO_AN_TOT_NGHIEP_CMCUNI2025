from pathlib import Path
from typing import List, Tuple, Any, Dict, Optional
import requests
from io import BytesIO
from PIL import Image
from sqlalchemy.orm import Session
import os
from app.core.config import settings
from app.models.image_detection import Img, Detection, Disease

class ExportError(Exception):
    pass

def _sanitize_class_name(raw: str | None) -> str:
    """Chuyển tên bệnh thành tên folder an toàn."""
    if not raw:
        return "unknown"
    name = raw.strip()
    name = name.replace(" ", "_")
    return name

def _extract_xyxy_from_bbox(bbox: Any, img_w: int, img_h: int) -> Tuple[int, int, int, int]:
    """Đọc bbox JSON và trả về (x_min, y_min, x_max, y_max) dạng pixel."""
    if bbox is None:
        raise ExportError("Dữ liệu tọa độ (bbox) bị trống (None)")

    # Trường hợp bbox là một dictionary chứa các key tọa độ
    if isinstance(bbox, dict):
        def _get_first(keys):
            for k in keys:
                if k in bbox:
                    return float(bbox[k])
            return None

        x_min = _get_first(("x_min", "xmin", "left", "x1"))
        y_min = _get_first(("y_min", "ymin", "top", "y1"))
        x_max = _get_first(("x_max", "xmax", "right", "x2"))
        y_max = _get_first(("y_max", "ymax", "bottom", "y2"))

        if x_min is not None and y_min is not None and x_max is not None and y_max is not None:
            # Xử lý nếu tọa độ đang ở dạng chuẩn hóa (0-1)
            normalized = bool(bbox.get("normalized", False))
            # Tự động nhận diện nếu giá trị <= 1.0 thì coi như đã chuẩn hóa
            if not normalized and max(x_min, y_min, x_max, y_max) <= 1.1:
                normalized = True

            if normalized:
                x_min *= img_w
                x_max *= img_w
                y_min *= img_h
                y_max *= img_h
            return int(x_min), int(y_min), int(x_max), int(y_max)

    # Trường hợp bbox là một list [x1, y1, x2, y2]
    if isinstance(bbox, (list, tuple)) and len(bbox) == 4:
        x1, y1, x2, y2 = map(float, bbox)
        if max(x1, y1, x2, y2) <= 1.1:
            x1 *= img_w
            x2 *= img_w
            y1 *= img_h
            y2 *= img_h
        return int(x1), int(y1), int(x2), int(y2)

    raise ExportError(f"Không nhận diện được định dạng tọa độ: {bbox!r}")

def export_detection_to_dataset(
    db: Session,
    detection_id: int,
    split: str = "train",
) -> List[str]:
    """
    Export 1 detection:
      - Tải ảnh từ URL (Cloudinary) hoặc Disk
      - Xử lý định dạng Gộp JSON (all_detections)
      - Crop ảnh và lưu vào dataset
    """
    det: Detection | None = db.get(Detection, detection_id)
    if not det:
        raise ExportError(f"Không tìm thấy bản ghi nhận diện ID: {detection_id}")

    img: Img | None = db.get(Img, det.img_id)
    if not img or not img.file_url:
        raise ExportError("Không tìm thấy thông tin ảnh hoặc URL ảnh trống")

    disease: Disease | None = db.get(Disease, det.disease_id)
    class_name = _sanitize_class_name(disease.name if disease else "Healthy")

    # -------- 1. LẤY ẢNH TỪ URL HOẶC DISK --------
    file_url = img.file_url
    try:
        if file_url.startswith(("http://", "https://")):
            # Tải ảnh từ Cloudinary
            response = requests.get(file_url, timeout=15)
            response.raise_for_status()
            pil_img = Image.open(BytesIO(response.content)).convert("RGB")
        else:
            # Xử lý ảnh local cũ
            rel_path = file_url.replace("/media/", "", 1) if file_url.startswith("/media/") else file_url
            img_path = Path("media") / rel_path
            if not img_path.exists():
                raise ExportError(f"Không tìm thấy file ảnh tại: {img_path}")
            pil_img = Image.open(img_path).convert("RGB")
    except Exception as e:
        raise ExportError(f"Lỗi khi tải ảnh: {str(e)}")

    w, h = pil_img.size

    # -------- 2. XỬ LÝ ĐỊNH DẠNG GỘP JSON (FIX LỖI 400) --------
    bbox_raw = det.bbox
    
    # Nếu dữ liệu ở dạng {'all_detections': [...]}
    if isinstance(bbox_raw, dict) and 'all_detections' in bbox_raw:
        detections_list = bbox_raw['all_detections']
        if not detections_list:
            raise ExportError("Bản ghi không chứa bất kỳ vết bệnh nào để export")
        
        # Lấy bbox của vết bệnh đầu tiên để crop
        # Bạn có thể dùng vòng lặp ở đây nếu muốn export tất cả các vết bệnh
        bbox_raw = detections_list[0].get('bbox')

    # -------- 3. TRÍCH XUẤT TỌA ĐỘ VÀ CROP --------
    x_min, y_min, x_max, y_max = _extract_xyxy_from_bbox(bbox_raw, w, h)

    # Đảm bảo tọa độ nằm trong phạm vi ảnh
    x_min, x_max = max(0, min(x_min, w-1)), max(1, min(x_max, w))
    y_min, y_max = max(0, min(y_min, h-1)), max(1, min(y_max, h))

    if x_max <= x_min or y_max <= y_min:
        raise ExportError("Tọa độ không hợp lệ sau khi xử lý (x_max <= x_min hoặc y_max <= y_min)")

    # -------- 4. LƯU ẢNH VÀO DATASET --------
    # Cloud Run sử dụng /tmp, Local sử dụng DATASET_ROOT trong settings
    base_dir = Path("/tmp/dataset") if os.getenv("K_SERVICE") else Path(settings.DATASET_ROOT)
    
    out_dir = base_dir / split / class_name
    out_dir.mkdir(parents=True, exist_ok=True)

    out_name = f"det_{det.detection_id}.jpg"
    out_path = out_dir / out_name

    crop = pil_img.crop((x_min, y_min, x_max, y_max))
    crop.save(out_path, format="JPEG", quality=95)

    return [str(out_path)]