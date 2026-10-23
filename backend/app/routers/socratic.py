"""Evaluación, pregunta socrática e intervención por intento."""
import json
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import models
from app.activities import persist_activity, public_activity
from app.auth import current_user, session_for_write
from app.db import get_db
from app.helpers import (
    MAX_REVISIONS,
    _evaluate_attempt,
    _lab_type,
    _practice_attempts,
    _require_active,
    docker_unit_status,
    submit_count,
)
from app.interventions import (
    ALLOWED_BY_WIDGET,
    CATALOG,
    SCHEMA_VERSION,
    safe_intervention,
    select_intervention,
    validate_ui_spec,
)
from app.socratic import feedback_text, socratic_question

router = APIRouter()


class EvaluateIn(BaseModel):
    attempt_id: str


@router.post("/sessions/{session_id}/evaluate")
def evaluate(session_id: str, body: EvaluateIn, user=Depends(current_user),
             db: Session = Depends(get_db)):
    session_for_write(user, db, session_id)
    attempt = db.query(models.LabAttempt).filter_by(id=body.attempt_id,
                                                    session_id=session_id).first()
    if not attempt:
        raise HTTPException(404, "attempt not found")
    s = db.query(models.LearningSession).filter_by(id=session_id).first()
    return _evaluate_attempt(db, s, attempt)


class SocraticIn(BaseModel):
    attempt_id: str


@router.post("/sessions/{session_id}/socratic")
async def socratic(session_id: str, body: SocraticIn, user=Depends(current_user),
                   db: Session = Depends(get_db)):
    _require_active(session_for_write(user, db, session_id))
    attempt = db.query(models.LabAttempt).filter_by(id=body.attempt_id,
                                                    session_id=session_id).first()
    if not attempt:
        raise HTTPException(404, "attempt not found")
    ev = (
        db.query(models.EvaluationResult)
        .filter_by(attempt_id=attempt.id)
        .order_by(models.EvaluationResult.id.desc())
        .first()
    )
    weak = []
    crits = []
    if ev:
        for c in json.loads(ev.normalized_scores_json).get("criteria", []):
            crits.append(c)
            if c.get("score", 0) <= 2:
                weak.append(c["id"])
    lab_type = _lab_type(db, session_id)
    state = json.loads(attempt.input_state_json)
    context = None
    if lab_type == "docker":
        from app.labs_docker import activity, UNITS

        unit = (state.get("extra") or {}).get("unit")
        if unit in UNITS:
            context = activity(unit, int(state.get("seed", 1)))
            context["student_decisions"] = {k: v for k, v in (state.get("extra") or {}).items()
                                             if k in ("choices", "prediction", "order", "mount", "predicted")}
    q = await socratic_question(attempt.answer_text, weak, lab_type, context)
    # P2.4: el feedback remite a la pregunta → secuencial (2 llamadas solo con Gemini)
    fb = await feedback_text(attempt.answer_text, crits, q["question"], lab_type, context)
    q["feedback"] = fb
    # P3.3: la pregunta queda en ui_events → historial por sesión sin tabla nueva
    db.add(models.UiEvent(id=uuid.uuid4().hex[:8], session_id=session_id,
                          widget_type="SocraticQuestionCard", event_type="hintRequested",
                          payload_json=json.dumps({"question": q["question"],
                                                   "provider": q.get("provider", "?")})))
    db.commit()
    return q


@router.post("/sessions/{session_id}/next-intervention")
async def next_intervention(session_id: str, body: SocraticIn, user=Depends(current_user),
                            db: Session = Depends(get_db)):
    # Reanuda el reto persistido del intento sin crear otra identidad ni gastar LLM.
    session = session_for_write(user, db, session_id)
    _require_active(session)
    attempt = db.query(models.LabAttempt).filter_by(id=body.attempt_id,
                                                    session_id=session_id).first()
    if not attempt:
        raise HTTPException(404, "attempt not found")
    previous = db.query(models.InterventionLog).filter_by(session_id=session_id).all()
    if previous and previous[-1].attempt_id == attempt.id:
        return public_activity(previous[-1])
    if len(_practice_attempts(db, session_id)) > MAX_REVISIONS:
        limited = await safe_intervention(
            f"Límite de {MAX_REVISIONS} revisiones alcanzado; ve al postest")
        return persist_activity(db, session_id, attempt.id, limited)
    ev = (
        db.query(models.EvaluationResult)
        .filter_by(attempt_id=attempt.id)
        .order_by(models.EvaluationResult.id.desc())
        .first()
    )
    eval_result = json.loads(ev.normalized_scores_json) if ev else None
    lab_type = _lab_type(db, session_id)
    # Unidades ya completadas: habilitan repaso mezclado, transferencia y los
    # bancos compartidos de esas unidades (el menú del planificador se filtra).
    done = ([u for u, st in docker_unit_status(db, session.student_id).items() if st == "done"]
            if lab_type == "docker" else None)
    intervention = await select_intervention(
        attempt.answer_text, json.loads(attempt.input_state_json), eval_result, lab_type,
        attempt_number=len(_practice_attempts(db, session_id)), done_units=done,
    )
    spec = intervention["widget_parameters"]
    errors = validate_ui_spec(
        {"widget_type": spec.get("type"), "widget_parameters": spec.get("parameters", {})}
    )
    if errors or intervention["widget_type"] not in CATALOG:
        raise HTTPException(503, "Actividad no disponible; reintenta la solicitud")
    # P1.1: contrato versionado — el cliente valida tipo, versión y eventos.
    # Lo que delataría la respuesta (p. ej. tipos a contrastar) vive solo en el log.
    private = intervention.pop("_private", None)
    planner = intervention.pop("planner", None)  # telemetría para el instructor
    intervention["schema_version"] = SCHEMA_VERSION
    intervention["allowed_events"] = ALLOWED_BY_WIDGET.get(intervention["widget_type"], [])
    return persist_activity(db, session_id, attempt.id, intervention, private, planner)
