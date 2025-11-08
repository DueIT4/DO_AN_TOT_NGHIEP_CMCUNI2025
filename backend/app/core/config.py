# from pydantic_settings import BaseSettings

# class Settings(BaseSettings):
#     APP_NAME: str = "Plant Health API"
#     API_V1: str = "/v1"
#     DB_URL: str = "mysql+pymysql://root:password@localhost:3306/plantdb"
#     CORS_ORIGINS: list[str] = [
#         "http://localhost",
#         "http://localhost:5173",
#         "http://localhost:8080",
#         "http://localhost:5353",
#         "http://127.0.0.1",
#         "http://127.0.0.1:8080",
#     ]
#     # Allow any localhost port via regex (overrides list when provided)
#     CORS_ORIGIN_REGEX: str = r"http://localhost:\\d+|http://127\\.0\\.0\\.1:\\d+"
#     class Config:
#         env_file = ".env"

# settings = Settings()
from typing import List
import json
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import model_validator

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # App
    APP_NAME: str = "Plant Health API"
    API_V1: str = "/api/v1"

    # DB
    DATABASE_URL: str  # đọc từ .env
    DB_URL: str = ""  # alias cho DATABASE_URL
    
    @model_validator(mode='after')
    def set_db_url(self):
        """Set DB_URL từ DATABASE_URL nếu chưa được set."""
        if not self.DB_URL:
            self.DB_URL = self.DATABASE_URL
        return self

    # Auth
    JWT_SECRET: str = "change_me"
    JWT_ALG: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60

    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = "" 
        # Facebook OAuth
    FB_APP_ID: str = ""
    FB_APP_SECRET: str = ""


    # CORS: để dạng CHUỖI raw để tránh pydantic parse list trước
    CORS_ORIGINS_RAW: str = "*"   # ví dụ: '*', hoặc CSV, hoặc JSON array
    CORS_ORIGIN_REGEX: str = r"http://localhost:\d+|http://127\.0\.0\.1:\d+"

    # Chuyển từ chuỗi sang list dùng property
    @property
    def CORS_ORIGINS(self) -> List[str]:
        s = (self.CORS_ORIGINS_RAW or "").strip()
        if s in ("", "*"):
            return ["*"]
        if s.startswith("["):
            # JSON array
            return json.loads(s)
        # CSV
        return [item.strip() for item in s.split(",") if item.strip()]

settings = Settings()
