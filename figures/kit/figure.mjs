// Envoltorio común de las figuras: encuadre, helpers, página de revisión,
// movimiento y salida. Cada figura define su escena y, si se mueve, su pose.
//
// El movimiento es determinista: la página expone `window.__pose(t)` con t en
// [0,1) y el exportador de fotogramas la llama fotograma a fotograma, así que
// el resultado no depende del reloj de la máquina.
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as k from "./iso-kit.mjs";
import { themeCss, FIGURE_CSS } from "../theme.mjs";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "out");

// Vector de pantalla por unidad de mundo en cada eje, para mover grupos sin
// arrastrar el kit entero al navegador.
function screenBasis(P) {
  const o = k.iso([0, 0, 0], P);
  return ["x", "y", "z"].map((_, index) => {
    const unit = [0, 0, 0];
    unit[index] = 1;
    const p = k.iso(unit, P);
    return [Number((p[0] - o[0]).toFixed(4)), Number((p[1] - o[1]).toFixed(4))];
  });
}

export function figure({
  id,
  extent,
  scene,
  live = null,
  title,
  label,
  keys = [],
  caption,
  readout = "",
  width = 660,
  height = 400,
  pageWidth = 940,
  azimuth = 40,
  elevation = 34,
  pad = 26,
}) {
  const theme = process.argv.includes("--light") ? "light" : "dark";
  const P = k.fitProjection(extent, width, height, { pad, azimuth, elevation });
  const helpers = {
    P,
    at: (point) => k.iso(point, P),
    S: (paths, style) => k.solidSvg(paths, style),
    L: (d, style) => k.lineSvg(d, style),
    D: (points, style) => k.dotsSvg(points, style),
  };
  const svg = k.figureSvg({ width, height, label, body: scene(helpers) });
  const plate = k.plateHtml({
    fig: "",
    title,
    hint: "",
    readout,
    keys,
    caption,
    body: `<div class="iso-stage">${svg}</div>`,
  });
  const script = live
    ? `
const stage = document.querySelector(".iso-stage");
const svg = stage.querySelector("svg");
const E = ${JSON.stringify(screenBasis(P))};
const mov = (dx, dy, dz) =>
  "translate(" + (dx * E[0][0] + dy * E[1][0] + dz * E[2][0]).toFixed(2) + " " +
  (dx * E[0][1] + dy * E[1][1] + dz * E[2][1]).toFixed(2) + ")";
const part = (name) => svg.querySelector('[data-part="' + name + '"]');
const parts = (name) => [...svg.querySelectorAll('[data-part="' + name + '"]')];
${live}
window.__pose = pose;
window.__pose(0);
`
    : "";
  const html = k.pageHtml({ title: plate, theme, body: plate, script, width: pageWidth }).replace(
    "</head>",
    `<style>${themeCss(theme)}${FIGURE_CSS}</style></head>`,
  );
  const name = `${id}${theme === "light" ? "-light" : ""}`;
  writeFileSync(join(OUT, `${name}.html`), html);
  console.log("wrote", join(OUT, `${name}.html`));
}
