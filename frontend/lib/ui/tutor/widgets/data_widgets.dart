import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '_shared.dart';
import 'events.dart';
import '../../labs/data/data_missions.dart' show anomalyTypeLabels;

final driftDistributionExplorer = CatalogItem(
  name: 'DriftDistributionExplorer',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del explorador'),
      'hint': S.string(description: 'Pista de qué comparar'),
      'features': S.list(
          description: 'Features a comparar', items: S.string()),
    },
    required: ['hint'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "DriftDistributionExplorer", '
        '"title": "Deriva", "hint": "Compara referencia vs actual", '
        '"features": ["temp", "pressure"]}]',
  ],
  widgetBuilder: (ctx) => _DriftDistributionExplorer(ctx),
);

/// P5.2: feature + changepoint + justificación de drift; emite
/// evidenceSelected y argumentSubmitted.
class _DriftDistributionExplorer extends StatefulWidget {
  final CatalogItemContext ctx;
  const _DriftDistributionExplorer(this.ctx);
  @override
  State<_DriftDistributionExplorer> createState() =>
      _DriftDistributionExplorerState();
}

class _DriftDistributionExplorerState
    extends State<_DriftDistributionExplorer> {
  String? feature;
  double changepoint = 90;
  final argument = TextEditingController();

  @override
  void initState() {
    super.initState();
    argument.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    argument.dispose();
    super.dispose();
  }

  List<String> get _features {
    final data = widget.ctx.data as Map;
    final f = data['features'];
    if (f is List) return [for (final e in f) '$e'];
    return const [];
  }

  void _select(String f) {
    setState(() => feature = f);
    TutorEvents.send(context, 'DriftDistributionExplorer', 'evidenceSelected',
        {'feature': f, 'changepoint': changepoint.round()});
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final cs = Theme.of(context).colorScheme;
    return titledCard(context, '${data['title'] ?? 'Deriva'}',
        '${data['hint'] ?? ''}',
        icon: Icons.science,
        accent: cs.secondary,
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final f in _features)
                ChoiceChip(
                  key: ValueKey('dde_feat_$f'),
                  label: Text(f),
                  selected: feature == f,
                  onSelected: (_) => _select(f),
                ),
            ],
          ),
          Row(
            children: [
              const Text('Cambio en'),
              Expanded(
                child: Slider(
                  key: const ValueKey('dde_changepoint'),
                  value: changepoint,
                  min: 0,
                  max: 179,
                  divisions: 179,
                  label: '${changepoint.round()}',
                  onChanged: (v) => setState(() => changepoint = v),
                  onChangeEnd: (_) {
                    if (feature != null) _select(feature!);
                  },
                ),
              ),
              Text('${changepoint.round()}'),
            ],
          ),
          TextField(
            key: const ValueKey('dde_argument'),
            controller: argument,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: '¿Drift o degradación? Justifica',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const ValueKey('dde_send'),
            onPressed: argument.text.trim().isEmpty || feature == null
                ? null
                : () => TutorEvents.send(context, 'DriftDistributionExplorer',
                    'argumentSubmitted',
                    {'argument': argument.text, 'feature': feature!}),
            child: const Text('Enviar diagnóstico'),
          ),
        ]);
  }
}

final dataTableExplorer = CatalogItem(
  name: 'DataTableExplorer',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del explorador'),
      'hint': S.string(description: 'Pista de qué buscar'),
      'n_rows': S.number(description: 'Filas de la tabla (ids 0..n-1)'),
      'rows': S.list(
          description: 'Filas contrastivas {ref, temp, unit, pressure, line}',
          items: S.object(properties: {
            'ref': S.string(),
            'temp': S.number(),
            'unit': S.string(),
            'pressure': S.number(),
            'line': S.string(),
          })),
    },
    required: ['hint'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "DataTableExplorer", '
        '"title": "Explora", "hint": "Busca anomalías", "n_rows": 30}]',
  ],
  widgetBuilder: (ctx) => _DataTableExplorer(ctx),
);

/// P5.1: marcar filas + justificación; emite evidenceSelected y argumentSubmitted.
class _DataTableExplorer extends StatefulWidget {
  final CatalogItemContext ctx;
  const _DataTableExplorer(this.ctx);
  @override
  State<_DataTableExplorer> createState() => _DataTableExplorerState();
}

class _DataTableExplorerState extends State<_DataTableExplorer> {
  final flags = TextEditingController();
  final argument = TextEditingController();
  String? flagsError;

  @override
  void initState() {
    super.initState();
    flags.addListener(() => setState(() {}));
    argument.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    flags.dispose();
    argument.dispose();
    super.dispose();
  }

  // ponytail: parseo estricto 0..n-1; lo inválido se explica, no se envía.
  List<int>? get _parsed {
    final data = widget.ctx.data as Map;
    final n = (numProp(data, 'n_rows') ?? 30).toInt();
    final out = <int>[];
    for (final part in flags.text.split(',')) {
      final t = part.trim();
      if (t.isEmpty) continue;
      final v = int.tryParse(t);
      if (v == null || v < 0 || v >= n) return null;
      out.add(v);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final rows = data['rows'];
    if (rows is List && rows.isNotEmpty) {
      return _ContrastTable(
          title: '${data['title'] ?? 'Explora'}',
          hint: '${data['hint'] ?? ''}',
          rows: [for (final r in rows) if (r is Map) r]);
    }
    final cs = Theme.of(context).colorScheme;
    final parsed = _parsed;
    return titledCard(context, '${data['title'] ?? 'Explora'}',
        '${data['hint'] ?? ''}',
        icon: Icons.table_chart,
        accent: cs.secondary,
        children: [
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('dte_flags'),
            controller: flags,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Filas sospechosas (ids separados por coma)',
              errorText: flags.text.trim().isEmpty || parsed != null
                  ? null
                  : 'Ids 0..${((numProp(data, 'n_rows') ?? 30).toInt() - 1)}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('dte_argument'),
            controller: argument,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              labelText: 'Justificación por fila marcada',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const ValueKey('dte_send'),
            onPressed: parsed == null ||
                    parsed.isEmpty ||
                    argument.text.trim().isEmpty
                ? null
                : () {
                    TutorEvents.send(context, 'DataTableExplorer', 'evidenceSelected',
                        {'flags': parsed});
                    TutorEvents.send(context, 'DataTableExplorer', 'argumentSubmitted',
                        {'argument': argument.text, 'flags': parsed});
                  },
            child: const Text('Enviar hallazgo'),
          ),
        ]);
  }
}

/// Reto contrastivo: elige una etiqueta y aplícala tocando filas reales que
/// envió el servidor. Emite evidenceSelected por fila y argumentSubmitted al final.
class _ContrastTable extends StatefulWidget {
  final String title;
  final String hint;
  final List<Map> rows;
  const _ContrastTable({required this.title, required this.hint, required this.rows});
  @override
  State<_ContrastTable> createState() => _ContrastTableState();
}

class _ContrastTableState extends State<_ContrastTable> {
  String label = 'unit';
  final marks = <String, String>{};
  final argument = TextEditingController();

  @override
  void initState() {
    super.initState();
    argument.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    argument.dispose();
    super.dispose();
  }

  void _stamp(String ref) {
    setState(() {
      if (marks[ref] == label) {
        marks.remove(ref);
      } else {
        marks[ref] = label;
      }
    });
    TutorEvents.send(context, 'DataTableExplorer', 'evidenceSelected',
        {'ref': ref, 'type': marks[ref] ?? 'sin_anomalia'});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget step(String n, String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text('$n · $t', style: tt.labelLarge),
        );
    return titledCard(context, widget.title, widget.hint,
        icon: Icons.table_chart, accent: cs.secondary, children: [
          step('1', 'Elige una etiqueta'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in anomalyTypeLabels.entries)
              if (e.key != 'sin_anomalia')
                ChoiceChip(
                  key: ValueKey('dte_label_${e.key}'),
                  label: Text(e.value),
                  selected: label == e.key,
                  onSelected: (_) => setState(() => label = e.key),
                ),
          ]),
          step('2', 'Toca las filas donde aplica (otra vez para quitarla)'),
          for (final r in widget.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: marks.containsKey('${r['ref']}')
                    ? cs.secondaryContainer
                    : cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                      color: marks.containsKey('${r['ref']}') ? cs.secondary : cs.outlineVariant),
                ),
                child: InkWell(
                  key: ValueKey('dte_row_${r['ref']}'),
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _stamp('${r['ref']}'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        SizedBox(
                          width: 44,
                          child: Text('${r['ref']}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: Text(
                            'temp ${r['temp'] ?? '— ausente'}${r['temp'] == null ? '' : ' °${r['unit']}'}'
                            ' · presión ${r['pressure'] == null ? '— ausente' : '${r['pressure']} kPa'}'
                            ' · línea ${r['line']}',
                            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                          ),
                        ),
                        if (marks['${r['ref']}'] != null) ...[
                          Icon(Icons.flag, size: 16, color: cs.secondary),
                          const SizedBox(width: 4),
                          Text(anomalyTypeLabels[marks['${r['ref']}']] ?? '',
                              style: tt.labelMedium),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          step('3', 'Explica qué distingue los casos'),
          TextField(
            key: const ValueKey('dte_argument'),
            controller: argument,
            maxLines: 4,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: '¿Qué evidencia separa un tipo de problema del otro?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            key: const ValueKey('dte_send'),
            onPressed: marks.isEmpty || argument.text.trim().isEmpty
                ? null
                : () => TutorEvents.send(context, 'DataTableExplorer', 'argumentSubmitted', {
                      'argument': argument.text,
                      'classifications': Map<String, String>.of(marks),
                      'flags': marks.keys.toList(),
                    }),
            child: const Text('Enviar hallazgo'),
          ),
        ]);
  }
}
