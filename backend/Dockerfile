FROM python:3.11-bullseye

RUN apt-get update && apt-get install -y \
    wkhtmltopdf \
    fonts-liberation \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
