from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import OperationalError, DBAPIError
from app.core.config import settings  # dùng settings.DATABASE_URL

# Tạo engine
engine = create_engine(settings.DATABASE_URL)

# Tạo session local
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Dependency cho FastAPI
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Ping DB
def ping_db() -> bool:
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except (OperationalError, DBAPIError):
        return False
