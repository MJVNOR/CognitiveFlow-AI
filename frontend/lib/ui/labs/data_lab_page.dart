import 'dart:convert';

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
import '../../ui/labs/data/cleaning_preview.dart';

// G1: tabla sintética, marcar anomalías, justificar, postest con tabla nueva.
class DataLabPage extends ConsumerStatefulWidget {
  final String labId;
  final String title;
  const DataLabPage({super.key, required this.labId, required this.title});
  @override
  ConsumerState<DataLabPage> createState() => _DataLabState();
}

class _DataLabState extends ConsumerState<DataLabPage> {
  final statusKey = GlobalKey();
  List columns = [];
  List rows = [];
  final flagged = <int>{};
  final cellTypes = <String, String>{};
  final actions = <String, String>{};
  final justification = TextEditingController();

  LabSessionViewModel get _vm =>
      ref.read(labSessionProvider(widget.labId).notifier);
  LabSession get lab => ref.watch(labSessionProvider(widget.labId));

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;

  @override
  void initState() {
    super.initState();
    justification.addListener(
        () => _vm.saveDraft(widget.labId, 'justification', justification.text));
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
    await _loadTable();
    // Sprint 3: lección del objetivo (no bloquea la tabla si falla).
    await _vm.loadObjectives(widget.labId);
    // Borrador previo (si salió del lab sin entregar).
    final f = await _vm.loadDraft(widget.labId, 'flagged');
    final cm = await _vm.loadDraft(widget.labId, 'cellmap');
    final j = await _vm.loadDraft(widget.labId, 'justification');
    if (!mounted) return;
    setState(() {
      if (f != null && f.isNotEmpty) {
        flagged.addAll(
            [for (final p in f.split(',')) int.tryParse(p)].whereType<int>());
      }
      if (cm != null && cm.isNotEmpty) {
        try {
          final m = Map<String, dynamic>.from(jsonDecode(cm) as Map);
          cellTypes.addAll(
              Map<String, String>.from(m['types'] as Map? ?? {}));
          actions.addAll(
              Map<String, String>.from(m['actions'] as Map? ?? {}));
        } catch (_) {}
      }
      if (j != null) justification.text = j;
    });
  }

  Future<void> _loadTable() async {
    try {
      final ds = await _vm.fetchDataset(widget.labId, seed);
      if (!mounted) return;
      setState(() {
        columns = ds['columns'] as List;
        rows = ds['rows'] as List;
        flagged.clear();
      });
    } catch (e) {
      _vm.setStatus('Error tabla: $e');
    }
  }

  Future<void> _send() async {
    final snap = ref.read(labSessionProvider(widget.labId));
    if (snap.sessionId == null || snap.evaluating) return;
    if (justification.text.trim().isEmpty) {
      _vm.setStatus('La justificación es obligatoria');
      return;
    }
    _vm.setEvaluating(true);
    _vm.setStatus('');
    try {
      await _vm.send({
        'seed': seed,
        'flags': flagged.toList(),
        'extra': {'cell_types': cellTypes, 'actions': actions},
        'answer_text': justification.text,
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

  final scrollCtrl = ScrollController();
  final hCtrl = ScrollController();

  @override
  void dispose() {
    justification.dispose();
    scrollCtrl.dispose();
    hCtrl.dispose();
    super.dispose();
  }

  Future<void> _persistFlags() async {
    await _vm.saveDraft(
        widget.labId, 'flagged', flagged.map((e) => '$e').join(','));
    await _vm.saveDraft(widget.labId, 'cellmap',
        jsonEncode({'types': cellTypes, 'actions': actions}));
  }

  /// Inspector contextual por celda: tipo de anomalía + acción de limpieza.
  Future<void> _inspect(Map r) async {
    final id = '${r['id']}';
    var type = cellTypes[id] ?? 'sin_anomalia';
    var action = actions[id] ?? 'revisar';
    final res = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: Text('Fila $id'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text([for (final col in columns) '$col: ${r['$col']}']
                    .join('\n')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('inspector_type'),
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de anomalía',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in anomalyTypeLabels.entries)
                      DropdownMenuItem(
                          value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setDialog(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('inspector_action'),
                  initialValue: action,
                  decoration: const InputDecoration(
                    labelText: 'Acción de limpieza',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final e in cleaningActionLabels.entries)
                      DropdownMenuItem(
                          value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setDialog(() => action = v ?? action),
                ),
              ],
            ),
          ),
          actions: [
            if (flagged.contains(int.tryParse(id) ?? -1))
              TextButton(
                key: const ValueKey('inspector_clear'),
                onPressed: () => Navigator.of(c).pop('clear'),
                child: const Text('Quitar marca'),
              ),
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const ValueKey('inspector_save'),
              onPressed: () => Navigator.of(c).pop('save:$type:$action'),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (res == 'clear') {
      setState(() {
        flagged.remove(int.tryParse(id));
        cellTypes.remove(id);
        actions.remove(id);
      });
      await _persistFlags();
    } else if (res != null && res.startsWith('save:')) {
      final parts = res.split(':');
      final t = parts.length > 1 ? parts[1] : 'sin_anomalia';
      final a = parts.length > 2 ? parts[2] : 'revisar';
      setState(() {
        if (t == 'sin_anomalia') {
          flagged.remove(int.tryParse(id));
          cellTypes.remove(id);
          actions.remove(id);
        } else {
          flagged.add(int.tryParse(id) ?? -1);
          cellTypes[id] = t;
          actions[id] = a;
        }
      });
      await _persistFlags();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final experimentAccent = lab.posttestMode ? null : cs.secondary;
    return Scaffold(
      appBar: DoubleTitleBar(
          title: widget.title, backRoute: '/labs', posttest: lab.posttestMode),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // P6.2: mismo split desktop que ML/Monitor (actividad | tutor).
              final controls = <Widget>[
              LabHeader(
                crumb: labCrumb(lab.objectives),
                meta: sessionMeta(lab),
                objective: lab.posttestMode
                    ? 'Tabla nueva, sin ayuda. Marca anomalías y justifica.'
                    : 'Marca las filas con anomalías y justifica tu plan de limpieza.',
                step: lab.step,
              ),
              const SizedBox(height: 12),
              if (lab.objectives.isNotEmpty)
                ConceptPrimer(objective: lab.objectives.first),
              if (lab.objectives.isNotEmpty)
                const SizedBox(height: 12),
              const SizedBox(height: 12),
              if (lab.posttestMode) const PosttestBanner(),
              if (lab.posttestMode) const SizedBox(height: 12),
              SectionCard(
                icon: Icons.science,
                title: '1 · Explora la tabla',
                accent: experimentAccent,
                children: [
              if (columns.isNotEmpty)
                const Text(Strings.scrollHint, style: TextStyle(fontSize: 12)),
              if (columns.isEmpty && lab.status.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (columns.isEmpty && lab.status.isNotEmpty)
                Row(
                  children: [
                    Expanded(child: Text(lab.status)),
                    TextButton(onPressed: _loadTable, child: const Text(Strings.retry)),
                  ],
                ),
              if (columns.isNotEmpty)
              Scrollbar(
                controller: hCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: hCtrl,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    // ponytail: filas ≥44px (WCAG 2.5.8).
                    dataRowMinHeight: 44,
                    columns: [for (final c in columns) DataColumn(label: Text('$c'))],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          key: ValueKey('datarow_${r['id']}'),
                          selected: flagged.contains(r['id']),
                          onSelectChanged: (_) => _inspect(r),
                          // ponytail: key en la celda (con RenderBox) para taps exactos;
                          // la key en DataRow no resuelve centro útil en web.
                          cells: [
                            for (final c in columns)
                              DataCell(Text('${r['$c'] ?? '—'}',
                                  key: ValueKey('datacell_${r['id']}_$c'))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                icon: Icons.preview,
                title: 'Vista previa de limpieza (simulación)',
                children: [
                  Builder(builder: (context) {
                    if (flagged.isEmpty) {
                      return const Text(
                          'Marca filas con el inspector para simular su limpieza.',
                          style: TextStyle(fontSize: 12));
                    }
                    final pv = cleanedPreview(
                        rows, flagged, cellTypes, actions);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${pv.removed} eliminadas · ${pv.converted} reparadas · ${pv.rows.length} finales',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            dataRowMinHeight: 44,
                            columns: [
                              for (final c in columns)
                                DataColumn(label: Text('$c')),
                            ],
                            rows: [
                              for (final m in pv.rows)
                                DataRow(cells: [
                                  for (final c in columns)
                                    DataCell(Text('${m['$c'] ?? '—'}')),
                                ]),
                            ],
                          ),
                        ),
                        const Text(
                            'Simulación client-side: no modifica los datos.',
                            style: TextStyle(fontSize: 11)),
                      ],
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                icon: Icons.edit_note,
                title: '2 · Justifica tu plan',
                accent: lab.posttestMode ? null : cs.tertiary,
                children: [
          TextField(
            key: const ValueKey('data_justification'),
            controller: justification,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Justificación y plan de limpieza *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('data_send'),
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
                  : () => confirmEnterPosttestVm(context, _vm, _loadTable),
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
                  if (ref.read(labSessionProvider(widget.labId)).done) {
                    _vm.clearDrafts(widget.labId,
                        const ['flagged', 'cellmap', 'justification']);
                  }
                  _vm.touch();
                }),
          StatusText(lab.status, key: statusKey),
            ],
          );
              if (constraints.maxWidth >= 1100) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: ListView(
                            padding: const EdgeInsets.all(16),
                            controller: scrollCtrl,
                            children: controls)),
                    SizedBox(
                      width: (constraints.maxWidth * 0.35).clamp(320.0, 420.0),
                      child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [result]),
                    ),
                  ],
                );
              }
              return ListView(
                  padding: const EdgeInsets.all(16),
                  controller: scrollCtrl,
                  children: [...controls, result]);
            },
          ),
        ),
      ),
    );
  }
}

const anomalyTypeLabels = {
  'sin_anomalia': 'Sin anomalía',
  'missing': 'Faltante',
  'duplicate': 'Duplicado',
  'unit': 'Unidad mezclada',
  'outlier': 'Imposible físico',
  'leak': 'Fuga de futuro',
};

const cleaningActionLabels = {
  'revisar': 'Revisar',
  'imputar': 'Imputar media',
  'convertir': 'Convertir a °C',
  'eliminar': 'Eliminar fila',
};

