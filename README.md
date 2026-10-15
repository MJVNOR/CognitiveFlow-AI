# CognitiveFlow AI — MVP

## Correr (2 terminales PowerShell)

```powershell
# Terminal 1 — backend
cd backend
uv sync
uv run python -m app.seed
uv run uvicorn app.main:app --reload --port 8000
```

```powershell
# Terminal 2 — frontend (web-server: chrome -d falla en este equipo)
cd frontend
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000
# abrir manual: http://localhost:8080
```

Verificar: http://localhost:8000/health, http://localhost:8000/modules
