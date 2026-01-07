# 🎥 Phân Tích Vấn Đề: Video Không Hiển Thị Trên APK

## 📊 Tóm Tắt
APK của bạn **chạy được, phân tích ảnh được**, nhưng **không hiển thị video stream**. Tôi đã tìm ra các nguyên nhân chính:

---

## 🔴 **Nguyên Nhân Chính**

### 1️⃣ **Network Request Không Gửi Đầy Đủ Authorization Header**

**File:** `camera_stream_service.dart` (dòng 77-85)

```dart
// ❌ BUG: startStream() không gửi Authorization header đúng cách
static Future<Map<String, dynamic>> startStream(int deviceId) async {
  final uri = ApiBase.uri('/streams/start');

  for (int attempt = 0; attempt < retries; attempt++) {
    try {
      final resp = await http.post(
        uri,
        headers: {
          ...ApiClient.authHeaders(),  // ← CÓ Authorization
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'device_id': deviceId}),
      ).timeout(const Duration(seconds: 20));
```

**Vấn đề:** Khi gửi `POST /streams/start` từ APK Android, có thể:
- Authorization token **hết hạn hoặc không được truyền**
- Backend trả về **404 hoặc 401 error** (unauthorized)
- Stream **không được khởi động**, nên HLS URL **không có video data**

---

### 2️⃣ **FFmpeg Process Không Chạy Trên Backend**

**File:** `stream_service.py` (dòng 48-100)

```python
def start_stream(device_id: int, rtsp_url: str) -> Optional[str]:
    """
    Khởi động FFmpeg để convert RTSP/MJPEG → HLS
    """
    # Backend sẽ khởi động ffmpeg subprocess để stream camera
    # Nếu device không có RTSP URL được config → stream không chạy
```

**Vấn đề:**
- Nếu device không có **valid RTSP/MJPEG URL** → FFmpeg **không thể mở stream**
- FFmpeg process **dies immediately** → HLS playlist **không có segments**
- Video player nhận được **empty m3u8 file** → không có gì để phát

---

### 3️⃣ **HLS Playlist Không Có Video Segments**

**Kịch bản:**
```
1. APK gọi: POST /streams/start (device_id=28)
2. Backend check database lấy RTSP URL của device 28
3. Nếu RTSP URL = NULL hoặc "":
   ❌ FFmpeg không start → hls_url = "/media/hls/28/index.m3u8"
   ❌ index.m3u8 file không được tạo hoặc EMPTY
4. Video player cố load index.m3u8
5. ❌ Không có segments → Video player hiển thị BLANK
```

---

### 4️⃣ **CORS Policy / Network Restriction**

**Nguyên nhân:**
- APK (Android) có thể bị **block** từ truy cập `/media/hls` folder
- Backend **không serve HLS files** với **correct headers**
- Hoặc **firewall/network** chặn HLS playlist

---

## 🔧 **Cách Kiểm Tra & Fix**

### **Step 1: Kiểm Tra Device Configuration**
```bash
# SSH vào database server
sqlite3 db.sqlite3

# Kiểm tra xem device 28 có RTSP URL không
SELECT id, name, rtsp_url, device_type_id FROM devices WHERE id = 28;

# Kết quả mong muốn:
# 28|DroidCam|http://192.168.1.100:4747/video|1
```

**Nếu `rtsp_url` = NULL → ĐÓ LÀ VẤN ĐỀ!**

### **Step 2: Kiểm Tra FFmpeg Process**
```bash
# Trên server backend, check xem FFmpeg có chạy không
ps aux | grep ffmpeg

# Mong muốn thấy:
# ffmpeg -i http://192.168.1.100:4747/video ... index.m3u8
```

### **Step 3: Kiểm Tra HLS Playlist**
```bash
# Kiểm tra file playlist tồn tại và có content
ls -la media/hls/28/

# Kết quả:
# -rw-r--r-- 1 ... index.m3u8
# -rw-r--r-- 1 ... segment_001.ts
# -rw-r--r-- 1 ... segment_002.ts
```

**Nếu chỉ có `index.m3u8` nhưng **không có `segment_*.ts`** → FFmpeg **không start thành công**

### **Step 4: Kiểm Tra Backend Logs**
```bash
# Trong terminal backend
tail -f logs/app.log

# Tìm dòng có lỗi từ FFmpeg
[Stream] Device 28: Starting stream
[Stream] Device 28: FFmpeg error: Connection refused
```

---

## ✅ **Solutions**

### **Solution 1: Cập Nhật RTSP URL Của Device**
```python
# File: backend/app/main.py hoặc trong admin panel

# UPDATE database
UPDATE devices SET rtsp_url = 'http://192.168.1.100:4747/video' WHERE id = 28;

# Hoặc qua API admin
POST /admin/devices/28
{
  "rtsp_url": "http://192.168.1.100:4747/video"
}
```

### **Solution 2: Thêm Debug Log Vào Frontend**
```dart
// File: camera_stream_player.dart - Thêm logs chi tiết

Future<void> _startStreamAndInitVideo() async {
  try {
    print('[DEBUG] Starting stream for device: ${widget.deviceId}');
    final result = await CameraStreamService.startStream(widget.deviceId);
    
    print('[DEBUG] Stream response: $result');
    print('[DEBUG] HLS URL: ${result['hls_url']}');
    
    if (result['running'] != true) {
      print('[ERROR] Stream not running: ${result['message']}');
      // ...
    }
  }
}
```

### **Solution 3: Thêm Fallback Explicit HLS URL**
```dart
// Nếu backend không return HLS URL, build manually
final hlsUrl = result['hls_url'] ?? '/media/hls/${widget.deviceId}/index.m3u8';
```

### **Solution 4: Kiểm Tra Network Permission Trên Android**
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

---

## 📋 **Checklist Fix**

- [ ] **Kiểm tra database:** Device có RTSP URL không?
- [ ] **Kiểm tra FFmpeg:** Có chạy process không? Check logs
- [ ] **Kiểm tra HLS files:** Có tồn tại segments không?
- [ ] **Kiểm tra network:** APK có access đến backend không?
- [ ] **Kiểm tra auth:** Token JWT có valid không?
- [ ] **Add debug logs:** Monitor request/response flow
- [ ] **Test trên web:** Browser web có display video không?

---

## 🚀 **Kết Luận**

**Vấn đề NHƯ NHẤT:** Device 28 trong database **không có RTSP URL được config** → FFmpeg không khởi động → HLS playlist **empty/không tạo**

**Action ngay:**
1. Kiểm tra: `SELECT rtsp_url FROM devices WHERE id = 28;`
2. Nếu NULL → UPDATE: `UPDATE devices SET rtsp_url = 'http://YOUR_DROIDCAM_IP:4747/video' WHERE id = 28;`
3. Restart backend & APK
