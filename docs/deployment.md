# Despliegue demo (HTTPS)

## Backend — Render (Blueprint `render.yaml`)

1. Conecta el repo `MJVNOR/CognitiveFlow-AI` en Render → New → Blueprint.
2. Render crea `cognitiveflow-api` con disco persistente (`/backend/data`).
3. En Environment, pega los secretos (nunca en git): `GEMINI_API_KEY`, `JEV_API_KEY`.
4. Ajusta `CORS_ORIGINS` a la URL pública del frontend.
5. Verifica: `https://<tu-api>.onrender.com/health`.

> SQLite vive en el disco persistente con backups de Render. Para escalar,
> migrar a PostgreSQL (los modelos usan SQLAlchemy 2, compatible).

## Frontend — hosting estático (Cloudflare Pages / Netlify / GitHub Pages)

```powershell
cd frontend
flutter build web --dart-define=API_BASE_URL=https://<tu-api>.onrender.com --release
```

Sube `build/web` al host estático. Eso es todo: la app es 100% estática.

## Variables (ver `backend/.env.example`)

`DATABASE_URL`, `LLM_PROVIDER=gemini`, `LLM_MODEL=gemini-3.8-flash`,
`GEMINI_API_KEY`, `JEV_API_KEY`, `JEV_BASE_URL=https://jev-api.org`,
`EVALUATOR_MODE=mock`, `CORS_ORIGINS`, `AUTH_SECRET`, `DEMO_MODE=true`.
