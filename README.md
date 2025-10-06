# AI Plant Health Detection System

Hệ thống phát hiện bệnh cây trồng sử dụng AI với giao diện web Flutter và API FastAPI.

## 🚀 Tính năng

- **Backend**: FastAPI với ONNX model inference
- **Frontend**: Flutter web UI responsive, chuyên nghiệp
- **API**: Upload ảnh và nhận kết quả dự đoán bệnh cây
- **Model**: Hỗ trợ YOLO và các model tương tự

## 📋 Yêu cầu hệ thống

### Backend
- Python 3.8+
- pip (Python package manager)

### Frontend
- Flutter SDK 3.0+
- Chrome browser (cho web development)
- Git (để clone dependencies)

## 🛠️ Cài đặt và chạy

### 0. Cài đặt Flutter SDK (nếu chưa có)

#### Windows
```bash
# Tải Flutter SDK từ https://docs.flutter.dev/get-started/install/windows
# Giải nén vào C:\flutter (hoặc thư mục khác)

# Thêm vào PATH environment variable:
# C:\flutter\bin

# Kiểm tra cài đặt
flutter doctor
```

#### macOS
```bash
# Sử dụng Homebrew
brew install flutter

# Hoặc tải manual từ https://docs.flutter.dev/get-started/install/macos
# Thêm vào ~/.zshrc hoặc ~/.bash_profile:
# export PATH="$PATH:`pwd`/flutter/bin"

# Kiểm tra cài đặt
flutter doctor
```

#### Linux
```bash
# Tải và giải nén Flutter SDK
cd ~/development
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz
tar xf flutter_linux_3.16.0-stable.tar.xz

# Thêm vào PATH
export PATH="$PATH:`pwd`/flutter/bin"
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.bashrc

# Kiểm tra cài đặt
flutter doctor
```

**Lưu ý**: Chạy `flutter doctor` để kiểm tra và cài đặt các dependencies còn thiếu (Android Studio, VS Code extensions, etc.)

### 1. Clone repository
```bash
git clone https://github.com/DueIT4/DO_AN_TOT_NGHIEP_CMCUNI2025.git
cd ai-plant-health-separated
```

### 2. Cài đặt Backend (FastAPI)

```bash
# Di chuyển vào thư mục backend
cd backend
# Cài đặt dependencies
pip install -r requirements.txt

# Tải model ONNX (nếu chưa có)
# Đảm bảo có file: ml/exports/v1.0/best.onnx
# Đảm bảo có file: ml/exports/v1.0/labels.txt
```
**Chạy Backend:**
```bash
# Chạy server development
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Hoặc với custom model path
MODEL_PATH="path/to/your/model.onnx" LABELS_PATH="path/to/labels.txt" uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Backend sẽ chạy tại: http://localhost:8000
- API docs: http://localhost:8000/docs
- Health check: http://localhost:8000/v1/healthz

### 3. Cài đặt Frontend (Flutter Web)

```bash
# Di chuyển vào thư mục frontend
cd frontend/mobile_web_flutter

# Kiểm tra Flutter web support
flutter config --enable-web

# Cài đặt dependencies từ pubspec.yaml (đã có sẵn http, image_picker)
flutter pub get

# Kiểm tra devices có sẵn
flutter devices

# Chạy Flutter web
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000

# Hoặc chạy với hot reload
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000 --hot
```

**Lệnh Flutter hữu ích:**
```bash
# Xem tất cả devices
flutter devices

# Chạy trên web server khác
flutter run -d web-server --web-port 8080

# Build cho production
flutter build web

# Clean và rebuild
flutter clean && flutter pub get

# Kiểm tra dependencies
flutter pub deps

# Thêm dependencies mới
flutter pub add package_name

# Xóa dependencies
flutter pub remove package_name
```

**Lưu ý quan trọng**: 
- File `pubspec.yaml` đã chứa đầy đủ dependencies cần thiết (`http`, `image_picker`)
- Người clone về chỉ cần chạy `flutter pub get` là đủ, không cần `flutter pub add`
- Lệnh `flutter pub get` sẽ tự động cài đặt tất cả dependencies từ `pubspec.yaml`
- Chỉ cần chạy `flutter pub add` nếu muốn thêm package mới

**Files tự động sinh ra:**
```bash
# Khi chạy flutter pub get
.dart_tool/          # Flutter tooling cache
.packages           # Package resolution cache
pubspec.lock        # Lock file cho dependencies

# Khi chạy flutter run/build
build/              # Build artifacts
.pub-cache/         # Pub cache (global)
```

**Lệnh sinh ra files:**
- `flutter pub get` → `.dart_tool/`, `.packages`, `pubspec.lock`
- `flutter run` → `build/` folder
- `flutter build web` → `build/web/` folder

Frontend sẽ mở tại: http://localhost:5353 (hoặc port khác)

## 📁 Cấu trúc dự án

```
ai-plant-health-separated/
├── backend/                    # FastAPI backend
│   ├── app/
│   │   ├── api/v1/            # API routes
│   │   ├── core/              # Configuration
│   │   ├── services/          # Business logic
│   │   └── main.py            # FastAPI app entry
│   ├── requirements.txt       # Python dependencies
│   └── Dockerfile            # Container config
├── frontend/                   # Flutter frontend
│   └── mobile_web_flutter/
│       ├── lib/
│       │   ├── main.dart      # App entry
│       │   └── src/app.dart   # Main UI
│       └── pubspec.yaml       # Flutter dependencies
├── ml/exports/v1.0/           # Model files
│   ├── best.onnx             # ONNX model (không commit)
│   └── labels.txt            # Class labels
├── docs/                      # Documentation
└── README.md                 # Hướng dẫn này
```

## 🔧 Cấu hình

### Backend Configuration
File: `backend/app/core/config.py`
```python
# CORS origins cho phép
CORS_ORIGINS = [
    "http://localhost",
    "http://localhost:5353",
    "http://localhost:8080",
    # ... thêm origins khác
]

# Model paths (có thể override bằng env vars)
MODEL_PATH = "ml/exports/v1.0/best.onnx"
LABELS_PATH = "ml/exports/v1.0/labels.txt"
```

### Frontend Configuration
File: `frontend/mobile_web_flutter/lib/src/app.dart`
```dart
// API base URL
static const String _apiBase = String.fromEnvironment(
  'API_BASE', 
  defaultValue: 'http://localhost:8000'
);
```

## 🧪 Test API

### Sử dụng curl
```bash
# Health check
curl http://localhost:8000/v1/healthz

# Upload ảnh và dự đoán
curl -X POST http://localhost:8000/v1/detect \
  -F "image=@path/to/your/image.jpg;type=image/jpeg"
```

### Sử dụng PowerShell (Windows)
```powershell
# Health check
Invoke-WebRequest -Uri http://localhost:8000/v1/healthz

# Upload ảnh
Invoke-WebRequest -Uri http://localhost:8000/v1/detect -Method Post -Form @{ image = Get-Item 'path/to/image.jpg' }
```

## 📊 API Response

### Success Response
```json
{
  "disease": "pomelo_leaf_healthy",
  "confidence": 0.9234
}
```

### Error Response
```json
{
  "detail": "Invalid image file"
}
```

## 🐛 Troubleshooting

### Backend Issues
1. **Model not found**: Đảm bảo file `ml/exports/v1.0/best.onnx` tồn tại
2. **CORS error**: Kiểm tra `CORS_ORIGINS` trong config
3. **Inference error**: Kiểm tra model format và labels.txt

### Frontend Issues
1. **API connection failed**: Kiểm tra backend đang chạy tại port 8000
2. **Image picker not working**: Đảm bảo chạy trên HTTPS hoặc localhost
3. **Build errors**: Chạy `flutter clean && flutter pub get`
4. **Flutter not found**: Đảm bảo Flutter đã được thêm vào PATH
5. **Web support not enabled**: Chạy `flutter config --enable-web`
6. **Chrome not found**: Cài đặt Chrome browser hoặc dùng `flutter run -d web-server`
7. **Dependencies issues**: Chạy `flutter pub get` và kiểm tra `pubspec.yaml`

## 🔄 Development

### Hot Reload
- Backend: Tự động reload khi có thay đổi (--reload flag)
- Frontend: 
  - `r` trong terminal để hot reload
  - `R` để hot restart
  - `q` để quit
  - `h` để xem help

### Adding New Labels
1. Cập nhật `ml/exports/v1.0/labels.txt`
2. Restart backend
3. Labels sẽ tự động load

### Custom Model
1. Thay thế `ml/exports/v1.0/best.onnx`
2. Cập nhật `ml/exports/v1.0/labels.txt`
3. Restart backend

## 📝 License

MIT License - xem file LICENSE để biết thêm chi tiết.

## 🤝 Contributing

1. Fork repository
2. Tạo feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Tạo Pull Request

## 📞 Support

Nếu gặp vấn đề, vui lòng tạo issue trên GitHub hoặc liên hệ team phát triển.

---

**Lưu ý**: File model `best.onnx` không được commit do kích thước lớn. Người dùng cần tự tải hoặc train model riêng.
