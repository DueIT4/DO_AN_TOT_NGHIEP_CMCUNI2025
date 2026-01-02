FROM python:3.12-slim

# Cài đặt thư viện hệ thống cho OpenCV/AI
RUN apt-get update && apt-get install -y \
    libgl1 \
    libglib2.0-0 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*
# ... (Các phần trên giữ nguyên)
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install -r requirements.txt

COPY backend/ .
# Copy cả model và labels vào cùng một cấu trúc
RUN mkdir -p ml/exports/v1.0
COPY ../ml/exports/v1.0/best.pt ./ml/exports/v1.0/
COPY ../ml/exports/v1.0/labels.txt ./ml/exports/v1.0/ 

ENV PYTHONPATH=/app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]