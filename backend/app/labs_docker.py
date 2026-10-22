"""Docker Academy: escenarios por unidad y semilla (simulación determinista).
`activity()` devuelve solo lo público (sin respuestas); la verdad vive aquí y
la usan la corrección de retos (`check`) y la evaluación mock. Semilla 1 =
práctica; el reto usa otra semilla y el postest la variante del servidor."""
import random

UNITS = ["M08-D01-containers", "M08-D02-lifecycle", "M08-D04-dockerfile", "M08-D07-persistence"]

# D01: (escenario, 0 = contenedor, 1 = máquina virtual)
_D01 = [
    ("Una API FastAPI que debe correr igual en tu PC y en el servidor", 0),
    ("Probar un driver que necesita un kernel distinto al del host", 1),
    ("Levantar 20 copias ligeras de un servicio que arrancan en segundos", 0),
    ("Ejecutar un Windows completo sobre un host Linux", 1),
    ("Empaquetar un script de Python con sus dependencias para CI", 0),
    ("Aislar un software que exige su propio kernel parcheado", 1),
    ("Desplegar el mismo worker en varias máquinas con la misma imagen", 0),
    ("Probar un módulo del kernel sin arriesgar el host", 1),
    ("Una base de datos de desarrollo desechable para pruebas", 0),
]

# D02: qué existe tras cada paso del ciclo
LIFECYCLE = ["pull / build", "run", "stop", "rm"]
_D02_EXISTS = {"pull / build": "imagen", "run": "ambos", "stop": "ambos", "rm": "imagen"}
D02_OPTIONS = ["imagen", "contenedor", "ambos", "ninguno"]

# D04: Dockerfiles en orden correcto; rol de cada línea para corregir
_ROLES = ["base", "workdir", "deps", "install", "code", "cmd"]
_D04 = [
    ("API FastAPI", ["FROM python:3.12-slim", "WORKDIR /app", "COPY requirements.txt ./",
                     "RUN pip install --no-cache-dir -r requirements.txt", "COPY ./app ./app",
                     'CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0"]']),
    ("servicio Node", ["FROM node:20-slim", "WORKDIR /srv", "COPY package*.json ./",
                       "RUN npm ci --omit=dev", "COPY ./src ./src", 'CMD ["node", "src/index.js"]']),
    ("worker Python", ["FROM python:3.12-slim", "WORKDIR /w", "COPY requirements.txt ./",
                       "RUN pip install -r requirements.txt", "COPY ./worker ./worker",
                       'CMD ["python", "-m", "worker"]']),
]

# D07: qué dato hay que conservar al recrear el contenedor
_D07 = [("la base SQLite de la API", "/data/app.db"),
        ("las fotos que suben los usuarios", "/srv/uploads"),
        ("los logs de auditoría", "/var/log/app")]
MOUNTS = ["sin montaje", "named volume", "bind mount"]


def activity(unit: str, seed: int = 1) -> dict:
    """Contenido público del experimento (nunca incluye respuestas)."""
    rnd = random.Random(f"{unit}:{seed}")
    if unit == "M08-D01-containers":
        picks = rnd.sample(range(len(_D01)), 3)
        if len({_D01[i][1] for i in picks}) == 1:  # que no salgan todas iguales
            picks[2] = next(i for i in range(len(_D01)) if _D01[i][1] != _D01[picks[0]][1])
        return {"unit": unit, "seed": seed, "scenarios": [_D01[i][0] for i in picks]}
    if unit == "M08-D02-lifecycle":
        return {"unit": unit, "seed": seed, "ask_stage": rnd.choice(LIFECYCLE),
                "options": D02_OPTIONS}
    if unit == "M08-D04-dockerfile":
        app, lines = _D04[rnd.randrange(len(_D04))]
        shuffled = list(lines)
        while shuffled == lines or _order_constraints(shuffled, lines)[1] == []:
            rnd.shuffle(shuffled)
        return {"unit": unit, "seed": seed, "app": app, "lines": shuffled}
    if unit == "M08-D07-persistence":
        story, path = _D07[rnd.randrange(len(_D07))]
        return {"unit": unit, "seed": seed, "story": story, "path": path, "mounts": MOUNTS}
    return {"unit": unit, "seed": seed}


def _d01_answers(seed: int) -> dict:
    texts = activity("M08-D01-containers", seed)["scenarios"]
    return {t: a for t, a in _D01 if t in texts}


def _dockerfile_for(order: list) -> list | None:
    names = {str(x) for x in order}
    for _, lines in _D04:
        if set(lines) == names:
            return lines
    return None


def _order_constraints(order: list, lines: list) -> tuple[list, list]:
    """Reglas de un Dockerfile cacheable: (cumplidas, incumplidas)."""
    role = {line: r for line, r in zip(lines, _ROLES)}
    pos = {role[str(x)]: i for i, x in enumerate(order) if str(x) in role}
    rules = [
        ("FROM va primero", pos.get("base") == 0),
        ("WORKDIR antes de copiar archivos", pos.get("workdir", 99) < pos.get("deps", -1)),
        ("dependencias antes que el código (conserva la caché)",
         pos.get("deps", 99) < pos.get("install", -1) < pos.get("code", -1)),
        ("CMD va al final", pos.get("cmd") == len(order) - 1),
    ]
    return [n for n, ok in rules if ok], [n for n, ok in rules if not ok]


def dockerfile_ok(order: list) -> bool | None:
    """True/False si el orden corresponde a un Dockerfile del banco; None si no."""
    lines = _dockerfile_for(order or [])
    return None if lines is None else not _order_constraints(order, lines)[1]


def check(unit: str, seed: int, payload: dict) -> dict | None:
    """Corrección descriptiva de una entrega del experimento (sin revelar respuestas)."""
    p = payload if isinstance(payload, dict) else {}
    if unit == "M08-D01-containers":
        texts = activity(unit, seed)["scenarios"]
        answers = _d01_answers(seed)
        choices = p.get("choices") if isinstance(p.get("choices"), list) else []
        ok = [str(i + 1) for i, t in enumerate(texts) if i < len(choices) and choices[i] == answers[t]]
        bad = [str(i + 1) for i in range(len(texts)) if str(i + 1) not in ok]
        return {"correctas": ok, "revisar": bad, "item": "escenario",
                "consejo": "Pregúntate si el caso necesita su propio kernel o solo aislar procesos."}
    if unit == "M08-D02-lifecycle":
        stage = activity(unit, seed)["ask_stage"]
        right = p.get("prediction") == _D02_EXISTS[stage]
        label = f"qué existe tras «{stage}»"
        return {"correctas": [label] if right else [], "revisar": [] if right else [label],
                "item": None,
                "consejo": "Distingue la plantilla (imagen) de la instancia (contenedor)."}
    if unit == "M08-D04-dockerfile":
        order = p.get("order") if isinstance(p.get("order"), list) else []
        lines = _dockerfile_for(order)
        if lines is None:
            return None
        ok, bad = _order_constraints(order, lines)
        return {"correctas": ok, "revisar": bad, "item": None,
                "consejo": "Lo que cambia poco va arriba; lo que cambia seguido, abajo."}
    if unit == "M08-D07-persistence":
        mount, pred = p.get("mount"), p.get("predicted")
        if mount not in MOUNTS or pred is None:
            return None
        label = f"tu predicción con «{mount}»"
        right = bool(pred) == (mount != "sin montaje")
        return {"correctas": [label] if right else [], "revisar": [] if right else [label],
                "item": None,
                "consejo": "Sin montaje, lo escrito vive en la capa del contenedor y muere con él."}
    return None


def d01_hits(seed: int, choices: list) -> int | None:
    """Aciertos de clasificación D01 (para la evaluación mock); None sin datos."""
    if not isinstance(choices, list) or not choices:
        return None
    return len(check("M08-D01-containers", seed, {"choices": choices})["correctas"])


def d02_right(seed: int, prediction) -> bool | None:
    if prediction is None:
        return None
    return bool(check("M08-D02-lifecycle", seed, {"prediction": prediction})["correctas"])
