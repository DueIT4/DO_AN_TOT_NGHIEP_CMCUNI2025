FROM python:3.12-slim

# Cài đặt thư viện hệ thống cần thiết cho AI và Cloudinary
# Cài đặt các thư viện hệ thống cần thiết
RUN apt-get update && apt-get install -y --no-install-recommends \
    wkhtmltopdf \
    libfontconfig1 \
    libxrender1 \
    libxext6 \
    xfonts-75dpi \
    xfonts-base \
    fontconfig \
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