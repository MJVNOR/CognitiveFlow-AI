// Construye las figuras y las exporta al bundle de Flutter como WebP animado.
//
//   node shoot.mjs            -> todas (claro + oscuro)
//   node shoot.mjs d01        -> solo las que empiezan por "d01"
//   node shoot.mjs --verify   -> además pasa el chequeo de líneas colgadas
//
// Cada figura se construye con su script de pose (`window.__pose(t)`), se
// fotografía fotograma a fotograma con Chrome headless y se monta en un WebP
// con Pillow (uv). El PNG no lleva texto: título, leyenda y lectura son texto
// de Flutter.
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "..", "frontend", "assets", "figures");
const FRAMES = join(HERE, "out", "frames");
const SKILL = process.env.ANATOMY_SKILL ?? "C:/Users/marti/.agents/skills/anatomy";
const DRIVE = join(SKILL, "scripts", "drive.mjs");
const LINES = join(SKILL, "scripts", "lines.mjs");

// Cada figura: carpeta con build.mjs, variantes y si tiene movimiento.
const FIGURES = [
  { id: "d01-shared", build: "d01-kernel", flags: [], frames: 24 },
  { id: "d01-own", build: "d01-kernel", flags: ["--own"], frames: 24 },
  { id: "d02-mould", build: "d02-mould", flags: [], frames: 24 },
  { id: "d04-layers", build: "d04-layers", flags: [], frames: 24 },
  { id: "d07-persistence", build: "d07-persistence", flags: [], frames: 1 },
  { id: "data-checkweigher", build: "data-checkweigher", flags: [], frames: 24 },
  { id: "ml-plotter", build: "ml-plotter", flags: [], frames: 26 },
  { id: "monitor-recorder", build: "monitor-recorder", flags: [], frames: 26 },
];

const FPS = 14;

const argv = process.argv.slice(2);
const verify = argv.includes("--verify");
const only = argv.find((arg) => !arg.startsWith("--"));

if (!existsSync(DRIVE)) {
  console.error(`No encuentro drive.mjs en ${DRIVE}. Define ANATOMY_SKILL.`);
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

    const frameDir = join(FRAMES, `${figure.id}-${theme}`);
    rmSync(frameDir, { recursive: true, force: true });
    mkdirSync(frameDir, { recursive: true });
    const actions = [];
    for (let i = 0; i < figure.frames; i++) {
      const shot = join(frameDir, `${String(i).padStart(3, "0")}.png`);
      if (figure.frames > 1) actions.push(["eval", `window.__pose(${(i / figure.frames).toFixed(5)})`]);
      actions.push(["shot", shot, ".iso-svg", 1]);
    }
    const actionsFile = join(FRAMES, `${figure.id}-${theme}.json`);
    writeFileSync(actionsFile, JSON.stringify(actions));

    const run = spawnSync(process.execPath, [DRIVE, html, "--actions", actionsFile], { encoding: "utf8" });
    if (run.status !== 0) {
      process.stderr.write(run.stdout ?? "");
      process.stderr.write(run.stderr ?? "");
      process.exit(run.status ?? 1);
    }
    if (verify && figure.frames === 1) {
      const png = join(HERE, "out", `lines-${figure.id}-${theme}.png`);
      const lines = spawnSync(process.execPath, [LINES, html, "--out", png], { encoding: "utf8" });
      process.stdout.write(lines.stdout ?? "");
      if (lines.status !== 0) process.exit(lines.status ?? 1);
    }

    const webp = join(OUT, `${figure.id}-${theme}.webp`);
    const encode = spawnSync(
      "uv",
      ["run", "--quiet", "--with", "pillow", "python", join(HERE, "encode.py"), frameDir, webp, "--fps", String(FPS)],
      { encoding: "utf8" },
    );
    process.stdout.write(encode.stdout ?? "");
    if (encode.status !== 0) {
      process.stderr.write(encode.stderr ?? "");
      process.exit(encode.status ?? 1);
    }
  }
}
console.log("figuras listas en", OUT);
