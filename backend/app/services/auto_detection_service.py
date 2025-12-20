# app/services/auto_detection_service.py
"""
Service tự động phát hiện bệnh từ camera với kết hợp nhiều nguồn dữ liệu
"""
from typing import Dict, Any, List, Optional, Tuple
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from collections import Counter
import logging

logger = logging.getLogger(__name__)

from app.models.devices import Device
from app.models.image_detection import Img, Detection, Disease, SourceType
from app.models.sensor_readings import SensorReadings
from app.models.notification import Notifications  # ✅ FIX: Là Notifications (số nhiều)
from app.services.camera_service import capture_multiple_images
from app.services.inference_service import YoloDetector, detector
from app.services.detect_service import save_detection_result
from app.services.llm_service import summarize_detections_with_llm
from PIL import Image
from io import BytesIO
import os
from pathlib import Path


def get_recent_sensor_readings(db: Session, device_id: int, hours: int = 24) -> Dict[str, Any]:
    cutoff_time = datetime.utcnow() - timedelta(hours=hours)

    readings = db.query(SensorReadings).filter(
        SensorReadings.device_id == device_id,
        SensorReadings.recorded_at >= cutoff_time,
        SensorReadings.status == "ok"
    ).order_by(SensorReadings.recorded_at.desc()).all()

    if not readings:
        return {}

    metrics = {}
    for reading in readings:
        metric_name = reading.metric
        if metric_name not in metrics:
            metrics[metric_name] = {'values': [], 'unit': reading.unit}
        if reading.value_num is not None:
            metrics[metric_name]['values'].append(float(reading.value_num))

    result = {}
    for metric_name, data in metrics.items():
        if data['values']:
            result[metric_name] = {
                'avg': sum(data['values']) / len(data['values']),
                'min': min(data['values']),
                'max': max(data['values']),
                'unit': data['unit'],
                'count': len(data['values'])
            }
    return result


def get_recent_detections(db: Session, device_id: int, days: int = 7) -> List[Dict[str, Any]]:
    cutoff_time = datetime.utcnow() - timedelta(days=days)

    detections = db.query(Detection).join(Img).filter(
        Img.device_id == device_id,
        Detection.created_at >= cutoff_time
    ).order_by(Detection.created_at.desc()).limit(50).all()

    result = []
    for det in detections:
        result.append({
            'disease_name': det.disease.name if det.disease else None,
            'confidence': float(det.confidence) if det.confidence else 0.0,
            'created_at': det.created_at
        })
    return result


def analyze_disease_trend(recent_detections: List[Dict[str, Any]]) -> Dict[str, Any]:
    if not recent_detections:
        return {'has_history': False, 'trend': 'no_data'}

    disease_counts = Counter()
    disease_confidences = {}

    for det in recent_detections:
        disease_name = det.get('disease_name')
        if disease_name and disease_name not in ['Không xác định', 'pomelo_leaf_healthy', 'pomelo_fruit_healthy']:
            disease_counts[disease_name] += 1
            disease_confidences.setdefault(disease_name, []).append(det.get('confidence', 0.0))

    disease_avg_conf = {k: sum(v)/len(v) for k, v in disease_confidences.items() if v}

    if disease_counts:
        most_common = disease_counts.most_common(1)[0]
        trend = 'increasing' if most_common[1] >= 3 else 'stable'
        return {
            'has_history': True,
            'trend': trend,
            'most_common_disease': most_common[0],
            'occurrence_count': most_common[1],
            'avg_confidence': disease_avg_conf.get(most_common[0], 0.0),
            'all_diseases': dict(disease_counts)
        }
    else:
        return {'has_history': True, 'trend': 'healthy', 'most_common_disease': None}


def build_enhanced_prompt(
    detections_list: List[Dict[str, Any]],
    sensor_data: Dict[str, Any],
    device_info: Device,
    trend_info: Dict[str, Any]
) -> str:
    lines = []
    lines.append("Thông tin thiết bị:")
    lines.append(f"- Tên: {device_info.name or 'N/A'}")
    lines.append(f"- Vị trí: {device_info.location or 'N/A'}")
    lines.append(f"- Thời gian: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")

    if sensor_data:
        lines.append("Dữ liệu cảm biến gần đây:")
        for metric, data in sensor_data.items():
            lines.append(f"- {metric}: {data['avg']:.2f} {data.get('unit', '')} (min: {data['min']:.2f}, max: {data['max']:.2f})")
        lines.append("")
    else:
        lines.append("Không có dữ liệu cảm biến.")
        lines.append("")

    if trend_info.get('has_history'):
        lines.append("Xu hướng bệnh trong 7 ngày qua:")
        if trend_info.get('most_common_disease'):
            lines.append(f"- Bệnh phổ biến: {trend_info['most_common_disease']}")
            lines.append(f"- Số lần xuất hiện: {trend_info['occurrence_count']}")
            lines.append(f"- Độ tin cậy trung bình: {trend_info['avg_confidence']:.1f}%")
            lines.append(f"- Xu hướng: {trend_info['trend']}")
        else:
            lines.append("- Không phát hiện bệnh trong thời gian gần đây")
        lines.append("")

    lines.append("Kết quả phân tích hình ảnh hiện tại:")
    if detections_list:
        for i, det in enumerate(detections_list, 1):
            class_name = det.get('class_name', 'N/A')
            confidence = det.get('confidence', 0.0)
            lines.append(f"{i}. {class_name} - Độ tin cậy: {confidence*100:.1f}%")
    else:
        lines.append("- Không phát hiện bệnh")
    lines.append("")

    lines.append("Hãy phân tích tổng hợp và đưa ra:")
    lines.append("[DISEASE_SUMMARY]")
    lines.append("- Đánh giá tình trạng cây dựa trên hình ảnh, cảm biến và xu hướng")
    lines.append("- Mức độ nghiêm trọng và khả năng lan rộng")
    lines.append("")
    lines.append("[CARE_INSTRUCTIONS]")
    lines.append("- Hướng dẫn xử lý cụ thể dựa trên điều kiện môi trường")
    lines.append("- Biện pháp phòng ngừa và chăm sóc")

    return "\n".join(lines)


def detect_from_camera_auto(
    db: Session,
    device: Device,
    num_images: int = 3,
    auto_stop_stream: bool = True
) -> Dict[str, Any]:
    """Auto-detect từ camera.
    
    ✅ FIX: 
    - Tự động stop stream sau khi detection xong (nếu auto_stop_stream=True)
    - Tránh resource leak từ ffmpeg processes
    """
    if not device.stream_url:
        return {'success': False, 'error': 'Device không có stream_url'}

    if not device.user_id:
        return {'success': False, 'error': 'Device không có user_id'}

    try:
        logger.info(f"[AutoDetection] Lấy {num_images} ảnh từ camera {device.device_id}...")
        images = capture_multiple_images(
            device.stream_url,
            count=num_images,
            interval=1.0,
            device_id=device.device_id,
        )

        if not images:
            return {'success': False, 'error': 'Không thể lấy ảnh từ camera'}

        logger.info(f"[AutoDetection] Đã lấy được {len(images)} ảnh")

        THIS_DIR = Path(__file__).resolve().parent
        REPO_ROOT = THIS_DIR.parents[2]
        MODEL_PATH = os.getenv("MODEL_PATH", str(REPO_ROOT / "ml/exports/v1.0/best.pt"))

        local_detector = None
        try:
            local_detector = detector
        except NameError:
            local_detector = None

        if local_detector is None:
            try:
                local_detector = YoloDetector(MODEL_PATH)
            except FileNotFoundError:
                return {'success': False, 'error': f'Model not found: {MODEL_PATH}'}

        all_detections = []
        best_detection = None
        best_confidence = 0.0

        for i, img_data in enumerate(images):
            try:
                pred = local_detector.predict_bytes(img_data)

                if not pred or pred.get('num_detections', 0) == 0:
                    class_name = 'Không xác định'
                    confidence = 0.0
                    bbox = None
                else:
                    top = pred.get('detections', [])[0]
                    class_name = top.get('class_key') or top.get('class_name') or 'Không xác định'
                    confidence = float(top.get('confidence', 0.0))
                    bbox = top.get("bbox")

                detection_item = {
                    'class_name': class_name,
                    'confidence': confidence,
                    'bbox': bbox,
                }

                all_detections.append(detection_item)

                if confidence > best_confidence:
                    best_confidence = confidence
                    best_detection = detection_item
            except Exception as e:
                logger.error(f"[AutoDetection] Lỗi khi detect ảnh {i+1}: {e}")
                continue

        sensor_data = get_recent_sensor_readings(db, device.device_id, hours=24)
        recent_detections = get_recent_detections(db, device.device_id, days=7)
        trend_info = analyze_disease_trend(recent_detections)

        enhanced_prompt = build_enhanced_prompt(all_detections, sensor_data, device, trend_info)

        disease_summary = None
        care_instructions = None

        if all_detections:
            try:
                disease_summary, care_instructions = summarize_detections_with_llm(all_detections)

                if sensor_data or trend_info.get('has_history'):
                    from app.services.llm_service import client, GEMINI_MODEL
                    import google.generativeai as genai

                    if client:
                        model = genai.GenerativeModel(model_name=GEMINI_MODEL)
                        response = model.generate_content(enhanced_prompt)
                        full_text = (response.text or "").strip()

                        text_lower = full_text.lower()
                        idx_ds = text_lower.find("[disease_summary]")
                        idx_ci = text_lower.find("[care_instructions]")

                        if idx_ds != -1 and idx_ci != -1:
                            disease_summary = full_text[idx_ds + len("[DISEASE_SUMMARY]"): idx_ci].strip()
                            care_instructions = full_text[idx_ci + len("[CARE_INSTRUCTIONS]"):].strip()
            except Exception as e:
                logger.error(f"[AutoDetection] Lỗi khi gọi LLM: {e}")

        saved_result = None
        has_disease = False

        if images and all_detections:
            try:
                # ✅ NEW: nhét llm vào yolo_result để detect_service lưu description/guideline
                yolo_result = {
                    'detections': all_detections,
                    'num_detections': len(all_detections),
                    'llm': {
                        'disease_summary': disease_summary,
                        'care_instructions': care_instructions,
                    }
                }

                saved_result = save_detection_result(
                    db=db,
                    raw=images[0],
                    filename=f"auto_scan_{device.device_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.jpg",
                    yolo_result=yolo_result,
                    user_id=device.user_id,
                    device_id=device.device_id,
                    model_version="v1.0"
                )

                healthy_classes = {'pomelo_leaf_healthy', 'pomelo_fruit_healthy'}
                for det in all_detections:
                    class_name = det.get('class_name', '')
                    if class_name and class_name not in healthy_classes:
                        has_disease = True
                        break
            except Exception as e:
                logger.error(f"[AutoDetection] Lỗi khi lưu kết quả: {e}")

        notification_created = False
        if has_disease and device.user_id:
            try:
                disease_names = [d.get('class_name', '') for d in all_detections if d.get('class_name')]
                disease_counts = Counter(disease_names)
                if disease_counts:
                    most_common_disease = disease_counts.most_common(1)[0][0]

                    title = f"⚠️ Phát hiện bệnh trên camera: {device.name or 'Camera'}"
                    description = f"""
Phát hiện bệnh: {most_common_disease}
Vị trí: {device.location or 'N/A'}
Thời gian: {datetime.now().strftime('%d/%m/%Y %H:%M')}

{disease_summary or 'Vui lòng chụp thêm ảnh để phân tích thêm'}

Hướng dẫn xử lý:
{care_instructions or 'Vui lòng kiểm tra chi tiết trong lịch sử phát hiện bệnh ở Camera.'}
                    """.strip()

                    notification = Notifications(  # ✅ FIX: Là Notifications
                        user_id=device.user_id,
                        title=title,
                        description=description
                    )
                    db.add(notification)
                    db.commit()
                    notification_created = True
                    logger.info(f"[AutoDetection] Đã tạo notification cho user {device.user_id}")
            except Exception as e:
                logger.error(f"[AutoDetection] Lỗi khi tạo notification: {e}")

            # ✅ FIX: Stop stream sau khi detection xong (nếu auto_stop_stream=True)
            if auto_stop_stream:
                try:
                    from app.services import stream_service
                    if stream_service.stop_stream(device.device_id):
                        logger.info(f"[AutoDetection] Đã stop stream cho device {device.device_id} sau khi detection xong")
                    else:
                        logger.debug(f"[AutoDetection] Stream cho device {device.device_id} không chạy hoặc đã dừng")
                except Exception as e:
                    logger.warning(f"[AutoDetection] Lỗi khi stop stream device {device.device_id}: {e}")

        return {
            'success': True,
            'device_id': device.device_id,
            'device_name': device.name,
            'images_captured': len(images),
            'detections_count': len(all_detections),
            'has_disease': has_disease,
            'disease_summary': disease_summary,
            'care_instructions': care_instructions,
            'sensor_data': sensor_data,
            'trend_info': trend_info,
            'saved_result': saved_result,
            'notification_created': notification_created,
            'stream_stopped': auto_stop_stream  # ✅ Report stream stopped status
        }
    except Exception as e:
        logger.error(f"[AutoDetection] Lỗi chung trong detect_from_camera_auto: {e}", exc_info=True)
        # ✅ Even on error, try to stop stream
        if auto_stop_stream:
            try:
                from app.services import stream_service
                stream_service.stop_stream(device.device_id)
            except Exception:
                pass
        return {
            'success': False,
            'error': str(e),
            'device_id': device.device_id
        }
