# Stage 1: Tải và chuẩn bị wkhtmltopdf
FROM alpine:latest as builder
RUN apk add --no-cache wget xz
RUN wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.generic.amd64.tar.xz \
    && tar -xf wkhtmltox_0.12.6-1.generic.amd64.tar.xz

# Stage 2: Bản chạy chính thức
FROM python:3.12-slim

# Chỉ cài đặt các thư viện cực kỳ cơ bản cho OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy file đã chuẩn bị từ Stage 1 sang (Không tốn thời gian tải lại)
COPY --from=builder /wkhtmltox/bin/wkhtmltopdf /usr/local/bin/wkhtmltopdf

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV PYTHONPATH=/app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]