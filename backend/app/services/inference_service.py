# backend/app/services/inference_service.py
import os
from typing import Optional, List, Union, Tuple
import numpy as np
import onnxruntime as ort
from PIL import Image, ImageFile

ImageFile.LOAD_TRUNCATED_IMAGES = True  # tránh lỗi ảnh bị cắt ngang

def sigmoid(x): 
    return 1 / (1 + np.exp(-x))

def _is_int(x):
    try:
        return int(x) == x or isinstance(x, int)
    except Exception:
        return False

def _make_divisible(x, divisor=32):
    return int(np.ceil(x / divisor) * divisor)

def letterbox(im: Image.Image, new_shape: Union[int, Tuple[int,int]] = 640, color=(114,114,114)) -> Image.Image:
    """Resize giữ tỉ lệ + padding về (W,H) mong muốn (bội số 32)."""
    if isinstance(new_shape, int):
        new_w = new_h = new_shape
    else:
        new_w, new_h = new_shape

    w, h = im.size
    r = min(new_w / w, new_h / h)
    nw, nh = int(round(w * r)), int(round(h * r))
    im = im.resize((nw, nh), Image.BILINEAR)
    new_im = Image.new("RGB", (new_w, new_h), color)
    new_im.paste(im, ((new_w - nw) // 2, (new_h - nh) // 2))
    return new_im

class OnnxDetector:
    def __init__(self, model_path: str, labels_path: Optional[str] = None, imgsz: Optional[int] = None, max_side: int = 1920):
        if not os.path.exists(model_path):
            raise FileNotFoundError(model_path)

        # Load model
        self.session = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name
        self.output_name = self.session.get_outputs()[0].name

        # Đọc shape input từ ONNX, ví dụ: [1, 3, 640, 640] hoặc [1, 3, 'height', 'width']
        in_shape = self.session.get_inputs()[0].shape  # [N,C,H,W]
        H, W = None, None
        if len(in_shape) == 4:
            H = in_shape[2] if _is_int(in_shape[2]) else None
            W = in_shape[3] if _is_int(in_shape[3]) else None
        # Nếu model quy định cố định (vd 640x640) thì dùng luôn, ngược lại để None để auto-chọn
        self.fixed_hw: Optional[Tuple[int,int]] = (int(W), int(H)) if (H and W) else None

        # nếu người dùng truyền imgsz thì ưu tiên (cho cả fixed/dynamic)
        self.user_imgsz = int(imgsz) if imgsz else None
        self.max_side = int(max_side)

        # labels
        self.labels: List[str] = []
        if labels_path and os.path.exists(labels_path):
            with open(labels_path, "r", encoding="utf-8") as f:
                self.labels = [ln.strip() for ln in f if ln.strip()]

    def _choose_size(self, im: Image.Image) -> Tuple[int,int]:
        """Chọn (W,H) input cho model:
           - Nếu model FIXED: dùng fixed (hoặc override bằng user_imgsz nếu có).
           - Nếu model DYNAMIC: lấy min(size ảnh, max_side), rồi làm tròn lên bội số 32."""
        if self.fixed_hw:
            fw, fh = self.fixed_hw
            if self.user_imgsz:  # cho phép override thành vuông user_imgsz nếu muốn
                s = _make_divisible(self.user_imgsz, 32)
                return (s, s)
            return (fw, fh)

        # dynamic: tự tính theo ảnh
        w, h = im.size
        if self.user_imgsz:
            s = _make_divisible(self.user_imgsz, 32)
            return (s, s)
        # giới hạn cạnh dài để tránh OOM
        scale = min(self.max_side / max(w, h), 1.0)
        tw, th = int(w * scale), int(h * scale)
        tw, th = _make_divisible(tw, 32), _make_divisible(th, 32)
        tw = max(tw, 32); th = max(th, 32)
        return (tw, th)

    def _preprocess(self, img: Image.Image) -> np.ndarray:
        img = img.convert("RGB")
        target_w, target_h = self._choose_size(img)
        img = letterbox(img, (target_w, target_h))
        arr = np.array(img).astype(np.float32) / 255.0
        arr = np.transpose(arr, (2,0,1))[None, ...]  # (1,3,H,W)
        return arr

    def infer_top1(self, img: Image.Image):
        x = self._preprocess(img)
        pred = self.session.run([self.output_name], {self.input_name: x})[0]
        pred = np.squeeze(pred)  # chấp nhận (1,C,A)->(C,A), (C,A), (A,C), (N,K)

        # ---- chuẩn hoá về (N,K) ----
        if pred.ndim == 3:
            if pred.shape[0] == 1:
                pred = np.squeeze(pred, 0)  # (C,A)
            else:
                raise RuntimeError(f"Unsupported 3D output: {pred.shape}")
        if pred.ndim != 2:
            raise RuntimeError(f"Unsupported output shape: {pred.shape}")

        H, W = pred.shape
        nc_from_labels = len(self.labels) if self.labels else None
        def looks_like_ck(val: int) -> bool:
            if nc_from_labels is None: return False
            return val in (4 + nc_from_labels, 5 + nc_from_labels)
        # nếu đang (C,A) (vd 8 x 8400) thì transpose (khi kênh nhỏ và anchors lớn)
        if W > H and (looks_like_ck(H) or H <= 32):
            pred = pred.T  # -> (A,C)

        N, K = pred.shape  # (A,C)
        nc = nc_from_labels if nc_from_labels is not None else max(K - 4, 1)

        # Giải mã linh hoạt: nếu K lớn hơn 5+nc, giả định cột cuối là logits lớp
        if K >= 5 + nc:  # YOLOv5/biến thể: có objectness
            obj = sigmoid(pred[:, 4])
            cls = sigmoid(pred[:, -nc:])
            cls_id = np.argmax(cls, axis=1)
            cls_conf = cls[np.arange(cls.shape[0]), cls_id]
            scores = obj * cls_conf
        elif K >= 4 + nc:  # YOLOv8/biến thể: không có objectness
            cls = sigmoid(pred[:, -nc:])
            cls_id = np.argmax(cls, axis=1)
            scores = cls[np.arange(cls.shape[0]), cls_id]
        else:
            raise RuntimeError(f"Unsupported decoded shape (N={N}, K={K}, nc={nc}).")

        i = int(np.argmax(scores))
        best_score = float(scores[i])
        best_cls = int(cls_id[i])
        name = self.labels[best_cls] if self.labels else str(best_cls)
        return {"disease": name, "confidence": round(best_score, 4)}
