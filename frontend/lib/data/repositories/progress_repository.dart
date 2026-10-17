// Repository: progreso del estudiante (me/*).
import '../services/api_client.dart';

Future<Map<String, dynamic>> fetchLabStatus() => fetchMap('/me/lab-status');
Future<List<dynamic>> fetchProgress() => fetchJson('/me/progress');
Future<List<dynamic>> fetchRecallDue() => fetchJson('/me/recall-due');
Future<void> markRecallDone(String id) =>
    postJson('/me/recall/$id/done', {}).then((_) {});
