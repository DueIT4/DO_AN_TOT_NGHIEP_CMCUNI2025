from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_NAME: str = "Plant Health API"
    API_V1: str = "/v1"
    DB_URL: str = "mysql+pymysql://root:password@localhost:3306/plantdb"
    CORS_ORIGINS: list[str] = [
        "http://localhost",
        "http://localhost:5173",
        "http://localhost:8080",
        "http://localhost:5353",
        "http://127.0.0.1",
        "http://127.0.0.1:8080",
    ]
    # Allow any localhost port via regex (overrides list when provided)
    CORS_ORIGIN_REGEX: str = r"http://localhost:\\d+|http://127\\.0\\.0\\.1:\\d+"
    class Config:
        env_file = ".env"

settings = Settings()
