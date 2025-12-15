# app/core/config.py
import json
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ===== App =====
    APP_NAME: str = "Plant Health API"
    API_V1: str = "/api/v1"
    DATASET_ROOT: str = "dataset"
    MEDIA_ROOT: str = "media"

    # ===== Database =====
    # Ưu tiên dùng DATABASE_URL (Neon/Postgres). Nếu không set thì fallback qua DB_*
    DATABASE_URL: Optional[str] = None

    DB_USER: str = "plantai"
    DB_PASS: str = "changeme-StrongPwd!"
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_NAME: str = "ai_plant_db"

    @property
    def db_url(self) -> str:
        # 1) Nếu có DATABASE_URL trong env → dùng luôn (Postgres/Neon)
        if self.DATABASE_URL and self.DATABASE_URL.strip():
            return self.DATABASE_URL.strip()

        # 2) Fallback: build MySQL URL (giữ để dev local nếu cần)
        return (
            f"mysql+pymysql://{self.DB_USER}:{self.DB_PASS}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )

    # ===== Auth =====
    JWT_SECRET: str = "change_me"
    JWT_ALG: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    FB_APP_ID: str = ""
    FB_APP_SECRET: str = ""

    # ===== CORS =====
    CORS_ORIGINS_RAW: str = "*"
    CORS_ORIGIN_REGEX: str = r"http://localhost:\d+|http://127\.0\.0\.1:\d+"

    @property
    def CORS_ORIGINS(self) -> List[str]:
        s = (self.CORS_ORIGINS_RAW or "").strip()
        if s in ("", "*"):
            return ["*"]
        if s.startswith("["):
            return json.loads(s)
        return [item.strip() for item in s.split(",") if item.strip()]

    # ===== Gemini LLM =====
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.5-flash"

    OPENWEATHER_API_KEY: str = ""
    OPENWEATHER_BASE_URL: str = "https://api.openweathermap.org/data/2.5"

settings = Settings()

# Debug (khuyên: chỉ bật khi dev)
print(">>> Raw DATABASE_URL from env:", settings.DATABASE_URL)
print(">>> Final DB URL used:", settings.db_url)
print(">>> GEMINI_MODEL:", settings.GEMINI_MODEL)
import os
print("DATABASE_URL =", os.getenv("DATABASE_URL"))
