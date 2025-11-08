# app/core/config.py
from pydantic_settings import BaseSettings
from typing import List, Optional

class Settings(BaseSettings):
    APP_NAME: str = "AI Plant Health API"
    API_V1: str = "/api/v1"

    DB_URL: str = "mysql+pymysql://root:password@localhost:3306/plantdb"

    # LLM
    GEMINI_API_KEY: Optional[str] = None
    GEMINI_MODEL: str = "gemini-1.5-flash"

    # CORS: pydantic sẽ parse JSON array trong .env
    CORS_ORIGINS: List[str] = ["http://localhost"]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
