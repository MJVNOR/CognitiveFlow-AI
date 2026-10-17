import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '_shared.dart';
import 'events.dart';

// ponytail: los 6 restantes del CATALOG comparten forma título+pregunta;
// un solo helper en vez de 6 clases casi idénticas.
CatalogItem _simpleCard(String name, String titleEx, String bodyEx,
    {bool experiment = false}) {
  return CatalogItem(
    name: name,
    dataSchema: S.object(
      properties: {
        'title': S.string(description: 'Título de la tarjeta'),
        'question': S.string(description: 'Consigna o pregunta'),
      },
      required: ['question'],
    ),
    exampleData: [
      () => '[{"id": "root", "component": "$name", '
          '"title": "$titleEx", "question": "$bodyEx"}]',
    ],
    widgetBuilder: (ctx) => boundCard(ctx, 'title', 'question',
        icon: experiment ? Icons.science : null,
        accent: experiment ? (cs) => cs.secondary : null),
  );
}

final choiceReasoningWidget =
    _simpleCard('ChoiceReasoningWidget', 'Elige y razona', '¿Qué opción y por qué?');
final sqlQueryWorkbench =
    _simpleCard('SqlQueryWorkbench', 'Consulta', '¿Qué consulta responde esto?');

/// P1.2: simulador paramétrico real (sliders + predicción); la curva vive en
/// LabDetailPage. Emite parameterChanged y predictionSubmitted.
final learningCurveSimulator = CatalogItem(
  name: 'LearningCurveSimulator',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del simulador'),
      'question': S.string(description: 'Consigna o pregunta'),
      'complexity': S.number(description: 'Complejidad inicial 1-10'),
      'noise_pct': S.number(description: 'Ruido inicial 0-50'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "LearningCurveSimulator", '
        '"title": "Simula", "question": "¿Qué pasa si subes la complejidad?", '
        '"complexity": 5, "noise_pct": 20}]',
  ],
  widgetBuilder: (ctx) => _LearningCurveSimulator(ctx),
);

class _LearningCurveSimulator extends StatefulWidget {
  final CatalogItemContext ctx;
  const _LearningCurveSimulator(this.ctx);
  @override
  State<_LearningCurveSimulator> createState() => _LearningCurveSimulatorState();
}

class _LearningCurveSimulatorState extends State<_LearningCurveSimulator> {
  late double complexity;
  late double noise;

  @override
  void initState() {
    super.initState();
    final data = widget.ctx.data as Map;
    complexity = (numProp(data, 'complexity') ?? 5).clamp(1, 10);
    noise = (numProp(data, 'noise_pct') ?? 20).clamp(0, 50);
  }

  void _changed() => TutorEvents.send('LearningCurveSimulator', 'parameterChanged',
      {'complexity': complexity.round(), 'noise_pct': noise.round()});

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final cs = Theme.of(context).colorScheme;
    return titledCard(context, '${data['title'] ?? 'Simula'}',
        '${data['question'] ?? ''}',
        icon: Icons.science,
        accent: cs.secondary,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Complejidad'),
              Expanded(
                child: Slider(
                  key: const ValueKey('lcs_complexity'),
                  value: complexity,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: '${complexity.round()}',
                  onChanged: (v) => setState(() => complexity = v),
                  onChangeEnd: (_) => _changed(),
                ),
              ),
              Text('${complexity.round()}/10'),
            ],
          ),
          Row(
            children: [
              const Text('Ruido'),
              Expanded(
                child: Slider(
                  key: const ValueKey('lcs_noise'),
                  value: noise,
                  min: 0,
                  max: 50,
                  divisions: 10,
                  label: '${noise.round()}%',
                  onChanged: (v) => setState(() => noise = v),
                  onChangeEnd: (_) => _changed(),
                ),
              ),
              Text('${noise.round()}%'),
            ],
          ),
          FilledButton.tonal(
            key: const ValueKey('lcs_send'),
            onPressed: () => TutorEvents.send('LearningCurveSimulator',
                'predictionSubmitted',
                {'complexity': complexity.round(), 'noise_pct': noise.round()}),
            child: const Text('Enviar predicción'),
          ),
        ]);
  }
}

final conceptMapBuilder =
    _simpleCard('ConceptMapBuilder', 'Mapa', '¿Cómo se conectan estos conceptos?');
final pipelineDAGBuilder =
    _simpleCard('PipelineDAGBuilder', 'Pipeline', '¿En qué orden van las etapas?');
final rubricFeedbackCard =
    _simpleCard('RubricFeedbackCard', 'Rúbrica', '¿En qué criterio estás más débil?');
final reflectionSummary =
    _simpleCard('ReflectionSummary', 'Reflexión', '¿Qué aprendiste?');
