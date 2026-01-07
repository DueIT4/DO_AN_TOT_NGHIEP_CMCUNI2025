# 📊 Luồng Hoạt Động Của Phân Tích Bệnh (Disease Detection Flow)

## 📱 Tổng Quan Hệ Thống

Hệ thống phân tích bệnh gồm **3 luồng chính**:
1. **Phân tích từ tải ảnh (Upload Flow)**
2. **Phân tích từ camera (Camera Capture Flow)**
3. **Phân tích tự động định kỳ (Auto Detection Flow)**

---

## 1️⃣ LUỒNG 1: TẢI ẢNH LÊN PHÂN TÍCH (Upload Detection)

### 📌 Quy Trình Tuần Tự:

```
[User Chooses Image] 
    ↓
[POST /api/v1/detect - Upload Image]
    ↓
[Validate File & User]
    ├─ Kiểm tra model đã load chưa
    ├─ Đọc dữ liệu file (raw bytes)
    └─ Kiểm tra hạn mức (X-Client-Key nếu guest)
    ↓
[Upload Image to Cloudinary] 
    ↓ (CloudinaryService)
    └─ Get image_url từ Cloudinary
    ↓
[YOLO Inference]
    ├─ Chạy YoloDetector.predict_bytes()
    ├─ Nhận kết quả detections_list
    ├─ Extract: class_name, confidence, bbox
    └─ num_detections ≥ 0
    ↓
[Gemini Verification - Cross-Check]
    ├─ verify_image_is_plant(raw_bytes)
    │   └─ Nếu Gemini nói "KHÔNG phải cây"
    │       └─ AND confidence < 0.98 → Hủy detections
    └─ Gemini response: is_plant (True/False)
    ↓
[Xác Định Kết Quả YOLO]
    ├─ Nếu num_detections == 0
    │   └─ explanation = "Không phát hiện bệnh"
    ├─ Nếu max_confidence < 0.4
    │   └─ LLM tóm tắt: "Ảnh không rõ, chụp lại"
    └─ Nếu max_confidence ≥ 0.4
        └─ LLM tóm tắt & tư vấn chi tiết
    ↓
[LLM Summarization]
    └─ summarize_detections_with_llm()
        ├─ disease_summary: Mô tả bệnh
        └─ care_instructions: Hướng dẫn chăm sóc
    ↓
[Lưu Kết Quả (Nếu User Đăng Nhập)]
    ├─ Create Img record
    │   ├─ source_type = "upload"
    │   ├─ file_url = image_url (Cloudinary)
    │   ├─ user_id = current_user.user_id
    │   └─ device_id = None (từ upload)
    ├─ Create Detection records (1 for each class)
    │   ├─ img_id → FK to Img
    │   ├─ disease_id → FK to Diseases
    │   ├─ confidence, bbox
    │   └─ review_status = "pending"
    └─ Commit DB
    ↓
[Trả Response cho Frontend]
    ├─ image_url (Cloudinary)
    ├─ num_detections, detections[]
    ├─ confidence, disease_name (top-1)
    ├─ disease_summary, care_instructions
    └─ saved_to_db (True/False)
```

### 🎯 Các Thành Phần Chính:

| Component | File | Chức Năng |
|-----------|------|----------|
| **API Endpoint** | `routes_detect.py` | POST /api/v1/detect |
| **Upload Service** | `cloudinary_service.py` | Upload ảnh lên cloud |
| **YOLO Inference** | `inference_service.py` | Nhận diện bệnh từ ảnh |
| **Gemini Verification** | `llm_service.py` | Cross-check ảnh hợp lệ |
| **LLM Summary** | `llm_service.py` | Tóm tắt & tư vấn từ Gemini |
| **Save Detection** | `detect_service.py` | Lưu kết quả vào DB |

### 📊 Database Schema (Upload):
```
Img (source_type = "upload")
├─ img_id (PK)
├─ source_type = "upload"
├─ file_url (from Cloudinary)
├─ user_id (FK)
├─ device_id = NULL
└─ created_at

Detection (N detection per Img)
├─ detection_id (PK)
├─ img_id (FK)
├─ disease_id (FK → Diseases)
├─ confidence
├─ bbox (JSON)
└─ review_status = "pending"
```

---

## 2️⃣ LUỒNG 2: CHỤP ẢNH TỪ CAMERA PHÂN TÍCH (Camera Capture Flow)

### 📌 Quy Trình Tuần Tự:

```
[User Taps Camera/Capture Button]
    ↓
[GET /api/v1/devices/{device_id}/capture]
    ├─ (auth required)
    └─ device_id = thiết bị camera
    ↓
[Load Device & Stream Config]
    ├─ Query Device by device_id
    ├─ Get stream_url từ device config
    └─ Validate stream_url exists
    ↓
[Capture Image from Camera Stream]
    └─ capture_image_from_stream(stream_url)
        ├─ HTTP Snapshot: GET /snapshot.jpg
        ├─ MJPEG Stream: Parse frame từ multipart stream
        ├─ RTSP: OpenCV video capture
        └─ Return: raw_bytes (JPEG)
    ↓
[Kiểm Tra Raw Bytes]
    ├─ Validate not empty
    └─ Convert to PIL Image (RGB)
    ↓
[Upload ảnh to Cloudinary]
    ├─ Folder: "zestguard/detections/2025"
    └─ Get image_url
    ↓
[YOLO Inference + Gemini Verification]
    ├─ YoloDetector.predict_bytes(raw)
    ├─ verify_image_is_plant() → Cross-check
    └─ Hủy detections nếu Gemini nói "KHÔNG phải cây"
    ↓
[LLM Summary (nếu confidence ≥ 0.4)]
    └─ disease_summary + care_instructions
    ↓
[Lưu Kết Quả vào DB]
    ├─ Create Img record
    │   ├─ source_type = "camera"
    │   ├─ device_id = device_id
    │   ├─ user_id = current_user.user_id
    │   └─ file_url = image_url
    ├─ Create Detection records
    │   ├─ img_id, disease_id, confidence
    │   └─ bbox
    └─ Create Notification (nếu phát hiện bệnh)
        ├─ type = "disease_detected"
        ├─ title = disease_name
        ├─ message = care_instructions
        └─ user_id = device owner
    ↓
[Return Response + Create Notification]
    ├─ saved_to_db = True
    ├─ img_id, detections[]
    ├─ disease_summary, confidence
    └─ notification_id (if created)
```

### 🎯 Các Thành Phần Chính:

| Component | File | Chức Năng |
|-----------|------|----------|
| **API Endpoint** | `routes_devices.py` | GET /devices/{id}/capture |
| **Camera Service** | `camera_service.py` | Lấy ảnh từ camera |
| **Stream Format Support** | `camera_service.py` | HTTP/MJPEG/RTSP/HLS |
| **YOLO + LLM** | `inference_service.py`, `llm_service.py` | Nhận diện & tóm tắt |
| **Save Detection** | `detect_service.py` | Lưu + tạo notification |

### 📊 Database Schema (Camera):
```
Device
├─ device_id (PK)
├─ stream_url
├─ name, location
└─ user_id (FK)

Img (source_type = "camera")
├─ img_id (PK)
├─ source_type = "camera"
├─ device_id (FK)
├─ user_id (FK)
├─ file_url
└─ created_at

Detection + Notifications (auto-create)
```

---

## 3️⃣ LUỒNG 3: PHÂN TÍCH TỰ ĐỘNG ĐỊNH KỲ (Auto Detection)

### 📌 Quy Trình Tuần Tự:

```
[Scheduler Trigger]
    └─ Every X minutes/hours
    ↓
[detect_from_camera_auto() - Auto Detection Service]
    ↓
[Query All Devices với Stream Enabled]
    └─ Filter: device.auto_detect = True
    ↓
[FOR EACH DEVICE:]
    ├─ Get device info: stream_url, location, name
    ├─ Capture image (giống Camera Capture Flow)
    │   └─ capture_image_from_stream(stream_url)
    ├─ Upload to Cloudinary
    ├─ YOLO Inference
    ├─ Gemini Verification
    │   └─ is_plant check
    ├─ Analyze Disease Trend (7 days history)
    │   ├─ Recent sensor readings (24h)
    │   │   ├─ soil_moisture, air_temp, humidity...
    │   │   └─ avg, min, max values
    │   ├─ Recent detections (7 days)
    │   │   └─ disease_counts, trend analysis
    │   └─ Disease history
    │       └─ increasing/stable/healthy
    ├─ Build Enhanced Prompt (LLM)
    │   ├─ Sensor context
    │   ├─ Disease history
    │   ├─ Current detections
    │   └─ Device info
    ├─ LLM Analysis (Gemini)
    │   ├─ disease_summary (kết hợp với sensor data)
    │   ├─ care_instructions (chuyên biệt)
    │   └─ Urgency level
    ├─ Lưu kết quả
    │   ├─ Img record
    │   ├─ Detection records
    │   └─ Auto-create Notification (nếu important)
    │       ├─ Type: "auto_detection" hoặc "disease_alert"
    │       ├─ Priority: URGENT/HIGH/NORMAL
    │       └─ Push FCM → User phone
    └─ Next device
    ↓
[Cleanup Old Sessions]
    └─ Delete expired HLS segments (nếu có)
```

### 🎯 Các Thành Phần Chính:

| Component | File | Chức Năng |
|-----------|------|----------|
| **Scheduler** | `scheduler_service.py` | Trigger periodic jobs |
| **Auto Detection** | `auto_detection_service.py` | Chạy detect tất cả devices |
| **Sensor Analytics** | `auto_detection_service.py` | Phân tích dữ liệu cảm biến |
| **Disease Trend** | `auto_detection_service.py` | Phân tích xu hướng bệnh |
| **Enhanced LLM** | `auto_detection_service.py` | LLM với context sensor |
| **Notifications** | `auto_detection_service.py` | Tạo & push notifications |

### 📊 Enhanced Context for Auto Detection:

```python
{
  "device_info": {
    "name": "Vườn cây bưởi A",
    "location": "Mekong Delta",
    "stream_url": "http://..."
  },
  "sensor_data": {
    "soil_moisture": {"avg": 45, "min": 30, "max": 60, "unit": "%"},
    "air_temp": {"avg": 32, "min": 28, "max": 38, "unit": "°C"},
    "humidity": {"avg": 75, "min": 65, "max": 85, "unit": "%"}
  },
  "disease_trend": {
    "most_common": "Sâu vẽ bùa",
    "trend": "increasing",
    "count": 5,
    "avg_confidence": 0.82
  },
  "current_detections": [
    {
      "class_name": "Sâu vẽ bùa",
      "confidence": 0.89,
      "bbox": [...]
    }
  ]
}
```

---

## 🔄 SO SÁNH CÁC LUỒNG

| Tiêu Chí | Upload | Camera Capture | Auto Detection |
|----------|--------|---|---|
| **Người Kích Hoạt** | User click | User click | Scheduler |
| **Source Ảnh** | Mobile upload | Device stream | Device stream |
| **Database Lưu** | ✅ Có | ✅ Có | ✅ Có |
| **LLM Context** | Chỉ YOLO result | YOLO + Device info | YOLO + Sensor + History |
| **Notification** | ❌ Không | ✅ Có | ✅ Có + Push FCM |
| **Urgency Priority** | N/A | Normal | High/Urgent (nếu cần) |

---

## 🗂️ DATABASE RELATIONSHIPS

```
Users
  ├─ (1:N) Devices
  │   ├─ (1:N) Img (camera + auto-detect)
  │   │   ├─ (1:N) Detection
  │   │   │   └─ (N:1) Disease
  │   │   └─ (1:N) DeviceLogs
  │   └─ (1:N) SensorReadings
  │
  ├─ (1:N) Img (upload)
  │   ├─ (1:N) Detection
  │   │   └─ (N:1) Disease
  │   └─ source_type = "upload"
  │
  └─ (1:N) Notifications
      ├─ img_id (FK, nullable)
      └─ device_id (FK, nullable)
```

---

## 📡 API ENDPOINTS MAP

### Upload Detection:
```
POST /api/v1/detect
├─ Input: UploadFile
├─ Auth: Optional (guest with X-Client-Key)
└─ Output: { num_detections, detections[], disease_summary, ... }
```

### Camera Capture:
```
GET /api/v1/devices/{device_id}/capture
├─ Input: device_id
├─ Auth: Required (JWT)
└─ Output: { img_id, detections[], disease_summary, ... }
```

### Camera Stream (Real-time):
```
GET /api/v1/stream/hls?mjpeg_url=...
├─ Input: MJPEG stream URL
├─ Auth: Optional
└─ Output: { hls_url, session_id }
```

### Sensor Ingest:
```
POST /api/v1/sensors
├─ Input: { serial_no, readings[] }
├─ Auth: Optional (device_token)
└─ Output: { ok, inserted, alerts }
```

---

## 🎯 KEY FEATURES

### ✅ Gemini Verification (Cross-Check):
- Xác minh ảnh có phải cây không
- Nếu không phải cây AND confidence < 0.98 → Hủy
- Tránh false positive từ logo/hình vẽ

### ✅ LLM Enhanced Prompt (Auto Detection):
- Kết hợp sensor data + disease history
- Context-aware tư vấn (không chỉ YOLO)
- Phân tích xu hướng bệnh (7 days)

### ✅ Notification System:
- Auto-push FCM cho thiết bị phát hiện bệnh
- Priority levels: URGENT/HIGH/NORMAL
- Lưu notification history trong DB

### ✅ Multi-format Stream Support:
- HTTP snapshot
- MJPEG stream
- RTSP (OpenCV)
- HLS playlist

---

## 🔐 Security & Validation

```
Upload Flow:
├─ Guest rate limit (X-Client-Key check)
├─ Gemini verify image is plant
└─ Save decision audit trail

Camera Flow:
├─ JWT auth required
├─ Device ownership verification
└─ Stream URL validation

Auto Detection:
├─ Device must have auto_detect = True
├─ Schedule throttle (prevent spam)
└─ Notification priority rules
```

---

## 📝 Ví Dụ Response Structure

### Upload Detection Response:
```json
{
  "file_name": "leaf.jpg",
  "url": "https://cloudinary.com/...",
  "num_detections": 1,
  "detections": [
    {
      "class_id": 2,
      "class_key": "pomelo_leaf_miner",
      "class_name": "Lá bưởi bị sâu vẽ bùa",
      "confidence": 0.87,
      "bbox": [100, 150, 200, 250]
    }
  ],
  "disease_name": "Lá bưởi bị sâu vẽ bùa",
  "confidence": 0.87,
  "disease_summary": "Ảnh cho thấy dấu hiệu sâu vẽ bùa...",
  "care_instructions": "Khuyến cáo: Sử dụng thuốc trừ sâu... ",
  "saved_to_db": true,
  "img": {
    "img_id": 123,
    "file_url": "https://cloudinary.com/...",
    "source_type": "web_upload"
  }
}
```

---

## 📊 Mô Tả Visual (ASCII Diagram)

```
┌─────────────────────────────────────────────────────────────┐
│              DISEASE DETECTION SYSTEM ARCHITECTURE          │
└─────────────────────────────────────────────────────────────┘

┌────────────┐     ┌────────────┐     ┌──────────────────┐
│   Mobile   │────▶│  Frontend  │────▶│   API Gateway    │
│   App      │     │   Web      │     │  (FastAPI)       │
└────────────┘     └────────────┘     └──────────────────┘
                                              │
        ┌───────────────────────────────────┬─┴─┬──────────────────┐
        │                                   │   │                  │
   ┌────▼──────┐  ┌──────────────┐  ┌──────▼──────┐  ┌────────────┐
   │  Upload   │  │  Camera      │  │  Scheduler  │  │  Ingest    │
   │  Detect   │  │  Capture     │  │  (Auto)     │  │  Sensors   │
   └────┬──────┘  └──────┬───────┘  └──────┬──────┘  └────────────┘
        │                │                 │
        └────────────┬───┴─────────────────┘
                     │
        ┌────────────▼──────────────────┐
        │  INFERENCE ENGINE             │
        ├───────────────────────────────┤
        │ 1. Camera Service             │
        │    (HTTP/MJPEG/RTSP capture)  │
        │ 2. Cloudinary Upload          │
        │ 3. YOLO Detector              │
        │ 4. Gemini Verification        │
        │ 5. LLM Summarization          │
        └────────────┬──────────────────┘
                     │
        ┌────────────▼──────────────────┐
        │  DATABASE (PostgreSQL)        │
        ├───────────────────────────────┤
        │ • Users, Devices              │
        │ • Img, Detection, Disease     │
        │ • SensorReadings, DeviceLogs  │
        │ • Notifications               │
        └───────────────────────────────┘
                     │
        ┌────────────▼──────────────────┐
        │  EXTERNAL SERVICES            │
        ├───────────────────────────────┤
        │ • Cloudinary (image storage)  │
        │ • Google Gemini (LLM)         │
        │ • Firebase (FCM push)         │
        └───────────────────────────────┘
```

---

**Đây là luồng hoạt động chi tiết để bạn vẽ sơ đồ! 🎨**
