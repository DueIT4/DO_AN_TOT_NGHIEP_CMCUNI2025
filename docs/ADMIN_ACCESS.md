# Hướng dẫn truy cập Admin Panel

## Cách truy cập Admin

### 1. Qua giao diện Web

**Bước 1: Tạo tài khoản Admin** (nếu chưa có)
- Xem phần "Cách tạo tài khoản Admin" bên dưới

**Bước 2: Đăng nhập**
- Truy cập trang đăng nhập: `http://localhost:8080/login`
- Đăng nhập bằng email/phone và password của tài khoản admin

**Bước 3: Truy cập Admin Panel**
- Sau khi đăng nhập, nút **"Admin"** màu tím sẽ xuất hiện trong thanh navbar (chỉ hiện khi bạn là admin)
- Nhấn nút **"Admin"** để vào trang quản trị
- Hoặc truy cập trực tiếp URL: `http://localhost:8080/admin`

### 2. Truy cập trực tiếp URL

Nếu bạn đã đăng nhập, có thể truy cập trực tiếp:
- `/admin` - Dashboard tổng quan (Quản lý thiết bị)
- `/admin/users` - Quản lý người dùng
- `/admin/notifications` - Quản lý thông báo

⚠️ **Lưu ý:** Nếu chưa đăng nhập, hệ thống sẽ tự động chuyển hướng về trang đăng nhập.

## Yêu cầu quyền truy cập

### Roles có quyền truy cập Admin:
- **admin**: Quyền đầy đủ (toàn bộ chức năng)
- **support_admin**: Quyền quản lý user, devices, notifications (không có quyền hỗ trợ khách hàng)

### Roles không có quyền:
- **viewer**: Chỉ xem/chỉnh sửa thông tin cá nhân
- **support**: Chỉ có quyền hỗ trợ khách hàng

## Cách tạo tài khoản Admin

### Cách 1: Tạo trực tiếp trong database

1. Kết nối database MySQL
2. Tìm role_id của role "admin":
```sql
SELECT role_id FROM role WHERE role_type = 'admin';
```

3. Tạo user mới với role admin:
```sql
INSERT INTO users (username, email, phone, password, role_id, status)
VALUES (
  'admin_user',
  'admin@example.com',
  '0123456789',
  SHA2('your_password', 256),  -- Hash password bằng SHA256
  (SELECT role_id FROM role WHERE role_type = 'admin'),
  'active'
);
```

### Cách 2: Sử dụng API (nếu bạn đã là admin)

1. Đăng nhập với tài khoản admin hiện có
2. Truy cập `/admin/users`
3. Tạo user mới và chọn role "admin"

### Cách 3: Cập nhật user hiện có thành admin

1. Tìm user_id của user cần nâng cấp:
```sql
SELECT user_id, username FROM users WHERE username = 'your_username';
```

2. Cập nhật role_id:
```sql
UPDATE users 
SET role_id = (SELECT role_id FROM role WHERE role_type = 'admin')
WHERE user_id = <user_id>;
```

## Kiểm tra quyền Admin

### Kiểm tra qua API:
```bash
# Lấy thông tin user hiện tại
curl -X GET http://localhost:8000/api/v1/me/get_me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

Response sẽ chứa `role_type`: `"admin"` hoặc `"support_admin"`

### Kiểm tra trong database:
```sql
SELECT u.username, u.email, r.role_type
FROM users u
JOIN role r ON u.role_id = r.role_id
WHERE r.role_type IN ('admin', 'support_admin');
```

## Xử lý lỗi

### Lỗi: "Không đủ quyền" (403)
- Kiểm tra user có role admin hoặc support_admin không
- Kiểm tra token còn hợp lệ không
- Đăng nhập lại nếu cần

### Lỗi: "Thiếu hoặc sai Authorization header" (401)
- Kiểm tra đã đăng nhập chưa
- Kiểm tra token có đúng format không: `Bearer <token>`
- Đăng nhập lại để lấy token mới

### Nút Admin không hiển thị
- Đảm bảo đã đăng nhập
- Kiểm tra user có role admin hoặc support_admin
- Refresh trang để cập nhật trạng thái

## Bảo mật

⚠️ **Lưu ý quan trọng:**
- Không chia sẻ tài khoản admin
- Sử dụng mật khẩu mạnh
- Thay đổi mật khẩu định kỳ
- Logout sau khi sử dụng xong
- Chỉ cấp quyền admin cho người đáng tin cậy

## Script tạo Admin nhanh

Sử dụng script có sẵn trong `db/create_admin_user.sql`:

```bash
mysql -u root -p your_database < db/create_admin_user.sql
```

Hoặc chạy trực tiếp trong MySQL:
```sql
-- Xem file db/create_admin_user.sql
```

Sau khi tạo admin user, đăng nhập với:
- Email/Phone: `admin@plantguard.com` hoặc `0123456789`
- Password: `admin123`
- ⚠️ **Nhớ đổi mật khẩu ngay sau khi đăng nhập!**

## Tóm tắt nhanh

1. **Tạo admin user**: Chạy script `db/create_admin_user.sql`
2. **Đăng nhập**: Vào `/login` và đăng nhập bằng email/phone và password
3. **Truy cập admin**: Nhấn nút **"Admin"** trong navbar hoặc vào `/admin`
4. **Các trang admin**:
   - `/admin` - Quản lý thiết bị
   - `/admin/users` - Quản lý người dùng
   - `/admin/notifications` - Quản lý thông báo

