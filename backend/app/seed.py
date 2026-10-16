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


def init_db():
    Base.metadata.create_all(bind=engine)


def seed_if_empty():
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
        db.commit()
    finally:
        db.close()


if __name__ == "__main__":
    init_db()
    seed_if_empty()
    print("seed ok")
