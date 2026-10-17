// Repository: ciclo de sesión de lab (sesión→intento→evaluar→
// intervenir→postest). Toda la red del ciclo vive aquí; [LabSession] es
// estado puro y [LabSessionViewModel] orquesta.
// Extraído de ui/labs/view_models/lab_session.dart sin cambios de lógica.
import '../services/api_client.dart';

class SessionRepository {
  final ApiClient api;
  SessionRepository({ApiClient? api}) : api = api ?? defaultApiClient;

  /// Crea la sesión; retorna el id (student_id lo deriva el servidor).
  Future<String> createSession(String labId) async {
    final s = await api.post('/sessions', {'lab_template_id': labId});
    return s['id'] as String;
  }

  /// Envía intento (o postest); retorna el attempt id.
  Future<String> sendAttempt({
    required String sessionId,
    required Map<String, dynamic> body,
    required bool posttest,
  }) async {
    final path = posttest ? 'posttest' : 'attempts';
    final a = await api.post('/sessions/$sessionId/$path', body);
    return a['id'] as String;
  }

  /// Evento GenUI → backend (deduplicado por client_event_id).
  Future<void> emitEvent(
    String sessionId,
    String widgetType,
    String eventType,
    Map<String, Object?> payload,
  ) async {
    await api.post('/sessions/$sessionId/events', {
      'client_event_id': newEventId(),
      'widget_type': widgetType,
      'event_type': eventType,
      'payload': payload,
    });
  }

  Future<Map<String, dynamic>> evaluate(String sessionId, String attemptId) =>
      api.post('/sessions/$sessionId/evaluate', {'attempt_id': attemptId});

  Future<Map<String, dynamic>> socraticQuestion(
          String sessionId, String attemptId) =>
      api.post('/sessions/$sessionId/socratic', {'attempt_id': attemptId});

  Future<Map<String, dynamic>> nextIntervention(
          String sessionId, String attemptId) =>
      api.post('/sessions/$sessionId/next-intervention',
          {'attempt_id': attemptId});

  Future<List<Map<String, dynamic>>> tutorHistory(String sessionId) async {
    final h = await api.getList('/sessions/$sessionId/tutor-history');
    return h.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Sesiones propias para un lab (reanudar abierta sin re-evaluar).
  Future<List<Map<String, dynamic>>> mySessions(String labId) async {
    final mine = await api.getList('/me/sessions?lab_template_id=$labId');
    return mine.map((m) => Map<String, dynamic>.from(m as Map)).toList();
  }

  Future<Map<String, dynamic>> sessionDetail(String sessionId) =>
      api.getMap('/sessions/$sessionId');

  Future<List<Map<String, dynamic>>> attempts(String sessionId) async {
    final atts = await api.getList('/sessions/$sessionId/attempts');
    return atts.map((a) => Map<String, dynamic>.from(a as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> interventions(String sessionId) async {
    final ivs = await api.getList('/sessions/$sessionId/interventions');
    return ivs.map((i) => Map<String, dynamic>.from(i as Map)).toList();
  }

  Future<Map<String, dynamic>> reflect(String sessionId, String text) =>
      api.post('/sessions/$sessionId/reflection', {'text': text});

  /// Inicia el postest; el servidor fija la variante.
  Future<Map<String, dynamic>> beginPosttest(String sessionId) =>
      api.post('/sessions/$sessionId/posttest', {'answer_text': ''});
}
