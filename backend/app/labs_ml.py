"""Curva sintética determinista — etiquetada como simulación, no entrenamiento real."""
import random


def ml_curve(complexity: int, noise_pct: int, seed: int = 1):
    # ponytail: fórmula cerrada + jitter con seed, reproducible por diseño
    rnd = random.Random(seed * 1000 + complexity * 100 + noise_pct)
    jitter = [rnd.uniform(-0.02, 0.02) for _ in range(10)]
    train, val = [], []
    for epoch in range(10):
        t = 0.9 / (1 + epoch * 0.35 + complexity * 0.12)
        t += noise_pct / 1000.0 + jitter[epoch] * 0.3
        overfit = max(0, complexity - 4) ** 1.6 * 0.02 * (epoch / 9)
        v = t + overfit + noise_pct / 500.0
        train.append(round(max(0.02, t), 4))
        val.append(round(max(0.02, v), 4))
    return {"train": train, "val": val, "simulated": True}
