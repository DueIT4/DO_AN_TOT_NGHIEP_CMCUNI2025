-- Script tạo admin user
-- Sử dụng: mysql -u root -p your_database < create_admin_user.sql

-- Tìm hoặc tạo role admin (nếu chưa có)
INSERT INTO role (role_type, description)
VALUES ('admin', 'Quản trị viên hệ thống')
ON DUPLICATE KEY UPDATE description = 'Quản trị viên hệ thống';

-- Tạo admin user
-- Mật khẩu: admin123 (SHA256 hash)
-- ⚠️ NHỚ ĐỔI MẬT KHẨU SAU KHI ĐĂNG NHẬP!
INSERT INTO users (username, email, phone, password, role_id, status)
VALUES (
  'admin',
  'admin@plantguard.com',
  '0123456789',
  'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3',  -- SHA256('admin123')
  (SELECT role_id FROM role WHERE role_type = 'admin'),
  'active'
)
ON DUPLICATE KEY UPDATE 
  role_id = (SELECT role_id FROM role WHERE role_type = 'admin'),
  status = 'active';

-- Kiểm tra user đã được tạo
SELECT 
  u.user_id,
  u.username,
  u.email,
  u.phone,
  r.role_type,
  u.status
FROM users u
JOIN role r ON u.role_id = r.role_id
WHERE u.username = 'admin';

