# Catálogo GenUI e identidad de actividades

Revisión: 22 de octubre de 2026. Alcance: catálogo, eventos, reanudación e identidad;
no completa los experimentos visuales pendientes de ML y Monitoring.

## Catálogo activo

`backend/app/interventions.py::CATALOG` coincide con
`frontend/lib/ui/tutor/catalog.dart::cognitiveFlowWidgets` (11 tipos).
Una prueba compara ambos archivos y verifica que el menú del planificador solo use tipos activos.

| Tipo | Función real actual | Límite |
|---|---|---|
| SocraticQuestionCard | Pregunta informativa | No es un laboratorio ni entrega evidencia por sí sola |
| EvidenceComparison | Seleccionar curva y argumentar | Pendiente presentar las curvas dentro del reto |
| HypothesisEditor | Escribir/revisar hipótesis; mostrar curvas cuando el servidor las incluye | No todos los contextos incluyen curvas |
| DataTableExplorer | Clasificar filas contrastivas del servidor y justificar | Variante histórica sin filas: formulario de IDs |
| DriftDistributionExplorer | Seleccionar variable, momento y argumento | Pendientes distribuciones/series dentro del reto |
| LearningCurveSimulator | Controles de complejidad/ruido y entrega de predicción | Pendientes curvas y observación dentro del componente |
| ContainerVsVmExplorer | Clasificar escenarios contenedor/VM | Simulación educativa |
| ImageContainerLifecycle | Predecir y recorrer estados de imagen/contenedor | Simulación educativa |
| DockerfileWorkbench | Reordenar instrucciones Dockerfile | No ejecuta Docker real |
| PersistenceExperiment | Predecir y comprobar persistencia según montaje | Motor determinista |
| DecisionScenarios | Elegir acciones ante casos de una unidad | No equivale a terminal, editor Compose o pipeline ejecutable |

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
