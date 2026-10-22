// D04 · "Capas y caché" — una pila de placas bajo una brida: las de abajo ya
// están hechas y se reutilizan; la de arriba (la que cambia) se vuelve a
// construir. A la derecha, la misma terna de capas guardada en una bandeja.
import * as k from "../kit/iso-kit.mjs";
import { bench } from "../kit/bench.mjs";
import { figure } from "../kit/figure.mjs";

const PLATE = { x: -74, y: -22, w: 148, d: 44, r: 7 };
const STACK_X = -36;
const TRAY = { x: 18, y: -15, w: 42, d: 30 };

figure({
  id: "d04-layers",
  title: "Capas y caché",
  extent: k.boxCorners(PLATE, -13, 30),
  readout: "3 capas reutilizadas · 1 reconstruida",
  keys: [
    { mark: "lit", label: "La capa que cambia: se vuelve a construir" },
    { mark: "raised", label: "Capas de abajo: ya hechas, se reutilizan" },
  ],
  caption:
    "Las capas de abajo ya están hechas y se reutilizan tal cual. Solo la capa que cambia se reconstruye: por eso el COPY del código va al final del Dockerfile.",
  label:
    "Una pila de placas de acero bajo una brida: las tres de abajo descansan ya montadas y la cuarta, la de arriba, es la única marcada. A la derecha, las tres capas de abajo se guardan en una bandeja para reutilizarlas.",
  // La capa de arriba se levanta y vuelve a apoyarse: es la única que se rehace.
  live: `
function pose(t) {
  const lift = 9 * (0.5 - 0.5 * Math.cos(t * Math.PI * 2));
  part("toplayer").setAttribute("transform", mov(0, 0, lift));
}
`,
  scene({ P, S, L, D }) {
    const out = [bench(P, PLATE, { grooveY: [-16] })];

    // --- pila de capas bajo la brida ---------------------------------------
    const x = STACK_X;
    const base = { x: x - 23, y: -15, w: 46, d: 30, r: 2 };
    out.push(S(k.slabOf(base, 0, 4, P, 5, 0.6), { tone: "mid" }));
    out.push(L(k.planOutline(k.insetPlan(base, 1.8), 4, P), { tone: "faint" }));
    for (const [bx, bd] of [[x - 20, -12], [x + 10, 12]]) {
      out.push(D([k.iso([bx, bd, 4], P)], { size: 0.45 }));
    }
    // Altura de la pila: tres capas reutilizadas más la que cambia.
    const layers = [7, 4, 6];
    const topZ = 4 + layers.reduce((sum, thick) => sum + thick, 0) + 4;
    // Brida al fondo: montantes y barra con su tornillo. Va antes que la pila
    // porque está detrás y la pila la tapa por delante.
    for (const px of [x - 23, x + 18]) {
      out.push(S(k.slabOf({ x: px, y: -19, w: 5, d: 6, r: 1.2 }, 4, topZ + 6 - 4, P, 4, 0.5), { tone: "mid" }));
      out.push(D([k.iso([px + 2.5, -16, topZ + 6], P)], { size: 0.4 }));
    }
    out.push(S(k.slabOf({ x: x - 23, y: -19, w: 46, d: 7, r: 1.6 }, topZ + 6, 4, P, 5, 0.6), { tone: "mid" }));
    out.push(S(k.cylinder(x, -15.5, 3.4, topZ + 10, 2.6, P, 24), { tone: "mid" }));
    out.push(L(k.knurl(x, -15.5, 3.4, topZ + 10, topZ + 12.6, 22, P, 0), { tone: "lo" }));
    out.push(L(k.ring(x, -15.5, 5, topZ + 6, P, 28), { tone: "faint" }));

    // Las tres capas reutilizadas (mismo grosor que en la bandeja).
    let z = 4;
    for (const thick of layers) {
      out.push(S(k.slabOf({ x: x - 17, y: -12, w: 34, d: 24, r: 1 }, z, thick, P, 5, 0.5), { tone: "hi", crease: "lo" }));
      z += thick;
    }
    // La capa que cambia, marcada: se levanta para que se vea que se rehace.
    out.push(
      `<g data-part="toplayer">${S(k.slabOf({ x: x - 17, y: -12, w: 34, d: 24, r: 1 }, z, 4, P, 5, 0.5), { tone: "hi", lit: true, crease: "lo" })}${L(k.planOutline(k.insetPlan({ x: x - 17, y: -12, w: 34, d: 24, r: 1 }, 2.4), z + 4, P), { tone: "faint" })}</g>`,
    );
    z += 4;
    // --- bandeja con la terna reutilizada ---------------------------------
    const tray = TRAY;
    out.push(S(k.slabOf(tray, 0, 3, P, 4, 0.4), { tone: "mid" }));
    for (const side of [
      { x: tray.x, y: tray.y, w: tray.w, d: 2.5 },
      { x: tray.x, y: tray.y + tray.d - 2.5, w: tray.w, d: 2.5 },
      { x: tray.x, y: tray.y, w: 2.5, d: tray.d },
      { x: tray.x + tray.w - 2.5, y: tray.y, w: 2.5, d: tray.d },
    ]) {
      out.push(S(k.slabOf({ ...side, r: 0.6 }, 3, 7, P, 3, 0.4), { tone: "mid" }));
    }
    out.push(L(k.planOutline(k.insetPlan(tray, 3.4), 3, P), { tone: "faint" }));
    let tz = 3;
    for (const thick of layers) {
      out.push(S(k.slabOf({ x: tray.x + 8, y: tray.y + 9, w: 26, d: 12, r: 1 }, tz, thick, P, 5, 0.5), { tone: "hi", crease: "lo" }));
      tz += thick;
    }
    out.push(D([k.iso([tray.x + 4.6, tray.y + 4.6, 10], P), k.iso([tray.x + tray.w - 4.6, tray.y + tray.d - 4.6, 10], P)], { size: 0.4 }));

    return out.join("");
  },
});
