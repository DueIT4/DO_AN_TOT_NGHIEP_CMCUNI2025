-- ================================
--  Script tạo admin user chuẩn
--  KHÔNG đổi tên DB / bảng / cột
-- ================================

-- Đảm bảo đang làm việc trên đúng DB
USE ai_plant_db;

-- 1) Đảm bảo chỉ có 1 role 'admin'
--    (xoá tất cả các bản ghi admin cũ nếu có)
DELETE FROM role
WHERE role_type = 'admin';

INSERT INTO role (role_type, description)
VALUES ('admin', 'Quản trị viên hệ thống');

-- 2) Tạo admin user
--    Mật khẩu: admin123 (đã hash SHA256)
INSERT INTO users (username, email, phone, password, role_id, status)
SELECT
  'admin'                                            AS username,
  'admin@plantguard.com'                             AS email,
  '0123456789'                                       AS phone,
  'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3' AS password,
  r.role_id                                          AS role_id,
  'active'                                           AS status
FROM role r
WHERE r.role_type = 'admin'
LIMIT 1
ON DUPLICATE KEY UPDATE 
  role_id = VALUES(role_id),
  status = 'active';

-- 3) Kiểm tra user đã được tạo
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
