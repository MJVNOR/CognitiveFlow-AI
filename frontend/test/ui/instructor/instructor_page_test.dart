// Panel del instructor: solo lectura y telemetría del planificador GenUI.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/data/services/api_client.dart';
import 'package:cognitiveflow/ui/instructor/instructor_page.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://fake');
  final posts = <String>[];

  @override
  Future<List<dynamic>> getList(String path) async => switch (path) {
        '/instructor/students' => [
            {'id': 's1', 'display_name': 'Ana'},
          ],
        '/labs' => [],
        '/instructor/matrix' => [],
        _ => throw Exception('404 $path'),
      };

  @override
  Future<Map<String, dynamic>> getMap(String path) async {
    if (path == '/instructor/planner-stats') {
      return {
        'ml_experiment': {
          'total': 3,
          'gemini': 2,
          'reglas': 1,
          'motivos': {'ok': 2, 'sin_respuesta': 1},
          'latencia_ms': {'mediana': 1400, 'max': 30000, 'n': 3},
        },
      };
    }
    throw Exception('404 $path');
  }

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    posts.add(path);
    throw Exception('el panel del instructor no debe escribir: $path');
  }
}

void main() {
  testWidgets('muestra quién eligió los retos y no escribe nada', (tester) async {
    final api = _FakeApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: const MaterialApp(home: Scaffold(body: InstructorPage())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('planner_stats')));
    await tester.pumpAndSettle();
    expect(find.text('Gemini eligió 2 de 3 retos; las reglas, 1.'), findsOneWidget);
    expect(find.textContaining('Gemini no respondió a tiempo: 1'), findsOneWidget);
    expect(find.textContaining('mediana 1400 ms'), findsOneWidget);
    // Solo lectura: ningún campo editable ni deslizador, y ninguna escritura.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(api.posts, isEmpty);
  });
}
