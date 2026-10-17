# PLAN.md — CognitiveFlow AI · Arquitectura educativa, GenUI y UX de laboratorios

> **Versión:** 2026-10-16 · Documento de ejecución para OpenCode. **Fuente de verdad nueva** para aprendizaje, UI/UX, adaptatividad y rol del instructor. Mantener `DESIGN.md` como fuente de tokens visuales y el plan con avances como historial de progreso. **NO reinicializar el proyecto, NO borrar datos SQLite, NO dar por comprobado lo que solo aparece en capturas.**

## 0. Orden ejecutiva para el agente

**Objetivo de producto:** plataforma de enseñanza activa para cuatro estudiantes de Data Science/ML y un instructor. Sustituir la secuencia actual «tabla o gráfico → escribir texto → chips con scores → siguiente actividad imprecisa» por un entorno en el que **se enseña el concepto**, el alumno **predice y manipula un experimento**, **justifica con evidencia**, recibe una **intervención concreta** de Gemini basada en evaluación estructurada Jev y luego demuestra aprendizaje en **una situación nueva sin ayuda**. El instructor **solo observa resultados**.

**Stack fijado:** Flutter Web / Material 3 / GenUI con A2UI acorde con la versión instalada; Python 3.12 + `uv`, FastAPI, SQLAlchemy 2, SQLite + Alembic cuando proceda, Gemini API como tutor generativo, Jev TypeSafe como juez estructurado. Preferir orquestación determinista antes de añadir LangGraph; LangGraph solo si mejora trazabilidad y complejidad comprobada. Desarrollo Windows + PowerShell; no exigir Docker/WSL. No usar `nano`; usar `vim` si hace falta editor en terminal.

**Jerarquía de prioridades:** aprendizaje funcional y eventos GenUI reales > próxima actividad específica > postest independiente > calidad de feedback > UX y accesibilidad > dashboard instructor > nuevas unidades. La expansión de Docker NO debe bloquear un recorrido E2E del laboratorio actual.

**Restricción fundamental:** los cuatro estudiantes constituyen un piloto exploratorio; no afirmar eficacia ni generalización estadística. No presentar puntuaciones Jev como medición neuropsicológica objetiva ni un único score como «dominio».

## 1. Hallazgos actuales y alcance de evidencia

En las capturas más recientes, Data Detective muestra selección de filas, un área extensa de scroll y panel derecho con chips de puntuación; Model Monitoring contiene distribuciones y una segunda gráfica con ejes densos y poco legibles; ML Experiment presenta curvas sintéticas, sliders y una justificación, pero la continuación visible consiste sobre todo en texto. La invitación temprana a «Ir al postest» rompe la secuencia formativa. La interfaz deja espacios desaprovechados y separa visualmente la evidencia, la respuesta y la intervención. La pantalla llamada «siguiente actividad» no explica en qué cambia el reto, ni garantiza widget interactivo. Todo esto es **observación de capturas**, no prueba de ausencia de código.

Hay progreso previo registrado en el plan: backend y SQLite iniciales, 4 estudiantes + instructor demo, academia y navegación, un laboratorio ML con simulación, intentos y mock evaluator; otros archivos e imágenes parecen mostrar Data Detective, Monitoring, GenUI y postest más adelantados. **No homogeneizar estas evidencias ni reiniciar componentes:** ejecutar auditoría de los fuentes actuales, tests y rutas; emitir `docs/current-state-audit.md` con `implementado y verificado` / `existe pero incompleto` / `pendiente` / `no verificable`.

### 1.1 Fuente de verdad y jerarquía

1. Código real y tests que pasan (estado actual, obligatorio auditar).
2. Este `PLAN.md` (objetivos y comportamiento deseado).
3. `DESIGN.md` (colores/tokens y reglas visuales).
4. `COGNITIVEFLOW_PLAN(2).md` (historial de avance; conservar marcas `[x]` sin copiarlas como pruebas actuales).
5. `PLAN_PEDAGOGICO_GENUI.md` (contenido curricular previo; ya incorporado aquí).

Ante discrepancias: documentar, adaptar con migraciones y tests, evitar refactors ajenos al sprint. Nunca sustituir diseño probado por placeholders.

## 2. Fundamentos pedagógicos y reglas basadas en evidencia

| Fundamento | Aplicación en CognitiveFlow | Riesgo / límite |
|---|---|---|
| Aprendizaje activo (Freeman et al., 2014) | Tareas donde el alumno decide, manipula y explica | Interactividad no garantiza comprensión |
| Descubrimiento guiado (Alfieri et al., 2011) | Ejemplo + apoyo graduado antes de autonomía | Evitar «averígualo solo» |
| Expertise reversal (Kalyuga et al., 2003) | Menos andamiaje para quien demuestra competencia | Nivel dinámico por unidad, no etiqueta permanente |
| Self-explanation (Bisra et al., 2018) | «¿Qué dato apoya esa conclusión?» | No repetir «justifica» sin contexto |
| Feedback (Hattie & Timperley, 2007) | Objetivo, evidencia actual, próximo paso ejecutable | Un score 2/4 no es feedback pedagógico |
| Retrieval practice (Roediger & Karpicke, 2006) | Recordar sin pistas en nuevas condiciones | No repetir idéntico problema memorizado |
| Distributed practice (Dunlosky et al., 2013) | Repaso diferido configurable | 1/3/7 días es punto de partida, no dosis óptima universal |
| Guardrails de tutores IA (Bastani et al., 2025) | Medir aprendizaje sin IA, no solo rendimiento durante chat | El score durante práctica puede inflarse por asistencia |

Fuentes al final. No atribuir a estudios resultados no estudiados (en particular, NO afirmar que Flutter GenUI o Jev producen mejores notas por sí mismos).

### 2.1 Política de enseñanza adaptable, NO ciclo rígido

- **Diagnóstico breve por objetivo:** dos o tres actividades equivalentes independientes; clasificar `needs_foundation | guided_practice | autonomous_challenge` como ruta provisional con evidencias; guardar versión y confianza metodológica, no inferir rasgos de inteligencia.
- **Novato:** concepto breve, demostración worked example, predicción de bajo riesgo, experimento guiado, feedback formativo.
- **Intermedio:** pregunta de contraste, predicción, experimento, autoexplicación, nuevo caso.
- **Avanzado:** problema auténtico, contraejemplo, tradeoffs, transferencia, menos ayuda y mayor autonomía.
- **Política de ayuda decreciente:** intento autónomo razonable → pregunta o pista contextual → evidencia señalada → ejemplo análogo resuelto → explicación directa si persiste bloqueo o el estudiante la solicita; después **nuevo ítem** para comprobar aprendizaje. No castigar pedir ayuda. Guardar `assistance_level` para interpretar resultados.
- **No forzar predicción/justificación textual en cada clic:** elegir modo de interacción según objetivo: clasificar, explicar, depurar, construir, comparar o interpretar.
- **Postest independiente:** bloquear en backend uso de Gemini, pistas, feedback de solución y reutilización literal de casos; ítems equivalentes nuevos y criterios versionados; mostrar evaluación al finalizar, nunca antes.
- **Repaso espaciado:** programar tareas sin pistas tras 1, 3 y 7 días como política configurable; si hay errores, generar repaso focalizado; dejar registrar ausencia, reintentos y retención. Sin automatización de correos en MVP.
- **Transferencia:** exigir aplicar conocimiento a un escenario nuevo, no solo reproducir respuesta. Ej.: volúmenes Docker → persistencia SQLite en un deploy.
- **Motivación:** progreso real por completitud; dominio separado por evidencia posterior; no animaciones de recompensa si la respuesta fue incorrecta.

### 2.2 Modos de actividad

`explain`, `worked_example`, `predict`, `manipulate`, `classify`, `construct`, `debug`, `compare`, `justify`, `reflect`, `independent_assessment`, `spaced_retrieval`. No todos se ejecutan siempre. El planificador elige el mínimo útil por objetivo y dificultad.

## 3. Currículo completo (9 módulos)

Cada unidad posee `learning_objectives` observables, prerrequisitos, conceptos, errores comunes, microlecciones originales, ejemplo resuelto, 1–3 tipos de tareas posibles, rúbrica, prueba sin ayuda y repaso. Los cursos externos son referencias vinculadas, NO se copian íntegros. Especificar estados `planned | content_ready | interactive_ready | validated`; no marcar una unidad «lista» solo porque está sembrada en SQLite.

## 3.1 Unidades y laboratorios por módulo


Todos los módulos necesitan `units`, `objectives`, `prerequisites`, `concept_explanations`, `worked_examples`, `misconceptions`, `lab_templates`, `rubrics`, `independent_assessments` y `resources`. Crear primero los seeds completos de contenido; implementar con GenUI los laboratorios prioritarios, no prometer 100% del contenido interactivo en el MVP.

### M01. Terminal Linux y Git

**Recursos:** https://ubuntu.com/tutorials/command-line-for-beginners#1-overview y https://learn.microsoft.com/es-es/training/modules/intro-to-git/

| Unidad | Enseñar explícitamente | Actividad GenUI y evidencia |
|---|---|---|
| M01-U01 Terminal y filesystem | shell, ruta absoluta/relativa, `pwd`, `ls`, `cd`, `mkdir`, `touch` | `VirtualTerminal`: navegar un árbol; justificar rutas |
| M01-U02 Archivos y procesos | `cat`, redirecciones, `grep`, pipes, permisos básicos, procesos, errores comunes | `CommandSequenceBuilder`: ordenar comandos y explicar efectos |
| M01-U03 Fundamentos Git | repositorio, commit, working tree, staging, `git status`, `add`, `commit`, `log` | `GitHistoryExplorer`: simular cambios e inferir estado |
| M01-U04 Branches y conflictos | branch, merge, conflictos, reset/restore y peligros | `GitConflictSimulator`: elegir resolución y justificar preservación de cambios |

### M02. Pandas, limpieza, visualización y SQL

**Recursos:** Kaggle Pandas, Data Visualization, Data Cleaning, Intro to SQL y Advanced SQL.

| Unidad | Enseñar explícitamente | Actividad GenUI y evidencia |
|---|---|---|
| M02-U01 Tablas y Pandas | DataFrames, series, tipos, index, filtros, agregaciones | `DataTableExplorer`: predecir operaciones y comparar resultados |
| M02-U02 Calidad de datos | valores nulos, duplicados, rangos imposibles, outliers, unidades | `DataDetective`: clasificar problema y plan de reparación |
| M02-U03 Visualización | distribuciones, escalas, codificación, gráficos engañosos | `ChartCritique`: escoger visualización y detectar distorsiones |
| M02-U04 SQL básico | `SELECT`, `WHERE`, `GROUP BY`, joins | `SqlQueryWorkbench`: editar consulta segura sobre dataset de práctica |
| M02-U05 SQL avanzado | CTE, window functions, subqueries, query plans conceptual | `QueryComparison`: contrastar consultas equivalentes y tradeoffs |
| M02-U06 Leakage / validación de datos | filtración futura, joins indebidos, estrategias de separación | `LeakageDetective`: explicar columnas problemáticas |

### M03. Machine Learning y explicabilidad

**Recursos:** Kaggle Intro ML, Intermediate ML, Feature Engineering, ML Explainability.

| Unidad | Enseñar explícitamente | Actividad GenUI y evidencia |
|---|---|---|
| M03-U01 Formulación | target, features, datos, baseline y particiones | `ProblemFramingCanvas`: definir hipótesis y riesgos |
| M03-U02 Entrenamiento/validación | overfitting, underfitting, generalización, cross-validation | `LearningCurveSimulator`: predecir→modificar→comparar |
| M03-U03 Métricas | clasificación, regresión, matriz de confusión, precision/recall | `MetricTradeoffLab`: elegir umbral y justificar costo de errores |
| M03-U04 Datos faltantes / categoricas | imputación, encoding, pipeline, leakage | `PreprocessingPipelineBuilder`: elegir pasos y orden |
| M03-U05 Features | ingeniería, selección y regularización | `FeatureImpactExperiment`: predecir impacto |
| M03-U06 Explainability | feature importance, SHAP, límites y correlaciones | `AttributionCritique`: interpretar sin confundir atribución y causalidad |

### M04. Deep Learning

**Recursos:** Kaggle Intro DL y videos de Deep Learning, CNN y RNN entregados por el instructor.

| Unidad | Enseñar explícitamente | Actividad GenUI y evidencia |
|---|---|---|
| M04-U01 Red neuronal | neuronas, capas, pesos, activaciones | `NeuralNetworkPlayground` |
| M04-U02 Optimización | loss, gradiente, learning rate, batch, épocas | `GradientDescentSimulator` |
| M04-U03 Generalización | regularización, dropout, early stopping | `TrainingStrategyExperiment` |
| M04-U04 CNN | kernels, convolución, pooling, receptive field | `ConvolutionExplorer` |
| M04-U05 RNN | secuencias, hidden state, vanishing gradient | `SequenceStateExplorer` |

### M05. Time Series y Computer Vision

**Recursos:** Kaggle Time Series y Computer Vision.

| Unidad | Enseñar explícitamente | Actividad GenUI y evidencia |
|---|---|---|
| M05-U01 Series temporales | tendencia, estacionalidad, lags, forecasting | `ForecastWorkbench` |
| M05-U02 Validación temporal | split temporal, leakage, rolling window | `TimeSplitBuilder` |
| M05-U03 Visión artificial | imagen, pixels, convoluciones, augmentación | `ImageFilterLab` |
| M05-U04 Evaluación CV | precision, recall, matriz de confusión, falsos rechazos | `VisionErrorExplorer` |

### M06. MLOps y observabilidad

**Recursos:** Grafana Fundamentals, Airflow 101, Evidently AI, DVC Data Scientist Path.

| Unidad | Enseñar explícitamente | Actividad GenUI y evidencia |
|---|---|---|
| M06-U01 Pipelines | DAG, dependencias, schedules y errores | `PipelineDAGBuilder` |
| M06-U02 Reproducibilidad | versiones de datos, DVC, experiment tracking | `ReproducibilityPuzzle` |
| M06-U03 Observabilidad | métricas, dashboard, alertas, umbrales | `DashboardDiagnosis` |
| M06-U04 Data drift | referencia/actual, p-value, PSI, límites estadísticos | `DriftDistributionExplorer` |
| M06-U05 Concept/performance drift | cambio de relación X→Y, delayed labels, evaluación | `MonitoringDecisionLab` |

### M07. Agentes de IA y contexto

**Recursos:** https://huggingface.co/context-course y https://academy.langchain.com/courses/intro-to-langgraph

| Unidad | Enseñar explícitamente | Actividad GenUI y evidencia |
|---|---|---|
| M07-U01 Context engineering | tokens, truncamiento, memoria, retrieval | `ContextWindowPuzzle` |
| M07-U02 RAG | chunking, búsqueda, citación, grounding | `EvidenceRetrievalLab` |
| M07-U03 Workflows y agentes | tool use, loops, criterios de parada | `AgentGraphBuilder` |
| M07-U04 LangGraph | nodos, edges, state, routing y errores | `GraphExecutionSimulator` |
| M07-U05 Seguridad y evaluación | prompt injection, permissions, judge y guardrails | `AgentSafetyScenario` |

### M08. Docker y despliegue — NUEVO (enseñanza completa)

**Objetivo final:** ser capaz de explicar, contenerizar y desplegar una app sencilla FastAPI + interfaz web, diagnosticar fallos y distinguir lo que resuelve Docker de lo que no resuelve. El contenido y las prácticas siguen conceptos de la documentación de Docker (https://docs.docker.com/get-started/ y https://docs.docker.com/compose/). El MVP usa **simuladores**, sin exigir que alumnos ejecuten comandos en el servidor de CognitiveFlow. Las tareas avanzadas pueden realizarse en un entorno local supervisado.

| Unidad | Conceptos que debe explicar la plataforma | Actividad GenUI (no solo texto) | Evidencia de dominio |
|---|---|---|---|
| D01 ¿Qué es Docker? | contenedores vs VMs, portabilidad, aislamiento, runtime, por qué se usa | `ContainerVsVmExplorer`: clasificar escenarios y visualizar capas | cuándo usar contenedor y limitaciones |
| D02 Imágenes y contenedores | imagen inmutable, capas, registry, tag/digest, `pull`, `run`, `ps`, `stop`, `rm` | `ImageContainerLifecycle`: arrastrar pasos y simular estados | distinguir build/run/stop/imagen |
| D03 Docker CLI | `images`, `logs`, `exec`, `inspect`, `--help`, `-d`, `--name`, puertos | `DockerCommandBuilder`: ensamblar comandos con opciones tipadas | justificar comando esperado y comprobar salida simulada |
| D04 Dockerfile | `FROM`, `WORKDIR`, `COPY`, `RUN`, `CMD`, `ENTRYPOINT`, `EXPOSE`, capas, cache, `.dockerignore` | `DockerfileWorkbench`: ordenar instrucciones, editar y observar build graph | crear Dockerfile reproducible y explicar cada instrucción |
| D05 Contexto y directorios | build context, rutas locales y dentro del contenedor, directorio de trabajo, bind mount, filesystem efímero | `FileSystemMapper`: dos árboles host/container enlazados | diagnosticar `COPY` fallido y pérdida de archivos |
| D06 Puertos y redes | host vs container, `-p`, localhost, DNS de servicios, redes de Compose, firewall | `PortNetworkSimulator`: conectar app/API/DB e identificar URL correcta | corregir un error de conexión sin adivinar |
| D07 Persistencia | volumes, bind mounts, cuándo guardarlos, diferencia con capas y backup | `PersistenceExperiment`: reiniciar contenedor y predecir qué permanece | persistir SQLite sin guardar datos en capa efímera |
| D08 Docker Compose | `compose.yaml`, `services`, `build`, `image`, `ports`, `volumes`, `environment`, `depends_on`, `healthcheck`, redes | `ComposeArchitectureBuilder`: configurar frontend + API + storage | definir servicios y conectividad (no equiparar depends_on con readiness) |
| D09 Build y debugging | `docker build`, multi-stage, caché, logs, exit codes, inspect, health | `BrokenBuildDebugger`: errores deliberados; seleccionar evidencia y corrección | diagnosticar fallos con trazas y árbol de build |
| D10 Seguridad y optimización | secretos, root/nonroot, imágenes mínimas, tags fijados, scanning, `.dockerignore`, recursos | `ContainerThreatModel`: priorizar riesgos y explicar mitigaciones | no poner claves en imagen ni repositorio |
| D11 Despliegue | local→registry→host, HTTPS reverse proxy, env vars, dominio, persistencia, backups, rollback, CI/CD | `DeploymentTopologyLab`: construir mapa y simular caída | describir despliegue reproducible y recuperación |
| D12 Proyecto Docker completo | FastAPI + frontend + SQLite persistente (demo), README y pruebas | `DockerCapstone`: encadenar todos los widgets y decisiones | dockerizar, explicar y solucionar escenarios con archivos originales |

**Lecciones Docker con contenido explícito (ejemplo D04):**
1. Concepto: un `Dockerfile` declara cómo construir una imagen; no es un contenedor ejecutándose.
2. Muestra un árbol de archivos (`app.py`, `requirements.txt`, `Dockerfile`, `.dockerignore`). Explica build context y `WORKDIR`.
3. Ejemplo guiado con sintaxis realista y versión de Python fijada; el estudiante predice qué copia `COPY . .` y qué archivos excluir.
4. Experimento: reordenar `COPY requirements` y `RUN pip install`; observar qué invalida la caché (simulación etiquetada, no afirmar benchmark real).
5. Pregunta causal: «¿por qué cambió el tiempo de build al modificar solo `app.py`?».
6. Jev evalúa afirmaciones delimitadas con evidencia de la simulación.
7. Gemini elige contraprueba: cambiar estructura/directorio o construir un `Dockerfile` mínimo con instrucciones limitadas.
8. Evaluación independiente: otro proyecto con rutas distintas, nuevo error y sin pistas.

**Ejemplo Dockerfile ilustrativo para el contenido (no usar automáticamente en producción):**

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY ./app ./app
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Aclaraciones esenciales:** `EXPOSE` documenta el puerto del contenedor, no lo publica en el host; `depends_on` básico no implica salud del servicio; `localhost` dentro de un contenedor no es otro contenedor; los cambios en filesystem del contenedor pueden perderse al recrearlo; la base SQLite requiere volumen persistente y precauciones de concurrencia.

### M09. Proyecto integrador (renumerado desde M08)

**Proyecto sugerido:** Industrial AI Monitoring Platform con datos autorizados, abiertos o sintéticos. Ingesta Pandas/SQL → limpieza → modelo ML/DL adecuado → DVC/Airflow → Evidently/Grafana → Docker y Compose → API y frontend → agente opcional LangGraph. Evaluación: selección de arquitectura, reproducibilidad, errores, explicabilidad, monitoreo, seguridad y defensa de hipótesis. Los 4 estudiantes se distribuyen trabajo pero cada uno debe comprender el conjunto.


## 4. El nuevo motor de enseñanza

### 4.1 Jerarquía y contrato de contenido

```text
LearningPath → Module → Unit → LearningObjective → LearningActivitySpec
                                           ↘ RubricVersion
                                             MisconceptionCatalog
LearningSession → ActivityInstances → Interactions → Attempts → Evaluations
                → Intervention → NextActivity → IndependentCheck → RecallSchedule
```

Para cada objetivo: `objective_id`, `prerequisite_objective_ids`, `level`, `concept_summary`, `worked_example_steps`, `misconceptions[]`, `allowed_widget_types[]`, `rubric_id`, `assessment_blueprint_id`, `retrieval_blueprint_id`. Los materiales pueden quedar en archivos versionados YAML/JSON y sembrarse a SQLite sin destruir avance.

### 4.2 Planificador de siguiente actividad

Entradas: objetivo, nivel provisional, evidencia previa, evento recién capturado, estado de lección, señales Jev y resultados deterministas, máximo de ayudas, accesibilidad y tiempo razonable. Salida: **una** actividad validada con `title`, `why_this_next`, `learning_goal`, `type`, `widget_type`, `widget_config`, `expected_evidence`, `assessment_mode`, `hint_policy`, `estimated_minutes` (estimación rotulada como tal), `phase`, `schema_version`, `source_intervention_id`.

Reglas mínimas:

1. Si falta prerequisito → worked example + práctica pequeña.
2. Si concepto incorrecto → contraejemplo manipulable, no simple repetición textual.
3. Si respuesta correcta sin evidencia → pedir ubicar evidencia en chart/tabla, no otra redacción abierta.
4. Si falta interpretación causal → experimento con variable controlada y predicción.
5. Si domina durante práctica → tarea de transferencia **sin pistas**.
6. Si Jev incierto o falla → no inventar resultado; verificar programáticamente, reintentar con límites o marcar revisión metodológica; el instructor sigue solo lectura.
7. Si alumno se bloquea → ejemplo análogo o explicación directa; comprobar con una tarea nueva.
8. Si termina postest → reflexión no evaluativa + programación de repaso espaciado.

Antes de avanzar: verificar que exista un widget renderizable y payload válido, que la actividad no sea idéntica a la anterior salvo repaso explícito y que el estado de sesión permita esa transición. Mostrar tarjeta concreta con título, objetivo y qué hará, nunca solo «Siguiente actividad».

### 4.3 Estados y transiciones

`not_started → diagnosing → lesson_or_challenge → responding → evaluating → feedback → adaptive_practice (0..N) → ready_for_independent_check → independent_check → completed → scheduled_review`. Incluir `paused`, `evaluation_pending`, `error_retryable`. El backend decide avance y autorización, el frontend solo muestra el estado autorizado. Persistir cada transición con idempotencia, hora UTC y trazabilidad.

### 4.4 Secuencia típica — ejemplo Docker D07

- **Concepto:** archivos del filesystem del contenedor vs volumen persistente; diagrama de capas.
- **Worked example:** un servicio escribe un archivo en `/app/data/` y se elimina/recrea el contenedor.
- **Predicción:** seleccionar qué archivos sobreviven; elegir causa.
- **GenUI:** `PersistenceExperiment` permite alternar `no mount | named volume | bind mount`, escribir un archivo simulado, recrear y observar el filesystem; no ejecutar Docker real en backend.
- **Evidencia:** registrar predicción previa, operaciones, observación y explicación final.
- **Jev:** clasificar menciones de persistencia/volúmenes vs generalizaciones erróneas; verificaciones deterministas confirman estado simulado.
- **Gemini:** plantea *por qué* el dato sobrevivió/no sobrevivió; selecciona una nueva actividad sobre SQLite persistente si hay confusión.
- **Transferencia:** app web con Compose y base SQLite recreada, nueva topología sin ayuda.
- **Repaso:** tarea posterior que pide predecir comportamiento de un volumen diferente.

## 5. GenUI / A2UI: comportamiento real, no tarjetas de texto

**Advertencia:** `ActivitySpec` es contrato INTERNO del backend, NO el protocolo oficial A2UI. Crear `A2UIAdapter` para la versión de `genui` instalada; consultar docs oficiales y fijar dependencias. Nunca dejar que Gemini genere código Dart, JavaScript, URLs arbitrarias, comandos ejecutables ni SQL sin control.

### 5.1 Interacciones y ciclo de eventos

```mermaid
sequenceDiagram
 participant S as Estudiante
 participant W as Flutter GenUI Widget
 participant B as FastAPI
 participant V as Verificador determinista
 participant J as Jev
 participant G as Gemini
 S->>W: manipula o envía explicación
 W->>B: event + activity_id + client_event_id
 B->>B: valida rol, estado, payload; persiste evento
 B->>V: verifica estados y hechos observables
 B->>J: evalúa argumentación con rúbrica y contexto
 J-->>B: criterios/decisiones estructurados
 B->>G: pide estrategia + feedback fundamentado
 G-->>B: propuesta estructurada de actividad y texto
 B->>B: valida contra catálogo, objetivo y políticas
 B-->>W: nueva ActivitySpec convertida a A2UI
 W-->>S: nuevo experimento interactivo
```

### 5.2 Catálogo y evidencia requerida

| Widget | Interacciones REALES | Resultado observable |
|---|---|---|
| `LessonConceptCard` | explorar ejemplo paso a paso, comprobar predicción | paso visitado, respuesta al microcheck |
| `WorkedExampleStepper` | revelar pasos y justificar decisiones | errores por paso, pistas usadas |
| `PredictionCanvas` | elegir/arrastrar hipótesis antes de revelar experimento | predicción con timestamp |
| `DataTableExplorer` | filtrar, seleccionar celda, clasificar tipo de error | anomalías por `row_id + column + error_type` |
| `DataCleaningWorkbench` | elegir y aplicar transformación simulada | antes/después + cambios controlados |
| `LearningCurveSimulator` | mover sliders, comparar dos ejecuciones, anotar época | predicción vs curvas y ensayo de control |
| `DriftDistributionExplorer` | elegir feature, periodo, umbral/zoom y evidencia | hallazgos y límites del diagnóstico |
| `ChartCritique` | detectar eje engañoso, seleccionar gráfica apropiada | explicación y alternativa |
| `SqlQueryWorkbench` | editor seguro en dataset aislado y readonly | SQL validado, salida/errores visibles |
| `EvidenceComparison` | marcar evidencia y unirla a una conclusión | pares afirmación-evidencia |
| `DockerfileWorkbench` | reordenar instrucciones, cambiar contexto y reconstruir | cache layers y fallos simulados |
| `FileSystemMapper` | explorar dos árboles, host vs contenedor | rutas y predicciones acertadas |
| `ImageContainerLifecycle` | ensamblar pasos build/pull/run/stop/rm | transición de estado válida |
| `PortNetworkSimulator` | conexiones, puertos, URL y DNS entre servicios | fallo detectado y corrección aplicada |
| `PersistenceExperiment` | crear archivo/recrear contenedor/montar volumen | persistencia observable |
| `ComposeArchitectureBuilder` | unir servicios, variables, networks, volumes, health | topología validada y explicación |
| `BrokenBuildDebugger` | inspeccionar logs y proponer arreglo | diagnóstico basado en evidencia |
| `ConceptMapBuilder` | crear nodos/aristas, explicar dependencia | mapa editable y relaciones |
| `RubricFeedbackCard` | expandir criterio y vínculo a dato | feedback legible, no nota aislada |
| `ReflectionSummary` | identificar qué cambió de opinión | metacognición sin falsa celebración |

**No implementar todo a la vez.** Para MVP garantizar interactividad bidireccional en `DataTableExplorer`, `LearningCurveSimulator`, `EvidenceComparison`, `PersistenceExperiment`, y una segunda actividad generada a partir de evaluación real.

### 5.3 Contrato de ejemplo (interno)

```json
{
  "schema_version": 1,
  "activity_id": "uuid",
  "objective_id": "M03-U02-generalization",
  "title": "Compara dos entrenamientos",
  "why_this_next": "Identificaste el patrón, pero aún no citaste las curvas",
  "phase": "guided_practice",
  "widget_type": "LearningCurveSimulator",
  "widget_config": {
    "dataset_id": "synthetic_overfit_02",
    "sliders": [{"id":"complexity","min":1,"max":10,"step":1,"initial":5}],
    "allow_compare_runs": true,
    "require_prediction_before_reveal": true
  },
  "expected_evidence": ["prediction", "selected_epoch", "claim_evidence_link"],
  "hint_policy": {"max": 3},
  "assessment_mode": "formative"
}
```

Evento: `activity_id`, `session_id`, `event_type`, `client_event_id`, `payload`, `schema_version`; validar ownership, fase, límites, tipos y retries. Deduplicar `client_event_id`, conservar estado al recargar, reanudar intento; pruebas de permisos cruzados. La UI se deriva del estado del backend, no confía en `score`, `unlock_posttest` ni rutas suministradas por el cliente.

## 6. Especificación UI/UX — arquitectura de información

### 6.1 Navegación estudiante

`Academia` (ruta/cursos/unidades y objetivos) · `Laboratorio` (actividad actual) · `Mi aprendizaje` (dominio, progreso, repasos) · `Proyecto integrador` (hitos y defensa). `Tutor` es un panel contextual disponible durante práctica y **deshabilitado completamente** en pruebas independientes. No usar «Explorar / Evaluar / Intervenir / Postest» como tabs visibles del estudiante: son estados internos del orquestador. El alumno debe ver «Aprende el concepto», «Prueba tu hipótesis», «Explica lo que observaste», «Aplica sin ayuda» según tarea.

### 6.2 Workspace escritorio (>= 1100 px, adaptar breakpoint según pruebas)

```text
┌───────────────────────────────────────────────────────────────────────┐
│ Ruta > Módulo > Unidad                    Objetivo y avance verdadero  │
├───────────────────────────────────────────┬───────────────────────────┤
│ ZONA DE APRENDIZAJE (~65–70%)             │ TUTOR CONTEXTUAL (~30–35%)│
│                                           │                           │
│ Título + «¿por qué hacemos esto?»          │ Tu hipótesis anterior     │
│ Microlección / ejemplo colapsable          │ Pista graduada            │
│ ACTIVIDAD INTERACTIVA GENUI                │ Evidencia a considerar   │
│ (tabla, curva, sandbox Docker)             │ Respuesta / conversación │
│ Predicción / elección / justificación      │                           │
│ Botón principal: «Probar mi hipótesis»     │ *Score solo bajo detalles*│
│ Próximo reto con título y objetivos        │                           │
└───────────────────────────────────────────┴───────────────────────────┘
```

**Importante:** una sola acción principal por estado. No dejar expuesto «Ir al postest» al inicio. Tutor no roba foco de la superficie experimental; el estudiante debe poder comparar evidencias con la justificación sin scroll entre ambos. El sidebar no debe duplicar título ni ocupar demasiado ancho. Modo concentración opcional oculta navegación secundaria, no contexto esencial.

### 6.3 Móvil (< 700 px, validar en dispositivos)

Una columna: encabezado compacto → actividad → respuesta → tutor como hoja inferior controlada → siguiente actividad. Evitar tablas anchas sin pista visual y sin scroll claramente indicado; permitir selección de celda/filas por tarjeta cuando corresponda. No mostrar dos barras de navegación redundantes. Targets táctiles, labels y acceso por teclado.

### 6.4 Componentes y estados

- **TaskHeader:** «D07 Persistencia · ¿Por qué desapareció mi archivo?» + objetivo en una frase + progreso de la unidad real + tiempo estimado opcional.
- **ConceptPrimer:** explicación de 80–160 palabras, diagrama relevante y un ejemplo, colapsable para avanzados; botones «Ver ejemplo» o «Comenzar experimento» según ruta.
- **TaskSurface:** un widget GenUI principal, un contexto visible, acciones ligadas a objetivos, nunca una lista de tarjetas genéricas.
- **EvidenceDock:** fijar/consultar datos seleccionados (row/column, gráfica, log, estado Docker), y arrastrarlos hacia una conclusión.
- **HypothesisComposer:** elegir predicción + argumentar «porque…» con evidencias marcadas, sin obligar párrafos largos para tareas simples.
- **TutorPanel:** pregunta concreta, explicación opcional, «Pedir pista», indicador de si es tutoría o evaluación; sin avatar caricaturesco obligatorio.
- **FeedbackPanel:** «Lo que observaste» (hecho), «Lo que falta conectar» (brecha), «Prueba ahora» (siguiente actividad real). Scores numéricos secundarios y accesibles solo expandiendo rúbrica.
- **NextActivityPreview:** título accionable, habilidad, widget, por qué sigue, botón específico (`Comparar distribuciones`, `Reconstruir contenedor`), estado de carga/error.
- **IndependentCheckShell:** pantalla limpia sin tutor y sin retroalimentación adelantada; instrucciones claras, temporizador solo si justificado pedagógicamente.
- **SessionEnd:** síntesis honesta, lo que demostró, lo pendiente y cuándo repasar; no elogiar una respuesta sin evidencia.

**Visual:** seguir `DESIGN.md` — azul `#2457C5` para CTA/navegación; teal `#0F766E` para experimentos; ámbar `#A65B00` para preguntas/reflexión. Neutros dominantes. WCAG 2.2 AA, foco, estados no codificados solo por color, tamaños responsivos. Gráficas con ejes legibles, unidades, leyenda y tabla accesible; evitar 100 ticks ilegibles. No usar el color ámbar automáticamente para «error».

### 6.5 Estados de interfaz (todos obligatorios)

`initial`, `loading`, `ready`, `dirty`, `submitting`, `evaluating`, `feedback_ready`, `new_activity_ready`, `awaiting_evaluation`, `offline`, `error_retryable`, `read_only_posttest`, `completed`. No cambiar arbitrariamente layout en loading; preservar borradores; feedback y nueva tarea son superficies diferenciadas.

### 6.6 Por qué las capturas requieren cambios específicos

- **Data Detective:** pasar de un enorme checkbox por fila a selección contextual de celda/tipo de anomalía; tabla paginada/virtualizada con headers sticky; barra de anomalías halladas; «Vista cambios» antes/después; área de conclusión al lado de evidencia; scroll solo dentro de tabla. Etiquetar unidades C/F y convertir antes de comparar.
- **ML Experiment:** superponer dos corridas con etiquetas, marcar época de inflexión, introducir predicción antes de mover slider, mostrar causa vs correlación y «mantener constante X». Escalas matemáticamente coherentes; simulación claramente señalada.
- **Monitoring:** una visualización principal por pregunta, controles para seleccionar feature/período, hover/tooltip de distribución, comparación por fechas, histograma normalizado y chart de performance aparte; corregir ejes ilegibles/curvas planas y distinguir data drift vs concept drift sin afirmar diagnóstico definitivo.
- **Docker:** diagramas host/imagen/contenedor con simulación por estado; tree view editable, editor Dockerfile seguro con validación determinista, red de servicios y manejo de volúmenes; cada ejercicio tiene artefacto verificable y no se reduce a marcar opciones.

## 7. Especificación por laboratorio: enseñanza, interacciones, feedback y transferencia

### 7.1 Data Detective — M02-U02

**Objetivo:** detectar valores faltantes, imposibles, duplicados, unidades mixtas y leakage y elegir acciones diferenciadas. **No confundir outlier con error por defecto**.

1. Microlección con 5 tarjetas breves de errores y un ejemplo contrastivo realista.
2. Tabla sintética de producción (20–100 filas) paginada o virtualizada; columna temp con Celsius y Fahrenheit declarados, pressure con nulos, duplicados por clave; acompañar un diccionario de datos.
3. Estudiante toca celda o fila y abre `AnomalyInspector`: seleccionar tipo + «qué evidencia tengo» + «qué haría». El dataset no se altera hasta elegir propuesta de limpieza.
4. `CleaningWorkbench`: escoger transformación por categoría, visualizar antes/después y costos potenciales de eliminar/transformar datos.
5. Verificación determinista comprueba anomalías deliberadas; Jev evalúa justificaciones sobre decisiones inciertas.
6. **Intervención distinta A:** confundió unidades F/C → `UnitConversionExplorer` con valores convertidos y explicación.
7. **Intervención distinta B:** eliminó outlier válido → `OutlierVsErrorComparison` con contexto de producción y consecuencias.
8. Transferencia: nuevo dataset, anomalías equivalentes, sin pistas.

**Pantalla:** tabla en zona principal; inspector contextual anclado a selección, no 30 checkboxes; evidencias en un dock; feedback «marcaste presión ausente en fila X, ¿por qué imputar sería seguro?»; CTA «Comparar estrategias de limpieza».

### 7.2 ML Experiment Lab — M03-U02

1. Mini explicación entrenamiento vs validación y ejemplo resuelto.
2. Predicción: cuando aumente complejidad, ¿qué curva cambiará primero y por qué?
3. `LearningCurveSimulator`: complejidad, ruido, tamaño de muestra como entradas simuladas deterministas; muestra dos corridas guardadas y gráficas de loss con ejes claros y tooltip.
4. El alumno marca el punto de divergencia y selecciona curvas/evidencias; Jev evalúa explicación causal; validación determinista comprueba selecciones.
5. **Intervención A:** respuesta sin evidencia → `EvidenceComparison` para seleccionar segmentos exactos.
6. **Intervención B:** confusión overfitting/underfitting → `CounterexamplePlot` con otro par de curvas.
7. **Intervención C:** acierta → `HyperparameterTradeoffLab` con variación controlada.
8. Postest: curvas nuevas y parámetros no vistos, sin ayudas.

**Pantalla:** gráficos grandes sin botones debajo cada 500 px; sliders al lado o panel compacto; comparar runs no usa 5 colores; predicción fija arriba hasta contrastar con observación. Declarar «curvas simuladas», no inventar training real.

### 7.3 Model Monitoring Lab — M06

1. Aclarar conceptos: data drift vs concept drift vs degradación de métrica; causas alternativas (sensor, mezcla de población, etiqueta tardía).
2. `DriftDistributionExplorer`: referencia y actual por feature/período, tooltip/unidades y métricas descriptivas; en separado `PerformanceTimeline` muestra labels disponibles, no asumir causalidad.
3. Estudiante predice qué feature cambió y decide qué comprobar antes de actuar.
4. **Intervención A:** presume que drift significa caída de precisión → contraejemplo: cambia input pero performance estable.
5. **Intervención B:** propone reentrenar instantáneamente → `DecisionTreeEvidence` con calidad, métricas, causa y costo.
6. **Intervención C:** confunde cambio de concepto → diagrama del vínculo X→Y y etiquetas tardías.
7. Postest: nueva feature con shift, anomalías de calidad e incertidumbre.

**Pantalla:** distribución y series en paneles con tabs **dentro de la evidencia** (no fases del tutor), eje X legible, leyenda permanente, selector de fecha y feature. Nunca el gráfico plano de la captura ni decenas de ticks superpuestos.

### 7.4 Docker Academy Lab — M08

Cada unidad D01–D12 del currículo tendrá **un objetivo, un mini-lección, un experimento demostrable y una prueba de transferencia**. Prácticas principales:

| Unidad | Experimento de interfaz | Desafío de experto / transferencia |
|---|---|---|
| D01 | clasificar escenarios VM vs container con capas interactivas | elegir estrategia para app reproducible y justificar limitaciones |
| D02 | `ImageContainerLifecycle`: pull→run→stop→rm y estados | diferenciar eliminar contenedor de eliminar imagen |
| D03 | `DockerCommandBuilder`: componer `run -p`, `logs`, `exec` en terminal simulada | recuperar servicio que no responde |
| D04 | `DockerfileWorkbench`: editor guiado, capas, cache, `.dockerignore` | arreglar Dockerfile con instrucciones en orden incorrecto |
| D05 | `FileSystemMapper`: dos árboles de directorios + contexto de build | resolver `COPY failed` por ruta fuera de contexto |
| D06 | `PortNetworkSimulator`: host, container, puerto, DNS, localhost | arreglar frontend/API que apunta a localhost erróneo |
| D07 | `PersistenceExperiment`: escritura + recreación con/sin volumen | persistir DB SQLite y justificar backup |
| D08 | `ComposeArchitectureBuilder`: 3 servicios + networks + volumes + healthchecks | reparar Compose donde `depends_on` no garantiza servicio listo |
| D09 | `BrokenBuildDebugger`: logs con fallos sembrados | diagnosticar build que falla sin cambiar archivos a ciegas |
| D10 | `ContainerThreatModel`: secretos, usuario no root, permisos | sacar credenciales de image y comparar riesgos |
| D11 | `DeploymentTopologyLab`: registry, host, HTTPS, rollback | desplegar app con datos persistentes en host y recuperarla |
| D12 | `DockerCapstone`: integrar la ruta completa | diseñar solución Compose y resolver incidente nuevo sin pistas |

**MVP Docker prioritario:** D01, D02, D04 y D07 con widgets interactivos; semilla completa de 12 unidades. **No ejecutar Docker no confiable en el servidor**. Para práctica externa indicar comandos y verificaciones a realizar en máquina propia o sandbox controlado futuro; nunca afirmar ejecución real cuando es simulación.

## 8. Modelo de evaluación y feedback (Gemini + Jev + verificador)

### 8.1 Separación de responsabilidades

- **Verificador determinista:** evalúa hechos verificables (fila/celda, resultado SQL read-only, estado Docker simulado, aparición de dato tras volumen, unidad de temperatura).
- **Jev:** recibe enunciado, criterio/rúbrica, contexto del ejercicio y respuesta; produce decisiones estructuradas sobre uso de evidencia, exactitud conceptual y calidad de justificación. Aplicar adaptador oficial/SDK **solo tras confirmar contrato y proveedor realmente comprado**; logs anonimizados y errores bien mostrados.
- **Gemini:** tutor socrático y redactor de feedback; nunca inventa que Jev aprobó ni cambia scores; selecciona una estrategia pedagógica de lista aprobada; produce intención UI validable.
- **Policy Engine:** decide transiciones, permisos y cuándo desbloquear prueba; soporta incertidumbre y bloqueos.

**No utilizar scores Jev como porcentajes probabilísticos de dominio:** mostrar criterios, evidencia concreta y grado de apoyo. La corrección automática es orientativa. Las revisiones humanas con fines de investigación pueden hacerse **fuera de la UI del maestro**, mediante datasets anonimizados del piloto, sin añadir botones de calificación manual.

### 8.2 Rúbrica por objetivo, no score único

En cada objetivo evaluar: (a) conocimiento conceptual, (b) habilidad procedimental demostrada, (c) justificación basada en evidencia, (d) razonamiento causal y límites, (e) revisión/transferencia cuando aplique. Anclar niveles 0–4 descriptivamente; derivar escalas con método documentado y no tratar probabilidad de modelo como calificación. Conservar versiones de rúbrica, modelo, prompt, evidencia y asistencia por fase.

### 8.3 Diseño de retroalimentación

Evitar: `Causalidad · 2`, `Revisión · 2`, «fortaleza exactitud conceptual» sin indicar evidencia. Mostrar:

```text
LO QUE OBSERVASTE
La columna temperature contiene registros en grados F junto a valores en C.

LO QUE TU EXPLICACIÓN NO ABORDA AÚN
Marcaste las filas correctas, pero no propusiste una conversión comprobable.

PRUEBA AHORA
Convierte dos valores, observa cómo cambia la distribución y explica si eran anomalías o diferencias de unidad.
[Comparar unidades]  ← abre widget real

[Ver criterios usados]  ← opcional; muestra rúbrica Jev con contexto
```

**Obligatorio:** feedback basado en evidencia visible o evaluaciones realmente realizadas. Si evaluación incierta, mostrar «No se pudo concluir» y un experimento de verificación en vez de inventar éxito.

## 9. Dashboard del maestro: SOLO LECTURA (decisión de producto)

### 9.1 Lo que el maestro SÍ puede hacer

- Iniciar sesión y abrir resumen de los cuatro alumnos.
- Ver módulos, unidades y cursos completados; distinguir avance y dominio.
- Filtrar por alumno/módulo/competencia/fecha y consultar histórico.
- Ver resultados Jev por criterio, respuestas, evidencias, ayudas utilizadas y estado de evaluación.
- Comparar diagnóstico/pretest, aprendizaje, postest y retención posterior; indicar cuando no hay datos.
- Consultar tendencias y errores conceptuales recurrentes sin divulgar respuestas de alumnos a otros alumnos.
- Exportar resultados anonimizados SOLO si permisos y consentimiento permiten; puede posponerse en MVP.

### 9.2 Lo que el maestro NO puede hacer

**No** dar notas, agregar comentarios, usar sliders, aprobar/rechazar intentos, desbloquear postests, asignar actividades ni editar resultados o progreso. Eliminar estos controles de navegación/UI. Conservar tablas y datos históricos si existen; **no borrar migraciones ni datos**. Rutas previas de mutación quedan deprecadas o restringidas sin romper consumidores hasta auditarlos; ninguna ruta de escritura queda accesible para rol de solo lectura. Distinguir auditoría metodológica offline de un flujo docente manual.

### 9.3 Jerarquía de pantallas

**Resumen Instructor:** header «Progreso de 4 estudiantes»; cuatro indicadores: alumnos activos, sesiones completadas, unidades con dominio demostrado, evaluaciones pendientes (NO media opaca de «76% dominio»). Línea temporal de evidencias; tabla por alumno (nombre, unidades, postest, área a reforzar), fecha de última actividad.

**Detalle Alumno:** encabezado, ruta curricular, matriz competencias por unidad (con evidencia y fecha), evolución por criterio en el tiempo y lista de sesiones. Clic en sesión → lectura de enunciado, actividad, intentos, Jev, postest y apoyos usados. Ningún botón «Editar», «Revisar», «Guardar nota».

**Estado vacío:** «Todavía no hay postest para esta unidad»; **incertidumbre:** «Evaluación automática pendiente/insuficiente», no 0 ni aprobado. Comparaciones deben usar pruebas equivalentes, rúbricas consistentes y advertencia de muestras pequeñas.

**Permisos:** rutas instructor GET solo para autenticados con role instructor; API no debe exponer `POST/PUT/PATCH/DELETE` para modificar resultados desde ese rol; tests 403 a mutaciones. Student no puede leer datos ajenos. No confundir esconder un botón con autorización.

## 10. SQLite y APIs: migración compatible sin perder datos

### 10.1 Entidades nuevas y cambios incrementales

`learning_objectives`, `objective_prerequisites`, `lesson_contents`, `worked_examples`, `misconceptions`, `activity_blueprints`, `activity_instances`, `activity_events`, `evidence_links`, `diagnostic_results`, `student_mastery_evidence`, `independent_assessments`, `recall_schedule`, `student_attempt_revisions`, `provider_evaluations` (si no existe equivalente). No crear duplicados de tablas presentes: analizar esquema real antes de migrar; claves foráneas y migración reversible cuando sea posible. SQLite WAL, backups, volumen persistente si se despliega en contenedor futuro.

Guardar prompts versionados, modelo y proveedor, source activity, tiempo, asistencia, rúbrica y estado de mock vs real. Minimizar PII; no almacenar secretos. Soportar SQLite con transacciones cortas y conexiones por petición.

### 10.2 Contratos API conceptuales (adaptar rutas EXISTENTES)

| Método | Endpoint propuesto | Propósito |
|---|---|---|
| GET | `/api/me/learning-path` | módulos/unidades y avance |
| GET | `/api/units/{unit_id}` | objetivos, prerequisitos, contenidos y recursos |
| POST | `/api/units/{unit_id}/diagnostics` | iniciar diagnóstico |
| POST | `/api/learning-sessions` | continuar o crear sesión idempotente |
| GET | `/api/learning-sessions/{id}/current-activity` | recuperar estado y actividad |
| POST | `/api/learning-sessions/{id}/events` | interacción GenUI idempotente |
| POST | `/api/learning-sessions/{id}/submit` | respuesta final del turno |
| GET | `/api/learning-sessions/{id}/next` | siguiente ActivitySpec validada |
| POST | `/api/learning-sessions/{id}/independent-check` | prueba sin tutor |
| GET | `/api/me/recall-due` | repasos vencidos |
| GET | `/api/instructor/overview` | métricas agregadas readonly |
| GET | `/api/instructor/students/{id}` | matriz y detalle readonly |
| GET | `/api/instructor/sessions/{id}` | evidencia readonly |

Respetar API preexistente; los nombres arriba son sugerencias, **no mandato de duplicar endpoints**. Versionar DTOs con Pydantic. Autorización backend, CORS limitado y rate limit; no permitir enviar comandos arbitrarios sin sandbox. `EVALUATOR_MODE=jev|mock` y `LLM_PROVIDER=gemini`; modo mock etiquetado en cada resultado, no camuflar.

## 11. Seguridad, accesibilidad y metodología de evaluación

- Nunca incorporar claves Gemini/Jev en Dart, browser, repositorio ni logs. Probar fallos 401/429/timeout, backoff acotado, circuito abierto básico y modo pendiente.
- En postest, el servidor debe denegar las herramientas de tutor y las pistas; usar nuevos seeds/ítems equivalentes y mantener estado tras refresh. Registrar asistencia anterior sin alterar el postest.
- Prevenir prompt injection desde respuestas/cursos: contenido del alumno son datos, no instrucciones del sistema; allowlist de widget y parámetros.
- GenUI debe exponer semántica, teclado, foco, contraste WCAG AA, navegación accesible, anuncios de feedback cuando corresponda, sin depender de color.
- API de tareas nunca ejecuta Dockerfile, comandos shell o Python sin aislamiento real. Simular de forma honesta.
- Piloto de cuatro estudiantes: consentimiento, pseudónimos, retención definida y tareas comparables. Comparar métricas de completitud, intervenciones, errores corregidos, pre/post/retención; no atribuir causalidad. Calibrar Jev con rúbricas humanas mediante evaluación fuera del panel del instructor si se decide realizarla.
- Rendimiento: widgets grandes virtualizados, tabla y charts sin redibujado total en cada tecla, límite de eventos de slider (debounce) con estado local fluido y snapshots relevantes.

## 12. Backlog para OpenCode — implementación verificable

**Regla de seguimiento:** conservar historial de completados del plan anterior; estas son NUEVAS tareas de mejora sin estados predeterminados. Después de cada PR registrar archivos cambiados, pruebas ejecutadas, evidencia/captura y decisiones. No declarar completado sin evidencia real.

### Sprint 0 — Auditoría no destructiva (P0)
- [x] Levantar estructura frontend/backend actual, `pubspec.lock`, versión genui, rutas, tests y esquema SQLite; escribir `docs/current-state-audit.md` con pruebas.
- [x] Ejecutar `flutter analyze`, `flutter test`, `uv run pytest` y reproducir flujo lab real; reportar resultados exactos sin inventarlos.
- [x] Documentar bugs de screenshots: scroll excesivo, ejes ilegibles, botones ambiguos, postest prematuro y tablero de instructor con mutaciones.
- [x] Snapshot/backup SQLite y commit antes de migraciones.

### Sprint 1 — Un recorrido educativo completo con Data Detective o ML (P0)
- [x] Introducir `LearningObjective` + lección + ejemplo + diagnóstico pequeño para una unidad.
- [x] Rehacer el workspace con actividad principal y tutor contextual responsive; una sola acción principal; no tabs internos de orquestador.
- [x] Convertir `LearningCurveSimulator` o `DataTableExplorer` en widget bidireccional; eventos reales A2UI→backend y refresh/reanudación.
- [x] Guardar predicción, evidencia seleccionada, revisión y ayudas usadas en SQLite.
- [x] Implementar next activity DIFERENTE y explícita según dos errores distintos, no nueva tarjeta genérica.
- [x] Postest variante nueva autorizado por backend; asegurar modo sin ayuda.
- [x] E2E automatizado sobre la unidad completa.

### Sprint 2 — Gemini + Jev con gobernanza (P0)
- [x] Confirmar proveedor Jev comprado, SDK/request/response real; credenciales backend y request sample mínimo seguro.
- [x] Integrar Gemini con salida estructurada + allowlist de estrategias y widgets.
- [x] Verificación determinista + Jev por criterio; feedback muestra evidencia textual específica y nueva acción.
- [x] Tolerar fallo/rate limits; distinguir mock, real, incierto y pendiente; tests con fake clients.
- [x] Congelar/versionar rúbricas/prompts, log de decisiones breve y seguro.

### Sprint 3 — Laboratorios bien diseñados (P1)
- [ ] Rediseñar Data Detective con inspector por celda y simulación de limpieza.
- [ ] Rediseñar ML Experiment con predicción, comparación de dos runs y selección de evidencia.
- [ ] Rediseñar Model Monitoring con ejes legibles, feature/periodo y contraste drift vs performance.
- [ ] Seeds curricular completos de nueve módulos y doce unidades Docker con estado real de preparación.
- [ ] Docker D01/D02/D04/D07 con widgets del MVP y prueba de transferencia.

### Sprint 4 — Dominio, repaso e instructor (P1)
- [ ] Diagnóstico por objetivos, adaptación novato/intermedio/avanzado y ayuda gradual.
- [ ] RecallSchedule configurable 1/3/7 días, preguntas nuevas y seguimiento de retención.
- [ ] Dashboard instructor readonly: overview, estudiante, sesión. Quitar formularios/sliders/comentarios y permisos de escritura; preservar históricos.
- [ ] Métricas de dominio SOLO de postests versionados; histórico con evidencia real y estados vacíos.

### Sprint 5 — Calidad de producto, investigación y entrega (P1/P2)
- [ ] Aplicar `DESIGN.md`, Impeccable para critique/layout/typeset/polish/audit sobre capturas y builds Flutter, sin asumir parser Dart automático.
- [ ] Test accesibilidad, keyboard, responsive y densidad de gráficos en pantallas similares a screenshots.
- [ ] Pruebas de ownership instructor/student, postest sin IA y prompt injection, esquema A2UI, errores de proveedores y migraciones.
- [ ] URL HTTPS real, persistencia SQLite, secrets, backup/restore, README, diagrama, video 5 min, deck, documento ético 3–5 páginas.
- [ ] Prueba exploratoria consentida con cuatro estudiantes; documentar hallazgos sin generalizaciones.

### DoD (aceptación obligatoria)

- [ ] El alumno entiende el objetivo de la unidad ANTES de un desafío complicado.
- [ ] Cambiar un parámetro o seleccionar evidencia produce un evento persistido y una diferencia visible en el laboratorio.
- [ ] Dos respuestas con errores distintos generan actividades GenUI distintas, funcionales y pertinentes.
- [ ] El alumno ve **por qué** aparece cada actividad y qué hará; no solo «Siguiente actividad».
- [ ] Jev evalúa de verdad cuando hay key; si no, mock marcado y nunca inventar scores.
- [ ] Gemini produce feedback a partir de evidencia real, sin reemplazar puntuaciones ni decisiones del backend.
- [ ] Existe postest independiente diferente a la práctica; el backend bloquea ayuda.
- [ ] Repaso posterior e historial de retención disponibles o marcados claramente como fase futura.
- [ ] Instructor no puede calificar/comentar/asignar/desbloquear desde UI NI API; solo consultas.
- [ ] Datos SQLite e historial existentes siguen intactos tras migración.
- [ ] Flutter desktop/móvil, pruebas E2E, accesibilidad, secretos y despliegue pasan comprobaciones documentadas.

## 13. Instrucción exacta de arranque para OpenCode

> Lee `PLAN.md`, `DESIGN.md` y el plan histórico de avances. Audita el código real y el esquema SQLite; no reinicialices, no borres históricos ni implementes todo el currículo de una vez. Primero crea un PR vertical: una unidad enseñada con un ejemplo, un widget GenUI genuinamente interactivo, eventos bidireccionales persistidos, intervención distinta basada en resultados, postest sin ayuda y tests. Después integra Gemini y Jev reales, despliega las mejoras de UX y simplifica el instructor a un dashboard READ-ONLY. Conserva la trifecta visual, usa `uv` y PowerShell, no exijas WSL/Docker; nunca uses nano. Entrega resumen de archivos cambiados, comandos de prueba, resultados y tareas marcadas como verificadas. Si no puedes acceder a un servicio, indícalo y no simules que quedó integrado.

## 14. Referencias para el agente (leer fuentes primarias)

- Flutter GenUI: https://docs.flutter.dev/ai/genui y https://pub.dev/packages/genui
- Docker: https://docs.docker.com/get-started/ y https://docs.docker.com/compose/
- Kaggle Learn: https://www.kaggle.com/learn
- Google Gemini: https://ai.google.dev/gemini-api/docs
- TypeSafe/Jev: verificar la documentación del proveedor de la suscripción y esquema actual antes de integrar.
- Freeman et al. (2014), Active learning increases student performance in STEM, PNAS: https://doi.org/10.1073/pnas.1319030111
- Alfieri et al. (2011), Does discovery-based instruction enhance learning?, JEP: https://doi.org/10.1037/a0021017
- Kalyuga et al. (2003), The expertise reversal effect, Educational Psychologist: https://doi.org/10.1207/S15326985EP3801_4
- Bisra et al. (2018), Inducing self-explanation: A meta-analysis: https://doi.org/10.1007/s10648-018-9434-x
- Hattie & Timperley (2007), The power of feedback: https://doi.org/10.3102/003465430298487
- Roediger & Karpicke (2006), Test-enhanced learning: https://doi.org/10.1111/j.1467-9280.2006.01693.x
- Dunlosky et al. (2013), Improving students’ learning with effective learning techniques: https://doi.org/10.1177/1529100612453266
- Bastani et al. (2025), Generative AI without guardrails can harm learning: https://doi.org/10.1073/pnas.2422633122

---

## Anexo A — Seguimiento histórico original (NO reescribir el progreso)

El siguiente extracto procede de la checklist anterior; `[x]` significa **declarado completo en aquel archivo**, no validado nuevamente en esta sesión. Conservar en el repositorio el archivo histórico íntegro.


### Épica A — Infraestructura

- [x] A1 Crear monorepo, README, `frontend/`, `backend/` (falta `AGENTS.md`, `.gitignore`).
- [x] A2 Configurar Python 3.12 con `uv` y pytest (falta `ruff`).
- [x] A3 Configurar Flutter Web 3.47.7, `flutter analyze` + `flutter test` en verde (rutas con `NavigationBar`; falta `go_router`).
- [ ] A4 Definir `.env.example`, error handler y logs sin secretos.
- [ ] A5 Integrar GitHub Actions para Flutter analyze/test y pytest.

### Épica B — Datos

- [x] B1 SQLAlchemy y conexión SQLite; WAL + `PRAGMA foreign_keys=ON`.
- [x] B2 Datos semilla reproducibles vía `app/seed.py` (Alembic diferido hasta congelar schema pre-piloto).
- [x] B3 Cuatro estudiantes demo y un instructor (`s1-s4`, `i1`).
- [x] B4 Seed de 8 módulos y tres laboratorios (falta tabla `courses` con URLs externas).
- [x] B5 CRUD de sesiones/intentos (falta control de acceso por roles).

### Épica C — Frontend

- [x] C1 Shell responsive con 4 tabs basado en mockup (theme mínimo).
- [x] C2 Academia (desde `/modules` real, sin hardcodeo) y listado de laboratorios.
- [x] C3 Detalle de laboratorio y estados cargando/error/sin red.
- [x] C4 Panel de instructor mínimo (4 estudiantes vía `/instructor/students`; falta historial).
- [x] C5 Test de shell (`flutter test` 1 passed); falta accesibilidad y móvil.

### Épica D — Laboratorio ML (vertical slice)

- [x] D1 Generador determinista de curvas (`app/labs_ml.py`, etiquetadas sintéticas).
- [x] D2 Flutter gráfico con sliders, selecciones y justificación (`LabDetailPage`).
- [x] D3 Tracking de intentos e hipótesis previas (`GET /sessions/{id}/attempts`).
- [ ] D4 Postest con variante nueva sin pistas.
- [ ] D5 Resumen final honesto y registro de resultados.

### Épica E — Evaluación

- [x] E1 Rúbrica inicial de overfitting (`ml-overfitting-v1`, 5 criterios).
- [x] E2 Contrato `MockEvaluator` determinista + `POST /sessions/{id}/evaluate` (etiquetado `mock`).
- [ ] E3 Integración Jev HTTP real con esquema actual, tests mock HTTP.
- [ ] E4 Traducción de decisiones Jev a salida interna tipada.
- [ ] E5 Vista de discrepancias y corrección del instructor.

### Épica F — Tutor y GenUI

- [ ] F1 Cliente LLM desacoplado y prompts versionados.
- [ ] F2 Máquina de estados y reglas socráticas deterministas base.
- [ ] F3 UI planner que produce intención de widget validada.
- [ ] F4 Catálogo Flutter GenUI + adaptador A2UI conforme SDK fijado.
- [ ] F5 Flujo evento→backend→evaluación→intervención→GenUI→evento.
- [ ] F6 Fallback cuando falla LLM/Jev o el UI spec no valida.

### Épica G — Dos laboratorios adicionales

- [ ] G1 Data Detective (tabla + anomalía + justificación).
- [ ] G2 Monitoring (drift simulado + interpretación).
- [ ] G3 Rúbricas de ambos y postests pequeños.

### Épica H — Investigación y entregables

- [ ] H1 Protocolo piloto con consentimiento y anonimización.
- [ ] H2 Capturar resultados de cuatro estudiantes; revisión humana.
- [ ] H3 Documento ético y gobernanza (3–5 páginas).
- [ ] H4 Arquitectura, despliegue, prompts y revisión de fallos.
- [ ] H5 Video de 5 minutos y presentación.
- [ ] H6 Deploy, smoke tests y envío a CHARAL.

---



## Anexo B — Gobierno de alcance y secuencia de entrega

**Para CHARAL:** implementar un recorrido E2E de un laboratorio existente y un segundo ejemplo diferencial; no construir todas las unidades Docker ni todas las pantallas antes del 31 de octubre. Mantener las demás unidades como temario real de largo plazo sin pretender interactividad terminada. El instructor readonly y las evaluaciones independientes deben estar demostrables. Documentar claramente qué está simulado y qué usa servicios reales.
