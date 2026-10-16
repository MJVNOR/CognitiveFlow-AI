import hashlib
import json
import os
import re
import time
import uuid
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import httpx
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from app.db import ensure_columns, get_db
from app import models
from app.seed import init_db, seed_if_empty
from app.labs_ml import ml_curve
from app.evaluation import mock_evaluate, mock_evaluate_data, mock_evaluate_monitor, jev_evaluate
from app.labs_data import generate as generate_dataset
from app.labs_monitor import generate as generate_monitor
from app.socratic import socratic_question, feedback_text
from app.interventions import select_intervention, validate_ui_spec, safe_intervention, CATALOG
from app.interventions import SCHEMA_VERSION, ALLOWED_EVENTS, ALLOWED_BY_WIDGET
from app.auth import current_user, require_instructor, session_for, new_token, revoke_token

load_dotenv()


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    ensure_columns()
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


@app.get("/me/sessions")
def my_sessions(lab_template_id: str = "", user=Depends(current_user),
                db: Session = Depends(get_db)):
    # P1.6: reanudar — última sesión propia por lab, con fase (sin gastar re-evaluar).
    q = db.query(models.LearningSession).filter_by(student_id=user.id)
    if lab_template_id:
        q = q.filter_by(lab_template_id=lab_template_id)
    return [{"id": s.id, "lab_template_id": s.lab_template_id, "status": s.status,
             "phase": _phase(db, s)} for s in q.all()]


@app.get("/sessions/{session_id}/interventions")
def session_interventions(session_id: str, user=Depends(current_user),
                          db: Session = Depends(get_db)):
    # F5: audit trail legible (estrategia por intento); ownership primero.
    session_for(user, db, session_id)
    rows = db.query(models.InterventionLog).filter_by(session_id=session_id).all()
    return [{"attempt_id": r.attempt_id, "strategy": r.strategy,
             "widget_type": r.widget_type} for r in rows]


@app.get("/instructor/agreement")
def instructor_agreement(user=Depends(require_instructor), db: Session = Depends(get_db)):
    # Calibración: acuerdo Jev vs humano por criterio (la validación real pide piloto).
    out = {}
    for ev in db.query(models.EvaluationResult).filter_by(evaluator="jev",
                                                          status="evaluated").all():
        try:
            crits = json.loads(ev.normalized_scores_json).get("criteria", [])
        except Exception:
            continue
        revs = db.query(models.InstructorReview).filter_by(attempt_id=ev.attempt_id).all()
        if not revs:
            continue
        rmap = {}
        for r in revs:
            try:
                rmap.update(json.loads(r.rubric_scores_json))
            except Exception:
                continue
        for c in crits:
            cid = c.get("id")
            if cid in rmap and isinstance(rmap[cid], int):
                d = out.setdefault(cid, {"n": 0, "exact": 0, "abs": 0})
                d["n"] += 1
                d["exact"] += 1 if rmap[cid] == c.get("score") else 0
                d["abs"] += abs(rmap[cid] - c.get("score", 0))
    return {k: {"n": v["n"], "exact_rate": round(v["exact"] / v["n"], 3),
                "mean_abs_diff": round(v["abs"] / v["n"], 3)} for k, v in out.items()}


@app.get("/instructor/students")
def instructor_students(user=Depends(require_instructor), db: Session = Depends(get_db)):
    rows = db.query(models.User).filter(models.User.role == "student").all()
    return [{"id": u.id, "display_name": u.display_name} for u in rows]


class LoginIn(BaseModel):
    user_id: str


_LOGIN_HITS: dict[str, list] = {}  # ponytail: memoria local, 1 worker demo
LOGIN_MAX_MIN = 10  # P7.1: freno a fuerza bruta en login demo


def _login_allowed(ip: str) -> bool:
    now = time.monotonic()
    hits = [t for t in _LOGIN_HITS.get(ip, []) if now - t < 60]
    _LOGIN_HITS[ip] = hits
    if len(hits) >= LOGIN_MAX_MIN:
        return False
    hits.append(now)
    return True


@app.post("/auth/login")
def login(body: LoginIn, request: Request, db: Session = Depends(get_db)):
    # Demo piloto: user_id de seed (s1-s4, i1). Sin passwords (ver app/auth.py).
    if not _login_allowed(request.client.host if request.client else "?"):
        raise HTTPException(429, "demasiados intentos, espera un minuto")
    user = db.query(models.User).filter_by(id=body.user_id, active=1).first()
    if not user:
        raise HTTPException(401, "usuario desconocido")
    return {"token": new_token(db, user.id), "role": user.role, "user_id": user.id}


_bearer_opt = HTTPBearer(auto_error=False)


@app.delete("/auth/logout")
def logout(creds: HTTPAuthorizationCredentials | None = Depends(_bearer_opt),
           user=Depends(current_user), db: Session = Depends(get_db)):
    if creds:
        revoke_token(db, creds.credentials)
    return {"status": "bye"}


@app.get("/instructor/backup")
def instructor_backup(user=Depends(require_instructor)):
    # P7.2: descarga del sqlite para backup externo (solo instructor).
    url = os.getenv("DATABASE_URL", "sqlite:///./cognitiveflow.db")
    if not url.startswith("sqlite://"):
        raise HTTPException(404, "backup solo para sqlite en archivo")
    path = re.sub(r"^/([A-Za-z]:/)", r"\1", url[len("sqlite://"):])
    if path.startswith("/./"):
        path = path[1:]
    if not path or not os.path.isfile(path):
        raise HTTPException(404, "sin archivo de respaldo")
    return FileResponse(path, filename="cognitiveflow-backup.db")


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
    notes: str = Field(default="", max_length=2000)


@app.post("/instructor/attempts/{attempt_id}/reviews")
def create_review(attempt_id: str, body: ReviewIn, user=Depends(require_instructor),
                 db: Session = Depends(get_db)):
    attempt = db.query(models.LabAttempt).filter_by(id=attempt_id).first()
    if not attempt:
        raise HTTPException(404, "attempt not found")
    # ponytail: append-only; jamás modifica evaluation_results
    for cid, score in body.rubric_scores.items():
        if not isinstance(score, int) or not 0 <= score <= 4:
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
    answer_text: str = Field(default="", max_length=6000)  # P7.1: tope de payload
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
        raise HTTPException(404, "attempt not found")
    s = db.query(models.LearningSession).filter_by(id=session_id).first()
    return _evaluate_attempt(db, s, attempt)


def _evaluate_attempt(db: Session, session, attempt) -> dict:
    state = json.loads(attempt.input_state_json)
    lab_type = ""
    if session:
        tpl = db.query(models.LabTemplate).filter_by(id=session.lab_template_id).first()
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


@app.post("/sessions/{session_id}/next-intervention")
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
        db.add(models.InterventionLog(id=uuid.uuid4().hex[:8], session_id=session_id,
                                      attempt_id=attempt.id, strategy=limited["strategy"],
                                      widget_type=limited["widget_type"],
                                      spec_json=json.dumps(limited["widget_parameters"])))
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
    intervention["schema_version"] = SCHEMA_VERSION
    intervention["allowed_events"] = ALLOWED_BY_WIDGET.get(intervention["widget_type"], [])
    # F5: audit trail — qué estrategia se decidió por intento (append-only).
    db.add(models.InterventionLog(id=uuid.uuid4().hex[:8], session_id=session_id,
                                  attempt_id=attempt.id,
                                  strategy=intervention["strategy"],
                                  widget_type=intervention["widget_type"],
                                  spec_json=json.dumps(intervention["widget_parameters"])))
    db.commit()
    return intervention


class PosttestIn(BaseModel):
    complexity: int = 5  # ignorados: la variante la fija el servidor (P4.1)
    noise_pct: int = 20
    answer_text: str = Field(default="", max_length=6000)


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


@app.post("/sessions/{session_id}/posttest")
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


@app.get("/me/progress")
def my_progress(user=Depends(current_user), db: Session = Depends(get_db)):
    # P4.2/P4.3: dominio demostrado (baseline vs postest), no clics ni tiempo.
    labs = db.query(models.LabTemplate).order_by(models.LabTemplate.order_index).all()
    return [{"lab_template_id": l.id, "title": l.title,
             **_lab_progress(db, user.id, l.id)} for l in labs]


@app.get("/instructor/matrix")
def instructor_matrix(user=Depends(require_instructor), db: Session = Depends(get_db)):
    # P4.4: matriz alumnos × labs con baseline/postest; códigos, nunca nombres aquí.
    users = db.query(models.User).filter(models.User.role == "student").all()
    labs = db.query(models.LabTemplate).order_by(models.LabTemplate.order_index).all()
    code = {}
    def anon(uid: str) -> str:
        return code.setdefault(uid, f"STU-{len(code)+1:02d}")

    return [{"student": anon(u.id), "student_id": u.id,
             "labs": {l.id: _lab_progress(db, u.id, l.id) for l in labs}} for u in users]


class ReflectionIn(BaseModel):
    text: str = Field(max_length=2000)


@app.post("/sessions/{session_id}/reflection")
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
