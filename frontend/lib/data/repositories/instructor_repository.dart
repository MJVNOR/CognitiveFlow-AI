// Repository: instructor readonly (solo lectura, decisión de producto).
// Extraído de session/lab_session.dart sin cambios.
import '../../domain/models/models.dart';
import '../services/api_client.dart';

Future<List<Student>> fetchStudents() async =>
    parseStudents(await fetchJson('/instructor/students'));
Future<List<SessionInfo>> fetchSessions(String studentId) async =>
    parseSessions(await fetchJson('/instructor/students/$studentId/sessions'));
Future<List<Attempt>> fetchAttempts(String sessionId) async =>
    parseAttempts(await fetchJson('/sessions/$sessionId/attempts'));
Future<List<dynamic>> fetchMatrix() => fetchJson('/instructor/matrix');
