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
    ("m8", "Docker y despliegue", 8),
    ("m9", "Proyecto integrador", 9),
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
    ("lab-docker", "Docker Academy Lab", "docker", "m8", 4,
     "Conteneriza y despliega: clasifica, construye, persiste y recupera."),
]

# Sprint 1: una unidad (M03-U02) con lección + ejemplo + diagnóstico pequeño.
# ponytail: constante única — seed y endpoint la comparten, sin duplicar.
# Sprint 3: M06-U04 con conceptos drift vs performance + diagnóstico pequeño.
OBJECTIVE_M06_U04 = {
    "id": "M06-U04-drift",
    "lab_template_id": "lab-monitor",
    "title": "Distinguir deriva de datos, cambio de concepto y caída de métrica",
    "level": "intermedio",
    "concept_summary": (
        "Deriva de datos: cambia la entrada X (ej. la media de temp sube) aunque el "
        "modelo siga igual. Cambio de concepto: cambia la relación X→Y (lo que antes "
        "era normal ahora es falla). Caída de métrica: empeoran los aciertos, y solo "
        "se afirma con etiquetas reales. Causas típicas: sensor, mezcla de población "
        "o etiqueta tardía. Antes de reentrenar (caro), monitorea con un umbral."
    ),
    "worked_example_steps": [
        "Compara referencia vs actual de temp: la media actual es mayor.",
        "Ubica en la serie cuándo se separa (t≈120): deriva de datos.",
        "Decide: monitorear con umbral antes de reentrenar; sin etiquetas no afirmes caída de precisión.",
    ],
    "misconceptions": [
        "Toda deriva implica caída de precisión.",
        "Reentrenar siempre arregla el problema.",
        "Confundir cambio de concepto con deriva de datos.",
    ],
    "rubric_id": "drift-v1",
    "status": "interactive_ready",
    "diagnostic_blueprint": {
        "items": [
            {"id": "dg-1", "widget_type": "DriftDistributionExplorer",
             "widget_config": {"features": ["temp", "pressure", "vibration"], "seed": 11},
             "expected_evidence": ["prediction"],
             "prompt": "Antes de comparar: ¿qué feature crees que cambió y por qué?"},
            {"id": "dg-2", "widget_type": "DriftDistributionExplorer",
             "widget_config": {"features": ["temp", "pressure", "vibration"], "seed": 12},
             "expected_evidence": ["prediction"],
             "prompt": "Mismo ejercicio, otros datos: predice y compara con dg-1."},
        ]
    },
}

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
    "status": "interactive_ready",
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

# Sprint 3: M02-U02 (Data Detective) con tipos de error + plan de limpieza.
OBJECTIVE_M02_U02 = {
    "id": "M02-U02-cleaning",
    "lab_template_id": "lab-data",
    "title": "Clasificar anomalías y elegir limpieza sin destruir evidencia",
    "level": "intermedio",
    "concept_summary": (
        "No toda rareza es error: un outlier puede ser real. Clasifica primero: "
        "faltante, duplicado, unidad mezclada, imposible físico o fuga de futuro. "
        "Después elige la reparación más barata que conserva evidencia: imputar, "
        "convertir, eliminar o revisar. Eliminar sin mirar destruye datos."
    ),
    "worked_example_steps": [
        "Fila con pressure vacío: faltante → imputar con la media.",
        "Temp 77 con unit F junto a valores en C: unidad mezclada → convertir.",
        "Fila idéntica a otra: duplicado → eliminar una.",
    ],
    "misconceptions": [
        "Todo outlier es un error que hay que borrar.",
        "Eliminar filas nunca tiene costo.",
        "Las unidades no importan si el número parece normal.",
    ],
    "rubric_id": "data-cleaning-v1",
    "status": "interactive_ready",
    "diagnostic_blueprint": {
        "items": [
            {"id": "dg-1", "widget_type": "DataTableExplorer",
             "widget_config": {"n_rows": 30, "seed": 11},
             "expected_evidence": ["prediction"],
             "prompt": "Antes de marcar: ¿qué tipos de error esperas y dónde?"},
            {"id": "dg-2", "widget_type": "DataTableExplorer",
             "widget_config": {"n_rows": 30, "seed": 12},
             "expected_evidence": ["prediction"],
             "prompt": "Nueva tabla: clasifica cada anomalía y su reparación."},
        ]
    },
}

# Sprint 3: Docker D01/D02/D04/D07 (contenido listo, widgets MVP, sin lab interactivo aún).
OBJECTIVE_D01 = {
    "id": "M08-D01-containers",
    "lab_template_id": "lab-docker",
    "title": "Distinguir contenedor de máquina virtual y sus límites",
    "level": "introductorio",
    "concept_summary": (
        "Un contenedor comparte el kernel del host y aísla procesos; una VM "
        "virtualiza hardware con su propio kernel. Contenedor: arranque rápido, "
        "ligero, ideal para apps reproducibles. Límite: no persiste solo, no es "
        "una VM pequeña y localhost dentro no es tu máquina."
    ),
    "worked_example_steps": [
        'Caso: una web estática con Nginx que quieres levantar y tirar en segundos. → Contenedor: corre sobre el mismo kernel Linux del host; solo necesita su proceso aislado.',
        'Caso: una herramienta que solo existe para FreeBSD, en un host Linux. → Máquina virtual: FreeBSD trae su propio kernel y un contenedor no puede cambiar el del host.',
        'Regla: si el caso necesita otro kernel u otro sistema operativo → VM; si basta aislar procesos sobre el kernel del host → contenedor.',
    ],
    "misconceptions": [
        "Un contenedor guarda mis archivos automáticamente.",
        "localhost en el contenedor es mi máquina.",
        "Contenedor y VM son intercambiables.",
    ],
    "rubric_id": "docker-d01-v1",
    "status": "content_ready",
    "diagnostic_blueprint": {
        "items": [
            {"id": "dg-1", "widget_type": "ContainerVsVmExplorer",
             "widget_config": {"seed": 11},
             "expected_evidence": ["prediction"],
             "prompt": "Tres escenarios: ¿contenedor o VM? Justifica cada uno."},
            {"id": "dg-2", "widget_type": "ContainerVsVmExplorer",
             "widget_config": {"seed": 12},
             "expected_evidence": ["prediction"],
             "prompt": "Nuevos escenarios: clasifica y señala el límite."},
        ]
    },
}

OBJECTIVE_D02 = {
    "id": "M08-D02-lifecycle",
    "lab_template_id": "lab-docker",
    "title": "Distinguir imagen, contenedor y su ciclo de vida",
    "level": "introductorio",
    "concept_summary": (
        "La imagen es inmutable (plantilla con capas); el contenedor es una "
        "instancia que puede estar en ejecución o detenida. pull/build crea la imagen; "
        "run crea un contenedor nuevo; stop lo detiene; start reanuda ese mismo contenedor; "
        "rm lo elimina. Con run --rm se elimina al terminar. La imagen se elimina con rmi."
    ),
    "worked_example_steps": [
        'docker pull redis → existe la imagen (la plantilla); todavía no hay ningún contenedor.',
        'docker run -d --name cache redis → existen la imagen y el contenedor cache, que está corriendo.',
        'docker stop cache → el contenedor cache sigue existiendo, detenido. docker start cache reanuda esa misma instancia.',
        'docker stop cache y luego docker rm cache → queda la imagen. docker rmi redis la elimina si no la usa otro contenedor.',
    ],
    "misconceptions": [
        "Borrar el contenedor borra la imagen.",
        "Parar un contenedor borra sus archivos.",
        "Imagen y contenedor son lo mismo.",
    ],
    "rubric_id": "docker-d02-v1",
    "status": "content_ready",
    "diagnostic_blueprint": {
        "items": [
            {"id": "dg-1", "widget_type": "ImageContainerLifecycle",
             "widget_config": {"seed": 11},
             "expected_evidence": ["prediction"],
             "prompt": "Ordena el ciclo y predice qué sobrevive a cada paso."},
            {"id": "dg-2", "widget_type": "ImageContainerLifecycle",
             "widget_config": {"seed": 12},
             "expected_evidence": ["prediction"],
             "prompt": "Servicio caído: ¿qué paso lo recupera y qué se pierde?"},
        ]
    },
}

OBJECTIVE_D04 = {
    "id": "M08-D04-dockerfile",
    "lab_template_id": "lab-docker",
    "title": "Escribir un Dockerfile reproducible y con buena caché",
    "level": "intermedio",
    "concept_summary": (
        "El Dockerfile declara capas: FROM fija versión, COPY requirements + RUN "
        "pip van antes que COPY del código para no invalidar la caché, EXPOSE "
        "documenta (no publica) y .dockerignore excluye. Orden malo = builds "
        "lentos; versión sin fijar = builds irreproducibles."
    ),
    "worked_example_steps": [
        'App Node: FROM node:20-slim → COPY package*.json → RUN npm ci → COPY . . : dependencias primero, código al final.',
        'Cambias un archivo .js → solo se rehace la capa de COPY . .; npm ci sale de la caché.',
        'Si COPY . . va antes de npm ci, cada cambio de código reinstala todas las dependencias.',
    ],
    "misconceptions": [
        "EXPOSE publica el puerto solo.",
        "El orden de instrucciones no afecta el tiempo.",
        "latest siempre es reproducible.",
    ],
    "rubric_id": "docker-d04-v1",
    "status": "content_ready",
    "diagnostic_blueprint": {
        "items": [
            {"id": "dg-1", "widget_type": "DockerfileWorkbench",
             "widget_config": {"seed": 11},
             "expected_evidence": ["prediction"],
             "prompt": "Ordena las instrucciones y predice qué invalida la caché."},
            {"id": "dg-2", "widget_type": "DockerfileWorkbench",
             "widget_config": {"seed": 12},
             "expected_evidence": ["prediction"],
             "prompt": "Dockerfile roto: corrige orden y explica cada capa."},
        ]
    },
}

OBJECTIVE_D07 = {
    "id": "M08-D07-persistence",
    "lab_template_id": "lab-docker",
    "title": "Predecir qué sobrevive al recrear un contenedor",
    "level": "intermedio",
    "concept_summary": (
        "El filesystem del contenedor es efímero: al recrear, lo no montado se "
        "pierde. Named volume persiste gestionado por Docker; bind mount enlaza "
        "tu carpeta. SQLite necesita volumen o se pierde con el contenedor."
    ),
    "worked_example_steps": [
        'Postgres sin volumen: haces docker rm y lo recreas → la base aparece vacía.',
        'Con -v pgdata:/var/lib/postgresql/data → los datos siguen ahí tras recrear: el volumen vive fuera del contenedor.',
        'Con bind mount ./pgdata:/var/lib/postgresql/data → también siguen, y los ves en tu carpeta (depende de que esa ruta exista).',
    ],
    "misconceptions": [
        "Recrear conserva los archivos escritos dentro.",
        "Volume y capa de imagen son lo mismo.",
        "Bind mount y named volume no se distinguen.",
    ],
    "rubric_id": "docker-d07-v1",
    "status": "content_ready",
    "diagnostic_blueprint": {
        "items": [
            {"id": "dg-1", "widget_type": "PersistenceExperiment",
             "widget_config": {"seed": 11},
             "expected_evidence": ["prediction"],
             "prompt": "Predice qué archivos sobreviven con cada montaje."},
            {"id": "dg-2", "widget_type": "PersistenceExperiment",
             "widget_config": {"seed": 12},
             "expected_evidence": ["prediction"],
             "prompt": "DB SQLite en Compose: ¿dónde la guardas y por qué?"},
        ]
    },
}

# Resto de unidades Docker D03/D05/D06/D08–D12: temario real con estado planned
# (sin widget interactivo ni evaluador aún; el laboratorio cubre el MVP).
def _docker_planned(uid, title, summary, steps, misconceptions, widget="DecisionScenarios"):
    return {
        "id": uid, "lab_template_id": "lab-docker", "title": title,
        "level": "intermedio", "concept_summary": summary,
        "worked_example_steps": steps, "misconceptions": misconceptions,
        "rubric_id": uid.lower().replace("m08-", "docker-") + "-v1",
        "status": "content_ready",  # unidad con experimento de decisiones (DecisionScenarios)
        "diagnostic_blueprint": {
            "items": [
                {"id": "dg-1", "widget_type": widget,
                 "widget_config": {"seed": 11},
                 "expected_evidence": ["prediction"],
                 "prompt": "Predice antes de experimentar."},
                {"id": "dg-2", "widget_type": widget,
                 "widget_config": {"seed": 12},
                 "expected_evidence": ["prediction"],
                 "prompt": "Transfiere a un escenario nuevo."},
            ]
        },
    }


OBJECTIVE_D03 = _docker_planned(
    "M08-D03-cli", "Componer comandos Docker CLI sin adivinar",
    "Las imágenes se listan, los contenedores se inspeccionan y los logs se "
    "leen: images, ps, logs, exec, inspect con --help. -d separa, --name nombra "
    "y -p publica puertos. Adivinar flags rompe; leer la ayuda no.",
    ['Quieres saber cuánta CPU y memoria usa cada contenedor → docker stats muestra el consumo en vivo.',
     'Copiar un archivo del contenedor a tu PC → docker cp api:/app/log.txt ./ (no hace falta entrar con una shell).',
     'No recuerdas un flag → docker run --help antes de adivinar.'],
    ["-p y EXPOSE hacen lo mismo.", "latest siempre funciona.", "rm borra imágenes."])

OBJECTIVE_D05 = _docker_planned(
    "M08-D05-context", "Distinguir contexto, WORKDIR y filesystem efímero",
    "El build context es lo que ve COPY; fuera de él, COPY falla. WORKDIR fija "
    "el directorio de trabajo y .dockerignore recorta. Bind mount comparte, "
    "volumen persiste, nada montado se pierde al recrear.",
    ['docker build -t web ./frontend → el contexto es ./frontend: COPY solo ve lo que hay dentro de esa carpeta.',
     'Quieres excluir dist/ y los *.log → los listas en .dockerignore, en la raíz del contexto.',
     'COPY src/ /app/src/ → copia desde el contexto (no desde tu disco entero) hacia esa ruta de la imagen.'],
    ["COPY ve todo tu disco.", "El contenedor guarda solo.", "WORKDIR crea volumen."])

OBJECTIVE_D06 = _docker_planned(
    "M08-D06-network", "Conectar servicios sin confundir localhost",
    "Cada contenedor tiene su localhost; -p mapea host→contenedor y el DNS de "
    "Compose resuelve por nombre de servicio dentro de su red. Un proceso servidor "
    "en otro contenedor usa http://api:8000. El JavaScript del navegador se ejecuta "
    "en la computadora del usuario: necesita una URL publicada o un proxy, no el DNS interno api.",
    ['El worker debe hablar con Redis en el mismo compose → usa redis:6379 (el nombre del servicio), no localhost.',
     '-p 5433:5432 → en tu PC entras por el 5433 y llega al 5432 del contenedor.',
     'Solo el frontend debe verse desde fuera → solo él publica puerto; el resto se habla por la red interna.'],
    ["localhost es igual en todas partes.", "EXPOSE publica puertos.", "Toda red es plana."])

OBJECTIVE_D08 = _docker_planned(
    "M08-D08-compose", "Definir servicios, redes y volúmenes en Compose",
    "compose.yaml declara services, build/image, ports, volumes, environment, "
    "networks y depends_on. depends_on ordena el arranque pero no garantiza "
    "disponibilidad. healthcheck y depends_on con condition: service_healthy permiten esperar "
    "a la comprobación inicial; la app también debe manejar fallos posteriores.",
    ['Añadir un Redis de caché → un service más con image: redis:7; la API lo alcanza como redis:6379.',
     'Ver los logs de todo el stack → docker compose logs -f muestra todos los servicios a la vez.',
     'Cambiaste el Dockerfile de la API → docker compose up --build lo reconstruye antes de arrancar.'],
    ["depends_on espera a que esté listo.", "Compose es solo para dev.", "Un servicio por archivo."])

OBJECTIVE_D09 = _docker_planned(
    "M08-D09-debug", "Diagnosticar builds y contenedores con evidencia",
    "build muestra capas y caché; logs, exit codes e inspect explican el fallo. "
    "Multi-stage separa build de runtime. Leer la traza antes de cambiar "
    "archivos a ciegas.",
    ['El contenedor se reinicia en bucle → docker logs y docker inspect (RestartCount, ExitCode) antes de cambiar nada.',
     'La app no ve una variable de entorno → docker exec api env comprueba qué recibió de verdad.',
     'El healthcheck marca unhealthy → docker inspect muestra la salida del último chequeo.'],
    ["Reconstruir todo arregla todo.", "Los logs mienten.", "La caché es magia."])

OBJECTIVE_D10 = _docker_planned(
    "M08-D10-security", "No filtrar secretos y minimizar superficie",
    "Secretos por entorno o montaje, nunca en imagen ni repo. Usuario no root, "
    "imágenes mínimas compatibles y .dockerignore. Un tag puede cambiar: el digest fija "
    "el contenido; actualizarlo de forma controlada permite incorporar parches. Escanear antes de publicar.",
    ['Necesitas una contraseña durante el build → usa --secret de BuildKit; ARG y ENV pueden filtrar valores en capas o metadatos.',
     'El contenedor no necesita escribir en su disco → --read-only reduce lo que un atacante puede cambiar.',
     'Una dependencia tiene una vulnerabilidad crítica → reconstruye con la versión corregida y vuelve a escanear.'],
    ["Si el repo es privado, el secreto está a salvo.", "Root es más cómodo y ya.", "Escanear es opcional."])

OBJECTIVE_D11 = _docker_planned(
    "M08-D11-deploy", "Desplegar reproducible con rollback",
    "Local→registry→host con HTTPS y reverse proxy; env por entorno, datos en "
    "volumen con respaldo consistente probado y rollback por digest anterior compatible con los datos. CI/CD publica imágenes "
    "trazables, no contenedores a mano.",
    ['Desplegar sin cortar el servicio → arranca la versión nueva, comprueba su healthcheck y solo entonces apaga la vieja.',
     'Saber qué contenido corre en producción → registra el tag de release y su digest; una etiqueta sola puede cambiar.',
     'Los logs de producción se pierden al recrear → envíalos fuera del contenedor (driver de logs o servicio externo).'],
    ["latest es rollback suficiente.", "Backup del contenedor basta.", "Desplegar es copiar archivos."])

OBJECTIVE_D12 = _docker_planned(
    "M08-D12-capstone", "Integrar frontend + API + storage en Compose",
    "Este ejercicio reúne cuatro casos de unidades distintas: redes, almacenamiento, "
    "configuración, seguridad o despliegue. Elige y justifica cada decisión. Es una simulación "
    "de decisiones; no construye ni ejecuta un stack real.",
    ['Frontend, API y DB en un compose: red interna, solo el frontend publica puerto y la DB usa volumen.',
     'Ante un incidente: primero logs del servicio que falla, luego nombres de servicio y healthchecks, en ese orden.',
     'Documenta cada decisión en el README: por qué cada volumen, puerto y variable.'],
    ["Juntar YAMLs basta.", "Documentar es opcional.", "Si corre, está listo."])

OBJECTIVES = [OBJECTIVE_ML_U02, OBJECTIVE_M06_U04, OBJECTIVE_M02_U02,
              OBJECTIVE_D01, OBJECTIVE_D02, OBJECTIVE_D04, OBJECTIVE_D07,
              OBJECTIVE_D03, OBJECTIVE_D05, OBJECTIVE_D06, OBJECTIVE_D08,
              OBJECTIVE_D09, OBJECTIVE_D10, OBJECTIVE_D11, OBJECTIVE_D12]


def init_db():
    Base.metadata.create_all(bind=engine)


def seed_if_empty():
    import json as _json

    db = SessionLocal()
    try:
        # ponytail: por id → agrega el que falte (m9, objetivos nuevos) sin tocar el resto
        for mid, title, order in MODULES:
            row = db.query(models.Module).filter_by(id=mid).first()
            if row is None:
                db.add(models.Module(id=mid, title=title, order_index=order))
            elif row.title != title:
                row.title = title
        if db.query(models.User).count() == 0:
            for uid, name, role in USERS:
                db.add(models.User(id=uid, display_name=name, role=role))
        for lid, title, ltype, mid, order, desc in LABS:
            if not db.query(models.LabTemplate).filter_by(id=lid).first():
                db.add(models.LabTemplate(id=lid, title=title, lab_type=ltype,
                                          module_id=mid, order_index=order,
                                          description=desc))
        if hasattr(models, "LearningObjective"):
            for o in OBJECTIVES:
                row = db.query(models.LearningObjective).filter_by(id=o["id"]).first()
                if row is None:
                    db.add(models.LearningObjective(
                        id=o["id"], lab_template_id=o["lab_template_id"], title=o["title"],
                        level=o["level"], concept_summary=o["concept_summary"],
                        worked_example_json=_json.dumps(o["worked_example_steps"]),
                        misconceptions_json=_json.dumps(o["misconceptions"]),
                        rubric_id=o["rubric_id"],
                        diagnostic_blueprint_json=_json.dumps(o["diagnostic_blueprint"]),
                        status=o.get("status", "planned")))
                else:
                    # Bases ya creadas: sincroniza estado, diagnóstico y contenido.
                    row.status = o.get("status", "planned")
                    row.diagnostic_blueprint_json = _json.dumps(o["diagnostic_blueprint"])
                    # El contenido didáctico vive en el código: se corrige sin borrar la base.
                    row.title = o["title"]
                    row.concept_summary = o["concept_summary"]
                    row.worked_example_json = _json.dumps(o["worked_example_steps"])
                    row.misconceptions_json = _json.dumps(o["misconceptions"])
        db.commit()
    finally:
        db.close()


if __name__ == "__main__":
    from app.db import upgrade_head

    upgrade_head()
    seed_if_empty()
    print("seed ok")
