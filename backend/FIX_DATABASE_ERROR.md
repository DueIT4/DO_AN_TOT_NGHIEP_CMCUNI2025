# 🔧 Sửa lỗi "Missing Database"

## Vấn đề
Lỗi "missing database" hoặc "DATABASE_URL not found" xảy ra khi:
1. File `.env` không tồn tại
2. File `.env` thiếu biến `DATABASE_URL`
3. Database chưa được tạo

## Giải pháp

### Bước 1: Tạo file .env

Tạo file `.env` trong thư mục `backend/`:

**Windows (PowerShell):**
```powershell
cd backend
Copy-Item .env.example .env
# Sau đó mở file .env và chỉnh sửa
```

**Hoặc tạo thủ công:**
Tạo file `backend/.env` với nội dung:

```env
DATABASE_URL=mysql+pymysql://root:password@localhost:3306/ai_plant_db
JWT_SECRET=change_me_to_a_secure_random_string
CORS_ORIGINS_RAW=*
```

**⚠️ QUAN TRỌNG:** Thay đổi:
- `root` → username MySQL của bạn
- `password` → password MySQL của bạn
- `ai_plant_db` → tên database (có thể dùng tên khác)

### Bước 2: Tạo Database

#### Cách 1: Dùng MySQL Command Line

```bash
# Đăng nhập MySQL
mysql -u root -p

# Chạy các lệnh sau:
CREATE DATABASE IF NOT EXISTS ai_plant_db 
  DEFAULT CHARACTER SET utf8mb4 
  DEFAULT COLLATE utf8mb4_unicode_ci;

# Tạo user (tùy chọn)
CREATE USER IF NOT EXISTS 'plantai'@'%' IDENTIFIED BY 'changeme-StrongPwd!';
GRANT ALL PRIVILEGES ON ai_plant_db.* TO 'plantai'@'%';
FLUSH PRIVILEGES;

# Thoát
exit;
```

#### Cách 2: Chạy script SQL

```bash
# Tạo database và user
mysql -u root -p < db/000_create_database.sql

# Tạo tables
mysql -u root -p ai_plant_db < db/001_schema.sql
```

### Bước 3: Kiểm tra

1. **Kiểm tra file .env:**
   ```bash
   cd backend
   # Windows
   type .env
   # Linux/Mac
   cat .env
   ```

2. **Kiểm tra MySQL đang chạy:**
   ```bash
   # Windows
   net start MySQL80
   # Hoặc kiểm tra trong Services
   ```

3. **Test kết nối:**
   ```bash
   cd backend
   python -c "from app.core.config import settings; print(settings.DATABASE_URL)"
   ```

4. **Chạy server:**
   ```bash
   uvicorn app.main:app --reload
   ```

   Nếu thấy lỗi kết nối, kiểm tra lại username/password trong `.env`

### Bước 4: Test API

Truy cập: http://localhost:8000/api/v1/healthz

Nếu trả về `{"status": "ok"}` → Database đã kết nối thành công! ✅

## Lỗi thường gặp

### "DATABASE_URL not found"
- ✅ Tạo file `.env` trong `backend/`
- ✅ Đảm bảo có dòng `DATABASE_URL=...`

### "Access denied for user"
- ✅ Kiểm tra username/password đúng
- ✅ Kiểm tra user có quyền truy cập database

### "Unknown database 'ai_plant_db'"
- ✅ Chạy: `mysql -u root -p < db/000_create_database.sql`
- ✅ Hoặc tạo database thủ công

### "Table doesn't exist"
- ✅ Chạy: `mysql -u root -p ai_plant_db < db/001_schema.sql`

## Ví dụ file .env hoàn chỉnh

```env
# Database - dùng root
DATABASE_URL=mysql+pymysql://root:your_password@localhost:3306/ai_plant_db

# Database - dùng user riêng (nếu đã tạo)
# DATABASE_URL=mysql+pymysql://plantai:changeme-StrongPwd!@localhost:3306/ai_plant_db

JWT_SECRET=my_super_secret_key_12345
CORS_ORIGINS_RAW=*
```

