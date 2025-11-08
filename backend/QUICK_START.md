# 🚀 Hướng dẫn Chạy Thử API Upload Ảnh

## ⚠️ Lưu ý quan trọng

**File model `best.onnx` cần có sẵn tại:** `ml/exports/v1.0/best.onnx`

Nếu chưa có, bạn cần:
1. Export model ONNX từ training
2. Hoặc tải model từ nguồn khác
3. Đặt vào thư mục `ml/exports/v1.0/`

## 📋 Bước 1: Kiểm tra file cần thiết

```bash
# Từ thư mục root của project
ls ml/exports/v1.0/best.onnx    # Phải có file này
ls ml/exports/v1.0/labels.txt   # Đã có sẵn
```

## 📋 Bước 2: Cấu hình Database

Tạo file `.env` trong thư mục `backend/`:

```env
DATABASE_URL=mysql+pymysql://user:password@localhost:3306/database_name
```

Thay `user`, `password`, và `database_name` bằng thông tin của bạn.

## 📋 Bước 3: Cài đặt dependencies

```bash
cd backend
pip install -r requirements.txt
```

## 📋 Bước 4: Chạy server

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Server sẽ chạy tại: **http://localhost:8000**

## 📋 Bước 5: Test API

### Cách 1: Dùng Swagger UI (Dễ nhất) ⭐

1. Mở trình duyệt: http://localhost:8000/docs
2. Tìm endpoint: `POST /api/v1/detect/upload`
3. Click **"Try it out"**
4. Click **"Choose File"** và chọn ảnh
5. Click **"Execute"**
6. Xem kết quả

### Cách 2: Dùng script Python

```bash
cd backend
python test_upload.py <đường_dẫn_ảnh>
# Ví dụ:
python test_upload.py ../test_images/pomelo_leaf.jpg
```

### Cách 3: Dùng PowerShell (Windows)

```powershell
$uri = "http://localhost:8000/api/v1/detect/upload"
$filePath = "C:\path\to\image.jpg"
$form = @{
    image = Get-Item $filePath
}
Invoke-RestMethod -Uri $uri -Method Post -Form $form
```

### Cách 4: Dùng curl (Linux/Mac)

```bash
curl -X POST http://localhost:8000/api/v1/detect/upload \
  -F "image=@/path/to/image.jpg"
```

## ✅ Response mẫu

```json
{
  "disease": "pomelo_leaf_healthy",
  "confidence": 0.9234,
  "explanation": "Kết quả phân tích cho thấy lá bưởi đang khỏe mạnh...",
  "img_id": 1,
  "detection_id": 1
}
```

## 🔍 Kiểm tra Database

Sau khi upload thành công, dữ liệu được lưu vào:
- Bảng `img`: Thông tin ảnh
- Bảng `diseases`: Thông tin bệnh (tự động tạo nếu chưa có)
- Bảng `detections`: Kết quả phân tích

## ❌ Troubleshooting

### Lỗi: "Model file not found"
- Kiểm tra file `ml/exports/v1.0/best.onnx` có tồn tại
- Kiểm tra đường dẫn trong log khi khởi động server

### Lỗi: "Database connection failed"
- Kiểm tra file `.env` có `DATABASE_URL` đúng
- Kiểm tra MySQL đang chạy
- Kiểm tra database đã được tạo

### Lỗi: "Import error"
- Chạy: `pip install -r requirements.txt`
- Kiểm tra Python version >= 3.8

### Server không khởi động được
- Kiểm tra port 8000 có đang được sử dụng
- Thử port khác: `--port 8001`

## 📝 Endpoints

- **Upload ảnh**: `POST /api/v1/detect/upload`
- **API Docs**: `GET /docs`
- **Health check**: `GET /api/v1/healthz`

