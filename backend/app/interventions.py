"""F2-F3: política determinista de intervención + UI planner con catálogo cerrado."""
from app.socratic import socratic_question

# Catálogo permitido (§7 del plan). Solo estos widget_type pueden salir del backend.
CATALOG = {
    "SocraticQuestionCard",
    "HypothesisEditor",
    "ChoiceReasoningWidget",
    "DataTableExplorer",
    "SqlQueryWorkbench",
    "LearningCurveSimulator",
    "DriftDistributionExplorer",
    "EvidenceComparison",
    "ConceptMapBuilder",
    "PipelineDAGBuilder",
    "RubricFeedbackCard",
    "ReflectionSummary",
}

FALLBACK_WIDGET = "SocraticQuestionCard"

SCHEMA_VERSION = 1

# P1.1: contrato mínimo versionado — qué eventos acepta cada widget.
ALLOWED_EVENTS = {
    "parameterChanged",
    "predictionSubmitted",
    "hypothesisSubmitted",
    "evidenceSelected",
    "argumentSubmitted",
    "hintRequested",
}

ALLOWED_BY_WIDGET = {
    "LearningCurveSimulator": ["parameterChanged", "predictionSubmitted", "hintRequested"],
    "EvidenceComparison": ["evidenceSelected", "argumentSubmitted", "hintRequested"],
    "HypothesisEditor": ["hypothesisSubmitted", "hintRequested"],
    "SocraticQuestionCard": ["hintRequested"],
    "ChoiceReasoningWidget": ["argumentSubmitted", "hintRequested"],
    "DataTableExplorer": ["evidenceSelected", "argumentSubmitted", "hintRequested"],
    "DriftDistributionExplorer": ["evidenceSelected", "argumentSubmitted", "hintRequested"],
    "SqlQueryWorkbench": ["argumentSubmitted", "hintRequested"],
    "ConceptMapBuilder": ["argumentSubmitted", "hintRequested"],
    "PipelineDAGBuilder": ["argumentSubmitted", "hintRequested"],
    "RubricFeedbackCard": ["hintRequested"],
    "ReflectionSummary": ["argumentSubmitted"],
}


def validate_ui_spec(spec: dict) -> list[str]:
    """Devuelve lista de errores; vacía = válida."""
    errors = []
    if spec.get("widget_type") not in CATALOG:
        errors.append(f"widget_type desconocido: {spec.get('widget_type')}")
    if not isinstance(spec.get("widget_parameters", {}), dict):
        errors.append("widget_parameters debe ser objeto")
    for name, p in (spec.get("widget_parameters") or {}).items():
        if isinstance(p, dict) and {"min", "max", "initial"} <= set(p):
            if not (p["min"] <= p["initial"] <= p["max"]):
                errors.append(f"parámetro {name} fuera de rango")
    return errors


def _avg(criteria: list[dict]) -> float:
    if not criteria:
        return 0.0
    return sum(c.get("score", 0) for c in criteria) / len(criteria)


def select_intervention(answer_text: str, input_state: dict, eval_result: dict | None,
                        lab_type: str = "ml_experiment") -> dict:
    """Reglas §9: débil→evidencia, sólida→transferencia, ambigua→aclarar."""
    complexity = int(input_state.get("complexity", 5))
    noise = int(input_state.get("noise_pct", 20))
    data_lab = lab_type == "data_detective" or bool(input_state.get("flags"))
    monitor_lab = lab_type == "model_monitoring"
    lab_hint = "model_monitoring" if monitor_lab else ("data_detective" if data_lab else "ml_experiment")

    if not eval_result or eval_result.get("status") != "evaluated":
        q = socratic_question(answer_text, ["sin evaluación"])["question"]
        spec = {
            "type": FALLBACK_WIDGET,
            "version": 1,
            "learning_objective": "Formular hipótesis inicial",
            "title": "Empieza con una hipótesis",
            "parameters": {},
            "reasoning_prompt": q,
            "requires_justification": True,
        }
        return {
            "strategy": "clarify",
            "reason": "Sin evaluación válida; no se afirma ningún score",
            "widget_type": FALLBACK_WIDGET,
            "widget_parameters": spec,
            "socratic_question": q,
            "difficulty_delta": 0,
            "give_direct_answer": False,
        }

    criteria = eval_result.get("criteria", [])
    weak = [c["id"] for c in criteria if c.get("score", 0) <= 2]
    avg = _avg(criteria)

    if avg <= 2:
        q = socratic_question(answer_text, weak, lab_hint)["question"]
        if monitor_lab:
            spec = {
                "type": "DriftDistributionExplorer",
                "version": 1,
                "learning_objective": "Comparar referencia vs actual",
                "title": "¿Qué cambió?",
                "parameters": {},
                "reasoning_prompt": q,
                "requires_justification": True,
            }
            return {
                "strategy": "request_evidence",
                "reason": f"Promedio {avg:.1f}: falta identificar deriva con evidencia",
                "widget_type": "DriftDistributionExplorer",
                "widget_parameters": spec,
                "socratic_question": q,
                "difficulty_delta": 0,
                "give_direct_answer": False,
            }
        if data_lab:
            spec = {
                "type": "DataTableExplorer",
                "version": 1,
                "learning_objective": "Distinguir error de outlier real",
                "title": "Revisa las filas marcadas",
                "parameters": {},
                "reasoning_prompt": q,
                "requires_justification": True,
            }
            return {
                "strategy": "request_evidence",
                "reason": f"Promedio {avg:.1f}: faltan anomalías por detectar o justificar",
                "widget_type": "DataTableExplorer",
                "widget_parameters": spec,
                "socratic_question": q,
                "difficulty_delta": 0,
                "give_direct_answer": False,
            }
        spec = {
            "type": "EvidenceComparison",
            "version": 1,
            "learning_objective": "Contrastar entrenamiento vs generalización",
            "title": "Compara ambas curvas",
            "parameters": {
                "complexity": {"min": 1, "max": 10, "initial": complexity},
                "noise_pct": {"min": 0, "max": 50, "initial": noise},
            },
            "reasoning_prompt": q,
            "requires_justification": True,
        }
        return {
            "strategy": "request_evidence",
            "reason": f"Promedio {avg:.1f}: la justificación no usa evidencia suficiente",
            "widget_type": "EvidenceComparison",
            "widget_parameters": spec,
            "socratic_question": q,
            "difficulty_delta": 0,
            "give_direct_answer": False,
        }

    q = socratic_question(answer_text, [], lab_hint)["question"]
    if monitor_lab:
        spec = {
            "type": "HypothesisEditor",
            "version": 1,
            "learning_objective": "Decidir monitoreo vs reentrenamiento",
            "title": "Nueva distribución, ¿y ahora qué?",
            "parameters": {},
            "reasoning_prompt": q,
            "requires_justification": True,
        }
        return {
            "strategy": "transfer",
            "reason": f"Promedio {avg:.1f}: deriva bien diagnosticada, se decide acción",
            "widget_type": "HypothesisEditor",
            "widget_parameters": spec,
            "socratic_question": q,
            "difficulty_delta": 1,
            "give_direct_answer": False,
        }
    if data_lab:
        spec = {
            "type": "HypothesisEditor",
            "version": 1,
            "learning_objective": "Generalizar plan de limpieza",
            "title": "Nueva tabla, mismo método",
            "parameters": {},
            "reasoning_prompt": q,
            "requires_justification": True,
        }
        return {
            "strategy": "transfer",
            "reason": f"Promedio {avg:.1f}: buena detección, se transfiere a tabla nueva",
            "widget_type": "HypothesisEditor",
            "widget_parameters": spec,
            "socratic_question": q,
            "difficulty_delta": 1,
            "give_direct_answer": False,
        }
    spec = {
        "type": "HypothesisEditor",
        "version": 1,
        "learning_objective": "Transferir a mayor complejidad",
        "title": "Sube la dificultad",
        "parameters": {
            "complexity": {"min": 1, "max": 10, "initial": min(10, complexity + 2)},
        },
        "reasoning_prompt": q,
        "requires_justification": True,
    }
    return {
        "strategy": "transfer",
        "reason": f"Promedio {avg:.1f}: razonamiento suficiente, se aumenta dificultad",
        "widget_type": "HypothesisEditor",
        "widget_parameters": spec,
        "socratic_question": q,
        "difficulty_delta": 1,
        "give_direct_answer": False,
    }


def safe_intervention(fallback_reason: str) -> dict:
    q = socratic_question("", ["fallback"])["question"]
    return {
        "strategy": "clarify",
        "reason": fallback_reason,
        "widget_type": FALLBACK_WIDGET,
        "widget_parameters": {"type": FALLBACK_WIDGET, "version": 1, "parameters": {}},
        "socratic_question": q,
        "difficulty_delta": 0,
        "give_direct_answer": False,
        "schema_version": SCHEMA_VERSION,
        "allowed_events": ALLOWED_BY_WIDGET.get(FALLBACK_WIDGET, []),
    }
