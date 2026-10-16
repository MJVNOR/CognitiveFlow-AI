import json
import os
import uuid
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db import get_db
from app import models
from app.seed import init_db, seed_if_empty
from app.labs_ml import ml_curve
from app.evaluation import mock_evaluate, mock_evaluate_data, mock_evaluate_monitor, jev_evaluate
from app.labs_data import generate as generate_dataset
from app.labs_monitor import generate as generate_monitor
from app.socratic import socratic_question
from app.interventions import select_intervention, validate_ui_spec, safe_intervention, CATALOG
from app.interventions import SCHEMA_VERSION, ALLOWED_EVENTS, ALLOWED_BY_WIDGET
from app.auth import current_user, require_instructor, session_for, new_token

load_dotenv()


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    seed_if_empty()
    yield


app = FastAPI(title="CognitiveFlow AI", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o for o in os.getenv(
        "CORS_ORIGINS", "http://localhost:8080,http://127.0.0.1:8080").split(",") if o],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/v1/models")
def list_models():
    # Espejo solo-lectura del catálogo Gemini (0 tokens): silencia sondeos OpenAI-style.
    import httpx

    key = os.getenv("GEMINI_API_KEY", "") or os.getenv("GOOGLE_API_KEY", "")
    if not key:
        return {"data": []}
    try:
        r = httpx.get(
            "https://generativelanguage.googleapis.com/v1beta/models",
            headers={"x-goog-api-key": key},
            timeout=20,
        )
        r.raise_for_status()
        return {"data": [{"id": m.get("name", "").replace("models/", "")}
                         for m in r.json().get("models", [])]}
    except Exception:
        return {"data": []}


@app.get("/modules")
def list_modules(db: Session = Depends(get_db)):
    rows = db.query(models.Module).order_by(models.Module.order_index).all()
    return [{"id": m.id, "title": m.title, "order_index": m.order_index} for m in rows]


@app.get("/labs")
def list_labs(db: Session = Depends(get_db)):
    rows = db.query(models.LabTemplate).order_by(models.LabTemplate.order_index).all()
    return [{"id": l.id, "title": l.title, "lab_type": l.lab_type,
             "description": l.description or "", "order_index": l.order_index,
             "module_id": l.module_id or ""} for l in rows]


@app.get("/me/lab-status")
def my_lab_status(user=Depends(current_user), db: Session = Depends(get_db)):
    # Última sesión por lab (orden de inserción); sin sesiones → {}.
    status = {}
    for s in db.query(models.LearningSession).filter_by(student_id=user.id).all():
        status[s.lab_template_id] = s.status
    return status


@app.get("/instructor/students")
def instructor_students(user=Depends(require_instructor), db: Session = Depends(get_db)):
    rows = db.query(models.User).filter(models.User.role == "student").all()
    return [{"id": u.id, "display_name": u.display_name} for u in rows]


class LoginIn(BaseModel):
    user_id: str


@app.post("/auth/login")
def login(body: LoginIn, db: Session = Depends(get_db)):
    # Demo piloto: user_id de seed (s1-s4, i1). Sin passwords (ver app/auth.py).
    user = db.query(models.User).filter_by(id=body.user_id, active=1).first()
    if not user:
        from fastapi import HTTPException

        raise HTTPException(401, "usuario desconocido")
    return {"token": new_token(db, user.id), "role": user.role, "user_id": user.id}


@app.get("/auth/me")
def me(user=Depends(current_user)):
    return {"user_id": user.id, "role": user.role, "display_name": user.display_name}


@app.get("/instructor/students/{student_id}/sessions")
def instructor_sessions(student_id: str, user=Depends(require_instructor),
                        db: Session = Depends(get_db)):
    rows = db.query(models.LearningSession).filter_by(student_id=student_id).all()
    return [{"id": s.id, "lab_template_id": s.lab_template_id, "status": s.status} for s in rows]


class ReviewIn(BaseModel):
    rubric_scores: dict = {}
    notes: str = ""


@app.post("/instructor/attempts/{attempt_id}/reviews")
def create_review(attempt_id: str, body: ReviewIn, user=Depends(require_instructor),
                 db: Session = Depends(get_db)):
    attempt = db.query(models.LabAttempt).filter_by(id=attempt_id).first()
    if not attempt:
        from fastapi import HTTPException

        raise HTTPException(404, "attempt not found")
    # ponytail: append-only; jamás modifica evaluation_results
    for cid, score in body.rubric_scores.items():
        if not isinstance(score, int) or not 0 <= score <= 4:
            from fastapi import HTTPException

            raise HTTPException(422, f"score inválido en {cid}: 0-4")
    rid = uuid.uuid4().hex[:8]
    db.add(models.InstructorReview(id=rid, attempt_id=attempt_id, instructor_id=user.id,
                                   rubric_scores_json=json.dumps(body.rubric_scores),
                                   notes=body.notes))
    db.commit()
    return {"id": rid}


@app.get("/instructor/export")
def instructor_export(format: str = "csv", user=Depends(require_instructor),
                      db: Session = Depends(get_db)):
    from fastapi.responses import PlainTextResponse
    import csv
    import io

    # ponytail: anonimizado — códigos, nunca nombres
    code = {}
    def anon(uid: str) -> str:
        return code.setdefault(uid, f"STU-{len(code)+1:02d}")

    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["student", "session", "lab", "attempt", "evaluator", "criterion", "score",
                "reviewer_score"])
    for s in db.query(models.LearningSession).all():
        for a in db.query(models.LabAttempt).filter_by(session_id=s.id).all():
            evs = db.query(models.EvaluationResult).filter_by(attempt_id=a.id).all()
            revs = db.query(models.InstructorReview).filter_by(attempt_id=a.id).all()
            rmap = {}
            for r in revs:
                rmap.update(json.loads(r.rubric_scores_json))
            crits = [c for ev in evs for c in json.loads(ev.normalized_scores_json).get("criteria", [])]
            if not crits:
                w.writerow([anon(s.student_id), s.id, s.lab_template_id, a.id, "", "", "", ""])
            for c in crits:
                w.writerow([anon(s.student_id), s.id, s.lab_template_id, a.id,
                            (evs[0].evaluator if evs else ""), c.get("id"), c.get("score"),
                            rmap.get(c.get("id"), "")])
    return PlainTextResponse(buf.getvalue(), media_type="text/csv")


class SessionIn(BaseModel):
    student_id: str = "s1"
    lab_template_id: str = "lab-ml"


@app.post("/sessions")
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


@app.get("/sessions/{session_id}")
def get_session(session_id: str, user=Depends(current_user), db: Session = Depends(get_db)):
    s = session_for(user, db, session_id)
    attempts = _practice_attempts(db, session_id)
    return {"id": s.id, "student_id": s.student_id, "lab_template_id": s.lab_template_id,
            "status": s.status, "phase": _phase(db, s), "attempt_count": len(attempts)}


MAX_REVISIONS = 6  # P3.5: tope de ciclos evaluar→intervenir por sesión; luego postest


def _practice_attempts(db: Session, session_id: str) -> list:
    # ponytail: O(n) scan; 4 alumnos, sesiones cortas
    out = []
    for a in db.query(models.LabAttempt).filter_by(session_id=session_id).all():
        try:
            kind = json.loads(a.input_state_json).get("kind", "")
        except Exception:
            kind = ""
        if kind != "posttest":
            out.append(a)
    return out


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


@app.get("/sessions/{session_id}/tutor-history")
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


@app.get("/labs/{lab_id}/curve")
def lab_curve(lab_id: str, complexity: int = 5, noise_pct: int = 20, seed: int = 1):
    # ponytail: solo ml_experiment por ahora, otros labs devuelven misma forma
    return {"lab_id": lab_id, **ml_curve(complexity, noise_pct, seed)}


class AttemptIn(BaseModel):
    complexity: int = 5
    noise_pct: int = 20
    seed: int = 1
    answer_text: str = ""
    flags: list = []  # ids de filas marcadas (Data Detective)
    extra: dict = {}  # monitor: {feature, changepoint}


class EventIn(BaseModel):
    client_event_id: str
    widget_type: str
    event_type: str
    payload: dict = {}


@app.post("/sessions/{session_id}/events")
def record_event(session_id: str, body: EventIn, user=Depends(current_user),
                 db: Session = Depends(get_db)):
    # P1.5: canal bidireccional — ownership primero, nunca score/cliente como verdad.
    session_for(user, db, session_id)
    if body.widget_type not in CATALOG:
        from fastapi import HTTPException

        raise HTTPException(422, f"widget_type desconocido: {body.widget_type}")
    if body.event_type not in ALLOWED_EVENTS:
        from fastapi import HTTPException

        raise HTTPException(422, f"event_type desconocido: {body.event_type}")
    if body.event_type not in ALLOWED_BY_WIDGET.get(body.widget_type, []):
        from fastapi import HTTPException

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


@app.post("/sessions/{session_id}/attempts")
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


@app.get("/labs/{lab_id}/dataset")
def lab_dataset(lab_id: str, seed: int = 1):
    # ponytail: plantados jamás salen al cliente
    ds = generate_dataset(seed)
    return {"lab_id": lab_id, "columns": ds["columns"], "rows": ds["rows"]}


@app.get("/labs/{lab_id}/distributions")
def lab_distributions(lab_id: str, seed: int = 1):
    # ponytail: verdad (truth) jamás sale al cliente
    ds = generate_monitor(seed)
    return {"lab_id": lab_id, "features": ds["features"], "series": ds["series"]}


@app.get("/sessions/{session_id}/attempts")
def list_attempts(session_id: str, user=Depends(current_user), db: Session = Depends(get_db)):
    session_for(user, db, session_id)
    rows = db.query(models.LabAttempt).filter_by(session_id=session_id).all()
    return [
        {"id": a.id, "input": json.loads(a.input_state_json), "answer": a.answer_text}
        for a in rows
    ]


class EvaluateIn(BaseModel):
    attempt_id: str


@app.post("/sessions/{session_id}/evaluate")
def evaluate(session_id: str, body: EvaluateIn, user=Depends(current_user),
             db: Session = Depends(get_db)):
    session_for(user, db, session_id)
    attempt = db.query(models.LabAttempt).filter_by(id=body.attempt_id,
                                                    session_id=session_id).first()
    if not attempt:
        from fastapi import HTTPException

        raise HTTPException(404, "attempt not found")
    state = json.loads(attempt.input_state_json)
    lab = db.query(models.LearningSession).filter_by(id=session_id).first()
    lab_type = ""
    if lab:
        tpl = db.query(models.LabTemplate).filter_by(id=lab.lab_template_id).first()
        lab_type = tpl.lab_type if tpl else ""
    if lab_type == "data_detective":
        # ponytail: Jev solo en ML por ahora; datos y monitoreo con mock determinista
        result = mock_evaluate_data(attempt.answer_text, state.get("flags", []),
                                    state.get("seed", 1))
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


class SocraticIn(BaseModel):
    attempt_id: str


def _require_active(session) -> None:
    if session.status != "active":
        from fastapi import HTTPException

        raise HTTPException(403, "sesión bloqueada: postest en curso o terminada")


def _lab_type(db: Session, session_id: str) -> str:
    s = db.query(models.LearningSession).filter_by(id=session_id).first()
    if not s:
        return ""
    tpl = db.query(models.LabTemplate).filter_by(id=s.lab_template_id).first()
    return tpl.lab_type if tpl else ""


@app.post("/sessions/{session_id}/socratic")
async def socratic(session_id: str, body: SocraticIn, user=Depends(current_user),
             db: Session = Depends(get_db)):
    _require_active(session_for(user, db, session_id))
    attempt = db.query(models.LabAttempt).filter_by(id=body.attempt_id,
                                                    session_id=session_id).first()
    if not attempt:
        from fastapi import HTTPException

        raise HTTPException(404, "attempt not found")
    ev = (
        db.query(models.EvaluationResult)
        .filter_by(attempt_id=attempt.id)
        .order_by(models.EvaluationResult.id.desc())
        .first()
    )
    weak = []
    if ev:
        for c in json.loads(ev.normalized_scores_json).get("criteria", []):
            if c.get("score", 0) <= 2:
                weak.append(c["id"])
    q = await socratic_question(attempt.answer_text, weak, _lab_type(db, session_id))
    # P3.3: la pregunta queda en ui_events → historial por sesión sin tabla nueva
    db.add(models.UiEvent(id=uuid.uuid4().hex[:8], session_id=session_id,
                          widget_type="SocraticQuestionCard", event_type="hintRequested",
                          payload_json=json.dumps({"question": q["question"],
                                                   "provider": q.get("provider", "?")})))
    db.commit()
    return q


@app.post("/sessions/{session_id}/next-intervention")
async def next_intervention(session_id: str, body: SocraticIn, user=Depends(current_user),
                      db: Session = Depends(get_db)):
    # ponytail: intervenciones no persistidas aún; deuda explícita (audit trail F5)
    _require_active(session_for(user, db, session_id))
    attempt = db.query(models.LabAttempt).filter_by(id=body.attempt_id,
                                                    session_id=session_id).first()
    if not attempt:
        from fastapi import HTTPException

        raise HTTPException(404, "attempt not found")
    if len(_practice_attempts(db, session_id)) > MAX_REVISIONS:
        return await safe_intervention(
            f"Límite de {MAX_REVISIONS} revisiones alcanzado; ve al postest")
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
    )
    spec = intervention["widget_parameters"]
    errors = validate_ui_spec(
        {"widget_type": spec.get("type"), "widget_parameters": spec.get("parameters", {})}
    )
    if errors or intervention["widget_type"] not in CATALOG:
        return await safe_intervention(f"ui_spec inválida: {errors}")
    # P1.1: contrato versionado — el cliente valida tipo, versión y eventos.
    intervention["schema_version"] = SCHEMA_VERSION
    intervention["allowed_events"] = ALLOWED_BY_WIDGET.get(intervention["widget_type"], [])
    return intervention


class PosttestIn(BaseModel):
    complexity: int = 5
    noise_pct: int = 20
    answer_text: str = ""


POSTTEST_SEED = 99  # variante equivalente, distinta del seed de práctica (1)


@app.post("/sessions/{session_id}/posttest")
def posttest(session_id: str, body: PosttestIn, user=Depends(current_user),
             db: Session = Depends(get_db)):
    s = session_for(user, db, session_id)
    if s.status != "active":
        from fastapi import HTTPException

        raise HTTPException(403, "postest ya iniciado o sesión terminada")
    s.status = "posttest"
    aid = uuid.uuid4().hex[:8]
    db.add(
        models.LabAttempt(
            id=aid,
            session_id=session_id,
            input_state_json=json.dumps(
                {
                    "complexity": body.complexity,
                    "noise_pct": body.noise_pct,
                    "seed": POSTTEST_SEED,
                    "kind": "posttest",
                }
            ),
            answer_text=body.answer_text,
        )
    )
    db.commit()
    return {"id": aid, "seed": POSTTEST_SEED}


class ReflectionIn(BaseModel):
    text: str


@app.post("/sessions/{session_id}/reflection")
def reflection(session_id: str, body: ReflectionIn, user=Depends(current_user),
               db: Session = Depends(get_db)):
    s = session_for(user, db, session_id)
    if s.status != "posttest":
        from fastapi import HTTPException

        raise HTTPException(403, "reflexión solo tras el postest")
    s.status = "done"
    db.add(models.Reflection(id=uuid.uuid4().hex[:8], session_id=session_id, text=body.text))
    db.commit()
    return {"status": "done"}
