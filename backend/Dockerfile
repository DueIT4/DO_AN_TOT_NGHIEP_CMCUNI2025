FROM python:3.12-slim

# Cài đặt thư viện hệ thống cần thiết cho AI và Cloudinary
RUN apt-get update && apt-get install -y \
    wkhtmltopdf \
    xfonts-75dpi \
    xfonts-base \
    libssl-dev \
    # Thêm font tiếng Việt để PDF không bị lỗi font
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Copy và cài đặt thư viện
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy toàn bộ code backend
COPY . .

ENV PYTHONPATH=/app

# Khởi chạy ứng dụng
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]