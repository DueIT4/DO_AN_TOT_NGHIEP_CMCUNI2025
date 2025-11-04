from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "AI Plant Health API"
    API_V1: str = "/api/v1"
    
from urllib.parse import quote_plus

class Settings(BaseSettings):
    APP_NAME: str = "AI Plant Health API"
    API_V1: str = "/api/v1"

    # Mã hóa mật khẩu để tránh lỗi ký tự đặc biệt
    _password = quote_plus("changeme-StrongPwd!")
    DB_URL: str = f"mysql+pymysql://plantai:{_password}@localhost:3306/ai_plant_db"

    CORS_ORIGINS: list[str] = [
        "http://localhost",
        "http://localhost:5173",
        "http://localhost:8080",
        "http://127.0.0.1:8000",
        "http://127.0.0.1:55971",
    ]

    class Config:
        env_file = ".env"

settings = Settings()
