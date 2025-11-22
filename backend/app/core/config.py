# app/core/config.py
import json
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # App
    APP_NAME: str = "Plant Health API"
    API_V1: str = "/api/v1"

    # ===== DB – dùng từng biến riêng, KHÔNG dùng env DATABASE_URL nữa =====
    DB_USER: str = "plantai"
    DB_PASS: str = "changeme-StrongPwd!"
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_NAME: str = "ai_plant_db"

    # Auth
    JWT_SECRET: str = "change_me"
    JWT_ALG: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""
    FB_APP_ID: str = ""
    FB_APP_SECRET: str = ""

    # CORS
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

    @property
    def DATABASE_URL(self) -> str:
        """Build URL kết nối MySQL từ DB_USER/DB_PASS/... (KHÔNG dùng env DATABASE_URL)."""
        return (
            f"mysql+pymysql://{self.DB_USER}:{self.DB_PASS}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )


settings = Settings()

# DEBUG
print(">>> DB_USER from env:", settings.DB_USER)
print(">>> Final DATABASE_URL:", settings.DATABASE_URL)
