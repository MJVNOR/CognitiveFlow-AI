# PR-01 — Baseline & Security (P0.1–P0.4)

Fecha: 2026-10-16 · Rama: `pr-01-baseline-security` · Plan: `PLAN.md` §0 + P0

## P0.1 Auditoría reproducible — inventario verificado

### Backend (`backend/app/`)
- Endpoints (23, `app/main.py`): `GET /health, /v1/models, /modules, /labs, /me/lab-status, /auth/me, /labs/{id}/curve|dataset|distributions, /sessions/{id}, /sessions/{id}/attempts, /instructor/students, /instructor/students/{id}/sessions, /instructor/export` + `POST /auth/login, /sessions, /sessions/{id}/attempts|evaluate|socratic|next-intervention|posttest|reflection, /instructor/attempts/{id}/reviews`.
- Tablas (9, `app/models.py`): `users, modules, lab_templates, learning_sessions(active|posttest|done), lab_attempts, evaluation_results(evaluator:mock|jev), reflections, auth_tokens, instructor_reviews`.
- Catálogo (`app/interventions.py`, 12): SocraticQuestionCard, HypothesisEditor, ChoiceReasoningWidget, DataTableExplorer, SqlQueryWorkbench, LearningCurveSimulator, DriftDistributionExplorer, EvidenceComparison, ConceptMapBuilder, PipelineDAGBuilder, RubricFeedbackCard, ReflectionSummary.
- Deps fijadas (`pyproject` + `uv.lock`): `requires-python==3.12.*`, prod solo `google-genai 2.31.0`; dev: fastapi 0.143.1, sqlalchemy 2.1.4, httpx 0.28.1, pytest 9.1.1, uvicorn 0.54.0.

### Frontend (`frontend/`)
- `lib/main.dart`: 2593 líneas. Rutas go_router (`main.dart:107-152`): `/login`, Shell(`/academy,/labs,/labs/:labId,/progress,/instructor,/instructor/session/:sid`); `:labId` → data_detective/monitoring/LabDetailPage; guard instructor→`/academy` si es estudiante.
- `lib/genui/catalog.dart` (214 lín, 12 widgets): 5 con schema propio (`SocraticQuestionCard, EvidenceComparison, HypothesisEditor, DataTableExplorer, DriftDistributionExplorer`); 7 vía `_simpleCard` (`ChoiceReasoningWidget, SqlQueryWorkbench, LearningCurveSimulator, ConceptMapBuilder, PipelineDAGBuilder, RubricFeedbackCard, ReflectionSummary`). **P1.2 pendiente: LearningCurveSimulator aún no es interactivo.**
- `lib/genui/tutor_surface.dart` (94 lín): `interventionToComponent()` → A2UI v0.9 vía `SurfaceController(catalog ai.cognitiveflow.tutor/surface)`.
- `lib/state/app_state.dart` (111 lín): Riverpod `authProvider, themeModeProvider`; `SharedPreferences: apiToken/apiUserId/apiRole/themeMode + draft:<labId>:<campo>`.
- Versiones (`pubspec.lock`): `genui 0.10.4, flutter_riverpod 3.4.3, a2ui_core 0.1.1, go_router 18.1.0`.
- Tests (`test/`, 4 ficheros): `genui_catalog_test, tutor_surface_test, models_test, widget_test`.

## P0.2 Línea base — ejecutada 2026-10-16, sin modificar lógica

| Comando | Resultado |
|---|---|
| `cd backend && uv sync && uv run pytest -q` | **30 passed** (1 warning preexistente: `starlette.testclient` deprecation por `httpx`, sin impacto) |
| `cd frontend && flutter analyze --no-pub` | **No issues found** |
| `cd frontend && flutter test` | **20 passed** |

Reproducir: comandos de arriba en sus carpetas. Backend usa SQLite `:memory:` + fixture `_no_live_llm` (sin red ni keys reales en tests).

## P0.3 Credenciales — verificado

- `.env` con keys reales existe pero está ignorado (`.gitignore:14` lo cubre; verificado con `git check-ignore`). `*.db` también ignorado.
- `backend/.env.example` cubre `DATABASE_URL, LLM_PROVIDER, LLM_MODEL, GEMINI_API_KEY, JEV_API_KEY, JEV_BASE_URL, EVALUATOR_MODE, CORS_ORIGINS, AUTH_SECRET, DEMO_MODE`. **Fix PR-01:** se añade `GOOGLE_API_KEY=` (fallback que `main.py:52` ya lee) + comentarios AI-Studio-vs-Vertex y JEV mock-vs-real.
- `load_dotenv()` carga `.env` al importar `app.main`; tests fuerzan mock borrando keys (`_no_live_llm`). `EVALUATOR_MODE=jev` solo afecta `ml_experiment`; data/monitor quedan en mock (deuda explícita, no fuga).
- CORS **sí existe** en `app/main.py:33-39` (`CORSMiddleware`, orígenes por `CORS_ORIGINS` default `localhost:8080,127.0.0.1:8080`). Corrige reporte previo que lo daba por ausente.

## P0.4 Seguridad mínima — verificado por tests

- Ownership vía `app/auth.py::session_for`: 404 si no existe, 403 si `role!=instructor` y `student_id!=user.id`. Cubierto por tests (`test_main.py`: A no lee sesión de B).
- `evaluation_results` append-only; revisión humana solo inserta en `instructor_reviews` con validación 0–4 (422 si no). Export anonimiza `STU-NN`, sin nombres.
- Deuda documentada (no bloquea PR-01, no se toca aquí): tokens opacos sin expiración/logout/rotación; `POST /sessions` permite a instructor `student_id` arbitrario (by design, auditar); `POSTTEST_SEED=99` fijo; IDs `hex[:8]`; sin Alembic (`create_all`); sin FKs; intervenciones no persistidas; export sin paginación; `socratic` httpx síncrono; `main.dart` 2593 lín por partir por feature.

## Estado tickets P0

- P0.1 Auditoría reproducible: **verificado** (este fichero).
- P0.2 Línea base: **verificado** (tabla de arriba).
- P0.3 Credenciales: **verificado** (fix `GOOGLE_API_KEY` incluido).
- P0.4 Seguridad mínima: **verificado** (tests ownership + append-only pasan).

## Archivos tocados en PR-01

- `docs/current-state.md` (nuevo, este fichero).
- `backend/.env.example` (añade `GOOGLE_API_KEY` + comentarios).
- Sin cambios de lógica, sin migraciones, sin borrar DB.
