-- Đảm bảo dùng đúng DB
USE ai_plant_db;

-- =========================
-- 1. XÓA TOÀN BỘ CÁC BẢNG
-- =========================
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS device_logs;
DROP TABLE IF EXISTS chatbot_detail;
DROP TABLE IF EXISTS chatbot;
DROP TABLE IF EXISTS user_settings;
DROP TABLE IF EXISTS support_messages;
DROP TABLE IF EXISTS support_tickets;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS detections;
DROP TABLE IF EXISTS diseases;
DROP TABLE IF EXISTS img;
DROP TABLE IF EXISTS sensor_readings;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS device_type;
DROP TABLE IF EXISTS auth_accounts;
DROP TABLE IF EXISTS user_role;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS role;

SET FOREIGN_KEY_CHECKS = 1;

-- =========================
-- 2. TẠO LẠI TOÀN BỘ SCHEMA
-- =========================

-- 2.1 role
CREATE TABLE role (
  role_id     BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  role_type   ENUM('support','viewer','admin','support_admin') NOT NULL,
  description VARCHAR(255)
) ENGINE=InnoDB;

-- 2.2 users
CREATE TABLE users (
  user_id        BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  role_id        BIGINT UNSIGNED NOT NULL,
  username       VARCHAR(191) UNIQUE,
  email          VARCHAR(255) UNIQUE,
  phone          VARCHAR(30) UNIQUE,
  avt_url        VARCHAR(500),
  address        VARCHAR(500),
  status         ENUM('active','inactive') DEFAULT 'active',
  password       VARCHAR(255),
  failed_login   INT DEFAULT 0,
  locked         DATETIME NULL,
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_user_role_role  FOREIGN KEY (role_id) REFERENCES role(role_id)   ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.3 user_role (n-n) nếu sau này cần
CREATE TABLE user_role (
  user_role_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id      BIGINT UNSIGNED NOT NULL,
  role_id      BIGINT UNSIGNED NOT NULL,
  assigned_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_role (user_id, role_id),
  CONSTRAINT fk_user_role_user  FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
  CONSTRAINT fk_user_role_role2 FOREIGN KEY (role_id) REFERENCES role(role_id)   ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.4 auth_accounts
CREATE TABLE auth_accounts (
  auth_id          BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id          BIGINT UNSIGNED NOT NULL,
  provider         ENUM('gg','fb','sdt') NOT NULL,
  provider_user_id VARCHAR(255),
  phone_verified   TINYINT(1) DEFAULT 0,
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_auth_user (user_id),
  CONSTRAINT fk_auth_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.5 device_type
CREATE TABLE device_type (
  device_type_id   BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  device_type_name VARCHAR(255) NOT NULL UNIQUE,
  has_stream       BOOLEAN NOT NULL DEFAULT FALSE,
  status           ENUM('active','inactive') DEFAULT 'active',
  created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2.6 devices
CREATE TABLE devices (
  device_id         BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id           BIGINT UNSIGNED NULL,
  name              VARCHAR(255),
  device_type_id    BIGINT UNSIGNED NOT NULL,
  parent_device_id  BIGINT UNSIGNED NULL,
  serial_no         VARCHAR(100) UNIQUE,
  location          VARCHAR(255),
  status            ENUM('active','maintain','inactive') NOT NULL DEFAULT 'active',
  stream_url        VARCHAR(700),
  created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_device_user (user_id),
  KEY idx_device_type (device_type_id),
  KEY idx_device_parent (parent_device_id),
  CONSTRAINT fk_device_user   FOREIGN KEY (user_id)        REFERENCES users(user_id)              ON DELETE SET NULL,
  CONSTRAINT fk_device_type   FOREIGN KEY (device_type_id) REFERENCES device_type(device_type_id) ON DELETE RESTRICT,
  CONSTRAINT fk_device_parent FOREIGN KEY (parent_device_id) REFERENCES devices(device_id)        ON DELETE SET NULL
) ENGINE=InnoDB;

-- 2.7 sensor_readings
CREATE TABLE sensor_readings (
  reading_id  BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  device_id   BIGINT UNSIGNED NOT NULL,
  metric      VARCHAR(255) NOT NULL,
  value_num   DECIMAL(10,3),
  unit        VARCHAR(20),
  status      ENUM('ok','error','missing') DEFAULT 'ok',
  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_sr_device_time (device_id, recorded_at),
  CONSTRAINT fk_sr_device FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.8 img
CREATE TABLE img (
  img_id      BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  source_type ENUM('camera','upload') NOT NULL,
  device_id   BIGINT UNSIGNED NULL,
  user_id     BIGINT UNSIGNED NULL,
  file_url    VARCHAR(700) NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_img_device (device_id),
  KEY idx_img_user (user_id),
  CONSTRAINT fk_img_device FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE SET NULL,
  CONSTRAINT fk_img_user   FOREIGN KEY (user_id)   REFERENCES users(user_id)   ON DELETE SET NULL
) ENGINE=InnoDB;

-- 2.9 diseases
CREATE TABLE diseases (
  disease_id          BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  name                VARCHAR(255) UNIQUE,
  description         TEXT,
  treatment_guideline TEXT,
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2.10 detections
CREATE TABLE detections (
  detection_id        BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  img_id              BIGINT UNSIGNED NOT NULL,
  disease_id          BIGINT UNSIGNED NULL,
  confidence          DECIMAL(5,2),
  description         TEXT,
  treatment_guideline TEXT,
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  bbox                JSON,
  review_status       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  model_version       VARCHAR(255),
  KEY idx_det_img (img_id),
  KEY idx_det_dis (disease_id),
  CONSTRAINT fk_det_img FOREIGN KEY (img_id) REFERENCES img(img_id) ON DELETE CASCADE,
  CONSTRAINT fk_det_dis FOREIGN KEY (disease_id) REFERENCES diseases(disease_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 2.11 notifications
CREATE TABLE notifications (
  notification_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id         BIGINT UNSIGNED NOT NULL,
  title           VARCHAR(255) NOT NULL,
  description     TEXT,
  created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  read_at         TIMESTAMP NULL,
  KEY idx_notif_user (user_id, created_at),
  CONSTRAINT fk_notif_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.12 support_tickets
CREATE TABLE support_tickets (
  ticket_id   BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED NOT NULL,
  title       VARCHAR(255) NOT NULL,
  description TEXT,
  status      ENUM('processing','processed') DEFAULT 'processing',
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_ticket_user (user_id, created_at),
  CONSTRAINT fk_ticket_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.13 support_messages
CREATE TABLE support_messages (
  message_id     BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  ticket_id      BIGINT UNSIGNED NOT NULL,
  sender_id      BIGINT UNSIGNED NULL,
  message        TEXT,
  attachment_url VARCHAR(700),
  created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_msg_ticket (ticket_id, created_at),
  CONSTRAINT fk_msg_ticket FOREIGN KEY (ticket_id) REFERENCES support_tickets(ticket_id) ON DELETE CASCADE,
  CONSTRAINT fk_msg_sender FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 2.14 user_settings
CREATE TABLE user_settings (
  user_setting_id       BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id               BIGINT UNSIGNED NOT NULL UNIQUE,
  color                 VARCHAR(255),
  font_size             VARCHAR(255),
  language              VARCHAR(255),
  notification_enabled  BOOLEAN DEFAULT TRUE,
  auto_connect          BOOLEAN DEFAULT FALSE,
  share_data_with_ai    BOOLEAN DEFAULT TRUE,
  CONSTRAINT fk_us_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.15 chatbot
CREATE TABLE chatbot (
  chatbot_id  BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT UNSIGNED NOT NULL,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  end_at      TIMESTAMP NULL,
  status      ENUM('active','ended') DEFAULT 'active',
  KEY idx_chatbot_user (user_id, created_at),
  CONSTRAINT fk_chatbot_user FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.16 chatbot_detail
CREATE TABLE chatbot_detail (
  detail_id  BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  chatbot_id BIGINT UNSIGNED NOT NULL,
  question   TEXT,
  answer     TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_cb_detail (chatbot_id, created_at),
  CONSTRAINT fk_cb_detail FOREIGN KEY (chatbot_id) REFERENCES chatbot(chatbot_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 2.17 device_logs
CREATE TABLE device_logs (
  log_id      BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  device_id   BIGINT UNSIGNED NOT NULL,
  event_type  ENUM('online','offline','error','maintenance') NOT NULL,
  description TEXT,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY idx_log_device_time (device_id, created_at),
  CONSTRAINT fk_log_device FOREIGN KEY (device_id) REFERENCES devices(device_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ==================================
-- 3. SEED DỮ LIỆU MẶC ĐỊNH (ROLES + ADMIN)
-- ==================================

-- 3.1 Thêm 4 role chuẩn, đảm bảo admin là role_id = 1
INSERT INTO role (role_type, description) VALUES
('admin',         'Quản trị toàn hệ thống'),
('support',       'Nhân viên hỗ trợ'),
('support_admin', 'Quản lý hỗ trợ'),
('viewer',        'Người dùng thông thường');

-- 3.2 Tạo user admin (mật khẩu: admin123)
INSERT INTO users (username, email, phone, password, role_id, status)
VALUES (
  'admin',
  'admin@plantguard.com',
  '0123456789',
  'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', -- SHA256('admin123')
  1,  -- role_id = 1 (admin)
  'active'
);

-- (tuỳ chọn) nếu sau này muốn dùng login/phone cho admin và check verified thì seed thêm:
-- INSERT INTO auth_accounts (user_id, provider, provider_user_id, phone_verified)
-- SELECT user_id, 'sdt', '0123456789', 1 FROM users WHERE username = 'admin';
