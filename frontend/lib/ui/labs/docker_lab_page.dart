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

  /// Justificación del reto: su propio ciclo (decidir → explicar → feedback).
  final challengeJustification = TextEditingController();
  bool challengeArgumentSent = false;
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

  /// Prerrequisito sin completar de la unidad pedida (null = disponible).
  String? lockedBy;

  bool ready = false;
  int mission = 0;
  int localMax = 0;

  LabSessionViewModel get _vm => ref.read(labSessionProvider(widget.labId).notifier);
  LabSession get lab => ref.watch(labSessionProvider(widget.labId));
  LabSession get _snap => ref.read(labSessionProvider(widget.labId));

  int get seed => _snap.posttestMode ? _snap.variantSeed(99) : 1;
  String _k(String field) => _snap.posttestMode ? 'post_$field' : field;
  String get _draftScope => '${widget.labId}:${unit.id}';

  static const _draftFields = [
    'unit', 'justification', 'mission_max', 'hints', 'interacted', 'post_justification',
    'evidence', 'post_evidence', 'post_interacted',
    'challenge_justification', 'challenge_sent',
  ];

  @override
  void initState() {
    super.initState();
    justification.addListener(() {
      _vm.saveDraft(_draftScope, _k('justification'), justification.text);
      setState(() {});
    });
    challengeJustification.addListener(() {
      _vm.saveDraft(_draftScope, 'challenge_justification', challengeJustification.text);
      setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    justification.dispose();
    challengeJustification.dispose();
    titleFocus.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final previousUnit = await _vm.loadDraft(widget.labId, 'unit');
    if (!mounted) return;
    unit = dockerUnitById(widget.unit ?? previousUnit);
    // Migrar el borrador anterior sin mezclar respuestas entre unidades.
    if (previousUnit == unit.id) {
      for (final field in _draftFields.where((f) => f != 'unit')) {
        if (await _vm.loadDraft(_draftScope, field) != null) continue;
        final value = await _vm.loadDraft(widget.labId, field);
        if (value != null) await _vm.saveDraft(_draftScope, field, value);
      }
    }
    // P1.6: reanudar abierta antes de crear una nueva.
    if (!await _vm.resume(widget.labId, unitId: unit.id)) {
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
    final j = await _vm.loadDraft(_draftScope, _k('justification'));
    final mm = await _vm.loadDraft(_draftScope, 'mission_max');
    final hs = await _vm.loadDraft(_draftScope, 'hints');
    final it = await _vm.loadDraft(_draftScope, _k('interacted'));
    final evidence = await _vm.loadDraft(_draftScope, _k('evidence'));
    final cj = await _vm.loadDraft(_draftScope, 'challenge_justification');
    final cs = await _vm.loadDraft(_draftScope, 'challenge_sent');
    if (!mounted) return;
    if (cj != null) challengeJustification.text = cj;
    challengeArgumentSent = cs == '1';
    // La justificación vive en el experimento: sin envío, la frontera es experimentar.
    localMax = (int.tryParse(mm ?? '') ?? 0).clamp(0, dkExperiment);
    if (_snap.lastInput == null && !inPosttestPhase(_snap)) {
      // Unidad nueva: se abre solo con su prerrequisito completado (el servidor
      // también rechaza el intento). Sin red, no se bloquea en el cliente.
      try {
        lockedBy = dockerLockedBy(unit, await _vm.fetchDockerUnits());
      } catch (_) {}
      if (!mounted) return;
    }
    _vm.saveDraft(widget.labId, 'unit', unit.id);
    if (j != null) justification.text = j;
    interacted = it == '1';
    if (evidence != null) {
      try { _evidence.addAll(Map<String, Object?>.from(jsonDecode(evidence) as Map)); } catch (_) {}
    }
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
  /// variante nueva). Si falla, se conserva el borrador y se ofrece reintentar.
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
      'widget_parameters': {'title': w.title, 'parameters': {
        ...?activity, 'feedback_enabled': !_snap.posttestMode,
      }},
      'socratic_question': unit.prompt,
    };
  }

  // ── Navegación ───────────────────────────────────────────────────────────
  void _goto(int i) {
    setState(() {
      mission = i;
      if (_snap.attemptId == null && i <= dkExperiment && i > localMax) localMax = i;
    });
    _vm.saveDraft(_draftScope, 'mission_max', '$localMax');
    _vm.setStatus('');
    // Foco al título de la nueva misión (lector de pantalla y teclado).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) titleFocus.requestFocus();
    });
  }

  Future<void> _onActivityEvent(String wt, String et, Map<String, Object?> p) async {
    if (mounted && wt == 'ImageContainerLifecycle' && p['completed'] == false) {
      setState(() {
        interacted = false;
        if (p.containsKey('prediction')) _evidence['prediction'] = p['prediction'];
      });
      if (p['prediction'] == null) _vm.clearPracticeCheck();
    }
    try {
      // La unidad deja al servidor corregir la práctica al momento.
      await _vm.emitEvent(wt, et, {...p, 'unit': unit.id});
    } catch (_) {}
    if (!mounted || et == 'hintRequested') return;
    setState(() {
      // Una selección incompleta se corrige, pero aún no es evidencia completa.
      if (et == 'evidenceSelected' || et == 'argumentSubmitted') interacted = true;
      if (wt == 'ImageContainerLifecycle' && p['completed'] == false) interacted = false;
      if (p['order'] is List) _evidence['order'] = (p['order'] as List).map((e) => '$e').toList();
      for (final k in ['mount', 'predicted', 'observed', 'choices', 'prediction', 'ask_stage']) {
        if (p.containsKey(k)) _evidence[k] = p[k];
      }
    });
    _vm.saveDraft(_draftScope, _k('interacted'), interacted ? '1' : '0');
    _vm.saveDraft(_draftScope, _k('evidence'), jsonEncode(_evidence));
  }

  String? get _hintUnit => mission == dkScenario
      ? dockerInterventionUnit(_snap.intervention) : unit.id;

  String get _hintKey {
    final id = dockerMissions[mission].id;
    if (mission != dkScenario) return id;
    final iv = _snap.intervention;
    final params = (iv?['widget_parameters'] as Map?)?['parameters'] as Map?;
    return '$id:${_snap.attemptId}:${iv?['widget_type']}:$_hintUnit:${params?['seed']}';
  }

  Future<void> _hint() async {
    final s = _snap;
    final allowed = mission == dkScenario ? s.intervention != null
        : mission == dkExperiment && s.attemptId == null;
    if (inPosttestPhase(s) || !allowed) return;
    final id = dockerMissions[mission].id;
    final target = _hintUnit;
    final key = _hintKey;
    final hints = dockerHintsFor(target, id);
    final shown = hintsShown[key] ?? 0;
    if (target == null || shown >= hints.length) return;
    final n = shown + 1;
    setState(() => hintsShown[key] = n);
    _vm.saveDraft(_draftScope, 'hints', jsonEncode(hintsShown));
    try {
      await _vm.emitEvent(dockerUnitWidget(target).widget, 'hintRequested', {
        'unit': target, 'mission': id, 'level': n, 'hint_context': key,
      });
    } catch (_) {
      _vm.setStatus('La pista está visible; no se pudo registrar la ayuda usada.');
    }
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
    if (mounted) _goto(dkJustify); // el resultado se lee en su propia misión
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
          interacted = false;
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
    if (lockedBy != null) return _lockedView(lockedBy!);
    final views = studioMissionViews(dockerMissions, l,
        localMax: localMax, scenarioDone: scenarioDone, selected: mission);
    final m = dockerMissions[mission];
    return LearningStudioScaffold(
      stageScroll: scrollCtrl,
      stageKey: ValueKey('scroll-$mission-${l.posttestMode}'),
      header: StudioHeader(
        backRoute: '/academy',
        onReset: () => confirmResetLab(context, _vm),
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
          : dockerCoach(m.id, unitId: _hintUnit, interacted: interacted, submitted: _submitted),
      actionBar: _actionBar(l) ?? const SizedBox.shrink(),
      missions: MissionNavigation(missions: views, selected: mission, onSelect: _goto),
    );
  }

  /// Unidad con prerrequisito pendiente: explica el motivo y ofrece la previa.
  Widget _lockedView(String code) {
    final prev = dockerUnits.firstWhere((u) => u.code == code);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: StudioCard(
            key: const ValueKey('docker_unit_locked'),
            title: 'Unidad ${unit.code} bloqueada',
            icon: Icons.lock_outline,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('«${unit.title}» se apoya en ${prev.code}: «${prev.title}». '
                  'Complétala (hasta la prueba y la reflexión) para abrir esta unidad.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const ValueKey('docker_goto_prereq'),
                onPressed: () => context.go('/labs/${widget.labId}?unit=${prev.id}'),
                icon: const Icon(Icons.arrow_forward),
                label: Text('Ir a ${prev.code}'),
              ),
            ]),
          ),
        ),
      ),
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
        ? dockerHintsFor(_hintUnit, m.id)
        : const <String>[];
    return ContextualTutorPanel(
      locked: locked,
      guidance: dockerCoach(m.id, unitId: _hintUnit, interacted: interacted, submitted: _submitted),
      hints: hints,
      hintsShown: hintsShown[_hintKey] ?? 0,
      onHint: hints.isEmpty ? null : _hint,
      evidence: mission == dkLearn ? null : [
        if (_evidence['order'] is List)
          TutorEvidence('Orden propuesto', '${(_evidence['order'] as List).length} instrucciones'),
        if (_evidence.containsKey('mount')) TutorEvidence('Montaje', '${_evidence['mount']}'),
        if (_evidence.containsKey('choices')) const TutorEvidence('Clasificación', 'registrada'),
        // Una predicción ya es evidencia aunque falte terminar el experimento.
        if (_evidence['prediction'] != null)
          TutorEvidence('Predicción', '${_evidence['prediction']}'),
        if (_evidence['predicted'] != null)
          TutorEvidence('Predicción',
              _evidence['predicted'] == true ? 'el archivo sobrevive' : 'el archivo se pierde'),
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
        final ok = activity != null && interacted && justification.text.trim().isNotEmpty;
        return bar('Evaluar mi razonamiento', Icons.fact_check_outlined,
            ok ? _submitPractice : null,
            key: 'docker_send',
            busy: l.evaluating,
            helper: l.evaluating
                ? 'Evaluando tu razonamiento…'
                : activity == null
                    ? 'Reintenta la carga del escenario. Tu explicación sigue guardada.'
                : !interacted
                    ? _pendingExperimentText
                    : ok
                        ? 'Se envían tus decisiones y tu justificación.'
                        : 'Justifica tus decisiones debajo del experimento.');
      case dkJustify:
        if (_postPhase || !_submitted) return backToCurrent;
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
        if (!challengeArgumentSent) {
          // El reto cierra su ciclo: decidir, explicar y recibir feedback de eso.
          final ok = challengeJustification.text.trim().isNotEmpty;
          return bar('Evaluar mi explicación', Icons.fact_check_outlined,
              ok ? _sendChallengeArgument : null,
              key: 'docker_challenge_send',
              // Breve: al 200 % de texto en 390 px la barra no puede crecer más.
              helper: ok ? 'Se evalúa tu explicación.' : 'Explica el reto para cerrar.');
        }
        return bar('Demostrar dominio', Icons.verified_outlined, () => _goto(dkMastery),
            key: 'docker_goto_mastery', helper: 'Ya puedes hacer la prueba sin ayuda.');
      default:
        if (!inPosttestPhase(l)) {
          return bar('Comenzar prueba sin ayuda', Icons.lock_outline,
              l.canEnterPosttest ? _beginPosttest : null,
              key: 'docker_begin_posttest',
              helper: 'Sin tutor. No podrás volver a la práctica de esta unidad.');
        }
        if (!l.posttestSent && !l.done) {
          final ok = activity != null && interacted && justification.text.trim().isNotEmpty;
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
        dkExperiment => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _activity(editable: _editable),
            practiceCheck(l,
                unit.code == 'D02' && !interacted
                    ? 'Tu predicción está comprobada. Falta recorrer la simulación con «Ejecutar…» hasta «Secuencia completa»; tu explicación se conserva.'
                    : 'Ahora explica abajo por qué: eso es lo que se evalúa.',
                successTitle: unit.code == 'D02' ? 'Predicción comprobada' : null),
            const SizedBox(height: 16),
            _justificationCard(),
          ]),
        dkJustify => _justifyStage(l),
        dkScenario => ScenarioStage(
            lab: l,
            scenarioDone: scenarioDone,
            onEvent: _onScenarioEvent,
            justification: scenarioDone ? _challengeJustificationCard() : null,
          ),
        _ => _masteryStage(l),
      };

  String get _pendingExperimentText => switch (unit.code) {
    'D02' => _evidence['prediction'] == null
        ? 'Elige una predicción y recorre la simulación con «Ejecutar…». Después podrás evaluar tu explicación.'
        : 'Tu predicción está registrada. Falta pulsar «Ejecutar…» hasta «Secuencia completa» para habilitar la evaluación.',
    'D07' => 'Elige un montaje, predice, escribe el archivo y pulsa «Recrear» antes de evaluar tu explicación.',
    'D04' => 'Reordena los bloques del Dockerfile para registrar el orden que vas a justificar.',
    'D01' => 'Elige una opción en cada escenario antes de evaluar tu explicación.',
    _ => 'Selecciona una opción en todos los casos antes de evaluar tu explicación.',
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
    return ConceptPrimer(objective: obj); // la lámina ya lleva el objetivo como título
  }

  Widget _activity({required bool editable}) {
    if (activity == null) {
      return StudioCard(
        title: 'No se pudo cargar el escenario',
        icon: Icons.cloud_off_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tu respuesta sigue guardada. Reintenta para cargar el ejercicio de esta unidad.'),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('docker_activity_retry'),
            onPressed: _loadActivity,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar escenario'),
          ),
        ]),
      );
    }
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
      _justificationCard(),
    ]);
  }

  /// Justificación junto a las decisiones (misión 2); en el resultado, solo lectura.
  Widget _justificationCard() => StudioCard(
        title: 'Justifica tu decisión',
        icon: Icons.edit_note,
        accent: Theme.of(context).colorScheme.tertiary,
        child: TextField(
          key: const ValueKey('docker_justification'),
          controller: justification,
          enabled: _editable,
          minLines: 3,
          maxLines: 8,
          decoration: InputDecoration(
            // Ya enviada: sin pista visible, la etiqueta da nombre al lector de pantalla.
            labelText: _editable ? null : 'Tu respuesta (enviada)',
            hintText: 'Elegí… / Porque (${_mechanism()})… / En otro caso haría…',
            border: const OutlineInputBorder(),
          ),
        ),
      );

  /// Justificación del reto (no la de la práctica): se evalúa por separado.
  Widget _challengeJustificationCard() => StudioCard(
        title: 'Explica este reto',
        icon: Icons.edit_note,
        accent: Theme.of(context).colorScheme.tertiary,
        child: TextField(
          key: const ValueKey('docker_challenge_justification'),
          controller: challengeJustification,
          enabled: !challengeArgumentSent,
          minLines: 2,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: challengeArgumentSent ? 'Tu explicación (enviada)' : null,
            hintText: 'Qué decidiste aquí y por qué (${_mechanism()}).',
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Future<void> _sendChallengeArgument() async {
    final wt = '${lab.intervention?['widget_type'] ?? ''}';
    if (wt.isEmpty) return;
    try {
      await _vm.emitEvent(wt, 'argumentSubmitted',
          {'argument': challengeJustification.text.trim()});
    } catch (e) {
      _vm.setStatus('No se envió tu explicación: $e. Sigue aquí; vuelve a intentarlo.');
      return;
    }
    if (!mounted) return;
    setState(() => challengeArgumentSent = true);
    _vm.saveDraft(_draftScope, 'challenge_sent', '1');
  }

  String _mechanism() => switch (unit.code) {
        'D01' => 'kernel, aislamiento',
        'D02' => 'imagen, contenedor, estado',
        'D03' => 'qué hace cada comando',
        'D04' => 'capas, caché',
        'D05' => 'contexto, .dockerignore',
        'D06' => 'localhost, puertos, red',
        'D07' => 'volumen, filesystem',
        'D08' => 'servicios, volúmenes, healthcheck',
        'D09' => 'logs, exit code, evidencia',
        'D10' => 'secretos, privilegios, superficie',
        'D11' => 'digest, compatibilidad, respaldo',
        _ => 'qué unidad aplica en cada caso',
      };

  Widget _masteryStage(LabSession l) {
    if (!inPosttestPhase(l)) {
      return PosttestRulesCard(novelty: 'Un caso nuevo de la unidad ${unit.code}.');
    }
    if (l.posttestSent || l.done) {
      return PosttestClosing(
        lab: l,
        labId: widget.labId,
        onUpdate: () {
          if (_snap.done) {
            _vm.clearDrafts(_draftScope, _draftFields);
            _vm.clearDrafts(widget.labId, _draftFields);
          }
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
