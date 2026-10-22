# Figuras de las unidades

Figuras isométricas que ilustran "El concepto en 1 minuto" de cada lab. Se
generan aparte de Flutter y se importan como PNG (claro y oscuro); el PNG **no
lleva texto**: título, leyenda y descripción viven en Dart para que sean
seleccionables, traducibles y con el color del tema.

Cada figura es un objeto real cuyo mecanismo *es* el concepto:

| Objetivo | Figura | Objeto |
|---|---|---|
| `M08-D01-containers` | `d01-shared` · `d01-own` | banco de taladros: un motor y tres cabezales / uno por cabezal |
| `M08-D02-lifecycle` | `d02-mould` | molde reutilizable y pieza que se va |
| `M08-D04-dockerfile` | `d04-layers` | pila de capas bajo brida y bandeja de capas reutilizadas |
| `M08-D07-persistence` | `d07-persistence` | bandeja seca, depósito con nivel y tubo que sale del banco |
| `M02-U02-cleaning` | `data-checkweigher` | cinta de inspección: huecos, duplicado, fuera de rango |
| `M03-U02-generalization` | `ml-plotter` | trazador de dos plumas sobre papel cuadriculado |
| `M06-U04-drift` | `monitor-recorder` | registrador de cinta: deriva y escalón |

## Generar los assets

```powershell
cd figures
node shoot.mjs                 # todas: PNG claro y oscuro en frontend/assets/figures/
node shoot.mjs d01             # solo una familia
node shoot.mjs --verify        # además comprueba que ninguna línea queda en el aire
```

Salida: `frontend/assets/figures/<figura>-light.png` y `-dark.png`. Después,
en Flutter: `flutter test test/ui/labs/concept_figure_test.dart` (falla si un
objetivo del mapa no tiene sus dos PNG).

`node <figura>/build.mjs [--light]` escribe además `out/<figura>.html`, la
página de revisión (leyenda, lectura, tamaño de tarjeta) para mirarla antes de
exportar.

## Reglas que siguen

- Un solo acento (`lit`) por figura: la pieza que hay que mirar.
- Nada de texto dentro del dibujo salvo lo que la máquina muestra de verdad.
- Las líneas acaban en una arista, un trazo o un punto (lo comprueba `--verify`).
- Las texturas (estriados, reglas, rejillas) acaban en un borde o se desvanecen.
- `figures/theme.mjs` fija los tokens a `DESIGN.md`: la "paper" de la figura es
  el color de la `Card` de Flutter (`#FFFFFF` / `#1E293B`).

Requiere Node 22 y Chrome; la captura usa `scripts/capture.mjs` de la skill
`anatomy` (ruta en `ANATOMY_SKILL` si no está en la de por defecto).
