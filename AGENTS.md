# CognitiveFlow AI — instrucciones para agentes

> **Fuentes de verdad (orden):** 1) código real + tests que pasan · 2) `PLAN_REDISENO_TAREAS_FLUTTER.md` (manda en UX Flutter/tareas/labs/motion) · 3) `PLAN.md` (arquitectura educativa/backend) · 4) `DESIGN.md` (tokens visuales) · 5) historial de avances. Ante discrepancia en Flutter, **gana el rediseño** y lo que interfiera **se quita** (ver §0.1).
> **Directiva rediseño:** continuar sin reiniciar Flutter, sin borrar estado/SQLite, sin modificar silenciosamente API/backend, sin perder avances. La plataforma NO es una colección de formularios: cada actividad es experiencia guiada, interactiva, comprensible y adaptada.

## 0. Directiva + qué se quita (interferencias eliminadas)

- **Se quita:** D01/D02/D04/D07 como chips intercambiables dentro de una sesión (parecían modos de un experimento). Ahora son **entradas del temario**, cada unidad su propia secuencia con prerrequisitos, progreso y dominio propio.
- **Se quita:** doble entrega `Enviar clasificación` (widget) + `Enviar intento` (página) en la misma fase. Una sola CTA por fase (ver §4).
- **Se quita:** columna derecha como `ResultPanel` caja de notas/scores + botón siguiente. Ahora es **tutor contextual** primero; resumen feedback + rúbrica numérica solo bajo demanda tras intento.
- **Se quita:** score inicial `0/4`, `0` a quien no respondió, y link global `go_posttest` / `Ir al postest`. Postest solo con `can_enter_posttest: true` server-side.
- **Se quita:** anunciar `_simpleCard` (SQL, DAG, mapa, etc.) como interactividad completa; no maquillarlo con tarjeta más bonita. Catálogo pequeño realmente funcional o backlog explícito.
- **Se quita:** tarjeta pequeña de "siguiente actividad" dentro de otra tarjeta. El siguiente reto **reemplaza el escenario central**, preservando evidencia/historial.
- **Se quita:** UI instructor con sliders, campos de notas, aprobación, comentarios, asignación, edición. Instructor **read-only** también en backend (sin destruir históricos). `instructor_reviews` queda como tabla histórica de solo lectura, no se escribe desde Flutter.
- **Se quita:** `.animate()` indiscriminado, bounce en todo, fades largos, parallax, animación infinita, shake insistente, animar evaluación con duración ficticia. Solo motion system §7.
- **Se quita:** marcar D03/D05/D07–D12 como terminados con texto/placeholder. Son backlog; 3–4 unidades excelentes > 12 ficticias.
- **Se quita:** `flutter run -d chrome`, `nano`, `python`/`pip` directos (ver §§1,5,9).

## 1. Python: siempre `uv` (nunca `python`/`pip` directos)

```powershell
cd backend
uv sync
uv run pytest -q
uv run python -m app.seed
uv run uvicorn app.main:app --reload --port 8000
```

## 2. Tests backend: prohibido gastar APIs reales

- `backend/.env` tiene **keys reales** y `load_dotenv()` las carga al importar `app.main`.
- Tests usan SQLite en memoria + fixture autouse `_no_live_llm` (fuerza mock Gemini).
- Todo test de `jev_*`/`socratic`/`socratic_question` usa HTTP simulado (`monkeypatch` sobre `httpx.post`) o setting `EVALUATOR_MODE`/`*_API_KEY` por env. Fallo de proveedor ⇒ `status: pending`, `criteria: []`, jamás scores.
- CI no tiene keys: nada puede depender de red.

## 3. Reglas de dominio (no negociables, ya filtradas por rediseño)

- `evaluation_results` es append-only; `instructor_reviews` es **histórico read-only** (no escribir desde Flutter; el maestro solo consulta).
- Catálogo GenUI cerrado: `backend/app/interventions.py::CATALOG` debe coincidir con `frontend/lib/ui/tutor/catalog.dart::cognitiveFlowWidgets`. Documentar qué tipos funcionan de verdad y cuáles son `_simpleCard`; nunca presentar `_simpleCard` como lab interactivo.
- `ui_spec` interna (`{type, version, parameters...}`) ≠ mensajes A2UI del wire (`{version: v0.9, createSurface|updateComponents}`); traducción vive en `frontend/lib/ui/tutor/tutor_surface.dart`. Conservar adaptador y completar ciclo de eventos según contrato real. No enviar JSON interno §4.1 como si fuera A2UI.
- Rúbricas mock etiquetadas (`evaluator: mock`); Jev real solo en ML (`EVALUATOR_MODE=jev`), datos/monitoreo usan mock determinista. Jev evalúa **después** de entregas, descriptivo primero; números solo en `ExpansionTile` bajo demanda. Una probabilidad no es nota de dominio.
- Auth demo: login por `user_id` (`s1-s4`, `i1`), token opaco en `auth_tokens` (sin passwords: solo piloto). Propiedad vía `session_for` (403 ajeno). Todo evento importante lleva `session_id` + `activity_id` + `client_event_id` idempotente + props validadas; backend valida fase/esquema/unit/límites/siguiente; el alumno no fuerza `posttest`, score, rol ni soluciones por payload. Deduplicar `client_event_id`, reanudar sin perder evidencia.
- Currículo fija competencias/objetivos/prerrequisitos; Gemini **no inventa temario**, propone actividad entre widgets aprobados usando fallos Jev + verificadores deterministas. No hardcodear tareas generadas como secuencia visual fingiendo personalización.
- **Planificador GenUI (Gemini, `interventions.py::ACTIVITY_MENU`):** en cada lab Gemini elige **una actividad del menú permitido de ese lab** (varios widgets del catálogo, no solo remediar/transferir) y propone **parámetros acotados** (p. ej. tipos de anomalía a contrastar, complejidad/ruido, features, unidad Docker). El backend valida actividad ∈ menú del lab y cada parámetro contra su esquema (rango, subconjunto, enum); lo inválido se descarta y se usa el valor por defecto; los datos (filas, escenarios, curvas) los genera siempre el servidor de forma determinista. Se consulta siempre que hay intento evaluado; salvaguarda: con promedio ≤ 1,5 se rechazan actividades de transferencia (tabla nueva, otra complejidad, decidir acción, otra unidad). Si Gemini falla, no hay clave o la propuesta no pasa la validación, deciden las reglas. La entrega de cada reto se corrige en el servidor (`app/checks.py`: qué está bien / qué revisar, sin números ni respuesta); los escenarios Docker salen de `app/labs_docker.py` con la verdad solo en el servidor. Se registra `decided_by` y los parámetros elegidos; lo que delate la respuesta (p. ej. tipos plantados) queda solo en el log del servidor, nunca en el payload al cliente. Gemini nunca emite A2UI ni JSON de UI directamente.
- Intervención = **nuevo objeto actividad** con `activity_id`, objetivo, widget, reglas, evidencia; nuevo escenario central + estado distinto + evidencia nueva; guardar `previous_activity_id → intervention_activity_id` + motivación breve + resultados. Tutor lateral explica *por qué este reto* sin revelar respuesta. Variar escenarios, no repetir misma tarjeta con distinto título.
- Progreso de pasos ≠ competencia; dominio solo con criterios definidos + postest/pruebas independientes. Postest: variante no vista, sin tutor/pistas/feedback, bloquea Gemini en backend.
- Repaso espaciado configurable (p. ej. 1/3/7 días punto de partida), transferencia a escenario nuevo, `assistance_level` guardado para interpretar resultados. Piloto n=4: no generalizar eficacia.

## 4. Esquema SQLite sin Alembic (deuda explícita)

- `Base.metadata.create_all` no altera tablas existentes: un cambio de modelo exige borrar `backend/cognitiveflow.db*` + `seed` (solo con API apagada; en Windows el archivo se bloquea mientras un servidor lo tiene abierto).
- Seed demo: 8 módulos, 5 usuarios, 3 labs (`uv run python -m app.seed`).

## 5. Frontend (Flutter 3.47.7, web)

```powershell
cd frontend
flutter pub get
flutter run -d web-server --web-port 8080 --dart-define=API_BASE_URL=http://localhost:8000
flutter analyze --no-pub; flutter test; flutter build web
```

- `flutter run -d chrome` no funciona en este equipo: usar `web-server`.
- **REGLA: todo texto visible es seleccionable** (`SelectionArea` global en `MaterialApp.router.builder`). No usar `Text` fuera de ella.
- `genui 0.10.4` fijado en `pubspec.lock`; builders usan `BoundString` + `CatalogItemContext`; `Surface` se obtiene con `controller.contextFor(id)`.
- Backend con `CORSMiddleware` (orígenes `CORS_ORIGINS` + regex loopback cualquier puerto) ⇒ el login web funciona; verificado con smoke vivo.
- **Estado global con Riverpod (`flutter_riverpod`):** `lib/core/auth/auth_state.dart` (`authProvider`), `lib/ui/core/themes/cognitive_theme.dart` (`themeModeProvider`); `lib/config/routing/router.dart` (`routerProvider`) se recrea al cambiar auth; `lib/main.dart` solo bootstrap (`lib/app/app.dart`). Lo local de labs/charts/forms sigue en `setState`; borradores en `SharedPreferences` (`draft:<labId>:<campo>`, se limpian al cerrar reflexión). No meter labs/GenUI/fetch en providers sin motivo.
- **`DESIGN.md` es fuente de verdad visual:** azul `#2457C5` (CTA/navegación), teal `#0F766E` (experimentos), ámbar `#A65B00` (preguntas/reflexión). Neutros dominantes. No usar solo color para informar; WCAG 2.2 AA, foco visible, teclado + `Semantics`. No usar ámbar automáticamente para «error».
- No cambiar rutas existentes hasta mapear deep links + tests. Jerarquía conceptual: `Academia → Módulo → Unidad → Lección/Actividad → Feedback/Adaptación → Postest → Reflexión`. El estado de unidad lo determina el backend; widgets solo presentan la fase permitida.

### 5.1 Principios UX educativa (obligatorios)

1. El alumno siempre sabe qué aprende, para qué sirve, qué debe hacer ahora y qué evidencia obtuvo.
2. Una sola **acción primaria** por fase. Controles internos del widget jamás compiten con segunda CTA global.
3. Diagnóstico ⇒ desconocimiento = explicación guiada primero; dominio = desafío autónomo.
4. Fases flexibles (no todas en toda unidad): **predecir → experimentar → observar → justificar → feedback → nuevo desafío → transferencia/postest**.
5. Ayudas graduales (intento autónomo → pista → evidencia señalada → ejemplo análogo → explicación directa si persiste bloqueo o se solicita). No bloquear explicaciones para siempre; no confundir esfuerzo innecesario con aprendizaje. No castigar pedir ayuda.
6. Evaluación descriptiva post-intento; números solo bajo detalles. Intervención = actividad nueva (ver §3).
7. Profesor solo consulta (estudiantes, unidades, progreso, habilidades, Jev, historial, pre/post). Sin comentarios/sliders/asignaciones/edición.
8. Animación funcional y calmada; respetar movimiento reducido (§7).

### 5.2 Workspace compartido `lib/ui/labs/workspace/`

- Layout desktop ≥1200px: 68/32, lateral 320–380px, mínimo 600px para actividad. Tablet 760–1199: principal + tutor en panel deslizable o `ExpansionTile` dedicado. Móvil <760: una columna, CTA visible al pie, tutor como bottom sheet/panel expansible. Breakpoint por espacio **dentro del shell**, no solo viewport global. Base anterior `maxWidth: 1100` con sidebar `>=1100` no daba distribución cómoda: redefinir + tests de viewport/overflow.
- Estructura: header (breadcrumb `Academia › Módulo › Unidad`, objetivo, progreso real de actividad, nivel ayuda; sin score) · zona principal (contexto breve + GenUI real grande + predicción/justificación según fase + CTA) · tutor contextual (en este paso estás…, predicción actual, pedir pista, evidencia clave, pregunta socrática breve; feedback solo tras intento).
- Componentes (nombres orientativos, no negocio en ellos): `learning_workspace.dart` (`LearningWorkspace` + composición responsiva), `learning_header.dart`, `learning_phase_indicator.dart` (stepper fases habilitadas/terminadas, teclado + Semantics), `learning_stage.dart` (render de **una** fase + `AnimatedSwitcher` controlado), `contextual_tutor_panel.dart` (sin duplicar widget de reto), `activity_action_bar.dart` (una CTA, habilitación derivada del VM), `next_challenge_card.dart` (previa + arranque **solo si backend autorizó y definió actividad**), `learning_feedback.dart` (1 fortaleza + evidencia + 1 brecha comprobable + próximo paso; números en `ExpansionTile`), `concept_explainer.dart` (microlección + ejemplo resuelto + chequeo), `motion/learning_motion.dart` (tokens §7).
- Estado: `LabSessionViewModel` o presenter derivado expone `LearningViewState` inmutable; sin segundo estado paralelo mutable. Sealed classes sugeridas: `concept, prediction, experiment, justification, evaluating, feedback, intervention, posttest, reflection`. Mapear estados reales del servidor **sin inventar transiciones locales autorizantes**.

### 5.3 Flujo de fases (central | tutor | CTA | ausente)

| Fase | Central | Tutor | CTA | Ausente |
|---|---|---|---|---|
| Diagnóstico | 1–3 preguntas breves | objetivo sin pistas resolutivas | Comprobar nivel | puntajes futuros, postest |
| Aprender | microlección visual + ejemplo | pregunta recuperación simple | Explorar concepto | rúbricas |
| Predecir | hipótesis/selección pre-experimento | invita a dar razones | Registrar predicción | solución |
| Experimentar | GenUI con controles + resultados en vivo | pista puntual si se pide | Continuar a explicación | scores, textarea duplicado |
| Justificar | resumen acciones/evidencias + respuesta | recuerda objetivo sin resolver | Evaluar mi razonamiento | postest temprano |
| Evaluando | espera compacta real | sin cambiar contexto | ninguna / Reintentar tras fallo | animación falsa de trabajo |
| Feedback | 1 fortaleza + 1 brecha | socrática específica | Explorar nuevo desafío | pantalla dominada por números |
| Intervención | **nuevo GenUI en área principal** | qué aprenderá con el reto | CTA de esa actividad | tarjeta duplicada a la derecha |
| Postest | variante autónoma nueva | desactivado/oculto | Entregar prueba | pistas, solución, eval en vivo |
| Reflexión | transferencia, cambio hipótesis, repaso | resumen breve | Volver a unidad / siguiente habilitada | felicitación no sustentada |

Política CTA: `ContainerVsVmExplorer` usa `Registrar clasificación` en exploración (no es entrega final); justificación en fase siguiente. GenUI puede emitir `selectionChanged` interno sin segundo `FilledButton` competidor. `ActivityActionBar` orquesta la CTA, o se delega al widget si él es toda la fase; nunca ambos. Si el envío falla: conservar controles/evidencia/respuesta + `Reintentar envío` idempotente.

### 5.4 Contrato actividad adaptativa (interno, NO A2UI; verificar esquema backend, no romper sesiones/tests)

```json
{"schema_version": 2, "activity_id": "docker-d01-contrast-002", "session_id": "<server-issued-id>", "unit_id": "M08-D01-containers", "phase": "intervention", "goal": "Distinguir aislamiento de contenedores y máquinas virtuales", "prerequisites": ["kernel", "sistema operativo"], "widget_type": "ContainerVsVmExplorer", "widget_props": {"scenario_set_id": "contrast-b"}, "allowed_events": ["selectionChanged", "predictionSubmitted", "argumentSubmitted"], "evidence_required": ["categorization", "justification"], "help_policy": {"mode": "graduated", "max_hint_level": 3}, "feedback_policy": "after_submission", "transition_policy": {"next_by_server_decision": true}}
```

### 5.5 Docker Academy (4 implementadas D01/D02/D04/D07; 12 es objetivo futuro)

| U | Microlección | GenUI real | Evidencia / transferencia |
|---|---|---|---|
| D01 | contenedor vs VM, kernel, aislamiento | `ContainerVsVmExplorer` | explicar por qué carga pide VM o contenedor |
| D02 | imagen, instancia, ciclo de vida | `ImageContainerLifecycle` (transiciones animadas) | predecir qué sobrevive a `stop/rm/run` |
| D03 | CLI `build/run/ps/logs/exec/rm` | terminal **simulada** | elegir comandos para diagnosticar |
| D04 | FROM/WORKDIR/COPY/RUN/CMD/EXPOSE | `DockerfileBuilder` (ordenar, capas) | Dockerfile FastAPI + detectar errores |
| D05 | build context, `.dockerignore` | árbol interactivo + simulador context | excluir secretos/artefactos; explicar COPY |
| D06 | filesystem, bind mounts, volumes | sandbox persistencia visual | predecir qué persiste tras recrear |
| D07 | redes, puertos, DNS, localhost | topología app/API/DB | corregir conexión + explicar puertos |
| D08 | Compose services/networks/env/volumes | `ComposeBuilder` con validación | orquestar API+DB con volumen |
| D09 | debugging | consola/logs simulados causales | diagnosticar por qué no arranca |
| D10 | registry y deploy | pipeline build→push→pull→run | explicar deploy local vs servidor |
| D11 | seguridad y optimización | auditoría Dockerfile | secretos, root, permisos, capas |
| D12 | capstone | simulador integral + debugging | diseñar/defender contenedorización real |

**D01 (6 pantallas):** 1 Aprender: 2 ilustraciones (contenedor comparte kernel; VM con guest OS/kernel) + 2–3 diferencias + ejemplo FastAPI resuelto → `Probar con escenarios`. 2 Predecir: escenario nuevo «necesito kernel distinto», opción + razón obligatoria, tutor «¿qué habría que virtualizar?» → `Registrar predicción`. 3 Experimentar: 3 tarjetas grandes **una a la vez**/carrusel sin respuesta revelada; comparación capas al seleccionar → `Comprobar mi clasificación`. 4 Justificar: resumen 3 decisiones + explicación anclada en kernel/aislamiento/requisitos → `Evaluar mi razonamiento`. 5 Feedback: si confunde kernel → **nuevo** `KernelContrastSimulation` (o variante `ContainerVsVmExplorer`); si acierta sin evidencia → `EvidenceComparison`. 6 Postest: escenario no visto, sin tutor/pistas/feedback → `Entregar prueba`.
**D02:** animar imagen/contenedor con flechas/estados; predecir antes de `rm`; no fingir ejecución real si es motor determinista. **D04:** bloques arrastrables **o** subir/bajar accesible; preview + explicación por capa + errores con texto; verificar CMD vs RUN, EXPOSE no publica. **D06:** 2 contenedores lado a lado + volúmenes; `Crear archivo / Eliminar / Recrear`; predicción previa; bind vs volumen. **No ejecutar Docker real desde entradas arbitrarias.**

### 5.6 Data / ML / Monitoring (migrar al Workspace, sin reescribir motor)

- **Data Detective:** separar explicación patrones (nulos, duplicados, unidades, outliers, leakage) del ejercicio; tabla headers fijos + filtros + selección con feedback; derecha = evidencia, no scores; pedir categoría + causa + tratamiento (incluir caso *no eliminar* outlier); si confunde faltante/outlier → mini-tabla contrastiva nueva central.
- **ML:** predicción antes de mover sliders, comparar hipótesis vs curvas, registrar diferencias; gráficas responsivas (tooltips, ejes, leyendas por patrón, tabla alternativa); feedback Jev ligado a puntos concretos; intervención = cambiar n muestral o ejemplo leakage; no anunciar simulación sintética como entrenamiento real.
- **Monitoring:** separar feature drift / concept drift / degradación métricas; predecir changepoint + evidencia antes de moverlo; histogramas/series distinguibles (leyenda+texto, zoom/ventana, tabla); intervención = drift sin caída vs caída sin drift.

## 6. `flutter_animate` — sistema, no decoración

1. `flutter pub add flutter_animate` (respetar restricciones + lockfile); `flutter pub get` + `flutter analyze` + tests. Sin más deps de motion salvo justificación. `AnimatedSwitcher/Size/Container`, `TweenAnimationBuilder`, `Hero`, controladores nativos siguen válidos.
2. Centralizar en `lib/ui/labs/workspace/motion/learning_motion.dart`. Comprobar APIs exactas de la versión resuelta; `activityId` anima una vez, no resetea forms por rebuilds Riverpod/slider drags.
3. Tokens: fase nueva fade+slideY 8–12px 180–240ms (1 vez por transición real) · nuevo widget fade+scale 0.98→1 220–280ms (preservar foco) · expandir `AnimatedSize` 180–220ms · selección color/borde/check 120–160ms · evidencia guardada check/fade 160–220ms (solo tras confirm backend) · feedback escalonado corto total ≤450ms · siguiente actividad 220–300ms + anuncio lector · gráfica 200–300ms sin animar cada punto en drag · validación borde+ayuda+focus 120–180ms (sin shake) · postest sobrio 180–220ms sin celebración.
4. A11y/rendimiento: `MediaQuery.disableAnimationsOf(context)` ⇒ quitar slide/scale, dejar instantáneo o fade mínimo, nunca ocultar contenido. Probar `textScaler`, `Semantics`, foco, teclado; no depender solo del efecto para éxito/error. No animar listas completas ni un controlador por fila; throttling/debounce en gráficos **sin perder evento final**; no mover layout bajo el textarea mientras escribe; DevTools profile orientativo 60fps (medir, no prometer; capturar jank); tests con animaciones off o `pumpAndSettle`, sin flakiness.

```dart
// Ilustrativo — verificar API de la versión instalada
import 'package:flutter_animate/flutter_animate.dart';
Widget animatedActivity(Widget child, String activityId) {
  return KeyedSubtree(
    key: ValueKey(activityId),
    child: child.animate(key: ValueKey('enter-$activityId')).fadeIn(duration: 220.ms).slideY(begin: 0.025, end: 0, duration: 220.ms),
  );
}
```

## 7. Plan PR-UX01…UX08 (un PR a la vez; diff + capturas antes/después + tests + riesgos; no `[x]` sin evidencia; actualizar plan tras cada PR)

- **UX01 línea base:** rama + `git status` + versiones + árbol; `flutter analyze`, `flutter test`, capturas D01 desktop/tablet/móvil + errores iniciales; backend real si disponible (no inventar endpoints); tabla GenUI funcional vs `_simpleCard`. Aceptación: nada eliminado.
- **UX02 workspace:** extraer Workspace/Header/PhaseIndicator/TutorPanel/ActionBar; `LearningViewState` derivado sin duplicar backend; detalle eval fuera de vista principal; quitar postest temprano; layouts + tests overflow. Aceptación: D01 con 1 protagonista, tutor útil, 1 CTA, sin nota inicial.
- **UX03 D01 completa:** lección/predicción/experimento/justificación/feedback/intervención separadas; escenarios grandes; sin doble entrega; eventos con id + evidencias + reanudación; nuevo reto central E2E; postest variante independiente sin tutor. Aceptación: D01 sin confusión; siguiente actividad cambia interacción+evidencia, no solo título.
- **UX04 motion:** instalar + tokens; solo transiciones fases/widgets, pistas, guardado, feedback; probar movimiento reducido/foco/reanudación/rebuilds; DevTools + analyze/test. Aceptación: orienta sin retrasar/distraer; sin pérdida de respuestas.
- **UX05 D02/D04/D06 + catálogo:** páginas de unidad + prerrequisitos (no chips); D02 lifecycle + D04 Dockerfile + D06 persistencia (localizar/validar widget real, respetar IDs); D03/D05/D07–D12 como backlog. Aceptación: 3–4 excelentes, no 12 ficticias.
- **UX06 Data/ML/Monitoring:** reutilizar Workspace; misma jerarquía tutor/feedback; predicción-antes cuando aporte; intervenciones Gemini como actividades centrales; sensores visuales + a11y + postest. Aceptación: mismo patrón en las 4 familias.
- **UX07 Academia + profesor:** unidades con estado real (por iniciar/en curso/repaso/demostrado) + requisitos + objetivos; `next_activity` sugerencia **server-side** con causa + CTA; repaso configurable + transferencia (sin inventar datos); instructor analytics read-only (quitar escrituras Flutter + permisos backend). Aceptación: ningún flujo obliga al instructor a evaluar; alumno con siguiente actividad comprensible.
- **UX08 piloto/release:** pilotar D01 + ML + 1 lab con 4 estudiantes (consentimiento, exploratorio); observar navegación/fatiga/duración/comprensión/ayuda; comparar antes/después sin asistencia ni corrección de errores (no generalizar n=4); QA responsive/a11y/tokens/fallbacks/HTTPS/demo. Aceptación: juez aprende, manipula, justifica, recibe intervención y completa prueba independiente sin ayuda del maestro.
- **Orden inmediata:** lee plan + `DESIGN.md`; empieza por UX01 y UX02; antes de codificar explica transición de pantallas + modelo de estado con archivos reales; implementa workspace en D01 (1 CTA, tutor lateral, GenUI principal, feedback post-intento); ejecuta pruebas. No las 12 unidades ni capa animación global hasta validar D01; luego `flutter_animate` con estos tokens.
- **Aceptación demo:** D01 enseña qué/por qué antes de responder · 1 CTA por fase · GenUI central interactivo con estado persistente · sin 0 inicial ni postest precoz · Jev/mock-etiquetado solo tras entrega · Gemini produce actividad distinta central con nuevos eventos · tutor con pista gradual, mudo en postest · motion sin distraer/perder estado + respeta reducción · desktop+móvil sin overflow, teclado + lector OK · maestro observa sin editar · ciclo reanudable con permisos backend.

## 8. Reglas estrictas para OpenCode

1. Preservar commits, tareas cerradas, navegación, GenUI, Gemini/Jev, SQLite y pruebas. El rediseño partió de frontend: investigar backend en repo antes de tocar contratos.
2. Nunca reemplazar `_simpleCard` por tarjeta bonita y marcarla como lab interactivo.
3. Currículo fijo + generador entre widgets autorizados; sin secuencias hardcodeadas fingiendo personalización.
4. Sin 0 iniciales; evaluación descriptiva post-entrega, números bajo demanda.
5. Maestro solo consulta; no mantener UI vieja de revisión manual como acción principal.
6. Eventos con sesión/actividad/props/`client_event_id` idempotente.
7. Sin postest hasta autorización servidor.
8. `flutter_animate` jamás reinicia selección, pierde foco, reproduce en bucle o bloquea pruebas.
9. Un PR a la vez (diff + capturas + tests + riesgos).
10. No usar `nano`; `vim` si hace falta editor de terminal.

## 9. MCPs disponibles (usar sin pedir permiso)

- `dart`: hot reload/restart tras cambios Dart/Flutter; `roots` para explorar paquetes.
- `marionette`: controlar la app Flutter en debug (VM service URI + `connect`, `get_interactive_elements`, `tap`/`enter_text`/`scroll`, screenshots, `get_logs`).
- `obscura`: abrir links y verificar en browser real (navegar, recargar, screenshots).

## 10. Smoke servers

- Puertos efímeros (8001+) con `Start-Job`; matar con `Remove-Job` + buscar el `python.exe` huérfano por puerto (`netstat -ano`), no existe proceso `uvicorn`.

## 11. Git y secretos

- Rama `main`, remoto `origin` (`MJVNOR/CognitiveFlow-AI`); identidad local lista.
- `.gitignore` excluye `.env`, `opencode.json`, `.venv`, `*.db*`, `build/`.
  **Nunca** stagear `opencode.json` (tiene keys MCP locales) ni imprimir keys.
- Planes vivos: `PLAN.md` + `PLAN_REDISENO_TAREAS_FLUTTER.md`: marcar `[x]` solo con evidencia (tests + capturas). Antes `COGNITIVEFLOW_PLAN.md` es viejo/historial.
