import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../session/lab_session.dart';
import '../state/app_state.dart';
import '../widgets/cards.dart';

final _num2 = NumberFormat('0.00', 'es');

class LabDetailPage extends StatefulWidget {
  final String labId;
  final String title;
  const LabDetailPage({super.key, required this.labId, required this.title});
  @override
  State<LabDetailPage> createState() => _LabDetailState();
}

class _LabDetailState extends State<LabDetailPage> {
  final lab = LabSession();
  final statusKey = GlobalKey();
  double complexity = 5;
  double noise = 20;
  final hypo = TextEditingController();
  Map<String, dynamic>? curve;
  List<Map<String, dynamic>>? objectives;
  List<num>? savedVal;
  String? savedLabel;
  double epochSel = 0;

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;

  @override
  void initState() {
    super.initState();
    hypo.addListener(() => saveDraft(widget.labId, 'hypo', hypo.text));
    _init();
  }

  Future<void> _init() async {
    // P1.6: reanudar abierta antes de crear una nueva.
    if (!await lab.resume(widget.labId)) {
      await lab.init(widget.labId);
      if (lab.sessionId == null) {
        setState(() {});
        return;
      }
    }
    // Sprint 1: lección del objetivo (no bloquea el experimento si falla).
    try {
      final objs = await fetchJson('/labs/${widget.labId}/objectives');
      if (!mounted) return;
      setState(() => objectives = [
            for (final o in objs) Map<String, dynamic>.from(o as Map)
          ]);
    } catch (_) {}
    await _loadCurve();
    final cx = await loadDraft(widget.labId, 'complexity');
    final nz = await loadDraft(widget.labId, 'noise');
    final h = await loadDraft(widget.labId, 'hypo');
    if (!mounted) return;
    setState(() {
      if (cx != null) complexity = double.tryParse(cx) ?? complexity;
      if (nz != null) noise = double.tryParse(nz) ?? noise;
      if (h != null) hypo.text = h;
    });
    if (cx != null || nz != null) await _loadCurve();
    // En postest manda la variante del servidor, no el borrador.
    final v = lab.posttestVariant;
    if (lab.posttestMode && v != null) {
      if (!mounted) return;
      setState(() {
        complexity = (v['complexity'] as num).toDouble();
        noise = (v['noise_pct'] as num).toDouble();
      });
      await _loadCurve();
    }
  }

  Future<void> _loadCurve() async {
    try {
      final c = await fetchMap(
        '/labs/${widget.labId}/curve?complexity=${complexity.round()}&noise_pct=${noise.round()}&seed=$seed',
      );
      setState(() => curve = c);
    } catch (e) {
      setState(() => lab.status = 'Error curva: $e');
    }
  }

  Future<void> _send() async {
    if (lab.sessionId == null || lab.evaluating) return;
    if (hypo.text.trim().isEmpty) {
      setState(() => lab.status =
          lab.posttestMode ? 'El diagnóstico es obligatorio' : 'La hipótesis es obligatoria');
      return;
    }
    setState(() {
      lab.evaluating = true;
      lab.status = '';
    });
    try {
      await lab.send({
        'complexity': complexity.round(),
        'noise_pct': noise.round(),
        'seed': seed,
        'answer_text': hypo.text,
      }, posttest: lab.posttestMode);
      setState(() {
        lab.evaluating = false;
        if (lab.posttestMode) {
          lab.posttestSent = true;
          lab.status = 'Postest entregado (sin ayuda de IA)';
        } else {
          lab.status = 'Guardado ✓ (simulación, sin IA)';
        }
      });
      if (!lab.posttestMode) {
        await lab.evaluate();
        setState(() {});
      }
    } catch (e) {
      setState(() {
        lab.evaluating = false;
        lab.status = 'Error envío: $e';
      });
    }
  }

  /// Sprint 3: la época marcada queda en ui_events como evidencia seleccionada.
  Future<void> _markEvidence() async {
    if (lab.sessionId == null) return;
    try {
      await postJson('/sessions/${lab.sessionId}/events', {
        'client_event_id': newEventId(),
        'widget_type': 'LearningCurveSimulator',
        'event_type': 'evidenceSelected',
        'payload': {
          'epoch': epochSel.round(),
          'complexity': complexity.round(),
          'noise_pct': noise.round(),
          'mode': lab.posttestMode ? 'posttest' : 'practice',
        },
      });
      if (!mounted) return;
      setState(() => lab.status = 'Evidencia guardada: época ${epochSel.round()}');
    } catch (e) {
      if (!mounted) return;
      setState(() => lab.status = 'No se guardó la evidencia: $e');
    }
  }

  Future<void> _retry() async {
    setState(() => lab.evaluating = true);
    await lab.evaluate();
    setState(() => lab.evaluating = false);
  }

  Future<void> _next() async {
    setState(() => lab.nextBusy = true);
    await lab.next();
    setState(() => lab.nextBusy = false);
  }

  @override
  void dispose() {
    hypo.dispose();
    super.dispose();
  }

  /// Miga Ruta > Módulo > Unidad derivada del objetivo (sin hardcodear textos).
  String? _crumb() => labCrumb(objectives);

  @override
  Widget build(BuildContext context) {
    final train = (curve?['train'] as List?)?.cast<num>() ?? [];
    final val = (curve?['val'] as List?)?.cast<num>() ?? [];
    final sent = lab.posttestSent;
    // P4.1: variante fijada por el servidor; en postest no se toca.
    final locked = sent || lab.posttestMode;
    final cs = Theme.of(context).colorScheme;
    final experimentAccent =
        lab.posttestMode ? null : cs.secondary;
    final controls = [
      LabHeader(
        crumb: _crumb(),
        meta: sessionMeta(lab),
        objective: lab.posttestMode
            ? 'Variante nueva. Sin pistas ni tutor hasta entregar.'
            : 'Predice el efecto de la complejidad y justifica por qué',
        step: lab.step,
      ),
      const SizedBox(height: 12),
      if (objectives != null && objectives!.isNotEmpty)
        ConceptPrimer(objective: objectives!.first),
      if (objectives != null && objectives!.isNotEmpty)
        const SizedBox(height: 12),
      if (lab.posttestMode) const PosttestBanner(),
      if (lab.posttestMode) const SizedBox(height: 12),
      SectionCard(
        icon: Icons.science,
        title: '1 · Experimenta con las curvas',
        accent: experimentAccent,
        trailing: curve?['simulated'] == true
            ? const Chip(
                label: Text(Strings.simulated,
                    style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              )
            : null,
        children: [
          if (train.isEmpty && val.isEmpty && lab.status.isNotEmpty)
            Row(
              children: [
                Expanded(child: Text(lab.status)),
                TextButton(onPressed: _loadCurve, child: const Text(Strings.retry)),
              ],
            ),
          AccessibleCurveChart(
            train: train,
            val: val,
            val2: savedVal,
            height: 220,
            label: lab.posttestMode ? 'Curvas del postest' : 'Curvas de pérdida',
          ),
          const SizedBox(height: 12),
          // P4.1: variante fijada por el servidor; en postest no se toca.
          ParamSlider(
            label: 'Complejidad del modelo',
            value: '${complexity.round()} / 10',
            help: 'Sube la complejidad y mira cuándo la validación se despega.',
            current: complexity,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: locked ? null : (v) => setState(() => complexity = v),
            onChangeEnd: locked
                ? null
                : (_) {
                    _loadCurve();
                    saveDraft(widget.labId, 'complexity', '$complexity');
                  },
          ),
          ParamSlider(
            label: 'Ruido en los datos',
            value: '${noise.round()} %',
            help: 'Más ruido → ambas curvas más altas e inestables.',
            current: noise,
            min: 0,
            max: 50,
            divisions: 10,
            onChanged: locked ? null : (v) => setState(() => noise = v),
            onChangeEnd: locked
                ? null
                : (_) {
                    _loadCurve();
                    saveDraft(widget.labId, 'noise', '$noise');
                  },
          ),
          if (train.isNotEmpty) ...[
            const SizedBox(height: 8),
            ParamSlider(
              label: 'Época de divergencia',
              value: 'e${epochSel.round()}',
              help: 'Marca dónde se despega la validación y úsala como evidencia.',
              current: epochSel.clamp(0, (train.length - 1).toDouble()),
              min: 0,
              max: (train.length - 1).toDouble(),
              divisions: train.length > 1 ? train.length - 1 : 1,
              onChanged: locked ? null : (v) => setState(() => epochSel = v),
              onChangeEnd: null,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  key: const ValueKey('ml_mark_evidence'),
                  onPressed:
                      lab.sessionId == null || sent ? null : _markEvidence,
                  child: const Text('Marcar época como evidencia'),
                ),
                OutlinedButton(
                  key: const ValueKey('ml_save_run'),
                  onPressed: curve == null
                      ? null
                      : () => setState(() {
                            savedVal = List<num>.from(val);
                            savedLabel =
                                'C${complexity.round()}·R${noise.round()}';
                          }),
                  child: Text(savedVal == null
                      ? 'Guardar corrida'
                      : 'Guardada: $savedLabel (reemplazar)'),
                ),
                if (savedVal != null)
                  TextButton(
                    key: const ValueKey('ml_clear_run'),
                    onPressed: () => setState(() => savedVal = null),
                    child: const Text('Quitar guardada'),
                  ),
              ],
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
      SectionCard(
        icon: Icons.edit_note,
        title: '2 · Predice y justifica',
        accent: lab.posttestMode ? null : cs.tertiary,
        children: [
          TextField(
            key: const ValueKey('ml_hypo'),
            controller: hypo,
            maxLines: 4,
            minLines: 3,
            enabled: !sent,
            decoration: InputDecoration(
              labelText: lab.posttestMode
                  ? 'Tu diagnóstico y justificación *'
                  : 'Hipótesis / justificación (obligatoria)',
              helperText: lab.posttestMode
                  ? 'Cita ambas curvas y tu decisión.'
                  : 'Predice qué pasa al subir la complejidad y cita las dos curvas.',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!sent)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('ml_send'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                onPressed: lab.evaluating ? null : _send,
                child: Text(lab.posttestMode
                    ? Strings.deliverPosttest
                    : Strings.sendAttempt),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ];
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Una sola acción principal: el postest solo aparece tras la primera evaluación.
        if (!lab.posttestMode && (lab.evalResult != null || lab.intervention != null))
          TextButton(
            key: const ValueKey('go_posttest'),
            onPressed: lab.sessionId == null
                ? null
                : () => confirmEnterPosttest(context, lab, setState, _loadCurve, () {
                      final v = lab.posttestVariant;
                      if (v != null) {
                        complexity = (v['complexity'] as num).toDouble();
                        noise = (v['noise_pct'] as num).toDouble();
                      }
                    }),
            child: const Text(Strings.goPosttestNoAI),
          ),
        if (!lab.posttestMode &&
            (lab.evalResult != null ||
                lab.evaluating ||
                lab.evalError != null ||
                lab.intervention != null))
          SectionCard(
            icon: Icons.fact_check,
            title: '3 · Evidencia y siguiente paso',
            children: [
              ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
            ],
          ),
        if (!lab.posttestMode &&
            lab.evalResult == null &&
            !lab.evaluating &&
            lab.evalError == null &&
            lab.intervention == null)
          ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
        if (lab.posttestMode && sent)
          PosttestReflection(
              lab: lab,
              labId: widget.labId,
              onUpdate: () {
                if (lab.done) {
                  clearDrafts(widget.labId, const ['complexity', 'noise', 'hypo']);
                }
                setState(() {});
              }),
        StatusText(lab.status, key: statusKey),
      ],
    );
    return Scaffold(
      appBar: DoubleTitleBar(
          title: widget.title, backRoute: '/labs', posttest: lab.posttestMode),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1100) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ListView(padding: const EdgeInsets.all(16), children: controls)),
                    SizedBox(
                      width: (constraints.maxWidth * 0.35).clamp(320.0, 420.0),
                      child: ListView(padding: const EdgeInsets.all(16), children: [result]),
                    ),
                  ],
                );
              }
              return ListView(padding: const EdgeInsets.all(16), children: [...controls, result]);
            },
          ),
        ),
      ),
    );
  }
}

/// Microlección del objetivo antes del reto (Sprint 1): concepto siempre
/// visible + ejemplo resuelto colapsable para avanzados.
class ConceptPrimer extends StatelessWidget {
  final Map<String, dynamic> objective;
  const ConceptPrimer({super.key, required this.objective});
  @override
  Widget build(BuildContext context) {
    final steps =
        (objective['worked_example_steps'] as List?)?.cast<String>() ?? [];
    return SectionCard(
      icon: Icons.menu_book_outlined,
      title: 'El concepto en 1 minuto',
      children: [
        Text('${objective['title'] ?? ''}',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('${objective['concept_summary'] ?? ''}'),
        if (steps.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Ver ejemplo resuelto',
                style: TextStyle(fontSize: 13)),
            children: [
              for (var i = 0; i < steps.length; i++)
                ListTile(
                  dense: true,
                  leading: Text('${i + 1}.'),
                  title:
                      Text(steps[i], style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
      ],
    );
  }
}

/// Curva de entrenamiento (continua) vs validación (discontinua).
/// Colores desde el tema — nunca hard-coded — para modo claro/oscuro y
/// diferenciación por estilo además de color (WCAG 1.4.1).
class CurvePainter extends StatelessWidget {
  final List<num> train;
  final List<num> val;
  final Color trainColor;
  final Color valColor;
  final double labelInterval;
  final List<num>? val2;
  final Color? savedColor;
  const CurvePainter(this.train, this.val,
      {super.key,
      required this.trainColor,
      required this.valColor,
      this.labelInterval = 5,
      this.val2,
      this.savedColor});

  List<FlSpot> _spots(List<num> ys) => [
        for (var i = 0; i < ys.length; i++)
          FlSpot(i.toDouble(), ys[i].toDouble().clamp(0, 1)),
      ];

  @override
  Widget build(BuildContext context) {
    if (train.isEmpty && val.isEmpty) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: labelInterval,
              getTitlesWidget: (v, _) => Text(
                'e${v.toInt()}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          if (train.isNotEmpty)
            LineChartBarData(
              spots: _spots(train),
              isCurved: false,
              color: trainColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          if (val.isNotEmpty)
            LineChartBarData(
              spots: _spots(val),
              isCurved: false,
              color: valColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
          if (val2 != null && val2!.isNotEmpty && savedColor != null)
            LineChartBarData(
              spots: _spots(val2!),
              isCurved: false,
              color: savedColor!,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [2, 4],
            ),
        ],
      ),
    );
  }
}

/// Gráfico de curvas con alternativa textual (WCAG 1.1.1) y leyenda sin
/// nombres de color.
// ponytail: sin animaciones propias; solo transiciones M3 por defecto
// (ExpansionTile, navegación), ninguna bloquea tareas ni transmite
// información solo por movimiento.
class AccessibleCurveChart extends StatelessWidget {
  final List<num> train;
  final List<num> val;
  final String label;
  final double height;
  final double labelInterval;
  final List<num>? val2;
  const AccessibleCurveChart({super.key, required this.train, required this.val, required this.label, this.height = 180, this.labelInterval = 5, this.val2});

  String _summary(List<num> ys) {
    if (ys.isEmpty) return 'sin datos';
    final min = ys.reduce((a, b) => a < b ? a : b);
    final max = ys.reduce((a, b) => a > b ? a : b);
    return '${ys.length} puntos, mín ${_num2.format(min)}, máx ${_num2.format(max)}, '
        'último ${_num2.format(ys.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$label. Entrenamiento: ${_summary(train)}. Validación: ${_summary(val)}.',
          child: SizedBox(
            height: height,
            child: CurvePainter(train, val,
                trainColor: cs.primary,
                valColor: cs.tertiary,
                labelInterval: labelInterval,
                val2: val2,
                savedColor: cs.outline),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 24, height: 3, color: cs.primary),
              const SizedBox(width: 6),
              const Text(Strings.legendTrain, style: TextStyle(fontSize: 12)),
            ]),
            // ponytail: muestra discontinua = redundancia no-cromática (WCAG 1.4.1);
            // la curva real ya usa dashArray [6,4].
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 24,
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Container(width: 6, height: 3, color: cs.tertiary),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(Strings.legendVal, style: TextStyle(fontSize: 12)),
            ]),
            if (val2 != null && val2!.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 30,
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        Container(width: 4, height: 3, color: cs.outline),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Corrida guardada (línea punteada)',
                    style: TextStyle(fontSize: 12)),
              ]),
          ],
        ),
        ExpansionTile(
          title: const Text(Strings.chartDataTable, style: TextStyle(fontSize: 13)),
          tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 44,
                columns: const [
                  DataColumn(label: Text('i')),
                  DataColumn(label: Text('entrenamiento')),
                  DataColumn(label: Text('validación')),
                ],
                rows: [
                  for (var i = 0; i < train.length; i++)
                    DataRow(cells: [
                      DataCell(Text('$i')),
                      DataCell(Text(train[i].toStringAsFixed(3))),
                      DataCell(Text(i < val.length ? val[i].toStringAsFixed(3) : '—')),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

