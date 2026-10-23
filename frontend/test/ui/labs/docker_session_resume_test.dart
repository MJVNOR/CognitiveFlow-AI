import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/data/services/api_client.dart';
import 'package:cognitiveflow/ui/labs/view_models/lab_session_viewmodel.dart';

class _UnitApi extends ApiClient {
  _UnitApi() : super(baseUrl: 'http://fake');
  final sessions = <String, (String, String)>{
    'd1': ('M08-D01-containers', 'done'),
    'd2': ('M08-D02-lifecycle', 'active'),
  };
  @override
  Future<List<dynamic>> getList(String path) async {
    if (path.startsWith('/me/sessions')) {
      return [for (final entry in sessions.entries)
        {'id': entry.key, 'status': entry.value.$2}];
    }
    final id = path.split('/')[2];
    if (path.endsWith('/attempts')) {
      return [
        {'id': '$id-practice', 'input': {'extra': {'unit': sessions[id]!.$1}}},
        if (sessions[id]!.$2 == 'done')
          {'id': '$id-post', 'input': {'kind': 'posttest'}},
      ];
    }
    return [];
  }
  @override
  Future<Map<String, dynamic>> getMap(String path) async => {
    'status': sessions[path.split('/')[2]]!.$2,
    'can_enter_posttest': false,
  };
  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async => {'id': 'new'};
}

void main() {
  test('D01 cerrada, D02 activa y D03 nueva no comparten estado', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _UnitApi();
    final container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);
    final provider = labSessionProvider('lab-docker');
    final vm = container.read(provider.notifier);

    expect(await vm.resume('lab-docker', unitId: 'M08-D01-containers'), isTrue);
    expect(container.read(provider).sessionId, 'd1');
    expect(container.read(provider).done, isTrue);
    expect(container.read(provider).posttestSent, isTrue);
    expect(container.read(provider).posttestMode, isTrue);

    expect(await vm.resume('lab-docker', unitId: 'M08-D02-lifecycle'), isTrue);
    expect(container.read(provider).sessionId, 'd2');
    expect(container.read(provider).done, isFalse);
    expect(container.read(provider).posttestSent, isFalse);
    expect(container.read(provider).posttestMode, isFalse);
    expect(container.read(provider).canEnterPosttest, isFalse);
    expect(container.read(provider).lastInput?['extra'], {'unit': 'M08-D02-lifecycle'});

    expect(await vm.resume('lab-docker', unitId: 'M08-D03-cli'), isFalse);
    await vm.init('lab-docker');
    expect(container.read(provider).sessionId, 'new');
    expect(container.read(provider).lastInput, isNull);
    expect(container.read(provider).attemptId, isNull);
    expect(container.read(provider).done, isFalse);
  });
}
