# Current State Audit — 2026-10-17 (Sprint 0 P0)

Commit: `acf031f` · DB intacta, sin migraciones. No se reinicializa ni se borra SQLite.

## 1. Versiones fijadas

- `frontend/pubspec.yaml`: `genui ^0.10.4`, `a2ui_core ^0.1.1`, `go_router ^18.1.0`, `flutter_riverpod ^3.4.3`, `fl_chart ^1.2.0`, `shared_preferences ^2.5.6`
- `frontend/pubspec.lock` real: `genui 0.10.4`, `a2ui_core 0.1.1`, `go_router 18.1.0`, `flutter_riverpod 3.4.3`
- `backend/pyproject.toml`: `python ==3.12.*`, dev: `fastapi>=0.143.1`, `sqlalchemy>=2.1.4`, `httpx>=0.28.1`, `pytest>=8`, `uvicorn[standard]`
- `backend/app/main.py`: CORS activado (corrige nota vieja de 404 preflight), `lifespan` con `init_db + ensure_columns + seed_if_empty`.

## 2. Estructura real

- Backend `app/`: `main.py`, `db.py`, `models.py`, `seed.py`, `labs_ml.py`, `labs_data.py`, `labs_monitor.py`, `evaluation.py`, `socratic.py`, `interventions.py`, `helpers.py`, `auth.py`, `routers/{auth,labs,socratic,instructor}.py`
- Frontend `lib/`: `main.dart`, `features/{academy,ml_lab,data_lab,monitor,progress,instructor,login,review}_page.dart`, `genui/{catalog,tutor_surface}.dart`, `state/`, `session/`, `models/`, `widgets/`, `l10n/`
- Tests: `backend/tests/test_main.py` (~1160 líneas), `frontend/test/{genui_catalog,models,progress,result_panel,tutor_surface,widget}_test.dart`

## 3. Rutas backend (verificadas por grep + tests)

Auth: `POST /auth/login`, `DELETE /auth/logout`, `GET /auth/me`
Labs/sesiones: `GET /modules`, `GET /labs`, `GET /me/lab-status`, `GET /me/sessions`, `GET /me/progress`, `POST /sessions`, `GET /sessions/{id}`, `GET /sessions/{id}/attempts`, `POST /sessions/{id}/attempts`, `POST /sessions/{id}/events`, `POST /sessions/{id}/posttest`, `POST /sessions/{id}/reflection`, `GET /sessions/{id}/interventions`, `GET /sessions/{id}/tutor-history`, `GET /labs/{id}/curve|dataset|distributions`
Evaluación/tutor: `POST /sessions/{id}/evaluate`, `POST /sessions/{id}/socratic`, `POST /sessions/{id}/next-intervention`
Instructor: `GET /instructor/...` solo lectura (`POST reviews` eliminado en Sprint 4), `GET /instructor/export`, `GET /instructor/matrix`, `GET /instructor/agreement`, `GET /instructor/backup`

## 4. Pruebas ejecutadas (evidencia, no inventario)

- `cd backend; uv run pytest -q` → `65 passed, 1 skipped` (skip = `test_jev_live_opt_in`, requiere `JEV_LIVE_TEST=1`). Incluye `test_ml_objective_and_diagnostics`.
- `cd frontend; flutter test` → `37 passed` (`All tests passed!`).
- `cd frontend; flutter analyze --no-pub` → `No issues found!` (62.6s).
- Flujo lab real cubierto en tests: `test_e2e_lab_loop_no_credits` (practicar→evaluar→tutor→intervenir→evento→postest→reflexión con mocks, sin gastar Jev/Gemini).

## 5. SQLite `cognitiveflow.db` (archivo dev, 2026-10-17)

Tablas: `auth_tokens(22)`, `evaluation_results(18)`, `instructor_reviews(0)`, `intervention_log(6)`, `lab_attempts(20)`, `lab_templates(3)`, `learning_objectives(1)`, `learning_sessions(40)`, `modules(8)`, `reflections(2)`, `ui_events(13)`, `users(5)`.
Columnas clave: `auth_tokens(token,user_id,created_at)` con `ensure_columns()` para no borrar datos; `evaluation_results(attempt_id,evaluator,rubric_version,normalized_scores_json,status)` append-only; `ui_events(id=client_event_id,session_id,widget_type,event_type,payload_json)` dedup natural.
Seed: 8 módulos, 5 usuarios (s1-s4,i1), 3 labs (lab-data, lab-ml, lab-monitor). Faltan tablas PLAN §10 (`objectives`, `diagnostics`, `independent_assessments`, `recall_schedule`, etc.) → pendiente, migrar sin borrar.

## 6. Catálogo GenUI (contrato cerrado, coincide)

Backend `app/interventions.py::CATALOG` (12): SocraticQuestionCard, HypothesisEditor, ChoiceReasoningWidget, DataTableExplorer, SqlQueryWorkbench, LearningCurveSimulator, DriftDistributionExplorer, EvidenceComparison, ConceptMapBuilder, PipelineDAGBuilder, RubricFeedbackCard, ReflectionSummary.
Frontend `lib/genui/catalog.dart::cognitiveFlowWidgets` (12): idéntico set. `tutor_surface.dart::interventionToComponent` traduce `next-intervention` a A2UI con fallback a SocraticQuestionCard, nunca crash.
`ALLOWED_BY_WIDGET` + `validate_ui_spec` + `test_events_*` verifican idempotencia `client_event_id` y 403 ajeno.

## 7. Clasificación PLAN §1

- Implementado y verificado: shell + academia + 3 labs, curvas/datasets/distribuciones deterministas, mock evaluator etiquetado, Jev real con `pending` sin inventar scores, socrático mock/Gemini conmutado, intervenciones 6 estrategias, postest con semilla ≥100 y bloqueo tutor, reflexión honesta, auth por `user_id` + expiración 12h + rate-limit login, instructor GETs + export anonimizado + backup.
- Existe pero incompleto: instructor aún con `POST /reviews` (PLAN §9 exige readonly total — de momento append-only fuera de UI maestro, falta deprecar); `LearningCurveSimulator`/`DataTableExplorer` funcionales pero sin inspector por celda ni EvidenceDock del PLAN §6; monitoreo con ejes mejorados en código, sin validar contra capturas.
- Pendiente: `LearningObjective`/diagnóstico/adaptatividad, workspace 65/35 + tutor contextual, Docker D01/D02/D04/D07, recall 1/3/7, dashboard readonly sin mutaciones, seeds curriculares 9 módulos.
- No verificable (solo capturas, sin código que lo pruebe): scroll excesivo, ejes ilegibles, botones ambiguos, postest prematuro — se documentan como bugs de screenshots PLAN Sprint 0, no se afirman como estado actual sin repro UI.

## 8. Snapshot

Backup local `backend/cognitiveflow.backup-20261017.db` (86 KB, 2026-10-17, `*.db` ignorado en git — no se commitea DB). Tabla nueva `learning_objectives` creada vía `create_all` sin borrar: 40 sesiones preservadas + 1 objetivo sembrado. `GET /instructor/backup` (solo instructor) como vía de respaldo externo.

## 9. Bugs de screenshots (Sprint 0, observación de capturas PLAN §1/§6 — no prueba de ausencia de código)

1. Data Detective: selección por fila con checkbox enorme + área de scroll extensa; panel derecho con chips de scores separados de la evidencia. Esperado §6: inspector contextual por celda/tipo de anomalía + EvidenceDock al lado de la conclusión, tabla paginada con sticky headers.
2. Model Monitoring: segunda gráfica con ejes densos/ilegibles + posible curva plana. Esperado §6: una visualización por pregunta, eje X legible, leyenda permanente, tabs dentro de la evidencia (no fases del tutor), distinguir drift vs performance sin afirmar causalidad.
3. ML Experiment: sliders y justificación visibles pero continuación mayormente textual; predicción no fijada antes del experimento. Esperado §6: predicción con timestamp arriba, superposición de 2 corridas, marca de inflexión, declarar simulación.
4. Postest prematuro: invitación «Ir al postest» expuesta al inicio. Esperado: una sola acción principal por estado; postest solo vía backend tras práctica (`ready_for_independent_check`), shell limpia sin tutor.
5. Instructor con mutaciones: `POST /instructor/attempts/{id}/reviews` existe (append-only, tests 403 para student). Esperado §9: readonly total — deprecation/restricción pendiente sin romper consumidores hasta auditar.

## 10. Sprint 1 (primera tarea, 2026-10-17)

`learning_objectives` (id, lab_template_id, title, level, concept_summary, worked_example_json, misconceptions_json, rubric_id, diagnostic_blueprint_json) + seed `M03-U02-generalization` (lab-ml: overfitting vs underfitting, ejemplo 3 pasos, 3 misconceptions, rúbrica `ml-overfitting-v1`) + `GET /labs/{id}/objectives` y `POST /labs/{id}/diagnostics` (2 ítems `LearningCurveSimulator` dg-1/dg-2, 404 en lab desconocido). Tests: `test_ml_objective_and_diagnostics` (65 passed, 1 skipped). Pendiente siguiente checkbox: workspace 65/35 + widget bidireccional.

## 11. Sprint 1 cierre (2026-10-17)

Workspace: pasos en lenguaje estudiante (`Aprende el concepto…Aplica sin ayuda`), postest con puerta tras 1ª evaluación (3 labs), ConceptPrimer ML + miga Módulo·Unidad, next `Continuar: <título>` y breakpoint 1100. Bidireccional: `InterventionLog` guarda la intervención completa y `GET interventions` devuelve spec + pregunta; `resume()` la restaura sin re-evaluar (no en postest). E2E `test_e2e_full_ml_unit`: débil→`EvidenceComparison`, fuerte→`HypothesisEditor`, 3 eventos en `ui_events`, postest seed≥100 + reflexión. Tests: backend 66 passed / frontend 39 passed / analyze limpio.

## 12. Sprint 2 cierre (2026-10-17)

Proveedor confirmado por código + keys presentes (`GEMINI`/`JEV_API_KEY`/`JEV_BASE_URL` SET, sin mostrar valores): request Jev real a `{base}/v1/systemone` con Bearer, payload `{model,state,questions}`; test de forma + redacción (key jamás fuera del header). Gemini con salida validada (`_clean`: pregunta ≤500, texto ≤600) y allowlist determinista intacta (estrategia/widget nunca vienen del LLM; test hostil lo prueba). Mock con evidencia textual determinista («Vas bien en X; a trabajar: Y con evidencia concreta», sin scores). Fallos/rate limits → `pending` con criterios `[]` (tests con fakes, sin gastar). Contrato congelado: rúbricas `ml-overfitting-v1`/`data-cleaning-v1`/`drift-v1`, prompts `socratic-v1`/`feedback-v1`, `SCHEMA_VERSION=1`, catálogo 12 (test manifiesto). Jev real solo en ML; datos/monitoreo con mock determinista (diseño, no deuda). Live no ejecutado: requiere tu OK (`JEV_LIVE_TEST=1`, 1 crédito). Tests: backend 69 passed / frontend 39 passed / analyze limpio.

## 13. Sprint 3.3 Monitoring (2026-10-17)

Objetivo `M06-U04-drift` + diagnósticos (2 ítems `DriftDistributionExplorer`); fallback de endpoints genérico por `OBJECTIVES`. Página: `ChoiceChip` de feature (un toque), tabs Distribución|Serie dentro de la evidencia, eje X del histograma con centros de bin (cada 2, tamaño 9), serie con intervalo 30, medias ref/actual + Δ con aviso «sin etiquetas no se afirma», tabla por pestaña, ConceptPrimer + miga, breakpoint 1100. Tests: backend 70 passed (nuevo `test_monitor_objective_and_diagnostics`) / frontend 40 passed / analyze limpio. Límite honesto: el postest varía semilla pero la feature con deriva sigue siendo `temp` (verdad fija en `labs_monitor.generate`); nueva feature con shift queda pendiente.

## 14. Sprint 3 cierre (2026-10-17)

Data Detective: inspector por fila (tipo + acción, diálogo con drafts) sin checkbox masivo, `cell_types`/`actions` en `extra` del intento, `detail.types_ok` determinista en el evaluador, vista previa de limpieza simulada (convertir/imputar/eliminar con medias reales) y ConceptPrimer M02-U02. ML: guardar 1 corrida y superponer su validación (leyenda + tabla), slider de época de divergencia con `evidenceSelected` persistido. Seeds: 9 módulos (m8 Docker, m9 integrador), 7 objetivos con `status` real (`interactive_ready` ×3, `content_ready` ×4 Docker), columna agregada vía `ensure_columns` sin borrar datos. Docker D01/D02/D04/D07: 4 widgets GenUI interactivos (clasificar, ciclo por pasos, reordenar Dockerfile, predecir+recrear persistencia) con eventos y tests; `CATALOG` 12→16 con allowlist; transferencia = dg-2 por unidad en blueprints. Tests: backend 72 passed / frontend 50 passed / analyze limpio.

## 15. Sprint 4 cierre (2026-10-17)

1. Instructor readonly: eliminado `POST /instructor/attempts/{id}/reviews` (404 para ambos roles; export/matriz/agreement intactos, históricos preservados); página de sesión en solo lectura (sin sliders/notas/guardar) y matriz sin chips de pendiente irresolubles.
2. Dominio solo de postests: `mastery` + `mastery_status` en progreso/matriz; UI declara «Sin dominio demostrado todavía (la práctica no cuenta)» hasta el postest.
3. Diagnóstico por objetivo: `diagnostic_results` en la primera evaluación (needs_foundation|guided_practice|autonomous_challenge, misma escala que la política de ayuda); `GET session` expone `level` + `assistance{hints,socratic,interventions}`; workspace muestra «Ruta: … · Ayudas usadas: N».
4. Repaso 1/3/7: `recall_schedule` al cerrar la sesión; `GET /me/recall-due` (vencidos) + `POST /me/recall/{id}/done` con ownership; sección «Repasos vencidos» en Progreso. Preguntas nuevas vía variantes del servidor; sin automatización de correos. Tests: backend 74 passed / frontend 51 passed / analyze limpio.

## 16. Sprint 5 parcial — entrega (2026-10-17, solo lo automatizable)

`.env.example` (backend, solo vars que el código lee), README con arquitectura
(mermaid), contratos GenUI, tabla de tests, procedimiento backup/restore y tabla
honesta simulado-vs-real. Pendiente humano: deploy + HTTPS, video, deck,
documento ético, piloto, critique Impeccable. Checkbox 4 de Sprint 5 queda sin
marcar hasta el deploy real.
