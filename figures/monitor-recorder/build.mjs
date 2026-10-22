// Monitoring · "Registrador de cinta" — un registrador de dos plumas: una
// deriva despacio (feature drift) y la otra pega un escalón (changepoint).
import * as k from "../kit/iso-kit.mjs";
import * as G from "../kit/lathe.mjs";
import { bench } from "../kit/bench.mjs";
import { figure } from "../kit/figure.mjs";

const PLATE = { x: -72, y: -23, w: 144, d: 46, r: 7 };
const CASE = { x: -40, y: -14, w: 62, d: 30, r: 3 };
const CASE_Z = 16;
const STRIP = { x: -37, y: -11, w: 56, d: 24, r: 1 };
const STRIP_Z = CASE_Z + 0.8;
const BEAM_X = 12;

figure({
  id: "monitor-recorder",
  title: "Dos plumas en la cinta",
  extent: k.boxCorners(PLATE, -13, 34),
  readout: "una deriva · un escalón",
  keys: [
    { mark: "lit", label: "Escalón: la señal cambia de golpe" },
    { mark: "raised", label: "Deriva: la señal se va poco a poco" },
  ],
  caption:
    "Las dos plumas escriben a la vez sobre la misma cinta: una deriva despacio, sin que la métrica de negocio se mueva; la otra pega un escalón de golpe. Son dos problemas distintos y se detectan de forma distinta.",
  label:
    "Un registrador de cinta sobre un banco: una caja con el rollo de papel detrás, la cinta sobre la tapa y una brida con dos plumas. En la cinta, una traza baja despacio y la otra da un escalón y sigue plana.",
  scene({ P, S, L, D }) {
    const out = [bench(P, PLATE, { grooveY: [-16] })];

    // --- rollo de papel detrás y su soporte ---------------------------------
    const roll = G.frameAlong([CASE.x + 4, -20, 9], [1, 0, 0]);
    out.push(S(G.solidOf([[0, 6.4], [54, 6.4]], roll, P), { tone: "mid", crease: "lo" }));
    out.push(S(G.disc(2, 3.4, 7, roll, P), { tone: "mid" }));
    out.push(S(G.disc(50.6, 52, 7, roll, P), { tone: "mid" }));
    out.push(L(G.arcOf(roll, 27, 6.4, P), { tone: "faint" }));
    for (const [bx, by] of [[CASE.x + 4, -20], [CASE.x + 58, -20]]) {
      out.push(S(k.slabOf({ x: bx - 2.5, y: by - 4, w: 5, d: 8, r: 1 }, 0, 9, P, 3, 0.4), { tone: "mid" }));
    }
    // La cinta pasa por encima de la tapa.
    out.push(S(k.slabOf({ x: STRIP.x, y: -22, w: STRIP.w, d: 13, r: 1 }, CASE_Z - 0.6, 0.8, P, 4, 0.2), { tone: "lo", crease: "none" }));

    // --- caja del registrador ----------------------------------------------
    out.push(S(k.slabOf(CASE, 0, CASE_Z, P, 6, 1), { tone: "mid" }));
    out.push(L(k.planOutline(k.insetPlan(CASE, 2), CASE_Z, P), { tone: "faint" }));
    out.push(D(k.corners(CASE, 4).map(([x, y]) => k.iso([x, y, CASE_Z], P)), { size: 0.45 }));
    // Tapa con la cinta encima y su ventana.
    out.push(S(k.slabOf(STRIP, CASE_Z, 0.8, P, 4, 0.2), { tone: "lo", crease: "none" }));
    out.push(L(k.planOutline(STRIP, STRIP_Z, P), { tone: "lo" }));
    // Mando de avance y piloto.
    out.push(S(k.cylinder(CASE.x + CASE.w + 6, 4, 5, 0, 3, P, 28), { tone: "mid" }));
    out.push(S(k.cylinder(CASE.x + CASE.w + 6, 4, 4.2, 3, 2.6, P, 24), { tone: "mid" }));
    out.push(L(k.knurl(CASE.x + CASE.w + 6, 4, 4.2, 3, 5.6, 28, P, 0), { tone: "lo" }));
    out.push(L(k.lineOnTop([CASE.x + CASE.w + 2.6, 4], [CASE.x + CASE.w + 9.4, 4], 5.6, P), { tone: "hi" }));
    out.push(S(k.cylinder(CASE.x + CASE.w + 6, -4, 2.6, 0, 1.4, P, 20), { tone: "mid" }));

    // --- las dos trazas sobre la cinta -------------------------------------
    const trace = (valueAt, tone, extra = "") => {
      const points = [];
      const N = 40;
      for (let i = 0; i <= N; i++) {
        const t = i / N;
        points.push([STRIP.x + 2 + t * (STRIP.w - 4), valueAt(t)]);
      }
      return k.onTop(points, STRIP_Z + 0.05 + extra, P);
    };
    // Deriva: baja despacio, sin escalón.
    const drift = (t) => -4 + 8 * t + 0.5 * Math.sin(t * 9);
    // Escalón: plana hasta la mitad y luego salta.
    const step = (t) => (t < 0.55 ? 2.5 + 0.25 * Math.sin(t * 12) : -3.5 + 0.25 * Math.sin(t * 12));
    out.push(L(trace(drift, "faint"), { tone: "mid", className: "iso-trace" }));
    out.push(L(trace(step), { tone: "hi", className: "iso-trace" }));

    // --- brida con las dos plumas ------------------------------------------
    out.push(S(k.slabOf({ x: STRIP.x - 2, y: STRIP.y - 3, w: STRIP.w + 4, d: 3, r: 1 }, STRIP_Z, 2, P, 3, 0.3), { tone: "mid" }));
    out.push(S(k.slabOf({ x: STRIP.x - 2, y: STRIP.y + STRIP.d, w: STRIP.w + 4, d: 3, r: 1 }, STRIP_Z, 2, P, 3, 0.3), { tone: "mid" }));
    for (const y of [STRIP.y - 2, STRIP.y + STRIP.d + 1]) {
      out.push(S(k.slabOf({ x: BEAM_X - 5, y: y - 3, w: 10, d: 6, r: 1.4 }, STRIP_Z + 2, 10, P, 4, 0.4), { tone: "mid" }));
    }
    out.push(S(k.slabOf({ x: BEAM_X - 3, y: STRIP.y - 5, w: 6, d: STRIP.d + 10, r: 1.4 }, STRIP_Z + 12, 3.6, P, 4, 0.4), { tone: "mid" }));
    out.push(D([k.iso([BEAM_X, STRIP.y - 4, STRIP_Z + 15.6], P), k.iso([BEAM_X, STRIP.y + STRIP.d + 4, STRIP_Z + 15.6], P)], { size: 0.4 }));
    // Cada pluma apoyada en su traza.
    for (const [py, lit] of [[drift(0.92), false], [step(0.92), true]]) {
      out.push(S(k.cylinder(BEAM_X, py, 1.3, STRIP_Z + 0.1, 11.9, P, 16), { tone: "hi", lit, crease: "none" }));
      out.push(S(k.cylinder(BEAM_X, py, 2.1, STRIP_Z + 11, 1.4, P, 16), { tone: "mid" }));
    }

    return out.join("");
  },
});
