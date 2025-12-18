from pathlib import Path
from typing import List, Tuple, Any, Dict
from PIL import Image
from sqlalchemy.orm import Session

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
    # Nếu muốn kỹ, bạn có thể giữ lại chỉ [a-zA-Z0-9_]
    return name

def _extract_xyxy_from_bbox(bbox: Any, img_w: int, img_h: int) -> Tuple[int, int, int, int]:
    """
    Đọc bbox JSON từ Detection.bbox và trả về (x_min, y_min, x_max, y_max) dạng pixel.
    Cố gắng support nhiều format phổ biến:

    1) dict:
       - { "x_min", "y_min", "x_max", "y_max", normalized?: bool }
       - { "xmin", "ymin", "xmax", "ymax" }
       - { "x1", "y1", "x2", "y2" }
       - { "xyxy": [x_min, y_min, x_max, y_max], normalized?: bool }
       - { "bbox": [x_min, y_min, x_max, y_max], normalized?: bool }
       - { "box":  [x_min, y_min, x_max, y_max], normalized?: bool }
       - { "cx", "cy", "w", "h", normalized?: bool }

    2) list/tuple:
       - [x_min, y_min, x_max, y_max]          (pixel hoặc normalized nếu <= 1)
       - (tùy bạn, nếu đang dùng định dạng khác thì sau này chuẩn hóa lại từ BE)
    """

    if bbox is None:
        raise ExportError("bbox is None")

    # -------- CASE 1: bbox là dict --------
    if isinstance(bbox, dict):
        # 1a) Dạng xyxy với nhiều kiểu key
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
            normalized = bool(bbox.get("normalized", False))
            if normalized:
                x_min *= img_w
                x_max *= img_w
                y_min *= img_h
                y_max *= img_h
            return int(x_min), int(y_min), int(x_max), int(y_max)

        # 1b) Dạng mảng con trong key: xyxy / bbox / box
        for arr_key in ("xyxy", "bbox", "box"):
            if arr_key in bbox:
                arr = bbox[arr_key]
                if isinstance(arr, (list, tuple)) and len(arr) == 4:
                    x1, y1, x2, y2 = map(float, arr)
                    normalized = bool(bbox.get("normalized", False))
                    if normalized:
                        x1 *= img_w
                        x2 *= img_w
                        y1 *= img_h
                        y2 *= img_h
                    return int(x1), int(y1), int(x2), int(y2)

        # 1c) Dạng cx, cy, w, h
        if all(k in bbox for k in ("cx", "cy", "w", "h")):
            cx = float(bbox["cx"])
            cy = float(bbox["cy"])
            w = float(bbox["w"])
            h = float(bbox["h"])
            normalized = bool(bbox.get("normalized", False))

            if normalized:
                cx *= img_w
                cy *= img_h
                w *= img_w
                h *= img_h

            x_min = cx - w / 2
            x_max = cx + w / 2
            y_min = cy - h / 2
            y_max = cy + h / 2
            return int(x_min), int(y_min), int(x_max), int(y_max)

        # Không nhận ra được dạng dict nào quen
        raise ExportError(f"Không nhận diện được format bbox dict: {bbox}")

    # -------- CASE 2: bbox là list/tuple 4 phần tử --------
    if isinstance(bbox, (list, tuple)) and len(bbox) == 4:
        x1, y1, x2, y2 = map(float, bbox)

        # Nếu tất cả <= 1.0 -> coi như normalized xyxy
        if max(abs(x1), abs(y1), abs(x2), abs(y2)) <= 1.0:
            x1 *= img_w
            x2 *= img_w
            y1 *= img_h
            y2 *= img_h

        return int(x1), int(y1), int(x2), int(y2)

    # -------- CASE khác: bó tay --------
    raise ExportError(f"Không nhận diện được format bbox: {bbox!r}")

def _resolve_img_path(file_url: str) -> Path:
    """
    Chuyển file_url trong DB thành đường dẫn thực trên disk, dựa trên MEDIA_ROOT.

    Hỗ trợ các kiểu:
    - "/media/detections/2025/11/17/abc.webp"
    - "media/detections/2025/11/17/abc.webp"
    - "detections/2025/11/17/abc.webp"  (trường hợp bị mất "media/")
    - URL đầy đủ: "http://localhost:8000/media/detections/..."
    """
    if not file_url:
        raise ExportError("file_url is empty")

    p = file_url.strip().replace("\\", "/")

    # Nếu là URL đầy đủ -> lấy phần path
    if p.startswith("http://") or p.startswith("https://"):
        from urllib.parse import urlparse
        path_part = urlparse(p).path  # "/media/..."
    else:
        path_part = p

    # Chuẩn hoá: luôn làm việc với path dạng không có domain, ví dụ:
    # "/media/detections/..." hoặc "media/detections/..." hoặc "detections/..."
    # Ưu tiên phần sau "media/"
    if "/media/" in path_part:
        # Ví dụ: "/media/detections/2025/11/17/abc.webp"
        rel = path_part.split("/media/", 1)[1]  # "detections/2025/11/17/abc.webp"
    elif path_part.startswith("media/"):
        rel = path_part[len("media/"):]         # "detections/2025/11/17/abc.webp"
    else:
        # Không có "media" trong đường dẫn -> coi như đã là path tương đối bên trong MEDIA_ROOT
        rel = path_part.lstrip("/")

    # Ghép vào MEDIA_ROOT
    return Path(settings.MEDIA_ROOT) / rel

def export_detection_to_dataset(
    db: Session,
    detection_id: int,
    split: str = "train",
) -> List[str]:
    """
    Export 1 detection:
      - Lấy Img + Disease + bbox JSON
      - Crop ảnh theo bbox
      - Lưu vào: DATASET_ROOT/split/<class_name>/
    """
    det: Detection | None = db.get(Detection, detection_id)
    if not det:
        raise ExportError(f"Detection {detection_id} not found")

    img: Img | None = db.get(Img, det.img_id)
    if not img or not img.file_url:
        raise ExportError("Image not found or file_url empty")

    disease: Disease | None = db.get(Disease, det.disease_id)
    class_name = _sanitize_class_name(disease.name if disease else None)

    file_url = img.file_url
    img_path = _resolve_img_path(file_url)

    if not img_path.exists():
        raise ExportError(f"Image file not found: {img_path}")


    pil_img = Image.open(img_path).convert("RGB")
    w, h = pil_img.size

    # -------- Chuyển bbox JSON -> xyxy pixel --------
    x_min, y_min, x_max, y_max = _extract_xyxy_from_bbox(det.bbox, w, h)

    # Clamp lại cho an toàn
    x_min = max(0, min(x_min, w - 1))
    x_max = max(1, min(x_max, w))
    y_min = max(0, min(y_min, h - 1))
    y_max = max(1, min(y_max, h))

    if x_max <= x_min or y_max <= y_min:
        raise ExportError("Invalid bbox after clamp")

    # -------- Tạo folder dataset/split/class_name --------
    out_dir = Path(settings.DATASET_ROOT) / split / class_name
    out_dir.mkdir(parents=True, exist_ok=True)

    orig_name = img_path.stem
    out_name = f"{orig_name}_det{det.detection_id}.jpg"
    out_path = out_dir / out_name

    # -------- Crop & save --------
    crop = pil_img.crop((x_min, y_min, x_max, y_max))
    crop.save(out_path, format="JPEG", quality=95)

    return [str(out_path)]
