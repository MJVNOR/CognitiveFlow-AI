"""CognitiveFlow AI — factory FastAPI delgada; rutas por dominio en app/routers/."""
import os
from contextlib import asynccontextmanager

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.db import upgrade_head
from app.routers import auth, instructor, labs, socratic
from app.seed import seed_if_empty
from app.socratic import LLMUnavailable

load_dotenv()


@asynccontextmanager
async def lifespan(_: FastAPI):
    upgrade_head()
    seed_if_empty()
    yield


app = FastAPI(title="CognitiveFlow AI", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o for o in os.getenv(
        "CORS_ORIGINS", "http://localhost:8080,http://127.0.0.1:8080").split(",") if o],
    # Piloto local: cualquier puerto efímero en loopback (smoke en 8081+).
    # Solo loopback; el servidor no se expone a la red.
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(LLMUnavailable)
async def llm_unavailable(_: Request, exc: LLMUnavailable):
    # Sin respuestas inventadas: el cliente muestra el error y reintenta.
    return JSONResponse(status_code=503, content={"detail": str(exc)})


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/v1/models")
def list_models():
    # Espejo solo-lectura del catálogo Gemini (0 tokens): silencia sondeos OpenAI-style.
    key = os.getenv("GEMINI_API_KEY", "") or os.getenv("GOOGLE_API_KEY", "")
    if not key:
        return {"data": []}
    try:
        r = httpx.get(
            "https://generativelanguage.googleapis.com/v1beta/models",
            headers={"x-goog-api-key": key},
            timeout=20,
        )
        r.raise_for_status()
        return {"data": [{"id": m.get("name", "").replace("models/", "")}
                         for m in r.json().get("models", [])]}
    except Exception:
        return {"data": []}


app.include_router(auth.router)
app.include_router(labs.router)
app.include_router(socratic.router)
app.include_router(instructor.router)
