# Catálogo GenUI e identidad de actividades

Revisión: 22 de octubre de 2026. Alcance: catálogo, eventos, reanudación e identidad;
no completa los experimentos visuales pendientes de ML y Monitoring.

## Catálogo activo

`backend/app/interventions.py::CATALOG` coincide con
`frontend/lib/ui/tutor/catalog.dart::cognitiveFlowWidgets` (13 tipos).
Una prueba compara ambos archivos y verifica que el menú del planificador solo use tipos activos.

El widget **ya no se deduce de la unidad Docker**: varias unidades comparten un mismo
widget y la unidad viaja en los parámetros (`parameters.unit`, o `parameters.units` en el
repaso mezclado) junto con el motor que generó el escenario (`parameters.kind`). La
corrección del reto usa esos mismos valores (`app/checks.py` → `labs_docker.check`).

| Tipo | Función real actual | Límite |
|---|---|---|
| SocraticQuestionCard | Pregunta informativa | No es un laboratorio ni entrega evidencia por sí sola |
| EvidenceComparison | Seleccionar curva y argumentar | Pendiente presentar las curvas dentro del reto |
| HypothesisEditor | Escribir/revisar hipótesis; mostrar curvas cuando el servidor las incluye | No todos los contextos incluyen curvas |
| DataTableExplorer | Clasificar filas contrastivas del servidor y justificar | Variante histórica sin filas: formulario de IDs |
| DriftDistributionExplorer | Seleccionar variable, momento y argumento | Pendientes distribuciones/series dentro del reto |
| LearningCurveSimulator | Controles de complejidad/ruido y entrega de predicción | Pendientes curvas y observación dentro del componente |
| ContainerVsVmExplorer | Clasificar escenarios contenedor/VM | Simulación educativa |
| ImageContainerLifecycle | Predecir el estado tras un paso y recorrer la secuencia: ciclo imagen/contenedor (D02) o la línea de tiempo que manda el servidor (`states`: D06, D07, D09) | Simulación educativa; el estado del paso predicho llega con la corrección, no en la actividad |
| DockerfileWorkbench | Reordenar instrucciones Dockerfile (D04) o los pasos de un procedimiento con reglas del banco (`ORDER_BANKS`: D03, D08, D11) | No ejecuta Docker real; el nombre del tipo ya no describe todo lo que ordena |
| PersistenceExperiment | Predecir y comprobar persistencia según montaje | Motor determinista |
| DecisionScenarios | Elegir acciones ante casos de una unidad, o un caso por unidad en el repaso mezclado (`kind: mixed`) | No equivale a terminal, editor Compose o pipeline ejecutable |
| ConfigAudit | Marcar **todos** los elementos que aplican de un archivo o configuración (D04 caché, D05 contexto, D08 compose, D09 evidencia, D10 riesgos); cada cambio se corrige al momento | No analiza archivos reales: audita el banco del servidor. Las omisiones se avisan sin enumerarlas |
| CommandComposer | Armar un comando por ranuras eligiendo en cada una (D03, D06, D07, D10) | No ejecuta ni valida sintaxis real: compara con la combinación del banco |

## Menú de actividades Docker (lo que puede elegir Gemini)

`ACTIVITY_MENU["docker"]` tiene nueve actividades y `docker_menu(unidad, completadas)`
devuelve solo las posibles para ese estudiante (unidad actual, unidades completadas y
bancos existentes), así que el planificador nunca propone algo que el servidor no sepa
construir; si lo hace, la actividad se descarta (503 reintentable en producción).

| Actividad | Widget | Qué cambia |
|---|---|---|
| `unit_practice` | el de la unidad | otro escenario de la misma unidad |
| `focused_contrast` | el de la unidad | variante que cambia solo en el tema fallado (`focus`) |
| `config_audit` | ConfigAudit | marcar todo lo que aplica |
| `command_build` | CommandComposer | construir el comando por ranuras |
| `order_steps` | DockerfileWorkbench | ordenar pasos con reglas |
| `predict_state` | ImageContainerLifecycle | predecir el estado tras un paso |
| `mixed_review` | DecisionScenarios | un caso por unidad ya trabajada |
| `transfer_unit` | el de la unidad destino | pasar a otra unidad con prerrequisito cumplido |
| `explain_axis` | HypothesisEditor | reexplicar el tema fallado, sin escenario nuevo |

Los ejes de contraste (`FOCUS_AXES`) cubren 9 unidades: D01, D02 y las siete de decisión
(D03, D05, D06, D08–D11); el capstone (D12) mezcla y no contrasta. Cada caso del banco
tiene su eje y una prueba falla si un caso nuevo queda sin etiquetar.

## Backlog e históricos

ChoiceReasoningWidget, SqlQueryWorkbench, ConceptMapBuilder, PipelineDAGBuilder,
RubricFeedbackCard y ReflectionSummary dejan de registrarse como componentes activos.
Se eliminó `_simpleCard`: sus seis aliases no implementaban las herramientas anunciadas.
`BACKLOG_WIDGETS` y `backlogWidgets` conservan los nombres solo para identificar históricos.

Los registros SQLite no se eliminan. Flutter muestra una actividad antigua de esos tipos
como «Actividad histórica · solo lectura», con su pregunta y sin controles ficticios.
El backend no acepta nuevos eventos de esos tipos y Gemini no puede seleccionarlos.

## Contrato aditivo de identidad

Cada reto persistido incluye:

```json
{
  "activity_id": "activity-<identificador emitido por el servidor>",
  "session_id": "<sesión>",
  "previous_activity_id": "<reto anterior o null>"
}
```

Se guardan en `InterventionLog.spec_json`, sin columnas ni migración nueva.
El identificador es distinto para cada nuevo reto, incluso si comparte widget y estrategia.
Reintentar `next-intervention` para el mismo intento actual recupera el reto guardado,
sin volver a consultar al proveedor. `GET /sessions/{id}/interventions` devuelve la misma identidad.
Los logs antiguos reciben una identidad estable derivada de su ID al leerse; no se reescriben.
Se mantiene `schema_version: 1`; estos campos son aditivos y no cambian el adaptador A2UI.

`POST /sessions/{id}/events` recibe `activity_id` en el nivel superior, junto con
`client_event_id`, `widget_type`, `event_type` y `payload`. La sesión viene de la ruta.
El servidor valida propiedad de sesión, actividad actual, widget y evento permitido.
Las pistas pueden proceder del tutor contextual; una entrega debe usar el widget del reto.
La práctica anterior a un reto usa `practice-<session_id>`.

- Reto nuevo sin `activity_id`: 422. ID ajeno o anterior: 409.
- Nuevos eventos durante postest, cierre o archivo: rechazados.
- El servidor guarda la identidad en `UiEvent.payload_json`; no acepta identidad ni
  corrección fabricadas dentro de `payload`.
- Un reintento idéntico recupera su resultado. Reutilizar `client_event_id` con otro
  contenido, actividad o sesión devuelve 409.
- El permiso de postest cuenta entregas de la identidad actual, no de otros retos
  que usen el mismo widget. Los históricos sin identidad conservan la lectura compatible.

Backend y frontend deben desplegarse juntos: los clientes antiguos que omitan el ID
en un reto nuevo recibirán 422. La compatibilidad sin ID se mantiene solo para práctica
y retos históricos, donde el servidor asigna la identidad al evento.

## Estado en Flutter

`LabSessionViewModel` restaura la identidad del servidor y la transmite por
`SessionRepository`. Las superficies usan `TutorEventScope` para evitar un destinatario
global compartido. El ID de origen acompaña al callback; una respuesta tardía de otra
actividad no actualiza el escenario actual.

Las claves de `ScenarioStage` y la superficie dependen de `activity_id`: una reconstrucción
del mismo reto conserva el borrador; otro reto crea una interacción limpia.
El repositorio conserva el `client_event_id` de un envío fallido mientras vive la sesión
del cliente; no implementa una cola offline persistente tras cerrar o recargar el navegador.

## Evidencia

- Backend: `uv run pytest -q --tb=short --basetemp=../.test-tmp-activities-final -p no:cacheprovider`:
  135 pasan, 1 prueba de proveedor real omitida. Incluye chequeo de esquema sin migraciones pendientes.
- Flutter: `flutter test --no-pub`: 162 pasan, 1 prueba de capturas optativa omitida.
- `flutter analyze --no-pub`: sin incidencias.
- `flutter build web`: compilación correcta. El compilador avisa de una referencia
  a la fuente CupertinoIcons que no está incluida; no bloquea esta compilación.
- Pruebas nuevas: igualdad de catálogos entre lenguajes, aislamiento entre retos del
  mismo widget, rechazo de IDs ajenos/anteriores, reintentos, reanudación histórica sin
  modificar JSON antiguo, superficies simultáneas y conservación/reinicio de borradores.

Estas comprobaciones no acreditan eficacia educativa ni una revisión visual en navegador.
