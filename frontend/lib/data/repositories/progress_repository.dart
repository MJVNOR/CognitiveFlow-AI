// Repository: progreso del estudiante (me/*).
// MVVM: [ProgressRepository] inyectable vía providers.
import '../services/api_client.dart';

class ProgressRepository {
  final ApiClient api;
  ProgressRepository({ApiClient? api}) : api = api ?? defaultApiClient;

  Future<Map<String, dynamic>> fetchLabStatus() => api.getMap('/me/lab-status');
  Future<List<dynamic>> fetchProgress() => api.getList('/me/progress');
  Future<List<dynamic>> fetchRecallDue() => api.getList('/me/recall-due');
  Future<void> markRecallDone(String id) =>
      api.post('/me/recall/$id/done', {}).then((_) {});
}
