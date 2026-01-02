# 1. Chọn hệ điều hành nhẹ có sẵn Python
FROM python:3.11-slim

# 2. Cài đặt các thư viện hỗ trợ xử lý ảnh (OpenCV cần cái này)
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 3. Tạo thư mục làm việc trong server ảo
WORKDIR /app

# 4. Copy danh sách thư viện và cài đặt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy toàn bộ code từ máy bạn vào server ảo
COPY . .

# 6. Mở cổng để App có thể ra ngoài internet
ENV PORT=8080
EXPOSE 8080

# 7. Lệnh để chạy App
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]