// ViewModel del lab (MVVM): posee el ciclo sesión→intento→evaluar→
// intervenir→postest y expone [LabSession] como UI state vía Riverpod.
// La View solo observa (`ref.watch`) y llama comandos; la red vive en los
// repositorios ([SessionRepository], [LabRepository], [DraftsRepository]).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/repositories/lab_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../utils/storage/drafts.dart';
import 'lab_session.dart';

export 'lab_session.dart';

class LabSessionViewModel extends Notifier<LabSession> {
  LabSessionViewModel([this.labId = '']);
  final String labId;

  SessionRepository get _sessions => ref.read(sessionRepositoryProvider);
  LabRepository get _labs => ref.read(labRepositoryProvider);
  DraftsRepository get _drafts => ref.read(draftsRepositoryProvider);

  @override
  LabSession build() => LabSession();

  void _emit() => state = state.copy();

  /// Re-notifica tras mutaciones externas del state compartido.
  void touch() => _emit();

  Future<void> init(String labId) async {
    try {
      // ponytail: student_id derived server-side from token (main.py:159); don't send it.
      state.sessionId = await _sessions.createSession(labId);
    } catch (e) {
      state.status = 'Error API: $e';
    }
    _emit();
  }

  Future<void> send(Map<String, dynamic> body,
      {required bool posttest}) async {
    final sid = state.sessionId;
    if (sid == null) return;
    state.attemptId = await _sessions.sendAttempt(
        sessionId: sid, body: body, posttest: posttest);
    _emit();
  }

  /// Evento GenUI → backend (deduplicado por client_event_id). Sin sesión, no-op.
  Future<void> emitEvent(
      String widgetType, String eventType, Map<String, Object?> payload) async {
    final sid = state.sessionId;
    if (sid == null) return;
    final r = await _sessions.emitEvent(sid, widgetType, eventType, payload);
    final check = r['check'];
    if (check is Map) {
      state.scenarioCheck = Map<String, dynamic>.from(check);
      _emit();
    }
    // Responder el reto puede habilitar el postest: lo decide el servidor.
    if (state.intervention != null && !state.canEnterPosttest) await refreshGate();
  }

  /// evaluate y socratic en try separados: si la pregunta falla, la
  /// evaluación se conserva y se puede reintentar solo la pregunta.
  Future<void> evaluate() async {
    final s = state;
    final sid = s.sessionId;
    final aid = s.attemptId;
    if (sid == null || aid == null) return;
    s.evalError = null;
    try {
      s.evalResult = await _sessions.evaluate(sid, aid);
    } catch (e) {
      s.evalError = 'No se pudo evaluar: $e';
      _emit();
      return;
    }
    try {
      final sq = await _sessions.socraticQuestion(sid, aid);
      s.socraticQ = (sq['question'] ?? '') as String;
      final fb = sq['feedback'];
      s.feedback = fb is Map ? Map<String, dynamic>.from(fb) : null;
    } catch (e) {
      s.evalError = 'Evaluado ✓, pero la pregunta no llegó: $e';
    }
    try {
      s.tutorHistory = await _sessions.tutorHistory(sid);
    } catch (_) {}
    _emit();
  }

  Future<void> next() async {
    final s = state;
    final sid = s.sessionId;
    final aid = s.attemptId;
    if (sid == null || aid == null) return;
    s.nextError = null;
    s.scenarioCheck = null;
    try {
      s.intervention = await _sessions.nextIntervention(sid, aid);
    } catch (e) {
      s.nextError = 'No llegó la actividad: $e';
    }
    // Un reto sin entrega (pregunta socrática) ya habilita el postest.
    if (s.intervention != null) await refreshGate();
    _emit();
  }

  /// Relee del servidor si el postest ya está habilitado (tras responder un reto).
  Future<void> refreshGate() async {
    final sid = state.sessionId;
    if (sid == null) return;
    try {
      final det = await _sessions.sessionDetail(sid);
      state.canEnterPosttest = det['can_enter_posttest'] == true;
      final am = det['assistance'];
      if (am is Map) {
        state.assistance = {
          for (final e in am.entries) '${e.key}': (e.value as num).toInt()
        };
      }
    } catch (_) {}
    _emit();
  }

  Future<void> loadHistory() async {
    final sid = state.sessionId;
    if (sid == null) return;
    try {
      state.tutorHistory = await _sessions.tutorHistory(sid);
    } catch (_) {}
    _emit();
  }

  // P1.6: reanudar sesión abierta tras recarga — sin re-evaluar (cero créditos).
  Future<bool> resume(String labId) async {
    final s = state;
    try {
      Map<String, dynamic>? open;
      for (final mm in await _sessions.mySessions(labId)) {
        if (mm['status'] != 'done') open = mm;
      }
      if (open == null) return false;
      final sid = open['id'] as String;
      s.sessionId = sid;
      final det = await _sessions.sessionDetail(sid);
      s.posttestMode = det['status'] == 'posttest';
      final v = det['variant'];
      if (v is Map) s.posttestVariant = Map<String, dynamic>.from(v);
      final atts = await _sessions.attempts(sid);
      s.attemptId = null;
      s.posttestSent = false;
      for (final am in atts) {
        final input = Map<String, dynamic>.from(am['input'] as Map);
        if (input['kind'] == 'posttest') {
          s.posttestSent = true;
        } else if (am['id'] != null) {
          s.attemptId = am['id'] as String;
          s.lastInput = {...input, 'answer_text': am['answer'] ?? ''};
        }
      }
      final le = det['last_eval'];
      s.evalResult = le is Map ? Map<String, dynamic>.from(le) : null;
      s.level = det['level'] as String?;
      s.canEnterPosttest = det['can_enter_posttest'] == true;
      final am = det['assistance'];
      s.assistance = am is Map
          ? {for (final e in am.entries) '${e.key}': (e.value as num).toInt()}
          : null;
      s.socraticQ = '';
      s.feedback = null;
      s.intervention = null;
      try {
        s.tutorHistory = await _sessions.tutorHistory(sid);
        // La última pregunta ya está en el servidor: se restaura sin re-preguntar.
        if (!s.posttestMode && s.evalResult != null && s.tutorHistory.isNotEmpty) {
          s.socraticQ = '${s.tutorHistory.last['question'] ?? ''}';
        }
      } catch (_) {}
      // Sprint 1: restaurar la última actividad al reanudar (sin re-evaluar ni gastar).
      if (!s.posttestMode) {
        try {
          final ivs = await _sessions.interventions(sid);
          if (ivs.isNotEmpty) {
            final last = ivs.last;
            final params = last['widget_parameters'];
            if (params is Map) {
              s.intervention = {
                'widget_type': last['widget_type'],
                'widget_parameters': Map<String, dynamic>.from(params),
                'socratic_question': last['socratic_question'],
                'strategy': last['strategy'],
              };
            }
          }
        } catch (_) {}
      }
      _emit();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> reflect(String text) async {
    final sid = state.sessionId;
    if (sid == null) return;
    final r = await _sessions.reflect(sid, text);
    state.reflectionSummary =
        (r['summary'] as Map?)?.map((k, v) => MapEntry('$k', v));
    state.done = true;
    _emit();
  }

  Future<bool> beginPosttest() async {
    final sid = state.sessionId;
    if (sid == null) return false;
    try {
      state.posttestVariant = await _sessions.beginPosttest(sid);
      _emit();
      return true;
    } catch (e) {
      state.status = 'No se pudo iniciar el postest: $e';
      _emit();
      return false;
    }
  }

  /// Entrada al postest con variante del servidor. Idempotente.
  Future<void> enterPosttest(
    Future<void> Function() reload, [
    void Function()? onVariant,
  ]) async {
    if (await beginPosttest()) {
      final s = state;
      s.posttestMode = true;
      s.evalResult = null;
      s.intervention = null;
      s.socraticQ = '';
      s.feedback = null;
      onVariant?.call();
      _emit();
      await reload();
    } else {
      _emit();
    }
  }

  /// Lección del objetivo (no bloquea el experimento si falla).
  Future<void> loadObjectives(String labId) async {
    try {
      state.objectives = await _labs.fetchObjectives(labId);
    } catch (_) {}
    _emit();
  }

  // Datos del experimento (la View los cachea para las gráficas).
  Future<Map<String, dynamic>> fetchCurve(
          String labId, int complexity, int noise, int seed) =>
      _labs.fetchCurve(labId, complexity, noise, seed);

  Future<Map<String, dynamic>> fetchDataset(String labId, int seed) =>
      _labs.fetchDataset(labId, seed);

  Future<Map<String, dynamic>> fetchDistributions(String labId, int seed) =>
      _labs.fetchDistributions(labId, seed);

  Future<Map<String, dynamic>> fetchDockerActivity(String labId, String unit, int seed) =>
      _labs.fetchDockerActivity(labId, unit, seed);

  Future<Map<String, dynamic>> fetchDockerUnits() => _labs.fetchDockerUnits();

  // Borradores (sobreviven a salir del lab).
  Future<String?> loadDraft(String labId, String field) =>
      _drafts.load(labId, field);

  Future<void> saveDraft(String labId, String field, String value) =>
      _drafts.save(labId, field, value);

  Future<void> clearDrafts(String labId, List<String> fields) =>
      _drafts.clear(labId, fields);

  // Setters de flags del ciclo (la View no muta el state directo).
  void setEvaluating(bool v) {
    state.evaluating = v;
    _emit();
  }

  void setNextBusy(bool v) {
    state.nextBusy = v;
    _emit();
  }

  void setStatus(String v) {
    state.status = v;
    _emit();
  }

  void setPosttestSent(bool v) {
    state.posttestSent = v;
    _emit();
  }

  void markDelivered({
    required bool posttest,
    String? savedMessage,
    String? posttestMessage,
  }) {
    final s = state;
    s.evaluating = false;
    if (posttest) {
      s.posttestSent = true;
      s.status = posttestMessage ?? 'Postest entregado (sin ayuda)';
    } else {
      s.status = savedMessage ?? 'Guardado ✓';
    }
    _emit();
  }
}

/// Un ViewModel por lab (la sesión vive por labId).
final labSessionProvider = NotifierProvider.family<LabSessionViewModel,
    LabSession, String>(
  (labId) => LabSessionViewModel(labId),
);
