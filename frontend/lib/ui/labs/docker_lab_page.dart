import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/core/motion.dart';
import '../../ui/labs/docker/docker_units.dart';
import '../../ui/labs/view_models/lab_session_viewmodel.dart';
import '../../ui/labs/widgets/concept_primer.dart';
import '../../ui/labs/widgets/lab_chrome.dart' show sessionMeta;
import '../../ui/labs/widgets/posttest.dart';
import '../../ui/labs/workspace/contextual_tutor_panel.dart';
import '../../ui/labs/workspace/learning_feedback.dart';
import '../../ui/labs/workspace/learning_studio.dart';
import '../../ui/labs/workspace/mission_navigation.dart';
import '../../ui/labs/workspace/studio_stages.dart';
import '../../ui/tutor/tutor_surface.dart';

/// Docker Academy en el Learning Studio. Cada unidad del temario es su propia
/// secuencia (aprender → experimentar → justificar → reto → prueba); la unidad
/// llega por la ruta (`?unit=`) y queda fijada en cuanto la sesión tiene intento.
class DockerLabPage extends ConsumerStatefulWidget {
  final String labId;
  final String title;
  final String? unit;
  const DockerLabPage({super.key, required this.labId, required this.title, this.unit});
  @override
  ConsumerState<DockerLabPage> createState() => _DockerState();
}

class _DockerState extends ConsumerState<DockerLabPage> {
  late DockerUnit unit = dockerUnitById(widget.unit);
  final justification = TextEditingController();
  final hintsShown = <String, int>{};
  final titleFocus = FocusNode(debugLabel: 'mission-title');
  final scrollCtrl = ScrollController();

  /// Evidencia del widget de práctica (viaja en el intento → evaluación).
  final Map<String, Object?> _evidence = {};
  bool interacted = false;

  /// Escenario público de la unidad (del servidor; null = por defecto del widget).
  Map<String, dynamic>? activity;

  /// La sesión abierta ya trabaja otra unidad que la pedida por la ruta.
  String? otherUnitInProgress;

  bool ready = false;
  int mission = 0;
  int localMax = 0;

  LabSessionViewModel get _vm => ref.read(labSessionProvider(widget.labId).notifier);
  LabSession get lab => ref.watch(labSessionProvider(widget.labId));
  LabSession get _snap => ref.read(labSessionProvider(widget.labId));

  int get seed => _snap.posttestMode ? _snap.variantSeed(99) : 1;
  String _k(String field) => _snap.posttestMode ? 'post_$field' : field;

  static const _draftFields = [
    'unit', 'justification', 'mission_max', 'hints', 'interacted', 'post_justification',
  ];

  @override
  void initState() {
    super.initState();
    justification.addListener(() {
      _vm.saveDraft(widget.labId, _k('justification'), justification.text);
      setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    justification.dispose();
    titleFocus.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // P1.6: reanudar abierta antes de crear una nueva.
    if (!await _vm.resume(widget.labId)) {
      await _vm.init(widget.labId);
      if (!mounted) return;
      if (_snap.sessionId == null) {
        setState(() => ready = true);
        return;
      }
    }
    await _vm.loadObjectives(widget.labId);
    await _restoreDrafts();
    await _loadActivity();
    if (!mounted) return;
    setState(() {
      mission = studioDefaultMission(dockerMissions, _snap, localMax);
      ready = true;
    });
  }

  Future<void> _restoreDrafts() async {
    final u = await _vm.loadDraft(widget.labId, 'unit');
    final j = await _vm.loadDraft(widget.labId, _k('justification'));
    final mm = await _vm.loadDraft(widget.labId, 'mission_max');
    final hs = await _vm.loadDraft(widget.labId, 'hints');
    final it = await _vm.loadDraft(widget.labId, 'interacted');
    if (!mounted) return;
    // La unidad de una sesión ya empezada manda sobre la ruta: una sesión = una unidad.
    localMax = int.tryParse(mm ?? '') ?? 0;
    final lastUnit = (_snap.lastInput?['extra'] as Map?)?['unit'] as String?;
    final sessionUnit = lastUnit ?? (localMax > 0 || _snap.posttestMode ? u : null);
    if (sessionUnit != null) {
      if (widget.unit != null && widget.unit != sessionUnit) {
        otherUnitInProgress = dockerUnitById(sessionUnit).code;
      }
      unit = dockerUnitById(sessionUnit);
    }
    _vm.saveDraft(widget.labId, 'unit', unit.id);
    if (j != null) justification.text = j;
    interacted = it == '1';
    if (hs != null && hs.isNotEmpty) {
      try {
        hintsShown.addAll(Map<String, int>.from(jsonDecode(hs) as Map));
      } catch (_) {}
    }
    final last = _snap.lastInput;
    if (!_snap.posttestMode && last != null && justification.text.isEmpty) {
      justification.text = '${last['answer_text'] ?? ''}';
      interacted = true;
    }
  }

  Map<String, dynamic>? get _objective {
    for (final o in lab.objectives) {
      if (o['id'] == unit.id) return o;
    }
    return null;
  }

  /// Escenario de la unidad desde el servidor (práctica: semilla 1; prueba:
  /// variante nueva). Sin red, el widget usa su escenario por defecto.
  Future<void> _loadActivity() async {
    try {
      final a = await _vm.fetchDockerActivity(widget.labId, unit.id, seed);
      if (mounted) setState(() => activity = a);
    } catch (_) {
      if (mounted) setState(() => activity = null);
    }
  }

  Map<String, Object?> _unitActivity() {
    final w = dockerUnitWidget(unit.id);
    return {
      'widget_type': w.widget,
      'widget_parameters': {'title': w.title, 'parameters': activity ?? const {}},
      'socratic_question': unit.prompt,
    };
  }

  // ── Navegación ───────────────────────────────────────────────────────────
  void _goto(int i) {
    setState(() {
      mission = i;
      if (_snap.attemptId == null && i <= dkJustify && i > localMax) localMax = i;
    });
    _vm.saveDraft(widget.labId, 'mission_max', '$localMax');
    _vm.setStatus('');
    // Foco al título de la nueva misión (lector de pantalla y teclado).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) titleFocus.requestFocus();
    });
  }

  Future<void> _onActivityEvent(String wt, String et, Map<String, Object?> p) async {
    try {
      await _vm.emitEvent(wt, et, p);
    } catch (_) {}
    if (!mounted || et == 'hintRequested') return;
    setState(() {
      interacted = true;
      if (p['order'] is List) _evidence['order'] = (p['order'] as List).map((e) => '$e').toList();
      for (final k in ['mount', 'predicted', 'observed', 'choices', 'prediction', 'ask_stage']) {
        if (p.containsKey(k)) _evidence[k] = p[k];
      }
    });
    _vm.saveDraft(widget.labId, 'interacted', '1');
  }

  void _hint() {
    final id = dockerMissions[mission].id;
    final n = (hintsShown[id] ?? 0) + 1;
    setState(() => hintsShown[id] = n);
    _vm.saveDraft(widget.labId, 'hints', jsonEncode(hintsShown));
    _onActivityEvent(dockerUnitWidget(unit.id).widget, 'hintRequested', {'mission': id, 'level': n});
  }

  // ── Envío, evaluación e intervención ─────────────────────────────────────
  Map<String, dynamic> _attempt() => {
        'seed': seed,
        'extra': {'unit': unit.id, ..._evidence},
        'answer_text': justification.text,
      };

  Future<void> _submitPractice() async {
    final s = _snap;
    if (s.sessionId == null || s.evaluating) return;
    _vm.setEvaluating(true);
    _vm.setStatus('');
    try {
      await _vm.send(_attempt(), posttest: false);
    } catch (e) {
      _vm.setEvaluating(false);
      _vm.setStatus('No se pudo enviar: $e. Tu respuesta sigue aquí; vuelve a intentarlo.');
      return;
    }
    await _vm.evaluate();
    _vm.setEvaluating(false);
  }

  Future<void> _retryEval() async {
    _vm.setEvaluating(true);
    await _vm.evaluate();
    _vm.setEvaluating(false);
  }

  Future<void> _next() async {
    _vm.setNextBusy(true);
    await _vm.next();
    _vm.setNextBusy(false);
    if (mounted && _snap.intervention != null) _goto(dkScenario);
  }

  bool get scenarioDone => lab.canEnterPosttest;

  Future<void> _onScenarioEvent(String wt, String et, Map<String, Object?> payload) async {
    final before = _snap.canEnterPosttest;
    try {
      await _vm.emitEvent(wt, et, payload); // refresca el permiso del postest
    } catch (e) {
      _vm.setStatus('No se guardó tu respuesta: $e. Vuelve a enviarla.');
      return;
    }
    if (!before && _snap.canEnterPosttest) _vm.setStatus('Respuesta guardada ✓');
  }

  Future<void> _beginPosttest() => confirmEnterPosttestVm(context, _vm, () async {
        setState(() {
          justification.text = '';
          _evidence.clear();
        });
        await _loadActivity(); // variante de la prueba: escenario nuevo
        if (mounted) _goto(dkMastery);
      });

  Future<void> _sendPosttest() async {
    final s = _snap;
    if (s.sessionId == null || s.evaluating) return;
    _vm.setEvaluating(true);
    try {
      await _vm.send(_attempt(), posttest: true);
      _vm.markDelivered(posttest: true, posttestMessage: 'Prueba entregada (sin ayuda de IA)');
    } catch (e) {
      _vm.setEvaluating(false);
      _vm.setStatus('No se pudo entregar: $e. Tu respuesta sigue aquí.');
    }
  }

  // ── Vistas ───────────────────────────────────────────────────────────────
  bool get _postPhase => inPosttestPhase(lab);
  bool get _submitted => lab.attemptId != null;
  bool get _editable => !_submitted && !_postPhase;

  @override
  Widget build(BuildContext context) {
    final l = lab;
    if (!ready) return const Center(child: CircularProgressIndicator());
    if (l.sessionId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.status.isEmpty ? 'No se pudo abrir el laboratorio.' : l.status),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() => ready = false);
                _init();
              },
              child: const Text('Reintentar'),
            ),
          ]),
        ),
      );
    }
    final views = studioMissionViews(dockerMissions, l,
        localMax: localMax, scenarioDone: scenarioDone, selected: mission);
    final m = dockerMissions[mission];
    return LearningStudioScaffold(
      stageScroll: scrollCtrl,
      stageKey: ValueKey('scroll-$mission-${l.posttestMode}'),
      header: StudioHeader(
        backRoute: '/academy',
        crumbs: [('Academia', '/academy'), ('Docker Academy', null), ('Unidad ${unit.code}', null)],
        title: unit.title,
        missionLabel: 'Misión ${mission + 1} de ${dockerMissions.length} · ${m.title}',
        meta: _postPhase ? null : sessionMeta(l),
        done: views.where((v) => v.status == MissionStatus.done).length,
        total: dockerMissions.length,
        trailing: l.posttestMode
            ? const Chip(
                avatar: Icon(Icons.lock_outline, size: 14),
                label: Text('Prueba sin ayuda', style: TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
      stage: KeyedSubtree(
        key: ValueKey('stage-$mission-${l.posttestMode}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (otherUnitInProgress != null) _otherUnitNotice(),
          MissionIntro(mission: m, focusNode: titleFocus),
          _stage(l),
        ]),
      ).enterMission(context, ValueKey('enter-$mission-${l.posttestMode}')),
      tutor: _tutor(l, m),
      tutorSummary: l.socraticQ.isNotEmpty
          ? l.socraticQ
          : dockerCoach(m.id, interacted: interacted, submitted: _submitted),
      actionBar: _actionBar(l) ?? const SizedBox.shrink(),
      missions: MissionNavigation(missions: views, selected: mission, onSelect: _goto),
    );
  }

  Widget _otherUnitNotice() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('docker_unit_in_progress'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Tienes la unidad $otherUnitInProgress en curso. '
              'Termínala (hasta la prueba y la reflexión) para empezar otra unidad.'),
        ),
      ]),
    );
  }

  Widget _tutor(LabSession l, Mission m) {
    final locked = l.posttestMode || (mission == dkMastery && !l.done);
    final hints = (_editable || mission == dkScenario) && !locked
        ? (dockerHints[m.id] ?? const <String>[])
        : const <String>[];
    return ContextualTutorPanel(
      locked: locked,
      guidance: dockerCoach(m.id, interacted: interacted, submitted: _submitted),
      hints: hints,
      hintsShown: hintsShown[m.id] ?? 0,
      onHint: _hint,
      evidence: [
        if (_evidence['order'] is List)
          TutorEvidence('Orden propuesto', '${(_evidence['order'] as List).length} instrucciones'),
        if (_evidence.containsKey('mount')) TutorEvidence('Montaje', '${_evidence['mount']}'),
        if (_evidence.containsKey('choices')) const TutorEvidence('Clasificación', 'registrada'),
      ],
      question: mission == dkScenario
          ? '${l.intervention?['socratic_question'] ?? ''}'
          : (_submitted ? l.socraticQ : null),
      questionWhy: mission == dkScenario ? '${l.intervention?['reason'] ?? ''}' : null,
      history: l.tutorHistory,
    );
  }

  Widget? _actionBar(LabSession l) {
    final status = l.status.isEmpty ? null : l.status;
    ActivityActionBar bar(String label, IconData icon, VoidCallback? onPressed,
            {String? helper, bool busy = false, required String key}) =>
        ActivityActionBar(
          buttonKey: ValueKey(key),
          label: label,
          icon: icon,
          onPressed: onPressed,
          helper: status ?? helper,
          busy: busy,
        );
    final frontier = studioDefaultMission(dockerMissions, l, localMax);
    final backToCurrent = bar('Volver a la misión actual', Icons.arrow_forward,
        () => _goto(frontier),
        key: 'docker_back_current',
        helper: 'Esta misión ya está entregada: puedes revisarla sin cambiarla.');
    switch (mission) {
      case dkLearn:
        if (!_editable) return backToCurrent;
        return bar('Probar con escenarios', Icons.science_outlined, () => _goto(dkExperiment),
            key: 'docker_cta_learn', helper: 'Pasarás a experimentar con la unidad ${unit.code}.');
      case dkExperiment:
        if (!_editable) return backToCurrent;
        return bar('Continuar a justificar', Icons.edit_note,
            interacted ? () => _goto(dkJustify) : null,
            key: 'docker_cta_experiment',
            helper: interacted
                ? 'Tu evidencia quedó registrada.'
                : 'Usa el experimento: tus decisiones son la evidencia.');
      case dkJustify:
        if (_postPhase) return backToCurrent;
        if (!_submitted) {
          final ok = justification.text.trim().isNotEmpty;
          return bar('Evaluar mi razonamiento', Icons.fact_check_outlined,
              ok ? _submitPractice : null,
              key: 'docker_send',
              busy: l.evaluating,
              helper: l.evaluating
                  ? 'Evaluando tu razonamiento…'
                  : ok
                      ? 'Se envían tu evidencia del experimento y tu justificación.'
                      : 'Explica lo que observaste y por qué.');
        }
        final r = l.evalResult;
        if (l.evaluating) {
          return bar('Evaluando…', Icons.fact_check_outlined, null,
              key: 'docker_send', busy: true, helper: 'Evaluando tu razonamiento…');
        }
        if (r == null || r['status'] == 'pending' || l.evalError != null) {
          return bar('Reintentar evaluación', Icons.refresh, _retryEval,
              key: 'docker_retry_eval',
              helper: l.evalError ?? 'Tu intento está guardado; falta la evaluación.');
        }
        if (l.intervention != null) {
          return bar('Ir al nuevo escenario', Icons.auto_awesome, () => _goto(dkScenario),
              key: 'docker_goto_scenario');
        }
        return bar('Explorar nuevo desafío', Icons.auto_awesome, _next,
            key: 'next_activity',
            busy: l.nextBusy,
            helper: l.nextError ?? 'El tutor elegirá el reto según esta evaluación.');
      case dkScenario:
        if (_postPhase) return backToCurrent;
        if (!scenarioDone) return null; // la CTA es la del propio widget GenUI
        return bar('Demostrar dominio', Icons.verified_outlined, () => _goto(dkMastery),
            key: 'docker_goto_mastery', helper: 'Ya puedes hacer la prueba sin ayuda.');
      default:
        if (!l.posttestMode) {
          return bar('Comenzar prueba sin ayuda', Icons.lock_outline,
              l.canEnterPosttest ? _beginPosttest : null,
              key: 'docker_begin_posttest',
              helper: 'Sin tutor. No podrás volver a la práctica de esta unidad.');
        }
        if (!l.posttestSent) {
          final ok = justification.text.trim().isNotEmpty;
          return bar('Entregar prueba', Icons.send, ok ? _sendPosttest : null,
              key: 'docker_send',
              busy: l.evaluating,
              helper: ok ? null : 'Resuelve y justifica antes de entregar.');
        }
        if (!l.done) return null; // la reflexión lleva su propio botón
        return bar('Volver a la academia', Icons.school_outlined,
            () => context.go('/academy'),
            key: 'docker_to_academy');
    }
  }

  Widget _stage(LabSession l) => switch (mission) {
        dkLearn => _learnStage(l),
        dkExperiment => _activity(editable: _editable),
        dkJustify => _justifyStage(l),
        dkScenario =>
          ScenarioStage(lab: l, scenarioDone: scenarioDone, onEvent: _onScenarioEvent),
        _ => _masteryStage(l),
      };

  Widget _learnStage(LabSession l) {
    final obj = _objective;
    if (obj == null) {
      return StudioCard(
        title: unit.title,
        icon: Icons.menu_book_outlined,
        child: Text(unit.prompt),
      );
    }
    return StudioCard(
      title: '${obj['title'] ?? unit.title}',
      icon: Icons.menu_book_outlined,
      child: ConceptPrimer(objective: obj),
    );
  }

  Widget _activity({required bool editable}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.secondary, width: 1.5),
      ),
      child: AbsorbPointer(
        absorbing: !editable,
        child: TutorSurface(
          key: ValueKey('docker_activity_${unit.id}_${activity?['seed']}'),
          intervention: _unitActivity(),
          onEvent: _onActivityEvent,
        ),
      ),
    );
  }

  Widget _justifyStage(LabSession l) {
    final cs = Theme.of(context).colorScheme;
    final r = l.evalResult;
    final interventionTitle = '${(l.intervention?['widget_parameters'] as Map?)?['title'] ?? ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (l.evaluating && r == null)
        const EvaluatingCard(detail: 'El evaluador está revisando tu evidencia y tu justificación.'),
      if (r != null && _submitted)
        StudioCard(
          title: 'Resultado de tu intento',
          icon: Icons.fact_check_outlined,
          child: LearningFeedbackView(
            evalResult: r,
            feedback: l.feedback,
            revisit: l.socraticQ,
            nextExperiment: interventionTitle.isNotEmpty
                ? 'Reto elegido: $interventionTitle'
                : 'Al continuar, el tutor elegirá un escenario nuevo según estas brechas.',
            onRetry: _retryEval,
          ),
        ).enterNote(context, const ValueKey('docker-feedback')),
      StudioCard(
        title: 'Justifica con lo que observaste',
        icon: Icons.edit_note,
        accent: cs.tertiary,
        child: TextField(
          key: const ValueKey('docker_justification'),
          controller: justification,
          enabled: _editable,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
            // Ya enviada: sin pista visible, la etiqueta da nombre al lector de pantalla.
            labelText: _editable ? null : 'Tu respuesta (enviada)',
            hintText: 'Hice… / Observé… / Porque (${_mechanism()})… / En otro caso haría…',
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    ]);
  }

  String _mechanism() => switch (unit.code) {
        'D01' => 'kernel, aislamiento',
        'D02' => 'imagen, contenedor, estado',
        'D04' => 'capas, caché',
        _ => 'volumen, filesystem',
      };

  Widget _masteryStage(LabSession l) {
    if (!l.posttestMode) {
      return PosttestRulesCard(novelty: 'Un caso nuevo de la unidad ${unit.code}.');
    }
    if (l.posttestSent) {
      return PosttestClosing(
        lab: l,
        labId: widget.labId,
        onUpdate: () {
          if (_snap.done) _vm.clearDrafts(widget.labId, _draftFields);
          _vm.touch();
        },
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PosttestBanner(),
      const SizedBox(height: 16),
      _activity(editable: true),
      const SizedBox(height: 16),
      StudioCard(
        title: 'Tu justificación',
        icon: Icons.edit_note,
        child: TextField(
          key: const ValueKey('docker_justification'),
          controller: justification,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Qué decidiste y por qué, citando el mecanismo.',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ]);
  }
}
