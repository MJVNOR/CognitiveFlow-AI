# CognitiveFlow AI — Plan de rediseño de tareas, laboratorios y motion UX (Flutter)

**Fecha:** 17 de octubre de 2026  
**Destino:** agente de programación OpenCode  
**Estado:** propuesta de implementación; **no implica que los cambios estén hechos**.  
**Fuente inspeccionada:** archivo del usuario `frontend(1).rar`, específicamente `lib/`, `test/` y `pubspec.yaml`. No se recibió el backend en este archivo, por lo que las modificaciones de API deberán contrastarse con el repositorio completo.

> **Directiva:** continuar el proyecto actual sin reiniciar Flutter, borrar estado, modificar silenciosamente API/backend o perder avances. La plataforma no debe presentar tareas como una larga colección de formularios. Cada actividad debe sentirse como una experiencia guiada, interactiva, comprensible y adaptada. Incorporar `flutter_animate` con criterios de accesibilidad, rendimiento y significado pedagógico.

## 0. Diagnóstico fundamentado en el frontend entregado

### Archivos existentes y qué conservar

| Archivo | Estado observado / responsabilidad | Decisión |
|---|---|---|
| `pubspec.yaml` | Flutter, `genui: ^0.10.4`, `a2ui_core`, `flutter_riverpod`, `fl_chart`, `go_router`; **no aparece `flutter_animate`** | Incorporar `flutter_animate` tras verificar compatibilidad; preservar lockfile |
| `lib/ui/labs/docker_lab_page.dart` | D01, D02, D04 y D07 en chips; `ConceptPrimer`, `TutorSurface`, campo de justificación, `ResultPanel`, acceso al postest | Convertir a flujo de actividad por estado, no apilar todos los bloques |
| `lib/ui/labs/widgets/lab_chrome.dart` | `LabHeader` y `LabSteps` mediante `Wrap` y texto pequeño | Reemplazar por navegación/stepper responsivo con objetivo y fase reales |
| `lib/ui/labs/widgets/result_panel.dart` | Rúbricas, feedback, preguntas, botón para siguiente actividad en columna lateral | Separar tutor/contexto, resumen de feedback y detalle de rúbrica bajo demanda |
| `lib/ui/tutor/widgets/docker_widgets.dart` | Widgets GenUI reales: `ContainerVsVmExplorer`, `ImageContainerLifecycle` y otros | Preservar lógica, rediseñar interacción/semántica/eventos |
| `lib/ui/tutor/widgets/ml_widgets.dart` | Parte del catálogo sigue usando `_simpleCard` para SQL, DAG, mapa y otros | No anunciar como interactividad completa; priorizar catálogo pequeño realmente funcional |
| `lib/ui/tutor/tutor_surface.dart` y `widgets/events.dart` | Render de GenUI y envío de eventos | Conservar adaptador y completar ciclo de eventos según contrato real |
| `lib/ui/labs/view_models/lab_session.dart` y `lab_session_viewmodel.dart` | Estado de sesión, intentos, postest, reanudación | Preservar y añadir modelo visual derivado sin duplicar fuente de verdad |
| `lib/ui/labs/ml_lab_page.dart`, `data_lab_page.dart`, `monitor_lab_page.dart` | Tres labs existentes con acciones y paso al postest | Migrar gradualmente al workspace compartido |
| `lib/ui/core/themes/cognitive_theme.dart` | Tema general | Reutilizar DESIGN.md, no reinventar identidad |
| `test/ui/tutor/`, `test/ui/labs/`, `test/ui/core/` | Pruebas existentes | Ampliar sin eliminar pruebas |

### Problemas específicos observados

1. `DockerLabPage` renderiza en el mismo scroll `LabHeader`, `ConceptPrimer`, selector de unidad, `TutorSurface` y textarea de justificación: **el alumno ve demasiados objetivos a la vez**.
2. `ContainerVsVmExplorer` tiene `Enviar clasificación`, mientras la página tiene `Enviar intento`: **dos entregas potencialmente ambiguas**. Separar *registrar predicción/selección* de *entrega final de justificación*, usando una CTA canónica por fase.
3. D01/D02/D04/D07 se ofrecen como chips intercambiables dentro de una sesión: **parecen modos de un experimento, no unidades con prerrequisitos, progreso y dominio propio**.
4. La columna derecha es principalmente `ResultPanel` y puede presentar puntuaciones y acción de siguiente actividad. **Debe ser primero un tutor contextual**, no una caja de notas.
5. La actividad generada por el agente puede terminar representada como tarjeta pequeña dentro de otra tarjeta; **el siguiente reto debe reemplazar el escenario experimental central**, preservando evidencia e historial.
6. `LabSteps` deriva del `step` general y mantiene cuatro etiquetas constantes; **la UI debe distinguir lección, actividad, feedback, intervención y prueba independiente según transiciones autorizadas**.
7. `go_posttest` aparece tras evaluaciones/intervenciones; **la entrada al postest debe depender de elegibilidad server-side**, no solo de que exista una evaluación.
8. Layout actual `maxWidth: 1100` con sidebar desde breakpoint `>=1100` dentro del contenedor: en determinados tamaños reales no se logra una distribución cómoda; redefinir layout con pruebas de viewport.
9. Las animaciones todavía no están orquestadas mediante un sistema de movimiento común. No resolver esto agregando `.animate()` indiscriminadamente.
10. El documento aportado contiene solo frontend: **no afirmar funcionamiento completo de Gemini/Jev, desbloqueo server-side o nuevas rutas API sin inspeccionar el backend**.

## 1. Principios de UX educativa obligatorios

- El alumno **siempre sabe** qué está aprendiendo, para qué sirve, qué debe hacer ahora y qué evidencia obtuvo.
- Una sola **acción primaria** por fase. Las interacciones internas pueden tener controles propios, pero jamás competir con una segunda acción primaria global.
- Mostrar primero explicación guiada cuando el diagnóstico detecta desconocimiento; desafíos autónomos para quien ya domina conceptos.
- Separar **predecir → experimentar → observar → justificar → recibir feedback → nuevo desafío → transferencia/postest**. No todas las unidades requieren todas las fases ni en la misma cantidad; es una máquina de estados flexible.
- Las ayudas se revelan gradualmente. No bloquear explicaciones para siempre ni confundir esfuerzo innecesario con aprendizaje.
- Evaluación Jev: descriptiva y posterior al intento; números solo bajo detalles. No mostrar 0/4 antes de responder.
- Una intervención es un **nuevo objeto de actividad** con `activity_id`, objetivo, widget, reglas y evidencia; no un cambio cosmético de la pregunta.
- El profesor **solo consulta** resultados, progreso, evaluaciones e historial; **sin comentarios, sliders, asignaciones ni edición de notas**.
- Progreso de pasos ≠ competencia demostrada; dominio solo con criterios definidos y postest/pruebas independientes.
- `DESIGN.md` es fuente de verdad de color y accesibilidad: azul `#2457C5`, teal `#0F766E`, ámbar `#A65B00`. No usar exclusivamente color para señalar información.
- Animación funcional y calmada; respetar preferencia de movimiento reducido.

## 2. Nueva arquitectura de experiencia en Flutter

### 2.1 Rutas conceptuales

`Academia → Módulo → Unidad → Lección / Actividad → Feedback / Adaptación → Postest → Reflexión`.

No cambiar rutas existentes hasta mapear los deep links y tests. El estado de unidad lo determina el backend; los widgets solo presentan la fase permitida.

### 2.2 Workspace escritorio

```text
┌──────────────────────────────────────────────────────────────────────────────────────┐
│ Academia › Docker › D01             Contenedor vs VM                 Unidad 1 / 12     │
│ Objetivo: distinguir tipos de aislamiento              progreso de actividad [----] │
├───────────────────────────────────────────────────┬──────────────────────────────────┤
│ ZONA PRINCIPAL (aprox. 68%)                       │ TUTOR CONTEXTUAL (aprox. 32%)   │
│                                                   │                                  │
│  Contexto breve: ¿por qué importa?                 │  En este paso estás...           │
│  [Ejemplo guiado / Recordar concepto]             │  Tu predicción actual           │
│                                                   │  [Pedir pista]                  │
│  ┌─────────────────────────────────────────────┐  │  Evidencia clave               │
│  │ ACTIVIDAD GENUI REAL                      │  │  Pregunta socrática            │
│  │ Escenarios grandes, decisiones y efectos  │  │  Tutor breve, no muro de chat  │
│  │ feedback visual de interacción             │  │                                  │
│  └─────────────────────────────────────────────┘  │  (feedback al terminar intento) │
│                                                   │                                  │
│  Tu predicción / justificación según fase         │                                  │
│  [Botón principal de esa fase]                     │                                  │
└───────────────────────────────────────────────────┴──────────────────────────────────┘
```

**Medidas iniciales propuestas (ajustables tras pruebas):** desktop ≥1200 px, 68/32 con panel lateral 320–380 px y mínimo 600 px para actividad; tablet 760–1199: área principal + tutor en panel lateral deslizable o `ExpansionTile` dedicado; móvil <760: una columna, CTA visible al pie del contenido, tutor como bottom sheet o panel expansible. Determinar breakpoint por espacio disponible **dentro del shell**, no viewport global únicamente.

### 2.3 Componentes Flutter reutilizables

Crear en `lib/ui/labs/workspace/` (nombres orientativos):

- `learning_workspace.dart`: `LearningWorkspace` y composición responsiva; no negocio.
- `learning_header.dart`: breadcrumb, objetivo, progreso real, nivel de ayuda; sin score.
- `learning_phase_indicator.dart`: stepper con fases habilitadas/terminadas, teclado y Semantics.
- `learning_stage.dart`: render de **una** fase central y `AnimatedSwitcher` controlado.
- `contextual_tutor_panel.dart`: hipótesis, pista, evidencia y pregunta según fase; sin duplicar widget de reto.
- `activity_action_bar.dart`: una CTA primaria; habilitación derivada del ViewModel.
- `next_challenge_card.dart`: previa y arranque de siguiente actividad **solo cuando el backend haya autorizado y definido la actividad**.
- `learning_feedback.dart`: fortaleza, evidencia observada, brecha y paso próximo; criterios numéricos en `ExpansionTile`.
- `concept_explainer.dart`: microlección, ejemplo resuelto y breve chequeo de comprensión.
- `motion/learning_motion.dart`: tokens y funciones de animación.

`LabSessionViewModel` o un presenter derivado expone `LearningViewState` inmutable; no introducir un segundo estado paralelo mutable. Considerar sealed classes Dart para fases `concept`, `prediction`, `experiment`, `justification`, `evaluating`, `feedback`, `intervention`, `posttest`, `reflection`; mapear los estados reales del servidor sin inventar transiciones locales autorizantes.

## 3. Rediseño del flujo de actividades

| Fase | Superficie central | Tutor lateral | CTA principal | Ausente de UI |
|---|---|---|---|---|
| Diagnóstico (si aplica) | 1–3 preguntas breves o actividad diagnóstica | Explica objetivo sin pistas resolutivas | Comprobar nivel | Puntajes futuros, postest |
| Aprender | Microlección visual + ejemplo concreto | Pregunta de recuperación simple | Explorar concepto | Rúbricas |
| Predecir | Hipótesis o selección antes del experimento | Invita a explicar razones | Registrar predicción | Solución |
| Experimentar | GenUI con controles y resultados en vivo | Pista puntual, cuando se solicite | Continuar a explicación | Scores, textarea duplicado |
| Justificar | Resumen de acciones/evidencias + respuesta | Recuérdale el objetivo sin resolver | Evaluar mi razonamiento | Postest temprano |
| Evaluación en curso | Vista central compacta de espera real | Sin cambiar contexto | Ninguna / reintentar tras fallo | Animación falsa de trabajo |
| Feedback | 1 fortaleza + 1 brecha comprobable | Pregunta socrática específica | Explorar nuevo desafío | Pantalla dominada por números |
| Intervención | Nuevo widget GenUI **en el área principal** | Explica qué aprenderá con el nuevo reto | La CTA de esa actividad | Tarjeta del mismo widget duplicada a derecha |
| Postest | Nueva variante autónoma | Desactivado u oculto | Entregar postest | Pistas, solución, evaluación en vivo |
| Reflexión | Transferencia, cambios de hipótesis, próximo repaso | Resumen breve | Volver a la unidad / siguiente unidad habilitada | Felicitación automática no sustentada |

### Política de botón primario

- `ContainerVsVmExplorer`: seleccionar escenarios **no es entrega final**. Durante exploración, usar `Registrar clasificación` como única CTA; luego se activa justificación en una fase siguiente.
- El componente GenUI puede emitir `selectionChanged` internamente sin mostrar un segundo `FilledButton` competidor.
- El botón principal de cada fase se orquesta desde `ActivityActionBar`, o se delega a un widget cuando ese widget sea la totalidad de la fase; nunca ambos.
- `posttest` no es un link global. Sólo aparece cuando el servidor responde `can_enter_posttest: true` o equivalente existente validado.
- Si el intento falla al guardar: conservar controles, evidencia y respuesta; mostrar `Reintentar envío` idempotente.

## 4. Contrato de actividad adaptativa (interno, NO A2UI oficial)

Verificar el esquema backend antes de implementarlo. Evolucionar el contrato actual sin romper sesiones guardadas ni tests:

```json
{
  "schema_version": 2,
  "activity_id": "docker-d01-contrast-002",
  "session_id": "<server-issued-id>",
  "unit_id": "M08-D01-containers",
  "phase": "intervention",
  "goal": "Distinguir aislamiento de contenedores y máquinas virtuales",
  "prerequisites": ["kernel", "sistema operativo"],
  "widget_type": "ContainerVsVmExplorer",
  "widget_props": {"scenario_set_id": "contrast-b"},
  "allowed_events": ["selectionChanged", "predictionSubmitted", "argumentSubmitted"],
  "evidence_required": ["categorization", "justification"],
  "help_policy": {"mode": "graduated", "max_hint_level": 3},
  "feedback_policy": "after_submission",
  "transition_policy": {"next_by_server_decision": true}
}
```

**Exigir** identidad de actividad y versión, propiedad de sesión, allowed events, deduplicación e idempotencia. El LLM propone objetivos/estrategias/widget autorizado, pero **backend valida** fase, esquema, unit id, límites y siguiente actividad. El alumno no puede forzar `posttest`, score, rol ni soluciones mediante payload. Adaptar al esquema A2UI real de `genui: ^0.10.4`; no enviar JSON interno directamente como si fuera A2UI.

### Generación pedagógica

- El currículo fija competencias, objetivos y prerrequisitos. Gemini **no inventa libremente el temario oficial**.
- Gemini propone actividad entre widgets aprobados usando fallos observables de Jev y verificadores deterministas.
- Jev evalúa criterios delimitados **después** de entregas; una probabilidad no es una nota de dominio.
- La intervención será visible en zona central y tendrá estado distinto, escenario nuevo y evidencia nueva.
- El tutor lateral explica brevemente *por qué este reto*, sin revelar la respuesta.
- Guardar el vínculo `previous_activity_id → intervention_activity_id`, motivación pedagógica breve y resultados.
- Variar escenarios, no repetir la misma tarjeta y texto con distinto título.

## 5. Docker Academy — rediseño concreto para las 12 unidades

**Estado verificado en frontend:** `docker_lab_page.dart` incluye **solo cuatro unidades** D01/D02/D04/D07. El currículo de doce unidades es **objetivo futuro**, no implementación presente. El agente debe dejar de mostrar las cuatro como chips mezclados dentro de una sola tarea; convertirlos en entradas del temario y tratar cada unidad como secuencia propia.

| Unidad | Concepto / microlección | GenUI que realmente practica | Evidencia de dominio / transferencia |
|---|---|---|---|
| D01 | Contenedor vs VM, kernel, aislamiento | `ContainerVsVmExplorer`: escenarios con explicación, comparación visual | Explica por qué una carga requiere VM o contenedor |
| D02 | Imagen, instancia, ciclo de vida | `ImageContainerLifecycle`: diagrama de transiciones animadas | Predice qué sobrevive a `stop`, `rm`, nuevo `run` |
| D03 | Docker CLI: `build/run/ps/logs/exec/rm` | Terminal **simulada**, elección/composición de comandos | Escoge comandos para diagnosticar un contenedor |
| D04 | Dockerfile: FROM/WORKDIR/COPY/RUN/CMD/EXPOSE | `DockerfileBuilder`: ordenar instrucciones, identificar capas | Construye un Dockerfile para FastAPI y detecta errores |
| D05 | Directorios, build context, `.dockerignore` | Árbol de archivos interactivo y simulador de build context | Excluye secretos/artefactos; explica COPY y rutas |
| D06 | Filesystem de contenedor, bind mounts, volumes | Sandbox de persistencia visual | Predice qué persiste tras recrear contenedor |
| D07 | Redes, puertos, DNS de servicios, localhost | Topología interactiva entre app/API/DB | Corrige conexión fallida y explica exposición de puertos |
| D08 | Compose: services, networks, env y volumes | `ComposeBuilder` con validación de configuración | Orquesta API + DB con volumen persistente |
| D09 | Debugging de contenedores | Consola/logs simulados con fallos causales | Diagnostica por qué no arranca un servicio |
| D10 | Registry y deploy de contenedores | Pipeline visual build→push→pull→run | Explica despliegue y diferencias local/servidor |
| D11 | Seguridad y optimización | Auditoría de Dockerfile y selección de mejoras | Identifica secretos, permisos, usuario root y capas |
| D12 | Capstone Docker | Simulador integral de arquitectura y debugging | Diseña/defiende contenedorización de una aplicación real |

### D01 — pantallas detalladas

1. **Aprender**: dos ilustraciones claras (contenedor comparte kernel del host; VM tiene guest OS/kernel), 2–3 diferencias esenciales. Ejemplo resuelto «Quiero correr una API FastAPI de forma reproducible». CTA `Probar con escenarios`.
2. **Predecir**: escenario nuevo individual «necesito un kernel distinto». Opción contenedor/VM con *razón obligatoria*. El tutor puede preguntar «¿qué necesitaría virtualizarse?». CTA `Registrar predicción`.
3. **Experimentar**: tres tarjetas grandes, **una a la vez** o carrusel sin respuesta revelada; comparación de capas del sistema al seleccionar. CTA `Comprobar mi clasificación`.
4. **Justificar**: resumen de tres decisiones; pedir una explicación anclada en kernel, aislamiento y requisitos. CTA `Evaluar mi razonamiento`.
5. **Feedback**: corregir concepciones comprobables. Si confunde kernel → activar **nuevo** `KernelContrastSimulation` (o variante de `ContainerVsVmExplorer`) con una comparación visual; si acierta sin evidencia → `EvidenceComparison` sobre procesos vs kernel. No repetir preguntas vagas.
6. **Postest**: escenario no visto; sin tutor, pistas o feedback previo. CTA `Entregar prueba independiente`.

### D02 / D04 / D06: microinteracciones distintivas

- **D02**: animar progresión de imagen/contendor con flechas y cambios de estado visual. Antes de `rm`, estudiante debe predecir qué se elimina; al pulsar se muestra resultado. No simular una ejecución real si es un motor educativo determinista.
- **D04**: bloques `FROM`, `WORKDIR`, `COPY`, `RUN`, `CMD` arrastrables **o** controles accesibles de subir/bajar como alternativa. Preview de Dockerfile, explicación de cada capa, indicadores de errores con texto. Verificar semántica (CMD vs RUN, EXPOSE no publica puertos).
- **D06**: dos contenedores visibles lado a lado con volúmenes y filesystem; botones `Crear archivo`, `Eliminar contenedor`, `Recrear`. Antes del resultado solicitar predicción. Mostrar qué cambia con bind mount vs volumen. **No ejecutar Docker real desde entradas arbitrarias del alumno**.

## 6. Otros tres laboratorios: migración pedagógica

### Data Detective

- Separar **explicación de patrones** (nulos, duplicados, unidades, outliers, leakage) y ejercicio.
- Tabla con headers fijos, filtros por columna y selección con feedback visual; mostrar a la derecha **evidencia recolectada**, no puntajes.
- Seleccionar anomalía no equivale a entenderla: pedir **categoría, posible causa y tratamiento**, incluyendo casos donde *no* se debe eliminar un outlier.
- Intervención: si confunde dato faltante y outlier, generar mini-tabla contrastiva nueva en la zona central.

### ML Experiment Lab

- Hacer una **predicción antes de cambiar sliders**, luego comparar hipótesis con curvas nuevas, registrar diferencias.
- Gráficas responsivas con tooltips, ejes legibles, leyendas diferenciadas por patrón, y tabla de datos alternativa.
- Feedback de Jev ligado a puntos de curva concretos; intervención: cambiar tamaño muestral o ejemplo de leakage.
- Evitar que un resultado de simulación sintética se anuncie como entrenamiento real.

### Model Monitoring Lab

- Separar drift de features, concept drift y degradación de métricas.
- Antes de mover changepoint, predecir dónde cambia distribución y qué evidencia valida la conclusión.
- Histogramas y series temporales distinguibles con leyenda y texto, zoom/selector de ventana y tabla accesible.
- Intervención: comparar dos situaciones distintas, una con drift sin caída de performance y otra con caída sin drift observable.

## 7. `flutter_animate` — sistema de movimiento, no decoración

### 7.1 Instalación y verificación

1. En el directorio frontend: `flutter pub add flutter_animate` (respetar restricciones y lockfile reales).
2. Verificar compatibilidad con SDK Flutter/Dart instalado mediante `flutter pub get`, `flutter analyze` y tests.
3. No añadir dependencias de motion adicionales salvo necesidad justificada. `AnimatedSwitcher`, `AnimatedSize`, `AnimatedContainer`, `TweenAnimationBuilder`, `Hero` y controladores nativos continúan disponibles.
4. Centralizar duración, curvas y reglas para todos los labs en `lib/ui/labs/workspace/motion/learning_motion.dart`.

### 7.2 Tokens de movimiento (propuesta inicial)

| Contexto | Efecto sugerido | Duración orientativa | Condición |
|---|---|---|---|
| Presentación de una fase nueva | fade + slide Y muy corto (8–12 px) | 180–240 ms | Una sola vez por transición real |
| Nuevo widget GenUI adaptativo | fade + scale sutil 0.98→1 | 220–280 ms | Preservar controles y foco |
| Expandir microlección/pista | `AnimatedSize` o equivalente | 180–220 ms | No mover al usuario inesperadamente |
| Seleccionar respuesta | transición de color/borde/check nativa | 120–160 ms | No parpadear ni hacer bounce |
| Confirmar evidencia guardada | check/fade suave | 160–220 ms | Solo tras confirmación backend |
| Feedback recibido | aparición escalonada **corta** (fortaleza→brecha→acción) | total ≤450 ms | No ocultar lectura por demora |
| Siguiente actividad disponible | transición del contenido central | 220–300 ms | Anunciar a lector de pantalla |
| Actualización gráfica | interpolación corta sin saltos | 200–300 ms | No animar todos los puntos en cada drag |
| Error de validación | borde/ayuda textual + focus | 120–180 ms | No shake insistente |
| Postest | transición sobria a modo concentración | 180–220 ms | Evitar efectos celebratorios |

**No** usar animaciones infinitas, rotaciones de panel, parallax innecesario, `bounce` en todos los botones, fades largos entre cada pregunta, ni animar la evaluación como si tuviera una duración ficticia.

### 7.3 Ejemplo Flutter ilustrativo

```dart
import 'package:flutter_animate/flutter_animate.dart';

Widget animatedActivity(Widget child, String activityId) {
  return KeyedSubtree(
    key: ValueKey(activityId),
    child: child
        .animate(key: ValueKey('enter-$activityId'))
        .fadeIn(duration: 220.ms)
        .slideY(begin: 0.025, end: 0, duration: 220.ms),
  );
}
```

**No copiar ciegamente:** el agente debe comprobar APIs exactas de la versión resuelta de `flutter_animate`; el cambio de identidad `activityId` debe animar una sola vez, no resetear formularios por reconstrucciones de Riverpod o slider drags.

### 7.4 Accesibilidad y rendimiento

- Detectar `MediaQuery.disableAnimationsOf(context)` / políticas de accesibilidad compatibles con SDK; cuando haya reducción de movimiento, eliminar slide/scale y dejar cambios instantáneos o fade mínimo, nunca ocultar contenido.
- Probar `textScaleFactor`/`textScaler`, `Semantics`, foco y teclado; no depender solo de un efecto animado para indicar éxito/error.
- Evitar animar listas completas, crear múltiples controladores por fila de dataset o disparar animación ante cada pixel de movimiento del slider.
- En gráficos, aplicar throttling/debounce apropiado **sin perder el evento final**, y preservar coherencia con el dato real.
- Evitar movimientos de layout que desplazan la caja de justificación mientras el alumno escribe.
- Probar 60 fps orientativo en máquina de desarrollo con Flutter DevTools (no prometerlo sin medición), capturar jank y frames lentos.
- Tests con animaciones deshabilitadas o usando `pumpAndSettle` cuando corresponda; no introducir flakiness.

## 8. Plan de implementación por PR (con criterios de aceptación)

### PR-UX01 — Línea base, estructura y evidencia

Evidencia: `docs/current-state-audit.md` §20 (2026-10-17).

- [x] Crear rama, registrar `git status`, versiones y árbol actual. (`main` ahead 1 `54bea7d`; sin rama nueva: un PR a la vez sobre main. Flutter 3.47.7 / Dart 3.13.5 / uv 0.11.16.)
- [x] Ejecutar `flutter analyze` (limpio), `flutter test` (71 passed), backend `pytest` (78 passed, 1 skipped); errores iniciales: ninguno.
- [ ] Captura del Docker D01 desktop/tablet/móvil — pendiente: sin navegador en este entorno (mismo límite que audit §17); se cubre con tests de viewport/overflow en UX02.
- [x] Levantar backend real si está disponible y revisar contratos/estados (audit §3; **no inventar endpoints**).
- [x] Documentar qué tipos GenUI funcionan y cuáles son `_simpleCard` (6 placeholders en `ml_widgets.dart:10`; resto reales en audit §20).
- **Aceptación:** ninguna funcionalidad eliminada (este paso solo toca docs); tabla de pruebas en audit §20; screenshots pendientes (ver punto 3).

### PR-UX02 — Workspace Flutter compartido

- [ ] Extraer `LearningWorkspace`, `LearningHeader`, `LearningPhaseIndicator`, `ContextualTutorPanel`, `ActivityActionBar`.
- [ ] Derivar `LearningViewState` de sesión existente, sin duplicar lógica backend.
- [ ] Mover evaluación detallada de la vista principal a detalles consultables tras intento.
- [ ] Eliminar postest temprano de vistas normales; respetar autorización backend.
- [ ] Implementar layouts desktop/tablet/móvil y tests de overflow.
- **Aceptación:** D01 tiene una actividad protagonista, tutor útil, una sola CTA y no muestra nota inicial.

### PR-UX03 — D01 como experiencia pedagógica completa

- [ ] Separar lección, predicción, experimento, justificación, feedback e intervención.
- [ ] Cambiar cards pequeñas de clasificador por escenarios grandes/visuales.
- [ ] Eliminar la doble entrega `Enviar clasificación` + `Enviar intento` dentro de la misma fase.
- [ ] Registrar eventos identificados por actividad, validar evidencias y persistir reanudación.
- [ ] Integrar **nuevo reto real** en panel central y probar su respuesta end-to-end.
- [ ] Comprobar postest independiente con nueva variante y sin tutor.
- **Aceptación:** estudiante completa D01 sin confundir pasos; siguiente actividad cambia interacción y evidencia, no solo título.

### PR-UX04 — Motion system

- [ ] Instalar `flutter_animate` y crear tokens compartidos.
- [ ] Animar únicamente transiciones de fases y widgets, pistas, confirmación de guardado y feedback.
- [ ] Probar reducción de movimiento, foco, reanudación y reconstrucciones Riverpod.
- [ ] Ejecutar DevTools profile básico, `flutter analyze`/`test`.
- **Aceptación:** las animaciones orientan y no retrasan ni distraen. No se pierden respuestas.

### PR-UX05 — D02/D04/D06 y catálogo Docker

- [ ] Crear páginas de unidad y prerrequisitos, no chips cambiantes dentro de una sesión.
- [ ] Implementar D02 lifecycle y D04 Dockerfile con UX visual y tareas de transferencia.
- [ ] Implementar D06 persistencia a partir del widget actual de persistencia que se debe localizar/validar; respetar nomenclatura real de IDs existentes.
- [ ] Documentar D03/D05/D07–D12 como backlog progresivo; no marcarlos terminados si solo tienen texto/placeholder.
- **Aceptación:** 3–4 unidades excelentes, en lugar de 12 pantallas ficticias.

### PR-UX06 — Migración de Data / ML / Monitoring

- [ ] Reutilizar Workspace sin reescribir motor de labs.
- [ ] Mover tutor y feedback a una jerarquía constante.
- [ ] Aplicar predicción antes del experimento cuando aporte valor.
- [ ] Convertir intervenciones de Gemini en nuevas actividades centrales.
- [ ] Probar sensores visuales, accesibilidad gráfica y modo postest.
- **Aceptación:** usuario reconoce el mismo patrón de trabajo en las cuatro familias de laboratorio.

### PR-UX07 — Academia, próxima tarea y profesor

- [ ] Mostrar unidades con estado real: por iniciar/en curso/pendiente de repaso/demostrado, requisitos y objetivos.
- [ ] Definir `next_activity` como sugerencia **server-side** con causa pedagógica y CTA clara.
- [ ] Implementar repaso espaciado configurable y tareas de transferencia; no inventar datos de aprendizaje.
- [ ] Cambiar Instructor a analytics exclusivamente **read-only**: estudiantes, unidades, progreso, habilidades, resultados Jev, historial y pre/post.
- [ ] Quitar sliders, campos de notas, aprobación y botones de escritura en Flutter; aplicar permisos de solo lectura también en backend sin destruir registros históricos.
- **Aceptación:** no existe un flujo que obligue al instructor a evaluar o comentar; el alumno tiene una siguiente actividad comprensible.

### PR-UX08 — Piloto, medición y release

- [ ] Pilotar D01, ML y un laboratorio adicional con los cuatro estudiantes (consentimiento, resultados exploratorios).
- [ ] Observar errores de navegación, fatiga, duración real, comprensión de pasos y necesidad de ayuda.
- [ ] Comparar desempeño antes/después sin asistencia y corrección de errores; no inferir eficacia generalizable desde n=4.
- [ ] Terminar QA responsive, accesibilidad, token usage, fallbacks, HTTPS y material de demo.
- **Aceptación:** juez puede aprender, manipular, justificar, recibir intervención y completar una prueba independiente sin ayuda del maestro.

## 9. Reglas estrictas para OpenCode

1. **Preservar commits, tareas cerradas, navegación, lógica de GenUI, Gemini/Jev, SQLite y pruebas existentes.** El archivo compartido es frontend: investigar backend en repo antes de modificar contratos.
2. Nunca reemplazar `_simpleCard` por una tarjeta más atractiva y marcarla como laboratorio interactivo.
3. **No hardcodear tareas generadas** como secuencia visual fingiendo personalización; el currículo mantiene objetivos fijos y el generador elige variantes entre widgets autorizados.
4. No asignar calificaciones iniciales 0 a un alumno que todavía no respondió.
5. El maestro solo consulta. No mantener UI vieja de revisión manual como acción principal.
6. Todo evento importante debe transportar ID de sesión/actividad, propiedades validadas y client_event_id idempotente.
7. No mostrar postest hasta autorización efectiva del servidor.
8. `flutter_animate` jamás debe reiniciar selección, perder foco, reproducir continuamente o bloquear pruebas.
9. Implementar un PR a la vez; entregar diff, capturas antes/después, tests y riesgos. No marcar `[x]` sin evidencia.
10. **No utilizar nano**; usar vim si hace falta un editor de terminal.

## 10. Orden inmediata para ejecutar

> Lee este plan y el `DESIGN.md` del repositorio. Comienza por PR-UX01 y PR-UX02. Antes de codificar, explica la transición entre pantallas y el modelo de estado usando archivos reales. Luego implementa el workspace compartido para Docker D01, con una única CTA, tutor lateral contextual, GenUI principal y feedback solo después del intento. Ejecuta pruebas. No implementes las doce unidades ni una capa de animación global hasta validar D01. Una vez estable, añade `flutter_animate` con los tokens de este documento. Actualiza el plan tras cada PR con pruebas y capturas.

## 11. Criterios de aceptación de demostración

- [ ] El alumno abre Docker D01 y sabe qué aprender y por qué antes de responder.
- [ ] Una sola CTA principal visible en cada fase.
- [ ] La actividad GenUI central es interactiva y su estado persiste.
- [ ] No hay score inicial de 0 ni enlace precoz al postest.
- [ ] Jev (o mock claramente etiquetado) evalúa solo tras entrega.
- [ ] Gemini/estrategia adaptativa produce una **actividad distinta**, que aparece en el panel principal y genera nuevos eventos.
- [ ] Tutor contextual entrega pista gradual y respeta postest.
- [ ] `flutter_animate` mejora las transiciones sin distraer ni perder estado, respeta reducción de movimiento.
- [ ] Desktop y móvil sin overflow, con teclado y lector de pantalla utilizables.
- [ ] Maestro observa avance y resultados sin poder editarlos.
- [ ] El ciclo completo es reanudable y está protegido por permisos backend.

---

### Nota sobre evidencia de esta auditoría

La revisión técnica se basa en fuentes **del frontend entregado**; no demuestra por sí sola que Gemini/Jev estén o no conectados en el backend actual. Los tamaños, duraciones, ejemplos JSON y nuevos widgets del plan son **propuestas de diseño**. El agente deberá comprobar API/SDK y registrar su implementación real antes de declararlos terminados.

## 12. Avance 2026-10-21 — Learning Studio + Data Detective (fases 1–3 del brief "Interactive Learning Studio")

**Hecho y verificado** (analyze limpio · frontend 97 passed, 1 skipped · backend 79 passed, 1 skipped · recorrido real en Chrome headless contra backend de smoke 8001 con BD temporal y proveedores en mock):

- `flutter_animate ^4.5.2`; tokens y entradas centralizados en `lib/ui/core/motion.dart` (`enterMission`/`enterNote`/`enterCheck`, respetan `disableAnimations`).
- Workspace `lib/ui/labs/workspace/`: `learning_studio.dart` (`LearningStudioScaffold` 70/30 ≥1080 px dentro del shell, tutor plegable en tablet/móvil, `StudioHeader`, `ActivityActionBar` 1 CTA), `mission_navigation.dart`, `contextual_tutor_panel.dart` (pistas graduadas → `hintRequested`, mudo en postest, sin «Promedio X»), `learning_feedback.dart` (bien / falta / investigar / siguiente; números solo en «Detalle de la rúbrica»).
- Data Detective (`data_lab_page.dart` reescrita + `lib/ui/labs/data/`): 6 misiones (explorar+hipótesis → detectar → explicar → limpiar+evaluar → reto GenUI → prueba), escena CustomPainter de línea de inspección (sensor↔columna, pieza↔fila), explorador con encabezado fijo/distribución/orden/filtro, inspector con comparación a mediana, banco de limpieza con verificación. Borradores por misión + restauración desde el último intento del servidor.
- Backend: `can_enter_posttest` aditivo en `GET /sessions/{id}` (intento evaluado + `argumentSubmitted`); intervención de datos con filas contrastivas reales (`_data_contrast_rows`: remediación con tus errores/omisiones, transferencia N1..N6 en otra tabla). GenUI `DataTableExplorer` con `rows` = etiqueta → tocar filas (modo ids-por-coma queda como respaldo).
- Shell: rail colapsable, marca + avatar de perfil. `TutorSurface` compara intervención por contenido (antes reiniciaba el widget en cada emit).
- Capturas: harness `test/screenshots/data_lab_screens_test.dart` (`--dart-define=SHOTS=<dir>`).

**Pendiente / riesgos explícitos:**
- `POST /sessions/{id}/posttest` aún no rechaza sesiones sin `can_enter_posttest` (solo UI); exige actualizar ~15 tests backend.
- La intervención la elige un motor de reglas (`select_intervention`); Gemini solo redacta la pregunta. «Gemini elige la actividad» = fase 4.
- Las respuestas al reto GenUI se guardan como eventos pero no se evalúan con Jev.
- `labs_data.generate` planta anomalías en los mismos ids para cualquier seed: el postest no es «no visto» en posición.
- Fases 5–8 (motion en otros labs, Docker sandbox, ML/Monitoring, QA a11y completa) sin empezar.

### 12.1 Verificación con marionette + dart MCP (2026-10-21, sesión 2)

Recorrido vivo en `flutter run -d web-server` (debug) con marionette: login → Data Detective → escena (sensor P1 = 999.9 kPa, pieza 25 resaltada) → hipótesis → clasificar fila 7 → explicar → limpiar → evaluar (estado real «Evaluando…») → feedback → hot restart (reanuda en misión 4 con evidencia del servidor). Modo oscuro revisado. `get_runtime_errors`: ninguno. Tests: frontend 98 passed · backend 80 passed.

Corregido a partir de lo observado en vivo:
- **Gate del postest por widget** (`helpers._can_enter_posttest`): antes exigía `argumentSubmitted`; `HypothesisEditor`, `LearningCurveSimulator`, `PersistenceExperiment` y el respaldo `SocraticQuestionCard` nunca lo emiten ⇒ alumno atascado. Ahora cuenta el evento de entrega que ese widget emite; si no tiene entrega, basta la intervención. Test `test_posttest_gate_uses_each_widget_submit_event`.
- Feedback coherente: usa `fortaleza`/`brecha` del backend; el `texto` solo si `provider == gemini` (el mock contradecía el bloque de brecha).
- Reanudar restaura la última pregunta socrática desde `tutor-history` (sin nuevas llamadas al LLM).
- Inspector junto a la tabla desde 780 px; columna `unit` sin truncar; leyenda de la escena anuncia la pieza seleccionada (liveRegion).

Límites de herramientas: obscura bloquea `localhost` sin `OBSCURA_ALLOW_PRIVATE_NETWORK=1`; `set_device_config` de marionette requiere envolver la app en `MarionetteDeviceConfig` (no hecho); `scroll_to`/`get_logs` de marionette fallan en web (se usó `swipe`).

### 12.2 Fases 4–8 (ronda «haz todo», 2026-10-22)

**Fase 4 — GenUI adaptativo (backend):**
- [x] `POST /sessions/{id}/posttest` rechaza (403) si `can_enter_posttest` es falso. Tests usan `_unlock_posttest`; nuevo `test_posttest_refused_until_server_gate_opens`.
- [x] Permiso por **evento de entrega real** de cada widget (`interventions.SUBMIT_EVENT`, verificado contra los `TutorEvents.send` de Flutter en `test_submit_events_match_what_flutter_widgets_emit`). Widgets sin entrega (SocraticQuestionCard, tarjetas simples) habilitan al mostrarse. Corrige retos que nunca abrían la prueba (ContainerVsVmExplorer, DockerfileWorkbench, ImageContainerLifecycle).
- [x] Solo cuentan entregas **posteriores** al reto (`submits_before` en `intervention_log.spec_json`; sin cambio de esquema). Docker usa el mismo widget en práctica y reto.
- [x] Gemini **elige** entre dos actividades construidas por el servidor (`remediate`/`transfer`) solo en zona ambigua (promedio 1.5–3.5); salida validada (choice ∈ set, motivo sin números). Fallo/sin clave → reglas. `decided_by` queda en el log. 3 tests con Gemini simulado.
- [x] La entrega del reto contrastivo de datos se corrige en el servidor (`check_data_contrast`): `{correctas, revisar}` sin revelar el tipo; un par duplicado se resuelve marcando una copia. Respuesta de `/events` con campo aditivo `check`; se guarda en el payload (`server_check`).
- [x] Variantes del postest ya no repiten posiciones: Data (semilla≠1 mueve filas plantadas) y Monitoring (otra feature, punto y sentido). Práctica (semilla 1) idéntica. `series_by_feature` aditivo.

**Fases 5–7 — Studio en todos los labs:**
- [x] Piezas compartidas `workspace/studio_stages.dart` (estado de misiones, StudioCard, MissionIntro, ScenarioStage con corrección del servidor, reglas/cierre del postest). Data Detective las usa.
- [x] ML (`ml/ml_missions.dart`): predecir (sin curvas) → experimentar (marcar época/corrida) → justificar → reto → prueba.
- [x] Monitoring (`monitor/monitor_missions.dart`): observar y predecir → comparar + marcar feature/punto → decidir → reto → prueba. Centro ponderado del histograma (antes promediaba conteos). `AccessibleSeriesChart` con unidades reales y marca del punto de cambio (antes línea plana en 1.0).
- [x] Docker Academy: unidades D01/D02/D04/D07 como **entradas del temario** en Academia (`?unit=`), sin chips; una sesión = una unidad; aprender → experimentar → justificar → reto → prueba. D03/D05/D06/D08–D12 marcadas «en preparación».
- [x] Eliminados `ResultPanel`, `LabHeader`/`LabSteps` y el link `go_posttest` (código muerto tras la migración).

**Fase 8 — QA en vivo (servidores propios 8001/8091, sin claves de Gemini):**
- [x] ML, Monitoring, Docker (390 px) y Data hasta reto + corrección servidor.
- [x] Bug a11y encontrado y corregido: al cambiar de misión, la semántica del área desplazable conservaba el offset previo (campos «fantasma» 350 px abajo). Ahora el área se recrea por misión (`stageKey`), sin `jumpTo`.
- Pendiente: lector de pantalla real, texto grande en vivo, perfil de rendimiento; progreso por unidad Docker en servidor (prerrequisitos hoy orientativos); `HypothesisEditor` ignora su parámetro de complejidad; reto de ML/Monitoring/Docker no se corrige en servidor (solo Data).

### 12.3 Planificador GenUI ampliado (AGENTS §3 actualizado)
- [x] `ACTIVITY_MENU` por lab: Data (`contrast_rows`, `new_table`, `revise_hypothesis`), ML (`compare_curves`, `predict_and_simulate`, `raise_complexity`), Monitoring (`drift_explorer`, `decide_action`), Docker (`unit_practice` con cualquier unidad implementada).
- [x] Gemini propone actividad + parámetros acotados (tipos de anomalía, complejidad/ruido, features, unidad); el backend valida cada uno contra su esquema y descarta lo inválido; los datos los genera el servidor.
- [x] El foco de tipos (delataría la respuesta) queda solo en `intervention_log.spec_json.private`; la corrección del reto lo usa. Se registran `activity` y `activity_params`.
- [x] Tests con Gemini simulado: menú en el prompt, parámetro fuera de rango descartado, actividad fuera del menú → reglas, motivo con números descartado, foco de Data sin fuga al cliente, validadores de Docker/Monitoring.
- Sigue: solo se consulta en la zona ambigua (promedio 1.5–3.5); fuera de ella deciden las reglas.

### 12.4 Cierre de pendientes (1–9)
- [x] **Retos corregidos en el servidor en los 4 labs** (`app/checks.py`): Data (filas), Docker (escenarios/reglas del Dockerfile/predicción), ML (curva elegida como evidencia, configuración del simulador, texto vía rúbrica mock), Monitoring (feature que deriva + texto). Formato `{correctas, revisar, item, consejo}` sin números ni respuesta; tarjeta genérica en `ScenarioStage`.
- [x] **Progreso por unidad Docker** sin cambio de esquema: `GET /me/docker-units` (unidad = `extra.unit` de los intentos). Academia muestra estado escrito por unidad y si el prerrequisito está cumplido (orientativo, no bloquea: piloto).
- [x] **Variantes Docker reales**: `app/labs_docker.py` genera escenarios por unidad+semilla (D01 casos, D02 paso a predecir, D04 Dockerfile distinto y desordenado, D07 dato a conservar); `GET /labs/{id}/docker-activity`. Práctica semilla 1, reto semilla+3, postest variante. Evaluación mock y corrección usan la verdad del servidor (no la observación del cliente).
- [x] **HypothesisEditor de ML** muestra las curvas de la complejidad del reto (enviadas por el servidor).
- [x] **Planificador consultado siempre** que hay evaluación; salvaguarda: promedio ≤ 1,5 no puede saltar a transferencia.
- [x] **Gemini real (9 llamadas)**: `_gemini_ask` tenía timeout de 10 s y el modelo configurado (`gemma-4-31b-it`, razona antes de responder) lo superaba ⇒ todo caía a reglas/mock en silencio (también preguntas socráticas). Timeout configurable `LLM_TIMEOUT_S` (30 s) + log del motivo. Resultado: ML y Docker devolvieron JSON válido aceptado; Data y Monitoring tardaron > 45 s.
- [x] **Accesibilidad**: tests de texto 150 %/200 % en 4 labs (desktop y 390 px) → overflow en leyendas de gráficos corregido; recorrido con Tab sin trampas; árbol de accesibilidad de Chrome sin controles sin nombre (se etiquetaron campos ya enviados).
- [x] **Rendimiento** (build de producción, Chrome headless): frames ~7 ms, p95 7,1 ms, ninguno > 33 ms al arrastrar complejidad o desplazar Data.
- [x] Hot reload aplicado en la app del usuario (hot restart falló: DWDS devolvió HTML).
- Pendiente: lector de pantalla real (NVDA), modelo LLM más rápido para no esperar ~30 s, revisión del panel instructor (UX07), piloto (UX08), commit.

### 12.5 Pendientes 2, 4–9 (tras commit 2151ef8)
- [x] **Instructor solo lectura también en backend**: `session_for_write` (403 a escrituras del instructor en eventos, intentos, evaluar, tutor, intervención, postest, reflexión); `POST /sessions` sin `student_id` del payload. Flutter: instructor que abre un lab → `/instructor`. Tests backend + widget (`instructor_page_test`).
- [x] **Prerrequisitos Docker exigidos**: servidor rechaza intentos con prerrequisito incompleto; academia «Bloqueada» + motivo; página con atajo a la unidad previa.
- [x] **D02 con variantes reales**: 7 secuencias de comandos (`pull/build`, `run`, `run --rm`, `stop`, `start`, `rm`, `rmi`) y paso a predecir variable; verdad simulada en servidor; el widget simula el estado tras predecir.
- [x] **Telemetría del planificador**: cada intervención guarda `planner {outcome, ms}` (ok / sin_clave / sin_respuesta / invalida / salvaguarda / sin_evaluacion); `GET /instructor/planner-stats` y tarjeta en el panel del instructor.
- [x] **Alembic**: ya estaba en uso (`upgrade_head`); AGENTS §4 corregido; `test_models_have_no_unmigrated_schema_changes` (excluye nulabilidad, documentado).
- [x] **Prueba de punta a punta con proveedores reales** (backend propio con `.env`, base nueva): ML evaluado por Jev + feedback/pregunta/planificador Gemini; Data con reto elegido por Gemini (`revise_hypothesis`) y corrección del servidor; postest habilitado. Encontrado y corregido: Markdown crudo en textos de Gemini y preguntas demasiado largas.
- [ ] **NVDA real**: no instalado en el equipo; sustituido por árbol de accesibilidad de Chrome (0 controles sin nombre) y tests de texto grande/teclado.
