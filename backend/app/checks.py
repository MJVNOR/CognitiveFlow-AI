"""Corrección en el servidor de la entrega de un reto GenUI.
Descriptiva (qué está bien / qué revisar), sin puntajes y sin revelar la
respuesta. La verdad sale de los generadores del servidor, nunca del cliente;
los textos libres se miran con los evaluadores mock deterministas (sin LLM)."""
from app import labs_docker
from app.evaluation import mock_evaluate, mock_evaluate_data, mock_evaluate_monitor
from app.interventions import DOCKER_WIDGETS, check_data_contrast
from app.socratic import CRITERION_LABELS

_DATA_TIP = ("Compara su evidencia con las demás y cambia la etiqueta "
             "(o quítala si no hay anomalía); luego reenvía.")


def _text(result: dict, tip: str) -> dict:
    """Criterios de la rúbrica como texto: hasta 2 a reforzar, nunca números."""
    crits = result.get("criteria", []) if result.get("status") == "evaluated" else []
    ok = [CRITERION_LABELS.get(c["id"], c["id"]) for c in crits if c.get("score", 0) >= 3]
    weak = sorted((c for c in crits if c.get("score", 0) <= 1), key=lambda c: c.get("score", 0))
    return {"correctas": ok, "revisar": [CRITERION_LABELS.get(c["id"], c["id"]) for c in weak[:2]],
            "item": None, "consejo": tip}


def _merge(first: dict, second: dict) -> dict:
    return {**second, "correctas": first["correctas"] + second["correctas"],
            "revisar": first["revisar"] + second["revisar"]}


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
        return labs_docker.check(unit, int(params.get("seed") or _seed(state)), p)

    if widget == "EvidenceComparison":
        sel = p.get("selection")
        first = ({"correctas": ["comparaste ambas curvas"], "revisar": []} if sel == "both" else
                 {"correctas": [], "revisar": ["qué curvas muestran el problema"]})
        cx = int((params.get("complexity") or {}).get("initial", state.get("complexity", 5)))
        return _merge(first, _text(mock_evaluate(p.get("argument", ""), cx),
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
        res = mock_evaluate_monitor(p.get("argument", ""), {"feature": feat}, _seed(state))
        return _merge(first, _text(res, "Separa cambio en la entrada de caída de precisión."))

    if widget == "HypothesisEditor":
        text = p.get("hypothesis", "")
        if lab_type == "model_monitoring":
            res = mock_evaluate_monitor(text, extra, _seed(state))
        elif lab_type == "data_detective":
            res = mock_evaluate_data(text, state.get("flags") or [], _seed(state), extra)
        else:
            cx = int((params.get("complexity") or {}).get("initial", state.get("complexity", 5)))
            res = mock_evaluate(text, cx)
        return _text(res, "Cita evidencia concreta y la causa, no solo la conclusión.")
    return None
