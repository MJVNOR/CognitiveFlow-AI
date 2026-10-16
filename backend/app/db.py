from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, sessionmaker
import os


class Base(DeclarativeBase):
    pass


DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./cognitiveflow.db")

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})

# ponytail: WAL + FK solo en sqlite file, skip para :memory: en tests
@event.listens_for(engine, "connect")
def _sqlite_pragmas(dbapi_conn, _):
    try:
        cur = dbapi_conn.cursor()
        cur.execute("PRAGMA foreign_keys=ON")
        cur.execute("PRAGMA journal_mode=WAL")
        cur.close()
    except Exception:
        pass

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def ensure_columns() -> None:
    """P7.2: añade columnas nuevas a DBs existentes sin borrar datos (sin Alembic)."""
    from sqlalchemy import inspect, text

    insp = inspect(engine)
    if insp.has_table("auth_tokens"):
        cols = [c["name"] for c in insp.get_columns("auth_tokens")]
        if "created_at" not in cols:
            with engine.begin() as conn:
                conn.execute(text("ALTER TABLE auth_tokens ADD COLUMN created_at INTEGER DEFAULT 0"))


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
