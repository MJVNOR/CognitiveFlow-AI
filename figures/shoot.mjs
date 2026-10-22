// Construye las figuras y las rasteriza al bundle de Flutter.
//
//   node shoot.mjs            -> PNG claro + oscuro de todas las figuras
//   node shoot.mjs d01        -> solo las que empiezan por "d01"
//   node shoot.mjs --verify   -> además pasa el chequeo de líneas colgadas
//
// El PNG no lleva texto: el título, la leyenda y la lectura van como texto de
// Flutter (seleccionable, traducible y con el color del tema).
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "..", "frontend", "assets", "figures");
const SKILL = process.env.ANATOMY_SKILL ?? "C:/Users/marti/.agents/skills/anatomy";
const CAPTURE = join(SKILL, "scripts", "capture.mjs");
const LINES = join(SKILL, "scripts", "lines.mjs");

// Cada figura: carpeta con build.mjs y variantes (modo) que produce.
const FIGURES = [
  { id: "d01-shared", build: "d01-kernel", flags: [] },
  { id: "d01-own", build: "d01-kernel", flags: ["--own"] },
  { id: "d02-mould", build: "d02-mould", flags: [] },
  { id: "d04-layers", build: "d04-layers", flags: [] },
  { id: "d07-persistence", build: "d07-persistence", flags: [] },
  { id: "data-checkweigher", build: "data-checkweigher", flags: [] },
  { id: "ml-plotter", build: "ml-plotter", flags: [] },
  { id: "monitor-recorder", build: "monitor-recorder", flags: [] },
];

const argv = process.argv.slice(2);
const verify = argv.includes("--verify");
const only = argv.find((arg) => !arg.startsWith("--"));

if (!existsSync(CAPTURE)) {
  console.error(`No encuentro capture.mjs en ${CAPTURE}. Define ANATOMY_SKILL.`);
  process.exit(1);
}
mkdirSync(OUT, { recursive: true });

for (const figure of FIGURES) {
  if (only && !figure.id.startsWith(only)) continue;
  const dir = resolve(HERE, figure.build);
  for (const theme of ["light", "dark"]) {
    const built = spawnSync(
      process.execPath,
      [join(dir, "build.mjs"), ...figure.flags, ...(theme === "light" ? ["--light"] : [])],
      { cwd: dir, encoding: "utf8" },
    );
    process.stdout.write(built.stdout ?? "");
    if (built.status !== 0) {
      process.stderr.write(built.stderr ?? "");
      process.exit(built.status ?? 1);
    }
    const html = (built.stdout ?? "").trim().split(/\r?\n/).pop().replace(/^wrote\s+/, "");
    const png = join(OUT, `${figure.id}-${theme}.png`);
    const shot = spawnSync(
      process.execPath,
      [CAPTURE, html, "--out", png, "--select", ".iso-svg", "--width", "900", "--scale", "2", "--theme", theme],
      { stdio: "inherit" },
    );
    if (shot.status !== 0) process.exit(shot.status ?? 1);
    if (verify) {
      const png2 = join(HERE, "out", `lines-${figure.id}-${theme}.png`);
      const lines = spawnSync(process.execPath, [LINES, html, "--out", png2], { stdio: "inherit" });
      if (lines.status !== 0) process.exit(lines.status ?? 1);
    }
  }
}
console.log("figuras listas en", OUT);
