-- Tạo database & user riêng
CREATE DATABASE IF NOT EXISTS ai_plant_db
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

-- Tạo user (đổi mật khẩu cho phù hợp)
CREATE USER IF NOT EXISTS 'plantai'@'%' IDENTIFIED BY 'changeme-StrongPwd!';
GRANT ALL PRIVILEGES ON ai_plant_db.* TO 'plantai'@'%';
FLUSH PRIVILEGES;
