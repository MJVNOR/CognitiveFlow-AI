# CognitiveFlow AI — instrucciones para agentes

## Python: siempre `uv` (nunca `python`/`pip` directos)

```powershell
cd backend
uv sync
uv run pytest -q
uv run python -m app.seed
uv run uvicorn app.main:app --reload --port 8000
```

## Tests backend: prohibido gastar APIs reales

- `backend/.env` tiene **keys reales** y `load_dotenv()` las carga al importar `app.main`.
- Los tests usan SQLite en memoria + fixture autouse `_no_live_llm` (fuerza mock Gemini).
- Regla: todo test de `jev_*`/`socratic`/`socratic_question` usa HTTP simulado
  (`monkeypatch` sobre `httpx.post`) o setting `EVALUATOR_MODE`/`*_API_KEY` por env.
  Fallo de proveedor ⇒ `status: pending`, `criteria: []`, jamás scores.
- CI no tiene keys: nada puede depender de red.

## Reglas de dominio (no negociables)

- `evaluation_results` es append-only; la revisión humana va a `instructor_reviews`.
- Catálogo GenUI cerrado: `backend/app/interventions.py::CATALOG` debe coincidir
  con `frontend/lib/genui/catalog.dart::cognitiveFlowWidgets`.
- `ui_spec` interna (`{type, version, parameters...}`) ≠ mensajes A2UI del wire
  (`{version: v0.9, createSurface|updateComponents}`); la traducción vive en
  `frontend/lib/genui/tutor_surface.dart`.
- Rúbricas mock etiquetadas (`evaluator: mock`); Jev real solo en ML
  (`EVALUATOR_MODE=jev`), datos/monitoreo usan mock determinista.
- Auth demo: login por `user_id` (`s1-s4`, `i1`), token opaco en tabla `auth_tokens`
  (sin passwords: solo piloto). Propiedad vía `session_for` (403 ajeno).

## Esquema SQLite sin Alembic (deuda explícita)

- `Base.metadata.create_all` no altera tablas existentes: un cambio de modelo
  exige borrar `backend/cognitiveflow.db*` + `seed` (solo con la API apagada;
  en Windows el archivo se bloquea mientras un servidor lo tiene abierto).
- Seed demo: 8 módulos, 5 usuarios, 3 labs (`uv run python -m app.seed`).

## Frontend (Flutter 3.47.7, web)

```powershell
cd frontend
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000
flutter analyze --no-pub; flutter test; flutter build web
```

- `flutter run -d chrome` no funciona en este equipo: usar `web-server`.
- **REGLA: todo texto visible es seleccionable** (`SelectionArea` global en
  `MaterialApp.router.builder`). No usar `Text` fuera de ella.
- `genui 0.10.4` fijado en `pubspec.lock`; builders usan `BoundString` +
  `CatalogItemContext`; `Surface` se obtiene con `controller.contextFor(id)`.
- Backend sin `CORSMiddleware` ⇒ el login web falla (preflight `OPTIONS` 404).
- **Estado global con Riverpod (`flutter_riverpod`):** `lib/state/app_state.dart`
  (`authProvider`, `themeModeProvider`; `routerProvider` en `main.dart` se
  recrea al cambiar auth). Lo local de labs/charts/forms sigue en `setState`;
  borradores en `SharedPreferences` (`draft:<labId>:<campo>`, se limpian al
  cerrar la reflexión). No meter labs/GenUI/fetch en providers sin motivo.

## Smoke servers

- Puertos efímeros (8001+) con `Start-Job`; matar con `Remove-Job` + buscar el
  `python.exe` huérfano por puerto (`netstat -ano`), no existe proceso `uvicorn`.

## Git y secretos

- Rama `main`, remoto `origin` (`MJVNOR/CognitiveFlow-AI`); identidad local lista.
- `.gitignore` excluye `.env`, `opencode.json`, `.venv`, `*.db*`, `build/`.
  **Nunca** stagear `opencode.json` (tiene keys MCP locales) ni imprimir keys.
- Plan vivo en `COGNITIVEFLOW_PLAN.md` (§22 hallazgos verificados): marcar `[x]`
  con evidencia al cerrar cada épica.
