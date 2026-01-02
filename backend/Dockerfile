FROM python:3.12-slim

# Cài đặt thư viện hệ thống cần thiết cho AI và Cloudinary
FROM python:3.12-slim

# Cài đặt tối thiểu các thư viện cơ bản cho OpenCV và tải file
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    xz-utils \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Tải bản wkhtmltopdf tĩnh (không phụ thuộc vào thư viện hệ thống)
RUN wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.generic.amd64.tar.xz \
    && tar -xf wkhtmltox_0.12.6-1.generic.amd64.tar.xz \
    && cp wkhtmltox/bin/wkhtmltopdf /usr/local/bin/ \
    && rm -rf wkhtmltox* wkhtmltox_0.12.6-1.generic.amd64.tar.xz
WORKDIR /app

# Copy và cài đặt thư viện
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy toàn bộ code backend
COPY . .

ENV PYTHONPATH=/app

# Khởi chạy ứng dụng
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]