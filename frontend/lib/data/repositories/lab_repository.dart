// Repository: fuente de verdad de módulos/labs y datasets de cada lab.
// MVVM: [LabRepository] inyectable vía providers.
import '../../domain/models/models.dart';
import '../services/api_client.dart';

class LabRepository {
  final ApiClient api;
  LabRepository({ApiClient? api}) : api = api ?? defaultApiClient;

  Future<List<Module>> fetchModules() async =>
      parseModules(await api.getList('/modules'));
  Future<List<Lab>> fetchLabs() async => parseLabs(await api.getList('/labs'));

  Future<List<Map<String, dynamic>>> fetchObjectives(String labId) async {
    final objs = await api.getList('/labs/$labId/objectives');
    return [for (final o in objs) Map<String, dynamic>.from(o as Map)];
  }

  Future<Map<String, dynamic>> fetchCurve(
          String labId, int complexity, int noise, int seed) =>
      api.getMap('/labs/$labId/curve?complexity=$complexity&noise_pct=$noise&seed=$seed');

  Future<Map<String, dynamic>> fetchDataset(String labId, int seed) =>
      api.getMap('/labs/$labId/dataset?seed=$seed');

  Future<Map<String, dynamic>> fetchDistributions(String labId, int seed) =>
      api.getMap('/labs/$labId/distributions?seed=$seed');
}
