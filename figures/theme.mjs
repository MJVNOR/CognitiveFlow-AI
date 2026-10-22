// Tokens de las figuras alineados con DESIGN.md (frontend/lib/ui/core/themes).
// La "paper" de la figura debe ser exactamente el color de la Card de Flutter
// porque el PNG se recorta al SVG y se incrusta en ella: #FFFFFF / #1E293B.
const LIGHT = `
.iso[data-theme="light"]{
  --anatomy-page:#f8fafc;--anatomy-card:#ffffff;--anatomy-text:#475569;--anatomy-strong:#0f172a;
  --fig-pad:#e4ebf3;--fig-liquid:#8fb6d8;--anatomy-paper:#ffffff;--anatomy-face:#ffffff;--anatomy-top:#ffffff;
  --anatomy-shade-0:#cbd6e2;--anatomy-shade-1:#d8e1ec;--anatomy-shade-2:#e4ebf3;--anatomy-shade-3:#eff4f9;
  --anatomy-lit-top:#b7ded5;--anatomy-lit-shade:#a2d2c8;
  --anatomy-hi:#0f172a;--anatomy-mid:#64748b;--anatomy-lo:#94a3b8;--anatomy-faint:#cbd5e1;
  --anatomy-lit:#0f766e;
  --anatomy-halo:#8a94a3;--anatomy-halo-opacity:.22;--anatomy-dot:#0f172a;
}`;

const DARK = `
.iso[data-theme="dark"]{
  --anatomy-page:#0f172a;--anatomy-card:#1e293b;--anatomy-text:#cbd5e1;--anatomy-strong:#f1f5f9;
  --fig-pad:#273549;--fig-liquid:#3a6b96;--anatomy-paper:#1e293b;--anatomy-face:#243449;--anatomy-top:#273549;
  --anatomy-shade-0:#1a2739;--anatomy-shade-1:#1f2e44;--anatomy-shade-2:#243349;--anatomy-shade-3:#283a52;
  --anatomy-lit-top:#155e57;--anatomy-lit-shade:#114c47;
  --anatomy-hi:#f1f5f9;--anatomy-mid:#94a3b8;--anatomy-lo:#64748b;--anatomy-faint:#334155;
  --anatomy-lit:#2dd4bf;
  --anatomy-halo:#05080f;--anatomy-halo-opacity:.7;--anatomy-dot:#f1f5f9;
}`;

export const themeCss = (theme) => (theme === "light" ? LIGHT : DARK);

// La bancada usa el gris de superficie de DESIGN.md, para que las máquinas
// blancas se lean sobre un plano con tono en vez de sobre otra superficie blanca.
export const FIGURE_CSS = `
.iso-pad>.iso-top{fill:var(--fig-pad)}
.iso-pad>.iso-fill{fill:var(--fig-pad)}
.iso-pad>.iso-bevel{stroke:var(--anatomy-lo)}
.iso-liquid{}.iso-liquid>.iso-top,.iso-liquid>.iso-fill{fill:var(--fig-liquid)}
.iso-trace{stroke-width:3.2;stroke-linecap:round;stroke-linejoin:round}
`;
