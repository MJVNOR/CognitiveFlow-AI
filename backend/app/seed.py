from app.db import Base, SessionLocal, engine
from app import models  # noqa: F401 ensure tables registered


MODULES = [
    ("m1", "Herramientas de desarrollo", 1),
    ("m2", "Datos y consultas", 2),
    ("m3", "Machine Learning y explicabilidad", 3),
    ("m4", "Deep Learning", 4),
    ("m5", "Modalidades especializadas", 5),
    ("m6", "MLOps, datos y observabilidad", 6),
    ("m7", "Agentes y contexto", 7),
    ("m8", "Proyecto integrador", 8),
]

USERS = [
    ("s1", "Alumna 1", "student"),
    ("s2", "Alumno 2", "student"),
    ("s3", "Alumna 3", "student"),
    ("s4", "Alumno 4", "student"),
    ("i1", "Instructor", "instructor"),
]

LABS = [
    # id, title, lab_type, module_id, order, description
    ("lab-data", "Data Detective", "data_detective", "m2", 1,
     "Datos sucios, decisiones limpias: detecta anomalías en una tabla y justifica tu plan de limpieza."),
    ("lab-ml", "ML Experiment Lab", "ml_experiment", "m3", 2,
     "Complejidad vs generalización: experimenta con las curvas de pérdida y formula tu hipótesis."),
    ("lab-monitor", "Model Monitoring Lab", "model_monitoring", "m6", 3,
     "El modelo ya está en producción: detecta deriva y decide si reentrenar o seguir monitoreando."),
]

# Sprint 1: una unidad (M03-U02) con lección + ejemplo + diagnóstico pequeño.
# ponytail: constante única — seed y endpoint la comparten, sin duplicar.
OBJECTIVE_ML_U02 = {
    "id": "M03-U02-generalization",
    "lab_template_id": "lab-ml",
    "title": "Distinguir overfitting de underfitting en curvas de pérdida",
    "level": "intermedio",
    "concept_summary": (
        "Overfitting: el entrenamiento mejora pero la validación empeora al subir "
        "la complejidad (el modelo memoriza). Underfitting: ambas curvas quedan "
        "altas y planas (el modelo es demasiado simple). La generalización se lee "
        "en la brecha y la pendiente de validación, no en una sola curva."
    ),
    "worked_example_steps": [
        "Con complejidad 3, train y validación bajan juntas: aún hay capacidad.",
        "Con complejidad 7, train sigue bajando pero validación sube: memoriza.",
        "Con complejidad 2 y ruido alto, ambas quedan altas: ni siquiera ajusta.",
    ],
    "misconceptions": [
        "Creer que más complejidad siempre ayuda.",
        "Leer solo la curva de entrenamiento.",
        "Confundir ruido en los datos con overfitting.",
    ],
    "rubric_id": "ml-overfitting-v1",
    "diagnostic_blueprint": {
        "items": [
            {"id": "dg-1", "widget_type": "LearningCurveSimulator",
             "widget_config": {"complexity": 7, "noise_pct": 20, "seed": 11},
             "expected_evidence": ["prediction"],
             "prompt": "Antes de mover el slider: ¿qué curva cambiará primero y por qué?"},
            {"id": "dg-2", "widget_type": "LearningCurveSimulator",
             "widget_config": {"complexity": 3, "noise_pct": 30, "seed": 12},
             "expected_evidence": ["prediction"],
             "prompt": "Mismo ejercicio, otros parámetros: predice y compara con dg-1."},
        ]
    },
}


def init_db():
    Base.metadata.create_all(bind=engine)


def seed_if_empty():
    import json as _json

    db = SessionLocal()
    try:
        if db.query(models.Module).count() == 0:
            for mid, title, order in MODULES:
                db.add(models.Module(id=mid, title=title, order_index=order))
        if db.query(models.User).count() == 0:
            for uid, name, role in USERS:
                db.add(models.User(id=uid, display_name=name, role=role))
        if db.query(models.LabTemplate).count() == 0:
            for lid, title, ltype, mid, order, desc in LABS:
                db.add(models.LabTemplate(id=lid, title=title, lab_type=ltype,
                                          module_id=mid, order_index=order,
                                          description=desc))
        # ponytail: tabla nueva → si está vacía se siembra sin tocar el resto
        if hasattr(models, "LearningObjective") and db.query(models.LearningObjective).count() == 0:
            o = OBJECTIVE_ML_U02
            db.add(models.LearningObjective(
                id=o["id"], lab_template_id=o["lab_template_id"], title=o["title"],
                level=o["level"], concept_summary=o["concept_summary"],
                worked_example_json=_json.dumps(o["worked_example_steps"]),
                misconceptions_json=_json.dumps(o["misconceptions"]),
                rubric_id=o["rubric_id"],
                diagnostic_blueprint_json=_json.dumps(o["diagnostic_blueprint"])))
        db.commit()
    finally:
        db.close()


if __name__ == "__main__":
    init_db()
    seed_if_empty()
    print("seed ok")
