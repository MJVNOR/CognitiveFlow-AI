"""Docker Academy: escenarios por unidad y semilla (simulación determinista).
`activity()` devuelve solo lo público (sin respuestas); la verdad vive aquí y
la usan la corrección de retos (`check`) y la evaluación mock. Semilla 1 =
práctica; el reto usa otra semilla y el postest la variante del servidor."""
import random

UNITS = ["M08-D01-containers", "M08-D02-lifecycle", "M08-D04-dockerfile", "M08-D07-persistence"]

# D01: (escenario, 0 = contenedor, 1 = máquina virtual, eje que decide el caso).
# El eje permite pedir una variante contrastiva: casos que cambian solo en eso.
_D01 = [
    ("Una API FastAPI que debe correr igual en tu PC y en el servidor", 0, "reproducibilidad"),
    ("Probar un driver que necesita un kernel distinto al del host", 1, "kernel"),
    ("Levantar 20 copias ligeras de un servicio que arrancan en segundos", 0, "peso"),
    ("Ejecutar un Windows completo sobre un host Linux", 1, "kernel"),
    ("Empaquetar un script de Python con sus dependencias para CI", 0, "reproducibilidad"),
    ("Aislar un software que exige su propio kernel parcheado", 1, "kernel"),
    ("Desplegar el mismo worker en varias máquinas con la misma imagen", 0, "reproducibilidad"),
    ("Probar un módulo del kernel sin arriesgar el host", 1, "kernel"),
    ("Una base de datos de desarrollo desechable para pruebas", 0, "peso"),
]

# D02: qué existe tras cada paso del ciclo
D02_OPTIONS = ["imagen", "contenedor", "ambos", "ninguno"]
# Secuencias de comandos válidas; la respuesta sale de simular el estado.
_D02_SEQUENCES = [
    (["docker pull", "docker run", "docker stop", "docker rm"], "borrado"),
    (["docker build", "docker run", "docker stop", "docker start"], "estado"),
    (["docker pull", "docker run --rm", "docker stop"], "efimero"),
    (["docker pull", "docker run", "docker stop", "docker rm", "docker rmi"], "borrado"),
    (["docker build", "docker run", "docker stop"], "estado"),
    (["docker pull", "docker run --rm", "docker stop", "docker run"], "efimero"),
    (["docker build", "docker run", "docker stop", "docker rm", "docker run"], "borrado"),
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


# Ejes de contraste por unidad: permiten pedir una variante dirigida al error
# («solo cambia el requisito de kernel») en vez de otro escenario al azar.
# Las unidades de decisión se añaden al final del módulo (DECISION_AXES).
FOCUS_AXES = {
    "M08-D01-containers": ["kernel", "peso", "reproducibilidad"],
    "M08-D02-lifecycle": ["borrado", "estado", "efimero"],
}


def failed_axes(unit: str, seed: int, payload: dict, focus=None) -> dict:
    """Ejes de los casos acertados y fallados: «falló el caso de kernel» dice al
    planificador qué contrastar; «falló el caso 3» no dice nada."""
    c = check(unit, seed, payload, focus) or {}
    if unit in DECISION_UNITS and unit in DECISION_AXES:
        axes = _decision_axis_of(unit, seed, focus)
        pick = lambda ids: sorted({axes[int(i) - 1] for i in ids  # noqa: E731
                                   if str(i).isdigit() and int(i) <= len(axes)})
        return {"fallados": pick(c.get("revisar", [])), "acertados": pick(c.get("correctas", []))}
    if unit == "M08-D01-containers":
        texts = activity(unit, seed, focus)["scenarios"]
        axis = {t: next(x[2] for x in _D01 if x[0] == t) for t in texts}
        pick = lambda ids: sorted({axis[texts[int(i) - 1]] for i in ids  # noqa: E731
                                   if str(i).isdigit() and int(i) <= len(texts)})
        return {"fallados": pick(c.get("revisar", [])), "acertados": pick(c.get("correctas", []))}
    if unit == "M08-D02-lifecycle":
        steps = activity(unit, seed, focus)["stages"]
        tag = next((t for q, t in _D02_SEQUENCES if q == steps), None)
        key = "fallados" if c.get("revisar") else "acertados"
        return {key: [tag] if tag else [], "fallados" if key == "acertados" else "acertados": []}
    return {"fallados": [], "acertados": []}


def focus_for(unit: str, focus) -> str | None:
    """Eje válido para esa unidad, o None (el servidor elige como siempre)."""
    return focus if isinstance(focus, str) and focus in FOCUS_AXES.get(unit, []) else None


def _d01_picks(rnd, focus: str | None) -> list[int]:
    """Tres casos; con eje, dos de ese eje y uno que contrasta (otra respuesta)."""
    if focus is None:
        picks = rnd.sample(range(len(_D01)), 3)
    else:
        axis = [i for i, c in enumerate(_D01) if c[2] == focus]
        picks = rnd.sample(axis, min(2, len(axis)))
        rest = [i for i in range(len(_D01)) if i not in picks]
        picks.append(rnd.choice(rest))
    if len({_D01[i][1] for i in picks}) == 1:  # que no salgan todas iguales
        picks[2] = next(i for i in range(len(_D01))
                        if _D01[i][1] != _D01[picks[0]][1] and i not in picks[:2])
    return picks


def activity(unit, seed: int = 1, focus=None, kind: str = "default") -> dict:
    """Contenido público del experimento (nunca incluye respuestas).
    [focus] = eje a contrastar dentro de la unidad; inválido se ignora.
    [kind] = motor de la actividad: el de la unidad («default») o uno compartido
    entre unidades (audit, command, order, timeline, mixed). En «mixed», [unit]
    es la lista de unidades que se mezclan."""
    if kind != "default":
        return _SHARED_ACTIVITY[kind](unit, seed, focus)
    if unit in DECISION_UNITS:
        return decision_activity(unit, seed, focus)
    rnd = random.Random(f"{unit}:{seed}:{focus_for(unit, focus) or ''}")
    axis = focus_for(unit, focus)
    if unit == "M08-D01-containers":
        picks = _d01_picks(rnd, axis)
        return {"unit": unit, "seed": seed,
                "instruction": "Elige la opción más ligera que satisface todos los requisitos: contenedor o máquina virtual. Supón un host Linux, sin una VM auxiliar.",
                **({"focus": axis} if axis else {}),
                "scenarios": [_D01[i][0] for i in picks]}
    if unit == "M08-D02-lifecycle":
        pool = [q for q, tag in _D02_SEQUENCES if axis is None or tag == axis]
        steps = pool[rnd.randrange(len(pool))]
        ask = rnd.randrange(1, len(steps))  # nunca el primer paso (sería trivial)
        return {"unit": unit, "seed": seed,
                "instruction": "Predice qué recursos existirán después del paso señalado. Después ejecuta la secuencia simulada y compara tu predicción con lo observado.",
                "context": "Partimos sin imágenes ni contenedores. Seguimos una sola imagen y un solo contenedor; los comandos están abreviados y siempre se refieren a ellos. El proceso permanece activo hasta stop.",
                **({"focus": axis} if axis else {}),
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


def _d01_answers(seed: int, focus=None) -> dict:
    texts = activity("M08-D01-containers", seed, focus)["scenarios"]
    return {c[0]: c[1] for c in _D01 if c[0] in texts}


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


def check(unit, seed: int, payload: dict, focus=None, kind: str = "default") -> dict | None:
    """Corrección descriptiva de una entrega del experimento (sin revelar respuestas).
    [focus] y [kind] deben ser los mismos con los que se generó: si no, calificaría
    otro escenario."""
    p = payload if isinstance(payload, dict) else {}
    if kind != "default":
        return _SHARED_CHECK[kind](unit, seed, p, focus)
    if unit in DECISION_UNITS:
        return decision_check(unit, seed, p, focus)
    if unit == "M08-D01-containers":
        texts = activity(unit, seed, focus)["scenarios"]
        answers = _d01_answers(seed, focus)
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
        a = activity(unit, seed, focus)
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


def _decision_picks(unit: str, seed: int, focus: str | None) -> list[int]:
    """Índices de los 3 casos de la variante. Con eje: dos de ese eje y uno de
    otro, para que el contraste siga existiendo (no todos del mismo tema)."""
    rnd = random.Random(f"{unit}:{seed}:{focus or ''}")
    n = len(DECISION_UNITS[unit])
    if focus is None:
        return rnd.sample(range(n), 3)
    axes = DECISION_AXES[unit]
    picks = rnd.sample([i for i, a in enumerate(axes) if a == focus], min(2, axes.count(focus)))
    # El relleno sale de OTRO eje: dirigido no significa monotema.
    rest = [i for i in range(n) if axes[i] != focus]
    return picks + rnd.sample(rest, 3 - len(picks))


def _decision_cases(unit: str, seed: int, focus: str | None = None) -> list[tuple]:
    """Casos crudos elegidos para la variante (con su respuesta: uso interno)."""
    rnd = random.Random(f"{unit}:{seed}")
    if unit == "M08-D12-capstone":
        units = rnd.sample([u for u in DECISION_UNITS if u != unit], 4)
        return [rnd.choice(DECISION_UNITS[u]) for u in units]
    bank = DECISION_UNITS[unit]
    return [bank[i] for i in _decision_picks(unit, seed, focus_for(unit, focus))]


def _decision_axis_of(unit: str, seed: int, focus=None) -> list[str]:
    """Eje de cada caso de la variante, en el orden en que se muestran."""
    bank = DECISION_UNITS[unit]
    axes = DECISION_AXES[unit]
    return [axes[bank.index(c)] for c in _decision_cases(unit, seed, focus)]


def _decision_items(unit: str, seed: int, focus=None) -> list[tuple[str, list[str], int]]:
    """Casos de la variante: (situación, opciones barajadas, índice correcto)."""
    rnd = random.Random(f"{unit}:{seed}")
    out = []
    for prompt, right, wrong in _decision_cases(unit, seed, focus):
        opts = [right, *wrong]
        rnd.shuffle(opts)
        out.append((prompt, opts, opts.index(right)))
    return out


def decision_activity(unit: str, seed: int, focus=None) -> dict:
    """Contenido público de una unidad de decisión (nunca la respuesta)."""
    items = _decision_items(unit, seed, focus)
    axis = focus_for(unit, focus)
    return {"unit": unit, "seed": seed, "mono": unit == "M08-D03-cli",
            **({"focus": axis} if axis else {}),
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


def decision_check(unit: str, seed: int, payload: dict, focus=None) -> dict:
    items = _decision_items(unit, seed, focus)
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


# ── Ejes de contraste de las unidades de decisión ──────────────────────────────
# Eje por índice del caso en su banco (no en cada tupla, para no duplicar el
# banco). `_axes_by_case` falla si un caso nuevo queda sin etiquetar: sin eje,
# la variante dirigida calificaría otro tema.
_DECISION_AXIS_INDEX = {
    "M08-D03-cli": {"observar": [0, 2, 4, 6, 7], "ejecutar": [1, 3], "limpiar": [5]},
    "M08-D05-context": {"alcance": [0, 4, 5], "exclusion": [1, 6], "secreto": [2], "rutas": [3]},
    "M08-D06-network": {"dns": [0, 4], "puerto": [1, 2, 6], "red": [3, 5]},
    "M08-D08-compose": {"configuracion": [0, 3, 6], "almacenamiento": [1],
                        "disponibilidad": [2, 5], "puerto": [4]},
    "M08-D09-debug": {"evidencia": [0, 3, 4], "causa": [1, 6], "capas": [2, 5]},
    "M08-D10-security": {"secreto": [0], "privilegio": [1, 6], "superficie": [2, 3, 4, 5]},
    "M08-D11-deploy": {"trazabilidad": [0, 5, 6], "datos": [1], "entrega": [2, 3, 4]},
}


def _axes_by_case(unit: str, groups: dict) -> list[str]:
    axis = {i: a for a, ids in groups.items() for i in ids}
    n = len(DECISION_UNITS[unit])
    assert set(axis) == set(range(n)), f"{unit}: casos sin eje {sorted(set(range(n)) - set(axis))}"
    return [axis[i] for i in range(n)]


DECISION_AXES = {u: _axes_by_case(u, g) for u, g in _DECISION_AXIS_INDEX.items()}
FOCUS_AXES.update({u: sorted(g) for u, g in _DECISION_AXIS_INDEX.items()})


# ── Repaso mezclado (DecisionScenarios compartido entre unidades) ─────────────
MIXED_MAX = 4


def mixed_units(units) -> list[str]:
    """Unidades de decisión válidas del repaso, en orden del temario (≤4)."""
    if isinstance(units, str):
        units = units.split("+")
    units = units if isinstance(units, list) else []
    return [u for u in UNITS if u in units and DECISION_UNITS.get(u)][:MIXED_MAX]


def _mixed_items(units: list[str], seed: int) -> list[tuple[str, list[str], int]]:
    rnd = random.Random("mixed:" + "+".join(units) + f":{seed}")
    out = []
    for u in units:
        prompt, right, wrong = rnd.choice(DECISION_UNITS[u])
        opts = [right, *wrong]
        rnd.shuffle(opts)
        out.append((prompt, opts, opts.index(right)))
    return out


def mixed_activity(units, seed: int, focus=None) -> dict:
    us = mixed_units(units)
    items = _mixed_items(us, seed)
    return {"unit": None, "units": us, "seed": seed, "mono": False,
            "instruction": "Un caso por tema ya trabajado: elige la acción que cumple los "
                           "requisitos y justifica con qué lo comprobarías.",
            "items": [{"prompt": p, "options": o} for p, o, _ in items]}


def mixed_check(units, seed: int, payload: dict, focus=None) -> dict | None:
    us = mixed_units(units)
    if not us:
        return None
    items = _mixed_items(us, seed)
    choices = payload.get("choices") if isinstance(payload.get("choices"), list) else []
    given = _answered(choices, len(items))
    ok = [str(i + 1) for i, (_, _, ans) in enumerate(items) if i in given and choices[i] == ans]
    return {"correctas": ok, "revisar": [str(i + 1) for i in given if str(i + 1) not in ok],
            "item": "caso", "pendientes": len(items) - len(given),
            "consejo": "Cada caso es de un tema distinto: identifica el requisito antes de elegir."}


# ── ConfigAudit (compartido): marcar TODO lo que aplica ───────────────────────
# unidad → variantes [(consigna, qué se audita, [(elemento, aplica)])].
# El orden de los elementos es contenido (no se baraja); la variedad sale de las
# variantes y de la semilla.
AUDIT_BANKS = {
    "M08-D04-dockerfile": [
        ("Cambias un archivo de app/ y vuelves a construir. Marca las instrucciones cuya capa "
         "se reconstruye.", "Dockerfile de la API, en este orden",
         [("FROM python:3.12-slim", False), ("WORKDIR /app", False),
          ("COPY requirements.txt ./", False),
          ("RUN pip install --no-cache-dir -r requirements.txt", False),
          ("COPY ./app ./app", True), ('CMD ["uvicorn", "app.main:app"]', True)]),
        ("Cambias una línea de requirements.txt y vuelves a construir. Marca las instrucciones "
         "cuya capa se reconstruye.", "Dockerfile de la API, en este orden",
         [("FROM python:3.12-slim", False), ("WORKDIR /app", False),
          ("COPY requirements.txt ./", True),
          ("RUN pip install --no-cache-dir -r requirements.txt", True),
          ("COPY ./app ./app", True), ('CMD ["uvicorn", "app.main:app"]', True)]),
    ],
    "M08-D05-context": [
        ("Construyes con docker build ./backend. Marca lo que no debe llegar a la imagen.",
         "contenido de ./backend",
         [(".env con las contraseñas de la base", True),
          ("node_modules/ (se instala durante el build)", True),
          (".git/ (historial del repositorio)", True),
          ("requirements.txt", False), ("app/ (el código de la API)", False),
          ("dist/ (artefacto de un build anterior)", True)]),
        ("docker build ./backend con un .dockerignore que contiene «node_modules» y «.env». "
         "Marca lo que COPY . . sí puede copiar.",
         "archivos del proyecto",
         [("backend/app/main.py", True), ("backend/requirements.txt", True),
          ("backend/.env", False), ("backend/node_modules/", False),
          ("config.yaml de la carpeta padre", False), ("backend/Dockerfile", True)]),
    ],
    "M08-D08-compose": [
        ("Requisitos: la API debe recibir el host de la base por entorno, los datos de postgres "
         "deben sobrevivir a «compose down» (sin -v) y la API no debe arrancar antes de que la "
         "base acepte conexiones. Marca lo que falta en este compose.",
         "compose.yaml: db (image: postgres:16) y api (build: ., depends_on: [db], "
         "ports: 8000:8000)",
         [("environment: DATABASE_HOST=db en api", True),
          ("named volume montado en /var/lib/postgresql/data de db", True),
          ("healthcheck en db + depends_on con condition: service_healthy", True),
          ("ports: 5432:5432 en db", False), ("privileged: true en api", False),
          ("restart: always en db", False)]),
        ("Requisitos: las contraseñas no deben quedar en la imagen ni en compose.yaml, el "
         "frontend (nginx, puerto 80) debe verse en el 3000 del host y la API no debe quedar "
         "accesible desde el host. Marca lo que cumple esos requisitos.",
         "opciones propuestas para el compose",
         [("secrets montados como archivos para la API", True),
          ('ports: ["3000:80"] en frontend', True),
          ("api sin ports, solo en la red compartida", True),
          ("environment: DB_PASSWORD=1234 en compose.yaml", False),
          ("ENV DB_PASSWORD en el Dockerfile de la API", False),
          ('ports: ["8000:8000"] en api', False)]),
    ],
    "M08-D09-debug": [
        ("El contenedor api termina solo. Marca las líneas de la evidencia que sostienen el "
         "diagnóstico.", "docker inspect api · docker logs api",
         [("State.ExitCode: 137", True), ("State.OOMKilled: true", True),
          ("HostConfig.Memory: 268435456", True),
          ("Pulling from library/python: ya actualizado", False),
          ("WARNING: pip cache deshabilitada", False), ("Started container api", False)]),
        ("El build falla en la instrucción COPY. Marca lo que explica el fallo.",
         "salida de docker build ./backend",
         [('ERROR: failed to compute cache key: "/requirements.txt" not found', True),
          ("requirements.txt está en la raíz del repo, no en ./backend", True),
          ("requirements.txt aparece en .dockerignore", True),
          ("Sending build context to Docker daemon 2.1MB", False),
          ("Step 1/6 : FROM python:3.12-slim --- Using cache", False)]),
    ],
    "M08-D10-security": [
        ("Marca los riesgos de este Dockerfile.", "Dockerfile de la API",
         [("ENV API_KEY=abc123", True), ("COPY . . con .git y las pruebas incluidas", True),
          ("sin USER: el proceso corre como root", True),
          ("FROM python:3.12-slim", False),
          ("RUN pip install --no-cache-dir -r requirements.txt", False),
          ("EXPOSE 8000", False)]),
        ("Marca lo que añade riesgo en este docker run.",
         "docker run -d --privileged -v /var/run/docker.sock:/var/run/docker.sock "
         "-e DB_PASSWORD=1234 -p 8000:8000 api:latest",
         [("--privileged", True),
          ("montar el socket de un daemon rootful del host", True),
          ("-e DB_PASSWORD=1234 (queda en el historial y en inspect)", True),
          ("api:latest en vez del digest publicado", True),
          ("-p 8000:8000", False), ("-d", False)]),
    ],
}

_AUDIT_TIP = {
    "M08-D04-dockerfile": "Una capa invalidada obliga a reconstruir todas las siguientes: "
                          "busca la primera instrucción afectada.",
    "M08-D05-context": "Separa qué se envía como contexto, qué está excluido y qué pide COPY.",
    "M08-D08-compose": "Vuelve a leer los requisitos: marca solo lo que cumple uno de ellos.",
    "M08-D09-debug": "Distingue el síntoma del dato que confirma la causa; el ruido del log no "
                     "prueba nada.",
    "M08-D10-security": "Pregúntate qué dato o capacidad queda expuesto y si la app lo necesita.",
}


def _audit_variant(unit: str, seed: int) -> tuple:
    bank = AUDIT_BANKS[unit]
    return bank[seed % len(bank)]


def audit_activity(unit: str, seed: int, focus=None) -> dict:
    instruction, subject, items = _audit_variant(unit, seed)
    return {"unit": unit, "seed": seed, "instruction": instruction, "subject": subject,
            "items": [t for t, _ in items], "multi": True}


def audit_check(unit: str, seed: int, payload: dict, focus=None) -> dict | None:
    _, _, items = _audit_variant(unit, seed)
    marked = payload.get("marked")
    if not isinstance(marked, list):
        return None
    sel = {i for i in marked if type(i) is int and 0 <= i < len(items)}
    ok = [f"el elemento {i + 1}" for i in sorted(sel) if items[i][1]]
    bad = [f"el elemento {i + 1}" for i in sorted(sel) if not items[i][1]]
    # Las omisiones no se enumeran (sería dar la respuesta); se avisa que faltan.
    if any(t for i, (_, t) in enumerate(items) if t and i not in sel):
        bad.append("falta al menos un elemento que sí aplica")
    return {"correctas": ok, "revisar": bad, "item": None, "consejo": _AUDIT_TIP[unit]}


# ── CommandComposer (compartido): armar el comando por ranuras ───────────────
# unidad → variantes [(consigna, prefijo, [(ranura, [opciones], índice correcto)])].
# Una opción entre paréntesis significa «no añadir nada» (no se concatena).
COMMAND_BANKS = {
    "M08-D03-cli": [
        ("Arranca la imagen web en segundo plano, con el nombre web y el 8080 del host "
         "publicado en el 80 del contenedor.", "docker",
         [("acción", ["run", "start", "exec"], 0),
          ("modo", ["-d", "-it", "(sin esa opción)"], 0),
          ("nombre", ["--name web", "--hostname web", "-n web"], 0),
          ("publicación", ["-p 8080:80", "-p 80:8080", "--port 8080"], 0),
          ("imagen", ["web", "web:8080", "./web"], 0)]),
        ("Abre una shell nueva dentro del contenedor api, que ya está corriendo e incluye sh.",
         "docker",
         [("acción", ["exec", "run", "start"], 0),
          ("modo", ["-it", "-d", "(sin esa opción)"], 0),
          ("objetivo", ["api", "api:latest", "./api"], 0),
          ("comando", ["sh", "docker sh", "(sin esa opción)"], 0)]),
    ],
    "M08-D06-network": [
        ("El worker debe alcanzar la API por su nombre en la red app-net, sin publicar puertos "
         "en el host.", "docker run -d",
         [("red", ["--network app-net", "--network host", "(sin esa opción)"], 0),
          ("publicación", ["(sin esa opción)", "-p 8000:8000", "-P"], 0),
          ("destino de la API", ["-e API_URL=http://api:8000",
                                 "-e API_URL=http://localhost:8000",
                                 "-e API_URL=http://127.0.0.1:8000"], 0),
          ("imagen", ["worker", "api", "worker:8000"], 0)]),
        ("Publica el frontend (nginx escucha en el 80 del contenedor) en el 3000 del host, en la "
         "red app-net.", "docker run -d",
         [("publicación", ["-p 3000:80", "-p 80:3000", "--expose 3000"], 0),
          ("red", ["--network app-net", "--network host", "(sin esa opción)"], 0),
          ("imagen", ["frontend", "frontend:3000", "./frontend"], 0)]),
    ],
    "M08-D07-persistence": [
        ("La base SQLite en /data/app.db debe sobrevivir a eliminar y recrear el contenedor, "
         "sin depender de una carpeta del host.", "docker",
         [("acción", ["run", "exec", "build"], 0),
          ("modo", ["-d", "-it", "(sin esa opción)"], 0),
          ("montaje", ["-v appdata:/data", "-v /data", "-v ./data:/data",
                       "(sin esa opción)"], 0),
          ("imagen", ["api", "api:/data", "./api"], 0)]),
        ("Las fotos que suben los usuarios se guardan en /srv/uploads y el equipo debe poder "
         "abrirlas en la carpeta ./uploads de su máquina.", "docker run -d",
         [("montaje", ["-v ./uploads:/srv/uploads", "-v uploads:/srv/uploads",
                       "(sin esa opción)"], 0),
          ("imagen", ["api", "api:uploads", "./api"], 0)]),
    ],
    "M08-D10-security": [
        ("Ejecuta la API sin privilegios de root, sin escritura en el filesystem de la imagen "
         "pero con /tmp escribible, y con la contraseña en un archivo montado de solo lectura.",
         "docker run -d",
         [("usuario", ["-u 1000:1000", "-u root", "--privileged"], 0),
          ("filesystem", ["--read-only", "(sin esa opción)", "--privileged"], 0),
          ("temporal", ["--tmpfs /tmp", "-v /tmp:/tmp", "(sin esa opción)"], 0),
          ("secreto", ["-v ./secrets/db:/run/secrets/db:ro", "-e DB_PASSWORD=1234",
                       "(sin esa opción)"], 0),
          ("imagen", ["api@sha256:9f2c", "api:latest", "api"], 0)]),
    ],
}

_COMMAND_TIP = {
    "M08-D03-cli": "Revisa si el comando actúa sobre una imagen o sobre un contenedor que ya "
                   "existe, y en qué orden van host y contenedor.",
    "M08-D06-network": "Separa red, dirección de destino y publicación al host: resuelven "
                       "problemas distintos.",
    "M08-D07-persistence": "Pregúntate qué recurso se elimina al recrear y cuál se reutiliza por "
                           "su nombre.",
    "M08-D10-security": "Comprueba qué capacidad o dato queda expuesto y si la app lo necesita.",
}


def _command_variant(unit: str, seed: int) -> tuple:
    bank = COMMAND_BANKS[unit]
    return bank[seed % len(bank)]


def _command_slots(unit: str, seed: int) -> list[tuple[str, list[str], int]]:
    """Ranuras con sus opciones barajadas por semilla (la correcta cambia de lugar)."""
    _, _, slots = _command_variant(unit, seed)
    rnd = random.Random(f"cmd:{unit}:{seed}")
    out = []
    for label, options, right in slots:
        opts = list(options)
        rnd.shuffle(opts)
        out.append((label, opts, opts.index(options[right])))
    return out


def command_activity(unit: str, seed: int, focus=None) -> dict:
    instruction, prefix, _ = _command_variant(unit, seed)
    return {"unit": unit, "seed": seed, "instruction": instruction, "prefix": prefix,
            "slots": [{"label": lbl, "options": opts} for lbl, opts, _ in
                      _command_slots(unit, seed)]}


def command_check(unit: str, seed: int, payload: dict, focus=None) -> dict | None:
    slots = _command_slots(unit, seed)
    choices = payload.get("slots")
    if not isinstance(choices, list):
        return None
    ok, bad = [], []
    for i, (label, _, right) in enumerate(slots):
        pick = choices[i] if i < len(choices) else None
        if pick is None:
            continue
        (ok if pick == right else bad).append(label)
    return {"correctas": ok, "revisar": bad, "item": None,
            "pendientes": sum(1 for i in range(len(slots))
                              if i >= len(choices) or choices[i] is None),
            "consejo": _COMMAND_TIP[unit]}


# ── Ordenar pasos (DockerfileWorkbench compartido) ───────────────────────────
# unidad → variantes [(consigna, pasos en orden correcto, [(regla, antes, después)])].
ORDER_BANKS = {
    "M08-D03-cli": [
        ("Ordena el diagnóstico de «api no responde»: de lo más general a lo que mira dentro "
         "del contenedor.",
         ["docker ps -a", "docker logs api", "docker inspect api", "docker exec -it api sh"],
         [("averiguar si el contenedor existe y en qué estado quedó, antes de leer logs", 0, 1),
          ("leer la evidencia antes de entrar al contenedor", 1, 3),
          ("confirmar puertos y montajes antes de buscar dentro", 2, 3)]),
    ],
    "M08-D08-compose": [
        ("Ordena el arranque del stack para que la API nunca vea la base caída.",
         ["docker compose build", "docker compose up -d db", "esperar el healthcheck de db",
          "docker compose up -d api", "docker compose logs -f api"],
         [("construir antes de levantar servicios", 0, 1),
          ("la base antes que la API", 1, 3),
          ("esperar el healthcheck antes de arrancar la API", 2, 3),
          ("comprobar con los logs al final", 3, 4)]),
    ],
    "M08-D11-deploy": [
        ("Ordena la publicación y el despliegue de la versión 1.4.2 con una referencia exacta.",
         ["docker build -t api:1.4.2 .",
          "docker tag api:1.4.2 registry.example.com/api:1.4.2",
          "docker push registry.example.com/api:1.4.2",
          "docker pull registry.example.com/api@sha256:9f2c (en el servidor)",
          "docker run -d registry.example.com/api@sha256:9f2c"],
         [("construir antes de etiquetar", 0, 1),
          ("etiquetar antes de publicar", 1, 2),
          ("publicar antes de descargar en el servidor", 2, 3),
          ("descargar la referencia exacta antes de ejecutarla", 3, 4)]),
    ],
}

_ORDER_TIP = {
    "M08-D03-cli": "Cada paso debe apoyarse en lo que mostró el anterior.",
    "M08-D08-compose": "Un servicio solo puede depender de otro que ya acepta conexiones.",
    "M08-D11-deploy": "Sigue la imagen: se construye, se etiqueta, se publica y se despliega por "
                      "su referencia exacta.",
}


def _order_variant(unit: str, seed: int) -> tuple:
    bank = ORDER_BANKS[unit]
    return bank[seed % len(bank)]


def order_activity(unit: str, seed: int, focus=None) -> dict:
    instruction, steps, rules = _order_variant(unit, seed)
    rnd = random.Random(f"order:{unit}:{seed}")
    shuffled = list(steps)
    while shuffled == steps or not _order_rules(shuffled, steps, rules)[1]:
        rnd.shuffle(shuffled)
    return {"unit": unit, "seed": seed, "instruction": instruction, "lines": shuffled,
            "app": "pasos del procedimiento"}


def _order_rules(order: list, steps: list, rules: list) -> tuple[list, list]:
    pos = {str(x): i for i, x in enumerate(order)}
    done, miss = [], []
    for text, a, b in rules:
        pa, pb = pos.get(steps[a]), pos.get(steps[b])
        (done if pa is not None and pb is not None and pa < pb else miss).append(text)
    return done, miss


def order_check(unit: str, seed: int, payload: dict, focus=None) -> dict | None:
    _, steps, rules = _order_variant(unit, seed)
    order = payload.get("order")
    if not isinstance(order, list) or {str(x) for x in order} != set(steps):
        return None
    done, miss = _order_rules(order, steps, rules)
    return {"correctas": done, "revisar": miss, "item": None, "consejo": _ORDER_TIP[unit]}


# ── Predecir el estado (ImageContainerLifecycle compartido) ───────────────────
# unidad → variantes [(contexto, pasos, estados visibles, paso a predecir,
# opciones, índice correcto)]. El estado del paso predicho se revela después.
TIMELINE_BANKS = {
    "M08-D06-network": [
        ("api escucha en 0.0.0.0:8000. Los dos contenedores arrancan en la red bridge por "
         "defecto, que no resuelve nombres de contenedor.",
         ["docker run -d --name api app", "docker run -d --name worker app",
          "worker: curl http://api:8000", "docker network create app-net + connect api y worker",
          "worker: curl http://api:8000"],
         ["api corriendo, sin red propia", "worker corriendo, misma red por defecto",
          "falla: en la red por defecto el nombre api no se resuelve",
          "api y worker conectados a app-net",
          "responde: app-net resuelve el nombre api"],
         2, ["responde 200", "falla: el nombre no se resuelve",
             "falla: el puerto no está publicado al host", "responde, pero el propio worker"], 1),
    ],
    "M08-D07-persistence": [
        ("El contenedor api escribe en /data/app.db y se montó el volumen named appdata en /data. "
         "No se elimina el volumen en ningún paso.",
         ["docker run -d --name api -v appdata:/data api", "dentro: escribir /data/app.db",
          "docker rm -f api", "docker run -d --name api -v appdata:/data api",
          "dentro: ls /data"],
         ["api corriendo con appdata montado", "app.db escrito dentro del volumen",
          "contenedor eliminado; el volumen appdata sigue existiendo",
          "api de nuevo corriendo con el mismo volumen",
          "app.db sigue ahí: el volumen sobrevive al contenedor"],
         4, ["app.db existe con sus datos", "/data está vacío", "app.db existe pero vacío",
             "el contenedor no arranca"], 0),
    ],
    "M08-D09-debug": [
        ("El servicio api tiene restart: always y su proceso termina al arrancar porque falta "
         "una variable de entorno obligatoria.",
         ["docker compose up -d api", "el proceso falla al leer la variable", "docker ps",
          "docker logs api", "docker compose up -d api otra vez"],
         ["api creado y arrancando", "el proceso termina con error de configuración",
          "Restarting: la política lo levanta y vuelve a fallar",
          "el log repite el mismo error de configuración",
          "vuelve a fallar: reiniciar no añade la variable"],
         2, ["api aparece Restarting", "api aparece Up y sano", "api no aparece: se eliminó",
             "api aparece Exited y quieto"], 0),
    ],
}

_TIMELINE_TIP = {
    "M08-D06-network": "Separa resolución de nombre, red compartida y publicación de puertos.",
    "M08-D07-persistence": "Ubica dónde se escribió el archivo y qué recurso se elimina al "
                           "recrear.",
    "M08-D09-debug": "Pregúntate si reiniciar cambia la causa o solo repite el síntoma.",
}


def _timeline_variant(unit: str, seed: int) -> tuple:
    bank = TIMELINE_BANKS[unit]
    return bank[seed % len(bank)]


def timeline_activity(unit: str, seed: int, focus=None) -> dict:
    context, steps, states, ask, options, _ = _timeline_variant(unit, seed)
    rnd = random.Random(f"timeline:{unit}:{seed}")
    opts = list(options)
    rnd.shuffle(opts)
    # El estado del paso predicho no viaja hasta que el alumno predice.
    public = [s if i != ask else None for i, s in enumerate(states)]
    return {"unit": unit, "seed": seed, "context": context,
            "instruction": "Predice qué pasa en el paso señalado. Después recorre la simulación "
                           "y compara tu predicción con lo observado.",
            "stages": steps, "states": public, "ask_index": ask, "ask_stage": steps[ask],
            "options": opts}


def timeline_check(unit: str, seed: int, payload: dict, focus=None) -> dict | None:
    _, steps, states, ask, options, right = _timeline_variant(unit, seed)
    pred = payload.get("prediction")
    if pred not in options:
        return None
    label = f"tu predicción del paso {ask + 1} («{steps[ask]}»)"
    good = pred == options[right]
    # La observación del paso predicho no viaja en la actividad (sería la
    # respuesta): llega aquí, cuando el alumno ya predijo.
    return {"correctas": [label] if good else [], "revisar": [] if good else [label],
            "item": None, "consejo": f"Lo observado: {states[ask]}. {_TIMELINE_TIP[unit]}"}


# Motores compartidos entre unidades: unidad(es) → contenido público / corrección.
_SHARED_ACTIVITY = {"audit": audit_activity, "command": command_activity,
                    "order": order_activity, "timeline": timeline_activity,
                    "mixed": mixed_activity}
_SHARED_CHECK = {"audit": audit_check, "command": command_check, "order": order_check,
                 "timeline": timeline_check, "mixed": mixed_check}
SHARED_UNITS = {"audit": sorted(AUDIT_BANKS), "command": sorted(COMMAND_BANKS),
                "order": sorted(ORDER_BANKS), "timeline": sorted(TIMELINE_BANKS)}
