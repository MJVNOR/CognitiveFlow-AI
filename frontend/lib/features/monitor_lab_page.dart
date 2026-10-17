import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../session/lab_session.dart';
import '../state/app_state.dart';
import '../widgets/cards.dart';
import 'ml_lab_page.dart';

// G2: referencia vs actual + serie con cambio; diagnosticar deriva y decidir acción.
class MonitorLabPage extends StatefulWidget {
  final String labId;
  final String title;
  const MonitorLabPage({super.key, required this.labId, required this.title});
  @override
  State<MonitorLabPage> createState() => _MonitorState();
}

class _MonitorState extends State<MonitorLabPage> {
  final lab = LabSession();
  final statusKey = GlobalKey();
  String feature = 'temp';
  double changepoint = 90;
  final answer = TextEditingController();
  Map<String, dynamic>? dist;
  List<Map<String, dynamic>>? objectives;
  int tab = 0;

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;

  @override
  void initState() {
    super.initState();
    answer.addListener(() => saveDraft(widget.labId, 'answer', answer.text));
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
    // Sprint 3: lección del objetivo (no bloquea el experimento si falla).
    try {
      final objs = await fetchJson('/labs/${widget.labId}/objectives');
      if (!mounted) return;
      setState(() => objectives = [
            for (final o in objs) Map<String, dynamic>.from(o as Map)
          ]);
    } catch (_) {}
    await _load();
    final ft = await loadDraft(widget.labId, 'feature');
    final cp = await loadDraft(widget.labId, 'changepoint');
    final an = await loadDraft(widget.labId, 'answer');
    if (!mounted) return;
    setState(() {
      if (ft != null && ft.isNotEmpty) feature = ft;
      if (cp != null) changepoint = double.tryParse(cp) ?? changepoint;
      if (an != null) answer.text = an;
    });
  }

  Future<void> _load() async {
    try {
      final d = await fetchMap('/labs/${widget.labId}/distributions?seed=$seed');
      setState(() => dist = d);
    } catch (e) {
      setState(() => lab.status = 'Error datos: $e');
    }
  }

  Future<void> _send() async {
    if (lab.sessionId == null || lab.evaluating) return;
    if (answer.text.trim().isEmpty) {
      setState(() => lab.status = 'La hipótesis es obligatoria');
      return;
    }
    setState(() {
      lab.evaluating = true;
      lab.status = '';
    });
    try {
      await lab.send({
        'seed': seed,
        'extra': {'feature': feature, 'changepoint': changepoint.round()},
        'answer_text': answer.text,
      }, posttest: lab.posttestMode);
      setState(() {
        lab.evaluating = false;
        if (lab.posttestMode) {
          lab.posttestSent = true;
          lab.status = 'Postest entregado (sin ayuda)';
        } else {
          lab.status = 'Guardado ✓';
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
    answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feats = (dist?['features'] as Map?) ?? {};
    final sel = (feats[feature] as Map?) ?? {};
    final ref = (sel['ref'] as List?)?.cast<num>() ?? [];
    final cur = (sel['cur'] as List?)?.cast<num>() ?? [];
    final bins = (sel['bins'] as List?)?.cast<num>() ?? [];
    final series = (dist?['series'] as List?)?.cast<num>() ?? [];
    final hasData = ref.isNotEmpty || cur.isNotEmpty;
    final dMean = _avg(cur) - _avg(ref);
    final cs = Theme.of(context).colorScheme;
    final experimentAccent = lab.posttestMode ? null : cs.secondary;
    final locked = lab.posttestSent || lab.posttestMode;
    final controls = [
      LabHeader(
        crumb: labCrumb(objectives),
        meta: sessionMeta(lab),
        objective: lab.posttestMode
            ? 'Distribución nueva, sin ayuda. ¿Deriva? ¿Reentrenar o monitorear?'
            : '¿Qué feature deriva? Compara referencia vs actual y ubica el cambio.',
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
        title: '1 · Compara distribuciones',
        accent: experimentAccent,
        children: [
      if (dist == null && lab.status.isNotEmpty)
        Row(
          children: [
            Expanded(child: Text(lab.status)),
            TextButton(onPressed: _load, child: const Text(Strings.retry)),
          ],
        ),
      if (feats.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final k in feats.keys.cast<String>())
              ChoiceChip(
                key: ValueKey('feat_$k'),
                label: Text(k),
                selected: feature == k,
                onSelected: locked
                    ? null
                    : (_) {
                        setState(() => feature = k);
                        saveDraft(widget.labId, 'feature', feature);
                      },
              ),
          ],
        ),
      if (hasData) ...[
        const SizedBox(height: 8),
        Text(
          'Media referencia ${_avg(ref).toStringAsFixed(1)} · '
          'Media actual ${_avg(cur).toStringAsFixed(1)} · '
          'Δ ${dMean >= 0 ? '+' : ''}${dMean.toStringAsFixed(1)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          'Cambio en la entrada ≠ caída de precisión: sin etiquetas no se afirma.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: const [
                  Tab(text: 'Distribución'),
                  Tab(text: 'Serie temporal'),
                ],
                onTap: (i) => setState(() => tab = i),
              ),
              const SizedBox(height: 8),
              IndexedStack(
                index: tab,
                children: [
                  AccessibleHistChart(
                      ref: ref,
                      cur: cur,
                      bins: bins,
                      showTable: false,
                      label: 'Distribución $feature'),
                  AccessibleCurveChart(
                      train: series,
                      val: const [],
                      label: 'Serie temporal $feature',
                      height: 220,
                      labelInterval: 30),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          title: Text(tab == 0 ? 'Ver bins como tabla' : 'Ver serie como tabla',
              style: const TextStyle(fontSize: 13)),
          tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: tab == 0
                  ? DataTable(
                      dataRowMinHeight: 44,
                      columns: const [
                        DataColumn(label: Text('bin')),
                        DataColumn(label: Text('centro')),
                        DataColumn(label: Text('referencia')),
                        DataColumn(label: Text('actual')),
                      ],
                      rows: [
                        for (var i = 0; i < ref.length; i++)
                          DataRow(cells: [
                            DataCell(Text('$i')),
                            DataCell(Text(i < bins.length
                                ? bins[i].toStringAsFixed(1)
                                : '—')),
                            DataCell(Text(ref[i].toStringAsFixed(0))),
                            DataCell(Text(i < cur.length
                                ? cur[i].toStringAsFixed(0)
                                : '—')),
                          ]),
                      ],
                    )
                  : DataTable(
                      dataRowMinHeight: 44,
                      columns: const [
                        DataColumn(label: Text('t')),
                        DataColumn(label: Text('valor')),
                      ],
                      rows: [
                        for (var i = 0; i < series.length; i++)
                          DataRow(cells: [
                            DataCell(Text('$i')),
                            DataCell(Text(series[i].toStringAsFixed(1))),
                          ]),
                      ],
                    ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      ParamSlider(
        label: 'Punto de cambio',
        value: 't=${changepoint.round()}',
        help: 'Mueve el punto y mira dónde la serie actual se separa.',
        current: changepoint,
        min: 0,
        max: 179,
        divisions: 179,
        onChanged: locked ? null : (v) => setState(() => changepoint = v),
        onChangeEnd: locked
            ? null
            : (_) => saveDraft(widget.labId, 'changepoint', '$changepoint'),
      ),
        ],
      ),
      const SizedBox(height: 12),
      SectionCard(
        icon: Icons.edit_note,
        title: '2 · Hipótesis y decisión',
        accent: lab.posttestMode ? null : cs.tertiary,
        children: [
      TextField(
        key: const ValueKey('monitor_answer'),
        controller: answer, maxLines: 3,
        enabled: !lab.posttestSent,
        decoration: const InputDecoration(
          labelText: 'Hipótesis de deriva y decisión *',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      if (!lab.posttestSent)
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('monitor_send'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
            ),
            onPressed: lab.evaluating ? null : _send,
            child: Text(lab.posttestMode ? Strings.deliverPosttest : Strings.sendAttempt),
          ),
        ),
        ],
      ),
      const SizedBox(height: 12),
    ];
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!lab.posttestMode &&
            (lab.evalResult != null || lab.intervention != null))
          TextButton(
            key: const ValueKey('go_posttest'),
            onPressed: lab.sessionId == null
                ? null
                : () => confirmEnterPosttest(context, lab, setState, _load),
            child: const Text(Strings.goPosttest),
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
        if (lab.posttestMode && lab.posttestSent)
          PosttestReflection(
              lab: lab,
              labId: widget.labId,
              onUpdate: () {
                if (lab.done) {
                  clearDrafts(widget.labId, const ['feature', 'changepoint', 'answer']);
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

// G2: media descriptiva de lo visible (no afirma causalidad ni precisión).
double _avg(List<num> xs) =>
    xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b.toDouble()) / xs.length;

class HistPainter extends StatelessWidget {
  final List<num> ref;
  final List<num> cur;
  final List<num> bins;
  final Color refColor;
  final Color curColor;
  const HistPainter(this.ref, this.cur,
      {super.key, required this.refColor, required this.curColor, this.bins = const []});

  @override
  Widget build(BuildContext context) {
    if (ref.isEmpty) return const SizedBox.shrink();
    final maxV = [...ref, ...cur].fold<double>(1, (a, b) => a > b.toDouble() ? a : b.toDouble());
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: bins.isNotEmpty,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 2,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= bins.length || i.isOdd) {
                  return const SizedBox.shrink();
                }
                return Text(bins[i].toStringAsFixed(0),
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
        barGroups: [
          for (var i = 0; i < ref.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: ref[i].toDouble(), color: refColor, width: 6),
                BarChartRodData(
                  toY: i < cur.length ? cur[i].toDouble() : 0,
                  color: curColor,
                  width: 6,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Histograma referencia vs actual con alternativa textual y leyenda por
/// posición (izquierda/derecha), no por color.
class AccessibleHistChart extends StatelessWidget {
  final List<num> ref;
  final List<num> cur;
  final List<num> bins;
  final String label;
  final bool showTable;
  const AccessibleHistChart(
      {super.key,
      required this.ref,
      required this.cur,
      required this.label,
      this.bins = const [],
      this.showTable = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$label. ${ref.length} barras. Referencia suma '
              '${ref.fold<num>(0, (a, b) => a + b).toStringAsFixed(2)}, '
              'actual ${cur.fold<num>(0, (a, b) => a + b).toStringAsFixed(2)}.',
          child: SizedBox(
            height: 120,
            child: HistPainter(ref, cur,
              refColor: cs.primary, curColor: cs.secondary, bins: bins),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 12, color: cs.primary),
              const SizedBox(width: 6),
              const Text(Strings.legendRef, style: TextStyle(fontSize: 12)),
            ]),
            // ponytail: actual hueco vs referencia sólida = distinción por forma,
            // no solo color (WCAG 1.4.1); texto ya dice izquierda/derecha.
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.secondary, width: 2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(Strings.legendCur, style: TextStyle(fontSize: 12)),
            ]),
          ],
        ),
        if (showTable)
          ExpansionTile(
            title: const Text(Strings.chartDataTable,
                style: TextStyle(fontSize: 13)),
            tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 44,
                columns: [
                  const DataColumn(label: Text('bin')),
                  if (bins.isNotEmpty)
                    const DataColumn(label: Text('centro')),
                  const DataColumn(label: Text('referencia')),
                  const DataColumn(label: Text('actual')),
                ],
                rows: [
                  for (var i = 0; i < ref.length; i++)
                    DataRow(cells: [
                      DataCell(Text('$i')),
                      if (bins.isNotEmpty)
                        DataCell(Text(i < bins.length
                            ? bins[i].toStringAsFixed(1)
                            : '—')),
                      DataCell(Text(ref[i].toStringAsFixed(3))),
                      DataCell(Text(i < cur.length ? cur[i].toStringAsFixed(3) : '—')),
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

