"""Alembic env: URL desde DATABASE_URL (mismo default que app/db.py)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from alembic import context
from sqlalchemy import create_engine

from app.db import Base
from app import models  # noqa: F401 — registra tablas en Base.metadata

config = context.config
target_metadata = Base.metadata


def _url() -> str:
    return os.getenv("DATABASE_URL", "sqlite:///./cognitiveflow.db")


def _engine_args(url: str) -> dict:
    if url.startswith("sqlite:"):
        return {"connect_args": {"check_same_thread": False}}
    return {}


def run_migrations_offline() -> None:
    context.configure(url=_url(), target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    engine = create_engine(_url(), **_engine_args(_url()))
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
