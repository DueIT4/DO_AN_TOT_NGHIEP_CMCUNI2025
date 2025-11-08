# Hướng dẫn sử dụng Admin Panel

## Tính năng

Ứng dụng desktop admin với giao diện đẹp, sidebar menu bên trái, bao gồm:

1. **Dashboard** - Tổng quan thống kê
2. **Quản lý người dùng** - Xem, thêm, sửa, xóa người dùng
3. **Quản lý thiết bị** - Xem, thêm, sửa, xóa thiết bị
4. **Quản lý thông báo** - Tạo và quản lý thông báo

## Cách chạy

### 1. Chạy Backend API

```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Chạy Flutter Desktop App

```bash
cd frontend/mobile_web_flutter

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### 3. Đăng nhập

1. Mở ứng dụng
2. Đăng nhập với tài khoản admin
3. Sau khi đăng nhập thành công, sẽ tự động chuyển đến `/admin/dashboard`

## Routes

- `/admin/dashboard` - Dashboard tổng quan
- `/admin/users` - Quản lý người dùng
- `/admin/devices` - Quản lý thiết bị
- `/admin/notifications` - Quản lý thông báo

## Giao diện

- **Sidebar menu bên trái**: Menu quản lý với các icon đẹp
- **Header**: Tiêu đề trang và thông tin user
- **Content area**: Nội dung chính với bảng dữ liệu và các nút thao tác

## API Integration

Tất cả các trang đã tích hợp với API thật:
- `GET /api/v1/users/` - Lấy danh sách users
- `GET /api/v1/devices/` - Lấy danh sách devices (có pagination)
- `GET /api/v1/notifications/` - Lấy danh sách notifications

## Lưu ý

- Cần đăng nhập với token hợp lệ để truy cập admin panel
- Nếu chưa đăng nhập, sẽ tự động redirect về trang login
- Tắt `USE_MOCK = false` trong `api_base.dart` để dùng API thật

