// Catálogo GenUI cerrado (genui 0.10.4, ver pubspec.lock).
// Espejo exacto del backend (app/interventions.py CATALOG).
// ponytail: sin eventos GenUI nativos aún; el loop usa nuestros eventos REST (verificado E2E).
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

Widget _card(CatalogItemContext ctx, String titleKey, String bodyKey,
    {IconData? icon, Color Function(ColorScheme cs)? accent}) {
  final data = ctx.data as Map;
  // ponytail: Builder para Theme real (ctx.buildContext es mock en tests).
  return Builder(builder: (context) {
    final cs = Theme.of(context).colorScheme;
    final ac = accent?.call(cs);
    return Card(
      shape: ac == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: ac),
            ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: ac),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: BoundString(
                    dataContext: ctx.dataContext,
                    value: data[titleKey],
                    builder: (c, v) => AutoSizeText(v ?? '',
                        maxLines: 1,
                        minFontSize: 12,
                        style: Theme.of(c).textTheme.titleSmall),
                  ),
                ),
              ],
            ),
            BoundString(
              dataContext: ctx.dataContext,
              value: data[bodyKey],
              builder: (c, v) => AutoSizeText(v ?? '',
                  maxLines: 3, minFontSize: 11, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }).animate().fadeIn(duration: 250.ms);
}

final socraticQuestionCard = CatalogItem(
  name: 'SocraticQuestionCard',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título de la tarjeta'),
      'question': S.string(description: 'Pregunta socrática'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "SocraticQuestionCard", '
        '"title": "Pregunta", "question": "¿Qué observas?"}]',
  ],
  widgetBuilder: (ctx) => _card(ctx, 'title', 'question',
      icon: Icons.help_outline, accent: (cs) => cs.tertiary),
);

final evidenceComparison = CatalogItem(
  name: 'EvidenceComparison',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del contraste'),
      'evidence': S.string(description: 'Evidencia a analizar'),
    },
    required: ['evidence'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "EvidenceComparison", '
        '"title": "Compara", "evidence": "curva de validación"}]',
  ],
  widgetBuilder: (ctx) => _card(ctx, 'title', 'evidence',
      icon: Icons.compare_arrows, accent: (cs) => cs.tertiary),
);

final hypothesisEditor = CatalogItem(
  name: 'HypothesisEditor',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del editor'),
      'hypothesis': S.string(description: 'Hipótesis inicial'),
    },
    required: ['hypothesis'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "HypothesisEditor", '
        '"title": "Hipótesis", "hypothesis": "Creo que…"}]',
  ],
  widgetBuilder: (ctx) => _card(ctx, 'title', 'hypothesis'),
);

final driftDistributionExplorer = CatalogItem(
  name: 'DriftDistributionExplorer',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del explorador'),
      'hint': S.string(description: 'Pista de qué comparar'),
    },
    required: ['hint'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "DriftDistributionExplorer", '
        '"title": "Deriva", "hint": "Compara referencia vs actual"}]',
  ],
  widgetBuilder: (ctx) => _card(ctx, 'title', 'hint',
      icon: Icons.science, accent: (cs) => cs.secondary),
);

final dataTableExplorer = CatalogItem(
  name: 'DataTableExplorer',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del explorador'),
      'hint': S.string(description: 'Pista de qué buscar'),
    },
    required: ['hint'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "DataTableExplorer", '
        '"title": "Explora", "hint": "Busca anomalías"}]',
  ],
  widgetBuilder: (ctx) => _card(ctx, 'title', 'hint',
      icon: Icons.table_chart, accent: (cs) => cs.secondary),
);

// ponytail: los 7 restantes del CATALOG comparten forma título+pregunta;
// un solo helper en vez de 7 clases casi idénticas.
// ponytail: LearningCurveSimulator es experiment (teal); resto neutral.
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
    widgetBuilder: (ctx) => _card(ctx, 'title', 'question',
        icon: experiment ? Icons.science : null,
        accent: experiment ? (cs) => cs.secondary : null),
  );
}

final choiceReasoningWidget =
    _simpleCard('ChoiceReasoningWidget', 'Elige y razona', '¿Qué opción y por qué?');
final sqlQueryWorkbench =
    _simpleCard('SqlQueryWorkbench', 'Consulta', '¿Qué consulta responde esto?');
final learningCurveSimulator = _simpleCard(
    'LearningCurveSimulator', 'Simula', '¿Qué pasa si subes la complejidad?',
    experiment: true);
final conceptMapBuilder =
    _simpleCard('ConceptMapBuilder', 'Mapa', '¿Cómo se conectan estos conceptos?');
final pipelineDAGBuilder =
    _simpleCard('PipelineDAGBuilder', 'Pipeline', '¿En qué orden van las etapas?');
final rubricFeedbackCard =
    _simpleCard('RubricFeedbackCard', 'Rúbrica', '¿En qué criterio estás más débil?');
final reflectionSummary =
    _simpleCard('ReflectionSummary', 'Reflexión', '¿Qué aprendiste?');

/// Nombres que el backend puede pedir (= CATALOG en app/interventions.py).
const cognitiveFlowWidgets = {
  'SocraticQuestionCard',
  'EvidenceComparison',
  'HypothesisEditor',
  'DataTableExplorer',
  'DriftDistributionExplorer',
  'ChoiceReasoningWidget',
  'SqlQueryWorkbench',
  'LearningCurveSimulator',
  'ConceptMapBuilder',
  'PipelineDAGBuilder',
  'RubricFeedbackCard',
  'ReflectionSummary',
};

final cognitiveFlowCatalog = [
  socraticQuestionCard,
  evidenceComparison,
  hypothesisEditor,
  dataTableExplorer,
  driftDistributionExplorer,
  choiceReasoningWidget,
  sqlQueryWorkbench,
  learningCurveSimulator,
  conceptMapBuilder,
  pipelineDAGBuilder,
  rubricFeedbackCard,
  reflectionSummary,
];
