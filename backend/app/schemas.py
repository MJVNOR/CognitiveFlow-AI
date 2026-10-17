"""Schemas públicos de la API (salida). Separan el contrato del modelo tabla.

Los modelos tabla viven en app/models.py (SQLAlchemy). Estos schemas Pydantic
son lo único que sale por el wire: si una tabla suma una columna interna,
no se filtra salvo que se añada aquí explícitamente.
"""
from typing import Any

from pydantic import BaseModel


class ModuleOut(BaseModel):
    id: str
    title: str
    order_index: int


class LabOut(BaseModel):
    id: str
    title: str
    lab_type: str
    description: str = ""
    order_index: int
    module_id: str = ""


class SessionBriefOut(BaseModel):
    id: str
    lab_template_id: str
    status: str
    phase: str


class InterventionLogOut(BaseModel):
    attempt_id: str
    strategy: str
    widget_type: str
    widget_parameters: dict = {}
    socratic_question: str | None = None


class SessionDetailOut(BaseModel):
    id: str
    student_id: str
    lab_template_id: str
    status: str
    phase: str
    attempt_count: int
    last_eval: dict | None = None
    level: str
    assistance: dict = {}
    variant: dict | None = None


class TutorHistoryItemOut(BaseModel):
    question: str
    provider: str


class AttemptOut(BaseModel):
    id: str
    input: dict = {}
    answer: str = ""


class ObjectiveOut(BaseModel):
    id: str
    lab_template_id: str
    title: str
    level: str
    concept_summary: str
    worked_example_steps: list = []
    misconceptions: list = []
    rubric_id: str = ""
    status: str = "planned"


class DiagnosticOut(BaseModel):
    lab_template_id: str
    objective_id: str
    items: list = []


class ProgressOut(BaseModel):
    lab_template_id: str
    title: str = ""
    status: str | None = None
    attempts: int = 0
    baseline: dict | None = None
    posttest: dict | None = None
    reviewed: bool = False
    pending_review: bool = False
    mastery: dict | None = None
    mastery_status: str = "not_demonstrated"


class RecallOut(BaseModel):
    id: str
    lab_template_id: str
    objective_id: str = ""
    due_at: int = 0


class LoginOut(BaseModel):
    token: str
    role: str
    user_id: str


class MeOut(BaseModel):
    user_id: str
    role: str
    display_name: str


class StudentOut(BaseModel):
    id: str
    display_name: str


class InstructorSessionOut(BaseModel):
    id: str
    lab_template_id: str
    status: str


class MatrixEntryOut(BaseModel):
    student: str
    student_id: str
    labs: dict[str, Any] = {}
