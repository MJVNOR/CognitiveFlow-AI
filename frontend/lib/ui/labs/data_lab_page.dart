import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/core/motion.dart';
import '../../ui/labs/data/cleaning_bench.dart';
import '../../ui/labs/data/data_missions.dart';
import '../../ui/labs/data/dataset_explorer.dart';
import '../../ui/labs/data/evidence_inspector.dart';
import '../../ui/labs/data/inspection_scene.dart';
import '../../ui/labs/view_models/lab_session_viewmodel.dart';
import '../../ui/labs/widgets/concept_primer.dart';
import '../../ui/labs/widgets/lab_chrome.dart' show sessionMeta;
import '../../ui/labs/widgets/posttest.dart';
import '../../ui/labs/workspace/contextual_tutor_panel.dart';
import '../../ui/labs/workspace/learning_feedback.dart';
import '../../ui/labs/workspace/learning_studio.dart';
import '../../ui/labs/workspace/mission_navigation.dart';
import '../../ui/labs/workspace/studio_stages.dart';


/// Data Detective en el Learning Studio: 6 misiones sobre una línea de
/// inspección industrial. Explorar → detectar → explicar → limpiar (envío +
/// evaluación) → reto GenUI elegido por el servidor → prueba sin ayuda.
class DataLabPage extends ConsumerStatefulWidget {
  final String labId;
  final String title;
  const DataLabPage({super.key, required this.labId, required this.title});
  @override
  ConsumerState<DataLabPage> createState() => _DataLabState();
}

class _DataLabState extends ConsumerState<DataLabPage> {
  List columns = [];
  List rows = [];
  final flagged = <int>{};
  final cellTypes = <String, String>{};
  final actions = <String, String>{};
  final hypothesis = TextEditingController();
  final justification = TextEditingController();
  final hintsShown = <String, int>{};
  final titleFocus = FocusNode(debugLabel: 'mission-title');
  final scrollCtrl = ScrollController();

  bool ready = false;
  int mission = 0;
  int localMax = 0;
  String? focusSensor;
  String? focusLine;
  int? selectedRow;

  LabSessionViewModel get _vm => ref.read(labSessionProvider(widget.labId).notifier);
  LabSession get lab => ref.watch(labSessionProvider(widget.labId));
  LabSession get _snap => ref.read(labSessionProvider(widget.labId));

  /// El postest usa su propio borrador: nunca hereda las marcas de práctica.
  String _k(String field) => _snap.posttestMode ? 'post_$field' : field;
  int get seed => _snap.posttestMode ? _snap.variantSeed(99) : 1;

  static const _draftFields = [
    'flagged', 'cellmap', 'justification', 'hypothesis', 'mission_max',
    'scenario_done', 'hints', 'post_flagged', 'post_cellmap', 'post_justification',
  ];

  @override
  void initState() {
    super.initState();
    hypothesis.addListener(() {
      _vm.saveDraft(widget.labId, 'hypothesis', hypothesis.text);
      setState(() {});
    });
    justification.addListener(() {
      _vm.saveDraft(widget.labId, _k('justification'), justification.text);
      setState(() {});
    });
    _init();
  }

  @override
  void dispose() {
    hypothesis.dispose();
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
    await _loadTable();
    await _vm.loadObjectives(widget.labId);
    await _restoreDrafts();
    if (!mounted) return;
    setState(() {
      mission = dataDefaultMission(_snap, localMax);
      ready = true;
    });
  }

  Future<void> _restoreDrafts() async {
    final f = await _vm.loadDraft(widget.labId, _k('flagged'));
    final cm = await _vm.loadDraft(widget.labId, _k('cellmap'));
    final j = await _vm.loadDraft(widget.labId, _k('justification'));
    final h = await _vm.loadDraft(widget.labId, 'hypothesis');
    final mm = await _vm.loadDraft(widget.labId, 'mission_max');
    final hs = await _vm.loadDraft(widget.labId, 'hints');
    if (!mounted) return;
    final s = _snap;
    if (f != null && f.isNotEmpty) {
      flagged.addAll([for (final p in f.split(',')) int.tryParse(p)].whereType<int>());
    }
    if (cm != null && cm.isNotEmpty) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(cm) as Map);
        cellTypes.addAll(Map<String, String>.from(m['types'] as Map? ?? {}));
        actions.addAll(Map<String, String>.from(m['actions'] as Map? ?? {}));
      } catch (_) {}
    }
    if (j != null) justification.text = j;
    if (h != null) hypothesis.text = h;
    localMax = int.tryParse(mm ?? '') ?? 0;
    if (hs != null && hs.isNotEmpty) {
      try {
        hintsShown.addAll(Map<String, int>.from(jsonDecode(hs) as Map));
      } catch (_) {}
    }
    // Sin borrador local (otro equipo, caché borrada): la evidencia enviada
    // vive en el servidor; se restaura del último intento.
    final last = s.lastInput;
    if (!s.posttestMode && flagged.isEmpty && last != null) {
      flagged.addAll([for (final x in (last['flags'] as List? ?? const [])) x].whereType<int>());
      final extra = last['extra'];
      if (extra is Map) {
        cellTypes.addAll(Map<String, String>.from(extra['cell_types'] as Map? ?? {}));
        actions.addAll(Map<String, String>.from(extra['actions'] as Map? ?? {}));
        if (hypothesis.text.isEmpty && extra['hypothesis'] is String) {
          hypothesis.text = extra['hypothesis'] as String;
        }
      }
      if (justification.text.isEmpty) justification.text = '${last['answer_text'] ?? ''}';
    }
  }

  Future<void> _loadTable() async {
    try {
      final ds = await _vm.fetchDataset(widget.labId, seed);
      if (!mounted) return;
      setState(() {
        columns = ds['columns'] as List;
        rows = ds['rows'] as List;
      });
    } catch (e) {
      _vm.setStatus('No se pudo cargar la tabla: $e');
    }
  }

  Future<void> _persistFlags() async {
    await _vm.saveDraft(widget.labId, _k('flagged'), flagged.map((e) => '$e').join(','));
    await _vm.saveDraft(
        widget.labId, _k('cellmap'), jsonEncode({'types': cellTypes, 'actions': actions}));
  }

  // ── Navegación entre misiones ────────────────────────────────────────────
  void _goto(int i) {
    final s = _snap;
    setState(() {
      mission = i;
      if (s.attemptId == null && i <= missionClean && i > localMax) localMax = i;
      selectedRow = null;
    });
    _vm.saveDraft(widget.labId, 'mission_max', '$localMax');
    _vm.setStatus('');
    // Foco al título de la nueva misión (lector de pantalla y teclado).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) titleFocus.requestFocus();
    });
  }

  // ── Evidencia ────────────────────────────────────────────────────────────
  void _classify(int id, String type) {
    setState(() {
      if (type == 'sin_anomalia') {
        flagged.remove(id);
        cellTypes.remove('$id');
        actions.remove('$id');
      } else {
        flagged.add(id);
        cellTypes['$id'] = type;
      }
    });
    _persistFlags();
    // El servidor corrige al momento las filas que clasificaste (solo esas).
    _emit('evidenceSelected', {
      'row': id,
      'type': type,
      'cell_types': Map.of(cellTypes),
      'mission': dataMissions[mission].id,
    });
  }

  void _setAction(int id, String action) {
    setState(() => actions['$id'] = action);
    _persistFlags();
  }

  Future<void> _emit(String event, Map<String, Object?> payload) async {
    try {
      await _vm.emitEvent('DataTableExplorer', event, payload);
    } catch (_) {
      // La evidencia también va en el intento; un evento perdido no la borra.
    }
  }

  void _hint() {
    final id = dataMissions[mission].id;
    final n = (hintsShown[id] ?? 0) + 1;
    setState(() => hintsShown[id] = n);
    _vm.saveDraft(widget.labId, 'hints', jsonEncode(hintsShown));
    _emit('hintRequested', {'mission': id, 'level': n});
  }

  // ── Envío, evaluación e intervención ─────────────────────────────────────
  Future<void> _submitPractice() async {
    final s = _snap;
    if (s.sessionId == null || s.evaluating) return;
    _vm.setEvaluating(true);
    _vm.setStatus('');
    try {
      await _vm.send({
        'seed': seed,
        'flags': flagged.toList(),
        'extra': {
          'cell_types': cellTypes,
          'actions': actions,
          'hypothesis': hypothesis.text,
        },
        'answer_text': justification.text,
      }, posttest: false);
    } catch (e) {
      _vm.setEvaluating(false);
      _vm.setStatus('No se pudo enviar: $e. Tu evidencia sigue aquí; vuelve a intentarlo.');
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
    if (mounted && _snap.intervention != null) _goto(missionScenario);
  }

  /// El servidor decide si el reto quedó respondido (evento de entrega del widget).
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
          flagged.clear();
          cellTypes.clear();
          actions.clear();
          justification.text = '';
          selectedRow = null;
          focusSensor = null;
          focusLine = null;
        });
        await _loadTable();
        if (mounted) _goto(missionMastery);
      });

  Future<void> _sendPosttest() async {
    final s = _snap;
    if (s.sessionId == null || s.evaluating) return;
    _vm.setEvaluating(true);
    try {
      await _vm.send({
        'seed': seed,
        'flags': flagged.toList(),
        'extra': {'cell_types': cellTypes, 'actions': actions},
        'answer_text': justification.text,
      }, posttest: true);
      _vm.markDelivered(posttest: true);
    } catch (e) {
      _vm.setEvaluating(false);
      _vm.setStatus('No se pudo entregar: $e. Tu respuesta sigue aquí.');
    }
  }

  // ── Vistas ───────────────────────────────────────────────────────────────
  bool get _postPhase => inPosttestPhase(lab);
  bool get _submitted => lab.attemptId != null;

  /// Misiones 1–4 solo se editan antes del envío de práctica.
  bool get _editable => !_submitted && !_postPhase;

  Map<String, bool>? get _verdicts {
    if (lab.posttestMode) return null;
    final t = (lab.evalResult?['detail'] as Map?)?['types'];
    if (t is! Map) return null;
    return {for (final e in t.entries) '${e.key}': (e.value as Map)['ok'] == true};
  }

  @override
  Widget build(BuildContext context) {
    final l = lab;
    if (!ready) {
      return const Center(child: CircularProgressIndicator());
    }
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
    final views = dataMissionViews(l,
        localMax: localMax, scenarioDone: scenarioDone, selected: mission);
    final m = dataMissions[mission];
    final module = l.objectives.isEmpty
        ? 'Data Science'
        : 'Módulo ${'${l.objectives.first['id']}'.split('-').first}';
    return LearningStudioScaffold(
      stageScroll: scrollCtrl,
      stageKey: ValueKey('scroll-$mission-${l.posttestMode}'),
      header: StudioHeader(
        backRoute: '/academy',
        onReset: () => confirmResetLab(context, _vm),
        crumbs: [('Academia', '/academy'), (module, null), (widget.title, null)],
        title: 'Encuentra el error antes de entrenar',
        missionLabel: 'Misión ${mission + 1} de ${dataMissions.length} · ${m.title}',
        meta: _postPhase ? null : sessionMeta(l),
        done: views.where((v) => v.status == MissionStatus.done).length,
        total: dataMissions.length,
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
        child: _stage(context, l, m),
      ).enterMission(context, ValueKey('enter-$mission-${l.posttestMode}')),
      tutor: _tutor(l, m),
      tutorSummary: l.socraticQ.isNotEmpty
          ? l.socraticQ
          : dataCoach(m.id, flagged: flagged.length, submitted: _submitted),
      actionBar: _actionBar(l) ?? const SizedBox.shrink(),
      missions: MissionNavigation(missions: views, selected: mission, onSelect: _goto),
    );
  }

  Widget? _tutor(LabSession l, Mission m) {
    final locked = l.posttestMode || (mission == missionMastery && !l.done);
    final hints = (_editable || mission == missionScenario) && !locked
        ? (dataHints[m.id] ?? const <String>[])
        : const <String>[];
    final question = mission == missionScenario
        ? '${l.intervention?['socratic_question'] ?? ''}'
        : (_submitted ? l.socraticQ : null);
    return ContextualTutorPanel(
      locked: locked,
      guidance: dataCoach(m.id,
          selectedRow: selectedRow,
          focusSensor: focusSensor,
          flagged: flagged.length,
          submitted: _submitted),
      hypothesis: mission == missionExplore ? null : hypothesis.text,
      hints: hints,
      hintsShown: hintsShown[m.id] ?? 0,
      onHint: _hint,
      evidence: [
        for (final id in (flagged.toList()..sort()))
          TutorEvidence('Fila $id', anomalyTypeLabels[cellTypes['$id']] ?? 'sospechosa'),
      ],
      question: question,
      questionWhy: mission == missionScenario ? '${l.intervention?['reason'] ?? ''}' : null,
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
    final frontier = dataDefaultMission(l, localMax);
    final backToCurrent = bar('Volver a la misión actual', Icons.arrow_forward,
        () => _goto(frontier),
        key: 'data_back_current',
        helper: 'Esta misión ya está entregada: puedes revisarla sin cambiarla.');
    switch (mission) {
      case missionExplore:
        if (!_editable) return backToCurrent;
        return bar('Registrar hipótesis', Icons.lightbulb_outline,
            hypothesis.text.trim().isEmpty ? null : () => _goto(missionDetect),
            key: 'data_cta_hypothesis',
            helper: hypothesis.text.trim().isEmpty
                ? 'Escribe qué problemas sospechas para pasar a detectar.'
                : 'Tu hipótesis queda guardada; la contrastarás al final.');
      case missionDetect:
        if (!_editable) return backToCurrent;
        return bar('Registrar hallazgos (${flagged.length})', Icons.flag,
            flagged.isEmpty ? null : () => _goto(missionExplain),
            key: 'data_cta_findings',
            helper: flagged.isEmpty
                ? 'Abre una fila y elige qué tipo de problema ves.'
                : '${flagged.length} filas marcadas como evidencia.');
      case missionExplain:
        if (!_editable) return backToCurrent;
        return bar('Continuar a limpieza', Icons.cleaning_services_outlined,
            justification.text.trim().isEmpty ? null : () => _goto(missionClean),
            key: 'data_cta_explain',
            helper: justification.text.trim().isEmpty
                ? 'Explica tu decisión citando filas concretas.'
                : null);
      case missionClean:
        if (_postPhase) return backToCurrent;
        if (!_submitted) {
          final ok = flagged.isNotEmpty && justification.text.trim().isNotEmpty;
          return bar('Evaluar mi razonamiento', Icons.fact_check_outlined,
              ok ? _submitPractice : null,
              key: 'data_send',
              busy: l.evaluating,
              helper: l.evaluating
                  ? 'Evaluando tu razonamiento…'
                  : ok
                      ? 'Se envían tu hipótesis, marcas, limpieza y explicación.'
                      : 'Necesitas al menos una fila marcada y tu explicación.');
        }
        final r = l.evalResult;
        if (l.evaluating) {
          return bar('Evaluando…', Icons.fact_check_outlined, null,
              key: 'data_send', busy: true, helper: 'Evaluando tu razonamiento…');
        }
        if (r == null || r['status'] == 'pending' || l.evalError != null) {
          return bar('Reintentar evaluación', Icons.refresh, _retryEval,
              key: 'data_retry_eval',
              helper: l.evalError ?? 'Tu intento está guardado; falta la evaluación.');
        }
        if (l.intervention != null) {
          return bar('Ir al nuevo escenario', Icons.auto_awesome, () => _goto(missionScenario),
              key: 'data_goto_scenario');
        }
        return bar('Explorar nuevo desafío', Icons.auto_awesome, _next,
            key: 'next_activity',
            busy: l.nextBusy,
            helper: l.nextError ?? 'El tutor elegirá el reto según esta evaluación.');
      case missionScenario:
        if (_postPhase) return backToCurrent;
        // Antes de responder, la CTA es la del propio widget GenUI.
        if (!scenarioDone) return null;
        return bar('Demostrar dominio', Icons.verified_outlined,
            l.canEnterPosttest ? () => _goto(missionMastery) : null,
            key: 'data_goto_mastery',
            helper: l.canEnterPosttest
                ? 'Ya puedes hacer la prueba sin ayuda.'
                : 'Esperando que el servidor confirme tu respuesta…');
      default:
        if (!l.posttestMode) {
          return bar('Comenzar prueba sin ayuda', Icons.lock_outline,
              l.canEnterPosttest ? _beginPosttest : null,
              key: 'data_begin_posttest',
              helper: 'Tabla nueva, sin tutor. No podrás volver a la práctica.');
        }
        if (!l.posttestSent) {
          final ok = flagged.isNotEmpty && justification.text.trim().isNotEmpty;
          return bar('Entregar prueba', Icons.send, ok ? _sendPosttest : null,
              key: 'data_send',
              busy: l.evaluating,
              helper: ok ? null : 'Marca filas y justifica antes de entregar.');
        }
        if (!l.done) return null; // la reflexión lleva su propio botón
        return bar('Volver a la academia', Icons.school_outlined,
            () => context.go('/academy'),
            key: 'data_to_academy');
    }
  }

  // ── Escenario central por misión ─────────────────────────────────────────
  Widget _stage(BuildContext context, LabSession l, Mission m) {
    final intro = MissionIntro(mission: m, focusNode: titleFocus);
    final body = switch (mission) {
      missionExplore => _exploreStage(l),
      missionDetect => _inspectStage(l, InspectorMode.classify),
      missionExplain => _explainStage(l),
      missionClean => _cleanStage(l),
      missionScenario => ScenarioStage(lab: l, scenarioDone: scenarioDone, onEvent: _onScenarioEvent),
      _ => _masteryStage(l),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        intro,
        body,
        if (mission == missionDetect) practiceCheck(l, 'Ahora explica por qué en la misión siguiente.'),
      ],
    );
  }

  Widget _exploreStage(LabSession l) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Situación: la planta registra temperatura y presión de cada pieza para '
            'entrenar un modelo que predice defectos. Si el registro trae errores, el '
            'modelo los aprende como si fueran verdad. Tu trabajo: encontrarlos antes.',
            style: TextStyle(height: 1.45),
          ),
        ),
        _inspectStage(l, InspectorMode.explore),
        // Diagnóstico: base guiada ⇒ la microlección se abre sola; si no, el
        // experimento manda y el concepto queda a un toque.
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
                key: const ValueKey('data_concept'),
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
          title: 'Tu hipótesis',
          icon: Icons.lightbulb_outline,
          accent: cs.tertiary,
          child: TextField(
            key: const ValueKey('data_hypothesis'),
            controller: hypothesis,
            enabled: _editable,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              // Ya enviada: sin pista visible, la etiqueta da nombre al lector de pantalla.
              labelText: _editable ? null : 'Tu respuesta (enviada)',
              hintText: '¿Qué problemas crees que tienen estos datos y por qué?',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  /// Escena + explorador + inspector: el laboratorio protagonista.
  Widget _inspectStage(LabSession l, InspectorMode mode) {
    final cs = Theme.of(context).colorScheme;
    if (columns.isEmpty) {
      return StudioCard(
        title: 'Línea de inspección',
        icon: Icons.precision_manufacturing_outlined,
        child: l.status.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
            : Row(children: [
                Expanded(child: Text(l.status)),
                TextButton(onPressed: _loadTable, child: const Text('Reintentar')),
              ]),
      );
    }
    Map? sel;
    for (final r in rows) {
      if (r['id'] == selectedRow) sel = r as Map;
    }
    final verdicts = _verdicts;
    final inspector = sel == null
        ? null
        : EvidenceInspector(
            row: sel,
            rows: rows,
            mode: mode,
            type: cellTypes['${sel['id']}'],
            verdict: verdicts?['${sel['id']}'],
            onType: (t) => _classify(sel!['id'] as int, t),
            onClose: () => setState(() => selectedRow = null),
          ).enterNote(context, ValueKey('insp-${sel['id']}-$mode'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioCard(
          title: 'Línea de inspección',
          icon: Icons.precision_manufacturing_outlined,
          child: InspectionScene(
            rows: rows,
            flagged: flagged,
            focusSensor: focusSensor,
            focusLine: focusLine,
            selectedRow: selectedRow,
            onSensor: (s) => setState(() => focusSensor = s),
            onLine: (v) => setState(() => focusLine = v),
            onRow: (id) => setState(() => selectedRow = id),
          ),
        ),
        StudioCard(
          title: focusSensor == null
              ? 'Registro de la línea (${rows.length} piezas)'
              : 'Registro · columnas de ${focusSensor == 'temp' ? 'T1 (temp + unit)' : 'P1 (pressure)'}',
          icon: Icons.table_chart_outlined,
          child: LayoutBuilder(builder: (context, c) {
            final explorer = DatasetExplorer(
              columns: columns,
              rows: rows,
              flagged: flagged,
              cellTypes: cellTypes,
              selectedRow: selectedRow,
              focusColumns: {...?sensorColumns[focusSensor]},
              focusLine: focusLine,
              verdicts: verdicts,
              onSelectRow: (id) => setState(() => selectedRow = selectedRow == id ? null : id),
              onColumn: (col) => setState(() {
                final s = sensorForColumn(col);
                focusSensor = focusSensor == s ? null : s;
              }),
              onLine: (v) => setState(() => focusLine = v),
            );
            // Tabla ≥ ~460 px + inspector 300 px: al lado en cuanto caben ambos.
            final side = c.maxWidth >= 780;
            final hint = Text(
              mode == InspectorMode.classify
                  ? 'Selecciona una fila para inspeccionarla y clasificarla.'
                  : 'Selecciona una fila para ver sus lecturas, su proceso y compararla.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            );
            if (side) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: explorer),
                const SizedBox(width: 16),
                SizedBox(width: 300, child: inspector ?? hint),
              ]);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              explorer,
              const SizedBox(height: 12),
              AnimatedSize(
                duration: Motion.at(context, Motion.base),
                curve: Motion.mechanical,
                alignment: Alignment.topCenter,
                child: inspector ?? hint,
              ),
            ]);
          }),
        ),
      ],
    );
  }

  Widget _explainStage(LabSession l) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ids = flagged.toList()..sort();
    String reading(int id) {
      for (final r in rows) {
        if (r['id'] == id) {
          return 'temp ${r['temp'] ?? '—'} °${r['unit']} · presión ${r['pressure'] ?? '—'}';
        }
      }
      return '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioCard(
          title: 'Tu evidencia (${ids.length} filas)',
          icon: Icons.push_pin_outlined,
          child: ids.isEmpty
              ? const Text('Aún no marcas filas. Vuelve a «Detecta anomalías».')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final id in ids)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Icon(Icons.flag, size: 16, color: cs.secondary),
                          const SizedBox(width: 8),
                          SizedBox(
                              width: 64,
                              child: Text('Fila $id',
                                  style: const TextStyle(fontWeight: FontWeight.w700))),
                          Expanded(
                            child: Text(
                                '${anomalyTypeLabels[cellTypes['$id']] ?? 'sospechosa'} — ${reading(id)}',
                                style: tt.bodyMedium),
                          ),
                        ]),
                      ),
                  ],
                ),
        ),
        if (hypothesis.text.trim().isNotEmpty)
          StudioCard(
            title: 'Tu hipótesis inicial',
            icon: Icons.lightbulb_outline,
            accent: cs.tertiary,
            child: Text('«${hypothesis.text.trim()}» — ¿se confirmó, cambió o faltó algo?',
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
        StudioCard(
          title: 'Explica tu decisión',
          icon: Icons.edit_note,
          accent: cs.tertiary,
          child: TextField(
            key: const ValueKey('data_justification'),
            controller: justification,
            enabled: _editable,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              // Ya enviada: sin pista visible, la etiqueta da nombre al lector de pantalla.
              labelText: _editable ? null : 'Tu respuesta (enviada)',
              hintText: 'Observo… / Causa probable… / Qué haría… / Qué no haría…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cleanStage(LabSession l) {
    final r = l.evalResult;
    final verdicts = _verdicts;
    final ok = verdicts?.values.where((v) => v).length ?? 0;
    final ko = (verdicts?.length ?? 0) - ok;
    final interventionTitle =
        '${(l.intervention?['widget_parameters'] as Map?)?['title'] ?? ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (l.evaluating && r == null)
          StudioCard(
            title: 'Evaluando tu razonamiento',
            icon: Icons.hourglass_top,
            child: const Row(children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Expanded(child: Text('El evaluador está revisando tus marcas y tu explicación.')),
            ]),
          ),
        if (r != null && _submitted)
          StudioCard(
            title: 'Resultado de tu intento',
            icon: Icons.fact_check_outlined,
            child: LearningFeedbackView(
              evalResult: r,
              feedback: l.feedback,
              strengthEvidence: verdicts == null || ok == 0
                  ? null
                  : '$ok ${ok == 1 ? 'clasificación coincide' : 'clasificaciones coinciden'} con el tipo real',
              gapEvidence: verdicts == null || ko == 0
                  ? null
                  : '$ko ${ko == 1 ? 'fila marcada tiene' : 'filas marcadas tienen'} otro tipo de problema '
                      '(aparecen como «no coincide» en la tabla)',
              revisit: l.socraticQ,
              nextExperiment: interventionTitle.isNotEmpty
                  ? 'Reto elegido: $interventionTitle'
                  : 'Al continuar, el tutor elegirá un escenario nuevo según estas brechas.',
              onRetry: _retryEval,
            ),
          ),
        if (_submitted && verdicts != null) _inspectStage(l, InspectorMode.readonly),
        StudioCard(
          title: 'Limpieza',
          icon: Icons.cleaning_services_outlined,
          child: CleaningBench(
            columns: columns,
            rows: rows,
            flagged: flagged,
            cellTypes: cellTypes,
            actions: actions,
            readOnly: !_editable,
            onAction: _setAction,
          ),
        ),
      ],
    );
  }

  Widget _masteryStage(LabSession l) {
    if (!l.posttestMode) {
      return const PosttestRulesCard(novelty: 'Una tabla nueva que no has visto.');
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PosttestBanner(),
        const SizedBox(height: 16),
        _inspectStage(l, InspectorMode.classify),
        StudioCard(
          title: 'Justifica tu diagnóstico',
          icon: Icons.edit_note,
          child: TextField(
            key: const ValueKey('data_justification'),
            controller: justification,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Qué problemas encontraste, en qué filas y qué harías con cada uno.',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
