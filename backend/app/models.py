from sqlalchemy import String, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.db import Base


class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    display_name: Mapped[str] = mapped_column(String, nullable=False)
    role: Mapped[str] = mapped_column(String, nullable=False)  # student|instructor
    active: Mapped[int] = mapped_column(Integer, default=1)


class Module(Base):
    __tablename__ = "modules"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False)


class LabTemplate(Base):
    __tablename__ = "lab_templates"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    lab_type: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str] = mapped_column(Text, default="")
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    module_id: Mapped[str] = mapped_column(String, default="")
    config_json: Mapped[str] = mapped_column(Text, default="{}")


class LearningSession(Base):
    __tablename__ = "learning_sessions"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    student_id: Mapped[str] = mapped_column(String, nullable=False)
    lab_template_id: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[str] = mapped_column(String, default="active")  # active|posttest|done


class LabAttempt(Base):
    __tablename__ = "lab_attempts"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    session_id: Mapped[str] = mapped_column(String, nullable=False)
    input_state_json: Mapped[str] = mapped_column(Text, default="{}")
    answer_text: Mapped[str] = mapped_column(Text, default="")


class EvaluationResult(Base):
    __tablename__ = "evaluation_results"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    attempt_id: Mapped[str] = mapped_column(String, nullable=False)
    evaluator: Mapped[str] = mapped_column(String, nullable=False)  # mock|jev
    rubric_version: Mapped[str] = mapped_column(String, nullable=False)
    normalized_scores_json: Mapped[str] = mapped_column(Text, default="{}")
    status: Mapped[str] = mapped_column(String, default="evaluated")


class Reflection(Base):
    __tablename__ = "reflections"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    session_id: Mapped[str] = mapped_column(String, nullable=False)
    text: Mapped[str] = mapped_column(Text, default="")


class AuthToken(Base):
    __tablename__ = "auth_tokens"
    token: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(String, nullable=False)
    # P7.1: epoch de emisión; 0 = heredado sin expiración (solo filas viejas)
    created_at: Mapped[int] = mapped_column(Integer, default=0)


class InstructorReview(Base):
    __tablename__ = "instructor_reviews"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    attempt_id: Mapped[str] = mapped_column(String, nullable=False)
    instructor_id: Mapped[str] = mapped_column(String, nullable=False)
    rubric_scores_json: Mapped[str] = mapped_column(Text, default="{}")
    notes: Mapped[str] = mapped_column(Text, default="")


class UiEvent(Base):
    __tablename__ = "ui_events"
    # ponytail: id = client_event_id → dedup natural por PK, un registro por evento
    id: Mapped[str] = mapped_column(String, primary_key=True)
    session_id: Mapped[str] = mapped_column(String, nullable=False)
    widget_type: Mapped[str] = mapped_column(String, nullable=False)
    event_type: Mapped[str] = mapped_column(String, nullable=False)
    payload_json: Mapped[str] = mapped_column(Text, default="{}")


class InterventionLog(Base):
    """P3/F5: audit trail de intervenciones (estrategia decidida por intento)."""
    __tablename__ = "intervention_log"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    session_id: Mapped[str] = mapped_column(String, nullable=False)
    attempt_id: Mapped[str] = mapped_column(String, nullable=False)
    strategy: Mapped[str] = mapped_column(String, nullable=False)
    widget_type: Mapped[str] = mapped_column(String, nullable=False)
    spec_json: Mapped[str] = mapped_column(Text, default="{}")


class DiagnosticResult(Base):
    """Sprint 4: diagnóstico por objetivo (una fila por sesión, primera evaluación)."""
    __tablename__ = "diagnostic_results"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    session_id: Mapped[str] = mapped_column(String, nullable=False)
    student_id: Mapped[str] = mapped_column(String, nullable=False)
    lab_template_id: Mapped[str] = mapped_column(String, nullable=False)
    objective_id: Mapped[str] = mapped_column(String, default="")
    level: Mapped[str] = mapped_column(String, nullable=False)
    evidence_json: Mapped[str] = mapped_column(Text, default="{}")


class RecallItem(Base):
    """Sprint 4: repaso espaciado 1/3/7 días (una fila por vencimiento)."""
    __tablename__ = "recall_schedule"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    student_id: Mapped[str] = mapped_column(String, nullable=False)
    lab_template_id: Mapped[str] = mapped_column(String, nullable=False)
    objective_id: Mapped[str] = mapped_column(String, default="")
    due_at: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String, default="pending")
    created_at: Mapped[int] = mapped_column(Integer, default=0)


class LearningObjective(Base):
    """Sprint 1: objetivo + lección + ejemplo + blueprint diagnóstico (una unidad)."""
    __tablename__ = "learning_objectives"
    id: Mapped[str] = mapped_column(String, primary_key=True)
    lab_template_id: Mapped[str] = mapped_column(String, nullable=False)
    title: Mapped[str] = mapped_column(String, nullable=False)
    level: Mapped[str] = mapped_column(String, default="intermedio")
    concept_summary: Mapped[str] = mapped_column(Text, default="")
    worked_example_json: Mapped[str] = mapped_column(Text, default="[]")
    misconceptions_json: Mapped[str] = mapped_column(Text, default="[]")
    rubric_id: Mapped[str] = mapped_column(String, default="")
    diagnostic_blueprint_json: Mapped[str] = mapped_column(Text, default="{}")
    # Sprint 3: estado real de preparación (planned|content_ready|interactive_ready|validated)
    status: Mapped[str] = mapped_column(String, default="planned")
