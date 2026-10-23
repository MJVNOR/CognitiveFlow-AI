"""Labs y sesiones: catálogo, intentos, eventos, postest, reflexión, progreso."""
import json
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app import models
from app.activities import activity_identity
from app.auth import current_user, session_for, session_for_write
from app.db import get_db
from app.helpers import (
    ARCHIVED,
    docker_prereq_missing,
    docker_unit_status,
    _evaluate_attempt,
    _lab_type,
    _lab_progress,
    _can_enter_posttest,
    _phase,
    _posttest_attempt,
    _posttest_variant,
    _practice_attempts,
)
from app.schemas import (
    AttemptOut,
    DiagnosticOut,
    InterventionLogOut,
    LabOut,
    ModuleOut,
    ObjectiveOut,
    ProgressOut,
    RecallOut,
    SessionBriefOut,
    SessionDetailOut,
    TutorHistoryItemOut,
)
from app.checks import check_challenge, check_practice
from app.interventions import (
    ALLOWED_BY_WIDGET,
    ALLOWED_EVENTS,
    CATALOG,
    DOCKER_WIDGETS,
    SUBMIT_EVENT,
)
from app.labs_data import generate as generate_dataset
from app.labs_ml import ml_curve
from app.labs_monitor import generate as generate_monitor

router = APIRouter()


@router.get("/modules", response_model=list[ModuleOut])
def list_modules(db: Session = Depends(get_db)):
    rows = db.query(models.Module).order_by(models.Module.order_index).all()
    return [{"id": m.id, "title": m.title, "order_index": m.order_index} for m in rows]


@router.get("/labs", response_model=list[LabOut])
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
        if s.status != ARCHIVED:
            status[s.lab_template_id] = s.status
    return status


@router.get("/me/sessions", response_model=list[SessionBriefOut])
def my_sessions(lab_template_id: str = "", user=Depends(current_user),
                db: Session = Depends(get_db)):
    # P1.6: reanudar — última sesión propia por lab, con fase (sin gastar re-evaluar).
    q = db.query(models.LearningSession).filter(
        models.LearningSession.student_id == user.id,
        models.LearningSession.status != ARCHIVED)
    if lab_template_id:
        q = q.filter_by(lab_template_id=lab_template_id)
    return [{"id": s.id, "lab_template_id": s.lab_template_id, "status": s.status,
             "phase": _phase(db, s)} for s in q.all()]


@router.post("/me/labs/{lab_id}/reset")
def reset_lab(lab_id: str, user=Depends(current_user), db: Session = Depends(get_db)):
    """El estudiante reinicia un laboratorio para empezar desde cero. No borra nada:
    sus sesiones pasan a `archived` (el instructor conserva el historial y las
    evaluaciones siguen intactas, append-only); la próxima apertura crea una nueva."""
    if user.role == "instructor":
        raise HTTPException(403, "el instructor solo consulta")
    n = 0
    for s in db.query(models.LearningSession).filter_by(student_id=user.id,
                                                        lab_template_id=lab_id).all():
        if s.status != ARCHIVED:
            s.status = ARCHIVED
            n += 1
    db.commit()
    return {"archived": n}


@router.get("/sessions/{session_id}/interventions", response_model=list[InterventionLogOut])
def session_interventions(session_id: str, user=Depends(current_user),
                          db: Session = Depends(get_db)):
    # F5: audit trail legible (estrategia por intento); ownership primero.
    # Sprint 1: devuelve la spec completa para restaurar la actividad al
    # reanudar sin re-evaluar. Filas viejas = solo widget_parameters (tolerado).
    session_for(user, db, session_id)
    rows = db.query(models.InterventionLog).filter_by(session_id=session_id).all()
    out = []
    for r in rows:
        try:
            spec = json.loads(r.spec_json)
        except Exception:
            spec = {}
        params = (spec.get("widget_parameters")
                  if isinstance(spec, dict) and isinstance(spec.get("widget_parameters"), dict)
                  else (spec if isinstance(spec, dict) else {}))
        out.append({**activity_identity(r), "attempt_id": r.attempt_id, "strategy": r.strategy,
                    "widget_type": r.widget_type, "widget_parameters": params,
                    "socratic_question": spec.get("socratic_question")
                    if isinstance(spec, dict) else None})
    return out


class SessionIn(BaseModel):
    student_id: str = "s1"
    lab_template_id: str = "lab-ml"


@router.post("/sessions")
def create_session(body: SessionIn, user=Depends(current_user), db: Session = Depends(get_db)):
    # El instructor solo consulta: no abre ni asigna sesiones a estudiantes.
    if user.role == "instructor":
        raise HTTPException(403, "el instructor solo consulta (sin asignar sesiones)")
    sid = uuid.uuid4().hex[:8]
    student_id = user.id  # nunca del payload
    db.add(
        models.LearningSession(
            id=sid, student_id=student_id, lab_template_id=body.lab_template_id
        )
    )
    db.commit()
    return {"id": sid}


@router.get("/sessions/{session_id}", response_model=SessionDetailOut)
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
    diag = db.query(models.DiagnosticResult).filter_by(session_id=session_id).first()
    # Sprint 4: ayuda usada hasta ahora (pistas + preguntas + intervenciones).
    assistance = {
        "hints": db.query(models.UiEvent).filter_by(
            session_id=session_id, event_type="hintRequested").count(),
        "socratic": db.query(models.UiEvent).filter_by(
            session_id=session_id, widget_type="SocraticQuestionCard").count(),
        "interventions": db.query(models.InterventionLog).filter_by(
            session_id=session_id).count(),
    }
    return {"id": s.id, "student_id": s.student_id, "lab_template_id": s.lab_template_id,
            "status": s.status, "phase": _phase(db, s), "attempt_count": len(attempts),
            "last_eval": last_eval, "level": diag.level if diag else "pending",
            "assistance": assistance,
            "can_enter_posttest": _can_enter_posttest(db, s),
            "variant": _posttest_variant(session_id) if s.status == "posttest" else None}


@router.get("/sessions/{session_id}/tutor-history", response_model=list[TutorHistoryItemOut])
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
    activity_id: str | None = Field(default=None, min_length=1, max_length=120)
    widget_type: str
    event_type: str
    payload: dict = {}


@router.post("/sessions/{session_id}/events")
def record_event(session_id: str, body: EventIn, user=Depends(current_user),
                 db: Session = Depends(get_db)):
    # P1.5: canal bidireccional — ownership primero, nunca score/cliente como verdad.
    session = session_for_write(user, db, session_id)
    if {"activity_id", "server_check"} & body.payload.keys():
        raise HTTPException(422, "Metadatos de actividad o corrección no permitidos en payload")
    if body.widget_type not in CATALOG:
        raise HTTPException(422, f"widget_type desconocido: {body.widget_type}")
    if body.event_type not in ALLOWED_EVENTS:
        raise HTTPException(422, f"event_type desconocido: {body.event_type}")
    if body.event_type not in ALLOWED_BY_WIDGET.get(body.widget_type, []):
        raise HTTPException(422, f"{body.event_type} no permitido en {body.widget_type}")
    # Un ID de reintento no permite reutilizar evidencia de otra sesión o reto.
    existing = db.query(models.UiEvent).filter_by(id=body.client_event_id).first()
    if existing:
        stored = json.loads(existing.payload_json)
        original = {k: v for k, v in stored.items() if k not in ("server_check", "activity_id")}
        if (existing.session_id != session_id or existing.widget_type != body.widget_type
                or existing.event_type != body.event_type or original != body.payload
                or (body.activity_id is not None and stored.get("activity_id") != body.activity_id)):
            raise HTTPException(409, "client_event_id ya utilizado para otro evento")
        prev = stored.get("server_check")
        return {"id": existing.id, "deduped": True, **({"check": prev} if prev else {})}
    if session.status != "active":
        raise HTTPException(409, "La sesión no admite eventos de práctica")
    logs = db.query(models.InterventionLog).filter_by(session_id=session_id).all()
    latest = logs[-1] if logs else None
    expected = activity_identity(latest)["activity_id"] if latest else f"practice-{session_id}"
    # Clientes antiguos pueden continuar históricos; los retos nuevos exigen ID.
    if latest and json.loads(latest.spec_json).get("activity_id") and body.activity_id is None:
        raise HTTPException(422, "activity_id es obligatorio para este reto")
    if body.activity_id is not None and body.activity_id != expected:
        raise HTTPException(409, "La actividad ya no es la actual de esta sesión")
    if latest and latest.widget_type != body.widget_type and body.event_type != "hintRequested":
        raise HTTPException(422, "El widget no pertenece a la actividad actual")
    check = _scenario_check(db, session_id, body)
    payload = {**body.payload, "activity_id": expected}
    if check:
        payload["server_check"] = check
    db.add(
        models.UiEvent(
            id=body.client_event_id,
            session_id=session_id,
            widget_type=body.widget_type,
            event_type=body.event_type,
            payload_json=json.dumps(payload),
        )
    )
    db.commit()
    # Campo aditivo: solo eventos corregidos por el servidor llevan "check".
    return {"id": body.client_event_id, "deduped": False, **({"check": check} if check else {})}


def _checked_event(body: EventIn) -> bool:
    """Se corrige la entrega del widget y también cada selección intermedia."""
    return body.event_type in (SUBMIT_EVENT.get(body.widget_type), "selectionChanged")


def _scenario_check(db: Session, session_id: str, body: EventIn) -> dict | None:
    """La entrega del último reto GenUI se corrige en el servidor (determinista) contra
    lo que él mismo generó; el cliente no aporta la verdad. Sin reto todavía, se
    corrige la práctica al momento (nunca en la prueba: ahí no hay feedback)."""
    s = db.query(models.LearningSession).filter_by(id=session_id).first()
    if s is None or s.status in ("posttest", "done"):
        return None
    lab_type = _lab_type(db, session_id)
    logs = db.query(models.InterventionLog).filter_by(session_id=session_id).all()
    log = logs[-1] if logs else None  # orden de inserción, como _can_enter_posttest
    # El evento de la práctica lleva su `unit` (el del reto no): con reto abierto,
    # volver al experimento sigue dando corrección inmediata.
    unit = body.payload.get("unit")
    practice = isinstance(unit, str) and DOCKER_WIDGETS.get(unit) == body.widget_type
    if practice or not log or body.widget_type != log.widget_type or not _checked_event(body):
        return check_practice(lab_type, body.widget_type, body.payload)
    attempt = db.query(models.LabAttempt).filter_by(id=log.attempt_id).first()
    if not attempt:
        return None
    try:
        spec = json.loads(log.spec_json)
        state = json.loads(attempt.input_state_json)
    except ValueError:
        return None
    return check_challenge(lab_type, body.widget_type, body.payload,
                           spec if isinstance(spec, dict) else {}, state)


@router.post("/sessions/{session_id}/attempts")
def create_attempt(session_id: str, body: AttemptIn, user=Depends(current_user),
                   db: Session = Depends(get_db)):
    s = session_for_write(user, db, session_id)
    # Docker: una unidad se abre cuando su prerrequisito está completado.
    unit = body.extra.get("unit") if isinstance(body.extra, dict) else None
    if unit and _lab_type(db, session_id) == "docker":
        missing = docker_prereq_missing(db, s.student_id, unit)
        if missing:
            raise HTTPException(403, f"unidad bloqueada: primero completa {missing}")
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


@router.get("/labs/{lab_id}/docker-activity")
def lab_docker_activity(lab_id: str, unit: str, seed: int = 1):
    # Escenario público de la unidad (sin respuestas); semilla 1 = práctica.
    from app.labs_docker import UNITS, activity

    if unit not in UNITS:
        raise HTTPException(404, "unidad desconocida")
    return activity(unit, seed)


@router.get("/me/docker-units")
def my_docker_units(user=Depends(current_user), db: Session = Depends(get_db)):
    """Estado por unidad Docker del estudiante: {unidad: active|posttest|done}."""
    return docker_unit_status(db, user.id)


@router.get("/labs/{lab_id}/distributions")
def lab_distributions(lab_id: str, seed: int = 1):
    # ponytail: verdad (truth) jamás sale al cliente
    ds = generate_monitor(seed)
    return {"lab_id": lab_id, "features": ds["features"], "series": ds["series"],
            "series_by_feature": ds["series_by_feature"]}


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
            "rubric_id": o.rubric_id, "status": o.status}


def _shape_const(o: dict) -> dict:
    # ponytail: una sola forma para filas DB y fallback
    return {**{k: o[k] for k in ("id", "lab_template_id", "title", "level",
                                 "concept_summary", "rubric_id", "status")},
            "worked_example_steps": o["worked_example_steps"],
            "misconceptions": o["misconceptions"]}


@router.get("/labs/{lab_id}/objectives", response_model=list[ObjectiveOut])
def lab_objectives(lab_id: str, db: Session = Depends(get_db)):
    # Sprint 1/3: fallback a constante si aún no se sembró.
    rows = db.query(models.LearningObjective).filter_by(lab_template_id=lab_id).all()
    if rows:
        return [_objective_out(o) for o in rows]
    from app.seed import OBJECTIVES as _OBJS
    matched = [o for o in _OBJS if o["lab_template_id"] == lab_id]
    if not matched:
        raise HTTPException(404, "sin objetivos para ese lab")
    return [_shape_const(o) for o in matched]


@router.post("/labs/{lab_id}/diagnostics", response_model=DiagnosticOut)
def lab_diagnostics(lab_id: str, db: Session = Depends(get_db)):
    # Sprint 1/3: diagnóstico breve (2 ítems equivalentes, sin pistas ni evaluación).
    from app.seed import OBJECTIVES as _OBJS
    bp = None
    row = db.query(models.LearningObjective).filter_by(lab_template_id=lab_id).first()
    if row is not None:
        try:
            bp = json.loads(row.diagnostic_blueprint_json)
        except Exception:
            bp = None
    if bp is None:
        for _o in _OBJS:
            if _o["lab_template_id"] == lab_id:
                bp = _o["diagnostic_blueprint"]
                break
    if bp is None:
        raise HTTPException(404, "sin diagnóstico para ese lab")
    items = bp.get("items", []) if isinstance(bp, dict) else []
    return {"lab_template_id": lab_id,
            "objective_id": row.id if row is not None else next(
                _o["id"] for _o in _OBJS if _o["lab_template_id"] == lab_id),
            "items": items}


@router.get("/sessions/{session_id}/attempts", response_model=list[AttemptOut])
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
    extra: dict = Field(default_factory=dict, max_length=16)


@router.post("/sessions/{session_id}/posttest")
def posttest(session_id: str, body: PosttestIn, user=Depends(current_user),
             db: Session = Depends(get_db)):
    s = session_for_write(user, db, session_id)
    if s.status == "done":
        raise HTTPException(403, "sesión terminada")
    variant = _posttest_variant(session_id)
    # El alumno no entra al postest por payload: el servidor decide (AGENTS §3).
    if not _can_enter_posttest(db, s):
        raise HTTPException(403, "postest aún no habilitado: responde el reto pendiente")
    if s.status == "active":
        s.status = "posttest"
        db.commit()
    if not body.answer_text.strip():
        return {"status": "begin", **variant}
    if _posttest_attempt(db, session_id):
        raise HTTPException(403, "postest ya entregado")
    evidence = {}
    if _lab_type(db, session_id) == "docker":
        from app.labs_docker import response_evidence, UNITS

        practice = _practice_attempts(db, session_id)
        previous = json.loads(practice[-1].input_state_json) if practice else {}
        unit = (previous.get("extra") or {}).get("unit")
        if unit in UNITS:
            if body.extra.get("unit", unit) != unit:
                raise HTTPException(403, "la prueba pertenece a la unidad de la sesión")
            try:
                evidence = response_evidence(unit, variant["seed"], body.extra)
            except ValueError as exc:
                raise HTTPException(422, str(exc)) from exc
    aid = uuid.uuid4().hex[:8]
    attempt = models.LabAttempt(
        id=aid, session_id=session_id,
        input_state_json=json.dumps({"complexity": variant["complexity"],
                                     "noise_pct": variant["noise_pct"],
                                     "seed": variant["seed"], "kind": "posttest",
                                     "extra": evidence}),
        answer_text=body.answer_text)
    db.add(attempt)
    db.commit()
    # P4.2: el postest se evalúa y guarda (comparación honesta), pero no se muestra
    result = _evaluate_attempt(db, s, attempt)
    return {"status": "submitted", "id": aid, **variant, "eval_status": result["status"]}


@router.get("/me/progress", response_model=list[ProgressOut])
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
    s = session_for_write(user, db, session_id)
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
    # Sprint 4: repaso espaciado 1/3/7 días (preguntas nuevas las da la variante).
    import time as _time

    now = int(_time.time())
    obj = db.query(models.LearningObjective).filter_by(
        lab_template_id=s.lab_template_id).first()
    if not db.query(models.RecallItem).filter_by(
            student_id=s.student_id, lab_template_id=s.lab_template_id,
            status="pending").first():
        for days in (1, 3, 7):
            db.add(models.RecallItem(
                id=uuid.uuid4().hex[:8], student_id=s.student_id,
                lab_template_id=s.lab_template_id, objective_id=obj.id if obj else "",
                due_at=now + days * 86400, status="pending", created_at=now))
    db.commit()
    return {"status": "done", "summary": {"mejora": mejora, "desafio": desafio}}


@router.get("/me/recall-due", response_model=list[RecallOut])
def recall_due(user=Depends(current_user), db: Session = Depends(get_db)):
    # Sprint 4: solo vencidos y pendientes, ordenados por fecha.
    import time as _time

    rows = (db.query(models.RecallItem)
            .filter_by(student_id=user.id, status="pending")
            .filter(models.RecallItem.due_at <= int(_time.time()))
            .order_by(models.RecallItem.due_at).all())
    return [{"id": r.id, "lab_template_id": r.lab_template_id,
             "objective_id": r.objective_id, "due_at": r.due_at} for r in rows]


@router.post("/me/recall/{item_id}/done")
def recall_done(item_id: str, user=Depends(current_user),
                db: Session = Depends(get_db)):
    r = db.query(models.RecallItem).filter_by(id=item_id).first()
    if r is None or r.student_id != user.id:
        raise HTTPException(404, "repaso no encontrado")
    r.status = "done"
    db.commit()
    return {"status": "done"}
