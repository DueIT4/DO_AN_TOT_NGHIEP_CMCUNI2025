FROM python:3.11-slim-bullseye

# Cài đặt các gói cần thiết
RUN apt-get update && apt-get install -y \
    wkhtmltopdf \
    fonts-liberation \
    libssl-dev \
    ffmpeg \
    libsm6 \
    libxext6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD sh -c "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"
