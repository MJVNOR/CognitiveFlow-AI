// Repository: instructor readonly (solo lectura, decisión de producto).
// MVVM: [InstructorRepository] inyectable vía providers.
import '../../domain/models/models.dart';
import '../services/api_client.dart';

class InstructorRepository {
  final ApiClient api;
  InstructorRepository({ApiClient? api}) : api = api ?? defaultApiClient;

  Future<List<Student>> fetchStudents() async =>
      parseStudents(await api.getList('/instructor/students'));
  Future<List<SessionInfo>> fetchSessions(String studentId) async =>
      parseSessions(await api.getList('/instructor/students/$studentId/sessions'));
  Future<List<Attempt>> fetchAttempts(String sessionId) async =>
      parseAttempts(await api.getList('/sessions/$sessionId/attempts'));
  Future<List<dynamic>> fetchMatrix() => api.getList('/instructor/matrix');
}
