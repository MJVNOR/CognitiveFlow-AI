"""Auth demo: login por user_id + token opaco en DB.

ponytail: sin passwords ni JWT; solo piloto con credenciales demo no productivas.
Upgrade path: hash robusto + expiración cuando salga del piloto.
"""
import secrets

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app import models
from app.db import get_db

_bearer = HTTPBearer(auto_error=False)


def current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
):
    if not creds:
        raise HTTPException(401, "falta token")
    tok = db.query(models.AuthToken).filter_by(token=creds.credentials).first()
    if not tok:
        raise HTTPException(401, "token inválido")
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
    db.add(models.AuthToken(token=tok, user_id=user_id))
    db.commit()
    return tok
