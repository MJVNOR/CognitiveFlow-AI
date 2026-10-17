// Catálogo GenUI cerrado (genui 0.10.4, ver pubspec.lock).
// Espejo exacto del backend (app/interventions.py CATALOG).
// ponytail: sin eventos GenUI nativos aún; el loop usa nuestros eventos REST (verificado E2E).
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

// P1.5: sink de eventos widget → backend. TutorSurface lo cablea a
// POST /sessions/{id}/events; null en tests unitarios del catálogo.
// ponytail: un static, no InheritedWidget para un solo callback.
abstract final class TutorEvents {
  static void Function(String widgetType, String eventType, Map<String, Object?> payload)? emit;
  static void send(String w, String e, [Map<String, Object?> p = const {}]) =>
      emit?.call(w, e, p);
}

double? _numProp(Map data, String key) {
  final v = data[key];
  return v is num ? v.toDouble() : null;
}

Widget _titledCard(BuildContext context, String title, String body,
    {IconData? icon, Color? accent, List<Widget> children = const []}) {
  return Card(
    shape: accent == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: accent),
          ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
            ],
          ),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          ...children,
        ],
      ),
    ),
  );
}

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
  });
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
    return _titledCard(context, '${data['title'] ?? 'Compara'}',
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
                    TutorEvents.send('EvidenceComparison', 'evidenceSelected',
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
                    TutorEvents.send('EvidenceComparison', 'argumentSubmitted',
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
    return _titledCard(context, '${data['title'] ?? 'Hipótesis'}',
        '${data['hypothesis'] ?? ''}',
        icon: Icons.edit_note,
        children: [
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
                    TutorEvents.send('HypothesisEditor', 'hypothesisSubmitted',
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
    TutorEvents.send('DriftDistributionExplorer', 'evidenceSelected',
        {'feature': f, 'changepoint': changepoint.round()});
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final cs = Theme.of(context).colorScheme;
    return _titledCard(context, '${data['title'] ?? 'Deriva'}',
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
                : () => TutorEvents.send('DriftDistributionExplorer',
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
    final n = (_numProp(data, 'n_rows') ?? 30).toInt();
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
    final cs = Theme.of(context).colorScheme;
    final parsed = _parsed;
    return _titledCard(context, '${data['title'] ?? 'Explora'}',
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
                  : 'Ids 0..${((_numProp(data, 'n_rows') ?? 30).toInt() - 1)}',
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
                    TutorEvents.send('DataTableExplorer', 'evidenceSelected',
                        {'flags': parsed});
                    TutorEvents.send('DataTableExplorer', 'argumentSubmitted',
                        {'argument': argument.text, 'flags': parsed});
                  },
            child: const Text('Enviar hallazgo'),
          ),
        ]);
  }
}

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
    widgetBuilder: (ctx) => _card(ctx, 'title', 'question',
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
    complexity = (_numProp(data, 'complexity') ?? 5).clamp(1, 10);
    noise = (_numProp(data, 'noise_pct') ?? 20).clamp(0, 50);
  }

  void _changed() => TutorEvents.send('LearningCurveSimulator', 'parameterChanged',
      {'complexity': complexity.round(), 'noise_pct': noise.round()});

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final cs = Theme.of(context).colorScheme;
    return _titledCard(context, '${data['title'] ?? 'Simula'}',
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

/// D01: clasificar 3 escenarios contenedor vs VM; emite evidenceSelected.
final containerVsVmExplorer = CatalogItem(
  name: 'ContainerVsVmExplorer',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del reto'),
      'question': S.string(description: 'Consigna'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "ContainerVsVmExplorer", '
        '"title": "Contenedor o VM", "question": "Clasifica cada escenario"}]',
  ],
  widgetBuilder: (ctx) => _ContainerVsVm(ctx),
);

const _containerScenarios = [
  'App que debe correr igual en tu PC y en el servidor',
  'Necesitas otro kernel y drivers específicos',
  'Tu archivo desapareció al recrear el entorno',
];

class _ContainerVsVm extends StatefulWidget {
  final CatalogItemContext ctx;
  const _ContainerVsVm(this.ctx);
  @override
  State<_ContainerVsVm> createState() => _ContainerVsVmState();
}

class _ContainerVsVmState extends State<_ContainerVsVm> {
  final choices = <int?>[null, null, null]; // 0 contenedor, 1 VM
  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    final ready = choices.every((c) => c != null);
    return _titledCard(context, '${data['title'] ?? 'Contenedor o VM'}',
        '${data['question'] ?? ''}',
        icon: Icons.inventory_2_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          for (var i = 0; i < _containerScenarios.length; i++) ...[
            Text(_containerScenarios[i],
                style: Theme.of(context).textTheme.bodySmall),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: ValueKey('cve_c_$i'),
                  label: const Text('Contenedor'),
                  selected: choices[i] == 0,
                  onSelected: (_) => setState(() => choices[i] = 0),
                ),
                ChoiceChip(
                  key: ValueKey('cve_v_$i'),
                  label: const Text('VM'),
                  selected: choices[i] == 1,
                  onSelected: (_) => setState(() => choices[i] = 1),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.tonal(
            key: const ValueKey('cve_send'),
            onPressed: ready
                ? () => TutorEvents.send('ContainerVsVmExplorer',
                    'evidenceSelected', {
                    'choices': [for (final c in choices) c]
                  })
                : null,
            child: const Text('Enviar clasificación'),
          ),
        ]);
  }
}

/// D02: simular ciclo pull/run/stop/rm por pasos; emite al completar.
final imageContainerLifecycle = CatalogItem(
  name: 'ImageContainerLifecycle',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del ciclo'),
      'question': S.string(description: 'Consigna'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "ImageContainerLifecycle", '
        '"title": "Ciclo de vida", "question": "Avanza el ciclo y observa"}]',
  ],
  widgetBuilder: (ctx) => _ImageLifecycle(ctx),
);

const _lifecycleStages = ['pull / build', 'run', 'stop', 'rm'];
const _lifecycleNotes = [
  'La imagen aún no existe aquí.',
  'Imagen lista. El contenedor corre.',
  'Contenedor detenido (existe, no corre).',
  'Contenedor eliminado.',
  'Ciclo completo: la imagen sigue disponible.',
];

class _ImageLifecycle extends StatefulWidget {
  final CatalogItemContext ctx;
  const _ImageLifecycle(this.ctx);
  @override
  State<_ImageLifecycle> createState() => _ImageLifecycleState();
}

class _ImageLifecycleState extends State<_ImageLifecycle> {
  int step = 0;
  bool sent = false;
  void _advance() {
    if (step >= _lifecycleStages.length) return;
    setState(() => step++);
    if (step == _lifecycleStages.length && !sent) {
      sent = true;
      TutorEvents.send('ImageContainerLifecycle', 'evidenceSelected',
          {'completed': true, 'stages': _lifecycleStages});
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    return _titledCard(context, '${data['title'] ?? 'Ciclo de vida'}',
        '${data['question'] ?? ''}',
        icon: Icons.sync,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < _lifecycleStages.length; i++)
                Chip(
                  label: Text(_lifecycleStages[i],
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: i < step
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_lifecycleNotes[step],
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonal(
                key: const ValueKey('icl_next'),
                onPressed: step >= _lifecycleStages.length ? null : _advance,
                child: const Text('Avanzar'),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('icl_reset'),
                onPressed: () => setState(() {
                  step = 0;
                  sent = false;
                }),
                child: const Text('Reiniciar'),
              ),
            ],
          ),
        ]);
  }
}

/// D04: reordenar instrucciones Dockerfile; emite el orden propuesto.
final dockerfileWorkbench = CatalogItem(
  name: 'DockerfileWorkbench',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del reto'),
      'question': S.string(description: 'Consigna'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "DockerfileWorkbench", '
        '"title": "Dockerfile", "question": "Ordena y reconstruye"}]',
  ],
  widgetBuilder: (ctx) => _DockerfileWorkbench(ctx),
);

const _dockerLines = [
  'FROM python:3.12-slim',
  'COPY requirements.txt ./',
  'RUN pip install --no-cache-dir -r requirements.txt',
  'COPY ./app ./app',
];

class _DockerfileWorkbench extends StatefulWidget {
  final CatalogItemContext ctx;
  const _DockerfileWorkbench(this.ctx);
  @override
  State<_DockerfileWorkbench> createState() => _DockerfileWorkbenchState();
}

class _DockerfileWorkbenchState extends State<_DockerfileWorkbench> {
  // ponytail: orden inicial deliberadamente malo (app antes que deps).
  var order = [0, 3, 1, 2];
  void _move(int pos, int dir) {
    final next = pos + dir;
    if (next < 0 || next >= order.length) return;
    setState(() {
      final t = order[pos];
      order[pos] = order[next];
      order[next] = t;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    return _titledCard(context, '${data['title'] ?? 'Dockerfile'}',
        '${data['question'] ?? ''}',
        icon: Icons.description_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          Text(
              'COPY requirements + RUN pip antes que COPY del código conserva la caché.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          for (var pos = 0; pos < order.length; pos++)
            Row(
              children: [
                Expanded(
                  child: Text('${pos + 1}. ${_dockerLines[order[pos]]}',
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'monospace')),
                ),
                IconButton(
                  key: ValueKey('dw_up_$pos'),
                  tooltip: 'Subir',
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed:
                      pos == 0 ? null : () => _move(pos, -1),
                ),
                IconButton(
                  key: ValueKey('dw_down_$pos'),
                  tooltip: 'Bajar',
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: pos == order.length - 1
                      ? null
                      : () => _move(pos, 1),
                ),
              ],
            ),
          const SizedBox(height: 4),
          FilledButton.tonal(
            key: const ValueKey('dw_send'),
            onPressed: () => TutorEvents.send('DockerfileWorkbench',
                'evidenceSelected', {
              'order': [for (final i in order) _dockerLines[i]]
            }),
            child: const Text('Reconstruir'),
          ),
        ]);
  }
}

/// D07: predecir persistencia, escribir, recrear; emite predicción y observación.
final persistenceExperiment = CatalogItem(
  name: 'PersistenceExperiment',
  dataSchema: S.object(
    properties: {
      'title': S.string(description: 'Título del experimento'),
      'question': S.string(description: 'Consigna'),
    },
    required: ['question'],
  ),
  exampleData: [
    () => '[{"id": "root", "component": "PersistenceExperiment", '
        '"title": "Persistencia", "question": "Predice y recrea"}]',
  ],
  widgetBuilder: (ctx) => _PersistenceExperiment(ctx),
);

const _mountLabels = ['sin montaje', 'named volume', 'bind mount'];

class _PersistenceExperiment extends StatefulWidget {
  final CatalogItemContext ctx;
  const _PersistenceExperiment(this.ctx);
  @override
  State<_PersistenceExperiment> createState() => _PersistenceExperimentState();
}

class _PersistenceExperimentState extends State<_PersistenceExperiment> {
  int? mount;
  bool? predicted;
  bool written = false;
  bool? observed;
  void _recreate() {
    final survives = (mount ?? 0) != 0;
    setState(() => observed = survives);
    TutorEvents.send('PersistenceExperiment', 'evidenceSelected', {
      'mount': _mountLabels[mount ?? 0],
      'predicted': predicted,
      'observed': survives,
      'match': predicted == survives,
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.ctx.data as Map;
    return _titledCard(context, '${data['title'] ?? 'Persistencia'}',
        '${data['question'] ?? ''}',
        icon: Icons.save_outlined,
        accent: Theme.of(context).colorScheme.secondary,
        children: [
          const Text('1 · Elige montaje', style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _mountLabels.length; i++)
                ChoiceChip(
                  key: ValueKey('pe_mount_$i'),
                  label: Text(_mountLabels[i]),
                  selected: mount == i,
                  onSelected: (_) => setState(() {
                    mount = i;
                    written = false;
                    observed = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('2 · Predice: ¿sobrevive al recrear?',
              style: TextStyle(fontSize: 12)),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                key: const ValueKey('pe_pred_survive'),
                label: const Text('Sobrevive'),
                selected: predicted == true,
                onSelected: (_) {
                  setState(() => predicted = true);
                  TutorEvents.send('PersistenceExperiment',
                      'predictionSubmitted', {
                    'predicted': true,
                    'mount': mount == null ? null : _mountLabels[mount!],
                  });
                },
              ),
              ChoiceChip(
                key: const ValueKey('pe_pred_lost'),
                label: const Text('Se pierde'),
                selected: predicted == false,
                onSelected: (_) {
                  setState(() => predicted = false);
                  TutorEvents.send('PersistenceExperiment',
                      'predictionSubmitted', {
                    'predicted': false,
                    'mount': mount == null ? null : _mountLabels[mount!],
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              FilledButton.tonal(
                key: const ValueKey('pe_write'),
                onPressed: mount == null || written ? null : () => setState(() => written = true),
                child: const Text('Escribir archivo'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                key: const ValueKey('pe_recreate'),
                onPressed: !written || observed != null ? null : _recreate,
                child: const Text('Recrear'),
              ),
            ],
          ),
          if (observed != null)
            Text(
                'El archivo ${observed! ? 'sobrevivió' : 'se perdió'}'
                '${predicted == null ? '.' : (predicted == observed ? ' — acertaste.' : ' — fallaste, revisa tu modelo.')}',
                style: Theme.of(context).textTheme.bodySmall),
        ]);
  }
}

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
  'ContainerVsVmExplorer',
  'ImageContainerLifecycle',
  'DockerfileWorkbench',
  'PersistenceExperiment',
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
  containerVsVmExplorer,
  imageContainerLifecycle,
  dockerfileWorkbench,
  persistenceExperiment,
];
