"""Evaluación, pregunta socrática e intervención por intento."""
import json
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import models
from app.auth import current_user, session_for
from app.db import get_db
from app.helpers import (
    MAX_REVISIONS,
    _evaluate_attempt,
    _lab_type,
    _practice_attempts,
    _require_active,
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
    session_for(user, db, session_id)
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
    _require_active(session_for(user, db, session_id))
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
    q = await socratic_question(attempt.answer_text, weak, lab_type)
    # P2.4: el feedback remite a la pregunta → secuencial (2 llamadas solo con Gemini)
    fb = await feedback_text(attempt.answer_text, crits, q["question"])
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
    # ponytail: intervenciones no persistidas aún; deuda explícita (audit trail F5)
    _require_active(session_for(user, db, session_id))
    attempt = db.query(models.LabAttempt).filter_by(id=body.attempt_id,
                                                    session_id=session_id).first()
    if not attempt:
        raise HTTPException(404, "attempt not found")
    if len(_practice_attempts(db, session_id)) > MAX_REVISIONS:
        limited = await safe_intervention(
            f"Límite de {MAX_REVISIONS} revisiones alcanzado; ve al postest")
        # ponytail: se guarda la intervención completa (pregunta incluida) para
        # poder restaurarla al reanudar sin re-evaluar ni gastar proveedor.
        db.add(models.InterventionLog(id=uuid.uuid4().hex[:8], session_id=session_id,
                                      attempt_id=attempt.id, strategy=limited["strategy"],
                                      widget_type=limited["widget_type"],
                                      spec_json=json.dumps({
                                          "widget_type": limited["widget_type"],
                                          "widget_parameters": limited["widget_parameters"],
                                          "socratic_question": limited.get("socratic_question"),
                                          "strategy": limited["strategy"],
                                          "reason": limited.get("reason")})))
        db.commit()
        return limited
    ev = (
        db.query(models.EvaluationResult)
        .filter_by(attempt_id=attempt.id)
        .order_by(models.EvaluationResult.id.desc())
        .first()
    )
    eval_result = json.loads(ev.normalized_scores_json) if ev else None
    intervention = await select_intervention(
        attempt.answer_text, json.loads(attempt.input_state_json), eval_result,
        _lab_type(db, session_id),
        attempt_number=len(_practice_attempts(db, session_id)),
    )
    spec = intervention["widget_parameters"]
    errors = validate_ui_spec(
        {"widget_type": spec.get("type"), "widget_parameters": spec.get("parameters", {})}
    )
    if errors or intervention["widget_type"] not in CATALOG:
        return await safe_intervention(f"ui_spec inválida: {errors}")
    # P1.1: contrato versionado — el cliente valida tipo, versión y eventos.
    # Lo que delataría la respuesta (p. ej. tipos a contrastar) vive solo en el log.
    private = intervention.pop("_private", None)
    intervention["schema_version"] = SCHEMA_VERSION
    intervention["allowed_events"] = ALLOWED_BY_WIDGET.get(intervention["widget_type"], [])
    # F5: audit trail — qué estrategia se decidió por intento (append-only).
    # Guarda la intervención completa para restaurarla al reanudar la sesión.
    db.add(models.InterventionLog(id=uuid.uuid4().hex[:8], session_id=session_id,
                                  attempt_id=attempt.id,
                                  strategy=intervention["strategy"],
                                  widget_type=intervention["widget_type"],
                                  spec_json=json.dumps({
                                      "widget_type": intervention["widget_type"],
                                      "widget_parameters": intervention["widget_parameters"],
                                      "socratic_question": intervention.get("socratic_question"),
                                      "strategy": intervention["strategy"],
                                      "reason": intervention.get("reason"),
                                      "decided_by": intervention.get("decided_by"),
                                      "activity": intervention.get("activity"),
                                      "activity_params": intervention.get("activity_params"),
                                      "private": private,
                                      "submits_before": submit_count(
                                          db, session_id, intervention["widget_type"])})))
    db.commit()
    return intervention
