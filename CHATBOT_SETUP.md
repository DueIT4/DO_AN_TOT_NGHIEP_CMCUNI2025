# Checklist: Thiết lập Chatbot

## ✅ Đã hoàn thành
- [x] Backend API routes đã được tạo
- [x] Frontend đã được cập nhật để gọi backend API
- [x] Models và schemas đã được tạo
- [x] Service chatbot đã được tích hợp

## 🔧 Cần làm để chatbot hoạt động

### 1. Cài đặt Python packages (Backend)
```bash
cd backend
pip install google-generativeai python-dotenv
```

Hoặc cài tất cả từ requirements.txt:
```bash
pip install -r requirements.txt
```

### 2. Kiểm tra file .env (Backend)
Đảm bảo file `backend/.env` có dòng:
```
GEMINI_API_KEY=AIzaSyAP4hXZVObcOWg9cx6JWiv8_wR2JDVMMSU
```

**Lưu ý:** 
- File `.env` phải ở thư mục `backend/` (cùng cấp với `app/`)
- Không có khoảng trắng trước/sau dấu `=`
- Không có dấu ngoặc kép quanh giá trị

### 3. Kiểm tra Database
Đảm bảo các bảng đã được tạo:
- `chatbot` (lưu sessions)
- `chatbot_detail` (lưu Q&A)

Nếu chưa có, chạy migration hoặc SQL script từ `db/001_schema.sql`

### 4. Khởi động lại Backend
```bash
cd backend
uvicorn app.main:app --reload --port 8000
```

Kiểm tra log khi khởi động, bạn sẽ thấy:
```
[Chatbot] Gemini configured OK.
```

Nếu thấy lỗi:
```
[Chatbot] ❌ GEMINI_API_KEY missing! Chatbot disabled.
```
→ Kiểm tra lại file `.env`

### 5. Test API (Tùy chọn)
Mở browser: http://127.0.0.1:8000/docs

Tìm endpoint `/api/v1/chatbot/messages` và test:
- Cần đăng nhập trước (có token)
- Gửi POST với body:
```json
{
  "question": "Xin chào"
}
```

### 6. Test Frontend
- Đảm bảo đã đăng nhập (có token)
- Vào trang Home → Click "AI Chatbot"
- Gửi tin nhắn test

## 🐛 Troubleshooting

### Lỗi: "GEMINI_API_KEY missing"
- Kiểm tra file `.env` có đúng vị trí không
- Kiểm tra key có đúng format không
- Khởi động lại backend

### Lỗi: "cannot import name 'genai'"
- Chạy: `pip install google-generativeai`

### Lỗi: "Table 'chatbot' doesn't exist"
- Chạy SQL script từ `db/001_schema.sql`
- Hoặc tạo migration

### Frontend không kết nối được
- Kiểm tra backend đang chạy không
- Kiểm tra CORS settings
- Kiểm tra API base URL trong `frontend/mobile_web_flutter/lib/core/api_base.dart`

## ✅ Khi hoạt động đúng
- Backend log hiển thị: `[Chatbot] Gemini configured OK.`
- Frontend có thể gửi tin nhắn và nhận phản hồi
- Lịch sử chat được lưu vào database

