// F5-full: render de next-intervention vía Surface GenUI (A2UI v0.9).
// El backend sigue emitiendo ui_spec validada; aquí se traduce a mensajes
// createSurface/updateComponents y se alimenta al SurfaceController local.
import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'catalog.dart';

const tutorCatalogId = 'ai.cognitiveflow.tutor';
const tutorSurfaceId = 'tutor';

/// Traduce una intervención del backend a componentes A2UI del catálogo.
/// P1.1: valida tipo contra el catálogo y propaga parámetros numéricos;
/// tipo desconocido o formato inválido → tarjeta accesible, nunca crash.
Map<String, Object?> interventionToComponent(Map intervention) {
  var type = '${intervention['widget_type']}';
  if (!cognitiveFlowWidgets.contains(type)) type = 'SocraticQuestionCard';
  final spec = (intervention['widget_parameters'] as Map?) ?? {};
  final title = backlogWidgets.contains('${intervention['widget_type']}')
      ? 'Actividad histórica · solo lectura'
      : type == '${intervention['widget_type']}'
      ? '${spec['title'] ?? type}'
      : 'Actividad no disponible';
  final question = '${intervention['socratic_question'] ?? ''}';
  final params = (spec['parameters'] as Map?) ?? {};
  num? paramNum(String k) {
    final p = params[k];
    if (p is Map && p['initial'] is num) return p['initial'];
    return null;
  }

  final props = switch (type) {
    'EvidenceComparison' => {'title': title, 'evidence': question},
    'HypothesisEditor' => {
        'title': title,
        'hypothesis': question,
        if (paramNum('complexity') != null) 'complexity': paramNum('complexity'),
        if (params['curve'] is Map) 'curve': params['curve'],
      },
    // Docker: el escenario (sin respuestas) lo genera el servidor por unidad y semilla.
    'ContainerVsVmExplorer' ||
    'ImageContainerLifecycle' ||
    'DockerfileWorkbench' ||
    'PersistenceExperiment' ||
    'DecisionScenarios' ||
    'ConfigAudit' ||
    'CommandComposer' =>
      {
        'title': title,
        // La consigna curricular describe la acción; la pregunta generada vive
        // en el tutor. No convertir una pregunta libre en instrucciones del lab.
        'question': params['instruction'] ?? switch (type) {
          'ContainerVsVmExplorer' => 'Elige contenedor o VM según los requisitos de cada caso y explica tu decisión.',
          'ImageContainerLifecycle' => 'Predice qué existirá tras el paso señalado; después compruébalo con la simulación.',
          'DockerfileWorkbench' => 'Ordena las instrucciones para construir la app y conservar la caché de dependencias. Coloca CMD al final.',
          'PersistenceExperiment' => 'Elige un montaje, predice si el archivo sobrevivirá y compruébalo al recrear.',
          'ConfigAudit' => 'Marca todos los elementos que aplican; puede aplicar más de uno.',
          'CommandComposer' => 'Elige en cada ranura la opción que cumple los requisitos del caso.',
          _ => 'Lee cada caso, elige la acción que resuelve sus requisitos y justifica con evidencia.',
        },
        if ((type == 'DockerfileWorkbench' || type == 'PersistenceExperiment') && params['feedback_enabled'] is bool)
          'feedback_enabled': params['feedback_enabled'],
        // `states` lo manda el servidor en las unidades que comparten el widget
        // de predicción (null en el paso que se predice).
        for (final k in const ['context', 'scenarios', 'stages', 'ask_index', 'ask_stage', 'options', 'states', 'lines', 'app', 'story', 'path', 'items', 'mono', 'subject', 'slots', 'prefix'])
          if (params[k] != null) k: params[k],
      },
    'DataTableExplorer' => {
        'title': title,
        'hint': question,
        if (params['n_rows'] is num) 'n_rows': params['n_rows'],
        if (params['rows'] is List) 'rows': params['rows'],
      },
    'DriftDistributionExplorer' => {
        'title': title,
        'hint': question,
        if (params['features'] is List) 'features': params['features'],
      },
    'LearningCurveSimulator' => {
        'title': title,
        'question': question,
        if (paramNum('complexity') != null) 'complexity': paramNum('complexity'),
        if (paramNum('noise_pct') != null) 'noise_pct': paramNum('noise_pct'),
      },
    _ => {'title': title, 'question': question},
  };
  return {'id': 'root', 'component': type, ...props};
}

class TutorSurface extends StatefulWidget {
  final Map intervention;
  final void Function(String widgetType, String eventType, Map<String, Object?> payload)? onEvent;
  const TutorSurface({super.key, required this.intervention, this.onEvent});
  @override
  State<TutorSurface> createState() => _TutorSurfaceState();
}

class _TutorSurfaceState extends State<TutorSurface> {
  late final SurfaceController _controller;
  late final A2uiTransportAdapter _transport;
  late final StreamSubscription<core.A2uiMessage> _sub;

  void _emit(String type, String event, Map<String, Object?> payload) {
    final id = widget.intervention['activity_id'];
    widget.onEvent?.call(type, event, {...payload, if (id is String) 'activity_id': id});
  }

  @override
  void initState() {
    super.initState();
    _controller = SurfaceController(
      catalogs: [Catalog(cognitiveFlowCatalog, catalogId: tutorCatalogId)],
    );
    _transport = A2uiTransportAdapter();
    _sub = _transport.incomingMessages.listen(_controller.handleMessage);
    _transport.addMessage(core.A2uiMessage.fromJson({
      'version': 'v0.9',
      'createSurface': {'surfaceId': tutorSurfaceId, 'catalogId': tutorCatalogId},
    }));
    _transport.addMessage(core.A2uiMessage.fromJson({
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': tutorSurfaceId,
        'components': [interventionToComponent(widget.intervention)],
      },
    }));
  }

  @override
  void didUpdateWidget(covariant TutorSurface old) {
    super.didUpdateWidget(old);
    // Por contenido: cada emit del VM copia el mapa y no debe reiniciar el widget.
    if (jsonEncode(old.intervention) != jsonEncode(widget.intervention)) {
      _transport.addMessage(core.A2uiMessage.fromJson({
        'version': 'v0.9',
        'updateComponents': {
          'surfaceId': tutorSurfaceId,
          'components': [interventionToComponent(widget.intervention)],
        },
      }));
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _transport.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TutorEventScope(
      emit: _emit,
      child: KeyedSubtree(
        key: ValueKey(widget.intervention['activity_id']),
        child: Surface(surfaceContext: _controller.contextFor(tutorSurfaceId)),
      ),
    );
  }
}
