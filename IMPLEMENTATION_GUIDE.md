# 🚀 Implementation Guide: Camera Stream + Auto-Detection

## ✅ Hoàn thành những phần chính

### 1. **Frontend: HLS Video Player trong Home Page**

#### Files tạo/chỉnh sửa:
- ✅ `lib/core/camera_provider.dart` - Provider quản lý camera được chọn
- ✅ `lib/services/camera_stream_service.dart` - Service fetch camera data + stream health
- ✅ `lib/ui/widgets/camera_stream_player.dart` - HLS video player widget
- ✅ `lib/ui/home_user.dart` - Integrate video player vào Home page
- ✅ `lib/ui/devices_page.dart` - Update chọn camera → sync với Home
- ✅ `lib/main.dart` - Setup Provider

#### Thay đổi pubspec.yaml:
```yaml
dependencies:
  video_player: ^2.8.0
  provider: ^6.4.0
```

---

### 2. **Backend: API GET /devices/me/selected**

#### File: `backend/app/api/v1/routes_devices.py`

```python
@router.get("/me/selected", dependencies=[Depends(get_current_user)])
def get_selected_camera(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Get currently selected camera for user"""
    camera = db.query(Device).filter(
        Device.user_id == current_user.user_id,
        Device.device_type_id == 1,  # Camera
        Device.stream_url.isnot(None),
    ).order_by(Device.updated_at.desc()).first()
    
    if not camera:
        return {
            "device_id": None,
            "name": None,
            "stream_url": None,
            "status": None,
            "hls_url": None,
            "message": "Không có camera nào được chọn"
        }
    
    hls_url = f"/media/hls/{camera.device_id}/index.m3u8"
    
    return {
        "device_id": camera.device_id,
        "name": camera.name,
        "stream_url": camera.stream_url or camera.gateway_stream_id,
        "status": camera.status,
        "hls_url": hls_url,
        "message": "Thành công"
    }
```

---

## 🎯 Workflow chi tiết

### **User vào trang Home:**
```
HomeUserPage.initState()
    ↓
_loadSelectedCamera() gọi CameraStreamService.getSelectedCamera()
    ↓
Backend API /devices/me/selected trả camera data
    ↓
CameraProvider.setSelectedCamera() lưu vào local + Provider
    ↓
Build CameraStreamPlayer widget
    ↓
CameraStreamPlayer._initializeVideo() tạo HLS URL
    ↓
VideoPlayerController.networkUrl() khởi tạo video
    ↓
Hiển thị video stream HLS
```

### **User chọn camera khác trong Devices Page:**
```
DevicesPage._selectCamera(device)
    ↓
DeviceService.selectCamera(device.deviceId) gửi server
    ↓
CameraProvider.setSelectedCamera() update provider state
    ↓
HomeUserPage lắng nghe CameraProvider (via Provider.watch)
    ↓
Rebuild CameraStreamPlayer với camera mới
    ↓
HLS URL cũ bị dispose, URL mới được khởi tạo
    ↓
Video stream tự động chuyển sang camera mới
```

### **Stream gặp lỗi (camera offline):**
```
CameraStreamPlayer._startHealthCheck() (mỗi 30s)
    ↓
CameraStreamService.checkStreamHealth(deviceId)
    ↓
Backend API /streams/health/{deviceId} kiểm tra ffmpeg process
    ↓
Nếu unhealthy → CameraStreamPlayer hiển thị error message
    ↓
User click "Kết nối lại" → _initializeVideo() retry
```

---

## 📋 Files thay đổi

### Frontend:
```
lib/
├── core/
│   └── camera_provider.dart (NEW)
├── services/
│   └── camera_stream_service.dart (NEW)
├── ui/
│   ├── widgets/
│   │   └── camera_stream_player.dart (NEW)
│   ├── home_user.dart (MODIFIED - thêm video player)
│   ├── devices_page.dart (MODIFIED - trigger camera sync)
│   └── home_shell.dart (UNCHANGED)
└── main.dart (MODIFIED - setup Provider)

pubspec.yaml (MODIFIED - thêm video_player + provider)
```

### Backend:
```
backend/app/api/v1/
└── routes_devices.py (MODIFIED - thêm /devices/me/selected)
```

---

## 🔌 API Endpoints

### Frontend → Backend

**1. Get selected camera:**
```
GET /api/v1/devices/me/selected
Headers: Authorization: Bearer {token}

Response:
{
    "device_id": 1,
    "name": "Camera chính",
    "stream_url": "rtsp://...",
    "status": "active",
    "hls_url": "/media/hls/1/index.m3u8",
    "message": "Thành công"
}
```

**2. Select camera (already existed):**
```
POST /api/v1/devices/select_camera
Headers: Authorization: Bearer {token}
Body: {"device_id": 1}

Response:
{
    "selected_device_id": 1,
    "status": "active"
}
```

**3. Check stream health (already existed):**
```
GET /api/v1/streams/health/{device_id}
Headers: Authorization: Bearer {token}

Response:
{
    "healthy": true,
    "running": true,
    "hls_exists": true,
    "last_update": 2.5
}
```

**4. Start stream (already existed):**
```
POST /api/v1/streams/start
Headers: Authorization: Bearer {token}
Body: {"device_id": 1}

Response:
{
    "hls_url": "/media/hls/1/index.m3u8",
    "running": true,
    "message": "Stream started or resumed"
}
```

**5. Stop stream (already existed):**
```
POST /api/v1/streams/stop
Headers: Authorization: Bearer {token}
Body: {"device_id": 1}

Response:
{
    "stopped": true
}
```

---

## ⚙️ Cài đặt & Chạy

### Backend:
```bash
cd backend

# Đã có scheduler chạy auto-detection mỗi 30 giây
# Không cần config thêm
```

### Frontend:
```bash
cd frontend/mobile_web_flutter

# Cài dependencies (có video_player + provider)
flutter pub get

# Build & run
flutter run -d chrome
```

---

## 🧪 Test Workflow

### Test 1: Home page hiển thị camera stream
1. Login → vào Home page
2. Kiểm tra: Video player hiển thị, camera name và status "Online"
3. Nếu không có camera → hiển thị "Chưa có camera nào được chọn"

### Test 2: Chuyển camera
1. Click nút "Đổi camera" → đi tới Devices page
2. Chọn camera khác
3. Click "Đi tới Home" → video stream tự động cập nhật

### Test 3: Error handling
1. Tắt ffmpeg hoặc camera → stream health check detect lỗi
2. Hiển thị "❌ Không thể kết nối camera"
3. Click "Kết nối lại" → retry

### Test 4: Auto-detection (Backend)
1. Backend scheduler chạy mỗi 30 giây
2. Nếu phát hiện bệnh → tạo Notification
3. Frontend lấy thông báo qua `/notifications/my`

---

## 🐛 Troubleshooting

### Video player không hiển thị
- [ ] Kiểm tra backend có chạy FFmpeg không: `curl http://localhost:8000/streams/active`
- [ ] Kiểm tra FFmpeg đã install: `ffmpeg -version`
- [ ] Kiểm tra RTSP URL hợp lệ: `ffprobe rtsp://...`
- [ ] Kiểm tra HLS files tồn tại: `ls media/hls/{device_id}/`

### Stream lag hoặc mất kết nối
- [ ] Kiểm tra mạng: latency, bandwidth
- [ ] Kiểm tra FFmpeg process còn chạy: `ps aux | grep ffmpeg`
- [ ] Kiểm tra server logs: `tail -f backend/logs.txt`

### Provider lỗi "not found"
- [ ] Kiểm tra `main.dart` có `MultiProvider` không
- [ ] Kiểm tra import `camera_provider.dart` đúng
- [ ] Rebuild app: `flutter clean && flutter pub get && flutter run`

---

## 📝 Tiếp theo cần làm

### High Priority:
1. **Test HLS video player** - Đảm bảo video phát được
2. **Test Provider state sync** - Kiểm tra Home auto-update khi chọn camera
3. **Test stream health check** - Đảm bảo error handling hoạt động

### Medium Priority:
4. **UI Polish** - Animations, loading states
5. **Notification detail** - Hiển thị ảnh + bệnh trong thông báo
6. **Toggle auto-detect per camera** - UI trong Devices page

### Low Priority:
7. **Analytics** - Track camera usage
8. **Performance** - Optimize HLS buffer, video quality

---

## 📞 Support

Nếu gặp vấn đề:
1. Check logs: `backend/logs.txt` + Flutter console
2. Check network: DevTools → Network tab
3. Check Provider state: DevTools → Provider extension
4. Read API response: Print JSON từ API

