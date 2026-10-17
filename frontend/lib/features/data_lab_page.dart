import 'package:flutter/material.dart';

import '../session/lab_session.dart';
import '../state/app_state.dart';
import '../widgets/cards.dart';

// G1: tabla sintética, marcar anomalías, justificar, postest con tabla nueva.
class DataLabPage extends StatefulWidget {
  final String labId;
  final String title;
  const DataLabPage({super.key, required this.labId, required this.title});
  @override
  State<DataLabPage> createState() => _DataLabState();
}

class _DataLabState extends State<DataLabPage> {
  final lab = LabSession();
  final statusKey = GlobalKey();
  List columns = [];
  List rows = [];
  final flagged = <int>{};
  final justification = TextEditingController();

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;

  @override
  void initState() {
    super.initState();
    justification.addListener(
        () => saveDraft(widget.labId, 'justification', justification.text));
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
    await _loadTable();
    // Borrador previo (si salió del lab sin entregar).
    final f = await loadDraft(widget.labId, 'flagged');
    final j = await loadDraft(widget.labId, 'justification');
    if (!mounted) return;
    setState(() {
      if (f != null && f.isNotEmpty) {
        flagged.addAll(
            [for (final p in f.split(',')) int.tryParse(p)].whereType<int>());
      }
      if (j != null) justification.text = j;
    });
  }

  Future<void> _loadTable() async {
    try {
      final ds = await fetchMap('/labs/${widget.labId}/dataset?seed=$seed');
      setState(() {
        columns = ds['columns'] as List;
        rows = ds['rows'] as List;
        flagged.clear();
      });
    } catch (e) {
      setState(() => lab.status = 'Error tabla: $e');
    }
  }

  Future<void> _send() async {
    if (lab.sessionId == null || lab.evaluating) return;
    if (justification.text.trim().isEmpty) {
      setState(() => lab.status = 'La justificación es obligatoria');
      return;
    }
    setState(() {
      lab.evaluating = true;
      lab.status = '';
    });
    try {
      await lab.send({
        'seed': seed,
        'flags': flagged.toList(),
        'answer_text': justification.text,
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

  final scrollCtrl = ScrollController();
  final hCtrl = ScrollController();

  @override
  void dispose() {
    justification.dispose();
    scrollCtrl.dispose();
    hCtrl.dispose();
    super.dispose();
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
                objective: lab.posttestMode
                    ? 'Tabla nueva, sin ayuda. Marca anomalías y justifica.'
                    : 'Marca las filas con anomalías y justifica tu plan de limpieza.',
                step: lab.step,
              ),
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
                    showCheckboxColumn: true,
                    // ponytail: filas ≥44px (WCAG 2.5.8).
                    dataRowMinHeight: 44,
                    columns: [for (final c in columns) DataColumn(label: Text('$c'))],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          key: ValueKey('datarow_${r['id']}'),
                          selected: flagged.contains(r['id']),
                          onSelectChanged: (_) {
                            setState(() {
                              flagged.contains(r['id'])
                                  ? flagged.remove(r['id'])
                                  : flagged.add(r['id'] as int);
                            });
                            saveDraft(widget.labId, 'flagged',
                                flagged.map((e) => '$e').join(','));
                          },
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
                  : () => confirmEnterPosttest(context, lab, setState, _loadTable),
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
                    clearDrafts(widget.labId, const ['flagged', 'justification']);
                  }
                  setState(() {});
                }),
          StatusText(lab.status, key: statusKey),
            ],
          );
              if (constraints.maxWidth >= 1024) {
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

