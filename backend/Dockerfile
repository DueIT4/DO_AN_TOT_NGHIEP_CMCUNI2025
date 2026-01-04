FROM python:3.11-bullseye

# Cài đặt các gói cần thiết
# Thêm libgl1 để hỗ trợ opencv-python bản thường (có GUI dependencies)
RUN apt-get update && apt-get install -y \
    wkhtmltopdf \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
# Cài đặt dependencies bình thường
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD sh -c "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"
