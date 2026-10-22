// Data · "Línea de inspección" — una cinta con piezas: huecos (nulos), una
// pieza repetida (duplicado) y una que pega la aguja al tope (fuera de rango).
import * as k from "../kit/iso-kit.mjs";
import * as G from "../kit/lathe.mjs";
import { bench } from "../kit/bench.mjs";
import { figure } from "../kit/figure.mjs";

const PLATE = { x: -74, y: -22, w: 148, d: 44, r: 7 };
const BELT = { from: -54, to: 40, y: 0, z: 22 };
const ROLLER_R = 6;
const ROLLER_Z = BELT.z - ROLLER_R;
const DIAL = { x: 32, y: 0, z: 34, r: 10 };
const PARTS = [-46, -33, -20, -7, 6, 19, 32];

figure({
  id: "data-checkweigher",
  title: "Línea de inspección",
  extent: k.boxCorners(PLATE, -13, 52),
  readout: "3 piezas · 1 hueco · 1 duplicado · 1 fuera de rango",
  keys: [
    { mark: "lit", label: "Fuera de rango: la aguja no puede pasar de aquí" },
    { mark: "raised", label: "Huecos en la cinta: dato que falta" },
    { mark: "raised", label: "Pieza repetida en el mismo puesto: duplicado" },
  ],
  caption:
    "La cinta trae seis puestos: dos llegan vacíos (faltan datos), uno trae la pieza repetida (duplicado) y uno trae una pieza que pega la aguja al tope (fuera de rango). Antes de calcular nada, hay que decidir qué hacer con cada uno.",
  label:
    "Una cinta transportadora sobre un banco con seis puestos. Dos puestos están vacíos, uno lleva dos piezas apiladas y el último, bajo un reloj comparador, lleva una pieza más grande que hace que la aguja marque el tope de la escala.",
  scene({ P, S, L, D }) {
    const out = [bench(P, PLATE, { grooveY: [-16] })];

    // --- bastidor de la cinta: dos largueros con sus patas ------------------
    for (const ry of [-13, 13]) {
      out.push(S(k.slabOf({ x: BELT.from - 6, y: ry - 2, w: BELT.to - BELT.from + 12, d: 4, r: 1 }, 10, 4, P, 4, 0.4), { tone: "mid" }));
      for (const lx of [BELT.from - 2, (BELT.from + BELT.to) / 2, BELT.to + 2]) {
        out.push(S(k.slabOf({ x: lx - 2, y: ry - 2, w: 4, d: 4, r: 0.8 }, 0, 10, P, 3, 0.3), { tone: "mid" }));
        out.push(D([k.iso([lx, ry, 0.2], P)], { size: 0.45 }));
      }
    }
    // Rodillos: dos cilindros tumbados en los extremos.
    for (const rx of [BELT.from, BELT.to]) {
      const F = G.frameAlong([rx, -13, ROLLER_Z], [0, 1, 0]);
      out.push(S(G.solidOf([[0, ROLLER_R], [26, ROLLER_R]], F, P), { tone: "mid", crease: "lo" }));
      out.push(S(G.disc(3, 4.4, ROLLER_R + 0.8, F, P), { tone: "mid" }));
      out.push(S(G.disc(21.6, 23, ROLLER_R + 0.8, F, P), { tone: "mid" }));
    }
    // La banda: un tramo superior fino que apoya en los dos rodillos.
    out.push(S(k.slabOf({ x: BELT.from, y: -11, w: BELT.to - BELT.from, d: 22, r: 5 }, BELT.z - 2, 2, P, 8, 0.4), { tone: "hi", crease: "lo" }));
    out.push(L(k.planOutline(k.insetPlan({ x: BELT.from, y: -11, w: BELT.to - BELT.from, d: 22, r: 5 }, 1.2), BELT.z, P), { tone: "faint" }));

    // --- puestos: piezas, huecos y duplicado --------------------------------
    const piece = (cx, z0, size = 1, lit = false, dy = 0) => {
      const w = 10 * size;
      out.push(S(k.slabOf({ x: cx - w / 2, y: dy - w / 2, w, d: w, r: 1 }, z0, 6 * size, P, 4, 0.5), { tone: "hi", lit, crease: "lo" }));
      out.push(D([k.iso([cx - w / 4, -w / 4, z0 + 6 * size], P), k.iso([cx + w / 4, -w / 4, z0 + 6 * size], P)], { size: 0.4 }));
    };
    piece(PARTS[0], BELT.z);
    piece(PARTS[1], BELT.z);
    piece(PARTS[2], BELT.z);
    // Puestos vacíos: la bandeja está en la cinta, sin pieza (dato que falta).
    for (const empty of [PARTS[3], PARTS[5]]) {
      out.push(S(k.slabOf({ x: empty - 5.5, y: -5.5, w: 11, d: 11, r: 1 }, BELT.z, 0.8, P, 4, 0.3), { tone: "lo", crease: "none" }));
      out.push(L(k.planOutline({ x: empty - 5.5, y: -5.5, w: 11, d: 11, r: 1 }, BELT.z + 0.8, P), { tone: "lo" }));
      out.push(L(k.planOutline({ x: empty - 3.4, y: -3.4, w: 6.8, d: 6.8, r: 0.6 }, BELT.z + 0.8, P), { tone: "faint" }));
    }
    // Duplicado: dos piezas en el mismo puesto.
    piece(PARTS[4], BELT.z, 1, false, -1);
    piece(PARTS[4], BELT.z + 6, 1, false, 1);
    // Fuera de rango: una pieza más ancha que el patrón, bajo el comparador.
    piece(PARTS[6], BELT.z, 1.45, true);

    // --- comparador: poste, brazo, reloj de esfera hacia arriba -------------
    const d = DIAL;
    out.push(S(k.slabOf({ x: d.x - 4, y: 14, w: 8, d: 7, r: 1.2 }, 0, 3, P, 4, 0.4), { tone: "mid" }));
    out.push(S(k.cylinder(d.x, 17.5, 2.8, 3, 33, P, 20), { tone: "mid", crease: "none" }));
    out.push(L(k.sideArc(d.x, 17.5, 2.8, 20, P, 20), { tone: "faint" }));
    out.push(S(k.slabOf({ x: d.x - 3, y: 4, w: 6, d: 14, r: 1.4 }, 34, 4, P, 4, 0.4), { tone: "mid" }));
    // Punta del palpador apoyada en la pieza grande (su tope está a 30.7).
    out.push(S(k.cylinder(d.x, d.y, 2.2, BELT.z + 8.7, d.z - BELT.z - 8.7, P, 18), { tone: "mid" }));
    out.push(S(k.cylinder(d.x, d.y, 3, BELT.z + 8.7, 1.4, P, 18), { tone: "mid" }));
    out.push(S(k.cylinder(d.x, d.y, d.r, d.z, 10, P, 48, 0.8), { tone: "hi", crease: "lo" }));
    out.push(L(k.knurl(d.x, d.y, d.r, d.z + 6.4, d.z + 9.6, 64, P, 0), { tone: "lo" }));
    out.push(L(k.sideArc(d.x, d.y, d.r, d.z + 6.4, P, 40), { tone: "faint" }));
    out.push(L(k.ring(d.x, d.y, d.r - 2.4, d.z + 10, P, 48), { tone: "lo" }));
    const ticks = k.radialTicks(d.x, d.y, d.r - 2.4, 40, 5, d.z + 10, [1.2, 2.4], P);
    out.push(L(k.ring(d.x, d.y, d.r - 3.6, d.z + 10, P, 48), { tone: "faint" }));
    out.push(L(k.ring(d.x, d.y, d.r - 4.8, d.z + 10, P, 48), { tone: "faint" }));
    out.push(L(ticks.minor, { tone: "lo" }), L(ticks.major, { tone: "mid" }));
    // Aguja al tope: marca el máximo de la escala.
    const angle = -Math.PI * 0.28;
    out.push(
      L(
        k.lineOnTop(
          [d.x - Math.sin(angle) * 3, d.y + Math.cos(angle) * 3],
          [d.x + Math.sin(angle) * (d.r - 2.6), d.y - Math.cos(angle) * (d.r - 2.6)],
          d.z + 10.2,
          P,
        ),
        { tone: "hi", free: true },
      ),
    );
    out.push(L(k.ring(d.x, d.y, 1.6, d.z + 10, P, 16), { tone: "mid" }));
    out.push(S(k.slabOf({ x: d.x + d.r - 1, y: -2.4, w: 4.6, d: 4.8, r: 1.2 }, d.z + 1, 4, P, 3, 0.4), { tone: "mid" }));
    out.push(D([k.iso([d.x, d.y, d.z + 10.2], P)], { size: 0.4, tone: "hi" }));

    return out.join("");
  },
});
