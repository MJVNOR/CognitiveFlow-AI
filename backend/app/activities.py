"""Identidad de retos persistida en JSON; compatible con históricos sin migración."""
import json
import uuid

from app import models
from fastapi import HTTPException


def activity_identity(log) -> dict:
    try:
        spec = json.loads(log.spec_json)
    except (ValueError, TypeError):
        spec = {}
    if not isinstance(spec, dict):
        spec = {}
    return {
        "activity_id": spec.get("activity_id", f"activity-{log.id}"),
        "session_id": log.session_id,
        "previous_activity_id": spec.get("previous_activity_id"),
    }


def persist_activity(db, session_id: str, attempt_id: str, intervention: dict,
                     private=None, planner=None) -> dict:
    """Guarda una actividad y su predecesora sin modificar registros anteriores."""
    rows = db.query(models.InterventionLog).filter_by(session_id=session_id).all()
    if rows and rows[-1].attempt_id == attempt_id:
        return public_activity(rows[-1])
    from app.helpers import _practice_attempts

    attempts = _practice_attempts(db, session_id)
    if attempts and attempts[-1].id != attempt_id:
        raise HTTPException(409, "El intento ya no es el actual de esta sesión")
    log_id = uuid.uuid4().hex
    identity = {
        "activity_id": f"activity-{log_id}",
        "session_id": session_id,
        "previous_activity_id": activity_identity(rows[-1])["activity_id"] if rows else None,
    }
    intervention.update(identity)
    from app.helpers import submit_count

    spec = {**intervention, "private": private, "planner": planner,
            "submits_before": submit_count(db, session_id, intervention["widget_type"])}
    db.add(models.InterventionLog(
        id=log_id, session_id=session_id, attempt_id=attempt_id,
        strategy=intervention["strategy"], widget_type=intervention["widget_type"],
        spec_json=json.dumps(spec)))
    db.commit()
    return intervention


def public_activity(log) -> dict:
    spec = json.loads(log.spec_json)
    from app.interventions import ALLOWED_BY_WIDGET, SCHEMA_VERSION

    result = {"widget_type": log.widget_type, "strategy": log.strategy,
              "widget_parameters": spec.get("widget_parameters", spec),
              "schema_version": SCHEMA_VERSION,
              "allowed_events": ALLOWED_BY_WIDGET.get(log.widget_type, []),
              **spec, **activity_identity(log)}
    return {k: v for k, v in result.items()
            if k not in ("private", "planner", "submits_before", "_private")}
