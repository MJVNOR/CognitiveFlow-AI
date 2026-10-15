// Catálogo GenUI cerrado (genui 0.10.4, ver pubspec.lock).
// Subconjunto activo del backend (app/interventions.py CATALOG).
// ponytail: sin eventos GenUI nativos aún; el loop usa nuestros eventos REST (verificado E2E).
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

Widget _card(CatalogItemContext ctx, String titleKey, String bodyKey) {
  final data = ctx.data as Map;
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoundString(
            dataContext: ctx.dataContext,
            value: data[titleKey],
            builder: (c, v) => Text(v ?? '', style: Theme.of(c).textTheme.titleSmall),
          ),
          BoundString(
            dataContext: ctx.dataContext,
            value: data[bodyKey],
            builder: (c, v) => Text(v ?? ''),
          ),
        ],
      ),
    ),
  );
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
  widgetBuilder: (ctx) => _card(ctx, 'title', 'question'),
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
  widgetBuilder: (ctx) => _card(ctx, 'title', 'evidence'),
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
  widgetBuilder: (ctx) => _card(ctx, 'title', 'hint'),
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
  widgetBuilder: (ctx) => _card(ctx, 'title', 'hint'),
);

/// Nombres que el backend puede pedir (subconjunto de CATALOG).
const cognitiveFlowWidgets = {
  'SocraticQuestionCard',
  'EvidenceComparison',
  'HypothesisEditor',
  'DataTableExplorer',
  'DriftDistributionExplorer',
};

final cognitiveFlowCatalog = [
  socraticQuestionCard,
  evidenceComparison,
  hypothesisEditor,
  dataTableExplorer,
  driftDistributionExplorer,
];
