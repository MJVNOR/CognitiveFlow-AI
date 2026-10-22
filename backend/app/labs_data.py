"""Dataset sintético determinista para Data Detective (etiquetado simulación)."""
import random

COLUMNS = ["id", "temp", "unit", "pressure", "line"]

# Semilla 1 = práctica: posiciones fijas (sesiones guardadas y tests dependen de ellas).
_PRACTICE_IDS = {"missing": (3, 17), "dup": (5, 12), "unit": (7, 21), "outlier": 25, "leak": 2}


def _planted_ids(seed: int, n: int, rnd: random.Random) -> dict:
    """Otras semillas (postest, transferencia): mismos 5 problemas en filas nuevas,
    para que la variante no se resuelva memorizando ids."""
    if seed == 1:
        return _PRACTICE_IDS
    a, b, src, dst, u1, u2, o, leak = rnd.sample(range(n), 8)
    return {"missing": (a, b), "dup": (src, dst), "unit": (u1, u2), "outlier": o, "leak": leak}


def generate(seed: int = 1, n: int = 30) -> dict:
    """30 filas con 5 problemas plantados. Retorna filas + ids anómalos (solo backend)."""
    rnd = random.Random(seed)
    rows, planted = [], set()
    for i in range(n):
        row = {
            "id": i,
            "temp": round(rnd.uniform(18.0, 25.0), 1),
            "unit": "C",
            "pressure": round(rnd.uniform(100.0, 110.0), 1),
            "line": rnd.choice(["A", "B"]),
        }
        rows.append(row)
    ids = _planted_ids(seed, n, rnd)
    # 1. faltantes (2 celdas)
    for rid in ids["missing"]:
        rows[rid]["pressure"] = None
        planted.add(rid)
    # 2. duplicado exacto de una fila normal
    src, dst = ids["dup"]
    rows[dst] = dict(rows[src], id=dst)
    planted.add(dst)
    # 3. unidades mezcladas: temp en F
    for rid in ids["unit"]:
        rows[rid]["temp"] = round(rows[rid]["temp"] * 9 / 5 + 32, 1)
        rows[rid]["unit"] = "F"
        planted.add(rid)
    # 4. outlier físico: presión imposible
    rows[ids["outlier"]]["pressure"] = 999.9
    planted.add(ids["outlier"])
    # 5. fuga: columna futura filtrada como pista (valor imposible de saber)
    rows[ids["leak"]]["temp"] = -273.2
    planted.add(ids["leak"])
    return {"columns": COLUMNS, "rows": rows, "planted": sorted(planted)}
