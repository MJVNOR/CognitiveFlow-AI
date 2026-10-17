"""Labs y sesiones: catálogo, intentos, eventos, postest, reflexión, progreso."""
import json
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app import models
from app.auth import current_user, session_for
from app.db import get_db
from app.helpers import (
    _evaluate_attempt,
    _lab_progress,
    _phase,
    _posttest_attempt,
    _posttest_variant,
    _practice_attempts,
)
from app.interventions import ALLOWED_BY_WIDGET, ALLOWED_EVENTS, CATALOG
from app.labs_data import generate as generate_dataset
from app.labs_ml import ml_curve
from app.labs_monitor import generate as generate_monitor

router = APIRouter()


@router.get("/modules")
def list_modules(db: Session = Depends(get_db)):
    rows = db.query(models.Module).order_by(models.Module.order_index).all()
    return [{"id": m.id, "title": m.title, "order_index": m.order_index} for m in rows]


@router.get("/labs")
def list_labs(db: Session = Depends(get_db)):
    rows = db.query(models.LabTemplate).order_by(models.LabTemplate.order_index).all()
    return [{"id": l.id, "title": l.title, "lab_type": l.lab_type,
             "description": l.description or "", "order_index": l.order_index,
             "module_id": l.module_id or ""} for l in rows]


@router.get("/me/lab-status")
def my_lab_status(user=Depends(current_user), db: Session = Depends(get_db)):
    # Última sesión por lab (orden de inserción); sin sesiones → {}.
    status = {}
    for s in db.query(models.LearningSession).filter_by(student_id=user.id).all():
        status[s.lab_template_id] = s.status
    return status


@router.get("/me/sessions")
def my_sessions(lab_template_id: str = "", user=Depends(current_user),
                db: Session = Depends(get_db)):
    # P1.6: reanudar — última sesión propia por lab, con fase (sin gastar re-evaluar).
    q = db.query(models.LearningSession).filter_by(student_id=user.id)
    if lab_template_id:
        q = q.filter_by(lab_template_id=lab_template_id)
    return [{"id": s.id, "lab_template_id": s.lab_template_id, "status": s.status,
             "phase": _phase(db, s)} for s in q.all()]


@router.get("/sessions/{session_id}/interventions")
def session_interventions(session_id: str, user=Depends(current_user),
                          db: Session = Depends(get_db)):
    # F5: audit trail legible (estrategia por intento); ownership primero.
    session_for(user, db, session_id)
    rows = db.query(models.InterventionLog).filter_by(session_id=session_id).all()
    return [{"attempt_id": r.attempt_id, "strategy": r.strategy,
             "widget_type": r.widget_type} for r in rows]


class SessionIn(BaseModel):
    student_id: str = "s1"
    lab_template_id: str = "lab-ml"


@router.post("/sessions")
def create_session(body: SessionIn, user=Depends(current_user), db: Session = Depends(get_db)):
    sid = uuid.uuid4().hex[:8]
    student_id = body.student_id if user.role == "instructor" else user.id
    db.add(
        models.LearningSession(
            id=sid, student_id=student_id, lab_template_id=body.lab_template_id
        )
    )
    db.commit()
    return {"id": sid}


@router.get("/sessions/{session_id}")
def get_session(session_id: str, user=Depends(current_user), db: Session = Depends(get_db)):
    s = session_for(user, db, session_id)
    attempts = _practice_attempts(db, session_id)
    last_eval = None
    for a in reversed(attempts):
        ev = (db.query(models.EvaluationResult).filter_by(attempt_id=a.id)
              .order_by(models.EvaluationResult.id.desc()).first())
        if ev is not None:
            try:
                last_eval = json.loads(ev.normalized_scores_json)
                last_eval["attempt_id"] = a.id
            except Exception:
                last_eval = None
            break
    return {"id": s.id, "student_id": s.student_id, "lab_template_id": s.lab_template_id,
            "status": s.status, "phase": _phase(db, s), "attempt_count": len(attempts),
            "last_eval": last_eval,
            "variant": _posttest_variant(session_id) if s.status == "posttest" else None}


@router.get("/sessions/{session_id}/tutor-history")
def tutor_history(session_id: str, user=Depends(current_user), db: Session = Depends(get_db)):
    # P3.3: preguntas del tutor por sesión (orden de inserción); ownership primero.
    session_for(user, db, session_id)
    out = []
    for e in db.query(models.UiEvent).filter_by(
            session_id=session_id, widget_type="SocraticQuestionCard").all():
        try:
            p = json.loads(e.payload_json)
        except Exception:
            continue
        if "question" in p:
            out.append({"question": p["question"], "provider": p.get("provider", "?")})
    return out


@router.get("/labs/{lab_id}/curve")
def lab_curve(lab_id: str, complexity: int = 5, noise_pct: int = 20, seed: int = 1):
    # ponytail: solo ml_experiment por ahora, otros labs devuelven misma forma
    return {"lab_id": lab_id, **ml_curve(complexity, noise_pct, seed)}


class AttemptIn(BaseModel):
    complexity: int = 5
    noise_pct: int = 20
    seed: int = 1
    answer_text: str = Field(default="", max_length=6000)  # P7.1: tope de payload
    flags: list = []  # ids de filas marcadas (Data Detective)
    extra: dict = {}  # monitor: {feature, changepoint}


class EventIn(BaseModel):
    client_event_id: str
    widget_type: str
    event_type: str
    payload: dict = {}


@router.post("/sessions/{session_id}/events")
def record_event(session_id: str, body: EventIn, user=Depends(current_user),
                 db: Session = Depends(get_db)):
    # P1.5: canal bidireccional — ownership primero, nunca score/cliente como verdad.
    session_for(user, db, session_id)
    if body.widget_type not in CATALOG:
        raise HTTPException(422, f"widget_type desconocido: {body.widget_type}")
    if body.event_type not in ALLOWED_EVENTS:
        raise HTTPException(422, f"event_type desconocido: {body.event_type}")
    if body.event_type not in ALLOWED_BY_WIDGET.get(body.widget_type, []):
        raise HTTPException(422, f"{body.event_type} no permitido en {body.widget_type}")
    # ponytail: dedup por PK (client_event_id) — reintento seguro, un solo registro
    existing = db.query(models.UiEvent).filter_by(id=body.client_event_id).first()
    if existing:
        return {"id": existing.id, "deduped": True}
    db.add(
        models.UiEvent(
            id=body.client_event_id,
            session_id=session_id,
            widget_type=body.widget_type,
            event_type=body.event_type,
            payload_json=json.dumps(body.payload),
        )
    )
    db.commit()
    return {"id": body.client_event_id, "deduped": False}


@router.post("/sessions/{session_id}/attempts")
def create_attempt(session_id: str, body: AttemptIn, user=Depends(current_user),
                   db: Session = Depends(get_db)):
    session_for(user, db, session_id)
    aid = uuid.uuid4().hex[:8]
    db.add(
        models.LabAttempt(
            id=aid,
            session_id=session_id,
            input_state_json=json.dumps(
                {
                    "complexity": body.complexity,
                    "noise_pct": body.noise_pct,
                    "seed": body.seed,
                    "flags": body.flags,
                    "extra": body.extra,
                }
            ),
            answer_text=body.answer_text,
        )
    )
    db.commit()
    return {"id": aid}


@router.get("/labs/{lab_id}/dataset")
def lab_dataset(lab_id: str, seed: int = 1):
    # ponytail: plantados jamás salen al cliente
    ds = generate_dataset(seed)
    return {"lab_id": lab_id, "columns": ds["columns"], "rows": ds["rows"]}


@router.get("/labs/{lab_id}/distributions")
def lab_distributions(lab_id: str, seed: int = 1):
    # ponytail: verdad (truth) jamás sale al cliente
    ds = generate_monitor(seed)
    return {"lab_id": lab_id, "features": ds["features"], "series": ds["series"]}


def _objective_out(o) -> dict:
    # ponytail: parseo tolerante — fila corrupta no tumba el endpoint
    try:
        steps = json.loads(o.worked_example_json)
    except Exception:
        steps = []
    try:
        misc = json.loads(o.misconceptions_json)
    except Exception:
        misc = []
    return {"id": o.id, "lab_template_id": o.lab_template_id, "title": o.title,
            "level": o.level, "concept_summary": o.concept_summary,
            "worked_example_steps": steps, "misconceptions": misc,
            "rubric_id": o.rubric_id}


@router.get("/labs/{lab_id}/objectives")
def lab_objectives(lab_id: str, db: Session = Depends(get_db)):
    # Sprint 1: lección + ejemplo por unidad; fallback a constante si la tabla aún no se sembró.
    rows = db.query(models.LearningObjective).filter_by(lab_template_id=lab_id).all()
    if rows:
        return [_objective_out(o) for o in rows]
    if lab_id == "lab-ml":
        from app.seed import OBJECTIVE_ML_U02 as _o
        return [{**{k: _o[k] for k in ("id", "lab_template_id", "title", "level",
                                      "concept_summary", "rubric_id")},
                 "worked_example_steps": _o["worked_example_steps"],
                 "misconceptions": _o["misconceptions"]}]
    raise HTTPException(404, "sin objetivos para ese lab")


@router.post("/labs/{lab_id}/diagnostics")
def lab_diagnostics(lab_id: str, db: Session = Depends(get_db)):
    # Sprint 1: diagnóstico breve (2 ítems equivalentes, sin pistas ni evaluación).
    bp = None
    row = db.query(models.LearningObjective).filter_by(lab_template_id=lab_id).first()
    if row is not None:
        try:
            bp = json.loads(row.diagnostic_blueprint_json)
        except Exception:
            bp = None
    if bp is None:
        if lab_id != "lab-ml":
            raise HTTPException(404, "sin diagnóstico para ese lab")
        from app.seed import OBJECTIVE_ML_U02 as _o
        bp = _o["diagnostic_blueprint"]
    items = bp.get("items", []) if isinstance(bp, dict) else []
    return {"lab_template_id": lab_id,
            "objective_id": row.id if row is not None else "M03-U02-generalization",
            "items": items}


@router.get("/sessions/{session_id}/attempts")
def list_attempts(session_id: str, user=Depends(current_user), db: Session = Depends(get_db)):
    session_for(user, db, session_id)
    rows = db.query(models.LabAttempt).filter_by(session_id=session_id).all()
    return [
        {"id": a.id, "input": json.loads(a.input_state_json), "answer": a.answer_text}
        for a in rows
    ]


class PosttestIn(BaseModel):
    complexity: int = 5  # ignorados: la variante la fija el servidor (P4.1)
    noise_pct: int = 20
    answer_text: str = Field(default="", max_length=6000)


@router.post("/sessions/{session_id}/posttest")
def posttest(session_id: str, body: PosttestIn, user=Depends(current_user),
             db: Session = Depends(get_db)):
    s = session_for(user, db, session_id)
    if s.status == "done":
        raise HTTPException(403, "sesión terminada")
    variant = _posttest_variant(session_id)
    if s.status == "active":
        s.status = "posttest"
        db.commit()
    if not body.answer_text.strip():
        return {"status": "begin", **variant}
    if _posttest_attempt(db, session_id):
        raise HTTPException(403, "postest ya entregado")
    aid = uuid.uuid4().hex[:8]
    attempt = models.LabAttempt(
        id=aid, session_id=session_id,
        input_state_json=json.dumps({"complexity": variant["complexity"],
                                     "noise_pct": variant["noise_pct"],
                                     "seed": variant["seed"], "kind": "posttest"}),
        answer_text=body.answer_text)
    db.add(attempt)
    db.commit()
    # P4.2: el postest se evalúa y guarda (comparación honesta), pero no se muestra
    result = _evaluate_attempt(db, s, attempt)
    return {"status": "submitted", "id": aid, **variant, "eval_status": result["status"]}


@router.get("/me/progress")
def my_progress(user=Depends(current_user), db: Session = Depends(get_db)):
    # P4.2/P4.3: dominio demostrado (baseline vs postest), no clics ni tiempo.
    labs = db.query(models.LabTemplate).order_by(models.LabTemplate.order_index).all()
    return [{"lab_template_id": l.id, "title": l.title,
             **_lab_progress(db, user.id, l.id)} for l in labs]


class ReflectionIn(BaseModel):
    text: str = Field(max_length=2000)


@router.post("/sessions/{session_id}/reflection")
def reflection(session_id: str, body: ReflectionIn, user=Depends(current_user),
               db: Session = Depends(get_db)):
    s = session_for(user, db, session_id)
    if s.status != "posttest":
        raise HTTPException(403, "reflexión solo tras el postest")
    s.status = "done"
    db.add(models.Reflection(id=uuid.uuid4().hex[:8], session_id=session_id, text=body.text))
    db.commit()
    # P4.5: pico-fin honesto desde deltas baseline→postest; sin halago automático.
    prog = _lab_progress(db, s.student_id, s.lab_template_id)
    base, post = prog["baseline"] or {}, prog["posttest"] or {}
    deltas = {k: post.get(k, 0) - base.get(k, 0) for k in base if k in post}
    mejora = max(deltas, key=deltas.get) if deltas and max(deltas.values()) > 0 else None
    desafio = min(deltas, key=deltas.get) if deltas else None
    if desafio is None and post:
        desafio = min(post, key=post.get)
    return {"status": "done", "summary": {"mejora": mejora, "desafio": desafio}}
