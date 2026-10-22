import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/labs/view_models/lab_session_viewmodel.dart';
import '../../ui/core/widgets/chrome.dart';
import '../../ui/core/widgets/strings.dart';
import '../../ui/labs/widgets/lab_chrome.dart';
import '../../ui/labs/widgets/posttest.dart';
import '../../ui/labs/widgets/reflection.dart';
import '../../ui/labs/widgets/result_panel.dart';
import '../../ui/labs/widgets/concept_primer.dart';
import '../../ui/labs/widgets/curve_chart.dart';
import '../../ui/labs/widgets/hist_chart.dart';

// G2: referencia vs actual + serie con cambio; diagnosticar deriva y decidir acción.
class MonitorLabPage extends ConsumerStatefulWidget {
  final String labId;
  final String title;
  const MonitorLabPage({super.key, required this.labId, required this.title});
  @override
  ConsumerState<MonitorLabPage> createState() => _MonitorState();
}

class _MonitorState extends ConsumerState<MonitorLabPage> {
  final statusKey = GlobalKey();
  String feature = 'temp';
  double changepoint = 90;
  final answer = TextEditingController();
  Map<String, dynamic>? dist;
  int tab = 0;

  LabSessionViewModel get _vm =>
      ref.read(labSessionProvider(widget.labId).notifier);
  LabSession get lab => ref.watch(labSessionProvider(widget.labId));

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;

  @override
  void initState() {
    super.initState();
    answer.addListener(() => _vm.saveDraft(widget.labId, 'answer', answer.text));
    _init();
  }

  Future<void> _init() async {
    // P1.6: reanudar abierta antes de crear una nueva.
    if (!await _vm.resume(widget.labId)) {
      await _vm.init(widget.labId);
      if (!mounted) return;
      if (ref.read(labSessionProvider(widget.labId)).sessionId == null) {
        setState(() {});
        return;
      }
    }
    // Sprint 3: lección del objetivo (no bloquea el experimento si falla).
    await _vm.loadObjectives(widget.labId);
    await _load();
    final ft = await _vm.loadDraft(widget.labId, 'feature');
    final cp = await _vm.loadDraft(widget.labId, 'changepoint');
    final an = await _vm.loadDraft(widget.labId, 'answer');
    if (!mounted) return;
    setState(() {
      if (ft != null && ft.isNotEmpty) feature = ft;
      if (cp != null) changepoint = double.tryParse(cp) ?? changepoint;
      if (an != null) answer.text = an;
    });
  }

  Future<void> _load() async {
    try {
      final d = await _vm.fetchDistributions(widget.labId, seed);
      if (!mounted) return;
      setState(() => dist = d);
    } catch (e) {
      _vm.setStatus('Error datos: $e');
    }
  }

  Future<void> _send() async {
    final snap = ref.read(labSessionProvider(widget.labId));
    if (snap.sessionId == null || snap.evaluating) return;
    if (answer.text.trim().isEmpty) {
      _vm.setStatus('La hipótesis es obligatoria');
      return;
    }
    _vm.setEvaluating(true);
    _vm.setStatus('');
    try {
      await _vm.send({
        'seed': seed,
        'extra': {'feature': feature, 'changepoint': changepoint.round()},
        'answer_text': answer.text,
      }, posttest: snap.posttestMode);
      _vm.markDelivered(
          posttest:
              ref.read(labSessionProvider(widget.labId)).posttestMode);
      if (!ref.read(labSessionProvider(widget.labId)).posttestMode) {
        await _vm.evaluate();
      }
    } catch (e) {
      _vm.setEvaluating(false);
      _vm.setStatus('Error envío: $e');
    }
  }

  Future<void> _retry() async {
    _vm.setEvaluating(true);
    await _vm.evaluate();
    _vm.setEvaluating(false);
  }

  Future<void> _next() async {
    _vm.setNextBusy(true);
    await _vm.next();
    _vm.setNextBusy(false);
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
        crumb: labCrumb(lab.objectives),
        meta: sessionMeta(lab),
        objective: lab.posttestMode
            ? 'Distribución nueva, sin ayuda. ¿Deriva? ¿Reentrenar o monitorear?'
            : '¿Qué feature deriva? Compara referencia vs actual y ubica el cambio.',
        step: lab.step,
      ),
      const SizedBox(height: 12),
      if (lab.objectives.isNotEmpty && !lab.posttestMode)
        ConceptPrimer(objective: lab.objectives.first),
      if (lab.objectives.isNotEmpty)
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
                        _vm.saveDraft(widget.labId, 'feature', feature);
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
            : (_) => _vm.saveDraft(widget.labId, 'changepoint', '$changepoint'),
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
                : () => confirmEnterPosttestVm(context, _vm, _load),
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
              ResultPanel(lab: lab, onNext: _next, onRetry: _retry, onEvent: _vm.emitEvent),
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
                  _vm.clearDrafts(widget.labId, const ['feature', 'changepoint', 'answer']);
                }
                _vm.touch();
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

