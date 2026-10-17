"""Baseline: crea las 14 tablas del monolito (estado final de app/models.py).

Revision ID: 0001
"""
import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("display_name", sa.String(), nullable=False),
        sa.Column("role", sa.String(), nullable=False),
        sa.Column("active", sa.Integer(), nullable=True),
    )
    op.create_table(
        "modules",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("order_index", sa.Integer(), nullable=False),
    )
    op.create_table(
        "lab_templates",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("lab_type", sa.String(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("order_index", sa.Integer(), nullable=True),
        sa.Column("module_id", sa.String(), nullable=True),
        sa.Column("config_json", sa.Text(), nullable=True),
    )
    op.create_table(
        "learning_sessions",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("student_id", sa.String(), nullable=False),
        sa.Column("lab_template_id", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=True),
    )
    op.create_table(
        "lab_attempts",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("input_state_json", sa.Text(), nullable=True),
        sa.Column("answer_text", sa.Text(), nullable=True),
    )
    op.create_table(
        "evaluation_results",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("attempt_id", sa.String(), nullable=False),
        sa.Column("evaluator", sa.String(), nullable=False),
        sa.Column("rubric_version", sa.String(), nullable=False),
        sa.Column("normalized_scores_json", sa.Text(), nullable=True),
        sa.Column("status", sa.String(), nullable=True),
    )
    op.create_table(
        "reflections",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("text", sa.Text(), nullable=True),
    )
    op.create_table(
        "auth_tokens",
        sa.Column("token", sa.String(), primary_key=True),
        sa.Column("user_id", sa.String(), nullable=False),
        sa.Column("created_at", sa.Integer(), nullable=True),
    )
    op.create_table(
        "instructor_reviews",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("attempt_id", sa.String(), nullable=False),
        sa.Column("instructor_id", sa.String(), nullable=False),
        sa.Column("rubric_scores_json", sa.Text(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
    )
    op.create_table(
        "ui_events",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("widget_type", sa.String(), nullable=False),
        sa.Column("event_type", sa.String(), nullable=False),
        sa.Column("payload_json", sa.Text(), nullable=True),
    )
    op.create_table(
        "intervention_log",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("attempt_id", sa.String(), nullable=False),
        sa.Column("strategy", sa.String(), nullable=False),
        sa.Column("widget_type", sa.String(), nullable=False),
        sa.Column("spec_json", sa.Text(), nullable=True),
    )
    op.create_table(
        "diagnostic_results",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("session_id", sa.String(), nullable=False),
        sa.Column("student_id", sa.String(), nullable=False),
        sa.Column("lab_template_id", sa.String(), nullable=False),
        sa.Column("objective_id", sa.String(), nullable=True),
        sa.Column("level", sa.String(), nullable=False),
        sa.Column("evidence_json", sa.Text(), nullable=True),
    )
    op.create_table(
        "recall_schedule",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("student_id", sa.String(), nullable=False),
        sa.Column("lab_template_id", sa.String(), nullable=False),
        sa.Column("objective_id", sa.String(), nullable=True),
        sa.Column("due_at", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(), nullable=True),
        sa.Column("created_at", sa.Integer(), nullable=True),
    )
    op.create_table(
        "learning_objectives",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("lab_template_id", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("level", sa.String(), nullable=True),
        sa.Column("concept_summary", sa.Text(), nullable=True),
        sa.Column("worked_example_json", sa.Text(), nullable=True),
        sa.Column("misconceptions_json", sa.Text(), nullable=True),
        sa.Column("rubric_id", sa.String(), nullable=True),
        sa.Column("diagnostic_blueprint_json", sa.Text(), nullable=True),
        sa.Column("status", sa.String(), nullable=True),
    )


def downgrade() -> None:
    for table in ("learning_objectives", "recall_schedule", "diagnostic_results",
                  "intervention_log", "ui_events", "instructor_reviews",
                  "auth_tokens", "reflections", "evaluation_results",
                  "lab_attempts", "learning_sessions", "lab_templates",
                  "modules", "users"):
        op.drop_table(table)
