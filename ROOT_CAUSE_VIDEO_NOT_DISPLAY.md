# 🔍 Nguyên Nhân Video Không Hiển Thị Khi Auto-Detection Chạy

## 📋 **Tóm Tắt Vấn Đề**

Dựa trên thông tin bạn cung cấp:

> 1. **Video và detection đổi từ manual thành auto** - Tự động kết nối camera và chụp theo lịch
> 2. **Khi auto-detection chạy** → Video stream **không hiển thị**, chỉ thấy **loading**
> 3. **Sau khi auto-detection xong** → Video **mới hiển thị** trở lại

---

## 🔴 **Nguyên Nhân Chính**

### **RTSP Stream Conflict - Chỉ 1 Process Có Thể Đọc RTSP Cùng Lúc**

**File:** `camera_service.py` (dòng 118-160)

```python
def _capture_from_rtsp(rtsp_url: str, timeout: int = 10) -> Optional[bytes]:
    """Lấy ảnh từ RTSP stream bằng OpenCV."""
    
    # ❌ OpenCV mở kết nối RTSP độc quyền
    cap = cv2.VideoCapture(rtsp_url, cv2.CAP_FFMPEG)
    
    # ❌ Khi capture_multiple_images() chạy:
    # - OpenCV chiếm RTSP stream
    # - FFmpeg (HLS streaming) KHÔNG thể đọc cùng lúc
    # - Video player → Loading mãi vì HLS segments không được tạo
```

**File:** `auto_detection_service.py` (dòng 184-194)

```python
def detect_from_camera_auto(...):
    # ❌ Scheduler gọi hàm này theo lịch (VD: 2 lần/ngày)
    
    images = capture_multiple_images(
        device.stream_url,  # ← RTSP URL
        count=num_images,   # ← Lấy 3 ảnh
        interval=1.0,       # ← Cách nhau 1 giây
        device_id=None,     # ← NULL → Bắt buộc dùng RTSP
    )
    # ❌ OpenCV chiếm RTSP trong ~3-5 giây
    # → FFmpeg (HLS streaming) bị BLOCK
    # → Video player không nhận được segments mới
```

---

## 🔬 **Chi Tiết Kỹ Thuật**

### **Timeline Conflict:**

```
T=0s:  User mở app → Video player bắt đầu load
       Frontend gọi: POST /streams/start (device_id)
       Backend start FFmpeg: rtsp://... → /media/hls/{id}/index.m3u8
       
T=1s:  FFmpeg đang đọc RTSP stream
       HLS segments được tạo: segment_001.ts, segment_002.ts
       Video player hiển thị video ✅

T=60s: Auto-Detection Scheduler triggers
       ❌ OpenCV chiếm RTSP: cap = cv2.VideoCapture(rtsp_url)
       ❌ FFmpeg KHÔNG ĐỌC ĐƯỢC RTSP → segments KHÔNG được update
       
T=61s: Video player cố load segment mới
       ❌ segment_003.ts KHÔNG tồn tại (FFmpeg bị block)
       → Video player: LOADING... 🔄

T=62s: OpenCV capture ảnh thứ 2
       FFmpeg vẫn bị block

T=63s: OpenCV capture ảnh thứ 3
       FFmpeg vẫn bị block
       
T=64s: OpenCV release stream
       ✅ FFmpeg connect lại RTSP
       ✅ HLS segments tiếp tục được tạo
       
T=65s: Video player nhận segments mới → Video hiển thị trở lại ✅
```

---

## 🧩 **Vì Sao Xảy Ra?**

### **1. RTSP Protocol Limitation**

```
RTSP (Real-Time Streaming Protocol):
- Designed cho 1-to-1 connection
- Camera chỉ cho phép 1 client đọc stream
- Khi OpenCV connect → FFmpeg bị disconnect
- Khi OpenCV disconnect → FFmpeg reconnect (mất 1-2s)
```

### **2. Code Flow:**

**Khi User Xem Video:**
```python
# routes_streams.py
@router.post("/start")
def start_stream(payload: StartStreamIn):
    # Start FFmpeg
    hls = stream_service.start_stream(device_id, rtsp_url)
    # FFmpeg process: rtsp://... → HLS segments
    return {"hls_url": hls, "running": True}
```

**Khi Auto-Detection Chạy:**
```python
# auto_detection_service.py
def detect_from_camera_auto(db, device):
    # Scheduler triggers → Lấy ảnh từ RTSP
    images = capture_multiple_images(
        device.stream_url,  # ← RTSP URL trực tiếp
        count=3,
        interval=1.0,
        device_id=None,  # ❌ NULL → Không dùng HLS fallback
    )
    # ❌ OpenCV chiếm RTSP 3-5 giây
```

### **3. `device_id=None` Là Lỗi Chính**

**File:** `auto_detection_service.py` (dòng 188)

```python
images = capture_multiple_images(
    device.stream_url,
    count=num_images,
    interval=1.0,
    device_id=None,  # ❌ SAI: Nên truyền device.device_id
)
```

**File:** `camera_service.py` (dòng 224-231)

```python
def capture_multiple_images(..., device_id: Optional[int] = None):
    for i in range(count):
        img_data = None

        if device_id is not None:
            # ✅ Nếu có device_id → Lấy từ HLS (không conflict)
            img_data = _capture_image_from_hls(device_id)

        if img_data is None:
            # ❌ Fallback: Lấy từ RTSP trực tiếp (conflict với FFmpeg)
            img_data = capture_image_from_stream(stream_url)
```

**Nếu truyền `device_id`:**
- ✅ Hàm sẽ lấy frame từ **HLS segments** (file `.ts`) đã có
- ✅ KHÔNG conflict với FFmpeg
- ✅ Video stream vẫn chạy bình thường

**Nếu `device_id=None` (hiện tại):**
- ❌ Bắt buộc lấy từ **RTSP trực tiếp**
- ❌ Conflict với FFmpeg
- ❌ Video stream bị gián đoạn

---

## ✅ **Solution: Fix Auto-Detection**

### **Fix 1: Truyền `device_id` Vào `capture_multiple_images()`**

**File:** `backend/app/services/auto_detection_service.py` (dòng 184-190)

```python
# ❌ BEFORE:
images = capture_multiple_images(
    device.stream_url,
    count=num_images,
    interval=1.0,
    device_id=None,  # ← SAI
)

# ✅ AFTER:
images = capture_multiple_images(
    device.stream_url,
    count=num_images,
    interval=1.0,
    device_id=device.device_id,  # ← FIX: Dùng HLS thay vì RTSP
)
```

**Giải thích:**
- Khi truyền `device_id` → `capture_multiple_images()` sẽ:
  1. Kiểm tra HLS folder: `/media/hls/{device_id}/`
  2. Lấy segment file mới nhất: `segment_XXX.ts`
  3. Extract frame từ segment (không touch RTSP)
  4. → **KHÔNG conflict** với FFmpeg stream

---

### **Fix 2: Ensure HLS Stream Is Running Before Auto-Detection**

**File:** `backend/app/services/auto_detection_service.py`

Thêm check stream status trước khi capture:

```python
def detect_from_camera_auto(...):
    # ✅ NEW: Start stream nếu chưa chạy
    from app.services import stream_service
    
    if not stream_service.is_running(device.device_id):
        logger.info(f"[AutoDetection] Starting stream for device {device.device_id}")
        hls_url = stream_service.start_stream(device.device_id, device.stream_url)
        if not hls_url:
            return {'success': False, 'error': 'Không thể start stream'}
        
        # Wait for segments to be created
        import time
        time.sleep(3)  # Đợi FFmpeg tạo segments
    
    # ✅ Lấy ảnh từ HLS (không conflict)
    images = capture_multiple_images(
        device.stream_url,
        count=num_images,
        interval=1.0,
        device_id=device.device_id,  # ← FIX
    )
```

---

## 🧪 **Test & Verify**

### **Test 1: Auto-Detection Không Làm Gián Đoạn Video**

```bash
# Terminal 1: Start backend
cd backend
uvicorn app.main:app --reload

# Terminal 2: Monitor HLS folder
watch -n 1 "ls -lh media/hls/YOUR_DEVICE_ID/"

# Terminal 3: Trigger auto-detection manually
curl -X POST "http://localhost:8000/api/v1/devices/YOUR_DEVICE_ID/detect-auto" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Expected:
# - HLS segments vẫn được tạo liên tục
# - Không có gap trong segment numbers
# - Video stream không bị gián đoạn
```

### **Test 2: Video Player Không Loading**

```
1. Mở app → Xem video stream
2. Trigger auto-detection (manual hoặc đợi scheduler)
3. ✅ Video vẫn chạy bình thường (không loading)
4. ✅ Detection results được lưu trong history
```

---

## 📊 **Impact Analysis**

### **Trước Fix:**

| Thời gian | FFmpeg | OpenCV | Video Player | User Experience |
|-----------|--------|--------|--------------|-----------------|
| 0-60s | ✅ Streaming | ❌ Idle | ✅ Video hiển thị | OK |
| 60-65s | ❌ BLOCKED | ✅ Capturing | ❌ Loading... | **BAD** |
| 65s+ | ✅ Streaming | ❌ Idle | ✅ Video hiển thị | OK |

### **Sau Fix:**

| Thời gian | FFmpeg | OpenCV | Video Player | User Experience |
|-----------|--------|--------|--------------|-----------------|
| 0-60s | ✅ Streaming | ❌ Idle | ✅ Video hiển thị | OK |
| 60-65s | ✅ Streaming | ✅ Reading HLS | ✅ Video hiển thị | **PERFECT** |
| 65s+ | ✅ Streaming | ❌ Idle | ✅ Video hiển thị | OK |

---

## 🎯 **Summary**

### **Root Cause:**
```
Auto-Detection chiếm RTSP stream
→ FFmpeg (HLS streaming) bị block
→ Video segments không được tạo
→ Video player loading mãi
```

### **Solution:**
```
Truyền device_id vào capture_multiple_images()
→ Lấy frame từ HLS segments thay vì RTSP
→ Không conflict với FFmpeg
→ Video stream chạy liên tục
```

### **Code Change:**
```python
# ❌ BEFORE:
device_id=None

# ✅ AFTER:
device_id=device.device_id
```

**Chỉ cần thay 1 dòng code là fix xong! 🚀**
