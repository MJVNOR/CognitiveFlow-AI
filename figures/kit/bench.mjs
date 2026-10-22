// Bancada común de las figuras: placa sobre patas, tornillos de esquina, guía
// en T, listón de regla con sus marcas y sombra. Misma pieza en todas las
// figuras para que la escala y el acabado sean comparables.
import * as k from "./iso-kit.mjs";

const byDepth = (points, P) =>
  [...points].sort((a, b) => k.depthOf([a[0], a[1], 0], P) - k.depthOf([b[0], b[1], 0], P));

/**
 * Placa a nivel z = 0 con su canto hacia abajo.
 * @param plan {x, y, w, d, r} planta de la bancada
 * @param opts {feeth, z, rule, grooveY, screws}
 */
export function bench(P, plan, { z = -9, feeth = 4, rule = true, grooveY = null, screws = 7 } = {}) {
  const out = [`<path class="iso-halo" d="${k.haloOf(plan, z - feeth, z, P)}"/>`];
  for (const [x, y] of byDepth(k.corners(plan, 16), P)) {
    out.push(k.solidSvg(k.cylinder(x, y, 6.5, z - feeth, 1.6, P, 24), { tone: "lo" }));
    out.push(k.solidSvg(k.cylinder(x, y, 4.8, z - feeth + 1.6, feeth - 1.6, P, 24), { tone: "lo" }));
  }
  out.push(k.solidSvg(k.slabOf(plan, z, -z, P, 10, 1.6), { tone: "mid", className: "iso-pad" }));
  if (grooveY !== null) {
    for (const y of grooveY) {
      out.push(k.lineSvg(k.planOutline({ x: plan.x + 9, y, w: plan.w - 18, d: 3.5, r: 1.6 }, 0, P), { tone: "faint" }));
    }
  }
  const spots = k.corners(plan, screws);
  out.push(k.lineSvg(spots.map(([x, y]) => k.ring(x, y, 2, 0, P, 16)).join(""), { tone: "lo" }));
  out.push(k.dotsSvg(spots.map(([x, y]) => k.iso([x, y, 0], P)), { size: 0.5 }));
  if (rule) {
    const strip = { x: plan.x + 10, y: plan.y + plan.d - 8, w: plan.w - 20, d: 3.5, r: 1 };
    out.push(k.solidSvg(k.slabOf(strip, 0, 0.6, P, 3), { tone: "lo", crease: "none" }));
    const ticks = k.topTicks(strip.x + 4, strip.x + strip.w - 4, 3.5, 5, strip.y + 0.6, 0.6, [1.2, 2.4], P);
    out.push(k.lineSvg(ticks.minor, { tone: "lo" }), k.lineSvg(ticks.major, { tone: "mid" }));
  }
  return out.join("");
}
