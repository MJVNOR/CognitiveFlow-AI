// D02 · "El molde y la pieza" — imagen (molde que se reutiliza) frente a
// contenedor (pieza que sale y se va). Un molde montado en el banco, una pieza
// recién sacada sobre la mesa y una caja con las piezas de ciclos anteriores.
import * as k from "../kit/iso-kit.mjs";
import { bench } from "../kit/bench.mjs";
import { figure } from "../kit/figure.mjs";

const PLATE = { x: -72, y: -22, w: 144, d: 44, r: 7 };
const MOULD_X = -42;
const BIN = { x: 20, y: -16, w: 28, d: 30 };

figure({
  id: "d02-mould",
  title: "El molde y la pieza",
  extent: k.boxCorners(PLATE, -13, 42),
  readout: "1 molde · 3 piezas",
  keys: [
    { mark: "lit", label: "Piezas: cada una sale del molde y se va" },
    { mark: "raised", label: "Molde montado: se cierra y se reutiliza" },
  ],
  caption:
    "El molde queda montado y vuelve a cerrarse igual en cada ciclo; la pieza sale, se usa y se descarta. La imagen es el molde; el contenedor es la pieza.",
  label:
    "Un molde de dos placas montado en un banco, con su husillo y cuatro columnas. Una pieza recién colada descansa sobre el banco y otras dos están en una caja: el molde se reutiliza, las piezas se van.",
  scene({ P, S, L, D }) {
    const out = [bench(P, PLATE, { grooveY: [-16] })];

    // --- la pieza: cuerpo, rebaba y mazarota ---------------------------------
    const castPart = (cx, cy, z0, size = 1) => {
      const w = 16 * size;
      const d = 12 * size;
      const body = { x: cx - w / 2, y: cy - d / 2, w, d, r: 1 };
      const boss = { x: cx - w * 0.3, y: cy - d * 0.3, w: w * 0.6, d: d * 0.6, r: 0.9 };
      out.push(S(k.slabOf(body, z0, 8 * size, P, 5, 0.6), { tone: "hi", lit: true, crease: "lo" }));
      out.push(S(k.slabOf(boss, z0 + 8 * size, 3 * size, P, 4, 0.5), { tone: "hi", lit: true }));
      out.push(L(k.planOutline(k.insetPlan(boss, 0.9), z0 + 11 * size, P), { tone: "faint" }));
      out.push(D([k.iso([boss.x + 1.6, boss.y + 1.6, z0 + 11 * size], P), k.iso([boss.x + boss.w - 1.6, boss.y + 1.6, z0 + 11 * size], P)], { size: 0.4 }));
    };

    // --- el molde: caja con impresión, tapa, columnas y husillo --------------
    const x = MOULD_X;
    const drag = { x: x - 21, y: -15, w: 42, d: 30, r: 2 };
    out.push(S(k.slabOf(drag, 0, 9, P, 6, 0.8), { tone: "mid" }));
    out.push(L(k.planOutline(k.insetPlan(drag, 2), 9, P), { tone: "faint" }));
    // Paredes de la impresión: dejan un hueco en el centro.
    const wall = 4.5;
    for (const side of [
      { x: x - 15.5, y: -11, w: 31, d: wall },
      { x: x - 15.5, y: 11 - wall, w: 31, d: wall },
      { x: x - 15.5, y: -11, w: wall, d: 22 },
      { x: x + 15.5 - wall, y: -11, w: wall, d: 22 },
    ]) {
      out.push(S(k.slabOf({ ...side, r: 0.8 }, 9, 7, P, 4, 0.5), { tone: "mid" }));
    }
    // La impresión queda vacía: la pieza acaba de salir.
    out.push(L(k.planOutline({ x: x - 16, y: -11.5, w: 32, d: 23, r: 1 }, 16, P), { tone: "lo" }));
    // Columna y tapa: el molde cerrado encima.
    const cope = { x: x - 21, y: -15, w: 42, d: 30, r: 2 };
    for (const [px, py] of [[x - 17, -11], [x + 17, -11], [x - 17, 11], [x + 17, 11]]) {
      out.push(S(k.cylinder(px, py, 2.4, 0, 30, P, 20), { tone: "mid", crease: "none" }));
      out.push(S(k.cylinder(px, py, 3.6, 26, 2, P, 20), { tone: "mid" }));
    }
    out.push(S(k.slabOf(cope, 30, 7, P, 6, 0.8), { tone: "mid" }));
    out.push(L(k.planOutline(k.insetPlan(cope, 2), 37, P), { tone: "faint" }));
    out.push(D([k.iso([cope.x + 4, cope.y + 4, 37], P), k.iso([cope.x + cope.w - 4, cope.y + 4, 37], P)], { size: 0.45 }));
    // Husillo de cierre con su volante estriado.
    out.push(S(k.cylinder(x, 0, 4.6, 37, 4, P, 24), { tone: "mid" }));
    out.push(S(k.cylinder(x, 0, 4.2, 41, 2.4, P, 24), { tone: "mid" }));
    out.push(S(k.cylinder(x, 0, 7.6, 43.4, 3.4, P, 36), { tone: "hi", crease: "lo" }));
    out.push(L(k.knurl(x, 0, 7.6, 43.4, 46.8, 40, P, 0), { tone: "lo" }));
    out.push(L(k.sideArc(x, 0, 7.6, 43.4, P, 32), { tone: "faint" }));
    out.push(L(k.lineOnTop([x - 7.6, 0], [x + 7.6, 0], 46.8, P), { tone: "mid" }));

    // --- la pieza ya sacada, sobre el banco --------------------------------
    castPart(-4, 4, 0);

    // --- caja con las piezas de ciclos anteriores --------------------------
    out.push(S(k.slabOf(BIN, 0, 3, P, 4, 0.4), { tone: "mid" }));
    for (const side of [
      { x: BIN.x, y: BIN.y, w: BIN.w, d: 2.5 },
      { x: BIN.x, y: BIN.y + BIN.d - 2.5, w: BIN.w, d: 2.5 },
      { x: BIN.x, y: BIN.y, w: 2.5, d: BIN.d },
      { x: BIN.x + BIN.w - 2.5, y: BIN.y, w: 2.5, d: BIN.d },
    ]) {
      out.push(S(k.slabOf({ ...side, r: 0.6 }, 3, 8, P, 3, 0.4), { tone: "mid" }));
    }
    castPart(BIN.x + 9, BIN.y + 9, 3, 0.62);
    castPart(BIN.x + 21, BIN.y + 19, 3, 0.62);
    out.push(L(k.planOutline(k.insetPlan(BIN, 3.4), 3, P), { tone: "faint" }));

    return out.join("");
  },
});
