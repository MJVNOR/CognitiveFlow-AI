// ML · "Dos plumas" — un trazador plano dibuja dos curvas sobre el papel:
// entrenamiento (baja y se aplana) y validación (baja y vuelve a subir). La
// separación final es el sobreajuste; el mando de la brida mueve la complejidad.
import * as k from "../kit/iso-kit.mjs";
import { bench } from "../kit/bench.mjs";
import { figure } from "../kit/figure.mjs";

const PLATE = { x: -76, y: -24, w: 152, d: 48, r: 7 };
const PAPER = { x: -58, y: -19, w: 94, d: 42 };
const RAIL_Y = [-22, 22];
const BEAM_X = 30;

figure({
  id: "ml-plotter",
  title: "Dos plumas, dos curvas",
  extent: k.boxCorners(PLATE, -13, 26),
  readout: "entrenamiento baja · validación se separa",
  keys: [
    { mark: "lit", label: "Validación: vuelve a subir al final" },
    { mark: "raised", label: "Entrenamiento: baja y se aplana" },
  ],
  caption:
    "Las dos plumas dibujan a la vez: la de entrenamiento baja y se aplana, la de validación baja un rato y vuelve a subir. Ese hueco final es el sobreajuste: el modelo aprende de memoria los datos que ya vio.",
  label:
    "Un trazador plano sobre un banco, con el papel cuadriculado sujeto a la mesa, una brida con dos plumas apoyadas en el papel y un mando estriado. En el papel hay dos curvas: una que baja y se aplana y otra que baja y vuelve a subir al final.",
  scene({ P, S, L, D }) {
    const out = [bench(P, PLATE, { grooveY: [-16] })];

    // --- papel cuadriculado -------------------------------------------------
    out.push(S(k.slabOf(PAPER, 0, 0.7, P, 4, 0.2), { tone: "lo", crease: "none" }));
    out.push(L(k.planOutline(PAPER, 0.7, P), { tone: "lo" }));
    // Marco del gráfico: dentro del papel, con la cuadrícula de borde a borde.
    const FRAME = { x: PAPER.x + 10, y: PAPER.y + 6, w: PAPER.w - 20, d: PAPER.d - 12, r: 0 };
    out.push(L(k.planOutline(FRAME, 0.7, P), { tone: "lo" }));
    const grid = [];
    for (let x = FRAME.x + 8; x < FRAME.x + FRAME.w - 1; x += 8) {
      grid.push(k.lineOnTop([x, FRAME.y], [x, FRAME.y + FRAME.d], 0.7, P));
    }
    for (let y = FRAME.y + 8; y < FRAME.y + FRAME.d - 1; y += 8) {
      grid.push(k.lineOnTop([FRAME.x, y], [FRAME.x + FRAME.w, y], 0.7, P));
    }
    out.push(L(grid.join(""), { tone: "faint" }));

    // --- las dos curvas: error frente a complejidad ------------------------
    const curve = (errorAt) => {
      const points = [];
      const N = 26;
      for (let i = 0; i <= N; i++) {
        const t = i / N;
        points.push([-46 + t * 76, -2 - errorAt(t) * 1.45]);
      }
      return k.onTop(points, 1, P);
    };
    const trainError = (t) => 1 + 8 * Math.exp(-t * 3.1);
    const valError = (t) => 1.4 + 7.4 * Math.exp(-t * 2.4) + 9 * Math.pow(t, 3.2);
    out.push(L(curve(trainError), { tone: "mid", className: "iso-trace" }));
    out.push(L(curve(valError), { tone: "hi", className: "iso-trace" }));
    // Marcas de los puntos medidos, sobre la curva de validación.
    out.push(D(Array.from({ length: 7 }, (_, i) => {
      const t = i / 6;
      return k.iso([-46 + t * 76, -2 - valError(t) * 1.45, 1], P);
    }), { size: 0.45, tone: "hi" }));

    // --- brida con dos plumas ----------------------------------------------
    for (const y of RAIL_Y) {
      out.push(S(k.slabOf({ x: PAPER.x - 2, y: y - 2, w: PAPER.w + 8, d: 4, r: 1 }, 0.7, 2.6, P, 4, 0.4), { tone: "mid" }));
    }
    for (const y of RAIL_Y) {
      out.push(S(k.slabOf({ x: BEAM_X - 5, y: y - 5, w: 10, d: 10, r: 1.6 }, 3.3, 15, P, 4, 0.5), { tone: "mid" }));
    }
    out.push(S(k.slabOf({ x: BEAM_X - 3.5, y: -24, w: 7, d: 48, r: 1.6 }, 18.3, 4, P, 5, 0.5), { tone: "mid" }));
    out.push(D([k.iso([BEAM_X, -18, 22.3], P), k.iso([BEAM_X, 18, 22.3], P)], { size: 0.45 }));
    // Cabezal con las dos plumas, cada una sobre su curva.
    out.push(S(k.slabOf({ x: BEAM_X - 4, y: -2, w: 8, d: 10, r: 1.4 }, 13, 5.3, P, 4, 0.5), { tone: "mid" }));
    for (const [py, tone] of [[-2 - (1 + 8 * Math.exp(-0.87 * 3.1)) * 1.45, "mid"], [-2 - (1.4 + 7.4 * Math.exp(-0.87 * 2.4) + 9 * Math.pow(0.87, 3.2)) * 1.45, "lit"]]) {
      out.push(S(k.cylinder(BEAM_X, py, 1.4, 0.7, 12.3, P, 16), { tone: tone === "lit" ? "hi" : "hi", lit: tone === "lit", crease: "none" }));
      out.push(S(k.cylinder(BEAM_X, py, 2.2, 12, 1.6, P, 16), { tone: "mid" }));
    }
    // Mando de la brida: mueve la complejidad del modelo.
    out.push(S(k.cylinder(BEAM_X, 14, 5, 22.3, 3, P, 28), { tone: "mid" }));
    out.push(S(k.cylinder(BEAM_X, 14, 5, 25.3, 3, P, 28), { tone: "mid" }));
    out.push(L(k.knurl(BEAM_X, 14, 5, 25.3, 28.3, 30, P, 0), { tone: "lo" }));
    out.push(S(k.cylinder(BEAM_X, 14, 4.2, 28.3, 1.6, P, 24), { tone: "mid" }));
    out.push(L(k.lineOnTop([BEAM_X - 4.2, 14], [BEAM_X + 4.2, 14], 29.9, P), { tone: "hi" }));

    return out.join("");
  },
});
