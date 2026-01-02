# app/services/auto_detection_service.py
"""
Service tự động phát hiện bệnh từ camera với kết hợp nhiều nguồn dữ liệu.
Tối ưu hóa cho môi trường Docker/Cloud Run với Cloudinary.
"""
from typing import Dict, Any, List, Optional, Tuple
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from collections import Counter
import logging
import os
from pathlib import Path

from app.models.devices import Device
from app.models.image_detection import Img, Detection, Disease, SourceType
from app.models.sensor_readings import SensorReadings
from app.models.notification import Notifications 
from app.services.camera_service import capture_multiple_images
from app.services.inference_service import YoloDetector, detector
from app.services.detect_service import save_detection_result
from app.services.llm_service import summarize_detections_with_llm
from app.services.cloudinary_service import upload_image_to_cloudinary  # ✅ Thêm Cloudinary

logger = logging.getLogger(__name__)

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
    lines = [
        "Thông tin thiết bị:",
        f"- Tên: {device_info.name or 'N/A'}",
        f"- Vị trí: {device_info.location or 'N/A'}",
        f"- Thời gian: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
    ]

    if sensor_data:
        lines.append("Dữ liệu cảm biến gần đây:")
        for metric, data in sensor_data.items():
            lines.append(f"- {metric}: {data['avg']:.2f} {data.get('unit', '')} (min: {data['min']:.2f}, max: {data['max']:.2f})")
        lines.append("")
    else:
        lines.append("Không có dữ liệu cảm biến.\n")

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
    
    lines.extend([
        "\nHãy phân tích tổng hợp và đưa ra:",
        "[DISEASE_SUMMARY]",
        "- Đánh giá tình trạng cây dựa trên hình ảnh, cảm biến và xu hướng",
        "- Mức độ nghiêm trọng và khả năng lan rộng\n",
        "[CARE_INSTRUCTIONS]",
        "- Hướng dẫn xử lý cụ thể dựa trên điều kiện môi trường",
        "- Biện pháp phòng ngừa và chăm sóc"
    ])

    return "\n".join(lines)

def detect_from_camera_auto(
    db: Session,
    device: Device,
    num_images: int = 3,
    auto_stop_stream: bool = True
) -> Dict[str, Any]:
    """Auto-detect từ camera, tích hợp Cloudinary và LLM."""
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

        # 1. Upload ảnh tốt nhất lên Cloudinary (mặc định lấy ảnh đầu tiên)
        image_url = upload_image_to_cloudinary(images[0], folder="zestguard/auto_detections")
        if not image_url:
             logger.error("[AutoDetection] Lỗi upload Cloudinary")
             return {'success': False, 'error': 'Cloudinary upload failed'}

        # 2. Setup Detector
        local_detector = detector
        if local_detector is None:
            THIS_DIR = Path(__file__).resolve().parent
            REPO_ROOT = THIS_DIR.parents[2]
            MODEL_PATH = os.getenv("MODEL_PATH", str(REPO_ROOT / "ml/exports/v1.0/best.pt"))
            try:
                local_detector = YoloDetector(MODEL_PATH)
            except FileNotFoundError:
                return {'success': False, 'error': f'Model not found: {MODEL_PATH}'}

        all_detections = []
        best_confidence = 0.0

        for i, img_data in enumerate(images):
            try:
                pred = local_detector.predict_bytes(img_data)
                if pred and pred.get('num_detections', 0) > 0:
                    top = pred.get('detections', [])[0]
                    class_name = top.get('class_key') or top.get('class_name') or 'Không xác định'
                    confidence = float(top.get('confidence', 0.0))
                    
                    detection_item = {
                        'class_name': class_name,
                        'confidence': confidence,
                        'bbox': top.get("bbox"),
                    }
                    all_detections.append(detection_item)
                    if confidence > best_confidence:
                        best_confidence = confidence
            except Exception as e:
                logger.error(f"[AutoDetection] Lỗi detect ảnh {i+1}: {e}")

        # 3. Thu thập ngữ cảnh và gọi LLM
        sensor_data = get_recent_sensor_readings(db, device.device_id, hours=24)
        trend_info = analyze_disease_trend(get_recent_detections(db, device.device_id, days=7))
        enhanced_prompt = build_enhanced_prompt(all_detections, sensor_data, device, trend_info)

        disease_summary, care_instructions = summarize_detections_with_llm(all_detections)
        
        # Nếu có dữ liệu mở rộng, dùng prompt nâng cao
        if sensor_data or trend_info.get('has_history'):
            try:
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
                logger.error(f"[AutoDetection] Lỗi nâng cao LLM: {e}")

        # 4. Lưu kết quả vào DB bằng image_url từ Cloudinary
        saved_result = None
        has_disease = False
        if all_detections:
            try:
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
                    image_url=image_url,  # ✅ THAY ĐỔI: Dùng URL thay vì bytes
                    filename=f"auto_scan_{device.device_id}.jpg",
                    yolo_result=yolo_result,
                    user_id=device.user_id,
                    device_id=device.device_id,
                    model_version="v1.0"
                )
                
                healthy_classes = {'pomelo_leaf_healthy', 'pomelo_fruit_healthy'}
                has_disease = any(d.get('class_name') not in healthy_classes for d in all_detections)
            except Exception as e:
                logger.error(f"[AutoDetection] Lỗi lưu DB: {e}")

        # 5. Thông báo và Dọn dẹp
        notification_created = False
        if has_disease and device.user_id:
            try:
                title = f"⚠️ Phát hiện bệnh: {device.name or 'Camera'}"
                description = f"Phát hiện tại {device.location or 'N/A'}.\n\n{disease_summary}"
                notification = Notifications(user_id=device.user_id, title=title, description=description)
                db.add(notification)
                db.commit()
                notification_created = True
            except Exception as e:
                logger.error(f"[AutoDetection] Lỗi notification: {e}")

        if auto_stop_stream:
            try:
                from app.services import stream_service
                stream_service.stop_stream(device.device_id)
            except Exception: pass

        return {
            'success': True,
            'device_id': device.device_id,
            'has_disease': has_disease,
            'image_url': image_url,
            'disease_summary': disease_summary,
            'care_instructions': care_instructions,
            'notification_created': notification_created
        }
    except Exception as e:
        logger.error(f"[AutoDetection] Lỗi tổng quát: {e}", exc_info=True)
        if auto_stop_stream:
            try:
                from app.services import stream_service
                stream_service.stop_stream(device.device_id)
            except Exception: pass
        return {'success': False, 'error': str(e), 'device_id': device.device_id}