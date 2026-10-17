"""Columnas añadidas tras el baseline (DBs viejas sin ensure_columns).

Reemplaza a app/db.ensure_columns: idempotente (solo añade si falta),
para DBs ya parcheadas a mano y para frescas (0001 ya las trae).

Revision ID: 0002
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy import inspect

revision: str = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def _missing(table: str, column: str) -> bool:
    bind = op.get_bind()
    cols = [c["name"] for c in inspect(bind).get_columns(table)]
    return column not in cols


def upgrade() -> None:
    # ponytail: tolerante — la DB puede venir de create_all nuevo (ya tiene
    # la columna) o de un sqlite viejo (falta). Solo añade si falta.
    if _missing("auth_tokens", "created_at"):
        op.add_column("auth_tokens",
                      sa.Column("created_at", sa.Integer(), server_default="0"))
    if _missing("learning_objectives", "status"):
        op.add_column("learning_objectives",
                      sa.Column("status", sa.String(), server_default="planned"))


def downgrade() -> None:
    # SQLite no soporta DROP COLUMN en versiones viejas; no-op intencional.
    pass
