import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../labs/widgets/curve_chart.dart';
import '_shared.dart';
import 'events.dart';

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
  widgetBuilder: (ctx) => boundCard(ctx, 'title', 'question',
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
  widgetBuilder: (ctx) => _EvidenceComparison(ctx),
);

/// P1.3: qué curva apoya tu conclusión + argumento; emite
/// evidenceSelected y argumentSubmitted (POST /sessions/{id}/events).
class _EvidenceComparison extends StatefulWidget {
  final CatalogItemContext ctx;
  const _EvidenceComparison(this.ctx);
  @override
  State<_EvidenceComparison> createState() => _EvidenceComparisonState();
}

class _EvidenceComparisonState extends State<_EvidenceComparison> {
  String? selection;
  final argument = TextEditingController();
  bool sent = false;

  @override
  void initState() {
    super.initState();
    // ponytail: el botón se habilita al escribir; sin esto queda muerto.
    argument.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    argument.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final cs = Theme.of(context).colorScheme;
    return titledCard(context, '${data['title'] ?? 'Compara'}',
        '${data['evidence'] ?? ''}',
        icon: Icons.compare_arrows,
        accent: cs.tertiary,
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final o in const [
                ('train', 'Entrenamiento'),
                ('val', 'Validación'),
                ('both', 'Ambas'),
              ])
                ChoiceChip(
                  key: ValueKey('ec_${o.$1}'),
                  label: Text(o.$2),
                  selected: selection == o.$1,
                  onSelected: (_) {
                    setState(() => selection = o.$1);
                    TutorEvents.send(context, 'EvidenceComparison', 'evidenceSelected',
                        {'selection': o.$1});
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('ec_argument'),
            controller: argument,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'Tu argumento (cita las curvas)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const ValueKey('ec_send'),
            onPressed: argument.text.trim().isEmpty
                ? null
                : () {
                    TutorEvents.send(context, 'EvidenceComparison', 'argumentSubmitted',
                        {'argument': argument.text, 'selection': selection ?? ''});
                    setState(() => sent = true);
                  },
            child: Text(sent ? 'Argumento enviado ✓' : 'Enviar argumento'),
          ),
        ]);
  }
}

final hypothesisEditor = CatalogItem(
  name: 'HypothesisEditor',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del editor'),
      'hypothesis': S.string(description: 'Hipótesis inicial'),
      'complexity': S.number(description: 'Complejidad del escenario nuevo (ML)'),
      'curve': S.object(
          description: 'Curvas simuladas del escenario {train, val}',
          properties: {
            'train': S.list(items: S.number()),
            'val': S.list(items: S.number()),
          }),
    },
    required: ['hypothesis'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "HypothesisEditor", '
        '"title": "Hipótesis", "hypothesis": "Creo que…"}]',
  ],
  widgetBuilder: (ctx) => _HypothesisEditor(ctx),
);

/// P1.4: hipótesis inicial + revisión justificada; cada guardado emite
/// hypothesisSubmitted con revision N (historial sin filtrar soluciones).
class _HypothesisEditor extends StatefulWidget {
  final CatalogItemContext ctx;
  const _HypothesisEditor(this.ctx);
  @override
  State<_HypothesisEditor> createState() => _HypothesisEditorState();
}

class _HypothesisEditorState extends State<_HypothesisEditor> {
  final field = TextEditingController();
  int revisions = 0;

  @override
  void initState() {
    super.initState();
    field.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final curve = data['curve'] is Map ? data['curve'] as Map : null;
    List<num> nums(Object? v) => v is List ? [for (final x in v) if (x is num) x] : const [];
    return titledCard(context, '${data['title'] ?? 'Hipótesis'}',
        '${data['hypothesis'] ?? ''}',
        icon: Icons.edit_note,
        children: [
          // Escenario nuevo del servidor: curvas con la complejidad del reto.
          if (curve != null) ...[
            const SizedBox(height: 8),
            AccessibleCurveChart(
              key: const ValueKey('he_curve'),
              train: nums(curve['train']),
              val: nums(curve['val']),
              height: 160,
              label: data['complexity'] is num
                  ? 'Curvas con complejidad ${(data['complexity'] as num).round()}'
                  : 'Curvas del escenario',
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('he_field'),
            controller: field,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              labelText: revisions == 0
                  ? 'Tu hipótesis revisada'
                  : 'Revisión ${revisions + 1}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const ValueKey('he_save'),
            onPressed: field.text.trim().isEmpty
                ? null
                : () {
                    revisions++;
                    TutorEvents.send(context, 'HypothesisEditor', 'hypothesisSubmitted',
                        {'hypothesis': field.text, 'revision': revisions});
                    setState(() {});
                  },
            child: Text(revisions == 0
                ? 'Guardar hipótesis'
                : 'Guardada revisión $revisions ✓'),
          ),
        ]);
  }
}
