// Monitoreo de deriva en el Learning Studio: predicción antes de comparar,
// evidencia marcada, reto GenUI central y layouts sin overflow.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';
import 'package:cognitiveflow/ui/labs/monitor_lab_page.dart';

import 'fake_data_lab_api.dart';

const _driftIntervention = {
  'widget_type': 'DriftDistributionExplorer',
  'widget_parameters': {
    'type': 'DriftDistributionExplorer',
    'title': '¿Qué cambió?',
    'parameters': {
      'features': ['temp', 'pressure'],
    },
  },
  'socratic_question': '¿Cambió la entrada o cayó la precisión?',
  'strategy': 'request_evidence',
  'reason': 'Promedio 1.8: falta identificar deriva con evidencia',
};

Future<FakeDataLabApi> _pump(WidgetTester tester,
    {FakeStage stage = FakeStage.fresh,
    Size size = const Size(1440, 900),
    Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeDataLabApi(stage, _driftIntervention);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: buildCognitiveLightTheme(),
      home: const MonitorLabPage(labId: 'lab-monitor', title: 'Monitoreo de deriva'),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('observar → predecir → comparar y marcar evidencia', (tester) async {
    final api = await _pump(tester);
    expect(find.text('Observa y predice'), findsWidgets);
    expect(find.byType(FilledButton), findsOneWidget);
    // Los histogramas no aparecen antes de predecir.
    expect(find.text('Referencia vs actual'), findsNothing);
    await tester.enterText(_key('monitor_prediction'), 'Cambió la temperatura a mitad de la serie');
    await tester.pump();
    await tester.tap(_key('monitor_cta_predict'));
    await tester.pumpAndSettle();
    expect(find.text('Referencia vs actual'), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(_key('monitor_cta_compare')).onPressed, isNull);
    await tester.ensureVisible(_key('monitor_mark_evidence'));
    await tester.tap(_key('monitor_mark_evidence'));
    await tester.pumpAndSettle();
    final ev = api.events.last;
    expect(ev['widget_type'], 'DriftDistributionExplorer');
    expect(ev['event_type'], 'evidenceSelected');
    expect((ev['payload'] as Map)['feature'], 'temp');
    expect(tester.widget<ButtonStyleButton>(_key('monitor_cta_compare')).onPressed, isNotNull);
  });

  testWidgets('decidir → evaluar → reto central → dominio tras responder', (tester) async {
    final api = await _pump(tester, prefs: {
      'draft:lab-monitor:prediction': 'Cambió temp',
      'draft:lab-monitor:mission_max': '2',
      'draft:lab-monitor:marked': 'temp@120',
      'draft:lab-monitor:answer': 'Deriva en temp desde t=120 comparando referencia; monitorear',
    });
    expect(find.text('Diagnostica y decide'), findsWidgets);
    expect(find.text('temp cambia desde t=120.'), findsOneWidget);
    await tester.tap(_key('monitor_send'));
    await tester.pumpAndSettle();
    expect(api.posts, containsAllInOrder(['/sessions/sess-1/attempts', '/sessions/sess-1/evaluate']));
    expect(find.text('Qué hiciste bien'), findsOneWidget);
    await tester.tap(_key('next_activity'));
    await tester.pumpAndSettle();
    expect(find.text('Resuelve un nuevo escenario'), findsWidgets);
    expect(find.textContaining('Promedio'), findsNothing);
    await tester.ensureVisible(_key('dde_feat_temp'));
    await tester.tap(_key('dde_feat_temp'));
    await tester.enterText(_key('dde_argument'), 'Cambió la entrada; sin etiquetas no sé si cayó la precisión');
    await tester.pump();
    await tester.ensureVisible(_key('dde_send'));
    await tester.tap(_key('dde_send'));
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(_key('monitor_goto_mastery')).onPressed, isNotNull);
  });

  testWidgets('postest: tutor en pausa, sin pistas', (tester) async {
    await _pump(tester, stage: FakeStage.posttest);
    expect(find.text('Tutor en pausa'), findsOneWidget);
    expect(find.text('Entregar prueba'), findsOneWidget);
  });

  for (final size in const [Size(1440, 900), Size(820, 1180), Size(390, 844)]) {
    testWidgets('sin overflow en ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      await _pump(tester, size: size, stage: FakeStage.evaluated);
      expect(tester.takeException(), isNull);
      await _pump(tester, size: size, stage: FakeStage.intervention);
      expect(tester.takeException(), isNull);
    });
  }
}
