import 'package:flutter_test/flutter_test.dart';
import 'package:cognitiveflow/data/repositories/session_repository.dart';
import 'package:cognitiveflow/data/services/api_client.dart';

class InterruptedApi extends ApiClient {
  InterruptedApi() : super(baseUrl: 'http://fake');
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    bodies.add(body);
    if (bodies.length == 1) throw Exception('Respuesta perdida');
    return {'id': body['client_event_id'], 'deduped': bodies.length == 2};
  }
}

void main() {
  test('reintento conserva client_event_id y actividad; otra entrega tiene otro ID', () async {
    final api = InterruptedApi();
    final repo = SessionRepository(api: api);
    Future<Map<String, dynamic>> send(String activity) => repo.emitEvent(
        'session', 'HypothesisEditor', 'hypothesisSubmitted', {'hypothesis': 'x'},
        activityId: activity);
    await expectLater(send('a'), throwsException);
    expect((await send('a'))['deduped'], isTrue);
    expect(api.bodies[0]['client_event_id'], api.bodies[1]['client_event_id']);
    await send('b');
    expect(api.bodies.last['activity_id'], 'b');
    expect(api.bodies.last['client_event_id'], isNot(api.bodies.first['client_event_id']));
    await send('b');
    expect(api.bodies[3]['client_event_id'], isNot(api.bodies[2]['client_event_id']));
  });
}
