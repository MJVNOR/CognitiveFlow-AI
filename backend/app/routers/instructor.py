"""Panel instructor: alumnos, revisiones, matriz, acuerdo, export, backup."""
import csv
import io
import json
import os
import re

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse, PlainTextResponse
from sqlalchemy.orm import Session

from app import models
from app.auth import require_instructor
from app.db import get_db
from app.helpers import _lab_progress
from app.schemas import InstructorSessionOut, MatrixEntryOut, StudentOut

router = APIRouter()


@router.get("/instructor/agreement")
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


@router.get("/instructor/students", response_model=list[StudentOut])
def instructor_students(user=Depends(require_instructor), db: Session = Depends(get_db)):
    rows = db.query(models.User).filter(models.User.role == "student").all()
    return [{"id": u.id, "display_name": u.display_name} for u in rows]


@router.get("/instructor/students/{student_id}/sessions", response_model=list[InstructorSessionOut])
def instructor_sessions(student_id: str, user=Depends(require_instructor),
                        db: Session = Depends(get_db)):
    rows = db.query(models.LearningSession).filter_by(student_id=student_id).all()
    return [{"id": s.id, "lab_template_id": s.lab_template_id, "status": s.status} for s in rows]


@router.get("/instructor/export")
def instructor_export(format: str = "csv", user=Depends(require_instructor),
                      db: Session = Depends(get_db)):
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


@router.get("/instructor/matrix", response_model=list[MatrixEntryOut])
def instructor_matrix(user=Depends(require_instructor), db: Session = Depends(get_db)):
    # P4.4: matriz alumnos × labs con baseline/postest; códigos, nunca nombres aquí.
    users = db.query(models.User).filter(models.User.role == "student").all()
    labs = db.query(models.LabTemplate).order_by(models.LabTemplate.order_index).all()
    code = {}

    def anon(uid: str) -> str:
        return code.setdefault(uid, f"STU-{len(code)+1:02d}")

    return [{"student": anon(u.id), "student_id": u.id,
             "labs": {l.id: _lab_progress(db, u.id, l.id) for l in labs}} for u in users]


@router.get("/instructor/planner-stats")
def instructor_planner_stats(user=Depends(require_instructor), db: Session = Depends(get_db)):
    """Cuántas veces decidió Gemini vs las reglas (y por qué), con latencia, por lab.
    Lee la telemetría que guarda cada intervención; solo lectura."""
    labs = {t.id: t.lab_type for t in db.query(models.LabTemplate).all()}
    sess = {s.id: labs.get(s.lab_template_id, "?")
            for s in db.query(models.LearningSession).all()}
    # Resultado de los retos: el evento de entrega del reto no lleva `unit`
    # (ese campo marca la práctica) y guarda la corrección del servidor.
    outcomes: dict = {}
    for e in db.query(models.UiEvent).all():
        try:
            payload = json.loads(e.payload_json)
        except ValueError:
            continue
        chk = payload.get("server_check") if isinstance(payload, dict) else None
        if not isinstance(chk, dict) or payload.get("unit"):
            continue
        # Solo las decisiones del reto: el feedback de la justificación lista
        # criterios a reforzar y contarlo como «mismo error» sería engañoso.
        if e.event_type == "argumentSubmitted" and not chk.get("item"):
            continue
        outcomes.setdefault(e.session_id, []).append((e.widget_type, bool(chk.get("revisar"))))
    out: dict = {}
    for log in db.query(models.InterventionLog).all():
        try:
            spec = json.loads(log.spec_json)
        except ValueError:
            continue
        if not isinstance(spec, dict):
            continue
        p = spec.get("planner") if isinstance(spec.get("planner"), dict) else {}
        row = out.setdefault(sess.get(log.session_id, "?"),
                             {"total": 0, "gemini": 0, "reglas": 0, "motivos": {}, "ms": [],
                              "variantes_dirigidas": {"total": 0, "error_repetido": 0,
                                                      "resuelto": 0, "sin_entrega": 0}})
        row["total"] += 1
        # ¿La variante dirigida evitó que repitiera el error? Señal exploratoria.
        params = ((spec.get("widget_parameters") or {}).get("parameters") or {})
        if params.get("focus"):
            v = row["variantes_dirigidas"]
            v["total"] += 1
            pend = [o for o in outcomes.get(log.session_id, []) if o[0] == log.widget_type]
            if not pend:
                v["sin_entrega"] += 1
            else:
                v["error_repetido" if pend.pop(0)[1] else "resuelto"] += 1
        row["gemini" if spec.get("decided_by") == "gemini" else "reglas"] += 1
        reason = p.get("outcome", "sin_registro")
        row["motivos"][reason] = row["motivos"].get(reason, 0) + 1
        if isinstance(p.get("ms"), int):
            row["ms"].append(p["ms"])
    for row in out.values():
        if row["variantes_dirigidas"]["total"]:
            row["variantes_dirigidas"]["nota"] = (
                "Exploratorio: cuenta si tras la variante dirigida quedó algo por revisar. "
                "Con pocos estudiantes no mide eficacia.")
        ms = sorted(row.pop("ms"))
        row["latencia_ms"] = ({"mediana": ms[len(ms) // 2], "max": ms[-1], "n": len(ms)}
                              if ms else None)
    return out


@router.get("/instructor/backup")
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
