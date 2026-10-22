"""Distribuciones y serie sintéticas con drift plantado (etiquetado simulación)."""
import random

FEATURES = ["temp", "pressure", "vibration"]
N_BINS = 12
SERIES_N = 180
_BASE = {"temp": 70, "pressure": 50, "vibration": 50}


def _hist(values: list[float], lo: float, hi: float) -> list[int]:
    bins = [0] * N_BINS
    for v in values:
        i = min(N_BINS - 1, max(0, int((v - lo) / (hi - lo) * N_BINS)))
        bins[i] += 1
    return bins


def generate(seed: int = 1, n: int = 200) -> dict:
    """Una feature deriva desde un punto de cambio. Semilla 1 (práctica): 'temp'
    +6 desde t=120 (fijo: sesiones y tests dependen de ello). Otras semillas
    (postest): otra feature, otro punto y otro sentido. Verdad solo-backend."""
    rnd = random.Random(seed)
    if seed == 1:
        feat, cp, shift = "temp", 120, 6
    else:
        feat, cp, shift = rnd.choice(FEATURES), rnd.randint(60, 150), rnd.choice([-7, -6, 6, 7])
    ref = {f: [rnd.gauss(_BASE[f], 5) for _ in range(n)] for f in FEATURES}
    cur = {f: list(v) for f, v in ref.items()}
    drift_n = 60
    cur[feat] = cur[feat][:-drift_n] + [rnd.gauss(_BASE[feat] + shift, 5) for _ in range(drift_n)]
    series = ([rnd.gauss(_BASE[feat], 3) for _ in range(cp)]
              + [rnd.gauss(_BASE[feat] + shift, 3) for _ in range(SERIES_N - cp)])
    by_feature = {f: series if f == feat else [rnd.gauss(_BASE[f], 3) for _ in range(SERIES_N)]
                  for f in FEATURES}
    lo, hi = 40.0, 100.0
    return {
        "features": {
            f: {"bins": [round(lo + (hi - lo) * (i + 0.5) / N_BINS, 1) for i in range(N_BINS)],
                  "ref": _hist(ref[f], lo, hi), "cur": _hist(cur[f], lo, hi)}
            for f in FEATURES
        },
        # "series" = la serie de la feature que deriva (contrato previo); por feature, aditivo.
        "series": [round(v, 1) for v in series],
        "series_by_feature": {f: [round(v, 1) for v in s] for f, s in by_feature.items()},
        "truth": {"drifted_feature": feat, "changepoint": cp, "kind": "data_drift"},
    }
