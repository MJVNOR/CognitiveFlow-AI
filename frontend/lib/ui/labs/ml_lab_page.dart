import 'package:flutter/material.dart';

import '../../data/repositories/lab_repository.dart' as lab_repo;
import '../../ui/labs/view_models/lab_session.dart';
import '../../utils/storage/drafts.dart';
import '../../ui/core/widgets/chrome.dart';
import '../../ui/core/widgets/strings.dart';
import '../../ui/labs/widgets/lab_chrome.dart';
import '../../ui/labs/widgets/posttest.dart';
import '../../ui/labs/widgets/reflection.dart';
import '../../ui/labs/widgets/result_panel.dart';
import '../../ui/labs/widgets/concept_primer.dart';
import '../../ui/labs/widgets/curve_chart.dart';

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
      final objs = await lab_repo.fetchObjectives(widget.labId);
      if (!mounted) return;
      setState(() => objectives = objs);
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
      final c = await lab_repo.fetchCurve(
        widget.labId,
        complexity.round(),
        noise.round(),
        seed,
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
      await lab.emitEvent('LearningCurveSimulator', 'evidenceSelected', {
        'epoch': epochSel.round(),
        'complexity': complexity.round(),
        'noise_pct': noise.round(),
        'mode': lab.posttestMode ? 'posttest' : 'practice',
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

