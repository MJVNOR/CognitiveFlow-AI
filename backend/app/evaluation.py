"""Rúbrica overfitting v1 + evaluadores mock/Jev (etiquetados).

Proveedor Jev: jev-api.org (doc: https://jev-api.org/jev-python, 2026-10-09).
POST {base}/v1/systemone con {model, state, questions}; claves JEV_API_KEY
o TYPESAFE_API_KEY (dashboard jev-api.org, no valen las de TypeSafe console).
Sin key o ante cualquier fallo: pending con criteria [], jamás scores.
"""
import os
import time

import httpx

RUBRIC_VERSION = "ml-overfitting-v1"
DATA_RUBRIC_VERSION = "data-cleaning-v1"
JEV_UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) CognitiveFlow/0.1"}
JEV_MODEL_DEFAULT = "jev-latest"  # default del proveedor; override con JEV_MODEL


def _jev_key() -> str:
    return os.getenv("JEV_API_KEY", "") or os.getenv("TYPESAFE_API_KEY", "")


def _jev_base() -> str:
    return (
        os.getenv("JEV_BASE_URL", "")
        or os.getenv("TYPESAFE_BASE_URL", "")
        or "https://jev-api.org"
    ).rstrip("/")


def _jev_model() -> str:
    return (
        os.getenv("JEV_MODEL", "")
        or os.getenv("TYPESAFE_DEFAULT_MODEL", "")
        or JEV_MODEL_DEFAULT
    )

# E4: cada criterio → una pregunta noul (5 ≤ límite 8 de Jev)
JEV_QUESTIONS = {
    "exactitud": "¿La respuesta identifica correctamente el fenómeno (overfitting/generalización)?",
    "evidencia": "¿La respuesta cita evidencia concreta (curvas, datos, parámetros)?",
    "causal": "¿La respuesta explica la relación causa-efecto?",
    "alternativas": "¿La respuesta considera alternativas o mitigaciones?",
    "metacognicion": "¿La respuesta revisa o corrige su hipótesis inicial?",
}


def mock_evaluate(answer_text: str, complexity: int = 5) -> dict:
    t = (answer_text or "").lower()
    uses_val = any(k in t for k in ["valid", "generaliz", "overfit", "sobreajust", "test"])
    evidence = any(k in t for k in ["curva", "dato", "epoch", "ruido", "complejidad"])
    causal = any(k in t for k in ["porque", "por qué", "debido", "relación", "causa"])
    scores = {
        "exactitud": 4 if uses_val and "overfit" in t else (2 if uses_val else 0),
        "evidencia": 4 if evidence and uses_val else (2 if evidence else 0),
        "causal": 2 if causal else 0,
        "alternativas": 2 if "alternativ" in t or "mitig" in t else 0,
        "metacognicion": 2 if "revis" in t or "hipótesis" in t or "hipotesis" in t else 0,
    }
    return {
        "evaluator": "mock",
        "status": "evaluated",
        "rubric_version": RUBRIC_VERSION,
        "criteria": [{"id": k, "score": v} for k, v in scores.items()],
        "feedback_generated_by": "mock",
    }


def _noul_to_score(p: float) -> int:
    # ponytail: heurística explícita solo para UI comparable; no es calibración 0-4
    return 4 if p >= 0.75 else (2 if p >= 0.5 else 0)


def jev_to_internal(jev_answers: dict) -> dict:
    return {
        "evaluator": "jev",
        "status": "evaluated",
        "rubric_version": RUBRIC_VERSION,
        "mapping": "noul>=0.75→4, >=0.5→2, else 0 (heurística UI, no calibración)",
        "criteria": [
            {
                "id": cid,
                "score": _noul_to_score(float((jev_answers.get(cid) or {}).get("noul", 0.0))),
                "noul": float((jev_answers.get(cid) or {}).get("noul", 0.0)),
            }
            for cid in JEV_QUESTIONS
        ],
        "feedback_generated_by": None,
    }


def _pending(reason: str) -> dict:    # Nunca puntuar ante fallo: pending/error sin scores
    return {
        "evaluator": "jev",
        "status": "pending",
        "rubric_version": RUBRIC_VERSION,
        "reason": reason,
        "requires_review": True,
        "criteria": [],
    }


def jev_evaluate(answer_text: str, input_state: dict) -> dict:
    key = _jev_key()
    if not key:
        return _pending("sin JEV_API_KEY")
    state = (
        f"complexity={input_state.get('complexity')} "
        f"noise={input_state.get('noise_pct')} answer: {(answer_text or '')[:6000]}"
    )
    body = {
        "model": _jev_model(),
        "state": state,
        "questions": {
            cid: {"type": "noul", "instructions": q} for cid, q in JEV_QUESTIONS.items()
        },
    }
    url = f"{_jev_base()}/v1/systemone"
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json", **JEV_UA}
    # ponytail: sin sleep entre reintentos; el endpoint es síncrono y bloquea el worker.
    last = "error desconocido"
    start = time.monotonic()
    for _ in (0, 1):
        try:
            r = httpx.post(url, headers=headers, json=body, timeout=25)
            if r.status_code in (429, 502):
                last = f"Jev {r.status_code}: transitorio, reintentable"
                continue
            if r.status_code == 401:
                return _pending("Jev 401: API key ausente o rechazada")
            if r.status_code == 402:
                return _pending("Jev 402: sin créditos")
            if r.status_code == 422:
                return _pending("Jev 422: cuerpo inválido")
            r.raise_for_status()
            out = jev_to_internal(r.json()["answers"])
            out["provider"] = "jev-api.org"
            out["model"] = _jev_model()
            out["latency_ms"] = int((time.monotonic() - start) * 1000)
            return out
        except (httpx.TimeoutException, httpx.ConnectError) as e:
            last = f"{type(e).__name__} (transitorio)"
            continue
        except Exception as e:
            return _pending(f"{type(e).__name__}")
    return _pending(last)


MONITOR_RUBRIC_VERSION = "drift-v1"


def mock_evaluate_monitor(answer_text: str, extra: dict, seed: int = 1) -> dict:
    """Rúbrica drift-v1: checks deterministas (feature + changepoint) + keywords."""
    from app.labs_monitor import generate

    truth = generate(seed)["truth"]
    extra = extra or {}
    feat_ok = extra.get("feature") == truth["drifted_feature"]
    try:
        cp_err = abs(int(extra.get("changepoint", -1)) - truth["changepoint"])
    except (TypeError, ValueError):
        cp_err = 999
    t = (answer_text or "").lower()
    mentions_drift = any(k in t for k in ["drift", "deriva", "desviación", "desviacion", "cambio"])
    mentions_ref = any(k in t for k in ["referencia", "reference", "compar", "histograma"])
    mentions_kind = any(k in t for k in ["concept", "concepto", "distribu"])
    mentions_action = any(k in t for k in ["reentren", "retrain", "monitore", "monitor", "alerta", "umbral"])
    scores = {
        # ponytail: verdad conocida en simulación; en producción sería revisión humana
        "exactitud": 4 if feat_ok and cp_err <= 15 else (2 if feat_ok else 0),
        "evidencia": 4 if mentions_ref and feat_ok else (2 if mentions_ref or feat_ok else 0),
        "causal": 2 if mentions_kind else 0,
        "alternativas": 2 if mentions_action else 0,
        "metacognicion": 2 if "revis" in t or "hipótesis" in t or "hipotesis" in t else 0,
    }
    return {
        "evaluator": "mock",
        "status": "evaluated",
        "rubric_version": MONITOR_RUBRIC_VERSION,
        "criteria": [{"id": k, "score": v} for k, v in scores.items()],
        "feedback_generated_by": "mock",
    }


def mock_evaluate_data(answer_text: str, flags: list, seed: int = 1) -> dict:
    """Rúbrica data-cleaning-v1: checks deterministas + keywords. Etiquetado mock."""
    from app.labs_data import generate

    planted = set(generate(seed)["planted"])
    flagged = set(flags or [])
    hits = len(planted & flagged)
    t = (answer_text or "").lower()
    mentions_missing = any(k in t for k in ["faltante", "nulo", "vacío", "vacio", "missing", "null"])
    mentions_dup = any(k in t for k in ["duplicado", "repetid", "duplicate"])
    mentions_unit = any(k in t for k in ["unidad", "fahrenheit", "grados", "unit"])
    mentions_out = any(k in t for k in ["atípico", "atipico", "outlier", "anomal"])
    mentions_leak = any(k in t for k in ["fuga", "leak", "futur"])
    mentions = sum([mentions_missing, mentions_dup, mentions_unit, mentions_out, mentions_leak])
    scores = {
        # ponytail: detección exacta posible aquí (plantados conocidos), no estimar
        "exactitud": 4 if hits >= 4 else (2 if hits >= 2 else 0),
        "evidencia": 4 if hits >= 3 and mentions >= 2 else (2 if hits >= 1 else 0),
        "causal": 2 if mentions_unit or mentions_out else 0,
        "alternativas": 2 if mentions_leak or "imput" in t else 0,
        "metacognicion": 2 if "revis" in t or "hipótesis" in t or "hipotesis" in t else 0,
    }
    return {
        "evaluator": "mock",
        "status": "evaluated",
        "rubric_version": DATA_RUBRIC_VERSION,
        "criteria": [{"id": k, "score": v} for k, v in scores.items()],
        "feedback_generated_by": "mock",
    }
