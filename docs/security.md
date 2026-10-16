# Seguridad y persistencia (P7.1–P7.2)

## Tokens (demo, no producción)

- Opacos en tabla `auth_tokens`, TTL 12h (`created_at`), `DELETE /auth/logout`.
- Sin rotación forzada ni refresh; al salir del piloto: hash + refresh.
- Filas viejas con `created_at=0` no expiran (compat); `ensure_columns()` añade
  la columna a DBs existentes sin borrar datos.

## Login

- Rate limit 10/min por IP (memoria local, 1 worker). Detrás de proxy real,
  tomar IP de `X-Forwarded-For` y/o subir a Redis.
- Sin passwords por diseño del piloto (`s1-s4`, `i1`).

## Payload y costo

- `answer_text` ≤ 6000, reflexión/notas ≤ 2000 (422 si excede).
- Jev: 1 crédito/llamada, reintento solo en transitorios; Gemini: 2 llamadas/turno
  socrático (pregunta + feedback). Sin keys ⇒ mock/pending, cero gasto.

## Backup y DB

- SQLite archivo (`DATABASE_URL`). Backup: `GET /instructor/backup` (solo
  instructor) o copiar el `.db` con la API apagada (en Windows el archivo se
  bloquea mientras un servidor lo tiene abierto).
- `Base.metadata.create_all` no migra tablas existentes: solo **añadir** tablas/
  columnas (`ensure_columns`); un cambio de columna exige borrar `.db*` + `seed`.
- CORS por `CORS_ORIGINS`; HTTPS y cabeceras duras en el deploy (P7.4), no aquí.
