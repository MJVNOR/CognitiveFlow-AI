import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/core/motion.dart';
import '../../ui/core/widgets/chrome.dart' show ParamSlider;
import '../../ui/core/widgets/strings.dart';
import '../../ui/labs/monitor/monitor_missions.dart';
import '../../ui/labs/view_models/lab_session_viewmodel.dart';
import '../../ui/labs/widgets/concept_primer.dart';
import '../../ui/labs/widgets/curve_chart.dart';
import '../../ui/labs/widgets/hist_chart.dart';
import '../../ui/labs/widgets/lab_chrome.dart' show sessionMeta;
import '../../ui/labs/widgets/posttest.dart';
import '../../ui/labs/workspace/contextual_tutor_panel.dart';
import '../../ui/labs/workspace/learning_feedback.dart';
import '../../ui/labs/workspace/learning_studio.dart';
import '../../ui/labs/workspace/mission_navigation.dart';
import '../../ui/labs/workspace/studio_stages.dart';

/// Monitoreo de deriva en el Learning Studio: observar y predecir → comparar
/// distribuciones → decidir (envío + evaluación) → reto GenUI → prueba sin ayuda.
class MonitorLabPage extends ConsumerStatefulWidget {
  final String labId;
  final String title;
  const MonitorLabPage({super.key, required this.labId, required this.title});
  @override
  ConsumerState<MonitorLabPage> createState() => _MonitorState();
}

class _MonitorState extends ConsumerState<MonitorLabPage> {
  String feature = 'temp';
  double changepoint = 90;
  final prediction = TextEditingController();
  final answer = TextEditingController();
  final hintsShown = <String, int>{};
  final titleFocus = FocusNode(debugLabel: 'mission-title');
  final scrollCtrl = ScrollController();
  Map<String, dynamic>? dist;
  int tab = 0;

  /// Evidencia marcada: feature + punto de cambio (null = aún no).
  String? markedFeature;
  int? markedChange;

  bool ready = false;
  int mission = 0;
  int localMax = 0;

  LabSessionViewModel get _vm => ref.read(labSessionProvider(widget.labId).notifier);
  LabSession get lab => ref.watch(labSessionProvider(widget.labId));
  LabSession get _snap => ref.read(labSessionProvider(widget.labId));

  int get seed => _snap.posttestMode ? _snap.variantSeed(99) : 1;
  String _k(String field) => _snap.posttestMode ? 'post_$field' : field;

  static const _draftFields = [
    'feature', 'changepoint', 'answer', 'prediction', 'mission_max', 'hints', 'marked',
    'post_answer', 'post_marked',
  ];

  @override
  void initState() {
    super.initState();
    prediction.addListener(() {
      _vm.saveDraft(widget.labId, 'prediction', prediction.text);
      setState(() {});
    });
    answer.addListener(() {
      _vm.saveDraft(widget.labId, _k('answer'), answer.text);
      setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    prediction.dispose();
    answer.dispose();
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
    await _load();
    if (!mounted) return;
    setState(() {
      mission = studioDefaultMission(monitorMissions, _snap, localMax);
      ready = true;
    });
  }

  Future<void> _restoreDrafts() async {
    final ft = await _vm.loadDraft(widget.labId, 'feature');
    final cp = await _vm.loadDraft(widget.labId, 'changepoint');
    final an = await _vm.loadDraft(widget.labId, _k('answer'));
    final p = await _vm.loadDraft(widget.labId, 'prediction');
    final mm = await _vm.loadDraft(widget.labId, 'mission_max');
    final hs = await _vm.loadDraft(widget.labId, 'hints');
    final mk = await _vm.loadDraft(widget.labId, _k('marked'));
    if (!mounted) return;
    if (ft != null && ft.isNotEmpty) feature = ft;
    changepoint = double.tryParse(cp ?? '') ?? changepoint;
    if (an != null) answer.text = an;
    if (p != null) prediction.text = p;
    localMax = int.tryParse(mm ?? '') ?? 0;
    if (mk != null && mk.contains('@')) {
      markedFeature = mk.split('@').first;
      markedChange = int.tryParse(mk.split('@').last);
    }
    if (hs != null && hs.isNotEmpty) {
      try {
        hintsShown.addAll(Map<String, int>.from(jsonDecode(hs) as Map));
      } catch (_) {}
    }
    // Sin borrador local: la evidencia enviada vive en el servidor.
    final last = _snap.lastInput;
    if (!_snap.posttestMode && last != null) {
      final extra = last['extra'];
      if (extra is Map) {
        if (extra['feature'] is String) feature = extra['feature'] as String;
        if (extra['changepoint'] is num) {
          changepoint = (extra['changepoint'] as num).toDouble();
          markedFeature ??= feature;
          markedChange ??= changepoint.round();
        }
        if (prediction.text.isEmpty && extra['prediction'] is String) {
          prediction.text = extra['prediction'] as String;
        }
      }
      if (answer.text.isEmpty) answer.text = '${last['answer_text'] ?? ''}';
    }
  }

  Future<void> _load() async {
    try {
      final d = await _vm.fetchDistributions(widget.labId, seed);
      if (!mounted) return;
      setState(() => dist = d);
    } catch (e) {
      _vm.setStatus('No se pudieron cargar los datos: $e');
    }
  }

  // ── Navegación y evidencia ───────────────────────────────────────────────
  void _goto(int i) {
    setState(() {
      mission = i;
      if (_snap.attemptId == null && i <= monDecide && i > localMax) localMax = i;
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
      await _vm.emitEvent('DriftDistributionExplorer', event, payload);
    } catch (_) {
      // La evidencia también viaja en el intento; un evento perdido no la borra.
    }
  }

  void _markEvidence() {
    setState(() {
      markedFeature = feature;
      markedChange = changepoint.round();
    });
    _vm.saveDraft(widget.labId, _k('marked'), '$feature@${changepoint.round()}');
    _emit('evidenceSelected', {
      'feature': feature,
      'changepoint': changepoint.round(),
      'mode': _snap.posttestMode ? 'posttest' : 'practice',
    });
  }

  void _hint() {
    final id = monitorMissions[mission].id;
    final n = (hintsShown[id] ?? 0) + 1;
    setState(() => hintsShown[id] = n);
    _vm.saveDraft(widget.labId, 'hints', jsonEncode(hintsShown));
    _emit('hintRequested', {'mission': id, 'level': n});
  }

  // ── Envío, evaluación e intervención ─────────────────────────────────────
  Map<String, dynamic> _attempt() => {
        'seed': seed,
        'extra': {
          'feature': markedFeature ?? feature,
          'changepoint': markedChange ?? changepoint.round(),
          if (!_snap.posttestMode) 'prediction': prediction.text,
        },
        'answer_text': answer.text,
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
    if (mounted && _snap.intervention != null) _goto(monScenario);
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
          answer.text = '';
          markedFeature = null;
          markedChange = null;
        });
        await _load();
        if (mounted) _goto(monMastery);
      });

  Future<void> _sendPosttest() async {
    final s = _snap;
    if (s.sessionId == null || s.evaluating) return;
    _vm.setEvaluating(true);
    try {
      await _vm.send(_attempt(), posttest: true);
      _vm.markDelivered(posttest: true);
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
    final views = studioMissionViews(monitorMissions, l,
        localMax: localMax, scenarioDone: scenarioDone, selected: mission);
    final m = monitorMissions[mission];
    final module = l.objectives.isEmpty
        ? 'MLOps'
        : 'Módulo ${'${l.objectives.first['id']}'.split('-').first}';
    return LearningStudioScaffold(
      stageScroll: scrollCtrl,
      stageKey: ValueKey('scroll-$mission-${l.posttestMode}'),
      header: StudioHeader(
        backRoute: '/academy',
        onReset: () => confirmResetLab(context, _vm),
        crumbs: [('Academia', '/academy'), (module, null), (widget.title, null)],
        title: '¿Cambió el mundo o falló el modelo?',
        missionLabel: 'Misión ${mission + 1} de ${monitorMissions.length} · ${m.title}',
        meta: _postPhase ? null : sessionMeta(l),
        done: views.where((v) => v.status == MissionStatus.done).length,
        total: monitorMissions.length,
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
          : monitorCoach(m.id, feature: markedFeature, changepoint: markedChange),
      actionBar: _actionBar(l) ?? const SizedBox.shrink(),
      missions: MissionNavigation(missions: views, selected: mission, onSelect: _goto),
    );
  }

  Widget _tutor(LabSession l, Mission m) {
    final locked = l.posttestMode || (mission == monMastery && !l.done);
    final hints = (_editable || mission == monScenario) && !locked
        ? (monitorHints[m.id] ?? const <String>[])
        : const <String>[];
    return ContextualTutorPanel(
      locked: locked,
      guidance: monitorCoach(m.id,
          feature: markedFeature, changepoint: markedChange, submitted: _submitted),
      hypothesis: mission == monObserve ? null : prediction.text,
      hints: hints,
      hintsShown: hintsShown[m.id] ?? 0,
      onHint: _hint,
      evidence: [
        if (markedChange != null)
          TutorEvidence('$markedFeature desde t=$markedChange', 'punto de cambio marcado'),
      ],
      question: mission == monScenario
          ? '${l.intervention?['socratic_question'] ?? ''}'
          : (_submitted ? l.socraticQ : null),
      questionWhy: mission == monScenario ? '${l.intervention?['reason'] ?? ''}' : null,
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
    final frontier = studioDefaultMission(monitorMissions, l, localMax);
    final backToCurrent = bar('Volver a la misión actual', Icons.arrow_forward,
        () => _goto(frontier),
        key: 'monitor_back_current',
        helper: 'Esta misión ya está entregada: puedes revisarla sin cambiarla.');
    switch (mission) {
      case monObserve:
        if (!_editable) return backToCurrent;
        final ok = prediction.text.trim().isNotEmpty;
        return bar('Registrar predicción', Icons.lightbulb_outline,
            ok ? () => _goto(monCompare) : null,
            key: 'monitor_cta_predict',
            helper: ok
                ? 'Tu predicción queda guardada; la contrastarás con las distribuciones.'
                : 'Escribe qué crees que cambió antes de comparar.');
      case monCompare:
        if (!_editable) return backToCurrent;
        return bar('Continuar a decidir', Icons.rule,
            markedChange == null ? null : () => _goto(monDecide),
            key: 'monitor_cta_compare',
            helper: markedChange == null
                ? 'Marca la feature y el punto de cambio como evidencia.'
                : 'Evidencia registrada: $markedFeature desde t=$markedChange.');
      case monDecide:
        if (_postPhase) return backToCurrent;
        if (!_submitted) {
          final ok = answer.text.trim().isNotEmpty;
          return bar('Evaluar mi razonamiento', Icons.fact_check_outlined,
              ok ? _submitPractice : null,
              key: 'monitor_send',
              busy: l.evaluating,
              helper: l.evaluating
                  ? 'Evaluando tu razonamiento…'
                  : ok
                      ? 'Se envían tu predicción, la evidencia marcada y tu decisión.'
                      : 'Escribe tu diagnóstico y tu decisión.');
        }
        final r = l.evalResult;
        if (l.evaluating) {
          return bar('Evaluando…', Icons.fact_check_outlined, null,
              key: 'monitor_send', busy: true, helper: 'Evaluando tu razonamiento…');
        }
        if (r == null || r['status'] == 'pending' || l.evalError != null) {
          return bar('Reintentar evaluación', Icons.refresh, _retryEval,
              key: 'monitor_retry_eval',
              helper: l.evalError ?? 'Tu intento está guardado; falta la evaluación.');
        }
        if (l.intervention != null) {
          return bar('Ir al nuevo escenario', Icons.auto_awesome, () => _goto(monScenario),
              key: 'monitor_goto_scenario');
        }
        return bar('Explorar nuevo desafío', Icons.auto_awesome, _next,
            key: 'next_activity',
            busy: l.nextBusy,
            helper: l.nextError ?? 'El tutor elegirá el reto según esta evaluación.');
      case monScenario:
        if (_postPhase) return backToCurrent;
        if (!scenarioDone) return null; // la CTA es la del propio widget GenUI
        return bar('Demostrar dominio', Icons.verified_outlined, () => _goto(monMastery),
            key: 'monitor_goto_mastery', helper: 'Ya puedes hacer la prueba sin ayuda.');
      default:
        if (!l.posttestMode) {
          return bar('Comenzar prueba sin ayuda', Icons.lock_outline,
              l.canEnterPosttest ? _beginPosttest : null,
              key: 'monitor_begin_posttest',
              helper: 'Distribución nueva, sin tutor. No podrás volver a la práctica.');
        }
        if (!l.posttestSent) {
          final ok = answer.text.trim().isNotEmpty && markedChange != null;
          return bar('Entregar prueba', Icons.send, ok ? _sendPosttest : null,
              key: 'monitor_send',
              busy: l.evaluating,
              helper: ok ? null : 'Marca la evidencia y escribe tu decisión antes de entregar.');
        }
        if (!l.done) return null; // la reflexión lleva su propio botón
        return bar('Volver a la academia', Icons.school_outlined,
            () => context.go('/academy'),
            key: 'monitor_to_academy');
    }
  }

  Widget _stage(LabSession l) => switch (mission) {
        monObserve => _observeStage(l),
        monCompare => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _compareStage(l, locked: !_editable),
            practiceCheck(l, 'Bien localizado: decide qué hacer en la misión siguiente.'),
          ]),
        monDecide => _decideStage(l),
        monScenario =>
          ScenarioStage(lab: l, scenarioDone: scenarioDone, onEvent: _onScenarioEvent),
        _ => _masteryStage(l),
      };

  /// Serie de la feature elegida (servidores previos solo envían `series`).
  List<num> _series() =>
      ((dist?['series_by_feature'] as Map?)?[feature] as List? ?? dist?['series'] as List?)
          ?.cast<num>() ??
      [];

  Widget _seriesCard() => StudioCard(
        title: 'Serie del sensor en producción',
        icon: Icons.timeline,
        child: AccessibleSeriesChart(series: _series(), label: 'Serie temporal $feature', height: 220),
      );

  Widget _observeStage(LabSession l) {
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
          'Situación: un modelo de calidad lleva meses en producción. Esta semana las '
          'lecturas del sensor se ven distintas. El equipo pregunta si hay que reentrenar. '
          'Tu trabajo: averiguar qué cambió y decidir con evidencia.',
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
              key: const ValueKey('monitor_concept'),
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
      _seriesCard(),
      StudioCard(
        title: 'Tu predicción',
        icon: Icons.lightbulb_outline,
        accent: cs.tertiary,
        child: TextField(
          key: const ValueKey('monitor_prediction'),
          controller: prediction,
          enabled: _editable,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
              // Ya enviada: sin pista visible, la etiqueta da nombre al lector de pantalla.
              labelText: _editable ? null : 'Tu respuesta (enviada)',
            hintText: 'Creo que cambió… desde… y el modelo (sí / no / no se puede saber aún)…',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ]);
  }

  Widget _compareStage(LabSession l, {required bool locked}) {
    final tt = Theme.of(context).textTheme;
    final feats = (dist?['features'] as Map?) ?? {};
    final sel = (feats[feature] as Map?) ?? {};
    final refD = (sel['ref'] as List?)?.cast<num>() ?? [];
    final cur = (sel['cur'] as List?)?.cast<num>() ?? [];
    final bins = (sel['bins'] as List?)?.cast<num>() ?? [];
    final series = _series();
    final dMean = _avg(cur, bins) - _avg(refD, bins);
    final canMark = !locked || l.posttestMode && !l.posttestSent;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (dist == null && l.status.isNotEmpty)
        Row(children: [
          Expanded(child: Text(l.status)),
          TextButton(onPressed: _load, child: const Text(Strings.retry)),
        ]),
      StudioCard(
        title: 'Referencia vs actual',
        icon: Icons.stacked_bar_chart,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final k in feats.keys.cast<String>())
              ChoiceChip(
                key: ValueKey('feat_$k'),
                label: Text(k),
                selected: feature == k,
                onSelected: canMark
                    ? (_) {
                        setState(() => feature = k);
                        _vm.saveDraft(widget.labId, 'feature', feature);
                      }
                    : null,
              ),
          ]),
          if (refD.isNotEmpty || cur.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Centro de referencia ${_avg(refD, bins).toStringAsFixed(1)} · '
              'centro actual ${_avg(cur, bins).toStringAsFixed(1)} · '
              'Δ ${dMean >= 0 ? '+' : ''}${dMean.toStringAsFixed(1)}',
              style: tt.bodySmall,
            ),
            Text('Cambio en la entrada ≠ caída de precisión: sin etiquetas nuevas no se afirma.',
                style: tt.bodySmall),
            const SizedBox(height: 8),
            AccessibleHistChart(
                ref: refD, cur: cur, bins: bins, showTable: true, label: 'Distribución $feature'),
          ],
        ]),
      ),
      StudioCard(
        title: 'Punto de cambio en la serie',
        icon: Icons.timeline,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AccessibleSeriesChart(
            series: series,
            label: 'Serie temporal $feature',
            marker: changepoint.round(),
          ),
          const SizedBox(height: 8),
          ParamSlider(
            label: 'Punto de cambio',
            value: 't=${changepoint.round()}',
            help: 'Mueve el punto hasta donde la serie actual se separa.',
            current: changepoint,
            min: 0,
            max: series.isEmpty ? 179 : (series.length - 1).toDouble(),
            divisions: series.length > 1 ? series.length - 1 : 179,
            onChanged: canMark ? (v) => setState(() => changepoint = v) : null,
            onChangeEnd: canMark
                ? (_) => _vm.saveDraft(widget.labId, 'changepoint', '$changepoint')
                : null,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              key: const ValueKey('monitor_mark_evidence'),
              onPressed: canMark ? _markEvidence : null,
              child: Text(markedChange == null
                  ? 'Marcar $feature en t=${changepoint.round()} como evidencia'
                  : 'Evidencia: $markedFeature en t=$markedChange (cambiar)'),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _decideStage(LabSession l) {
    final cs = Theme.of(context).colorScheme;
    final r = l.evalResult;
    final interventionTitle = '${(l.intervention?['widget_parameters'] as Map?)?['title'] ?? ''}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (l.evaluating && r == null)
        const EvaluatingCard(detail: 'El evaluador está revisando tu evidencia y tu decisión.'),
      if (r != null && _submitted)
        StudioCard(
          title: 'Resultado de tu intento',
          icon: Icons.fact_check_outlined,
          child: LearningFeedbackView(
            evalResult: r,
            feedback: l.feedback,
            strengthEvidence: markedChange == null
                ? null
                : 'Ubicaste el cambio de $markedFeature en t=$markedChange',
            revisit: l.socraticQ,
            nextExperiment: interventionTitle.isNotEmpty
                ? 'Reto elegido: $interventionTitle'
                : 'Al continuar, el tutor elegirá un escenario nuevo según estas brechas.',
            onRetry: _retryEval,
          ),
        ).enterNote(context, const ValueKey('monitor-feedback')),
      StudioCard(
        title: 'Tu evidencia',
        icon: Icons.push_pin_outlined,
        child: Text(markedChange == null
            ? 'Aún no marcas evidencia. Vuelve a «Compara distribuciones».'
            : '$markedFeature cambia desde t=$markedChange.'),
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
        title: 'Diagnóstico y decisión',
        icon: Icons.edit_note,
        accent: cs.tertiary,
        child: TextField(
          key: const ValueKey('monitor_answer'),
          controller: answer,
          enabled: _editable,
          minLines: 4,
          maxLines: 8,
          decoration: InputDecoration(
              // Ya enviada: sin pista visible, la etiqueta da nombre al lector de pantalla.
              labelText: _editable ? null : 'Tu respuesta (enviada)',
            hintText: 'Qué cambió → desde cuándo → qué no sé aún → monitorear / investigar / reentrenar porque…',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ]);
  }

  Widget _masteryStage(LabSession l) {
    if (!l.posttestMode) {
      return const PosttestRulesCard(novelty: 'Una distribución nueva que no has visto.');
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
      _compareStage(l, locked: true),
      StudioCard(
        title: 'Diagnóstico y decisión',
        icon: Icons.edit_note,
        child: TextField(
          key: const ValueKey('monitor_answer'),
          controller: answer,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: '¿Deriva? ¿En qué feature y desde cuándo? ¿Qué harías y por qué?',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ]);
  }
}

/// Centro ponderado del histograma (lo que el estudiante ve, sin afirmar causalidad).
double _avg(List<num> counts, List<num> bins) {
  if (counts.isEmpty) return 0;
  if (bins.length != counts.length) {
    return counts.fold<double>(0, (a, b) => a + b.toDouble()) / counts.length;
  }
  final total = counts.fold<double>(0, (a, b) => a + b.toDouble());
  if (total == 0) return 0;
  var s = 0.0;
  for (var i = 0; i < counts.length; i++) {
    s += counts[i] * bins[i];
  }
  return s / total;
}
