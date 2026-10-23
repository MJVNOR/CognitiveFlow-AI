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
D02_OPTIONS = ["imagen", "contenedor", "ambos", "ninguno"]
# Secuencias de comandos válidas; la respuesta sale de simular el estado.
_D02_SEQUENCES = [
    ["docker pull", "docker run", "docker stop", "docker rm"],
    ["docker build", "docker run", "docker stop", "docker start"],
    ["docker pull", "docker run --rm", "docker stop"],
    ["docker pull", "docker run", "docker stop", "docker rm", "docker rmi"],
    ["docker build", "docker run", "docker stop"],
    ["docker pull", "docker run --rm", "docker stop", "docker run"],
    ["docker build", "docker run", "docker stop", "docker rm", "docker run"],
]


def _d02_exists(steps: list[str]) -> str:
    """Qué existe tras ejecutar los pasos: imagen / contenedor / ambos / ninguno."""
    image, container, auto_rm = False, False, False
    for s in steps:
        if s in ("docker pull", "docker build"):
            image = True
        elif s.startswith("docker run"):
            container, auto_rm = True, s.endswith("--rm")
        elif s == "docker stop" and auto_rm:
            container = False  # --rm: el contenedor se borra al detenerse
        elif s == "docker rm":
            container = False
        elif s == "docker rmi":
            image = False
    return {(True, True): "ambos", (True, False): "imagen",
            (False, True): "contenedor", (False, False): "ninguno"}[(image, container)]

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
    if unit in DECISION_UNITS:
        return decision_activity(unit, seed)
    rnd = random.Random(f"{unit}:{seed}")
    if unit == "M08-D01-containers":
        picks = rnd.sample(range(len(_D01)), 3)
        if len({_D01[i][1] for i in picks}) == 1:  # que no salgan todas iguales
            picks[2] = next(i for i in range(len(_D01)) if _D01[i][1] != _D01[picks[0]][1])
        return {"unit": unit, "seed": seed,
                "instruction": "Elige la opción más ligera que satisface todos los requisitos: contenedor o máquina virtual. Supón un host Linux, sin una VM auxiliar.",
                "scenarios": [_D01[i][0] for i in picks]}
    if unit == "M08-D02-lifecycle":
        steps = _D02_SEQUENCES[rnd.randrange(len(_D02_SEQUENCES))]
        ask = rnd.randrange(1, len(steps))  # nunca el primer paso (sería trivial)
        return {"unit": unit, "seed": seed,
                "instruction": "Predice qué recursos existirán después del paso señalado. Después ejecuta la secuencia simulada y compara tu predicción con lo observado.",
                "context": "Partimos sin imágenes ni contenedores. Seguimos una sola imagen y un solo contenedor; los comandos están abreviados y siempre se refieren a ellos. El proceso permanece activo hasta stop.",
                "stages": steps, "ask_index": ask,
                "ask_stage": steps[ask], "options": D02_OPTIONS}
    if unit == "M08-D04-dockerfile":
        app, lines = _D04[rnd.randrange(len(_D04))]
        shuffled = list(lines)
        while shuffled == lines or _order_constraints(shuffled, lines)[1] == []:
            rnd.shuffle(shuffled)
        return {"unit": unit, "seed": seed, "app": app, "lines": shuffled,
                "instruction": "Ordena este Dockerfile para construir la app y reutilizar la caché de dependencias al cambiar solo el código. Coloca CMD al final como convención de lectura."}
    if unit == "M08-D07-persistence":
        story, path = _D07[rnd.randrange(len(_D07))]
        return {"unit": unit, "seed": seed, "story": story, "path": path, "mounts": MOUNTS,
                "instruction": "Elige el montaje, predice si el archivo sobrevivirá y compruébalo al eliminar y recrear el contenedor. Se reutiliza el mismo montaje; no se elimina el volumen ni la carpeta del host."}
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
        ("CMD al final (convención pedida en este ejercicio)", pos.get("cmd") == len(order) - 1),
    ]
    return [n for n, ok in rules if ok], [n for n, ok in rules if not ok]


def dockerfile_ok(order: list) -> bool | None:
    """True/False si el orden corresponde a un Dockerfile del banco; None si no."""
    lines = _dockerfile_for(order or [])
    return None if lines is None else not _order_constraints(order, lines)[1]


def check(unit: str, seed: int, payload: dict) -> dict | None:
    """Corrección descriptiva de una entrega del experimento (sin revelar respuestas)."""
    p = payload if isinstance(payload, dict) else {}
    if unit in DECISION_UNITS:
        return decision_check(unit, seed, p)
    if unit == "M08-D01-containers":
        texts = activity(unit, seed)["scenarios"]
        answers = _d01_answers(seed)
        choices = p.get("choices") if isinstance(p.get("choices"), list) else []
        given = _answered(choices, len(texts))
        ok = [str(i + 1) for i, t in enumerate(texts) if i in given and choices[i] == answers[t]]
        bad = [str(i + 1) for i in given if str(i + 1) not in ok]
        return {"correctas": ok, "revisar": bad, "item": "escenario",
                "pendientes": len(texts) - len(given),
                "consejo": "Pregúntate si el caso necesita su propio kernel o solo aislar procesos."}
    if unit == "M08-D02-lifecycle":
        if p.get("prediction") not in D02_OPTIONS:
            return None
        a = activity(unit, seed)
        right = p.get("prediction") == _d02_exists(a["stages"][:a["ask_index"] + 1])
        label = f"qué existe tras el paso {a['ask_index'] + 1} («{a['ask_stage']}»)"
        return {"correctas": [label] if right else [], "revisar": [] if right else [label],
                "item": None,
                "consejo": "Separa existencia de estado en ejecución y revisa el efecto del comando señalado."}
    if unit == "M08-D04-dockerfile":
        order = p.get("order") if isinstance(p.get("order"), list) else []
        lines = _dockerfile_for(order)
        if lines is None:
            return None
        ok, bad = _order_constraints(order, lines)
        return {"correctas": ok, "revisar": bad, "item": None,
                "consejo": "Revisa qué archivos requiere cada instrucción y qué capas se invalidan si cambias solo el código."}
    if unit == "M08-D07-persistence":
        mount, pred = p.get("mount"), p.get("predicted")
        if mount not in MOUNTS or pred is None:
            return None
        label = f"tu predicción con «{mount}»"
        right = bool(pred) == (mount != "sin montaje")
        return {"correctas": [label] if right else [], "revisar": [] if right else [label],
                "item": None,
                "consejo": "Ubica dónde se escribió el archivo y qué recurso se elimina al recrear. Comprueba qué montaje se reutiliza."}
    return None


def d01_hits(seed: int, choices: list) -> int | None:
    """Aciertos de clasificación D01 (para la evaluación mock); None sin datos."""
    if not isinstance(choices, list) or not choices:
        return None
    return len(check("M08-D01-containers", seed, {"choices": choices})["correctas"])


def d02_right(seed: int, prediction) -> bool | None:
    if prediction is None:
        return None
    result = check("M08-D02-lifecycle", seed, {"prediction": prediction})
    return bool(result["correctas"]) if result is not None else None


# Prerrequisito de cada unidad (se exige completada: postest + reflexión).
PREREQ = {"M08-D02-lifecycle": "M08-D01-containers",
          "M08-D03-cli": "M08-D02-lifecycle",
          "M08-D04-dockerfile": "M08-D02-lifecycle",
          "M08-D05-context": "M08-D04-dockerfile",
          "M08-D06-network": "M08-D03-cli",
          "M08-D07-persistence": "M08-D02-lifecycle",
          "M08-D08-compose": "M08-D06-network",
          "M08-D09-debug": "M08-D08-compose",
          "M08-D10-security": "M08-D05-context",
          "M08-D11-deploy": "M08-D09-debug",
          "M08-D12-capstone": "M08-D11-deploy"}


# ── Unidades de decisión (D03, D05, D06, D08–D12): casos realistas donde se
# elige qué hacer. Cada caso: (situación, respuesta correcta, distractores
# plausibles = errores típicos). El orden de opciones se baraja por semilla.
DECISION_UNITS = {
    "M08-D03-cli": [
        ("El contenedor api ya existe y la aplicación escribe sus errores en stdout/stderr. ¿Qué comando permite leerlos?",
         "docker logs api", ["docker images", "docker rm api"]),
        ("Necesitas abrir una shell nueva dentro del contenedor api, que está corriendo e incluye sh.",
         "docker exec -it api sh", ["docker run -it api sh", "docker attach api"]),
        ("¿Qué contenedores están corriendo ahora mismo?",
         "docker ps", ["docker images", "docker logs"]),
        ("Arranca la imagen web en segundo plano, llamada web, con el 8080 del host al 80.",
         "docker run -d --name web -p 8080:80 web",
         ["docker run web -p 80:8080", "docker start web:8080"]),
        ("Quieres ver también los contenedores detenidos.",
         "docker ps -a", ["docker ps", "docker images -a"]),
        ("Elimina la imagen local web:1.0; ningún contenedor la utiliza.",
         "docker rmi web:1.0", ["docker rm web:1.0", "docker stop web:1.0"]),
        ("Necesitas la IP, los montajes y las variables de un contenedor.",
         "docker inspect api", ["docker logs api", "docker top api"]),
        ("Quieres seguir los logs en vivo mientras reproduces el fallo.",
         "docker logs -f api", ["docker logs --tail 20 api", "docker inspect api"]),
    ],
    "M08-D05-context": [
        ("Construyes con docker build ./backend. config.yaml solo existe en la carpeta padre, no dentro de backend. ¿Por qué COPY no puede traerlo?",
         "El archivo está fuera del contexto de build",
         ["Falta un WORKDIR", "Docker no tiene permisos de lectura"]),
        ("El build tarda minutos «enviando el contexto» (node_modules, .git).",
         "Agregar node_modules y .git a .dockerignore",
         ["Usar una imagen base más grande", "Quitar el WORKDIR"]),
        ("El archivo .env con contraseñas terminó dentro de la imagen.",
         "Retirar la imagen afectada y rotar los secretos expuestos; excluir .env en builds futuros e inyectar secretos al ejecutar",
         ["Renombrarlo a .env.bak", "Moverlo a otra carpeta del mismo contexto"]),
        ("WORKDIR /app y luego COPY . . — ¿dónde quedan los archivos?",
         "En /app", ["En la raíz /", "En la carpeta del host"]),
        ("En un build local, ¿de dónde toma archivos COPY sin --from ni contextos adicionales?",
         "Solo el contexto enviado en docker build, menos lo ignorado",
         ["Todo tu disco", "Solo el Dockerfile"]),
        ("docker build -t api ./backend — ¿cuál es el contexto de build?",
         "La carpeta ./backend", ["La carpeta actual completa", "Solo el Dockerfile"]),
        ("Un archivo está en .dockerignore y una instrucción COPY lo pide.",
         "COPY falla: el archivo no está en el contexto",
         ["Se copia igual", "Se copia vacío"]),
    ],
    "M08-D06-network": [
        ("Un proceso servidor dentro del contenedor worker llama a http://localhost:8000 y falla. La API escucha en 0.0.0.0:8000 en el servicio api de la misma red Compose. ¿Qué dirección debe usar el worker?",
         "Usar http://api:8000 (el nombre del servicio)",
         ["Seguir usando localhost:8000", "Publicar el frontend también en el 8000"]),
        ("¿Qué significa -p 8080:80?",
         "El 8080 del host lleva al 80 del contenedor",
         ["El 80 del host lleva al 8080 del contenedor",
          "Abre ambos puertos dentro del contenedor"]),
        ("Hay EXPOSE 8000 en el Dockerfile pero ejecutaste sin -p. "
         "¿Abre localhost:8000 en tu navegador?",
         "No: EXPOSE documenta; -p publica",
         ["Sí: EXPOSE publica el puerto", "Solo en Linux"]),
        ("La base de datos solo debe ser accesible por la API, sin conexiones desde el host ni otros servicios. ¿Qué configuración cumple ese objetivo?",
         "No publicar su puerto y conectarla a una red dedicada compartida solo con la API",
         ["Publicarla en el 5432 para todos", "Usar la red del host"]),
        ("Dentro del contenedor api, en una red bridge normal (sin network_mode: host), «localhost» apunta a…",
         "Al propio contenedor api", ["A tu computadora", "A todos los contenedores"]),
        ("Dos contenedores en redes distintas no se ven entre sí.",
         "Conectarlos a una red compartida", ["Reiniciar Docker", "Darles el mismo nombre"]),
        ("Dos servicios piden -p 8000:8000 en el mismo host.",
         "Cambiar el puerto del host de uno (8001:8000)",
         ["Cambiar el EXPOSE", "Es imposible correr ambos"]),
    ],
    "M08-D08-compose": [
        ("La app lee DATABASE_HOST del entorno. La base está en el servicio db de la misma red Compose. ¿Cómo le pasas ese nombre?",
         "environment: {DATABASE_HOST: db}",
         ['ports: ["5432"]', "volumes: [DATABASE_URL]"]),
        ("Usas postgres:16. Sus datos deben sobrevivir a docker compose down sin -v y al recrear el servicio con el mismo volumen. ¿Qué necesitas?",
         "Un named volume montado en /var/lib/postgresql/data",
         ["depends_on: [db]", "restart: always"]),
        ("La API arranca antes de que la base acepte conexiones y falla.",
         "healthcheck en db + depends_on con condition: service_healthy",
         ["depends_on: [db] basta", "Publicar más puertos"]),
        ("Quieres construir la API desde ./backend en vez de bajar una imagen.",
         "build: ./backend", ["image: ./backend", "context: latest"]),
        ("Nginx escucha en el puerto 80 del contenedor frontend. Publícalo en el 3000 del host.",
         'ports: ["3000:80"]', ["expose: [3000]", "networks: [3000]"]),
        ("El servicio debe reiniciarse si termina con código distinto de cero, pero no cuando termina correctamente. ¿Qué política corresponde?",
         "restart: on-failure", ["restart: always", "restart: 'no'"]),
        ("La app puede leer contraseñas desde archivos. ¿Cómo suministrarlas sin grabarlas en la imagen ni en compose.yaml?",
         "Montarlas como secrets y configurar la app para leer esos archivos",
         ["Escritas en compose.yaml", "Dentro de la imagen"]),
    ],
    "M08-D09-debug": [
        ("docker run termina al instante con exit code 1.",
         "Leer docker logs del contenedor",
         ["Reconstruir sin caché a ciegas", "Borrar todas las imágenes"]),
        ("El build falla en COPY requirements.txt.",
         "Revisar que el archivo esté en el contexto y la ruta sea correcta",
         ["Cambiar la imagen base", "Agregar EXPOSE"]),
        ("Cada cambio de código reinstala todas las dependencias.",
         "Copiar requirements e instalar antes de copiar el código",
         ["Usar la etiqueta latest", "Desactivar la caché"]),
        ("El contenedor termina con exit code 137 y docker inspect muestra State.OOMKilled=true. ¿Qué evidencia tenemos?",
         "Docker confirma que el proceso terminó por falta de memoria (OOM)",
         ["Hay un error de sintaxis", "El puerto está ocupado"]),
        ("En tu PC funciona; en el contenedor, que sigue corriendo y tiene shell, no encuentra un archivo. ¿Cómo compruebas qué rutas existen dentro?",
         "Revisar con docker exec qué hay en su filesystem",
         ["Reinstalar Docker", "Subir la versión de Python"]),
        ("La imagen final pesa 1,5 GB con compiladores incluidos.",
         "Multi-stage: compilar en una etapa y copiar solo el resultado",
         ["Comprimir el contenedor", "Agregar más capas RUN"]),
        ("Al levantar aparece «port is already allocated».",
         "Otro proceso usa ese puerto del host: revisar y cambiar el mapeo",
         ["La imagen está corrupta", "Falta un healthcheck"]),
    ],
    "M08-D10-security": [
        ("El Dockerfile tiene ENV API_KEY=abc123.",
         "Riesgo: queda grabada en la imagen; pasarla al ejecutar",
         ["Es seguro si el repo es privado", "Es seguro porque es una variable"]),
        ("La aplicación web no requiere privilegios especiales, pero su proceso corre como root. ¿Cómo reduces sus privilegios?",
         "Crear un usuario sin privilegios y usar USER",
         ["Es lo recomendado", "Da igual dentro de Docker"]),
        ("Quieres usar exactamente el mismo contenido de la imagen base en builds futuros. Una etiqueta, incluso 3.12-slim, puede cambiar. ¿Qué referencia lo fija?",
         "Fijar el digest verificado de la imagen base (FROM python@sha256:…)",
         ["latest siempre es más seguro", "No tiene efecto"]),
        ("La imagen incluye .git y archivos de prueba.",
         "Excluirlos con .dockerignore",
         ["Borrarlos con RUN rm después del COPY", "No importa"]),
        ("Antes de publicar una imagen…",
         "Escanearla en busca de vulnerabilidades",
         ["Subirla directo", "Quitarle la etiqueta"]),
        ("Dos imágenes satisfacen los requisitos y se mantienen actualizadas. Una incluye compiladores y paquetes que tu app no usa. ¿Cuál reduce componentes expuestos?",
         "La mínima compatible con la app, sin herramientas innecesarias",
         ["Completa: más paquetes, más seguro", "Siempre ubuntu completo"]),
        ("Una app web sin necesidad de administrar Docker monta el socket de un daemon rootful del host. ¿Qué riesgo añade?",
         "Permite controlar el daemon y comprometer el host: quitar ese montaje",
         ["Recomendado para leer logs", "Es inofensivo"]),
    ],
    "M08-D11-deploy": [
        ("Quieres recuperar el contenido exacto de una release anterior; las etiquetas del registry son mutables. ¿Qué debes registrar?",
         "El digest de cada imagen publicada, para desplegar esa misma referencia",
         ["Usar siempre latest", "Copiar archivos al servidor"]),
        ("Vas a migrar la base de datos en producción.",
         "Crear un respaldo consistente con la herramienta de la base y verificar su restauración antes de migrar",
         ["Respaldar solo el contenedor", "Nada: Docker guarda todo"]),
        ("El diseño del despliegue usa un reverse proxy para gestionar certificados y enviar HTTP a la app en una red privada. ¿Dónde se termina TLS?",
         "En el reverse proxy (Nginx, Traefik) delante de la app",
         ["Dentro de cada contenedor sin proxy", "En la base de datos"]),
        ("Llevar la imagen de tu laptop al servidor.",
         "docker push a un registry y docker pull en el servidor",
         ["Copiar el contenedor con scp", "Reconstruir a mano en el servidor"]),
        ("La configuración cambia entre desarrollo y producción.",
         "Variables de entorno por entorno, misma imagen",
         ["Una imagen distinta con valores fijos", "Editar el contenedor en vivo"]),
        ("La versión nueva falla; la anterior sigue siendo compatible con el esquema de datos actual y guardaste su digest. ¿Cómo vuelves sin tocar los datos?",
         "Desplegar la imagen anterior por su digest y comprobar su salud",
         ["Arreglarlo dentro del contenedor con exec", "Borrar el volumen"]),
        ("El equipo necesita builds repetibles, revisados y trazables por commit, sin pasos manuales por desarrollador. ¿Qué proceso conviene?",
         "CI/CD con builds trazables",
         ["Cada desarrollador desde su laptop", "El servidor de producción"]),
    ],
}
DECISION_UNITS["M08-D12-capstone"] = []  # mezcla casos de todas las unidades
UNITS += list(DECISION_UNITS)


def _decision_items(unit: str, seed: int) -> list[tuple[str, list[str], int]]:
    """Casos de la variante: (situación, opciones barajadas, índice correcto)."""
    rnd = random.Random(f"{unit}:{seed}")
    if unit == "M08-D12-capstone":
        units = rnd.sample([u for u in DECISION_UNITS if u != unit], 4)
        cases = [rnd.choice(DECISION_UNITS[u]) for u in units]
    else:
        cases = rnd.sample(DECISION_UNITS[unit], 3)
    out = []
    for prompt, right, wrong in cases:
        opts = [right, *wrong]
        rnd.shuffle(opts)
        out.append((prompt, opts, opts.index(right)))
    return out


def decision_activity(unit: str, seed: int) -> dict:
    """Contenido público de una unidad de decisión (nunca la respuesta)."""
    items = _decision_items(unit, seed)
    return {"unit": unit, "seed": seed, "mono": unit == "M08-D03-cli",
            "instruction": ("Resuelve cuatro decisiones de unidades distintas y justifica cada una. Es un ejercicio de decisiones, no una ejecución real de Docker."
                            if unit == "M08-D12-capstone" else
                            "Lee los requisitos de cada caso, elige la acción que los cumple y justifica con una observación o un comando que permita comprobarla."),
            "items": [{"prompt": p, "options": o} for p, o, _ in items]}


def _answered(choices: list, n: int) -> list[int]:
    """Índices ya elegidos: solo se corrige lo que el alumno respondió."""
    return [i for i in range(min(n, len(choices))) if choices[i] is not None]


_DECISION_ADVICE = {
    "M08-D03-cli": "Identifica la acción pedida y si el comando actúa sobre una imagen o un contenedor existente.",
    "M08-D05-context": "Ubica el contexto del build, el archivo origen y las exclusiones antes de interpretar COPY.",
    "M08-D06-network": "Ubica dónde se ejecuta el cliente; después distingue red, dirección y puerto de destino.",
    "M08-D08-compose": "Separa configuración, almacenamiento y disponibilidad: identifica qué requisito concreto pide el caso.",
    "M08-D09-debug": "Distingue síntoma de causa y busca el dato que permitiría confirmar tu diagnóstico.",
    "M08-D10-security": "Comprueba qué dato o capacidad se expone y si la aplicación realmente lo necesita.",
    "M08-D11-deploy": "Separa imagen, configuración y datos; comprueba trazabilidad y compatibilidad antes de cambiar de versión.",
    "M08-D12-capstone": "Justifica cada caso por separado: requisito, mecanismo y comprobación del resultado.",
}


def decision_check(unit: str, seed: int, payload: dict) -> dict:
    items = _decision_items(unit, seed)
    choices = payload.get("choices") if isinstance(payload.get("choices"), list) else []
    given = _answered(choices, len(items))
    ok = [str(i + 1) for i, (_, _, ans) in enumerate(items) if i in given and choices[i] == ans]
    return {"correctas": ok,
            "revisar": [str(i + 1) for i in given if str(i + 1) not in ok],
            "item": "caso",
            "pendientes": len(items) - len(given),
            "consejo": _DECISION_ADVICE[unit]}


def decision_hits(unit: str, seed: int, choices) -> tuple[int, int] | None:
    """(aciertos, total) para la evaluación mock; None sin elecciones."""
    if unit not in DECISION_UNITS or not isinstance(choices, list) or not choices:
        return None
    return (len(decision_check(unit, seed, {"choices": choices})["correctas"]),
            len(_decision_items(unit, seed)))


def response_evidence(unit: str, seed: int, payload: dict) -> dict:
    """Respuesta acotada, nunca verdad ni puntuación del cliente. Unidad/variante del servidor."""
    a = activity(unit, seed)
    if unit in DECISION_UNITS or unit == "M08-D01-containers":
        choices = payload.get("choices")
        counts = [len(i["options"]) for i in a["items"]] if "items" in a else [2] * len(a["scenarios"])
        if not isinstance(choices, list) or len(choices) != len(counts) or any(
                type(v) is not int or not 0 <= v < n for v, n in zip(choices, counts)):
            raise ValueError("Responde todos los casos de la prueba")
        return {"unit": unit, "choices": choices}
    if unit == "M08-D02-lifecycle" and payload.get("prediction") in D02_OPTIONS:
        return {"unit": unit, "prediction": payload["prediction"]}
    if unit == "M08-D04-dockerfile":
        order = payload.get("order")
        if isinstance(order, list) and all(isinstance(v, str) for v in order) and len(order) == len(a["lines"]) and set(order) == set(a["lines"]):
            return {"unit": unit, "order": order}
    if unit == "M08-D07-persistence" and payload.get("mount") in MOUNTS and type(payload.get("predicted")) is bool:
        return {"unit": unit, "mount": payload["mount"], "predicted": payload["predicted"]}
    raise ValueError("Falta la decisión del experimento de esta prueba")
