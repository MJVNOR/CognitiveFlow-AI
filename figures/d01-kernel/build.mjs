// D01 · "Un motor, tres cabezales" (contenedor) / "Cada cabezal con el suyo" (VM)
//
// Objeto: un banco de taladros por eje de línea. En modo `shared` un solo motor,
// en el extremo, sube por un reductor y mueve un eje del que cuelgan tres
// cabezales: los tres comparten la misma fuente de movimiento. En modo `own` el
// eje desaparece y cada cabezal lleva su propio motor encima: cada uno trae su
// máquina completa, como una VM con su kernel.
//
// node build.mjs            -> figures/out/d01-kernel-shared.html
// node build.mjs --light    -> figures/out/d01-kernel-shared-light.html
// node build.mjs --own      -> figures/out/d01-kernel-own.html
// node build.mjs --own --light
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as k from "../kit/iso-kit.mjs";
import * as G from "../kit/lathe.mjs";
import { bench as benchPlate } from "../kit/bench.mjs";
import { themeCss, FIGURE_CSS } from "../theme.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "..", "out");

const argv = process.argv.slice(2);
const mode = argv.includes("--own") ? "own" : "shared";
const theme = argv.includes("--light") ? "light" : "dark";
const shared = mode === "shared";

const WIDTH = 660;
const HEIGHT = 400;

const PLATE = { x: -104, y: -22, w: 184, d: 46, r: 7 };
const PLATE_Z = -9;
const FEET = 4;

const HEAD_X = [-52, 0, 52];
const HEAD_Y = 2;
const BOX_Z = 38;
const BOX_TOP = 50;
const SHAFT_Z = 53.4;
const SHAFT_R = 4;
const CAP_TOP = 57;
const CHUCK_Z = 24;
const WORK_TOP = 16;
const MOTOR_X = -91;
const MOTOR_Z = 12;
const MOTOR_H = 26;
const MOTOR_R = 9;

// Cada modo se ajusta a su propia altura (el motor propio sube más) para llenar
// la tarjeta; banco, cabezales y mordazas son idénticos en unidades de mundo.
const tall = shared ? 62 : 86;
const P = k.fitProjection(k.boxCorners(PLATE, PLATE_Z - FEET, tall), WIDTH, HEIGHT, {
  pad: 26,
  azimuth: 40,
  elevation: 35,
});

const at = (point) => k.iso(point, P);
const S = (paths, style) => k.solidSvg(paths, style);
const L = (d, style) => k.lineSvg(d, style);
const D = (points, style) => k.dotsSvg(points, style);

// ---------------------------------------------------------------- el banco

const bench = () => benchPlate(P, PLATE, { grooveY: [-16] });

// --------------------------------------------------------------- el puesto

function vise(cx) {
  const out = [];
  const base = { x: cx - 12, y: HEAD_Y - 12, w: 24, d: 24, r: 2 };
  out.push(S(k.slabOf(base, 0, 6, P, 5, 0.5), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(base, 2), 6, P), { tone: "faint" }));
  out.push(S(k.slabOf({ x: cx - 11, y: HEAD_Y - 11, w: 22, d: 5, r: 1 }, 6, 12, P, 4, 0.5), { tone: "mid" }));
  out.push(D([at([cx - 7.5, HEAD_Y - 8.5, 18]), at([cx + 7.5, HEAD_Y - 8.5, 18])], { size: 0.45 }));
  // Pieza entre mordazas: su cara de arriba es la que ataca la broca.
  out.push(S(k.slabOf({ x: cx - 5.5, y: HEAD_Y - 5.5, w: 11, d: 9, r: 0.8 }, 6, WORK_TOP - 6, P, 3, 0.5), { tone: "hi", crease: "lo" }));
  out.push(L(k.lineOnTop([cx - 5.5, HEAD_Y - 3.5], [cx + 5.5, HEAD_Y - 3.5], WORK_TOP, P), { tone: "faint" }));
  out.push(S(k.slabOf({ x: cx - 11, y: HEAD_Y + 3.5, w: 22, d: 4, r: 1 }, 6, 4, P, 4, 0.5), { tone: "mid" }));
  // Volante de apriete, de eje vertical para poder dibujarlo con cilindros.
  const knob = [cx, HEAD_Y + 9];
  out.push(S(k.cylinder(knob[0], knob[1], 3.2, 6, 4.6, P, 24), { tone: "mid" }));
  out.push(S(k.cylinder(knob[0], knob[1], 2.1, 10.6, 3, P, 20), { tone: "mid" }));
  out.push(L(k.knurl(knob[0], knob[1], 2.1, 10.6, 13.6, 18, P, 0), { tone: "lo" }));
  out.push(L(k.sideArc(knob[0], knob[1], 3.2, 10.6, P, 20), { tone: "faint" }));
  return out.join("");
}

// Lo que cuelga del eje en cada cabezal: broca, portabrocas, husillo y caja.
function spindleStack(cx) {
  const out = [];
  out.push(S(k.cylinder(cx, HEAD_Y, 1.2, WORK_TOP, CHUCK_Z - WORK_TOP, P, 14), { tone: "hi", crease: "none" }));
  out.push(S(k.cylinder(cx, HEAD_Y, 6.4, CHUCK_Z, 8, P, 40), { tone: "hi", crease: "lo" }));
  out.push(L(k.knurl(cx, HEAD_Y, 6.4, CHUCK_Z, CHUCK_Z + 8, 44, P, 0), { tone: "lo" }));
  out.push(L(k.sideArc(cx, HEAD_Y, 6.4, CHUCK_Z + 1.4, P, 32), { tone: "faint" }));
  out.push(S(k.cylinder(cx, HEAD_Y, 7.2, CHUCK_Z + 8, 2, P, 40), { tone: "mid" }));
  out.push(L(k.ring(cx, HEAD_Y, 5.6, CHUCK_Z + 10, P, 32), { tone: "faint" }));
  out.push(S(k.cylinder(cx, HEAD_Y, 2.6, CHUCK_Z + 10, BOX_Z - CHUCK_Z - 10, P, 24), { tone: "hi", crease: "none" }));
  out.push(S(k.cylinder(cx, HEAD_Y, 4.4, BOX_Z - 5, 4, P, 24), { tone: "mid" }));
  // Caja del cabezal: el eje se apoya arriba, en su tapa.
  const box = { x: cx - 7.5, y: HEAD_Y - 7.5, w: 15, d: 15, r: 1.4 };
  out.push(S(k.slabOf(box, BOX_Z, BOX_TOP - BOX_Z, P, 5, 0.6), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(box, 1.5), BOX_TOP, P), { tone: "faint" }));
  out.push(L(k.lineOnTop([cx - 5.6, HEAD_Y - 7.5], [cx - 5.6, HEAD_Y + 7.5], BOX_Z, P), { tone: "faint" }));
  out.push(D([at([cx + 5, HEAD_Y + 5, BOX_TOP]), at([cx + 5, HEAD_Y - 5, BOX_TOP])], { size: 0.45 }));
  return out.join("");
}

// Tapa de apoyo del eje sobre cada caja: el eje entra dentro de ella.
function bearingCap(cx) {
  const out = [];
  out.push(S(k.slabOf({ x: cx - 6, y: HEAD_Y - 6.5, w: 12, d: 13, r: 2 }, BOX_TOP, CAP_TOP - BOX_TOP, P, 5, 0.5), { tone: "mid" }));
  out.push(D([at([cx - 4, HEAD_Y + 4.5, CAP_TOP]), at([cx + 4, HEAD_Y + 4.5, CAP_TOP])], { size: 0.4 }));
  return out.join("");
}

// Soporte del eje en su extremo: pie desde el banco y bloque que lo abraza.
function pillowBracket(cx) {
  const out = [];
  out.push(S(k.slabOf({ x: cx - 7, y: HEAD_Y - 7, w: 14, d: 14, r: 2 }, 0, 4, P, 4, 0.4), { tone: "mid" }));
  out.push(D([at([cx - 5, HEAD_Y - 5, 4]), at([cx + 5, HEAD_Y - 5, 4])], { size: 0.45 }));
  out.push(S(k.slabOf({ x: cx - 4, y: HEAD_Y - 4.5, w: 8, d: 9, r: 1 }, 4, 45.8, P, 4, 0.4), { tone: "mid" }));
  return out.join("");
}

// Bloque que abraza el eje encima del soporte.
function pillowBlock(cx) {
  const out = [];
  out.push(S(k.slabOf({ x: cx - 6, y: HEAD_Y - 6.5, w: 12, d: 13, r: 2 }, 49.8, CAP_TOP - 49.8, P, 5, 0.5), { tone: "mid" }));
  out.push(D([at([cx - 4, HEAD_Y + 4.5, CAP_TOP]), at([cx + 4, HEAD_Y + 4.5, CAP_TOP])], { size: 0.4 }));
  return out.join("");
}

// El motor: una lata vertical, la misma pieza en los dos modos.
function motorCan(cx, y, z0, tall = MOTOR_H) {
  const out = [];
  out.push(S(k.cylinder(cx, y, MOTOR_R - 1, z0, 1.4, P, 32), { tone: "mid" }));
  out.push(S(k.cylinder(cx, y, MOTOR_R - 2.2, z0 + 1.4, tall, P, 32), { tone: "hi", lit: true, crease: "lo" }));
  // Aletas de refrigeración: rayas verticales sobre el cuerpo, sin taparlo.
  out.push(L(k.knurl(cx, y, MOTOR_R - 2.2, z0 + 1.4, z0 + 1.4 + tall, 34, P, 0), { tone: "lo" }));
  out.push(S(k.cylinder(cx, y, MOTOR_R - 3.6, z0 + tall + 1.4, 2.6, P, 28), { tone: "mid" }));
  out.push(S(k.cylinder(cx, y, 3.4, z0 + tall + 4, 2, P, 20), { tone: "mid" }));
  out.push(L(k.sideArc(cx, y, MOTOR_R - 2.2, z0 + 2, P, 32), { tone: "faint" }));
  // Caja de bornes atornillada al costado.
  out.push(S(k.slabOf({ x: cx + MOTOR_R - 3.4, y: y - 3.4, w: 4.6, d: 6.8, r: 1 }, z0 + 6, 6.4, P, 3, 0.4), { tone: "mid" }));
  out.push(D([at([cx + MOTOR_R - 1.4, y - 1.6, z0 + 12]), at([cx + MOTOR_R - 1.4, y + 1.6, z0 + 12])], { size: 0.4 }));
  return out.join("");
}

// Extremo motriz del modo compartido: apoyo, motor, acoplamiento y reductor.
function driveEnd() {
  const out = [];
  const y = HEAD_Y;
  out.push(S(k.slabOf({ x: MOTOR_X - 11, y: y - 11, w: 22, d: 22, r: 2 }, 0, MOTOR_Z, P, 5, 0.6), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan({ x: MOTOR_X - 9, y: y - 9, w: 18, d: 18, r: 1.6 }, 1), MOTOR_Z, P), { tone: "faint" }));
  out.push(D([at([MOTOR_X - 8, y + 8, MOTOR_Z]), at([MOTOR_X + 8, y + 8, MOTOR_Z])], { size: 0.45 }));
  out.push(motorCan(MOTOR_X, y, MOTOR_Z));
  // Reductor: va montado sobre el motor y saca el eje horizontal a la derecha.
  const gear = { x: MOTOR_X - 7, y: y - 7, w: 14, d: 14, r: 1.4 };
  out.push(S(k.slabOf(gear, MOTOR_Z + MOTOR_H + 6.4, CAP_TOP - (MOTOR_Z + MOTOR_H + 6.4), P, 5, 0.6), { tone: "mid" }));
  out.push(L(k.planOutline(k.insetPlan(gear, 1.5), CAP_TOP, P), { tone: "faint" }));
  out.push(D([at([MOTOR_X + 4, y + 4, CAP_TOP]), at([MOTOR_X + 4, y - 4, CAP_TOP])], { size: 0.45 }));
  return out.join("");
}

// Eje de línea: sale del reductor y atraviesa las tres cajas.
function lineShaft() {
  const from = MOTOR_X + 7;
  const to = 78;
  const F = G.frameAlong([from, HEAD_Y, SHAFT_Z], [1, 0, 0]);
  const out = [];
  out.push(S(G.solidOf([[0, SHAFT_R], [to - from, SHAFT_R]], F, P), { tone: "mid", crease: "none" }));
  out.push(L(G.arcOf(F, 24, SHAFT_R, P), { tone: "faint" }));
  // Un collar a cada lado de cada caja: el eje entra en ella, no la atraviesa.
  for (const cx of HEAD_X) {
    for (const edge of [cx - 9.4, cx + 7.6]) {
      out.push(S(G.disc(edge - from, edge + 1.6 - from, 5.4, F, P), { tone: "mid" }));
    }
  }
  // Collar de tope al final del eje.
  out.push(S(G.disc(to - from - 3.2, to - from, 5.6, F, P), { tone: "mid" }));
  return out.join("");
}

// Caja de piezas al fondo, para que el banco no quede vacío en modo `own`.
function partsBin() {
  const out = [];
  const bin = { x: MOTOR_X - 10, y: PLATE.y + 4, w: 22, d: 12, r: 1.5 };
  out.push(S(k.slabOf(bin, 0, 3, P, 4, 0.4), { tone: "mid" }));
  for (const side of [
    { x: bin.x, y: bin.y, w: bin.w, d: 2 },
    { x: bin.x, y: bin.y + bin.d - 2, w: bin.w, d: 2 },
    { x: bin.x, y: bin.y, w: 2, d: bin.d },
    { x: bin.x + bin.w - 2, y: bin.y, w: 2, d: bin.d },
  ]) {
    out.push(S(k.slabOf({ ...side, r: 0.6 }, 3, 5, P, 3, 0.4), { tone: "mid" }));
  }
  for (const [dx, dy, w, d, h] of [[4, 3, 5, 4, 3.4], [11, 4, 4.6, 5, 4], [5, 7.4, 6, 4, 2.6]]) {
    out.push(S(k.slabOf({ x: bin.x + dx, y: bin.y + dy, w, d, r: 0.6 }, 3, h, P, 3, 0.4), { tone: "lo" }));
  }
  return out.join("");
}

// ------------------------------------------------------------- composición
// Lejos → cerca: banco, soportes del fondo, puestos, lo que cuelga, el eje y
// por último las tapas y bornes que lo abrazan.
const body = [
  bench(),
  ...(shared ? [pillowBracket(70)] : [partsBin()]),
  ...HEAD_X.map((cx) => vise(cx)),
  ...HEAD_X.map((cx) => spindleStack(cx)),
  shared ? lineShaft() : "",
  ...HEAD_X.map((cx) => bearingCap(cx)),
  shared ? pillowBlock(70) : "",
  shared ? driveEnd() : "",
  ...(shared ? [] : HEAD_X.map((cx) => motorCan(cx, HEAD_Y, BOX_TOP))),
].join("");

const svg = k.figureSvg({
  width: WIDTH,
  height: HEIGHT,
  label: shared
    ? "Un banco de taladros por eje de línea: un solo motor sube por un reductor y mueve un eje del que cuelgan tres cabezales, que comparten esa única fuente de movimiento."
    : "Tres cabezales de taladro independientes: cada uno lleva encima su propio motor y su propia caja, sin eje ni fuente de movimiento compartida.",
  body,
});

const keys = shared
  ? [
      { mark: "lit", label: "El motor: única fuente; si se para, se paran los tres" },
      { mark: "raised", label: "Reductor y eje de línea con dos soportes" },
      { mark: "raised", label: "Tres cabezales colgados del mismo eje" },
    ]
  : [
      { mark: "lit", label: "Tres motores: cada cabezal trae el suyo" },
      { mark: "raised", label: "Sin eje, sin soportes, sin fuente común" },
    ];

const caption = shared
  ? "Un motor sube por un reductor y mueve un eje del que cuelgan tres cabezales: comparten el movimiento. Si el motor cambia o se para, los tres cambian con él."
  : "Tres cabezales, cada uno con su propio motor encima: cada uno funciona y se para por su cuenta, y cada uno carga con el coste de tener su máquina completa.";

const name = `d01-kernel-${mode}${theme === "light" ? "-light" : ""}`;
const plate = k.plateHtml({
  fig: shared ? "Fig 1" : "Fig 2",
  title: shared ? "Un motor, tres cabezales" : "Tres motores, tres cabezales",
  hint: "",
  readout: shared ? "1 motor · 3 cabezales" : "3 motores · 3 cabezales",
  keys,
  caption,
  body: `<div class="iso-stage">${svg}</div>`,
});
const html = k.pageHtml({ title: plate, theme, body: plate }).replace("</head>", `<style>${themeCss(theme)}${FIGURE_CSS}</style></head>`);
writeFileSync(join(OUT, `${name}.html`), html);
console.log("wrote", join(OUT, `${name}.html`));
