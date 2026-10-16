"""Auth demo: login por user_id + token opaco en DB.

ponytail: sin passwords ni JWT; solo piloto con credenciales demo no productivas.
P7.1: tokens con TTL 12h + logout; sin rotación forzada (rompería sesiones del piloto).
Upgrade path: hash robusto + refresh cuando salga del piloto.
"""
import secrets
import time

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app import models
from app.db import get_db

_bearer = HTTPBearer(auto_error=False)

TOKEN_TTL_S = 12 * 3600  # P7.1: expiración demo (12h); 0 en created_at = heredado sin TTL


def current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
):
    if not creds:
        raise HTTPException(401, "falta token")
    tok = db.query(models.AuthToken).filter_by(token=creds.credentials).first()
    if not tok:
        raise HTTPException(401, "token inválido")
    if tok.created_at and time.time() - tok.created_at > TOKEN_TTL_S:
        raise HTTPException(401, "token expirado")
    user = db.query(models.User).filter_by(id=tok.user_id).first()
    if not user or not user.active:
        raise HTTPException(401, "usuario inactivo")
    return user


def require_instructor(user=Depends(current_user)):
    if user.role != "instructor":
        raise HTTPException(403, "solo instructor")
    return user


def session_for(user, db: Session, session_id: str):
    s = db.query(models.LearningSession).filter_by(id=session_id).first()
    if not s:
        raise HTTPException(404, "session not found")
    if user.role != "instructor" and s.student_id != user.id:
        raise HTTPException(403, "sesión de otro estudiante")
    return s


def new_token(db: Session, user_id: str) -> str:
    tok = secrets.token_hex(16)
    db.add(models.AuthToken(token=tok, user_id=user_id, created_at=int(time.time())))
    db.commit()
    return tok


def revoke_token(db: Session, token: str) -> bool:
    tok = db.query(models.AuthToken).filter_by(token=token).first()
    if not tok:
        return False
    db.delete(tok)
    db.commit()
    return True
