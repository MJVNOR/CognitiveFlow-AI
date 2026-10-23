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
    if (path == '/me/progress') {
      return [
        {
          'lab_template_id': 'lab-x',
          'baseline': {'exactitud': 2, 'evidencia': 0},
          'posttest': {'exactitud': 4, 'evidencia': 2},
          'mastery_status': 'demonstrated',
        },
      ];
    }
    if (path == '/me/recall-due') {
      return [
        {'id': 'r1', 'lab_template_id': 'lab-x'},
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
    for (final code in ['D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09', 'D10', 'D11', 'D12']) {
      expect(find.byKey(ValueKey('academy_unit_$code')), findsOneWidget);
    }
    // D01 completada (servidor) → requisito de D02 cumplido; estado escrito por unidad.
    expect(find.text('Requisito cumplido: D01'), findsOneWidget);
    expect(find.text('Primero completa D02'), findsNWidgets(3)); // D03, D04 y D07
    expect(tester.widget<Text>(find.byKey(const ValueKey('academy_unit_status_D04'))).data,
        'Bloqueada');
    expect(tester.widget<Text>(find.byKey(const ValueKey('academy_unit_status_D01'))).data,
        'Completado');
    expect(find.textContaining('en preparación'), findsNothing); // temario completo
    // Docker: una unidad hecha de 12 no es «lab completado».
    expect(tester.widget<Text>(find.byKey(const ValueKey('academy_docker_units_done'))).data,
        'Unidades completadas: 1 de 12');
    expect(find.text('Completado'), findsOneWidget); // solo la unidad D01
    // El progreso vive en la Academia: evidencia por lab, dominio y repasos.
    expect(find.text('Ver progreso'), findsNothing);
    final line = tester.widget<Text>(find.byKey(const ValueKey('academy_progress_lab-x'))).data!;
    expect(line, contains('Dominio demostrado'));
    expect(find.byKey(const ValueKey('academy_recalls')), findsOneWidget);
    expect(find.byKey(const ValueKey('recall_done_r1')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('academy_evidence_lab-x')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('academy_evidence_lab-x')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 → 4'), findsOneWidget);
  });

  for (final scale in const [1.0, 1.5]) {
    testWidgets('academia con progreso integrado sin overflow en móvil (texto ${scale}x)',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(_FakeApi())],
          child: MaterialApp(
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: const Scaffold(body: AcademyPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
