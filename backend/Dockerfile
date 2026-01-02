FROM python:3.12-slim

# Cài đặt thư viện hệ thống cần thiết cho AI và Cloudinary
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    xz-utils \
    libxrender1 \
    libxext6 \
    libfontconfig1 \
    libfontconfig \
    fontconfig \
    # Các thư viện bổ sung cho OpenCV và AI
    libgl1-mesa-glx \
    libglib2.0-0 \
    && wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.generic.amd64.tar.xz \
    && tar -xf wkhtmltox_0.12.6-1.generic.amd64.tar.xz \
    && cp wkhtmltox/bin/wkhtmltopdf /usr/local/bin/ \
    && rm -rf wkhtmltox* \
    && apt-get clean \
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