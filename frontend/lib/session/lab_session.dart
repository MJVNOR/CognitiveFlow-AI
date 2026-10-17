// P6.3: ciclo de sesión + transporte extraídos de main.dart sin cambios de lógica.
// UI y páginas quedan en main.dart; este módulo no importa widgets.
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import '../state/app_state.dart';

const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

Map<String, String> _headers([bool json = false]) => {
      if (apiToken != null) 'Authorization': 'Bearer $apiToken',
      if (json) 'Content-Type': 'application/json',
    };

Future<List<dynamic>> fetchJson(String path) async {
  final r = await http.get(Uri.parse('$apiBase$path'), headers: _headers());
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as List;
}

Future<Map<String, dynamic>> fetchMap(String path) async {
  final r = await http.get(Uri.parse('$apiBase$path'), headers: _headers());
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
  final r = await http.post(
    Uri.parse('$apiBase$path'),
    headers: _headers(true),
    body: jsonEncode(body),
  );
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

// P1.5: id único por evento (reintento seguro vía dedup en backend).
int _eventSeq = 0;
String newEventId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_eventSeq++}';

Future<List<Module>> fetchModules() async => parseModules(await fetchJson('/modules'));
Future<List<Lab>> fetchLabs() async => parseLabs(await fetchJson('/labs'));
Future<List<Student>> fetchStudents() async =>
    parseStudents(await fetchJson('/instructor/students'));
Future<List<SessionInfo>> fetchSessions(String studentId) async =>
    parseSessions(await fetchJson('/instructor/students/$studentId/sessions'));
Future<List<Attempt>> fetchAttempts(String sessionId) async =>
    parseAttempts(await fetchJson('/sessions/$sessionId/attempts'));

/// Ciclo compartido de un lab: sesión → intento → evaluar → intervenir → postest.
/// La página envuelve cada llamada en setState (esta clase no notifica sola).
class LabSession {
  String? sessionId;
  String? attemptId;
  Map<String, dynamic>? evalResult;
  String socraticQ = '';
  Map? intervention;
  String status = '';
  bool evaluating = false;
  bool nextBusy = false;
  String? evalError;
  String? nextError;
  bool posttestMode = false;
  bool posttestSent = false;
  bool done = false;
  // P3.3: historial de preguntas del tutor por sesión (GET tutor-history).
  List<Map<String, dynamic>> tutorHistory = [];
  // PR-06: feedback compuesto fortaleza→brecha (texto Gemini o null en mock).
  Map<String, dynamic>? feedback;

  /// 0 explorar, 1 evaluar, 2 intervenir, 3 postest.
  int get step => (posttestMode || posttestSent || done)
      ? 3
      : intervention != null
          ? 2
          : evalResult != null
              ? 1
              : 0;

  Future<void> init(String labId) async {
    try {
      // ponytail: student_id derived server-side from token (main.py:159); don't send it.
      final s = await postJson('/sessions', {'lab_template_id': labId});
      sessionId = s['id'] as String;
    } catch (e) {
      status = 'Error API: $e';
    }
  }

  Future<void> send(Map<String, dynamic> body, {required bool posttest}) async {
    final path = posttest ? 'posttest' : 'attempts';
    final a = await postJson('/sessions/$sessionId/$path', body);
    attemptId = a['id'] as String;
  }

  /// evaluate y socratic en try separados: si la pregunta falla, la
  /// evaluación se conserva y se puede reintentar solo la pregunta.
  Future<void> evaluate() async {
    evalError = null;
    try {
      evalResult =
          await postJson('/sessions/$sessionId/evaluate', {'attempt_id': attemptId});
    } catch (e) {
      evalError = 'No se pudo evaluar: $e';
      return;
    }
    try {
      final sq =
          await postJson('/sessions/$sessionId/socratic', {'attempt_id': attemptId});
      socraticQ = (sq['question'] ?? '') as String;
      final fb = sq['feedback'];
      feedback = fb is Map ? Map<String, dynamic>.from(fb) : null;
    } catch (e) {
      evalError = 'Evaluado ✓, pero la pregunta no llegó: $e';
    }
    await loadHistory();
  }

  Future<void> next() async {
    nextError = null;
    try {
      intervention = await postJson(
          '/sessions/$sessionId/next-intervention', {'attempt_id': attemptId});
    } catch (e) {
      nextError = 'No llegó la actividad: $e';
    }
  }

  Future<void> loadHistory() async {
    try {
      final h = await fetchJson('/sessions/$sessionId/tutor-history');
      tutorHistory = h.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
  }

  // P1.6: reanudar sesión abierta tras recarga — sin re-evaluar (cero créditos).
  Future<bool> resume(String labId) async {
    try {
      final mine = await fetchJson('/me/sessions?lab_template_id=$labId');
      Map<String, dynamic>? open;
      for (final m in mine) {
        final mm = Map<String, dynamic>.from(m as Map);
        if (mm['status'] != 'done') open = mm;
      }
      if (open == null) return false;
      sessionId = open['id'] as String;
      final det = await fetchMap('/sessions/$sessionId');
      posttestMode = det['status'] == 'posttest';
      final v = det['variant'];
      if (v is Map) posttestVariant = Map<String, dynamic>.from(v);
      final atts = await fetchJson('/sessions/$sessionId/attempts');
      attemptId = null;
      posttestSent = false;
      for (final a in atts) {
        final am = Map<String, dynamic>.from(a as Map);
        final input = Map<String, dynamic>.from(am['input'] as Map);
        if (input['kind'] == 'posttest') {
          posttestSent = true;
        } else if (am['id'] != null) {
          attemptId = am['id'] as String;
        }
      }
      final le = det['last_eval'];
      evalResult = le is Map ? Map<String, dynamic>.from(le) : null;
      socraticQ = '';
      feedback = null;
      intervention = null;
      await loadHistory();
      // Sprint 1: restaurar la última actividad al reanudar (sin re-evaluar ni gastar).
      if (!posttestMode) {
        try {
          final ivs = await fetchJson('/sessions/$sessionId/interventions');
          if (ivs.isNotEmpty) {
            final last = Map<String, dynamic>.from(ivs.last as Map);
            final params = last['widget_parameters'];
            if (params is Map) {
              intervention = {
                'widget_type': last['widget_type'],
                'widget_parameters': Map<String, dynamic>.from(params),
                'socratic_question': last['socratic_question'],
                'strategy': last['strategy'],
              };
            }
          }
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> reflect(String text) async {
    final r = await postJson('/sessions/$sessionId/reflection', {'text': text});
    reflectionSummary = (r['summary'] as Map?)?.map((k, v) => MapEntry('$k', v));
    done = true;
  }

  // P4.1: el servidor fija la variante del postest; el cliente la aplica.
  Map<String, dynamic>? posttestVariant;
  Map<String, dynamic>? reflectionSummary;

  Future<bool> beginPosttest() async {
    try {
      final r = await postJson('/sessions/$sessionId/posttest', {'answer_text': ''});
      posttestVariant = r;
      return true;
    } catch (e) {
      status = 'No se pudo iniciar el postest: $e';
      return false;
    }
  }

  int variantSeed(int fallback) => (posttestVariant?['seed'] as num?)?.toInt() ?? fallback;
}

// P4.1: entrada al postest con variante del servidor (igual en los 3 labs).
// beginPosttest es idempotente: doble toque no duplica nada.
Future<void> enterPosttest(LabSession lab, void Function(void Function()) setState,
    Future<void> Function() reload,
    [void Function()? onVariant]) async {
  if (await lab.beginPosttest()) {
    setState(() {
      lab.posttestMode = true;
      lab.evalResult = null;
      lab.intervention = null;
      lab.socraticQ = '';
      lab.feedback = null;
      onVariant?.call();
    });
    await reload();
  } else {
    setState(() {});
  }
}

// P2.4: etiquetas humanas para criterios Jev — nunca solo `id · score`.
const criterionLabels = {
  'exactitud': 'Exactitud conceptual',
  'evidencia': 'Uso de evidencia',
  'causal': 'Causalidad',
  'alternativas': 'Alternativas',
  'metacognicion': 'Revisión',
};

String criterionLabel(String id) => criterionLabels[id] ?? id;

// P4.2: línea inicial→postest desde mapas {criterio: score 0-4}; null si no comparable.
String? progressLine(Map? base, Map? post) {
  double? avg(Map? m) {
    if (m == null || m.isEmpty) return null;
    var t = 0.0;
    for (final v in m.values) {
      t += (v as num).toDouble();
    }
    return t / m.length;
  }

  final b = avg(base);
  final p = avg(post);
  String f(double v) => v.toStringAsFixed(1);
  if (b == null && p == null) return null;
  if (b == null) return 'Inicial sin registrar · Postest ${f(p!)}/4';
  if (p == null) return 'Inicial ${f(b)}/4 · Postest pendiente';
  final d = p - b;
  return 'Inicial ${f(b)}/4 → Postest ${f(p)}/4 (${d >= 0 ? '+' : ''}${f(d)})';
}
