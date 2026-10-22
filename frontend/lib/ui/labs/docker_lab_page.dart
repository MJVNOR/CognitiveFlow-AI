import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/labs/view_models/lab_session_viewmodel.dart';
import '../../ui/core/widgets/chrome.dart';
import '../../ui/core/widgets/strings.dart';
import '../../ui/labs/widgets/lab_chrome.dart';
import '../../ui/labs/widgets/posttest.dart';
import '../../ui/labs/widgets/reflection.dart';
import '../../ui/labs/widgets/result_panel.dart';
import '../../ui/tutor/tutor_surface.dart';
import '../../ui/labs/widgets/concept_primer.dart';
import '../../ui/labs/docker/docker_units.dart';

// M08: Docker Academy — 4 unidades con widgets GenUI + transferencia al postest.
// La actividad usa el mismo TutorSurface que las intervenciones: el widget emite
// eventos al backend y la justificación viaja en el intento (extra.unit).
class DockerLabPage extends ConsumerStatefulWidget {
  final String labId;
  final String title;
  const DockerLabPage({super.key, required this.labId, required this.title});
  @override
  ConsumerState<DockerLabPage> createState() => _DockerState();
}

const _dockerUnits = [
  'M08-D01-containers',
  'M08-D02-lifecycle',
  'M08-D04-dockerfile',
  'M08-D07-persistence',
];

const _unitPrompts = {
  'M08-D01-containers': 'Tres escenarios: ¿contenedor o VM? Justifica cada uno.',
  'M08-D02-lifecycle': 'Ordena el ciclo y predice qué sobrevive a cada paso.',
  'M08-D04-dockerfile':
      'Ordena las instrucciones y predice qué invalida la caché.',
  'M08-D07-persistence': 'Predice qué archivos sobreviven con cada montaje.',
};

class _DockerState extends ConsumerState<DockerLabPage> {
  final statusKey = GlobalKey();
  String unit = 'M08-D01-containers';
  String? posttestUnit;
  final justification = TextEditingController();
  final Map<String, Object?> _evidence = {};

  LabSessionViewModel get _vm =>
      ref.read(labSessionProvider(widget.labId).notifier);
  LabSession get lab => ref.watch(labSessionProvider(widget.labId));

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;
  String get _activeUnit =>
      lab.posttestMode ? (posttestUnit ?? unit) : unit;

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
    // Sprint 5: lección por unidad (no bloquea si falla).
    await _vm.loadObjectives(widget.labId);
    final u = await _vm.loadDraft(widget.labId, 'unit');
    final pu = await _vm.loadDraft(widget.labId, 'posttest_unit');
    final j = await _vm.loadDraft(widget.labId, 'justification');
    if (!mounted) return;
    setState(() {
      if (u != null && _dockerUnits.contains(u)) unit = u;
      if (pu != null && _dockerUnits.contains(pu)) posttestUnit = pu;
      if (j != null) justification.text = j;
    });
  }

  Map<String, dynamic>? _objectiveFor(String id) {
    for (final o in lab.objectives) {
      if (o['id'] == id) return o;
    }
    return null;
  }

  Map<String, Object?> _unitIntervention() {
    final u = dockerUnitWidget(_activeUnit);
    return {
      'widget_type': u.widget,
      'widget_parameters': {'title': u.title},
      'socratic_question':
          _unitPrompts[_activeUnit] ?? 'Experimenta y justifica.',
    };
  }

  Future<void> _onActivityEvent(
      String wt, String et, Map<String, Object?> p) async {
    final sid = ref.read(labSessionProvider(widget.labId)).sessionId;
    if (sid != null) {
      try {
        await _vm.emitEvent(wt, et, p);
      } catch (_) {}
    }
    // La evidencia del widget alimenta la evaluación del intento.
    if (!mounted || et != 'evidenceSelected') return;
    setState(() {
      if (p['order'] is List) {
        _evidence['order'] =
            (p['order'] as List).map((e) => '$e').toList();
      }
      for (final k in ['mount', 'predicted', 'observed']) {
        if (p.containsKey(k)) _evidence[k] = p[k];
      }
    });
  }

  Future<void> _send() async {
    final snap = ref.read(labSessionProvider(widget.labId));
    if (snap.sessionId == null || snap.evaluating) return;
    if (justification.text.trim().isEmpty) {
      _vm.setStatus(snap.posttestMode
          ? 'El diagnóstico es obligatorio'
          : 'La justificación es obligatoria');
      return;
    }
    _vm.setEvaluating(true);
    _vm.setStatus('');
    try {
      await _vm.send({
        'seed': seed,
        'extra': {'unit': _activeUnit, ..._evidence},
        'answer_text': justification.text,
      }, posttest: snap.posttestMode);
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
    justification.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sent = lab.posttestSent;
    final locked = sent || lab.posttestMode;
    final cs = Theme.of(context).colorScheme;
    final obj = _objectiveFor(_activeUnit);
    final parts = _activeUnit.split('-');
    final controls = [
      LabHeader(
        crumb: parts.length >= 2 ? 'Módulo ${parts[0]} · Unidad ${parts[1]}' : null,
        meta: sessionMeta(lab),
        objective: lab.posttestMode
            ? 'Variante nueva. Sin pistas ni tutor hasta entregar.'
            : 'Experimenta con la unidad y justifica por qué',
        step: lab.step,
      ),
      const SizedBox(height: 12),
      if (obj != null && !lab.posttestMode) ConceptPrimer(objective: obj),
      if (obj != null && !lab.posttestMode) const SizedBox(height: 12),
      if (lab.posttestMode) const PosttestBanner(),
      if (lab.posttestMode) const SizedBox(height: 12),
      SectionCard(
        icon: Icons.science,
        title: '1 · Experimenta con Docker',
        accent: lab.posttestMode ? null : cs.secondary,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final u in _dockerUnits)
                ChoiceChip(
                  key: ValueKey('docker_unit_$u'),
                  label: Text(u.split('-')[1]),
                  selected: _activeUnit == u,
                  onSelected: locked
                      ? null
                      : (_) {
                          setState(() {
                            unit = u;
                            _evidence.clear();
                          });
                          _vm.saveDraft(widget.labId, 'unit', u);
                        },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TutorSurface(
            key: ValueKey('docker_activity_$_activeUnit'),
            intervention: _unitIntervention(),
            onEvent: _onActivityEvent,
          ),
        ],
      ),
      const SizedBox(height: 12),
      SectionCard(
        icon: Icons.edit_note,
        title: '2 · Justifica tu decisión',
        accent: lab.posttestMode ? null : cs.tertiary,
        children: [
          TextField(
            key: const ValueKey('docker_justification'),
            controller: justification,
            maxLines: 4,
            minLines: 3,
            enabled: !sent,
            decoration: const InputDecoration(
              labelText: 'Justificación (obligatoria)',
              helperText: 'Cita lo que observaste en el experimento.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!sent)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('docker_send'),
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
        if (!lab.posttestMode &&
            (lab.evalResult != null || lab.intervention != null))
          TextButton(
            key: const ValueKey('go_posttest'),
            onPressed: lab.sessionId == null
                ? null
                : () => confirmEnterPosttestVm(context, _vm, () async {},
                    () {
                      setState(() => posttestUnit = unit);
                      _vm.saveDraft(widget.labId, 'posttest_unit', unit);
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
                  _vm.clearDrafts(widget.labId,
                      const ['unit', 'posttest_unit', 'justification']);
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
