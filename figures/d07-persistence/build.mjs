// D07 · "Qué sobrevive al recrear" — tres formas de guardar: bandeja seca (sin
// montar, se pierde), depósito atornillado al banco (volumen nombrado, con su
// nivel a la vista) y brida con tubo que sale del banco (bind mount al host).
import * as k from "../kit/iso-kit.mjs";
import * as G from "../kit/lathe.mjs";
import { bench } from "../kit/bench.mjs";
import { figure } from "../kit/figure.mjs";

const PLATE = { x: -74, y: -22, w: 148, d: 44, r: 7 };
const DRUM = { x: -36, y: 2, r: 13 };
const TRAY = { x: -64, y: -14, w: 36, d: 26 };
const PIPE = { x: 28, y: 2, z: 11 };

figure({
  id: "d07-persistence",
  title: "Qué sobrevive al recrear",
  extent: k.boxCorners(PLATE, -13, 44),
  readout: "depósito lleno · bandeja seca · tubo fuera",
  keys: [
    { mark: "lit", label: "Nivel del volumen: sigue lleno tras recrear" },
    { mark: "raised", label: "Bandeja sin montar: se queda seca" },
    { mark: "raised", label: "Brida y tubo: depende de una ruta del host" },
  ],
  caption:
    "El depósito atornillado al banco (volumen nombrado) conserva su nivel aunque el contenedor se recree. La brida lleva el tubo fuera del banco (bind mount): depende de que esa ruta exista. La bandeja sin montar se queda seca.",
  label:
    "Un banco con tres formas de guardar: una bandeja abierta y seca, un depósito atornillado con un tubo de nivel lleno hasta la mitad, y una brida con un tubo recto que sale del banco.",
  scene({ P, S, L, D }) {
    const out = [bench(P, PLATE, { grooveY: [-16] })];

    // --- bandeja sin montar: base con paredes bajas y su desagüe ----------
    const tray = TRAY;
    out.push(S(k.slabOf(tray, 0, 2.5, P, 4, 0.4), { tone: "mid" }));
    for (const side of [
      { x: tray.x, y: tray.y, w: tray.w, d: 2.5 },
      { x: tray.x, y: tray.y + tray.d - 2.5, w: tray.w, d: 2.5 },
      { x: tray.x, y: tray.y, w: 2.5, d: tray.d },
      { x: tray.x + tray.w - 2.5, y: tray.y, w: 2.5, d: tray.d },
    ]) {
      out.push(S(k.slabOf({ ...side, r: 0.6 }, 2.5, 6, P, 3, 0.4), { tone: "mid" }));
    }
    out.push(L(k.planOutline(k.insetPlan(tray, 3.2), 2.5, P), { tone: "faint" }));
    out.push(S(k.cylinder(tray.x + tray.w / 2, tray.y + tray.d / 2, 2.4, 2.5, 1.2, P, 20), { tone: "mid" }));
    out.push(L(k.ring(tray.x + tray.w / 2, tray.y + tray.d / 2, 2.4, 3.7, P, 20), { tone: "lo" }));

    // --- depósito atornillado: volumen nombrado ---------------------------
    const F = G.frameAlong([DRUM.x, DRUM.y, 0], [0, 0, 1]);
    out.push(S(k.cylinder(DRUM.x, DRUM.y, DRUM.r + 3, 0, 3, P, 40), { tone: "mid" }));
    out.push(D(Array.from({ length: 8 }, (_, i) => {
      const a = (i / 8) * Math.PI * 2 + 0.2;
      return k.iso([DRUM.x + (DRUM.r + 1.5) * Math.cos(a), DRUM.y + (DRUM.r + 1.5) * Math.sin(a), 3], P);
    }), { size: 0.45 }));
    // Cuerpo cerrado, con su tapa y la brida del borde.
    out.push(S(G.solidOf([[0, DRUM.r], [24, DRUM.r], [24, DRUM.r - 2.4]], F, P), { tone: "mid" }));
    out.push(L(G.arcOf(F, 3, DRUM.r, P), { tone: "faint" }));
    out.push(L(G.arcOf(F, 24, DRUM.r, P), { tone: "lo" }));
    out.push(D(Array.from({ length: 12 }, (_, i) => {
      const a = (i / 12) * Math.PI * 2 + 0.1;
      return k.iso([DRUM.x + (DRUM.r - 1.2) * Math.cos(a), DRUM.y + (DRUM.r - 1.2) * Math.sin(a), 24], P);
    }), { size: 0.4 }));
    out.push(S(k.cylinder(DRUM.x, DRUM.y, 4, 24, 2.4, P, 24), { tone: "mid" }));
    out.push(L(k.ring(DRUM.x, DRUM.y, 4, 26.4, P, 24), { tone: "lo" }));
    // Grifo bajo el depósito.
    out.push(S(k.cylinder(DRUM.x, DRUM.y + DRUM.r - 1, 1.8, 7, 4, P, 18), { tone: "mid" }));
    out.push(L(k.knurl(DRUM.x, DRUM.y + DRUM.r - 1, 1.8, 7, 11, 14, P, 0), { tone: "lo" }));

    // Tubo de nivel: se ve hasta dónde llega lo guardado.
    const glass = { x: DRUM.x + DRUM.r + 4, y: DRUM.y + 6 };
    for (const z of [8, 20]) {
      out.push(S(k.slabOf({ x: glass.x - 1.4, y: DRUM.y + 2, w: 2.8, d: glass.y - DRUM.y - 2, r: 0.6 }, z, 1.4, P, 3, 0.3), { tone: "mid" }));
    }
    out.push(S(k.cylinder(glass.x, glass.y, 1.9, 6, 18, P, 18), { tone: "hi", crease: "lo" }));
    out.push(S(k.cylinder(glass.x, glass.y, 1.4, 6, 12, P, 16), { tone: "hi", className: "iso-liquid" }));
    for (const z of [4.6, 22.4]) {
      out.push(S(k.cylinder(glass.x, glass.y, 2.6, z, 2, P, 18), { tone: "mid" }));
    }

    // --- brida con tubo que sale del banco: bind mount --------------------
    const p = PIPE;
    out.push(S(k.slabOf({ x: p.x - 8, y: p.y - 7, w: 16, d: 14, r: 2 }, 0, 7, P, 4, 0.5), { tone: "mid" }));
    out.push(S(k.cylinder(p.x, p.y, 5.4, 7, 4, P, 28), { tone: "mid" }));
    out.push(D(Array.from({ length: 6 }, (_, i) => {
      const a = (i / 6) * Math.PI * 2 + 0.4;
      return k.iso([p.x + 4.2 * Math.cos(a), p.y + 4.2 * Math.sin(a), 11], P);
    }), { size: 0.4 }));
    // Un solo tramo recto hacia el fondo, que acaba fuera del banco en brida.
    const axis = G.frameAlong([p.x, p.y + 2, p.z], [0, -1, 0]);
    const run = p.y + 2 - (PLATE.y - 4);
    out.push(S(G.solidOf([[0, 3.2], [run, 3.2]], axis, P), { tone: "mid", crease: "none" }));
    out.push(S(G.disc(6, 8, 4.6, axis, P), { tone: "mid" }));
    out.push(S(G.disc(run - 2, run, 5.6, axis, P), { tone: "mid" }));
    out.push(L(G.arcOf(axis, run - 1, 5.6, P), { tone: "lo" }));

    return out.join("");
  },
});
