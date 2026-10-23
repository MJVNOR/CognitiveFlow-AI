import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/core/motion.dart';
import '../../ui/core/widgets/strings.dart';
import '../../ui/labs/ml/ml_missions.dart';
import '../../ui/labs/view_models/lab_session_viewmodel.dart';
import '../../ui/labs/widgets/concept_primer.dart';
import '../../ui/labs/widgets/curve_chart.dart';
import '../../ui/core/widgets/chrome.dart' show ParamSlider;
import '../../ui/labs/widgets/lab_chrome.dart' show sessionMeta;
import '../../ui/labs/widgets/posttest.dart';
import '../../ui/labs/workspace/contextual_tutor_panel.dart';
import '../../ui/labs/workspace/learning_feedback.dart';
import '../../ui/labs/workspace/learning_studio.dart';
import '../../ui/labs/workspace/mission_navigation.dart';
import '../../ui/labs/workspace/studio_stages.dart';

/// Lab de curvas de aprendizaje en el Learning Studio: predecir → experimentar
/// → justificar (envío + evaluación) → reto GenUI del servidor → prueba sin ayuda.
/// Simulación sintética (no entrena un modelo real): se etiqueta como tal.
class LabDetailPage extends ConsumerStatefulWidget {
  final String labId;
  final String title;
  const LabDetailPage({super.key, required this.labId, required this.title});
  @override
  ConsumerState<LabDetailPage> createState() => _LabDetailState();
}

class _LabDetailState extends ConsumerState<LabDetailPage> {
  double complexity = 5;
  double noise = 20;
  final prediction = TextEditingController();
  final hypo = TextEditingController();
  final hintsShown = <String, int>{};
  final titleFocus = FocusNode(debugLabel: 'mission-title');
  final scrollCtrl = ScrollController();
  Map<String, dynamic>? curve;
  List<num>? savedVal;
  String? savedLabel;
  double epochSel = 0;
  int? markedEpoch;

  bool ready = false;
  int mission = 0;
  int localMax = 0;

  LabSessionViewModel get _vm => ref.read(labSessionProvider(widget.labId).notifier);
  LabSession get lab => ref.watch(labSessionProvider(widget.labId));
  LabSession get _snap => ref.read(labSessionProvider(widget.labId));

  int get seed => _snap.posttestMode ? _snap.variantSeed(99) : 1;

  /// El postest usa su propio borrador: nunca hereda la justificación de práctica.
  String _k(String field) => _snap.posttestMode ? 'post_$field' : field;

  static const _draftFields = [
    'complexity', 'noise', 'hypo', 'prediction', 'mission_max', 'hints', 'epoch', 'post_hypo',
  ];

  @override
  void initState() {
    super.initState();
    prediction.addListener(() {
      _vm.saveDraft(widget.labId, 'prediction', prediction.text);
      setState(() {});
    });
    hypo.addListener(() {
      _vm.saveDraft(widget.labId, _k('hypo'), hypo.text);
      setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    prediction.dispose();
    hypo.dispose();
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
    // En postest manda la variante del servidor, no el borrador.
    final v = _snap.posttestVariant;
    if (_snap.posttestMode && v != null) _applyVariant(v);
    await _loadCurve();
    if (!mounted) return;
    setState(() {
      mission = studioDefaultMission(mlMissions, _snap, localMax);
      ready = true;
    });
  }

  Future<void> _restoreDrafts() async {
    final cx = await _vm.loadDraft(widget.labId, 'complexity');
    final nz = await _vm.loadDraft(widget.labId, 'noise');
    final h = await _vm.loadDraft(widget.labId, _k('hypo'));
    final p = await _vm.loadDraft(widget.labId, 'prediction');
    final mm = await _vm.loadDraft(widget.labId, 'mission_max');
    final hs = await _vm.loadDraft(widget.labId, 'hints');
    final ep = await _vm.loadDraft(widget.labId, 'epoch');
    if (!mounted) return;
    complexity = double.tryParse(cx ?? '') ?? complexity;
    noise = double.tryParse(nz ?? '') ?? noise;
    if (h != null) hypo.text = h;
    if (p != null) prediction.text = p;
    localMax = int.tryParse(mm ?? '') ?? 0;
    markedEpoch = int.tryParse(ep ?? '');
    if (hs != null && hs.isNotEmpty) {
      try {
        hintsShown.addAll(Map<String, int>.from(jsonDecode(hs) as Map));
      } catch (_) {}
    }
    // Sin borrador local: la evidencia enviada vive en el servidor.
    final last = _snap.lastInput;
    if (!_snap.posttestMode && last != null) {
      complexity = (last['complexity'] as num?)?.toDouble() ?? complexity;
      noise = (last['noise_pct'] as num?)?.toDouble() ?? noise;
      final extra = last['extra'];
      if (extra is Map) {
        if (prediction.text.isEmpty && extra['prediction'] is String) {
          prediction.text = extra['prediction'] as String;
        }
        markedEpoch ??= (extra['epoch'] as num?)?.toInt();
      }
      if (hypo.text.isEmpty) hypo.text = '${last['answer_text'] ?? ''}';
    }
  }

  void _applyVariant(Map v) {
    complexity = (v['complexity'] as num?)?.toDouble() ?? complexity;
    noise = (v['noise_pct'] as num?)?.toDouble() ?? noise;
  }

  Future<void> _loadCurve() async {
    try {
      final c = await _vm.fetchCurve(widget.labId, complexity.round(), noise.round(), seed);
      if (!mounted) return;
      setState(() => curve = c);
    } catch (e) {
      _vm.setStatus('No se pudieron cargar las curvas: $e');
    }
  }

  // ── Navegación ───────────────────────────────────────────────────────────
  void _goto(int i) {
    setState(() {
      mission = i;
      if (_snap.attemptId == null && i <= mlJustify && i > localMax) localMax = i;
    });
    _vm.saveDraft(widget.labId, 'mission_max', '$localMax');
    _vm.setStatus('');
    // Foco al título de la nueva misión (lector de pantalla y teclado).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) titleFocus.requestFocus();
    });
  }

  Future<void> _emit(String event, Map<String, Object?> payload) async {
    try {
      await _vm.emitEvent('LearningCurveSimulator', event, payload);
    } catch (_) {
      // La evidencia también viaja en el intento; un evento perdido no la borra.
    }
  }

  void _registerPrediction() {
    _emit('predictionSubmitted', {'prediction': prediction.text});
    _goto(mlExperiment);
  }

  void _markEvidence() {
    final e = epochSel.round();
    setState(() => markedEpoch = e);
    _vm.saveDraft(widget.labId, 'epoch', '$e');
    _emit('evidenceSelected', {
      'epoch': e,
      'complexity': complexity.round(),
      'noise_pct': noise.round(),
      'mode': _snap.posttestMode ? 'posttest' : 'practice',
    });
  }

  void _hint() {
    final id = mlMissions[mission].id;
    final n = (hintsShown[id] ?? 0) + 1;
    setState(() => hintsShown[id] = n);
    _vm.saveDraft(widget.labId, 'hints', jsonEncode(hintsShown));
    _emit('hintRequested', {'mission': id, 'level': n});
  }

  // ── Envío, evaluación e intervención ─────────────────────────────────────
  Map<String, dynamic> _attempt() => {
        'complexity': complexity.round(),
        'noise_pct': noise.round(),
        'seed': seed,
        'answer_text': hypo.text,
        'extra': {
          if (!_snap.posttestMode) 'prediction': prediction.text,
          if (markedEpoch != null) 'epoch': markedEpoch,
        },
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
    if (mounted && _snap.intervention != null) _goto(mlScenario);
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
          hypo.text = '';
          savedVal = null;
          markedEpoch = null;
          epochSel = 0;
        });
        await _loadCurve();
        if (mounted) _goto(mlMastery);
      }, () {
        final v = _snap.posttestVariant;
        if (v != null) setState(() => _applyVariant(v));
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
    final views = studioMissionViews(mlMissions, l,
        localMax: localMax, scenarioDone: scenarioDone, selected: mission);
    final m = mlMissions[mission];
    final module = l.objectives.isEmpty
        ? 'Machine Learning'
        : 'Módulo ${'${l.objectives.first['id']}'.split('-').first}';
    return LearningStudioScaffold(
      stageScroll: scrollCtrl,
      stageKey: ValueKey('scroll-$mission-${l.posttestMode}'),
      header: StudioHeader(
        backRoute: '/academy',
        onReset: () => confirmResetLab(context, _vm),
        crumbs: [('Academia', '/academy'), (module, null), (widget.title, null)],
        title: '¿Aprende o memoriza?',
        missionLabel: 'Misión ${mission + 1} de ${mlMissions.length} · ${m.title}',
        meta: _postPhase ? null : sessionMeta(l),
        done: views.where((v) => v.status == MissionStatus.done).length,
        total: mlMissions.length,
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
          MissionIntro(mission: m, focusNode: titleFocus),
          _stage(l),
        ]),
      ).enterMission(context, ValueKey('enter-$mission-${l.posttestMode}')),
      tutor: _tutor(l, m),
      tutorSummary: l.socraticQ.isNotEmpty
          ? l.socraticQ
          : mlCoach(m.id, markedEpoch: markedEpoch, submitted: _submitted),
      actionBar: _actionBar(l) ?? const SizedBox.shrink(),
      missions: MissionNavigation(missions: views, selected: mission, onSelect: _goto),
    );
  }

  Widget _tutor(LabSession l, Mission m) {
    final locked = l.posttestMode || (mission == mlMastery && !l.done);
    final hints = (_editable || mission == mlScenario) && !locked
        ? (mlHints[m.id] ?? const <String>[])
        : const <String>[];
    return ContextualTutorPanel(
      locked: locked,
      guidance: mlCoach(m.id,
          markedEpoch: markedEpoch, savedRun: savedVal != null, submitted: _submitted),
      hypothesis: mission == mlPredict ? null : prediction.text,
      hints: hints,
      hintsShown: hintsShown[m.id] ?? 0,
      onHint: _hint,
      evidence: [
        if (markedEpoch != null)
          TutorEvidence('Época $markedEpoch', 'donde la validación se despega'),
        if (savedLabel != null) TutorEvidence('Corrida guardada', savedLabel!),
      ],
      question: mission == mlScenario
          ? '${l.intervention?['socratic_question'] ?? ''}'
          : (_submitted ? l.socraticQ : null),
      questionWhy: mission == mlScenario ? '${l.intervention?['reason'] ?? ''}' : null,
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
    final frontier = studioDefaultMission(mlMissions, l, localMax);
    final backToCurrent = bar('Volver a la misión actual', Icons.arrow_forward,
        () => _goto(frontier),
        key: 'ml_back_current',
        helper: 'Esta misión ya está entregada: puedes revisarla sin cambiarla.');
    switch (mission) {
      case mlPredict:
        if (!_editable) return backToCurrent;
        final ok = prediction.text.trim().isNotEmpty;
        return bar('Registrar predicción', Icons.lightbulb_outline,
            ok ? _registerPrediction : null,
            key: 'ml_cta_predict',
            helper: ok
                ? 'Tu predicción queda guardada; la contrastarás con las curvas.'
                : 'Escribe qué esperas antes de mirar las curvas.');
      case mlExperiment:
        if (!_editable) return backToCurrent;
        return bar('Continuar a justificar', Icons.edit_note,
            markedEpoch == null ? null : () => _goto(mlJustify),
            key: 'ml_cta_experiment',
            helper: markedEpoch == null
                ? 'Marca la época donde se despegan las curvas como evidencia.'
                : 'Evidencia registrada: época $markedEpoch.');
      case mlJustify:
        if (_postPhase) return backToCurrent;
        if (!_submitted) {
          final ok = hypo.text.trim().isNotEmpty;
          return bar('Evaluar mi razonamiento', Icons.fact_check_outlined,
              ok ? _submitPractice : null,
              key: 'ml_send',
              busy: l.evaluating,
              helper: l.evaluating
                  ? 'Evaluando tu razonamiento…'
                  : ok
                      ? 'Se envían tu predicción, la época marcada y tu justificación.'
                      : 'Escribe tu justificación citando las dos curvas.');
        }
        final r = l.evalResult;
        if (l.evaluating) {
          return bar('Evaluando…', Icons.fact_check_outlined, null,
              key: 'ml_send', busy: true, helper: 'Evaluando tu razonamiento…');
        }
        if (r == null || r['status'] == 'pending' || l.evalError != null) {
          return bar('Reintentar evaluación', Icons.refresh, _retryEval,
              key: 'ml_retry_eval',
              helper: l.evalError ?? 'Tu intento está guardado; falta la evaluación.');
        }
        if (l.intervention != null) {
          return bar('Ir al nuevo escenario', Icons.auto_awesome, () => _goto(mlScenario),
              key: 'ml_goto_scenario');
        }
        return bar('Explorar nuevo desafío', Icons.auto_awesome, _next,
            key: 'next_activity',
            busy: l.nextBusy,
            helper: l.nextError ?? 'El tutor elegirá el reto según esta evaluación.');
      case mlScenario:
        if (_postPhase) return backToCurrent;
        if (!scenarioDone) return null; // la CTA es la del propio widget GenUI
        return bar('Demostrar dominio', Icons.verified_outlined, () => _goto(mlMastery),
            key: 'ml_goto_mastery', helper: 'Ya puedes hacer la prueba sin ayuda.');
      default:
        if (!l.posttestMode) {
          return bar('Comenzar prueba sin ayuda', Icons.lock_outline,
              l.canEnterPosttest ? _beginPosttest : null,
              key: 'ml_begin_posttest',
              helper: 'Curvas nuevas, sin tutor. No podrás volver a la práctica.');
        }
        if (!l.posttestSent) {
          final ok = hypo.text.trim().isNotEmpty;
          return bar('Entregar prueba', Icons.send, ok ? _sendPosttest : null,
              key: 'ml_send',
              busy: l.evaluating,
              helper: ok ? null : 'Escribe tu diagnóstico antes de entregar.');
        }
        if (!l.done) return null; // la reflexión lleva su propio botón
        return bar('Volver a la academia', Icons.school_outlined,
            () => context.go('/academy'),
            key: 'ml_to_academy');
    }
  }

  Widget _stage(LabSession l) => switch (mission) {
        mlPredict => _predictStage(l),
        mlExperiment => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _experimentStage(l, locked: !_editable),
            practiceCheck(l, 'Esa época muestra el sobreajuste: explícalo al justificar.'),
          ]),
        mlJustify => _justifyStage(l),
        mlScenario =>
          ScenarioStage(lab: l, scenarioDone: scenarioDone, onEvent: _onScenarioEvent),
        _ => _masteryStage(l),
      };

  Widget _predictStage(LabSession l) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Situación: un equipo entrena un modelo cada vez más complejo y el error en '
          'entrenamiento sigue bajando. Antes de desplegarlo, quieren saber si de verdad '
          'aprendió o solo memorizó. Tú vas a averiguarlo con sus curvas.',
          style: TextStyle(height: 1.45),
        ),
      ),
      if (l.objectives.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: cs.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: const ValueKey('ml_concept'),
              initiallyExpanded: l.level == 'needs_foundation',
              leading: Icon(Icons.menu_book_outlined, color: cs.primary),
              title: const Text('El concepto en 1 minuto',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${l.objectives.first['title'] ?? ''}'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [ConceptPrimer(objective: l.objectives.first)],
            ),
          ),
        ),
      StudioCard(
        title: 'Tu predicción',
        icon: Icons.lightbulb_outline,
        accent: cs.tertiary,
        child: TextField(
          key: const ValueKey('ml_prediction'),
          controller: prediction,
          enabled: _editable,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
              // Ya enviada: sin pista visible, la etiqueta da nombre al lector de pantalla.
              labelText: _editable ? null : 'Tu respuesta (enviada)',
            hintText: 'Si subo la complejidad, el error de validación… porque…',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ]);
  }

  Widget _experimentStage(LabSession l, {required bool locked}) {
    final train = (curve?['train'] as List?)?.cast<num>() ?? [];
    final val = (curve?['val'] as List?)?.cast<num>() ?? [];
    final variant = l.posttestMode;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      StudioCard(
        title: variant ? 'Curvas de la prueba' : 'Curvas de entrenamiento y validación',
        icon: Icons.show_chart,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (curve?['simulated'] == true)
            const Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(Strings.simulated, style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (curve == null && l.status.isNotEmpty)
            Row(children: [
              Expanded(child: Text(l.status)),
              TextButton(onPressed: _loadCurve, child: const Text(Strings.retry)),
            ]),
          AccessibleCurveChart(
            train: train,
            val: val,
            val2: savedVal,
            height: 240,
            label: variant ? 'Curvas del postest' : 'Curvas de pérdida',
          ),
        ]),
      ),
      StudioCard(
        title: variant ? 'Variante fijada por el servidor' : 'Controles del experimento',
        icon: Icons.tune,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ParamSlider(
            label: 'Complejidad del modelo',
            value: '${complexity.round()} / 10',
            help: 'Sube la complejidad y mira cuándo la validación se despega.',
            current: complexity,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: locked || variant ? null : (v) => setState(() => complexity = v),
            onChangeEnd: locked || variant
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
            onChanged: locked || variant ? null : (v) => setState(() => noise = v),
            onChangeEnd: locked || variant
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
              onChanged: locked && !variant ? null : (v) => setState(() => epochSel = v),
              onChangeEnd: null,
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonal(
                key: const ValueKey('ml_mark_evidence'),
                onPressed: (locked && !variant) || l.posttestSent ? null : _markEvidence,
                child: Text(markedEpoch == epochSel.round()
                    ? 'Evidencia: época $markedEpoch ✓'
                    : 'Marcar época ${epochSel.round()} como evidencia'),
              ),
              if (!variant)
                OutlinedButton(
                  key: const ValueKey('ml_save_run'),
                  onPressed: curve == null || locked
                      ? null
                      : () => setState(() {
                            savedVal = List<num>.from(val);
                            savedLabel = 'complejidad ${complexity.round()} · ruido ${noise.round()} %';
                          }),
                  child: Text(savedVal == null ? 'Guardar corrida para comparar' : 'Reemplazar corrida guardada'),
                ),
            ]),
          ],
        ]),
      ),
    ]);
  }

  Widget _justifyStage(LabSession l) {
    final cs = Theme.of(context).colorScheme;
    final r = l.evalResult;
    final interventionTitle = '${(l.intervention?['widget_parameters'] as Map?)?['title'] ?? ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (l.evaluating && r == null)
        const EvaluatingCard(detail: 'El evaluador está revisando tu predicción y tu justificación.'),
      if (r != null && _submitted)
        StudioCard(
          title: 'Resultado de tu intento',
          icon: Icons.fact_check_outlined,
          child: LearningFeedbackView(
            evalResult: r,
            feedback: l.feedback,
            strengthEvidence: markedEpoch == null
                ? null
                : 'Anclaste tu explicación en la época $markedEpoch',
            revisit: l.socraticQ,
            nextExperiment: interventionTitle.isNotEmpty
                ? 'Reto elegido: $interventionTitle'
                : 'Al continuar, el tutor elegirá un escenario nuevo según estas brechas.',
            onRetry: _retryEval,
          ),
        ).enterNote(context, const ValueKey('ml-feedback')),
      StudioCard(
        title: 'Lo que observaste',
        icon: Icons.push_pin_outlined,
        child: Text(
          markedEpoch == null
              ? 'Aún no marcas una época. Vuelve a «Experimenta con las curvas».'
              : 'Época $markedEpoch con complejidad ${complexity.round()} y ruido ${noise.round()} %'
                  '${savedLabel == null ? '' : '; comparada con la corrida ($savedLabel)'}.',
        ),
      ),
      if (prediction.text.trim().isNotEmpty)
        StudioCard(
          title: 'Tu predicción inicial',
          icon: Icons.lightbulb_outline,
          accent: cs.tertiary,
          child: Text('«${prediction.text.trim()}» — ¿se confirmó, cambió o faltó algo?',
              style: const TextStyle(fontStyle: FontStyle.italic)),
        ),
      StudioCard(
        title: 'Justifica con las dos curvas',
        icon: Icons.edit_note,
        accent: cs.tertiary,
        child: TextField(
          key: const ValueKey('ml_hypo'),
          controller: hypo,
          enabled: _editable,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
              // Ya enviada: sin pista visible, la etiqueta da nombre al lector de pantalla.
              labelText: _editable ? null : 'Tu respuesta (enviada)',
            hintText: 'Predije… / Observé (época, curvas)… / Causa… / Qué haría…',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ]);
  }

  Widget _masteryStage(LabSession l) {
    if (!l.posttestMode) {
      return const PosttestRulesCard(novelty: 'Curvas nuevas con otra complejidad y ruido.');
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
      _experimentStage(l, locked: true),
      StudioCard(
        title: 'Tu diagnóstico',
        icon: Icons.edit_note,
        child: TextField(
          key: const ValueKey('ml_hypo'),
          controller: hypo,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '¿Aprende o memoriza? Cita ambas curvas y la época, y di qué harías.',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ]);
  }
}
