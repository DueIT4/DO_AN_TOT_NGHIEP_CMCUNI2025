# Hướng dẫn Setup Database

## Bước 1: Tạo file .env

Tạo file `.env` trong thư mục `backend/` với nội dung:

```env
DATABASE_URL=mysql+pymysql://root:password@localhost:3306/plantdb
JWT_SECRET=your_secret_key_here
CORS_ORIGINS_RAW=*
```

**Lưu ý:** Thay đổi:
- `root` → username MySQL của bạn
- `password` → password MySQL của bạn  
- `plantdb` → tên database của bạn (hoặc tên khác nếu muốn)

## Bước 2: Tạo Database

### Cách 1: Sử dụng MySQL Command Line

```bash
# Đăng nhập MySQL
mysql -u root -p

# Tạo database
CREATE DATABASE IF NOT EXISTS plantdb 
  DEFAULT CHARACTER SET utf8mb4 
  DEFAULT COLLATE utf8mb4_unicode_ci;

# Thoát
exit;
```

### Cách 2: Chạy script SQL

```bash
# Tạo database
mysql -u root -p < db/000_create_database.sql

# Tạo tables
mysql -u root -p plantdb < db/001_schema.sql
```

## Bước 3: Kiểm tra kết nối

Chạy backend và kiểm tra log:

```bash
cd backend
uvicorn app.main:app --reload
```

Nếu thấy lỗi kết nối database, kiểm tra:
1. MySQL đang chạy
2. Username/password trong `.env` đúng
3. Database đã được tạo
4. Port 3306 không bị chặn

## Bước 4: Test kết nối

Truy cập: http://localhost:8000/api/v1/healthz

Nếu trả về `{"status": "ok"}` thì database đã kết nối thành công.

## Troubleshooting

### Lỗi: "DATABASE_URL not found"
- Kiểm tra file `.env` có tồn tại trong `backend/`
- Kiểm tra `DATABASE_URL` có trong file `.env`

### Lỗi: "Access denied for user"
- Kiểm tra username/password MySQL
- Kiểm tra user có quyền truy cập database

### Lỗi: "Unknown database"
- Chạy script tạo database: `mysql -u root -p < db/000_create_database.sql`
- Hoặc tạo database thủ công

### Lỗi: "Table doesn't exist"
- Chạy script tạo tables: `mysql -u root -p plantdb < db/001_schema.sql`

