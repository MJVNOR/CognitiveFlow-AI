"""Lógica compartida de sesiones/evaluación/progreso (sin rutas)."""
import hashlib
import json
import os
import uuid

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app import models
from app.evaluation import (
    jev_evaluate,
    mock_evaluate,
    mock_evaluate_data,
    mock_evaluate_monitor,
)


MAX_REVISIONS = 6  # P3.5: tope de ciclos evaluar→intervenir por sesión; luego postest


def _kind(attempt) -> str:
    try:
        return json.loads(attempt.input_state_json).get("kind", "")
    except Exception:
        return ""


def _practice_attempts(db: Session, session_id: str) -> list:
    # ponytail: O(n) scan; 4 alumnos, sesiones cortas
    return [a for a in db.query(models.LabAttempt).filter_by(session_id=session_id).all()
            if _kind(a) != "posttest"]


def _phase(db: Session, session) -> str:
    """P3.2: fase derivada de datos persistidos — recuperable tras recarga sin tabla extra."""
    if session.status == "done":
        return "cierre"
    if session.status == "posttest":
        return "postest"
    attempts = _practice_attempts(db, session.id)
    if not attempts:
        return "prediccion"
    evs = [e for a in attempts
           for e in db.query(models.EvaluationResult).filter_by(attempt_id=a.id).all()]
    if not evs:
        return "justificacion"
    if not any(e.status == "evaluated" for e in evs):
        return "evaluacion"
    nev = db.query(models.UiEvent).filter_by(session_id=session.id).count()
    if len(attempts) > 1:
        return "revision"
    return "intervencion" if nev else "evaluacion"


def _posttest_variant(session_id: str) -> dict:
    """P4.1: variante equivalente pero nueva por sesión (determinista)."""
    h = int(hashlib.sha256(session_id.encode()).hexdigest(), 16)
    return {"seed": 100 + h % 800, "complexity": 6 + h % 4,
            "noise_pct": 15 + (h % 3) * 10}


def _posttest_attempt(db: Session, session_id: str):
    for a in db.query(models.LabAttempt).filter_by(session_id=session_id).all():
        if _kind(a) == "posttest":
            return a
    return None


def _evaluate_attempt(db: Session, session, attempt) -> dict:
    state = json.loads(attempt.input_state_json)
    lab_type = ""
    if session:
        tpl = db.query(models.LabTemplate).filter_by(id=session.lab_template_id).first()
        lab_type = tpl.lab_type if tpl else ""
    if lab_type == "data_detective":
        # ponytail: Jev solo en ML por ahora; datos y monitoreo con mock determinista
        result = mock_evaluate_data(attempt.answer_text, state.get("flags", []),
                                    state.get("seed", 1), state.get("extra", {}))
    elif lab_type == "model_monitoring":
        result = mock_evaluate_monitor(attempt.answer_text, state.get("extra", {}),
                                       state.get("seed", 1))
    elif os.getenv("EVALUATOR_MODE", "mock") == "jev":
        result = jev_evaluate(attempt.answer_text, state)
    else:
        result = mock_evaluate(attempt.answer_text, state.get("complexity", 5))
    eid = uuid.uuid4().hex[:8]
    db.add(
        models.EvaluationResult(
            id=eid,
            attempt_id=attempt.id,
            evaluator=result["evaluator"],
            rubric_version=result["rubric_version"],
            normalized_scores_json=json.dumps(result),
            status=result["status"],
        )
    )
    db.commit()
    return result


def _require_active(session) -> None:
    if session.status != "active":
        raise HTTPException(403, "sesión bloqueada: postest en curso o terminada")


def _lab_type(db: Session, session_id: str) -> str:
    s = db.query(models.LearningSession).filter_by(id=session_id).first()
    if not s:
        return ""
    tpl = db.query(models.LabTemplate).filter_by(id=s.lab_template_id).first()
    return tpl.lab_type if tpl else ""


def _eval_map(db: Session, attempt_id: str) -> dict | None:
    """Última evaluación del intento como {criterion: score}; None si no evaluado."""
    ev = (db.query(models.EvaluationResult).filter_by(attempt_id=attempt_id)
          .order_by(models.EvaluationResult.id.desc()).first())
    if not ev or ev.status != "evaluated":
        return None
    try:
        crits = json.loads(ev.normalized_scores_json).get("criteria", [])
    except Exception:
        return None
    return {c.get("id"): c.get("score", 0) for c in crits if c.get("id")}


def _lab_progress(db: Session, student_id: str, lab_template_id: str) -> dict:
    """P4.2: baseline (primer intento práctica) vs postest, por criterio."""
    sessions = db.query(models.LearningSession).filter_by(
        student_id=student_id, lab_template_id=lab_template_id).all()
    if not sessions:
        return {"status": None, "attempts": 0, "baseline": None, "posttest": None,
                "reviewed": False}
    s = sessions[-1]
    practice = _practice_attempts(db, s.id)
    baseline = _eval_map(db, practice[0].id) if practice else None
    pt = _posttest_attempt(db, s.id)
    posttest = _eval_map(db, pt.id) if pt else None
    aids = [a.id for a in practice] + ([pt.id] if pt else [])
    reviewed = bool(aids and db.query(models.InstructorReview).filter(
        models.InstructorReview.attempt_id.in_(aids)).first())
    pending_review = bool(aids and not reviewed and (baseline or posttest))
    return {"status": s.status, "attempts": len(practice), "baseline": baseline,
            "posttest": posttest, "reviewed": reviewed, "pending_review": pending_review}
