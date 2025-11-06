# app/services/inference_service.py
import io
import os
from typing import Dict, Any

import numpy as np
from fastapi import UploadFile, HTTPException
from PIL import Image, ImageOps, ImageFilter

from app.models.onnx_detector import OnnxDetector
from app.services.llm_service import explain_disease_with_llm
from app.utils.logger import logger

# ====== ĐƯỜNG DẪN MODEL/LABELS ======
# Lưu ý: cấu trúc dự án của bạn là:
#   <project_root>/
#     ml/exports/v1.0/best.onnx
#     backend/app/services/...
# Từ file này (backend/app/services), "../../../ml/..." sẽ trỏ tới <project_root>/ml/...
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "../../../ml/exports/v1.0/best.onnx")
LABELS_PATH = os.path.join(BASE_DIR, "../../../ml/exports/v1.0/labels.txt")  # fallback nếu ONNX không có metadata

# ====== THAM SỐ CHẤT LƯỢNG HIỂN THỊ ======
DISPLAY_MIN = 0.10      # ẩn dự đoán quá thấp (<10%). Điều chỉnh tùy ý.
BLUR_TOO_LOW = 50.0     # rất mờ → thử tăng cường + infer lại
BLUR_A_BIT_LOW = 120.0  # hơi mờ
DARK_THRES = 80.0       # quá tối (0..255)
BRIGHT_THRES = 200.0    # quá sáng


# ====== HELPERS: đo mờ, sáng, tăng cường ảnh ======
def variance_of_laplacian_pil(im: Image.Image) -> float:
    """Đo độ sắc nét ảnh bằng phương pháp Laplacian (không cần OpenCV)."""
    g = ImageOps.grayscale(im)
    w, h = g.size
    if max(w, h) > 512:
        scale_w = min(w, 512)
        scale_h = min(h, 512)
        g = g.resize((scale_w, scale_h), Image.BILINEAR)
    a = np.asarray(g, dtype=np.float32)
    k = np.array([[0, 1, 0],
                  [1, -4, 1],
                  [0, 1, 0]], dtype=np.float32)
    H, W = a.shape
    if H < 3 or W < 3:
        return 0.0
    # conv valid 3x3 đơn giản
    out = np.zeros((H - 2, W - 2), dtype=np.float32)
    for i in range(H - 2):
        for j in range(W - 2):
            patch = a[i:i+3, j:j+3]
            out[i, j] = float((patch * k).sum())
    return float(out.var())


def estimate_brightness(im: Image.Image) -> float:
    """Ước lượng độ sáng [0..255] bằng trung bình mức xám."""
    g = ImageOps.grayscale(im)
    w, h = g.size
    if max(w, h) > 512:
        g = g.resize((min(w, 512), min(h, 512)), Image.BILINEAR)
    arr = np.asarray(g, dtype=np.float32)
    return float(arr.mean())


def enhance_image_soft(im: Image.Image) -> Image.Image:
    """
    Tăng cường ảnh nhẹ: UnsharpMask (tăng nét) + equalize kênh Y (tăng tương phản nhẹ).
    Không dùng OpenCV để tránh thêm phụ thuộc.
    """
    im = im.convert("RGB")
    # 1) tăng nét nhẹ
    im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=130, threshold=2))
    # 2) equalize nhẹ trên kênh Y
    try:
        ycbcr = im.convert("YCbCr")
        y, cb, cr = ycbcr.split()
        y_eq = ImageOps.equalize(y)
        y_mix = Image.blend(y, y_eq, alpha=0.3)
        out = Image.merge("YCbCr", (y_mix, cb, cr)).convert("RGB")
        return out
    except Exception:
        return im


class InferenceService:
    def __init__(self):
        try:
            # OnnxDetector mới đọc labels từ ONNX metadata (fallback labels.txt)
            self.detector = OnnxDetector(
                model_path=MODEL_PATH,
                labels_path=LABELS_PATH,
                input_size=(640, 640),
                conf_thres=0.25,                # dùng ở mức parser; vote theo lớp vẫn chạy
                iou_thres=0.45,
                providers=["CPUExecutionProvider"],  # đổi nếu dùng CUDA/DML
            )
            logger.info("✅ ONNX model loaded successfully.")
        except Exception as e:
            logger.error(f"❌ Failed to load ONNX model: {e}")
            self.detector = None

    def _wrap(self, disease: str, confidence: float, llm_text: str,
              quality: Dict[str, Any], debug: Dict[str, Any] | None = None):
        res = {
            "success": True,
            "result": {
                "disease": disease,
                "confidence": round(float(confidence), 4),
                "llm_explanation": llm_text,
                "quality": quality,
            }
        }
        if debug:
            res["result"]["debug"] = debug
        return res

    async def analyze(self, image_file: UploadFile):
        if not self.detector:
            raise HTTPException(status_code=500, detail="Model chưa được load.")

        try:
            raw_bytes = await image_file.read()
            if not raw_bytes:
                raise HTTPException(status_code=400, detail="Ảnh rỗng.")

            image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")

            # ===== 1) đánh giá chất lượng ảnh =====
            blur = variance_of_laplacian_pil(image)
            bright = estimate_brightness(image)
            too_dark = bright < DARK_THRES
            too_bright = bright > BRIGHT_THRES
            quality = {
                "blur_score": round(blur, 2),
                "brightness": round(bright, 1),
                "too_dark": too_dark,
                "too_bright": too_bright,
            }

            # ===== 2) suy luận lần 1 =====
            pred1 = self.detector.predict(image)  # {'label','confidence','best_cls','debug'}
            logger.info(f"📸 Pred#1: {pred1}")
            disease = pred1.get("label", "Không xác định") or "Không xác định"
            confidence = float(pred1.get("confidence", 0.0))
            debug = {
                "display_threshold": DISPLAY_MIN,
                "model_nc": len(self.detector.labels),  # sẽ là 5
                **(pred1.get("debug") or {})
            }
            enhanced_used = False

            # ===== 3) nếu ảnh rất mờ → thử tăng cường & infer lại đúng 1 lần =====
            if blur < BLUR_TOO_LOW:
                enhanced = enhance_image_soft(image)
                pred2 = self.detector.predict(enhanced)
                logger.info(f"📸 Pred#2 (enhanced): {pred2}")
                enhanced_used = True
                debug["enhanced_used"] = True
                # chọn kết quả tốt hơn
                if float(pred2.get("confidence", 0.0)) > confidence:
                    disease = pred2.get("label", disease)
                    confidence = float(pred2.get("confidence", confidence))

            # ===== 4) ẩn dự đoán quá thấp cho UI (không ảnh hưởng debug) =====
            shown_disease = disease
            shown_conf = confidence
            if shown_conf < DISPLAY_MIN:
                shown_disease = "Không xác định"
                shown_conf = 0.0

            # ===== 5) gọi LLM để giải thích (KHÔNG truyền extra_context) =====
            try:
                llm_text = explain_disease_with_llm(
                    disease_name=shown_disease,
                    confidence=shown_conf
                )
            except Exception as e:
                logger.error(f"❌ LLM error: {e}")
                if shown_conf > 0 and shown_disease != "Không xác định":
                    llm_text = f"Bệnh dự đoán: {shown_disease}. Độ tin cậy: {shown_conf*100:.2f}%."
                else:
                    tips = []
                    if blur < BLUR_A_BIT_LOW:
                        tips.append("Chụp gần hơn và giữ máy ổn định để ảnh rõ nét.")
                    if too_dark:
                        tips.append("Tăng ánh sáng (đèn/ánh sáng tự nhiên), tránh ngược sáng.")
                    if too_bright:
                        tips.append("Giảm chói, tránh ánh sáng gắt chiếu trực tiếp.")
                    llm_text = "Không thể sinh giải thích từ LLM." + (f" {' '.join(tips)}" if tips else "")

            # ===== 6) trả kết quả =====
            debug["enhanced_used"] = enhanced_used
            return {
                "success": True,
                "result": {
                    "disease": shown_disease,
                    "confidence": round(shown_conf, 4),
                    "description": llm_text
                }
            }


        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"❌ Inference error: {e}")
            raise HTTPException(status_code=500, detail=str(e))
