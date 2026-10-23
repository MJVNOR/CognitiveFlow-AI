"""Corrección en el servidor de la entrega de un reto GenUI.
Descriptiva (qué está bien / qué revisar), sin puntajes y sin revelar la
respuesta. La verdad sale de los generadores del servidor, nunca del cliente;
los textos libres los juzga Jev (EVALUATOR_MODE=jev); el mock determinista solo en tests."""
import os

from app import labs_docker
from app.evaluation import (
    mock_evaluate,
    mock_evaluate_data,
    mock_evaluate_docker,
    mock_evaluate_monitor,
)
from app.interventions import DOCKER_WIDGETS, check_data_contrast
from app.socratic import CRITERION_LABELS, criterion_explained

_DATA_TIP = ("Compara su evidencia con las demás y cambia la etiqueta "
             "(o quítala si no hay anomalía); luego reenvía.")


def _text(result: dict, tip: str) -> dict:
    """Criterios de la rúbrica como texto: hasta 2 a reforzar, nunca números."""
    if result.get("status") != "evaluated":  # Jev no respondió: nunca "bien resuelto"
        return {"correctas": [], "revisar": ["tu argumento (el evaluador no respondió; reenvía)"],
                "item": None, "consejo": tip}
    crits = result.get("criteria", [])
    ok = [CRITERION_LABELS.get(c["id"], c["id"]) for c in crits if c.get("score", 0) >= 3]
    weak = sorted((c for c in crits if c.get("score", 0) <= 1), key=lambda c: c.get("score", 0))
    return {"correctas": ok, "revisar": [criterion_explained(c["id"]) for c in weak[:2]],
            "item": None, "consejo": tip}


def _merge(first: dict, second: dict) -> dict:
    return {**second, "correctas": first["correctas"] + second["correctas"],
            "revisar": first["revisar"] + second["revisar"]}


def _judged(lab_type: str, text: str, state: dict, mock) -> dict:
    """Texto libre → Jev con los hechos verificados; [mock] solo con EVALUATOR_MODE=mock."""
    if os.getenv("EVALUATOR_MODE", "mock") != "jev":
        return mock()
    from app.evaluation import jev_evaluate, verified_facts

    lab = lab_type or "ml_experiment"
    return jev_evaluate(text, state, lab, verified_facts(lab, state))


def _seed(state: dict) -> int:
    try:
        return int(state.get("seed", 1))
    except (TypeError, ValueError):
        return 1


def check_challenge(lab_type: str, widget: str, payload: dict, spec: dict,
                    state: dict) -> dict | None:
    """[spec] = intervención guardada en el log; [state] = estado del intento."""
    p = payload if isinstance(payload, dict) else {}
    params = ((spec.get("widget_parameters") or {}).get("parameters") or {}) if spec else {}
    private = spec.get("private") if isinstance(spec.get("private"), dict) else {}
    extra = state.get("extra") if isinstance(state.get("extra"), dict) else {}

    if widget == "DataTableExplorer":
        rows = params.get("rows") if isinstance(params.get("rows"), list) else []
        transfer = private.get("transfer", any(str(r.get("ref", "")).startswith("N") for r in rows))
        res = check_data_contrast(state, transfer, p.get("classifications") or {},
                                  private.get("types"))
        return {**res, "item": "fila", "consejo": _DATA_TIP}

    if widget in DOCKER_WIDGETS.values():
        unit = params.get("unit") or next(u for u, w in DOCKER_WIDGETS.items() if w == widget)
        seed = int(params.get("seed") or _seed(state))
        # El reto cierra su ciclo con una justificación propia: se juzga ese texto.
        argument = p.get("argument")
        if isinstance(argument, str) and argument.strip():
            # Solo el texto: las decisiones del reto ya las corrigió el servidor y
            # las de la práctica son de otro escenario (mezclarlas puntuaría en falso).
            res = _judged(lab_type, argument, state,
                          lambda: mock_evaluate_docker(argument, {"unit": unit}, seed))
            return _text(res, "Nombra el mecanismo (kernel, capa, red o volumen) y cita qué "
                              "observaste en este reto, no en la práctica.")
        return labs_docker.check(unit, seed, p)

    if widget == "EvidenceComparison":
        sel = p.get("selection")
        first = ({"correctas": ["comparaste ambas curvas"], "revisar": []} if sel == "both" else
                 {"correctas": [], "revisar": ["qué curvas muestran el problema"]})
        cx = int((params.get("complexity") or {}).get("initial", state.get("complexity", 5)))
        res = _judged(lab_type, p.get("argument", ""), state,
                      lambda: mock_evaluate(p.get("argument", ""), cx))
        return _merge(first, _text(res,
                                   "El sobreajuste se ve en la distancia entre las dos curvas."))

    if widget == "LearningCurveSimulator":
        from app.labs_ml import ml_curve

        try:
            cx, nz = int(p.get("complexity", 5)), int(p.get("noise_pct", 20))
        except (TypeError, ValueError):
            return None
        c = ml_curve(cx, nz, _seed(state))
        gap = c["val"][-1] - c["train"][-1]
        shows = gap > 0.12
        label = f"configuración complejidad {cx} · ruido {nz} %"
        return {"correctas": [label] if shows else [], "revisar": [] if shows else [label],
                "item": None,
                "consejo": ("Ahí la validación se despega: explica por qué." if shows else
                            "Con esa configuración las curvas casi no se separan: "
                            "prueba más complejidad.")}

    if widget == "DriftDistributionExplorer":
        from app.labs_monitor import generate

        truth = generate(_seed(state))["truth"]
        feat = p.get("feature")
        first = ({"correctas": [f"la feature que deriva ({feat})"], "revisar": []}
                 if feat == truth["drifted_feature"] else
                 {"correctas": [], "revisar": ["qué feature cambió de verdad"]})
        res = _judged(lab_type, p.get("argument", ""), state, lambda: mock_evaluate_monitor(
            p.get("argument", ""), {"feature": feat}, _seed(state)))
        return _merge(first, _text(res, "Separa cambio en la entrada de caída de precisión."))

    if widget == "HypothesisEditor":
        text = p.get("hypothesis", "")
        cx = int((params.get("complexity") or {}).get("initial", state.get("complexity", 5)))
        res = _judged(lab_type, text, state, lambda: (
            mock_evaluate_monitor(text, extra, _seed(state)) if lab_type == "model_monitoring"
            else mock_evaluate_data(text, state.get("flags") or [], _seed(state), extra)
            if lab_type == "data_detective" else mock_evaluate(text, cx)))
        return _text(res, "Cita evidencia concreta y la causa, no solo la conclusión.")
    return None


def check_practice(lab_type: str, widget: str, payload: dict) -> dict | None:
    """Práctica (semilla 1): corrige cada selección al momento, solo lo que el alumno
    tocó, sin revelar la respuesta ni dar números. Nunca se llama en la prueba."""
    p = payload if isinstance(payload, dict) else {}
    if lab_type == "docker":
        unit = p.get("unit")
        return labs_docker.check(unit, 1, p) if DOCKER_WIDGETS.get(unit) == widget else None

    if lab_type == "data_detective" and widget == "DataTableExplorer":
        from app.evaluation import _true_row_type
        from app.labs_data import generate

        rows = generate(1)["rows"]
        claimed = dict(p.get("cell_types") or {}) if isinstance(p.get("cell_types"), dict) else {}
        if p.get("row") is not None:
            claimed[str(p.get("row"))] = p.get("type")
        ok, bad = [], []
        for rid, t in claimed.items():
            try:
                i = int(rid)
            except (TypeError, ValueError):
                continue
            if 0 <= i < len(rows):
                actual = _true_row_type(rows, i)
                (ok if (t == "sin_anomalia" and actual == "ok") or t == actual else bad).append(str(i))
        return {"correctas": sorted(ok, key=int), "revisar": sorted(bad, key=int), "item": "fila",
                "consejo": "Mira qué columna delata el problema: vacío, unidad, valor imposible, "
                           "fila repetida o dato del futuro."}

    if lab_type == "ml_experiment" and widget == "LearningCurveSimulator":
        from app.labs_ml import ml_curve

        try:
            cx, nz, ep = int(p.get("complexity", 5)), int(p.get("noise_pct", 20)), int(p["epoch"])
        except (KeyError, TypeError, ValueError):
            return None
        c = ml_curve(cx, nz, 1)
        best = min(range(len(c["val"])), key=lambda i: c["val"][i])
        overfits = c["val"][-1] - c["train"][-1] > 0.12
        label = f"época {ep} con complejidad {cx}"
        right = overfits and abs(ep - best) <= 1
        tip = ("Busca el punto donde la validación deja de bajar y empieza a subir."
               if overfits else
               "Con esta configuración las curvas no se separan: sube la complejidad o el ruido.")
        return {"correctas": [label] if right else [], "revisar": [] if right else [label],
                "item": None, "consejo": tip}

    if lab_type == "model_monitoring" and widget == "DriftDistributionExplorer":
        from app.labs_monitor import generate

        truth = generate(1)["truth"]
        feat = p.get("feature")
        try:
            cp_err = abs(int(p.get("changepoint")) - truth["changepoint"])
        except (TypeError, ValueError):
            cp_err = None
        ok, bad = [], []
        (ok if feat == truth["drifted_feature"] else bad).append(f"la feature elegida ({feat})")
        if cp_err is not None:
            (ok if cp_err <= 15 else bad).append("el momento del cambio")
        return {"correctas": ok, "revisar": bad, "item": None,
                "consejo": "Compara referencia y actual: ¿qué distribución se movió y desde cuándo?"}
    return None
