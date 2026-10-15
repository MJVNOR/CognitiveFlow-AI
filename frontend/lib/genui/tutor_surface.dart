// F5-full: render de next-intervention vía Surface GenUI (A2UI v0.9).
// El backend sigue emitiendo ui_spec validada; aquí se traduce a mensajes
// createSurface/updateComponents y se alimenta al SurfaceController local.
import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';

import 'catalog.dart';

const tutorCatalogId = 'ai.cognitiveflow.tutor';
const tutorSurfaceId = 'tutor';

/// Traduce una intervención del backend a componentes A2UI del catálogo.
Map<String, Object?> interventionToComponent(Map intervention) {
  final type = '${intervention['widget_type']}';
  final spec = (intervention['widget_parameters'] as Map?) ?? {};
  final title = '${spec['title'] ?? type}';
  final question = '${intervention['socratic_question'] ?? ''}';
  final props = switch (type) {
    'EvidenceComparison' => {'title': title, 'evidence': question},
    'HypothesisEditor' => {'title': title, 'hypothesis': question},
    'DataTableExplorer' => {'title': title, 'hint': question},
    'DriftDistributionExplorer' => {'title': title, 'hint': question},
    _ => {'title': title, 'question': question},
  };
  return {'id': 'root', 'component': type, ...props};
}

class TutorSurface extends StatefulWidget {
  final Map intervention;
  const TutorSurface({super.key, required this.intervention});
  @override
  State<TutorSurface> createState() => _TutorSurfaceState();
}

class _TutorSurfaceState extends State<TutorSurface> {
  late final SurfaceController _controller;
  late final A2uiTransportAdapter _transport;
  late final StreamSubscription<core.A2uiMessage> _sub;

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
    if (!identical(old.intervention, widget.intervention)) {
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
    return Surface(surfaceContext: _controller.contextFor(tutorSurfaceId));
  }
}
