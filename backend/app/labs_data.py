"""Dataset sintético determinista para Data Detective (etiquetado simulación)."""
import random

COLUMNS = ["id", "temp", "unit", "pressure", "line"]


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
    # 1. faltantes (2 celdas)
    for rid in (3, 17):
        rows[rid]["pressure"] = None
        planted.add(rid)
    # 2. duplicado exacto de la fila 5 en la 12
    rows[12] = dict(rows[5], id=12)
    planted.add(12)
    # 3. unidades mezcladas: temp en F en filas 7, 21
    for rid in (7, 21):
        rows[rid]["temp"] = round(rows[rid]["temp"] * 9 / 5 + 32, 1)
        rows[rid]["unit"] = "F"
        planted.add(rid)
    # 4. outlier físico: presión imposible en fila 25
    rows[25]["pressure"] = 999.9
    planted.add(25)
    # 5. fuga: columna futura filtrada como pista en fila 2 (valor imposible de saber)
    rows[2]["temp"] = -273.2
    planted.add(2)
    return {"columns": COLUMNS, "rows": rows, "planted": sorted(planted)}
