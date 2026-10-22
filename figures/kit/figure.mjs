// Envoltorio común de las figuras: encuadre, helpers, página de revisión y
// salida. Cada figura define su escena y su leyenda; esto pone cámara, tema,
// tarjeta y nombre de archivo.
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import * as k from "./iso-kit.mjs";
import { themeCss, FIGURE_CSS } from "../theme.mjs";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "out");

export function figure({
  id,
  extent,
  scene,
  title,
  label,
  keys = [],
  caption,
  readout = "",
  width = 660,
  height = 400,
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
  const html = k.pageHtml({ title: plate, theme, body: plate }).replace(
    "</head>",
    `<style>${themeCss(theme)}${FIGURE_CSS}</style></head>`,
  );
  const name = `${id}${theme === "light" ? "-light" : ""}`;
  writeFileSync(join(OUT, `${name}.html`), html);
  console.log("wrote", join(OUT, `${name}.html`));
}
