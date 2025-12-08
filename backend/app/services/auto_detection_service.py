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
from app.models.notification import Notification
from app.services.camera_service import capture_multiple_images
#rom app.services.inference_service import OnnxDetector
from app.services.inference_service import YoloDetector, detector, MODEL_PATH
from app.services.detect_service import save_detection_result
from app.services.llm_service import summarize_detections_with_llm
from PIL import Image
from io import BytesIO
import os
from pathlib import Path

def get_recent_sensor_readings(db: Session, device_id: int, hours: int = 24) -> Dict[str, Any]:
    """
    Lấy sensor readings gần đây của device.
    Returns: Dict với các metric và giá trị trung bình
    """
    cutoff_time = datetime.utcnow() - timedelta(hours=hours)
    
    readings = db.query(SensorReadings).filter(
        SensorReadings.device_id == device_id,
        SensorReadings.recorded_at >= cutoff_time,
        SensorReadings.status == "ok"
    ).order_by(SensorReadings.recorded_at.desc()).all()
    
    if not readings:
        return {}
    
    # Nhóm theo metric và tính trung bình
    metrics = {}
    for reading in readings:
        metric_name = reading.metric
        if metric_name not in metrics:
            metrics[metric_name] = {
                'values': [],
                'unit': reading.unit
            }
        if reading.value_num is not None:
            metrics[metric_name]['values'].append(float(reading.value_num))
    
    # Tính trung bình
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
    """
    Lấy lịch sử detection gần đây của device.
    Returns: List các detection với disease name và confidence
    """
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
    """
    Phân tích xu hướng bệnh từ lịch sử.
    Returns: Dict với thông tin về xu hướng
    """
    if not recent_detections:
        return {
            'has_history': False,
            'trend': 'no_data'
        }
    
    # Đếm số lần xuất hiện mỗi bệnh
    disease_counts = Counter()
    disease_confidences = {}
    
    for det in recent_detections:
        disease_name = det.get('disease_name')
        if disease_name and disease_name not in ['Không xác định', 'pomelo_leaf_healthy', 'pomelo_fruit_healthy']:
            disease_counts[disease_name] += 1
            if disease_name not in disease_confidences:
                disease_confidences[disease_name] = []
            disease_confidences[disease_name].append(det.get('confidence', 0.0))
    
    # Tính trung bình confidence cho mỗi bệnh
    disease_avg_conf = {}
    for disease_name, confidences in disease_confidences.items():
        disease_avg_conf[disease_name] = sum(confidences) / len(confidences)
    
    # Xác định xu hướng
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
        return {
            'has_history': True,
            'trend': 'healthy',
            'most_common_disease': None
        }

def build_enhanced_prompt(
    detections_list: List[Dict[str, Any]],
    sensor_data: Dict[str, Any],
    device_info: Device,
    trend_info: Dict[str, Any]
) -> str:
    """
    Xây dựng prompt nâng cao kết hợp nhiều nguồn dữ liệu.
    """
    lines = []
    
    # 1. Thông tin device
    lines.append(f"Thông tin thiết bị:")
    lines.append(f"- Tên: {device_info.name or 'N/A'}")
    lines.append(f"- Vị trí: {device_info.location or 'N/A'}")
    lines.append(f"- Thời gian: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("")
    
    # 2. Dữ liệu cảm biến
    if sensor_data:
        lines.append("Dữ liệu cảm biến gần đây:")
        for metric, data in sensor_data.items():
            lines.append(f"- {metric}: {data['avg']:.2f} {data.get('unit', '')} (min: {data['min']:.2f}, max: {data['max']:.2f})")
        lines.append("")
    else:
        lines.append("Không có dữ liệu cảm biến.")
        lines.append("")
    
    # 3. Xu hướng bệnh
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
    
    # 4. Kết quả detection hiện tại
    lines.append("Kết quả phân tích hình ảnh hiện tại:")
    if detections_list:
        for i, det in enumerate(detections_list, 1):
            class_name = det.get('class_name', 'N/A')
            confidence = det.get('confidence', 0.0)
            lines.append(f"{i}. {class_name} - Độ tin cậy: {confidence*100:.1f}%")
    else:
        lines.append("- Không phát hiện bệnh")
    lines.append("")
    
    # 5. Yêu cầu phân tích
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
    num_images: int = 3
) -> Dict[str, Any]:
    """
    Tự động phát hiện bệnh từ camera với kết hợp nhiều nguồn.
    
    Args:
        db: Database session
        device: Device object có stream_url
        num_images: Số lượng ảnh cần lấy (mặc định 3)
    
    Returns:
        Dict với kết quả detection và thông tin cảnh báo
    """
    if not device.stream_url:
        return {
            'success': False,
            'error': 'Device không có stream_url'
        }
    
    if not device.user_id:
        return {
            'success': False,
            'error': 'Device không có user_id'
        }
    
    # 1. Lấy nhiều ảnh từ camera
    logger.info(f"[AutoDetection] Lấy {num_images} ảnh từ camera {device.device_id}...")
    images = capture_multiple_images(device.stream_url, count=num_images, interval=1.0)
    
    if not images:
        return {
            'success': False,
            'error': 'Không thể lấy ảnh từ camera'
        }
    
    logger.info(f"[AutoDetection] Đã lấy được {len(images)} ảnh")
    
    # 2. Load detector (giống như routes_detect.py)
    THIS_DIR = Path(__file__).resolve().parent  # .../backend/app/services
    REPO_ROOT = THIS_DIR.parents[2]  # go up to repo root
    MODEL_PATH = os.getenv("MODEL_PATH", str(REPO_ROOT / "ml/exports/v1.0/best.pt"))

    # Prefer the shared detector instance from inference_service if available.
    # Otherwise, try to instantiate the YoloDetector defined in inference_service.
    local_detector = None
    try:
        # `detector` and `YoloDetector` were imported at module top from inference_service
        local_detector = detector
    except NameError:
        local_detector = None

    if local_detector is None:
        try:
            local_detector = YoloDetector(MODEL_PATH)
        except FileNotFoundError:
            return {
                'success': False,
                'error': f'Model not found: {MODEL_PATH}'
            }
    
    # 3. Detect từng ảnh và tổng hợp kết quả
    all_detections = []
    best_detection = None
    best_confidence = 0.0
    
    for i, img_data in enumerate(images):
        try:
            # Use the detector's byte-based predict API
            pred = local_detector.predict_bytes(img_data)

            # Normalize to expected keys
            if not pred or pred.get('num_detections', 0) == 0:
                class_name = 'Không xác định'
                confidence = 0.0
            else:
                top = pred.get('detections', [])[0]
                # prefer raw class key if present, otherwise use class_name
                class_name = top.get('class_key') or top.get('class_name') or 'Không xác định'
                confidence = float(top.get('confidence', 0.0))

            detection_item = {
                'class_name': class_name,
                'confidence': confidence
            }

            all_detections.append(detection_item)

            # Tìm detection có confidence cao nhất
            if confidence > best_confidence:
                best_confidence = confidence
                best_detection = detection_item
        except Exception as e:
            logger.error(f"[AutoDetection] Lỗi khi detect ảnh {i+1}: {e}")
            continue
    
    # 3. Lấy dữ liệu cảm biến
    sensor_data = get_recent_sensor_readings(db, device.device_id, hours=24)
    
    # 4. Lấy lịch sử detection
    recent_detections = get_recent_detections(db, device.device_id, days=7)
    
    # 5. Phân tích xu hướng
    trend_info = analyze_disease_trend(recent_detections)
    
    # 6. Xây dựng prompt nâng cao và gọi LLM
    enhanced_prompt = build_enhanced_prompt(
        all_detections,
        sensor_data,
        device,
        trend_info
    )
    
    disease_summary = None
    care_instructions = None
    
    if all_detections:
        # Gọi LLM với prompt nâng cao
        try:
            disease_summary, care_instructions = summarize_detections_with_llm(all_detections)
            
            # Nếu có thông tin bổ sung, thêm vào prompt
            if sensor_data or trend_info.get('has_history'):
                # Gọi lại LLM với prompt đầy đủ
                from app.services.llm_service import client, GEMINI_MODEL
                import google.generativeai as genai
                
                if client:
                    full_prompt = enhanced_prompt
                    model = genai.GenerativeModel(model_name=GEMINI_MODEL)
                    response = model.generate_content(full_prompt)
                    full_text = (response.text or "").strip()
                    
                    # Parse lại từ full_text
                    text_lower = full_text.lower()
                    idx_ds = text_lower.find("[disease_summary]")
                    idx_ci = text_lower.find("[care_instructions]")
                    
                    if idx_ds != -1 and idx_ci != -1:
                        disease_summary = full_text[idx_ds + len("[DISEASE_SUMMARY]"): idx_ci].strip()
                        care_instructions = full_text[idx_ci + len("[CARE_INSTRUCTIONS]"):].strip()
        except Exception as e:
            print(f"[AutoDetection] Lỗi khi gọi LLM: {e}")
    
    # 7. Lưu kết quả vào database (dùng ảnh đầu tiên làm đại diện)
    saved_result = None
    has_disease = False
    
    if images and all_detections:
        # Lưu ảnh đầu tiên và tất cả detections
        try:
            # Format yolo_result giống như routes_detect.py
            yolo_result = {
                'detections': all_detections,
                'num_detections': len(all_detections)
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
            
            # Kiểm tra có bệnh không (loại trừ healthy classes)
            healthy_classes = {'pomelo_leaf_healthy', 'pomelo_fruit_healthy'}
            for det in all_detections:
                class_name = det.get('class_name', '')
                if class_name and class_name not in healthy_classes:
                    has_disease = True
                    break
        except Exception as e:
            logger.error(f"[AutoDetection] Lỗi khi lưu kết quả: {e}")
    
    # 8. Tạo notification nếu phát hiện bệnh
    notification_created = False
    if has_disease and device.user_id:
        try:
            # Xác định bệnh phổ biến nhất
            disease_names = [d.get('class_name', '') for d in all_detections if d.get('class_name')]
            disease_counts = Counter(disease_names)
            if disease_counts:
                most_common_disease = disease_counts.most_common(1)[0][0]
                
                title = f"⚠️ Phát hiện bệnh trên camera: {device.name or 'Camera'}"
                description = f"""
Phát hiện bệnh: {most_common_disease}
Vị trí: {device.location or 'N/A'}
Thời gian: {datetime.now().strftime('%d/%m/%Y %H:%M')}

{disease_summary or 'Đang phân tích...'}

Hướng dẫn xử lý:
{care_instructions or 'Vui lòng kiểm tra chi tiết trong lịch sử detection.'}
                """.strip()
                
                notification = Notification(
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
        'notification_created': notification_created
    }

