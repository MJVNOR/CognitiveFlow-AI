"""Distribuciones y serie sintéticas con drift plantado (etiquetado simulación)."""
import random

FEATURES = ["temp", "pressure", "vibration"]
N_BINS = 12


def _hist(values: list[float], lo: float, hi: float) -> list[int]:
    bins = [0] * N_BINS
    for v in values:
        i = min(N_BINS - 1, max(0, int((v - lo) / (hi - lo) * N_BINS)))
        bins[i] += 1
    return bins


def generate(seed: int = 1, n: int = 200) -> dict:
    """Solo 'temp' deriva (+6 media desde índice 120 de la serie). Retorna verdad solo-backend."""
    rnd = random.Random(seed)
    ref = {f: [rnd.gauss(70 if f == "temp" else 50, 5) for _ in range(n)] for f in FEATURES}
    cur = {f: list(v) for f, v in ref.items()}
    drift_n = 60
    cur["temp"] = cur["temp"][:-drift_n] + [rnd.gauss(76, 5) for _ in range(drift_n)]
    series = [rnd.gauss(70, 3) for _ in range(120)] + [rnd.gauss(76, 3) for _ in range(60)]
    lo, hi = 40.0, 100.0
    return {
        "features": {
            f: {"bins": [round(lo + (hi - lo) * (i + 0.5) / N_BINS, 1) for i in range(N_BINS)],
                  "ref": _hist(ref[f], lo, hi), "cur": _hist(cur[f], lo, hi)}
            for f in FEATURES
        },
        "series": [round(v, 1) for v in series],
        "truth": {"drifted_feature": "temp", "changepoint": 120, "kind": "data_drift"},
    }
