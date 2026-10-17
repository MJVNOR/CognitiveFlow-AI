"""Auth demo: login/logout/me por user_id (ver app/auth.py)."""
import time

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import models
from app.auth import _bearer, current_user, new_token, revoke_token
from app.db import get_db
from app.schemas import LoginOut, MeOut

router = APIRouter()


class LoginIn(BaseModel):
    user_id: str


_LOGIN_HITS: dict[str, list] = {}  # ponytail: memoria local, 1 worker demo
LOGIN_MAX_MIN = 10  # P7.1: freno a fuerza bruta en login demo


def _login_allowed(ip: str) -> bool:
    now = time.monotonic()
    hits = [t for t in _LOGIN_HITS.get(ip, []) if now - t < 60]
    _LOGIN_HITS[ip] = hits
    if len(hits) >= LOGIN_MAX_MIN:
        return False
    hits.append(now)
    return True


@router.post("/auth/login", response_model=LoginOut)
def login(body: LoginIn, request: Request, db: Session = Depends(get_db)):
    # Demo piloto: user_id de seed (s1-s4, i1). Sin passwords (ver app/auth.py).
    if not _login_allowed(request.client.host if request.client else "?"):
        raise HTTPException(429, "demasiados intentos, espera un minuto")
    user = db.query(models.User).filter_by(id=body.user_id, active=1).first()
    if not user:
        raise HTTPException(401, "usuario desconocido")
    return {"token": new_token(db, user.id), "role": user.role, "user_id": user.id}


@router.delete("/auth/logout")
def logout(creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
           user=Depends(current_user), db: Session = Depends(get_db)):
    if creds:
        revoke_token(db, creds.credentials)
    return {"status": "bye"}


@router.get("/auth/me", response_model=MeOut)
def me(user=Depends(current_user)):
    return {"user_id": user.id, "role": user.role, "display_name": user.display_name}
