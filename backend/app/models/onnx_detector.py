import logging, ast, json, os
from typing import List, Tuple, Optional, Dict, Any
import numpy as np
import onnx
import onnxruntime as ort
from PIL import Image

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

UNKNOWN_LABEL = "Không xác định"

# ===============================
# 🧠 HÀM ĐỌC NHÃN TỪ ONNX METADATA
# ===============================
def load_labels_from_onnx(model_path: str, labels_path: Optional[str] = None) -> List[str]:
    def parse_names(val):
        if isinstance(val, (list, tuple)):
            return list(val)
        if isinstance(val, dict):
            ids = sorted(int(k) for k in val.keys())
            return [val[i] for i in ids]
        if isinstance(val, str):
            for parser in (ast.literal_eval, json.loads):
                try:
                    obj = parser(val)
                    return parse_names(obj)
                except Exception:
                    pass
            return [p.strip() for p in val.split(",") if p.strip()]
        return []

    labels = []
    try:
        model = onnx.load(model_path)
        meta = {p.key: p.value for p in model.metadata_props}
        if "names" in meta:
            labels = parse_names(meta["names"])
            logger.info(f"🧾 Found {len(labels)} labels from ONNX metadata.")
        else:
            logger.warning("⚠️ No 'names' field found in ONNX metadata.")
    except Exception as e:
        logger.error(f"❌ Failed to read ONNX metadata: {e}")

    # fallback nếu không có metadata
    if not labels and labels_path and os.path.exists(labels_path):
        with open(labels_path, "r", encoding="utf-8") as f:
            labels = [ln.strip() for ln in f if ln.strip()]
        logger.info(f"📄 Loaded {len(labels)} labels from {labels_path}")

    return labels

# ===============================
# 📏 CÁC HÀM HỖ TRỢ
# ===============================
def sigmoid(x): return 1 / (1 + np.exp(-x))

def softmax(x: np.ndarray) -> np.ndarray:
    x = x - np.max(x, axis=1, keepdims=True)
    e = np.exp(x)
    return e / (np.sum(e, axis=1, keepdims=True) + 1e-9)

def letterbox(im: Image.Image, new_shape=(640, 640), color=(114, 114, 114)) -> Image.Image:
    """Resize giữ tỉ lệ và pad về kích thước vuông."""
    im = im.convert("RGB")
    w, h = im.size
    r = min(new_shape[0] / h, new_shape[1] / w)
    nw, nh = int(round(w * r)), int(round(h * r))
    im = im.resize((nw, nh), Image.LANCZOS)
    new_im = Image.new("RGB", new_shape, color)
    new_im.paste(im, ((new_shape[1] - nw) // 2, (new_shape[0] - nh) // 2))
    return new_im

# ===============================
# ⚙️ CLASS CHÍNH
# ===============================
class OnnxDetector:
    def __init__(
        self,
        model_path: str,
        labels_path: Optional[str] = None,
        input_size: Tuple[int, int] = (640, 640),
        conf_thres: float = 0.25,
        iou_thres: float = 0.45,
        providers: Optional[List[str]] = None,
    ):
        self.session = ort.InferenceSession(model_path, providers=providers or ["CPUExecutionProvider"])
        self.input_name = self.session.get_inputs()[0].name
        self.output_names = [o.name for o in self.session.get_outputs()]
        self.input_size = input_size
        self.conf_thres = conf_thres
        self.iou_thres = iou_thres

        # Load labels từ ONNX metadata
        self.labels = load_labels_from_onnx(model_path, labels_path)
        logger.info(f"🔤 Labels in use (K={len(self.labels)}): {self.labels}")

        self.last_debug: Dict[str, Any] = {}

    def preprocess(self, image: Image.Image) -> np.ndarray:
        image = letterbox(image, self.input_size)
        arr = np.array(image).astype(np.float32) / 255.0
        arr = np.transpose(arr, (2, 0, 1))[None, ...]  # (1,3,H,W)
        return arr

    def predict(self, image: Image.Image) -> Dict[str, Any]:
        try:
            x = self.preprocess(image)
            outputs = self.session.run(self.output_names, {self.input_name: x})
            out = outputs[0]
            self.last_debug = {"out_shape": tuple(out.shape)}

            # Nếu output là vector (phân loại)
            if out.ndim == 1 or (out.ndim == 2 and out.shape[0] == 1):
                vec = np.squeeze(out)
                probs = softmax(vec[None, :]) if vec.ndim == 1 else softmax(vec)
                cls_id = int(np.argmax(probs))
                score = float(np.max(probs))
                label = self.labels[cls_id] if cls_id < len(self.labels) else UNKNOWN_LABEL
                return {"label": label, "confidence": round(score, 4), "best_cls": cls_id, "debug": self.last_debug}

            # Dạng pre-NMS (YOLOv8, out.shape=(1, 5+K, N) hoặc (1, N, 5+K))
            arr = np.squeeze(out, 0)
            if arr.ndim != 2:
                return {"label": UNKNOWN_LABEL, "confidence": 0.0, "debug": {"reason": "invalid_shape", **self.last_debug}}

            A, B = arr.shape
            channels = A if (A >= 6 and A < B) else B
            transposed = False
            if channels == A:
                arr = arr.T
                transposed = True
            self.last_debug["transposed"] = transposed

            # arr: (N, C) sau khi transpose nếu cần
            C = arr.shape[1]
            K_meta = len(self.labels)  # 5 theo ONNX metadata

            has_obj = None
            if K_meta > 0:
                if C == 4 + K_meta:
                    has_obj = False  # YOLOv8: [x,y,w,h] + K logits
                elif C == 5 + K_meta:
                    has_obj = True   # YOLOv5: [x,y,w,h,obj] + K logits

            # Nếu vẫn chưa xác định, fallback mềm (ưu tiên v8)
            if has_obj is None:
                if C >= 4 + K_meta:
                    has_obj = (C == 5 + K_meta)  # True nếu trùng v5, else coi như v8
                else:
                    raise ValueError(f"Không suy ra được head: C={C}, K_meta={K_meta}")

            # --- Giải mã lớp ---
            cls_logits = arr[:, -K_meta:]           # luôn lấy đúng 5 lớp theo metadata
            # v8/v5 export thường là logits -> dùng softmax
            def _softmax(z):
                z = z - np.max(z, axis=1, keepdims=True)
                e = np.exp(z)
                return e / (np.sum(e, axis=1, keepdims=True) + 1e-9)

            cls_probs = _softmax(cls_logits)
            cls_id = np.argmax(cls_probs, axis=1)
            cls_conf = cls_probs[np.arange(cls_probs.shape[0]), cls_id]

            if has_obj:
                obj = 1.0 / (1.0 + np.exp(-arr[:, 4]))  # sigmoid
                scores = np.clip(obj * cls_conf * 1.5, 0, 1)  # nhân hệ số nhẹ để scale confidence
            else:
                # YOLOv8: không có obj_conf
                scores = cls_conf

            # ---- VOTE THEO LỚP (ổn định) ----
            top = np.argsort(scores)[-300:]
            top_scores = scores[top]
            top_classes = cls_id[top]
            sum_per_class = np.bincount(top_classes, weights=top_scores, minlength=K_meta)
            max_per_class = np.zeros(K_meta, dtype=np.float32)
            for c in range(K_meta):
                if np.any(top_classes == c):
                    max_per_class[c] = float(top_scores[top_classes == c].max())

            final_cls = int(np.argmax(sum_per_class))
            final_score = float(max_per_class[final_cls])
            label = self.labels[final_cls]

            self.last_debug.update({
                "C": int(C),
                "K_meta": int(K_meta),
                "has_obj": bool(has_obj),
                "vote_sum_per_class": sum_per_class.tolist(),
                "vote_max_per_class": max_per_class.tolist(),
                "final_cls": final_cls,
                "final_label": label,
                "final_score": final_score,
            })
            return {"label": label, "confidence": round(final_score, 4), "best_cls": final_cls, "debug": self.last_debug}


        except Exception as e:
            logger.error(f"❌ Inference failed: {e}")
            return {"label": UNKNOWN_LABEL, "confidence": 0.0, "debug": {"exception": str(e)}}
