// Docker Academy en el Learning Studio: la unidad llega por la ruta (temario),
// una sesión = una unidad, una CTA por misión y reto GenUI central.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';
import 'package:cognitiveflow/ui/labs/docker_lab_page.dart';

import 'fake_data_lab_api.dart';

const _dockerIntervention = {
  'widget_type': 'DockerfileWorkbench',
  'widget_parameters': {
    'type': 'DockerfileWorkbench',
    'title': 'Transfiere: Ordena y reconstruye',
    'parameters': {},
  },
  'socratic_question': '¿Qué instrucción invalida la caché?',
  'strategy': 'explore_alternative',
  'reason': 'Promedio 2.6: domina la unidad, transfiere a M08-D04-dockerfile',
};

Future<FakeDataLabApi> _pump(WidgetTester tester,
    {String? unit,
    FakeStage stage = FakeStage.fresh,
    Size size = const Size(1440, 900),
    Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeDataLabApi(stage, _dockerIntervention);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: buildCognitiveLightTheme(),
      home: DockerLabPage(labId: 'lab-docker', title: 'Docker Academy', unit: unit),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('la unidad viene del temario: sin chips de unidad, aprender → experimentar',
      (tester) async {
    final api = await _pump(tester, unit: 'M08-D02-lifecycle');
    expect(find.text('Imagen, contenedor y ciclo de vida'), findsWidgets);
    expect(find.text('Unidad D02'), findsOneWidget);
    expect(find.byKey(const ValueKey('docker_unit_M08-D01-containers')), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(_key('docker_cta_learn'));
    await tester.pumpAndSettle();
    expect(find.text('Experimenta'), findsWidgets);
    expect(tester.widget<ButtonStyleButton>(_key('docker_cta_experiment')).onPressed, isNull);
    // El escenario llega del servidor: primero se predice, luego se simula.
    expect(find.textContaining('tras «rm»'), findsOneWidget);
    await tester.ensureVisible(_key('icl_pred_imagen'));
    await tester.tap(_key('icl_pred_imagen'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(_key('icl_next'));
      await tester.pumpAndSettle();
    }
    expect(api.events.last['widget_type'], 'ImageContainerLifecycle');
    expect((api.events.last['payload'] as Map)['prediction'], 'imagen');
    expect(tester.widget<ButtonStyleButton>(_key('docker_cta_experiment')).onPressed, isNotNull);
  });

  testWidgets('una sesión = una unidad: la unidad en curso manda sobre la ruta', (tester) async {
    await _pump(tester, unit: 'M08-D04-dockerfile', prefs: {
      'draft:lab-docker:unit': 'M08-D01-containers',
      'draft:lab-docker:mission_max': '1',
    });
    expect(_key('docker_unit_in_progress'), findsOneWidget);
    expect(find.text('Contenedor vs máquina virtual'), findsWidgets);
  });

  testWidgets('justificar → evaluar → reto central → dominio tras responder', (tester) async {
    final api = await _pump(tester, unit: 'M08-D01-containers', prefs: {
      'draft:lab-docker:unit': 'M08-D01-containers',
      'draft:lab-docker:mission_max': '2',
      'draft:lab-docker:interacted': '1',
      'draft:lab-docker:justification': 'El kernel compartido aísla procesos; uso contenedor',
    });
    expect(find.text('Justifica tu decisión'), findsWidgets);
    await tester.tap(_key('docker_send'));
    await tester.pumpAndSettle();
    expect(api.posts, containsAllInOrder(['/sessions/sess-1/attempts', '/sessions/sess-1/evaluate']));
    expect(find.text('Qué hiciste bien'), findsOneWidget);
    await tester.tap(_key('next_activity'));
    await tester.pumpAndSettle();
    expect(find.text('Resuelve un nuevo escenario'), findsWidgets);
    expect(_key('docker_goto_mastery'), findsNothing);
    await tester.ensureVisible(_key('dw_send'));
    await tester.tap(_key('dw_send'));
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(_key('docker_goto_mastery')).onPressed, isNotNull);
  });

  for (final size in const [Size(1440, 900), Size(820, 1180), Size(390, 844)]) {
    testWidgets('sin overflow en ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      await _pump(tester, size: size, unit: 'M08-D07-persistence');
      expect(tester.takeException(), isNull);
      await _pump(tester, size: size, stage: FakeStage.intervention);
      expect(tester.takeException(), isNull);
    });
  }
}
