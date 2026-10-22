// ML · "Dos plumas" — un trazador plano dibuja dos curvas sobre el papel:
// entrenamiento (baja y se aplana) y validación (baja y vuelve a subir). La
// separación final es el sobreajuste.
//
// Movimiento: la brida avanza por los carriles en X y cada pluma se desliza en
// Y sobre la brida, así que cada pluma sigue su propia curva. Al final las
// curvas se desvanecen y la brida vuelve al origen: el bucle no da un salto.
import * as k from "../kit/iso-kit.mjs";
import { bench } from "../kit/bench.mjs";
import { figure } from "../kit/figure.mjs";

const PLATE = { x: -76, y: -24, w: 152, d: 48, r: 7 };
const PAPER = { x: -58, y: -19, w: 94, d: 42 };
const RAIL_Y = [-22, 22];
const BEAM_X = 30;
const X0 = -46;
const X1 = 30;

// Error frente a complejidad: baja y se aplana / baja y vuelve a subir.
const N = 26;
const XS = Array.from({ length: N + 1 }, (_, i) => X0 + (i / N) * (X1 - X0));
const ERR_TRAIN = Array.from({ length: N + 1 }, (_, i) => {
  const t = i / N;
  return 1 + 8 * Math.exp(-t * 3.1);
});
const ERR_VAL = Array.from({ length: N + 1 }, (_, i) => {
  const t = i / N;
  return 1.4 + 7.4 * Math.exp(-t * 2.4) + 9 * Math.pow(t, 3.2);
});
// El error se dibuja hacia el fondo del papel (y negativa).
const toY = (error) => -2 - error * 1.45;
const LAST = N;

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
    "Las dos plumas dibujan a la vez: la de entrenamiento baja y se aplana, la de validación baja un rato y vuelve a subir. Ese hueco final es el sobreajuste: el modelo se aprende los datos de memoria.",
  label:
    "Un trazador plano sobre un banco, con el papel cuadriculado sujeto a la mesa, una brida con dos plumas apoyadas en el papel y un mando estriado. En el papel hay dos curvas: una que baja y se aplana y otra que baja y vuelve a subir al final.",
  live: `
const XS = ${JSON.stringify(XS)};
const TRAIN = ${JSON.stringify(ERR_TRAIN.map(toY))};
const VAL = ${JSON.stringify(ERR_VAL.map(toY))};
const LAST = XS.length - 1;
const XEND = XS[LAST];
function pose(t) {
  // 0: hoja acabada (el cartel) · se desvanece · las plumas vuelven · dibuja.
  const FADE0 = 0.12, BACK1 = 0.26, DRAW0 = 0.3;
  let s = 1, fade = 1, back = 1;
  if (t < FADE0) {
    s = 1;
  } else if (t < BACK1) {
    const u = (t - FADE0) / (BACK1 - FADE0);
    fade = 1 - u;
    back = 1 - u;
  } else {
    const u = Math.max(0, (t - DRAW0) / (1 - DRAW0));
    s = 1 - Math.pow(1 - u, 3);
    back = s;
  }
  const i = Math.round(back * LAST);
  // La brida avanza por los carriles y cada pluma se desliza en Y.
  part("beam").setAttribute("transform", mov(XS[i] - XEND, 0, 0));
  part("penTrain").setAttribute("transform", mov(0, TRAIN[i] - TRAIN[LAST], 0));
  part("penVal").setAttribute("transform", mov(0, VAL[i] - VAL[LAST], 0));
  for (const trace of [part("train"), part("val")]) {
    trace.style.opacity = fade.toFixed(3);
    const path = trace.querySelector("path");
    const total = path.getTotalLength();
    path.style.strokeDasharray = total;
    path.style.strokeDashoffset = total * (1 - s);
  }
}
`,
  scene({ P, S, L, D }) {
    const out = [bench(P, PLATE, { grooveY: [-16] })];

    // --- papel cuadriculado y marco del gráfico ----------------------------
    out.push(S(k.slabOf(PAPER, 0, 0.7, P, 4, 0.2), { tone: "lo", crease: "none" }));
    out.push(L(k.planOutline(PAPER, 0.7, P), { tone: "lo" }));
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

    // --- las dos curvas ----------------------------------------------------
    const line = (values) => k.onTop(XS.map((x, i) => [x, values[i]]), 1, P);
    out.push(`<g data-part="train">${L(line(ERR_TRAIN.map(toY)), { tone: "mid", className: "iso-trace" })}</g>`);
    out.push(`<g data-part="val">${L(line(ERR_VAL.map(toY)), { tone: "hi", className: "iso-trace" })}</g>`);
    out.push(D(XS.filter((_, i) => i % 4 === 0).map((x, j) => k.iso([x, toY(ERR_VAL[j * 4]), 1], P)), { size: 0.45, tone: "hi" }));

    // --- brida: carros en los carriles, viga y mando ----------------------
    for (const y of RAIL_Y) {
      out.push(S(k.slabOf({ x: PAPER.x - 2, y: y - 2, w: PAPER.w + 8, d: 4, r: 1 }, 0.7, 2.6, P, 4, 0.4), { tone: "mid" }));
    }
    const beam = [];
    for (const y of RAIL_Y) {
      beam.push(S(k.slabOf({ x: BEAM_X - 5, y: y - 5, w: 10, d: 10, r: 1.6 }, 3.3, 15, P, 4, 0.5), { tone: "mid" }));
    }
    beam.push(S(k.slabOf({ x: BEAM_X - 3.5, y: -24, w: 7, d: 48, r: 1.6 }, 18.3, 4, P, 5, 0.5), { tone: "mid" }));
    beam.push(D([k.iso([BEAM_X, -18, 22.3], P), k.iso([BEAM_X, 18, 22.3], P)], { size: 0.45 }));
    beam.push(S(k.slabOf({ x: BEAM_X - 4, y: -2, w: 8, d: 10, r: 1.4 }, 13, 5.3, P, 4, 0.5), { tone: "mid" }));
    // Mando de la brida: mueve la complejidad del modelo.
    beam.push(S(k.cylinder(BEAM_X, 14, 5, 22.3, 3, P, 28), { tone: "mid" }));
    beam.push(S(k.cylinder(BEAM_X, 14, 5, 25.3, 3, P, 28), { tone: "mid" }));
    beam.push(L(k.knurl(BEAM_X, 14, 5, 25.3, 28.3, 30, P, 0), { tone: "lo" }));
    beam.push(S(k.cylinder(BEAM_X, 14, 4.2, 28.3, 1.6, P, 24), { tone: "mid" }));
    beam.push(L(k.lineOnTop([BEAM_X - 4.2, 14], [BEAM_X + 4.2, 14], 29.9, P), { tone: "hi" }));
    // Las dos plumas, cada una en su grupo, colgadas de la brida.
    const pen = (y, name, lit) =>
      `<g data-part="${name}">${S(k.cylinder(BEAM_X, y, 1.4, 0.7, 12.3, P, 16), { tone: "hi", lit, crease: "none" })}${S(k.cylinder(BEAM_X, y, 2.2, 12, 1.6, P, 16), { tone: "mid" })}</g>`;
    beam.push(pen(toY(ERR_TRAIN[LAST]), "penTrain", false));
    beam.push(pen(toY(ERR_VAL[LAST]), "penVal", true));
    out.push(`<g data-part="beam">${beam.join("")}</g>`);

    return out.join("");
  },
});
