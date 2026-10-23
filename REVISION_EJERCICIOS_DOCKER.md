# Revisión de ejercicios Docker — 22 de octubre de 2026

Alcance: las 12 unidades de Docker, sus microlecciones, consignas, opciones,
simulaciones, corrección y entrega independiente. No es una evaluación de eficacia
con estudiantes ni una ejecución real de Docker.

## Hallazgos y correcciones

| Unidad | Revisión y resultado |
|---|---|
| D01 Contenedor/VM | Se explicita host Linux sin VM auxiliar y se pide la opción más ligera que cumple los requisitos. Evita que «una VM también podría hacerlo» convierta la decisión en ambigua. Se conserva el banco de nueve escenarios. |
| D02 Ciclo de vida | Se explicitan estado inicial y comandos abreviados, recurso preguntado y paso observado. Las opciones distinguen existencia de ejecución. Predicción antes de observar, bloqueada después; reiniciar la borra. Siete secuencias conservadas, incluido start y run --rm. Microlección ampliada. |
| D03 CLI | Casos precisan stdout/stderr, contenedor existente, disponibilidad de shell y recurso a eliminar. Distractores plausibles en vez de flags inexistentes. |
| D04 Dockerfile | Se pide construir y conservar caché al cambiar código. CMD al final se identifica como convención de este ejercicio, no una exigencia universal de Docker. Se elimina la afirmación falsa de reconstruir una imagen real con cada movimiento. |
| D05 Contexto | COPY se acota al contexto local y sin --from. Se explicita dónde está el archivo ausente. Ante secretos ya incluidos se pide retirar la imagen y rotar secretos; .dockerignore protege builds futuros. |
| D06 Redes | Se distingue proceso servidor dentro del contenedor de JavaScript ejecutado en el navegador. Se explicitan red bridge, DNS del servicio, puertos y red dedicada para la base. |
| D07 Persistencia | Se aclara que recrear reutiliza el montaje y no elimina volumen/carpeta. Montaje → predicción → escritura → recreación. Cambiar montaje borra la predicción; observar la bloquea. La entrega del reto es evidenceSelected tras recrear, no solo predecir. Sin corrección de acierto/error durante el postest. |
| D08 Compose | Se fija postgres:16 para la ruta de datos; down sin -v. Se diferencia orden de arranque de disponibilidad inicial con healthcheck/service_healthy. Reinicio ante salida no exitosa usa on-failure. Configuración y secrets se plantean con requisitos explícitos. |
| D09 Depuración | 137 deja de equivaler automáticamente a OOM: el caso aporta OOMKilled=true. exec requiere que el contenedor siga corriendo. Se conserva el diagnóstico basado en evidencia. |
| D10 Seguridad | Digest para contenido exacto, no garantía de reproducibilidad por tag mutable. Mínima compatible con la app, root solo cuando hace falta, riesgo del socket de un daemon rootful explícito. |
| D11 Despliegue | Referencias por digest, respaldo consistente y restauración verificada. Rollback supone compatibilidad con datos. TLS en proxy se plantea como arquitectura dada, no única opción válida. CI/CD responde a trazabilidad y repetibilidad. |
| D12 Reto final | Se presenta honestamente como cuatro decisiones de unidades distintas. No se anuncia como construcción/ejecución de un stack ni como prueba experimental de transferencia. |

## Cambios comunes

### Revisión adicional de pistas

La primera revisión no completaba toda la ayuda: el reto aún usaba una pista
genérica y tomaba la unidad de la página, incluso si el planificador había elegido otra.
También se registraba el evento con el widget de origen.

- Se reescriben 48 pistas: cuatro por unidad, disponibles en práctica y reto.
  Progresión: orientar la decisión → señalar evidencia → contrastar mecanismos →
  explicar con un ejemplo distinto al ejercicio. El último nivel permite salir
  del bloqueo; no se limita a repetir «vuelve a leer».
- Las pistas del reto usan su unidad pública validada. Para widgets históricos
  exclusivos de una unidad se puede identificar esa unidad; un DecisionScenarios
  sin unidad identificable no recibe ayuda de una unidad adivinada.
- El despliegue progresivo se guarda por intento, widget, unidad y semilla del
  reto. Cambiar de variante no arrastra las pistas desplegadas de la anterior.
- La telemetría de ayuda identifica widget, unidad, misión, nivel y contexto
  correctos. Se conservan los borradores y los contadores previos.
- La guía deja de afirmar que hubo un fallo cuando el reto puede ser una
  transferencia tras un buen intento. D02 orienta al paso preguntado, no al final
  de la secuencia. D10/D11 distinguen privilegios, digest y compatibilidad.
- Los consejos automáticos de corrección se ajustan por unidad. Persistencia
  invita a localizar el archivo y el recurso eliminado; no entrega la solución
  «sin montaje se pierde» antes de que se pida más explicación.
- La fase de dominio/postest mantiene tutor y pistas desactivados.

Verificación adicional: 163 pruebas Flutter aprobadas (1 omitida), 131 backend
aprobadas (1 omitida) y 30 pruebas Docker nuevamente aprobadas tras el ajuste final
de consejos; análisis y build web correctos. Prueba de las cuatro pistas largas
en 390 px con texto al 200 %, progresión de una en una, contexto nuevo independiente,
unidad de telemetría correcta y ausencia de ayuda en la prueba.

### Ciclo y evaluación

Seguimiento de D02: elegir la predicción y escribir la justificación no ejecuta
la secuencia. La tarjeta «Bien resuelto / Ahora explica» inducía a creer que la
práctica había terminado aunque siguiera en «Estado inicial».
Ahora se distingue «Predicción comprobada», se muestra el número de comandos
ejecutados y se explica qué falta junto al botón de evaluación. La entrega se
habilita al completar la simulación y justificar, conservando el texto si se
escribió antes. Reiniciar la simulación invalida la evidencia local y su corrección
anterior, sin borrar la explicación. Una prueba reproduce ese orden exacto.

- El tutor deja de recibir una identidad de machine learning para todos los labs.
  Recibe dominio y actividad pública del servidor; al planificar recibe la unidad
  elegida para el reto, aunque sea distinta de la práctica anterior.
- Se reintenta una vez si el texto Docker menciona conceptos ajenos de entrenamiento;
  si persiste se devuelve LLMUnavailable/503. Esta comprobación cubre la contaminación
  detectada; no garantiza automáticamente la calidad de cualquier texto futuro.
- La consigna curricular del widget se separa de la pregunta libre del tutor, también
  para intervenciones históricas sin el campo nuevo `instruction`.
- Ayudas de práctica específicas por unidad, sin analogías de VM en todos los ejercicios.
- Si no llega el escenario público del servidor, se ofrece reintentar conservando el
  borrador; no se presenta un ejemplo local distinto como ejercicio evaluable.
- Cambio aditivo del contrato: POST /sessions/{id}/posttest acepta `extra` con decisiones
  Docker. La unidad se deriva de la práctica y la semilla de la variante del servidor.
  Se validan opciones, tamaño de respuesta y líneas; no se aceptan scores ni verdad
  del cliente. La evidencia se guarda en el JSON existente y no se muestra feedback
  durante la prueba. No hay cambio de modelos, migración ni borrado de históricos.
- Borradores de decisiones de práctica/postest separados por unidad y fase.

## Evidencia de validación

Resultado final: `uv run pytest` — 131 aprobadas, 1 omitida (proveedor vivo);
`flutter test` — 163 aprobadas, 1 omitida; `flutter analyze --no-pub` sin incidencias;
`flutter build web --no-pub --no-wasm-dry-run` correcto. Detector Impeccable sin hallazgos.
Pytest usa un directorio temporal del workspace porque el temporal global del equipo
rechaza acceso; no se cambia la configuración del usuario ni se borra ese directorio global.

- Backend: pruebas por cada una de las 12 unidades para conservar y verificar evidencia
  de postest; rechazar otra unidad/respuesta incompleta y no aceptar semilla/score
  del cliente. Fixtures de prerrequisitos, SQLite en memoria, Gemini/Jev simulados.
- Banco: consignas presentes, decisiones coherentes con verificador en semillas
  1, 4, 99 y 412 para las 12 unidades; lifecycle incluye start y --rm.
- Tutor: reproducción de la pregunta sobre pesos, corrección/rechazo y contexto de
  la actividad elegida por el planificador.
- Flutter: predicción D02 bloqueada tras observar; reinicio; recuperación de error
  al cargar escenario; catálogo y ciclo de sesión existentes.
- Fixture público `frontend/test/fixtures/docker_activities.json`: las 12 actividades
  de semilla 1, sin índices correctos. Prueba de render en 390 px con texto al 200 %.
  Regeneración: `uv run python` importando `app.labs_docker.activity` desde backend.
- Capturas locales de la actividad D02 en `.impeccable/docker-audit-d02-*.png`.
- Los resultados de suites y build se registran en `.impeccable/docker-audit-*.log`.
  Un test de proveedor vivo se omite deliberadamente; no se gastan APIs reales.

La revisión no incluye un piloto con alumnos ni garantiza que cada combinación
de lenguaje natural futura del proveedor sea pedagógicamente correcta. D03/D05/D06/
D08–D12 siguen siendo ejercicios de decisiones, no terminal, editor Compose o
entorno de despliegue reales. Las sesiones y evaluaciones históricas no se reescriben.

## Fuentes técnicas

- [Ciclo y comandos de contenedores](https://docs.docker.com/reference/cli/docker/container/).
- [Contexto y .dockerignore](https://docs.docker.com/build/concepts/context/),
  [COPY y Dockerfile](https://docs.docker.com/reference/dockerfile/).
- [Disponibilidad inicial en Compose](https://docs.docker.com/compose/how-tos/startup-order/).
- [Secrets de Compose](https://docs.docker.com/compose/how-tos/use-secrets/).
- [Recursos y OOM](https://docs.docker.com/engine/containers/resource_constraints/).
- [Referencias a imágenes por digest](https://docs.docker.com/build/policies/validate-images/).
