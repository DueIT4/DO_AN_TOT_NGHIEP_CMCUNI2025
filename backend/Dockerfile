FROM python:3.12-slim

# Cài đặt thư viện hệ thống cần thiết cho AI và Cloudinary
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    fontconfig \
    libfontconfig1 \
    libxrender1 \
    libxext6 \
    xfonts-75dpi \
    xfonts-base \
    && curl -L https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_amd64.deb -o /tmp/wkhtml.deb \
    && apt-get install -y /tmp/wkhtml.deb \
    && rm /tmp/wkhtml.deb \
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