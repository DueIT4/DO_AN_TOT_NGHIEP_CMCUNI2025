# 📊 Phân tích Workflow Hệ thống Camera & Phân tích AI

## ✅ Phần đã hoàn thành

### 1️⃣ Trang Home – Hiển thị thông báo & Thời tiết
**Status: ✅ HOÀN THÀNH**
- **File**: `frontend/mobile_web_flutter/lib/ui/home_user.dart`
- ✅ Hiển thị danh sách thông báo từ backend
- ✅ Xử lý lỗi tải thông báo
- ✅ Hiển thị thời tiết từ API OpenWeather
- ✅ Quản lý LocationPermission để lấy tọa độ

**Tuy nhiên**: Home page chưa có tính năng hiển thị **camera stream trực tiếp**

---

### 2️⃣ Trang Thiết bị – Quản lý & Chọn Camera
**Status: ✅ HOÀN THÀNH**
- **File**: `frontend/mobile_web_flutter/lib/ui/devices_page.dart`

**Những gì đã làm:**
- ✅ Tải danh sách thiết bị (camera + sensor)
- ✅ Hiển thị trạng thái camera (online/offline)
- ✅ Hiển thị cảm biến cuối cùng (humidity, battery)
- ✅ Cho phép **chọn camera** → gọi `DeviceService.selectCamera()`
- ✅ Lưu lựa chọn camera trên **server backend**
- ✅ Filter thiết bị (tất cả / camera / cảm biến)
- ✅ Hiển thị ảnh phát hiện gần nhất của camera

**Flow chọn camera:**
```
User chọn camera trong DevicesPage
    ↓
_selectCamera(device) gọi DeviceService.selectCamera(device.deviceId)
    ↓
Backend lưu: user → device mapping
    ↓
Hiển thị toast: "Đang sử dụng camera: {name}"
```

---

### 3️⃣ Luồng Trích xuất Ảnh & Phân tích AI
**Status: ✅ HOÀN THÀNH**
- **Files Backend**:
  - `app/services/scheduler_service.py` - Scheduler chạy mỗi 30 giây
  - `app/services/auto_detection_service.py` - Logic phát hiện tự động
  - `app/api/v1/routes_auto_detection.py` - API endpoints

**Những gì đã làm:**
- ✅ Scheduler khởi động mỗi **30 giây**
- ✅ Quét tất cả devices có `auto_detect` bật
- ✅ Lấy ảnh từ camera stream (RTSP/HTTP/HLS)
- ✅ Chạy YOLO detection
- ✅ **Nếu phát hiện bệnh**:
  - ✅ Lưu kết quả vào DB (Img + Detection)
  - ✅ Tạo thông báo (Notification) → gửi cho user
  - ✅ Thông báo bao gồm: camera name, thời gian, loại bệnh
  - ✅ LLM tổng hợp kết quả + lịch sử + cảm biến → khuyến nghị
- ✅ **Nếu cây bình thường**:
  - ✅ KHÔNG gửi thông báo (chỉ lưu log)

**Code flow:**
```python
# scheduler_service.py - mỗi 30 giây
for device_id in _auto_detect_devices:
    result = detect_from_camera_auto(db, device, num_images=1, auto_stop_stream=False)
    
    if result['has_disease']:
        # Notification đã được tạo trong detect_from_camera_auto
        logger.warning(f"⚠️ Phát hiện bệnh: {device.name}")
```

```python
# auto_detection_service.py
def detect_from_camera_auto(...) -> Dict[str, Any]:
    # 1. Lấy 1 ảnh từ stream
    images = capture_multiple_images(...)
    
    # 2. Chạy YOLO detection
    detections = detector.predict(...)
    
    # 3. Lưu kết quả vào DB
    save_detection_result(db, ...)
    
    # 4. LLM tổng hợp + tạo thông báo nếu có bệnh
    if has_disease:
        notification = Notifications(
            user_id=device.user_id,
            type='auto_detection',
            title=f'Phát hiện bệnh từ {device.name}',
            content=llm_summary,
            link=f'/detections/{detection_id}'
        )
        db.add(notification)
        db.commit()
```

---

### 4️⃣ Stream Video từ Camera
**Status: ✅ HOÀN THÀNH (Cơ bản)**
- **Files**: `app/services/stream_service.py`, `app/api/v1/routes_streams.py`

**Những gì đã làm:**
- ✅ FFmpeg chuyển RTSP → HLS
- ✅ Start stream API: `POST /streams/start` (truyền device_id)
- ✅ Stop stream API: `POST /streams/stop`
- ✅ Get stream health: `GET /streams/health/{device_id}`
- ✅ List active streams: `GET /streams/active`
- ✅ Tự động cleanup stream cũ nếu RTSP URL thay đổi
- ✅ HLS URL output: `/media/hls/{device_id}/index.m3u8`

---

## ❌ Phần THIẾU / CẦN CẢI THIỆN

### ❌ 1. HOME PAGE CHƯA CÓ STREAM VIDEO CAMERA TRỰC TIẾP
**Problem**: HomeUserPage không hiển thị camera stream

**Cần làm:**
1. ✏️ Chỉnh sửa `home_user.dart` để thêm:
   - HLS video player (dùng `video_player` plugin)
   - Khi user vào Home → tự động kết nối stream của camera đang chọn
   - Hiển thị lỗi nếu camera offline / stream fail
   - Xử lý khi user đổi tab hoặc reload

2. ✏️ Backend cần API để get **camera info của user hiện tại**:
   - `GET /devices/me/selected` → trả về device_id + stream_url của camera được chọn
   - Hoặc `GET /devices/me/primary-camera`

---

### ❌ 2. CHƯA TỰ ĐỘNG CHUYỂN STREAM KHI ĐỔI CAMERA
**Problem**: Khi chọn camera khác trong DevicesPage → Home chưa tự động cập nhật video

**Cần làm:**
1. ✏️ HomeShell / HomeUserPage cần **lắng nghe sự thay đổi camera**:
   - Dùng Provider / GetX / BLoC để quản lý "selected camera"
   - Khi user đổi camera → trigger event → Home tự động stop stream cũ + start stream mới

2. ✏️ Hoặc frontend poll API `GET /devices/me/selected` định kỳ để check

---

### ❌ 3. CHƯA CÓ ERROR HANDLING CHO CAMERA STREAM
**Problem**: Nếu camera mất kết nối, frontend vẫn hiển thị giao diện blank

**Cần làm:**
1. ✏️ `home_user.dart` cần xử lý:
   - Nếu stream fail → hiển thị "❌ Không thể kết nối camera"
   - Poll `/streams/health/{device_id}` định kỳ → detect lỗi
   - Tự động retry kết nối stream

2. ✏️ Backend `/streams/health/{device_id}` đã có, cần frontend sử dụng nó

---

### ❌ 4. CHƯA TEST DISABLE AUTO-DETECTION
**Problem**: Backend có route enable/disable auto-detect, nhưng frontend chưa dùng

**File cần xem**: `app/api/v1/routes_auto_detection.py`

**Cần làm:**
1. ✏️ Thêm UI trong DevicesPage để toggle "Auto-detect" cho từng camera
2. ✏️ Frontend call API: `POST /auto-detection/enable/{device_id}`
3. ✏️ Lưu trạng thái vào server

---

### ❌ 5. FRONTEND HOME PAGE CHƯA CÓ "SELECTED CAMERA" INFO
**Problem**: HomeUserPage chỉ hiển thị thời tiết + thông báo, chưa biết camera nào được chọn

**Cần làm:**
1. ✏️ HomeUserPage cần gọi:
   - `GET /devices/me` → filter camera `status='active'`
   - Hoặc backend thêm field `is_selected: bool` trong Device schema
2. ✏️ Hiển thị camera name + status
3. ✏️ Nút "Chuyển camera" → đưa user đến DevicesPage

---

### ❌ 6. FRONTEND NOTIFICATION CHƯA HIỂN THỊ THÔNG TIN CHI TIẾT
**Problem**: Thông báo chỉ hiển thị title, chưa có:
- Hình ảnh phát hiện
- Camera nào phát hiện
- Loại bệnh là gì
- Khuyến nghị xử lý

**Cần làm:**
1. ✏️ Mở rộng schema Notification:
   ```python
   class Notifications(Base):
       # ... hiện tại
       camera_name: str  # Thêm
       detection_id: int  # Link đến detection
       disease_name: str  # Tên bệnh
   ```

2. ✏️ Frontend click thông báo → mở detail page:
   - Hiển thị ảnh được phát hiện
   - Hiển thị loại bệnh + confidence
   - Khuyến nghị xử lý

---

## 📋 CHECKLIST: CÓ/CHƯA CÓ LOGIC

| Yêu cầu | Status | File | Ghi chú |
|--------|--------|------|---------|
| Home page hiển thị video camera | ❌ | `home_user.dart` | CHƯA CÓ |
| Home page xử lý lỗi camera | ❌ | `home_user.dart` | CHƯA CÓ |
| Trang Devices quản lý camera | ✅ | `devices_page.dart` | Hoàn thành |
| Chọn camera → lưu server | ✅ | `devices_page.dart` + `routes_devices.py` | Hoàn thành |
| Chuyển camera → stream tự cập nhật | ❌ | `home_user.dart` + `devices_page.dart` | CHƯA CÓ |
| Backend: Scheduler 30s quét camera | ✅ | `scheduler_service.py` | Hoàn thành |
| Backend: Lấy ảnh + chạy YOLO | ✅ | `auto_detection_service.py` | Hoàn thành |
| Backend: Nếu bệnh → gửi notification | ✅ | `auto_detection_service.py` | Hoàn thành |
| Backend: Nếu bình thường → không báo | ✅ | `auto_detection_service.py` | Hoàn thường |
| Backend: Stream health check | ✅ | `stream_service.py` | Hoàn thành |
| Frontend: Notification detail page | ❌ | `notifications_list_page.dart` | CHƯA CÓ |
| Frontend: Camera notification bao gồm ảnh | ❌ | DB schema | CHƯA CÓ |
| Frontend: Toggle auto-detect per camera | ❌ | `devices_page.dart` | CHƯA CÓ |

---

## 🎯 KHO HỤC TỪ ĐƠNG VÀ TỔNG LUỒNG

### Backend (✅ Gần như hoàn thành)
```
Scheduler chạy mỗi 30s
    ↓
Quét devices có auto_detect bật
    ↓
Với mỗi device:
  1. Lấy 1 ảnh từ stream
  2. Chạy YOLO detection
  3. Lưu Img + Detection + DeviceLog vào DB
  4. Nếu phát hiện bệnh:
     - LLM tổng hợp kết quả + lịch sử + cảm biến
     - Tạo Notification → gửi user
  5. Nếu cây bình thường:
     - Chỉ lưu log, không gửi notification
```

### Frontend (⚠️ 50% hoàn thành)
```
✅ Đã làm:
  - DevicesPage: Quản lý camera + chọn camera
  - HomeUserPage: Thông báo + thời tiết
  - CameraDetectionPage: Upload ảnh hoặc chụp ảnh phân tích

❌ Chưa làm:
  - HomeUserPage: Hiển thị camera stream
  - Tự động chuyển stream khi chọn camera khác
  - Error handling cho stream
  - Xem chi tiết thông báo (ảnh + bệnh + khuyến nghị)
```

---

## 🚀 HÀNH ĐỘNG TIẾP THEO

### Ưu tiên cao (Critical):
1. **Home page hiển thị camera stream**
   - Thêm HLS video player vào HomeUserPage
   - Tự động kết nối stream khi vào Home

2. **Chuyển camera → tự động cập nhật stream**
   - Dùng Provider/GetX để quản lý selected camera
   - HomeUserPage lắng nghe thay đổi → cập nhật stream

3. **Error handling stream**
   - Check stream health định kỳ
   - Hiển thị error message nếu offline

### Ưu tiên trung bình:
4. **Chi tiết thông báo với ảnh + bệnh**
   - Mở rộng Notification schema
   - Tạo detail page hiển thị detection

5. **Toggle auto-detect per camera**
   - UI trong DevicesPage

### Ưu tiên thấp:
6. **Polish UI/UX**
   - Animations + loading states
   - Retry logic

