# app/services/sensor_alert_service.py
"""
Service tự động cảnh báo khi nhiệt độ/độ ẩm vượt ngưỡng an toàn
"""
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

from app.models.devices import Device
from app.models.sensor_readings import SensorReadings
from app.models.notification import Notifications
from app.models.user import Users

# ============================================
# NGƯỠNG CẢNH BÁO (theo bảng của người dùng)
# ============================================
THRESHOLDS = {
    'temperature': {
        'very_high': {'value': 40, 'level': 'critical', 'message': 'Nhiệt độ rất cao'},
        'high': {'value': 35, 'level': 'warning', 'message': 'Nhiệt độ cao'},
        'low': {'value': 10, 'level': 'warning', 'message': 'Nhiệt độ thấp'},  # ✅ Thay đổi từ 15 thành 17
        'very_low': {'value': 4, 'level': 'critical', 'message': 'Nhiệt độ rất thấp'},
    },
    'humidity': {
        'very_high': {'value': 85, 'level': 'warning', 'message': 'Độ ẩm không khí cao'},
        'low': {'value': 50, 'level': 'warning', 'message': 'Độ ẩm không khí thấp'},
    }
}

# Hướng dẫn xử lý cho từng ngưỡng
RECOMMENDATIONS = {
    'temperature': {
        'very_high': """Gây sốc nhiệt, ngừng sinh trưởng; tổn thương mô non; có thể dẫn đến chết cây, đặc biệt ở giai đoạn cây con

Biện pháp khắc phục:
- Che nắng tạm thời toàn bộ tán cây
- Áp dụng hệ thống tưới nhỏ giọt để duy trì ẩm đất
- Hạn chế bón phân hóa học""",
        
        'high': """Gây cháy mép lá, giảm khả năng quang hợp; rụng hoa và quả non; làm suy giảm năng suất và chất lượng quả

Biện pháp khắc phục:
- Sử dụng lưới che nắng (30-50%)
- Tưới nước vào sáng sớm hoặc chiều mát
- Phủ gốc bằng vật liệu hữu cơ
- Phun phân bón lá có tác dụng giảm stress sinh lý""",
        
        'low': """Làm chậm quá trình sinh trưởng; giảm tỷ lệ đậu quả; tăng nguy cơ nhiễm bệnh do nấm

Biện pháp khắc phục:
- Che chắn gió lạnh
- Phủ gốc giữ ấm cho rễ
- Hạn chế cắt tỉa và bón phân đạm trong thời kỳ nhiệt độ thấp""",
        
        'very_low': """Gây cháy lá, hoại tử mô non; cây suy kiệt và có thể ngừng sinh trưởng hoàn toàn

Biện pháp khắc phục:
- Che phủ gốc và thân cây
- Giữ ấm đất bằng vật liệu hữu cơ
- Tránh mọi biện pháp canh tác tác động mạnh""",
    },
    'humidity': {
        'very_high': """Tạo điều kiện thuận lợi cho các bệnh do nấm phát sinh (thối rễ, xì mủ, than thư); gây rụng hoa và quả

Biện pháp khắc phục:
- Tăng cường thoát nước cho vườn
- Cải tạo đất
- Phun phòng nấm bằng chế phẩm sinh học hoặc thuốc bảo vệ thực vật phù hợp""",
        
        'low': """Cây mất nước, héo lá; hoa khó đậu quả; gia tăng mật độ sâu hại như nhện đỏ, bọ trĩ

Biện pháp khắc phục:
- Tưới bổ sung nước hợp lý
- Phủ gốc giữ ẩm
- Trồng cây phủ đất
- Áp dụng biện pháp phòng trừ sâu hại sinh học""",
    }
}


def check_temperature_threshold(value: float) -> Optional[Dict[str, Any]]:
    """Kiểm tra ngưỡng nhiệt độ và trả về cảnh báo nếu vượt ngưỡng"""
    if value >= THRESHOLDS['temperature']['very_high']['value']:
        return {
            **THRESHOLDS['temperature']['very_high'],
            'type': 'temperature',
            'value': value,
            'threshold_key': 'very_high',
            'recommendation': RECOMMENDATIONS['temperature']['very_high']
        }
    elif value >= THRESHOLDS['temperature']['high']['value']:
        return {
            **THRESHOLDS['temperature']['high'],
            'type': 'temperature',
            'value': value,
            'threshold_key': 'high',
            'recommendation': RECOMMENDATIONS['temperature']['high']
        }
    elif value <= THRESHOLDS['temperature']['very_low']['value']:
        return {
            **THRESHOLDS['temperature']['very_low'],
            'type': 'temperature',
            'value': value,
            'threshold_key': 'very_low',
            'recommendation': RECOMMENDATIONS['temperature']['very_low']
        }
    elif value <= THRESHOLDS['temperature']['low']['value']:
        return {
            **THRESHOLDS['temperature']['low'],
            'type': 'temperature',
            'value': value,
            'threshold_key': 'low',
            'recommendation': RECOMMENDATIONS['temperature']['low']
        }
    return None


def check_humidity_threshold(value: float) -> Optional[Dict[str, Any]]:
    """Kiểm tra ngưỡng độ ẩm và trả về cảnh báo nếu vượt ngưỡng"""
    if value >= THRESHOLDS['humidity']['very_high']['value']:
        return {
            **THRESHOLDS['humidity']['very_high'],
            'type': 'humidity',
            'value': value,
            'threshold_key': 'very_high',
            'recommendation': RECOMMENDATIONS['humidity']['very_high']
        }
    elif value <= THRESHOLDS['humidity']['low']['value']:
        return {
            **THRESHOLDS['humidity']['low'],
            'type': 'humidity',
            'value': value,
            'threshold_key': 'low',
            'recommendation': RECOMMENDATIONS['humidity']['low']
        }
    return None


def check_sensor_alerts(db: Session, hours_back: int = 1) -> Dict[str, Any]:
    """
    Kiểm tra các cảnh báo sensor trong X giờ gần đây
    Tạo notification cho user nếu phát hiện vượt ngưỡng
    
    Args:
        db: Database session
        hours_back: Số giờ kiểm tra ngược lại (mặc định 1 giờ)
    
    Returns:
        Dict với thống kê alerts đã tạo
    """
    cutoff_time = datetime.utcnow() - timedelta(hours=hours_back)
    
    # Lấy tất cả sensor readings trong khoảng thời gian
    readings = db.query(SensorReadings).filter(
        SensorReadings.recorded_at >= cutoff_time,
        SensorReadings.status == "ok",
        SensorReadings.value_num.isnot(None)
    ).order_by(SensorReadings.recorded_at.desc()).all()
    
    if not readings:
        logger.info(f"[SensorAlert] Không có sensor readings trong {hours_back} giờ qua")
        return {'alerts_created': 0, 'devices_checked': 0}
    
    # Group readings theo device_id và metric
    device_metrics: Dict[int, Dict[str, List[float]]] = {}
    device_info: Dict[int, Device] = {}
    
    for reading in readings:
        if reading.device_id not in device_metrics:
            device_metrics[reading.device_id] = {}
            device_info[reading.device_id] = reading.device
        
        metric = reading.metric.lower()
        if metric not in device_metrics[reading.device_id]:
            device_metrics[reading.device_id][metric] = []
        
        device_metrics[reading.device_id][metric].append(float(reading.value_num))
    
    alerts_created = 0
    devices_checked = len(device_metrics)
    
    # Kiểm tra từng device
    for device_id, metrics in device_metrics.items():
        device = device_info[device_id]
        
        if not device.user_id:
            continue
        
        # Kiểm tra nhiệt độ
        if 'temperature' in metrics:
            avg_temp = sum(metrics['temperature']) / len(metrics['temperature'])
            logger.info(f"[SensorAlert] Device {device_id} ({device.name}): Nhiệt độ TB = {avg_temp:.1f}°C")
            alert = check_temperature_threshold(avg_temp)
            
            if alert:
                logger.info(f"[SensorAlert] ⚠️ Phát hiện vượt ngưỡng: {alert['message']} (giá trị: {avg_temp:.1f}°C, ngưỡng: {alert['value']}°C)")
                # ✅ TEST: Giảm xuống 1 phút để test (production nên để 6 giờ)
                recent_notif = db.query(Notifications).filter(
                    Notifications.user_id == device.user_id,
                    Notifications.title.like(f"%{alert['message']}%"),
                    Notifications.title.like(f"%{device.name}%"),
                    Notifications.created_at >= datetime.utcnow() - timedelta(minutes=1)
                ).first()
                
                if not recent_notif:
                    title = f"⚠️ {alert['message']}: {device.name or 'Thiết bị'}"
                    description = f"""
Cảnh báo {alert['level'].upper()}: {alert['message']}

Thiết bị: {device.name or 'N/A'}
Vị trí: {device.location or 'N/A'}
Nhiệt độ hiện tại: {avg_temp:.1f}°C
Ngưỡng: {'>' if 'high' in alert['threshold_key'] else '<'} {alert['value']}°C
Thời gian: {datetime.now().strftime('%d/%m/%Y %H:%M')}

Tác hại:
{alert['recommendation']}
                    """.strip()
                    
                    notification = Notifications(
                        user_id=device.user_id,
                        title=title,
                        description=description
                    )
                    db.add(notification)
                    alerts_created += 1
                    logger.info(f"[SensorAlert] ✅ Đã tạo cảnh báo nhiệt độ cho user {device.user_id}, device {device_id}")
                else:
                    logger.debug(f"[SensorAlert] Bỏ qua - Đã có notification tương tự gần đây cho device {device_id}")
        
        # Kiểm tra độ ẩm
        if 'humidity' in metrics:
            avg_humidity = sum(metrics['humidity']) / len(metrics['humidity'])
            logger.info(f"[SensorAlert] Device {device_id} ({device.name}): Độ ẩm TB = {avg_humidity:.1f}%")
            alert = check_humidity_threshold(avg_humidity)
            
            if alert:
                logger.info(f"[SensorAlert] ⚠️ Phát hiện vượt ngưỡng: {alert['message']} (giá trị: {avg_humidity:.1f}%, ngưỡng: {alert['value']}%)")
                # ✅ TEST: Giảm xuống 1 phút để test (production nên để 6 giờ)
                recent_notif = db.query(Notifications).filter(
                    Notifications.user_id == device.user_id,
                    Notifications.title.like(f"%{alert['message']}%"),
                    Notifications.title.like(f"%{device.name}%"),
                    Notifications.created_at >= datetime.utcnow() - timedelta(minutes=1)
                ).first()
                
                if not recent_notif:
                    title = f"⚠️ {alert['message']}: {device.name or 'Thiết bị'}"
                    description = f"""
Cảnh báo {alert['level'].upper()}: {alert['message']}

Thiết bị: {device.name or 'N/A'}
Vị trí: {device.location or 'N/A'}
Độ ẩm hiện tại: {avg_humidity:.1f}%
Ngưỡng: {'>' if 'high' in alert['threshold_key'] else '<'} {alert['value']}%
Thời gian: {datetime.now().strftime('%d/%m/%Y %H:%M')}

Tác hại:
{alert['recommendation']}
                    """.strip()
                    
                    notification = Notifications(
                        user_id=device.user_id,
                        title=title,
                        description=description
                    )
                    db.add(notification)
                    alerts_created += 1
                    logger.info(f"[SensorAlert] ✅ Đã tạo cảnh báo độ ẩm cho user {device.user_id}, device {device_id}")
                else:
                    logger.debug(f"[SensorAlert] Bỏ qua - Đã có notification tương tự gần đây cho device {device_id}")
    
    if alerts_created > 0:
        db.commit()
        logger.info(f"[SensorAlert] Đã tạo {alerts_created} cảnh báo cho {devices_checked} thiết bị")
    
    return {
        'alerts_created': alerts_created,
        'devices_checked': devices_checked,
        'readings_analyzed': len(readings)
    }
