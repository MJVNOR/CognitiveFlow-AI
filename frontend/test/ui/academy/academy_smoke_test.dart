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
      ];
    }
    throw Exception('404 $path');
  }

  @override
  Future<Map<String, dynamic>> getMap(String path) async {
    if (path == '/me/lab-status') return {'lab-x': 'active'};
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
  });
}
