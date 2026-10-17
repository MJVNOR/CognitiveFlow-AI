// Repository: fuente de verdad de módulos/labs y datasets de cada lab.
// Extraído de session/lab_session.dart + llamadas directas en pages, sin cambios.
import '../../domain/models/models.dart';
import '../services/api_client.dart';

Future<List<Module>> fetchModules() async => parseModules(await fetchJson('/modules'));
Future<List<Lab>> fetchLabs() async => parseLabs(await fetchJson('/labs'));

Future<List<Map<String, dynamic>>> fetchObjectives(String labId) async {
  final objs = await fetchJson('/labs/$labId/objectives');
  return [for (final o in objs) Map<String, dynamic>.from(o as Map)];
}

Future<Map<String, dynamic>> fetchCurve(
    String labId, int complexity, int noise, int seed) =>
    fetchMap('/labs/$labId/curve?complexity=$complexity&noise_pct=$noise&seed=$seed');

Future<Map<String, dynamic>> fetchDataset(String labId, int seed) =>
    fetchMap('/labs/$labId/dataset?seed=$seed');

Future<Map<String, dynamic>> fetchDistributions(String labId, int seed) =>
    fetchMap('/labs/$labId/distributions?seed=$seed');
