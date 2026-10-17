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

/// View del lab ML (MVVM): estado efímero local (sliders, controllers,
/// curva) en el State; ciclo de sesión en [LabSessionViewModel].
class LabDetailPage extends ConsumerStatefulWidget {
  final String labId;
  final String title;
  const LabDetailPage({super.key, required this.labId, required this.title});
  @override
  ConsumerState<LabDetailPage> createState() => _LabDetailState();
}

class _LabDetailState extends ConsumerState<LabDetailPage> {
  final statusKey = GlobalKey();
  double complexity = 5;
  double noise = 20;
  final hypo = TextEditingController();
  Map<String, dynamic>? curve;
  List<num>? savedVal;
  String? savedLabel;
  double epochSel = 0;

  LabSessionViewModel get _vm =>
      ref.read(labSessionProvider(widget.labId).notifier);
  LabSession get _lab => ref.watch(labSessionProvider(widget.labId));

  int get seed => _lab.posttestMode ? _lab.variantSeed(99) : 1;

  @override
  void initState() {
    super.initState();
    hypo.addListener(() => _vm.saveDraft(widget.labId, 'hypo', hypo.text));
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
    // Sprint 1: lección del objetivo (no bloquea el experimento si falla).
    await _vm.loadObjectives(widget.labId);
    await _loadCurve();
    final cx = await _vm.loadDraft(widget.labId, 'complexity');
    final nz = await _vm.loadDraft(widget.labId, 'noise');
    final h = await _vm.loadDraft(widget.labId, 'hypo');
    if (!mounted) return;
    setState(() {
      if (cx != null) complexity = double.tryParse(cx) ?? complexity;
      if (nz != null) noise = double.tryParse(nz) ?? noise;
      if (h != null) hypo.text = h;
    });
    if (cx != null || nz != null) await _loadCurve();
    // En postest manda la variante del servidor, no el borrador.
    final v = ref.read(labSessionProvider(widget.labId)).posttestVariant;
    final posttestMode =
        ref.read(labSessionProvider(widget.labId)).posttestMode;
    if (posttestMode && v != null) {
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
      final c = await _vm.fetchCurve(
        widget.labId,
        complexity.round(),
        noise.round(),
        seed,
      );
      if (!mounted) return;
      setState(() => curve = c);
    } catch (e) {
      _vm.setStatus('Error curva: $e');
    }
  }

  Future<void> _send() async {
    final lab = ref.read(labSessionProvider(widget.labId));
    if (lab.sessionId == null || lab.evaluating) return;
    if (hypo.text.trim().isEmpty) {
      _vm.setStatus(lab.posttestMode
          ? 'El diagnóstico es obligatorio'
          : 'La hipótesis es obligatoria');
      return;
    }
    _vm.setEvaluating(true);
    _vm.setStatus('');
    try {
      await _vm.send({
        'complexity': complexity.round(),
        'noise_pct': noise.round(),
        'seed': seed,
        'answer_text': hypo.text,
      }, posttest: lab.posttestMode);
      _vm.markDelivered(
          posttest:
              ref.read(labSessionProvider(widget.labId)).posttestMode,
          savedMessage: 'Guardado ✓ (simulación, sin IA)',
          posttestMessage: 'Postest entregado (sin ayuda de IA)');
      if (!ref.read(labSessionProvider(widget.labId)).posttestMode) {
        await _vm.evaluate();
      }
    } catch (e) {
      _vm.setEvaluating(false);
      _vm.setStatus('Error envío: $e');
    }
  }

  /// Sprint 3: la época marcada queda en ui_events como evidencia seleccionada.
  Future<void> _markEvidence() async {
    final lab = ref.read(labSessionProvider(widget.labId));
    if (lab.sessionId == null) return;
    try {
      await _vm.emitEvent('LearningCurveSimulator', 'evidenceSelected', {
        'epoch': epochSel.round(),
        'complexity': complexity.round(),
        'noise_pct': noise.round(),
        'mode': lab.posttestMode ? 'posttest' : 'practice',
      });
      _vm.setStatus('Evidencia guardada: época ${epochSel.round()}');
    } catch (e) {
      _vm.setStatus('No se guardó la evidencia: $e');
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
    hypo.dispose();
    super.dispose();
  }

  /// Miga Ruta > Módulo > Unidad derivada del objetivo (sin hardcodear textos).
  String? _crumb() => labCrumb(_lab.objectives);

  @override
  Widget build(BuildContext context) {
    final lab = _lab;
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
      if (lab.objectives.isNotEmpty)
        ConceptPrimer(objective: lab.objectives.first),
      if (lab.objectives.isNotEmpty)
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
                    _vm.saveDraft(widget.labId, 'complexity', '$complexity');
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
                    _vm.saveDraft(widget.labId, 'noise', '$noise');
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
                : () => confirmEnterPosttestVm(context, _vm, _loadCurve, () {
                      final v = ref
                          .read(labSessionProvider(widget.labId))
                          .posttestVariant;
                      if (v != null) {
                        setState(() {
                          complexity = (v['complexity'] as num).toDouble();
                          noise = (v['noise_pct'] as num).toDouble();
                        });
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
              ResultPanel(lab: lab, onNext: _next, onRetry: _retry, onEvent: _vm.emitEvent),
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
                if (ref.read(labSessionProvider(widget.labId)).done) {
                  _vm.clearDrafts(widget.labId, const ['complexity', 'noise', 'hypo']);
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
