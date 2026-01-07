# 🖼️ Phân Tích Vấn Đề Hiển Thị Video & Images

## 📍 Tóm Tắt Vấn Đề
1. **Video stream được nhận nhưng không render** - HLS URL không display ở camera section
2. **Detection images phân tích được nhưng không hiển thị** - Không show ở history
3. **Ảnh không hiện sau khi phân tích xong** - State update có vấn đề

---

## 🔴 **Vấn Đề 1: Video Stream Không Hiển Thị**

### Nguyên Nhân
**File:** `home_user.dart` (dòng 745-758)

```dart
// ✅ Nơi hiển thị video
return ClipRRect(
  borderRadius: BorderRadius.circular(16),
  child: camera_widgets.CameraStreamPlayer(
    deviceId: widget.deviceId,
    deviceName: 'DroidCam',
    hlsUrl: _hlsUrl,
  ),
);
```

**File:** `camera_stream_player.dart` (dòng 74-99)

```dart
void _initializeVideo() {
  final provided = widget.hlsUrl.trim();
  String fullUrl;

  if (provided.isEmpty) {
    // ⚠️ Nếu hlsUrl = "" → Build từ device ID
    fullUrl = CameraStreamService.buildFullHlsUrl(widget.deviceId);
  } else if (provided.startsWith('http://') || provided.startsWith('https://')) {
    fullUrl = provided;
  } else {
    // Nếu relative path: "/media/hls/28/index.m3u8"
    fullUrl = '${ApiBase.host}$provided';
  }
  
  // ✅ Thực tế:
  // Video player initialize → nhưng playlist không có segments
  // → Video không phát được
}
```

### Root Cause
**HLS Playlist trống hoặc không được serve:**
- Backend `stream_service.py` start FFmpeg
- FFmpeg convert RTSP → HLS segments
- **Nhưng:** Nếu device **không có RTSP URL trong database** → FFmpeg không start
- → `/media/hls/{device_id}/index.m3u8` tồn tại nhưng **EMPTY** (không có segment_*.ts files)
- → Video player load playlist nhưng **không có video data** → Blank screen

**Hoặc:** Permission issue - frontend không thể access `/media/hls` folder từ Android APK

---

## 🔴 **Vấn Đề 2 & 3: Detection Images Không Hiển Thị**

### Vấn Đề 2a: List History Không Show Ảnh

**File:** `detection_service.dart` (dòng 119-122)

```dart
// ⚠️ BUG: Khi fetch history list, backend trả file_url
final imageUrl = _resolveUrl(m['file_url'] ?? m['img_url'] ?? m['image_url']);
// ❌ Frontend convert: file_url → full URL
// Ví dụ: "/media/detections/abc123.jpg" → "http://backend.com/media/detections/abc123.jpg"
```

**File:** `camera_detection_page.dart` (dòng 374-385)

```dart
Widget _buildImage() {
  if (record.imageBytes != null) {
    return Image.memory(record.imageBytes!, fit: BoxFit.cover);
  }
  if (record.imageUrl != null && record.imageUrl!.isNotEmpty) {
    return Image.network(
      record.imageUrl!,  // ← Load từ URL
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFE8F4D9),
        child: const Icon(Icons.broken_image, size: 40),
      ),
    );
  }
  // ...
}
```

### 🔴 **Nguyên Nhân Chi Tiết**

#### ❌ Problem #1: Backend `file_url` Format
**File:** `backend/app/api/v1/routes_detections.py` (tương tự)

```python
# Backend return trong list response:
{
    "detection_id": 123,
    "disease_name": "Leaf Spot",
    "confidence": 0.85,
    "file_url": "/media/detections/leaf_spot_123.jpg",  # ← Relative path
    "created_at": "2025-01-05T10:30:00Z"
}
```

Frontend cố convert:
```dart
// _resolveUrl() trong detection_service.dart
static String? _resolveUrl(dynamic raw) {
  if (raw == null) return null;
  final v = raw.toString();
  if (v.isEmpty) return null;
  if (v.startsWith('http')) return v;
  return '${ApiBase.host}$v';  // ← Append to host
  // Result: "http://backend.com/media/detections/leaf_spot_123.jpg"
}
```

**Vấn đề:**
- Nếu `ApiBase.host` = `"http://localhost:8000"` ✅ OK
- Nếu `ApiBase.host` = `"http://192.168.1.100:8000"` ✅ OK
- Nhưng nếu **port sai hoặc backend path sai** → 404 error → Image load fail → Blank

#### ❌ Problem #2: CORS / File Serving
**Backend không serve media folder hoặc có CORS issue:**

```python
# backend/app/main.py
app.mount("/media", StaticFiles(directory="media"), name="media")
# ✅ Nếu có dòng này → OK
# ❌ Nếu không có → Frontend không access được /media folder
```

#### ❌ Problem #3: Image File Không Được Save
**File:** `backend/app/services/auto_detection_service.py`

```python
async def analyze(device_id: int, frame: np.ndarray):
    # ...
    # Nhưng đâu:
    # - Ảnh được save vào `/media/detections/` chưa?
    # - File path có correct chưa?
    # - Permission để write vào folder?
```

### Vấn Đề 2b: Sau Phân Tích, Ảnh Không Hiện Ngay

**File:** `camera_detection_page.dart` (dòng 59-72)

```dart
Future<void> _handlePick(ImageSource source) async {
  // ...
  try {
    final record = await DetectionService.analyzeImage(...);
    
    if (!mounted) return;
    setState(() {
      _history = [record, ..._history];  // ✅ Add ngay
    });

    // Đồng bộ lại list
    await _loadHistory();  // ← Reload từ backend
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
}
```

**Vấn Đề:**
```dart
// 1. Frontend add record ngay (record.imageBytes từ local file)
_history = [record, ..._history];

// 2. Nhưng record từ analyzeImage() response có imageUrl không?
// ✅ Nếu backend return trong response → show image
// ❌ Nếu backend KHÔNG return imageUrl → record.imageUrl = null
// → setState refresh → image không show vì imageUrl null

// 3. Sau đó reload từ backend
await _loadHistory();  // ← Lấy lại từ DB
// ❌ Nhưng nếu image file KHÔNG được save → imageUrl = null
// → Image vẫn không show
```

---

## ✅ **Root Cause Summary**

| Vấn Đề | Nguyên Nhân | Dấu Hiệu |
|--------|-----------|---------|
| **Video không show** | HLS playlist empty / Device no RTSP URL | Blank video area, progressbar loading |
| **List images không show** | `ApiBase.host` sai / Backend không serve media folder | Broken image icon |
| **Image sau phân tích không show** | Backend không return `imageUrl` trong response / Image file không save | Ảnh hiện rồi disappear sau reload |

---

## 🔧 **Kiểm Tra & Fix**

### **Bước 1: Kiểm Tra Backend Config**

```bash
# 1. Check static files mount
grep -n "StaticFiles.*media" backend/app/main.py

# Expected output:
# app.mount("/media", StaticFiles(directory="media"), name="media")
```

### **Bước 2: Kiểm Tra Image File Được Save**

```bash
# Check media folder tồn tại và có files
ls -la media/detections/

# Kết quả:
# -rw-r--r-- leaf_spot_123.jpg
# -rw-r--r-- powdery_mildew_456.jpg
```

### **Bước 3: Kiểm Tra Backend Response Format**

```bash
# Gọi API để xem response
curl -H "Authorization: Bearer YOUR_TOKEN" \
  "http://localhost:8000/api/v1/detection-history/me?limit=5"

# Kết quả expected:
# {
#   "items": [
#     {
#       "detection_id": 123,
#       "disease_name": "Leaf Spot",
#       "file_url": "/media/detections/leaf_spot_123.jpg",  ← Important!
#       "confidence": 0.85,
#       "created_at": "2025-01-05T10:30:00Z"
#     }
#   ]
# }

# ❌ Nếu "file_url" = null hoặc missing → Problem!
```

### **Bước 4: Kiểm Tra APK Network Config**

```dart
// frontend/mobile_web_flutter/lib/core/api_base_app.dart

// Check ApiBase.host là gì
print('Backend host: ${ApiBase.host}');

// Expected: "http://192.168.x.x:8000" (IP của backend server)
// hoặc "https://api.yourdomain.com"
```

### **Bước 5: Test Image URL Trực Tiếp**

```bash
# Nếu APK cố load image từ URL:
# http://192.168.1.100:8000/media/detections/leaf_spot_123.jpg

# Kiểm tra từ browser:
curl -v "http://192.168.1.100:8000/media/detections/leaf_spot_123.jpg"

# Expected: 200 OK + image data
# ❌ Error: 404 Not Found → File không tồn tại
# ❌ Error: 403 Forbidden → Permission issue
```

---

## ✅ **Solutions**

### **Solution 1: Đảm Bảo Backend Mount Media Folder**

```python
# backend/app/main.py

from fastapi.staticfiles import StaticFiles
from pathlib import Path

# ✅ Thêm line này nếu chưa có
app.mount("/media", StaticFiles(directory="media"), name="media")

# Make sure media folder tồn tại
Path("media").mkdir(exist_ok=True)
Path("media/detections").mkdir(exist_ok=True)
Path("media/hls").mkdir(exist_ok=True)
```

### **Solution 2: Backend Endpoint Trả File URL**

```python
# backend/app/api/v1/routes_detections.py

@router.get("/detection-history/me")
async def get_detection_history(skip: int = 0, limit: int = 50):
    """Get detection history"""
    detections = db.query(Detection).filter(...).all()
    
    results = []
    for det in detections:
        results.append({
            "detection_id": det.id,
            "disease_name": det.disease_name,
            "confidence": det.confidence,
            # ✅ IMPORTANT: Trả file_url - relative path
            # Frontend sẽ convert: "/media/detections/abc.jpg" → full URL
            "file_url": det.image_path or f"/media/detections/{det.image_filename}",
            "created_at": det.created_at.isoformat(),
        })
    
    return {"items": results}
```

### **Solution 3: Frontend Kiểm Tra URL**

```dart
// frontend/mobile_web_flutter/lib/services/detection_service.dart

// Add debug logging
static String? _resolveUrl(dynamic raw) {
  if (raw == null) return null;
  final v = raw.toString();
  if (v.isEmpty) return null;
  
  if (v.startsWith('http')) {
    print('[DEBUG] Absolute URL: $v');
    return v;
  }
  
  final fullUrl = '${ApiBase.host}$v';
  print('[DEBUG] Relative URL: $v → Full: $fullUrl');
  return fullUrl;
}
```

### **Solution 4: APK Android Permissions**

```xml
<!-- android/app/src/main/AndroidManifest.xml -->

<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Nếu backend có HTTPS, thêm network security config -->
<application
    android:usesCleartextTraffic="true"
    ...>
</application>
```

### **Solution 5: Enable CORS (Nếu Cần)**

```python
# backend/app/main.py

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ← Cho phép tất cả origins (dev mode)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

---

## 📋 **Checklist**

### Video Stream
- [ ] Device có RTSP URL trong database?
- [ ] FFmpeg process đang chạy (check ps aux)?
- [ ] `/media/hls/{device_id}/` có segment files không?
- [ ] Frontend ApiBase.host đúng?

### Detection Images
- [ ] Backend trả `file_url` trong response?
- [ ] Backend mount `/media` folder?
- [ ] Image files tồn tại trong `/media/detections/`?
- [ ] Frontend `ApiBase.host` + `/media/...` = valid URL?
- [ ] Image file có permission readable?

### APK
- [ ] AndroidManifest.xml có INTERNET permission?
- [ ] APK có access được đến backend server?
- [ ] Network timeout setting đủ lâu?

---

## 🚀 **Debug Commands**

```bash
# 1. Check backend đang chạy
curl -v http://localhost:8000/docs

# 2. Check media folder
du -sh media/
ls -la media/detections/ | head

# 3. Check HLS segments
ls -la media/hls/*/

# 4. Check database
sqlite3 backend/app.db "SELECT id, name, rtsp_url FROM devices LIMIT 3;"

# 5. Check FFmpeg processes
ps aux | grep ffmpeg

# 6. Check logs
tail -f backend/logs/app.log 2>/dev/null || tail -f nohup.out
```

---

## 🎯 **Most Likely Issues (by probability)**

1. **Video:** Backend mount `/media` sai hoặc device không có RTSP URL
2. **Images:** Backend không trả `file_url` trong history response
3. **Images:** APK `ApiBase.host` sai, không match backend address
4. **Images:** Image file không được save khi detect
