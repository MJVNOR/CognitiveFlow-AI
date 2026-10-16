from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
import pytest
from app.main import app
from app.db import Base, get_db
from app.labs_ml import ml_curve
from app.evaluation import JEV_QUESTIONS


@pytest.fixture(autouse=True)
def _no_live_llm(monkeypatch):
    # Los tests nunca gastan llamadas reales a Gemini
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)

engine = create_engine(
    "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
)
TestingSession = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)
Base.metadata.create_all(bind=engine)


def _override():
    db = TestingSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = _override

from app import models  # noqa: E402

db = TestingSession()
for mid, title, order in [
    ("m1", "Herramientas de desarrollo", 1),
    ("m2", "Datos y consultas", 2),
    ("m3", "Machine Learning y explicabilidad", 3),
    ("m4", "Deep Learning", 4),
    ("m5", "Modalidades especializadas", 5),
    ("m6", "MLOps, datos y observabilidad", 6),
    ("m7", "Agentes y contexto", 7),
    ("m8", "Proyecto integrador", 8),
]:
    db.add(models.Module(id=mid, title=title, order_index=order))
for uid in ["s1", "s2", "s3", "s4"]:
    db.add(models.User(id=uid, display_name=uid, role="student"))
db.add(models.User(id="i1", display_name="Instructor", role="instructor"))
for lid, title, ltype, mid, order, desc in [
    ("lab-data", "Data Detective", "data_detective", "m2", 1, "datos"),
    ("lab-ml", "ML Experiment Lab", "ml_experiment", "m3", 2, "ml"),
    ("lab-monitor", "Model Monitoring Lab", "model_monitoring", "m6", 3, "monitoreo"),
]:
    db.add(models.LabTemplate(id=lid, title=title, lab_type=ltype,
                              module_id=mid, order_index=order, description=desc))
db.commit()
db.close()

client = TestClient(app)


def _auth(uid: str):
    return {"Authorization": f"Bearer {client.post('/auth/login', json={'user_id': uid}).json()['token']}"}


H_S1 = _auth("s1")
H_S2 = _auth("s2")
H_I1 = _auth("i1")


def test_health():
    assert client.get("/health").json() == {"status": "ok"}


def test_models_mirror_without_key(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    assert client.get("/v1/models").json() == {"data": []}


def test_models_mirror_mocked(monkeypatch):
    import httpx

    class FakeResp:
        def raise_for_status(self):
            pass

        def json(self):
            return {"models": [{"name": "models/gemini-3.8-flash"}]}

    monkeypatch.setenv("GEMINI_API_KEY", "test-key")
    monkeypatch.setattr(httpx, "get", lambda *a, **k: FakeResp())
    assert client.get("/v1/models").json() == {"data": [{"id": "gemini-3.8-flash"}]}


def test_login_and_me():
    me = client.get("/auth/me", headers=H_S1).json()
    assert me == {"user_id": "s1", "role": "student", "display_name": "s1"}
    assert client.get("/auth/me").status_code == 401


def test_modules_from_db():
    assert len(client.get("/modules").json()) == 8


def test_instructor_sees_4_students():
    assert len(client.get("/instructor/students", headers=H_I1).json()) == 4
    assert client.get("/instructor/students", headers=H_S1).status_code == 403


def test_cross_student_session_forbidden():
    sid = client.post("/sessions", json={"lab_template_id": "lab-ml"}, headers=H_S1).json()["id"]
    assert client.get(f"/sessions/{sid}", headers=H_S2).status_code == 403
    assert client.get(f"/sessions/{sid}", headers=H_S1).json()["status"] == "active"
    assert client.get(f"/sessions/{sid}", headers=H_I1).json()["status"] == "active"


# E1: academia viva — labs con descripción, orden y módulo + estado por estudiante
def test_labs_expose_description_order_module():
    labs = client.get("/labs").json()
    assert {l["id"] for l in labs} == {"lab-ml", "lab-data", "lab-monitor"}
    assert all(l["description"] and l["module_id"] for l in labs)
    orders = [l["order_index"] for l in labs]
    assert orders == sorted(orders)


def test_my_lab_status_tracks_session():
    h_s4 = {"Authorization": f"Bearer {client.post('/auth/login', json={'user_id': 's4'}).json()['token']}"}
    assert client.get("/me/lab-status", headers=h_s4).json() == {}
    assert client.get("/me/lab-status").status_code == 401
    sid = client.post("/sessions", json={"lab_template_id": "lab-data"}, headers=h_s4).json()["id"]
    assert client.get("/me/lab-status", headers=h_s4).json() == {"lab-data": "active"}
    client.post(f"/sessions/{sid}/posttest", json={"answer_text": "x"}, headers=h_s4)
    assert client.get("/me/lab-status", headers=h_s4).json() == {"lab-data": "posttest"}


# G1: Data Detective — dataset determinista sin filtrar plantados + rúbrica datos
def _data_session():
    return client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-data"}, headers=H_S1
    ).json()["id"]


def test_dataset_deterministic_and_clean():
    from app.labs_data import generate

    a = client.get("/labs/lab-data/dataset?seed=1").json()
    b = client.get("/labs/lab-data/dataset?seed=1").json()
    assert a["rows"] == b["rows"] and len(a["rows"]) == 30
    assert "planted" not in a
    assert len(generate(1)["planted"]) == 7


def test_data_eval_detects_all_planted():
    from app.labs_data import generate

    sid = _data_session()
    planted = generate(1)["planted"]
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"seed": 1, "flags": planted,
              "answer_text": "Hay faltantes, un duplicado, unidades en fahrenheit, "
                             "un outlier atípico y posible fuga de información futura."},
        headers=H_S1,
    ).json()["id"]
    r = client.post(f"/sessions/{sid}/evaluate", json={"attempt_id": aid}, headers=H_S1).json()
    assert r["rubric_version"] == "data-cleaning-v1"
    assert {c["id"]: c["score"] for c in r["criteria"]}["exactitud"] == 4
    iv = client.post(f"/sessions/{sid}/next-intervention",
                     json={"attempt_id": aid}, headers=H_S1).json()
    assert iv["strategy"] == "transfer"


def test_data_eval_weak_flags_nothing():
    sid = _data_session()
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"seed": 1, "flags": [], "answer_text": "todo bien"},
        headers=H_S1,
    ).json()["id"]
    r = client.post(f"/sessions/{sid}/evaluate", json={"attempt_id": aid}, headers=H_S1).json()
    assert {c["id"]: c["score"] for c in r["criteria"]}["exactitud"] == 0
    iv = client.post(f"/sessions/{sid}/next-intervention",
                     json={"attempt_id": aid}, headers=H_S1).json()
    assert iv["strategy"] == "request_evidence"
    assert iv["widget_type"] == "DataTableExplorer"


# G2: Model Monitoring — distribuciones deterministas + rúbrica drift
def _monitor_session():
    return client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-monitor"}, headers=H_S1
    ).json()["id"]


def test_distributions_deterministic_and_clean():
    from app.labs_monitor import generate

    a = client.get("/labs/lab-monitor/distributions?seed=1").json()
    b = client.get("/labs/lab-monitor/distributions?seed=1").json()
    assert a["series"] == b["series"] and len(a["series"]) == 180
    assert "truth" not in a
    assert generate(1)["truth"] == {"drifted_feature": "temp", "changepoint": 120,
                                    "kind": "data_drift"}


def test_monitor_eval_strong_and_weak():
    sid = _monitor_session()
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"seed": 1, "extra": {"feature": "temp", "changepoint": 118},
              "answer_text": "Hay drift en temp vs referencia; la distribución cambió "
                             "a mitad de la serie. Propongo monitorear con umbral antes "
                             "de reentrenar; reviso mi hipótesis."},
        headers=H_S1,
    ).json()["id"]
    r = client.post(f"/sessions/{sid}/evaluate", json={"attempt_id": aid}, headers=H_S1).json()
    assert r["rubric_version"] == "drift-v1"
    assert {c["id"]: c["score"] for c in r["criteria"]}["exactitud"] == 4
    iv = client.post(f"/sessions/{sid}/next-intervention",
                     json={"attempt_id": aid}, headers=H_S1).json()
    assert iv["widget_type"] == "HypothesisEditor"

    sid2 = _monitor_session()
    aid2 = client.post(
        f"/sessions/{sid2}/attempts",
        json={"seed": 1, "extra": {"feature": "pressure", "changepoint": 10},
              "answer_text": "todo normal"},
        headers=H_S1,
    ).json()["id"]
    r2 = client.post(f"/sessions/{sid2}/evaluate", json={"attempt_id": aid2}, headers=H_S1).json()
    assert {c["id"]: c["score"] for c in r2["criteria"]}["exactitud"] == 0
    iv2 = client.post(f"/sessions/{sid2}/next-intervention",
                      json={"attempt_id": aid2}, headers=H_S1).json()
    assert iv2["widget_type"] == "DriftDistributionExplorer"


def test_curve_reproducible():
    assert ml_curve(5, 20, 1) == ml_curve(5, 20, 1)
    assert ml_curve(5, 20, 1)["simulated"] is True


def test_session_attempt_roundtrip():
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"complexity": 7, "noise_pct": 20, "seed": 1, "answer_text": "overfit?"},
        headers=H_S1,
    ).json()["id"]
    assert aid
    attempts = client.get(f"/sessions/{sid}/attempts", headers=H_S1).json()
    assert len(attempts) == 1 and attempts[0]["answer"] == "overfit?"


def _eval(answer: str):
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"complexity": 7, "noise_pct": 20, "seed": 1, "answer_text": answer},
        headers=H_S1,
    ).json()["id"]
    return client.post(f"/sessions/{sid}/evaluate", json={"attempt_id": aid}, headers=H_S1).json()


def test_weak_vs_strong_scores_differ():
    weak = _eval("no sé")
    strong = _eval(
        "Hay overfit porque la curva de validación sube con complejidad 7, "
        "los datos muestran generalización pobre y propongo mitigar con regularización; "
        "reviso mi hipótesis inicial"
    )
    assert weak["evaluator"] == "mock"
    assert strong["evaluator"] == "mock"
    sw = sum(c["score"] for c in weak["criteria"])
    ss = sum(c["score"] for c in strong["criteria"])
    assert ss > sw


# E4: traducción Jev tipada con HTTP simulado (cero créditos en CI)
def _jev_answers(high: bool):
    p = 0.9 if high else 0.1
    return {cid: {"type": "noul", "noul": p} for cid in JEV_QUESTIONS}


def test_jev_translation_orders_weak_strong():
    from app.evaluation import jev_to_internal

    weak = jev_to_internal(_jev_answers(False))
    strong = jev_to_internal(_jev_answers(True))
    assert weak["evaluator"] == strong["evaluator"] == "jev"
    assert weak["status"] == "evaluated" and weak["feedback_generated_by"] is None
    sw = sum(c["score"] for c in weak["criteria"])
    ss = sum(c["score"] for c in strong["criteria"])
    assert ss > sw


def test_jev_failure_yields_pending(monkeypatch):
    import httpx
    from app.evaluation import jev_evaluate

    monkeypatch.setenv("JEV_API_KEY", "test-key")
    monkeypatch.setattr(
        httpx, "post", lambda *a, **k: (_ for _ in ()).throw(httpx.ConnectError("down"))
    )
    r = jev_evaluate("algo", {"complexity": 5})
    assert r["status"] == "pending" and r["criteria"] == [] and r["requires_review"]


def test_evaluate_jev_mode_without_key_is_pending(monkeypatch):
    monkeypatch.setenv("EVALUATOR_MODE", "jev")
    monkeypatch.delenv("JEV_API_KEY", raising=False)
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"complexity": 5, "noise_pct": 20, "seed": 1, "answer_text": "x"},
        headers=H_S1,
    ).json()["id"]
    r = client.post(f"/sessions/{sid}/evaluate", json={"attempt_id": aid}, headers=H_S1).json()
    assert r["evaluator"] == "jev" and r["status"] == "pending"


# F1: socrático mock por defecto, gemini cuando el REST da 200
def _attempt_with_text(text: str):
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"complexity": 5, "noise_pct": 20, "seed": 1, "answer_text": text},
        headers=H_S1,
    ).json()["id"]
    return sid, aid


def test_socratic_mock_by_default(monkeypatch):
    monkeypatch.delenv("GEMINI_API_KEY", raising=False)
    monkeypatch.delenv("GOOGLE_API_KEY", raising=False)
    sid, aid = _attempt_with_text("no sé")
    r = client.post(f"/sessions/{sid}/socratic", json={"attempt_id": aid}, headers=H_S1).json()
    assert r["provider"] == "mock" and r["question"]


def test_socratic_gemini_when_200(monkeypatch):
    import httpx

    class FakeResp:
        status_code = 200

        def raise_for_status(self):
            pass

        def json(self):
            return {"output_text": "¿Qué ves en validación?"}

    monkeypatch.setenv("GEMINI_API_KEY", "test-key")
    monkeypatch.setattr(httpx, "post", lambda *a, **k: FakeResp())
    sid, aid = _attempt_with_text("no sé")
    r = client.post(f"/sessions/{sid}/socratic", json={"attempt_id": aid}, headers=H_S1).json()
    assert r["provider"] == "gemini" and "validación" in r["question"]


def test_extract_text_from_interaction_steps():
    from app.socratic import _extract_text

    body = {
        "status": "completed",
        "steps": [
            {"type": "thought", "signature": "abc"},
            {"type": "model_output", "content": [{"text": "¿Qué ves?", "type": "text"}]},
        ],
    }
    assert _extract_text(body) == "¿Qué ves?"
    assert _extract_text({"status": "completed", "steps": []}) is None


# F2-F3: débil→evidencia, sólida→transferencia, ambigua→aclarar, spec inválida→fallback
def _intervene(answer: str):
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"complexity": 5, "noise_pct": 20, "seed": 1, "answer_text": answer},
        headers=H_S1,
    ).json()["id"]
    client.post(f"/sessions/{sid}/evaluate", json={"attempt_id": aid}, headers=H_S1)
    return client.post(f"/sessions/{sid}/next-intervention", json={"attempt_id": aid}, headers=H_S1).json()


def test_weak_answer_requests_evidence():
    r = _intervene("no sé")
    assert r["strategy"] == "request_evidence"
    assert r["widget_type"] == "EvidenceComparison"
    assert r["difficulty_delta"] == 0 and not r["give_direct_answer"]


def test_strong_answer_transfers():
    r = _intervene(
        "Hay overfit porque la curva de validación sube con complejidad alta, "
        "los datos muestran generalización pobre y propongo mitigar con regularización; "
        "reviso mi hipótesis inicial"
    )
    assert r["strategy"] == "transfer"
    assert r["difficulty_delta"] == 1


def test_pending_eval_clarifies_without_scores():
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"complexity": 5, "noise_pct": 20, "seed": 1, "answer_text": "x"},
        headers=H_S1,
    ).json()["id"]
    r = client.post(f"/sessions/{sid}/next-intervention", json={"attempt_id": aid}, headers=H_S1).json()
    assert r["strategy"] == "clarify" and "Sin evaluación" in r["reason"]


def test_invalid_spec_rejected():
    from app.interventions import validate_ui_spec

    assert validate_ui_spec({"widget_type": "NoExiste", "widget_parameters": {}})
    assert validate_ui_spec(
        {"widget_type": "EvidenceComparison",
         "widget_parameters": {"complexity": {"min": 1, "max": 10, "initial": 99}}})
    assert validate_ui_spec(
        {"widget_type": "EvidenceComparison",
         "widget_parameters": {"complexity": {"min": 1, "max": 10, "initial": 5}}}) == []


# D4: postest bloqueado (variante nueva, sin tutor) + reflexión honesta
def _practice_attempt(sid: str):
    return client.post(
        f"/sessions/{sid}/attempts",
        json={"complexity": 5, "noise_pct": 20, "seed": 1, "answer_text": "practica"},
        headers=H_S1,
    ).json()["id"]


def test_posttest_locks_session():
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    aid = _practice_attempt(sid)
    pt = client.post(
        f"/sessions/{sid}/posttest",
        json={"complexity": 6, "noise_pct": 20, "answer_text": "postest"},
        headers=H_S1,
    ).json()
    assert pt["seed"] == 99  # variante distinta a práctica (seed 1)
    # Tutor e intervenciones bloqueados durante/tras postest
    assert client.post(f"/sessions/{sid}/socratic", json={"attempt_id": aid}, headers=H_S1).status_code == 403
    assert (
        client.post(f"/sessions/{sid}/next-intervention", json={"attempt_id": aid}, headers=H_S1).status_code
        == 403
    )
    # Segundo postest rechazado
    assert (
        client.post(
            f"/sessions/{sid}/posttest", json={"answer_text": "otro"}, headers=H_S1
        ).status_code
        == 403
    )
    # Reflexión cierra sin inflar logros
    r = client.post(f"/sessions/{sid}/reflection", json={"text": "aprendí X"}, headers=H_S1).json()
    assert r == {"status": "done"}


def test_reflection_only_after_posttest():
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    assert (
        client.post(f"/sessions/{sid}/reflection", json={"text": "x"}, headers=H_S1).status_code == 403
    )


# E5: revisión humana versionada (append-only) + export anonimizado
def test_instructor_review_flow():
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    aid = client.post(
        f"/sessions/{sid}/attempts",
        json={"complexity": 5, "noise_pct": 20, "seed": 1, "answer_text": "x"},
        headers=H_S1,
    ).json()["id"]
    # Estudiante no puede revisar
    assert client.post(
        f"/instructor/attempts/{aid}/reviews",
        json={"rubric_scores": {"exactitud": 2}, "notes": ""}, headers=H_S1).status_code == 403
    # Instructor revisa; score inválido se rechaza
    assert client.post(
        f"/instructor/attempts/{aid}/reviews",
        json={"rubric_scores": {"exactitud": 9}, "notes": ""}, headers=H_I1).status_code == 422
    rid = client.post(
        f"/instructor/attempts/{aid}/reviews",
        json={"rubric_scores": {"exactitud": 2}, "notes": "parcial"}, headers=H_I1).json()["id"]
    assert rid
    # Export sin PII
    csv_text = client.get("/instructor/export?format=csv", headers=H_I1).text
    assert "Alumna" not in csv_text and "s1" not in csv_text and "STU-" in csv_text
    assert client.get("/instructor/export?format=csv", headers=H_S1).status_code == 403


# PR-02 P1.5: eventos UI idempotentes por client_event_id, validados y con ownership
def test_events_idempotent_single_record():
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    body = {"client_event_id": "evt-pr02-1", "widget_type": "LearningCurveSimulator",
            "event_type": "parameterChanged", "payload": {"complexity": 7}}
    r1 = client.post(f"/sessions/{sid}/events", json=body, headers=H_S1).json()
    assert r1 == {"id": "evt-pr02-1", "deduped": False}
    r2 = client.post(f"/sessions/{sid}/events", json=body, headers=H_S1).json()
    assert r2 == {"id": "evt-pr02-1", "deduped": True}
    rows = TestingSession().query(models.UiEvent).filter_by(id="evt-pr02-1").all()
    assert len(rows) == 1 and rows[0].session_id == sid


def test_events_reject_unknown_or_mismatched():
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    base = {"client_event_id": "evt-x", "payload": {}}
    assert client.post(f"/sessions/{sid}/events",
        json={**base, "widget_type": "Nope", "event_type": "hintRequested"},
        headers=H_S1).status_code == 422
    assert client.post(f"/sessions/{sid}/events",
        json={**base, "widget_type": "SocraticQuestionCard", "event_type": "hack"},
        headers=H_S1).status_code == 422
    assert client.post(f"/sessions/{sid}/events",
        json={**base, "widget_type": "SocraticQuestionCard", "event_type": "parameterChanged"},
        headers=H_S1).status_code == 422


def test_events_cross_student_forbidden():
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    assert client.post(f"/sessions/{sid}/events",
        json={"client_event_id": "evt-ajeno", "widget_type": "SocraticQuestionCard",
              "event_type": "hintRequested", "payload": {}},
        headers=H_S2).status_code in (403, 404)


# PR-02 P1.1: contrato versionado en next-intervention
def test_intervention_carries_schema_and_events():
    sid = client.post(
        "/sessions", json={"student_id": "s1", "lab_template_id": "lab-ml"}, headers=H_S1
    ).json()["id"]
    aid = client.post(f"/sessions/{sid}/attempts",
        json={"complexity": 8, "noise_pct": 20, "seed": 1, "answer_text": "creo que sube"},
        headers=H_S1).json()["id"]
    client.post(f"/sessions/{sid}/evaluate", json={"attempt_id": aid}, headers=H_S1)
    iv = client.post(f"/sessions/{sid}/next-intervention",
        json={"attempt_id": aid}, headers=H_S1).json()
    assert iv["schema_version"] == 1
    assert isinstance(iv["allowed_events"], list) and iv["allowed_events"]
