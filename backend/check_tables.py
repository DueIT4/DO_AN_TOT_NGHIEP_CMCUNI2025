from sqlalchemy import create_engine, text
from app.core.config import settings

engine = create_engine(settings.db_url, pool_pre_ping=True)

with engine.connect() as conn:
    tables = conn.execute(text("""
        select table_name
        from information_schema.tables
        where table_schema='public'
        order by table_name
    """)).fetchall()
    print([t[0] for t in tables])
engine = create_engine(settings.db_url, pool_pre_ping=True)

with engine.connect() as conn:
    row = conn.execute(text("select username, email, status from users where username='admin'")).fetchone()
    print(row)