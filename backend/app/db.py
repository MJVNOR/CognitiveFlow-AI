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


def upgrade_head() -> None:
    """Migra la DB a head (Alembic). Reemplaza a ensure_columns + create_all.

    - DB nueva: aplica 0001+0002 (crea todo).
    - DB vieja sin tabla alembic_version: sella 0001 y aplica 0002
      (añade created_at/status solo si faltan).
    - :memory: (tests): create_all directo, Alembic no aplica ahí.
    """
    if DATABASE_URL in ("sqlite://", "sqlite:///:memory:"):
        Base.metadata.create_all(bind=engine)
        return
    import os as _os

    from alembic import command
    from alembic.config import Config
    from sqlalchemy import inspect as _inspect

    backend_dir = _os.path.dirname(_os.path.dirname(os.path.abspath(__file__)))
    cfg = Config(_os.path.join(backend_dir, "alembic.ini"))
    cfg.set_main_option("script_location", _os.path.join(backend_dir, "alembic"))
    names = set(_inspect(engine).get_table_names())
    if names and "alembic_version" not in names:
        command.stamp(cfg, "0001")
    command.upgrade(cfg, "head")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
