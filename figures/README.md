# Figuras de las unidades

Figuras isométricas que ilustran "El concepto en 1 minuto" de cada lab. Se
generan aparte de Flutter y se importan como **WebP animado** (claro y oscuro,
un archivo por figura y tema); el WebP **no lleva texto**: título, leyenda y
descripción viven en Dart para que sean seleccionables, traducibles y con el
color del tema.

Cada figura es un objeto real cuyo mecanismo *es* el concepto, y su movimiento
explica la misma idea: en D01 los tres cabezales bajan **a la vez** cuando
comparten motor y **cada uno a su ritmo** cuando cada uno lleva el suyo; en ML
las dos plumas dibujan sus curvas a la vez; en Monitoring la cinta corre bajo
las plumas; en D02 el molde se abre y se cierra; en D04 la capa que cambia se
levanta. D07 se queda quieta: un nivel de depósito no gana nada moviéndose.

| Objetivo | Figura | Objeto | Movimiento |
|---|---|---|---|
| `M08-D01-containers` | `d01-shared` · `d01-own` | banco de taladros: un motor y tres cabezales / uno por cabezal | los cabezales taladran, juntos o por separado |
| `M08-D02-lifecycle` | `d02-mould` | molde reutilizable y pieza que se va | la tapa sube y baja |
| `M08-D04-dockerfile` | `d04-layers` | pila de capas bajo brida y bandeja de capas reutilizadas | la capa que cambia se levanta |
| `M08-D07-persistence` | `d07-persistence` | bandeja seca, depósito con nivel y tubo que sale del banco | quieta |
| `M02-U02-cleaning` | `data-checkweigher` | cinta de inspección: huecos, duplicado, fuera de rango | la aguja tiembla contra el tope |
| `M03-U02-generalization` | `ml-plotter` | trazador de dos plumas sobre papel cuadriculado | las plumas dibujan; la brida vuelve al origen |
| `M06-U04-drift` | `monitor-recorder` | registrador de cinta: deriva y escalón | la cinta se escribe y vuelve a empezar |

## Generar los assets

```powershell
cd figures
node shoot.mjs                 # todas: WebP claro y oscuro en frontend/assets/figures/
node shoot.mjs d01             # solo una familia
node shoot.mjs --verify        # además comprueba que ninguna línea queda en el aire
```

Salida: `frontend/assets/figures/<figura>-light.webp` y `-dark.webp`. Después,
en Flutter: `flutter test test/ui/labs/concept_figure_test.dart` (falla si un
objetivo del mapa no tiene sus dos WebP).

`node <figura>/build.mjs [--light]` escribe además `out/<figura>.html`, la
página de revisión (leyenda, lectura, tamaño de tarjeta) para mirarla antes de
exportar. El movimiento es determinista: la página expone `window.__pose(t)` y
`shoot.mjs` la llama fotograma a fotograma (24-26 por figura, 14 fps), así que
el WebP no depende del reloj de la máquina. Se monta con Pillow vía `uv`
(`encode.py`).

## Reglas que siguen

- Un solo acento (`lit`) por figura: la pieza que hay que mirar.
- Nada de texto dentro del dibujo salvo lo que la máquina muestra de verdad.
- Las líneas acaban en una arista, un trazo o un punto (lo comprueba `--verify`).
- Las texturas (estriados, reglas, rejillas) acaban en un borde o se desvanecen.
- El primer fotograma es el cartel: la figura completa, no un estado a medias.
- Movimiento calmado y en bucle sin saltos: lo que se desvanece vuelve a
  empezar cuando ya no se ve.
- `figures/theme.mjs` fija los tokens a `DESIGN.md`: la "paper" de la figura es
  el color de la `Card` de Flutter (`#FFFFFF` / `#1E293B`).

Requiere Node 22, Chrome y `uv`; la captura usa `scripts/drive.mjs` de la skill
`anatomy` (ruta en `ANATOMY_SKILL` si no está en la de por defecto).
