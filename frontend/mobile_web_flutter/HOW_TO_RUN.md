# 🚀 Hướng dẫn Xem Trang Frontend

## Cách 1: Chạy trên Web Browser (Dễ nhất) ⭐

### Bước 1: Kiểm tra Flutter Web Support

```bash
cd frontend/mobile_web_flutter

# Bật web support
flutter config --enable-web

# Kiểm tra devices
flutter devices
```

### Bước 2: Cài đặt Dependencies

```bash
flutter pub get
```

### Bước 3: Chạy trên Chrome

```bash
# Chạy trên Chrome (tự động mở browser)
flutter run -d chrome

# Hoặc chỉ định port
flutter run -d chrome --web-port 8080
```

**Kết quả:** Trình duyệt Chrome sẽ tự động mở tại: `http://localhost:8080` (hoặc port mặc định)

---

## Cách 2: Chạy Desktop App (Windows/macOS/Linux)

### Windows

```bash
cd frontend/mobile_web_flutter

# Cài dependencies
flutter pub get

# Chạy desktop app
flutter run -d windows
```

### macOS

```bash
cd frontend/mobile_web_flutter
flutter pub get
flutter run -d macos
```

### Linux

```bash
cd frontend/mobile_web_flutter
flutter pub get
flutter run -d linux
```

---

## Cách 3: Build và Chạy Static Web

### Build Web

```bash
cd frontend/mobile_web_flutter

# Build production
flutter build web

# Files sẽ được tạo trong: build/web/
```

### Chạy Static Web Server

**Option 1: Dùng Python**

```bash
# Từ thư mục build/web
cd build/web
python -m http.server 8080

# Hoặc Python 3
python3 -m http.server 8080
```

**Option 2: Dùng Node.js (http-server)**

```bash
# Cài đặt http-server
npm install -g http-server

# Chạy
cd build/web
http-server -p 8080
```

**Option 3: Dùng VS Code Live Server**
- Mở thư mục `build/web` trong VS Code
- Click chuột phải vào `index.html` → "Open with Live Server"

---

## Cách 4: Chạy với Backend API

### Bước 1: Chạy Backend

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Bước 2: Chạy Frontend

```bash
cd frontend/mobile_web_flutter

# Chạy với API base URL
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
```

---

## Kiểm tra Devices Có Sẵn

```bash
flutter devices
```

Kết quả mẫu:
```
3 connected devices:

Chrome (chrome) • chrome • web-javascript • Google Chrome 120.0.6099.109
Windows (windows) • windows • windows-x64 • Microsoft Windows
macOS (macos) • macos • darwin-arm64 • macOS
```

---

## Troubleshooting

### Lỗi: "No devices found"
```bash
# Kiểm tra Flutter web support
flutter config --enable-web

# Kiểm tra Chrome đã cài đặt chưa
# Windows: Kiểm tra trong Start Menu
# macOS: Kiểm tra trong Applications
```

### Lỗi: "Unable to find Chrome"
- Cài đặt Google Chrome
- Hoặc dùng: `flutter run -d web-server` (chạy trên web server thay vì Chrome)

### Lỗi: "Port already in use"
```bash
# Dùng port khác
flutter run -d chrome --web-port 8081
```

### Lỗi: "Dependencies not found"
```bash
flutter clean
flutter pub get
```

### Lỗi: "Firebase not initialized"
- Kiểm tra file `lib/firebase_options.dart` có tồn tại
- Hoặc tạm thời comment phần Firebase trong `main.dart` nếu chưa cần

---

## URLs Sau Khi Chạy

- **Home page**: `http://localhost:8080/` hoặc `http://localhost:8080/#/`
- **Login**: `http://localhost:8080/#/login`
- **Admin Dashboard**: `http://localhost:8080/#/admin/dashboard` (cần đăng nhập)
- **Detect**: `http://localhost:8080/#/detect`
- **Devices**: `http://localhost:8080/#/device`

---

## Hot Reload

Khi đang chạy `flutter run`, bạn có thể:
- Nhấn `r` trong terminal → Hot reload (nhanh)
- Nhấn `R` → Hot restart (chậm hơn nhưng reset state)
- Nhấn `q` → Quit

---

## Lưu Ý

1. **Backend phải chạy** nếu frontend cần gọi API
2. **CORS**: Đảm bảo backend cho phép CORS từ frontend URL
3. **API Base URL**: Kiểm tra trong `lib/core/api_base.dart` hoặc `lib/services/api_client.dart`


