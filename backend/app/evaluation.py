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

# Jev evalúa los 4 labs con la misma rúbrica de 5 criterios; cambia el tema.
_JEV_TOPIC = {
    "data_detective": "calidad de datos: faltantes, duplicados, unidades, outliers y fuga",
    "model_monitoring": "drift de datos o de concepto y degradación de métricas",
    "docker": "contenedores Docker (imágenes, capas, volúmenes, redes y despliegue)",
}


def jev_questions(lab_type: str = "ml_experiment") -> dict:
    topic = _JEV_TOPIC.get(lab_type)
    if topic is None:
        return JEV_QUESTIONS
    return {
        **JEV_QUESTIONS,
        "exactitud": f"¿La respuesta identifica correctamente el fenómeno ({topic})?",
        "evidencia": "¿La respuesta cita evidencia concreta de lo que hizo u observó en el laboratorio?",
    }


def lab_rubric(lab_type: str) -> str:
    return {"data_detective": DATA_RUBRIC_VERSION, "model_monitoring": MONITOR_RUBRIC_VERSION,
            "docker": DOCKER_RUBRIC_VERSION}.get(lab_type, RUBRIC_VERSION)


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
    # ponytail: raw saneado = solo floats noul por criterio; nada de PII (el state no vuelve)
    safe = {cid: {"noul": float((jev_answers.get(cid) or {}).get("noul", 0.0))}
            for cid in JEV_QUESTIONS}
    return {
        "evaluator": "jev",
        "status": "evaluated",
        "rubric_version": RUBRIC_VERSION,
        "mapping": "noul>=0.75→4, >=0.5→2, else 0 (heurística UI, no calibración)",
        "criteria": [
            {"id": cid, "score": _noul_to_score(safe[cid]["noul"]), "noul": safe[cid]["noul"]}
            for cid in JEV_QUESTIONS
        ],
        "raw_answers": safe,
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


def jev_evaluate(answer_text: str, input_state: dict, lab_type: str = "ml_experiment",
                 facts: str | None = None) -> dict:
    """[facts] = lo que el verificador determinista del servidor comprobó (aciertos
    reales); Jev juzga el razonamiento sabiendo qué decisiones fueron correctas."""
    if facts:
        state = (f"Laboratorio: {lab_type}. Verificado por el servidor: {facts}. "
                 f"answer: {(answer_text or '')[:6000]}")
    else:
        state = (
            f"complexity={input_state.get('complexity')} "
            f"noise={input_state.get('noise_pct')} answer: {(answer_text or '')[:6000]}"
        )
    out = _jev_request(state, jev_questions(lab_type))
    out["rubric_version"] = lab_rubric(lab_type)
    return out


def _jev_request(state: str, questions: dict) -> dict:
    key = _jev_key()
    if not key:
        return _pending("sin JEV_API_KEY")
    body = {
        "model": _jev_model(),
        "state": state,
        "questions": {
            cid: {"type": "noul", "instructions": q} for cid, q in questions.items()
        },
    }
    url = f"{_jev_base()}/v1/systemone"
    headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
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

DOCKER_RUBRIC_VERSION = "docker-mvp-v1"

_DOCKER_LINES = [
    "FROM python:3.12-slim",
    "COPY requirements.txt ./",
    "RUN pip install --no-cache-dir -r requirements.txt",
    "COPY ./app ./app",
]


def _docker_order_ok(order: list) -> bool:
    # ponytail: caché óptima = deps antes que código; comparación por prefijo
    try:
        idx = ["".join(order).find("COPY requirements"), "".join(order).find("RUN pip"),
               "".join(order).find("COPY ./app")]
        if any(i < 0 for i in idx):
            names = [str(x) for x in order]
            i_req = next(i for i, x in enumerate(names) if x.startswith("COPY requirements"))
            i_run = next(i for i, x in enumerate(names) if x.startswith("RUN pip"))
            i_app = next(i for i, x in enumerate(names) if x.startswith("COPY ./app"))
            return i_req < i_run < i_app
        return idx[0] < idx[1] < idx[2]
    except (ValueError, StopIteration, TypeError):
        return False


def mock_evaluate_docker(answer_text: str, extra: dict | None = None, seed: int = 1) -> dict:
    """Rúbrica docker-mvp-v1: checks deterministas por unidad + keywords."""
    extra = extra if isinstance(extra, dict) else {}
    unit = extra.get("unit", "")
    t = (answer_text or "").lower()
    from app import labs_docker

    if unit == "M08-D04-dockerfile":
        bank = labs_docker.dockerfile_ok(extra.get("order", []))
        ok = _docker_order_ok(extra.get("order", [])) if bank is None else bank
        mentions_cache = any(k in t for k in ["cach", "capa", "layer", "orden"])
        mentions_extra = any(k in t for k in ["dockerignore", "expose", "latest", "version"])
        scores = {
            "exactitud": 4 if ok else (2 if extra.get("order") else 0),
            "evidencia": 4 if ok and mentions_cache else (2 if mentions_cache or ok else 0),
            "causal": 2 if mentions_cache and ("porqu" in t or "invalid" in t) else 0,
            "alternativas": 2 if mentions_extra else 0,
            "metacognicion": 2 if "revis" in t or "hipótesis" in t or "hipotesis" in t else 0,
        }
    elif unit == "M08-D07-persistence":
        pred, mount = extra.get("predicted"), extra.get("mount")
        # Verdad del servidor, no la observación que calculó el cliente.
        match = pred is not None and mount in labs_docker.MOUNTS and (
            bool(pred) == (mount != "sin montaje"))
        mentions_mount = any(k in t for k in ["volumen", "volume", "montaje", "mount", "bind"])
        scores = {
            "exactitud": 4 if match else (2 if pred is not None else 0),
            "evidencia": 4 if match and mentions_mount else (2 if mentions_mount or match else 0),
            "causal": 2 if "porqu" in t and mentions_mount else 0,
            "alternativas": 2 if "backup" in t or "sqlite" in t else 0,
            "metacognicion": 2 if "revis" in t or "hipótesis" in t or "hipotesis" in t else 0,
        }
    elif unit == "M08-D01-containers":
        mentions_kernel = any(k in t for k in ["kernel", "aisl", "proceso"])
        mentions_cases = sum(
            1 for k in ["servidor", "reproduc", "driver", "maquina", "pc"] if k in t)
        mentions_limits = any(k in t for k in ["efímero", "efimero", "localhost", "persist"])
        hits = labs_docker.d01_hits(seed, extra.get("choices"))
        scores = {
            "exactitud": (4 if hits == 3 else 2 if hits == 2 else 0) if hits is not None else
            (4 if mentions_kernel and mentions_cases >= 2 else (2 if mentions_kernel else 0)),
            "evidencia": 4 if mentions_cases >= 2 else (2 if mentions_cases >= 1 else 0),
            "causal": 2 if mentions_limits else 0,
            "alternativas": 2 if "vm" in t or "máquina" in t or "maquina" in t else 0,
            "metacognicion": 2 if "revis" in t or "hipótesis" in t or "hipotesis" in t else 0,
        }
    elif unit == "M08-D02-lifecycle":
        stages = sum(1 for k in ["pull", "build", "run", "stop", "rm"] if k in t)
        mentions_survive = any(k in t for k in ["sobreviv", "imagen", "eliminar", "borrar"])
        right = labs_docker.d02_right(seed, extra.get("prediction"))
        scores = {
            "exactitud": (4 if right else 0) if right is not None else
            (4 if stages >= 4 else (2 if stages >= 2 else 0)),
            "evidencia": 4 if stages >= 3 and mentions_survive else (2 if mentions_survive else 0),
            "causal": 2 if "porqu" in t and mentions_survive else 0,
            "alternativas": 2 if "volumen" in t or "volume" in t else 0,
            "metacognicion": 2 if "revis" in t or "hipótesis" in t or "hipotesis" in t else 0,
        }
    elif unit in labs_docker.DECISION_UNITS:
        # Exactitud = decisiones correctas contra la verdad del servidor (no keywords).
        hits = labs_docker.decision_hits(unit, seed, extra.get("choices"))
        ratio = hits[0] / hits[1] if hits else 0
        why = "porqu" in t or "por qu" in t or "debido" in t
        scores = {
            "exactitud": 4 if ratio >= 0.99 else (2 if ratio >= 0.5 else 0),
            "evidencia": 4 if hits and why and len(t) > 80 else (2 if why or hits else 0),
            "causal": 2 if why else 0,
            "alternativas": 2 if any(k in t for k in ["en vez", "alternativ", "en lugar"]) else 0,
            "metacognicion": 2 if "revis" in t or "hipótesis" in t or "hipotesis" in t else 0,
        }
    else:
        mentions = any(k in t for k in ["docker", "contenedor", "imagen", "volumen", "puerto"])
        scores = {c: (2 if mentions else 0) for c in
                  ["exactitud", "evidencia", "causal", "alternativas", "metacognicion"]}
    return {
        "evaluator": "mock",
        "status": "evaluated",
        "rubric_version": DOCKER_RUBRIC_VERSION,
        "criteria": [{"id": k, "score": v} for k, v in scores.items()],
        "feedback_generated_by": "mock",
    }


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


def _true_row_type(rows: list, rid: int) -> str:
    # ponytail: mismas reglas que generate(); el frontend las duplica para simular
    r = rows[rid]
    if r.get("pressure") is None:
        return "missing"
    if r.get("unit") == "F":
        return "unit"
    if r.get("pressure") == 999.9:
        return "outlier"
    if r.get("temp") == -273.2:
        return "leak"
    base = {k: r[k] for k in ("temp", "unit", "pressure", "line")}
    for i, o in enumerate(rows):
        if i != rid and all(o.get(k) == v for k, v in base.items()):
            return "duplicate"
    return "ok"


def mock_evaluate_data(answer_text: str, flags: list, seed: int = 1,
                       extra: dict | None = None) -> dict:
    """Rúbrica data-cleaning-v1: checks deterministas + keywords. Etiquetado mock."""
    from app.labs_data import generate

    planted = set(generate(seed)["planted"])
    rows_all = generate(seed)["rows"]
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
        "detail": _data_type_detail(rows_all, flags, extra),
    }


def _data_type_detail(rows: list, flags: list, extra: dict | None) -> dict:
    """Sprint 3: acierto por tipo declarado vs real (inspector por celda)."""
    claimed = {}
    if isinstance(extra, dict):
        ct = extra.get("cell_types", {})
        if isinstance(ct, dict):
            claimed = {str(k): v for k, v in ct.items()}
    types = {}
    for rid in flags or []:
        try:
            i = int(rid)
        except (TypeError, ValueError):
            continue
        if not 0 <= i < len(rows):
            continue
        actual = _true_row_type(rows, i)
        c = claimed.get(str(i))
        types[str(i)] = {"claimed": c, "actual": actual,
                         "ok": c == actual and actual != "ok"}
    actions = extra.get("actions", {}) if isinstance(extra, dict) else {}
    return {"types": types, "types_ok": sum(1 for t in types.values() if t["ok"]),
            "actions": actions if isinstance(actions, dict) else {}}


def verified_facts(lab_type: str, state: dict) -> str | None:
    """Hechos que el servidor comprueba solo (verdad de sus generadores) para Jev."""
    extra = state.get("extra") if isinstance(state.get("extra"), dict) else {}
    seed = state.get("seed", 1)
    if lab_type == "docker":
        from app import labs_docker

        unit = extra.get("unit", "")
        c = labs_docker.check(unit, seed, extra) or {}
        return (f"unidad {unit}; decisiones correctas: {c.get('correctas', [])}; "
                f"decisiones incorrectas: {c.get('revisar', [])}")
    if lab_type == "data_detective":
        from app.labs_data import generate

        planted, flags = set(generate(seed)["planted"]), set(state.get("flags") or [])
        return (f"marcó {len(flags)} filas; {len(planted & flags)} de {len(planted)} "
                f"anomalías reales encontradas; {len(flags - planted)} filas sanas marcadas")
    if lab_type == "model_monitoring":
        from app.labs_monitor import generate

        truth = generate(seed)["truth"]
        try:
            cp_err = abs(int(extra.get("changepoint", -1)) - truth["changepoint"])
        except (TypeError, ValueError):
            cp_err = None
        ok = extra.get("feature") == truth["drifted_feature"]
        return (f"feature con drift {'correcta' if ok else 'incorrecta'}; "
                f"error del changepoint: {cp_err if cp_err is not None else 'sin marcar'} pasos")
    return None


def data_type_detail(state: dict) -> dict:
    """Acierto por tipo (inspector por celda) también cuando evalúa Jev."""
    from app.labs_data import generate

    return _data_type_detail(generate(state.get("seed", 1))["rows"], state.get("flags") or [],
                             state.get("extra"))
