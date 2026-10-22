// Smoke de DI (MVVM): providers fake → ViewModel → View real.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/data/services/api_client.dart';
import 'package:cognitiveflow/ui/academy/academy_page.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://fake');

  @override
  Future<List<dynamic>> getList(String path) async {
    if (path == '/modules') {
      return [
        {'id': 'm1', 'title': 'Módulo 1', 'order_index': 0},
      ];
    }
    if (path == '/labs') {
      return [
        {
          'id': 'lab-x',
          'title': 'Lab X',
          'lab_type': 'ml_experiment',
          'description': 'd',
          'order_index': 0,
          'module_id': 'm1',
        },
        {
          'id': 'lab-docker',
          'title': 'Docker Academy',
          'lab_type': 'docker',
          'description': 'Contenedores',
          'order_index': 1,
          'module_id': 'm1',
        },
      ];
    }
    throw Exception('404 $path');
  }

  @override
  Future<Map<String, dynamic>> getMap(String path) async {
    if (path == '/me/lab-status') return {'lab-x': 'active'};
    if (path == '/me/docker-units') return {'M08-D01-containers': 'done'};
    throw Exception('404 $path');
  }

  @override
  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    throw Exception('404 $path');
  }
}

void main() {
  testWidgets('academia renderiza labs del ViewModel', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_FakeApi())],
        child: const MaterialApp(home: AcademyPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lab X'), findsWidgets);
    expect(find.text('Tu objetivo actual'), findsOneWidget);
    // Docker: cada unidad implementada es una entrada propia del temario.
    for (final code in ['D01', 'D02', 'D04', 'D07']) {
      expect(find.byKey(ValueKey('academy_unit_$code')), findsOneWidget);
    }
    // D01 completada (servidor) → requisito de D02 cumplido; estado escrito por unidad.
    expect(find.text('Requisito cumplido: D01'), findsOneWidget);
    expect(find.text('Conviene dominar antes: D02'), findsNWidgets(2));
    expect(tester.widget<Text>(find.byKey(const ValueKey('academy_unit_status_D01'))).data,
        'Completado');
    expect(find.textContaining('en preparación'), findsOneWidget);
  });
}
