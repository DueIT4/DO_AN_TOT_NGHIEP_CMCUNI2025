# Hướng dẫn Test API Upload Ảnh

## 1. Kiểm tra trước khi chạy

### Kiểm tra file model:
```bash
# Từ thư mục backend
ls ../ml/exports/v1.0/best.onnx
ls ../ml/exports/v1.0/labels.txt
```

### Kiểm tra database:
Đảm bảo file `.env` có cấu hình:
```
DATABASE_URL=mysql+pymysql://user:password@localhost:3306/database_name
```

## 2. Chạy server

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Server sẽ chạy tại: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Health check: http://localhost:8000/api/v1/healthz

## 3. Test API

### Cách 1: Dùng script Python

```bash
cd backend
python test_upload.py <đường_dẫn_ảnh>
# Ví dụ:
python test_upload.py ../test_images/pomelo_leaf.jpg
```

### Cách 2: Dùng curl (Linux/Mac)

```bash
curl -X POST http://localhost:8000/api/v1/detect/upload \
  -F "image=@/path/to/your/image.jpg" \
  -H "Content-Type: multipart/form-data"
```

### Cách 3: Dùng PowerShell (Windows)

```powershell
$uri = "http://localhost:8000/api/v1/detect/upload"
$filePath = "C:\path\to\your\image.jpg"
$form = @{
    image = Get-Item $filePath
}
Invoke-RestMethod -Uri $uri -Method Post -Form $form
```

### Cách 4: Dùng Swagger UI

1. Mở trình duyệt: http://localhost:8000/docs
2. Tìm endpoint `POST /api/v1/detect/upload`
3. Click "Try it out"
4. Chọn file ảnh
5. Click "Execute"

## 4. Response mẫu

```json
{
  "disease": "pomelo_leaf_healthy",
  "confidence": 0.9234,
  "explanation": "Kết quả phân tích cho thấy lá bưởi đang khỏe mạnh...",
  "img_id": 1,
  "detection_id": 1
}
```

## 5. Kiểm tra database

Sau khi upload thành công, kiểm tra các bảng:
- `img`: Lưu thông tin ảnh
- `diseases`: Lưu thông tin bệnh (tự động tạo nếu chưa có)
- `detections`: Lưu kết quả phân tích

```sql
SELECT * FROM img ORDER BY created_at DESC LIMIT 1;
SELECT * FROM detections ORDER BY created_at DESC LIMIT 1;
SELECT * FROM diseases WHERE name = 'pomelo_leaf_healthy';
```

## 6. Troubleshooting

### Lỗi: Model file not found
- Kiểm tra file `ml/exports/v1.0/best.onnx` có tồn tại
- Kiểm tra đường dẫn trong `inference_service.py`

### Lỗi: Database connection failed
- Kiểm tra `.env` có `DATABASE_URL` đúng
- Kiểm tra MySQL đang chạy
- Kiểm tra database đã được tạo chưa

### Lỗi: Import error
- Cài đặt dependencies: `pip install -r requirements.txt`
- Kiểm tra Python version >= 3.8

