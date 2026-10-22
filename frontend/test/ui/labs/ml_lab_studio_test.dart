// Lab de curvas (ML) en el Learning Studio: predicción antes de experimentar,
// una CTA por misión, reto GenUI central y postest solo con permiso del servidor.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';
import 'package:cognitiveflow/ui/labs/ml_lab_page.dart';

import 'fake_data_lab_api.dart';

const _mlIntervention = {
  'widget_type': 'HypothesisEditor',
  'widget_parameters': {
    'type': 'HypothesisEditor',
    'title': 'Sube la dificultad',
    'parameters': {
      'complexity': {'min': 1, 'max': 10, 'initial': 7},
    },
  },
  'socratic_question': '¿Qué cambiaría en las curvas con más complejidad?',
  'strategy': 'increase_difficulty',
  'reason': 'Pondrás a prueba tu idea con otra complejidad.',
  'decided_by': 'gemini',
};

Future<FakeDataLabApi> _pump(WidgetTester tester,
    {FakeStage stage = FakeStage.fresh,
    Size size = const Size(1440, 900),
    Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeDataLabApi(stage, _mlIntervention);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: buildCognitiveLightTheme(),
      home: const LabDetailPage(labId: 'lab-ml', title: 'Curvas de aprendizaje'),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('inicio: predecir antes de experimentar, una sola CTA', (tester) async {
    final api = await _pump(tester);
    expect(find.text('Predice antes de experimentar'), findsWidgets);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    // Las curvas no se muestran antes de la predicción.
    expect(find.text('Curvas de entrenamiento y validación'), findsNothing);
    expect(_key('go_posttest'), findsNothing);
    await tester.enterText(_key('ml_prediction'), 'La validación subirá con complejidad alta');
    await tester.pump();
    await tester.tap(_key('ml_cta_predict'));
    await tester.pumpAndSettle();
    expect(api.events.single['event_type'], 'predictionSubmitted');
    expect(find.text('Curvas de entrenamiento y validación'), findsOneWidget);
    // Sin evidencia marcada no se avanza.
    expect(tester.widget<ButtonStyleButton>(_key('ml_cta_experiment')).onPressed, isNull);
    await tester.ensureVisible(_key('ml_mark_evidence'));
    await tester.tap(_key('ml_mark_evidence'));
    await tester.pumpAndSettle();
    expect(api.events.last['event_type'], 'evidenceSelected');
    expect(tester.widget<ButtonStyleButton>(_key('ml_cta_experiment')).onPressed, isNotNull);
  });

  testWidgets('justificar → evaluar → reto central → dominio habilitado por el servidor',
      (tester) async {
    final api = await _pump(tester, prefs: {
      'draft:lab-ml:prediction': 'Subirá la validación',
      'draft:lab-ml:mission_max': '2',
      'draft:lab-ml:epoch': '4',
      'draft:lab-ml:hypo': 'Desde la época 4 la validación sube mientras entrenamiento baja',
    });
    expect(find.text('Justifica con evidencia'), findsWidgets);
    expect(find.textContaining('Época 4 con complejidad'), findsOneWidget);
    await tester.tap(_key('ml_send'));
    await tester.pumpAndSettle();
    expect(api.posts, containsAllInOrder(['/sessions/sess-1/attempts', '/sessions/sess-1/evaluate']));
    expect(find.text('Qué hiciste bien'), findsOneWidget);
    expect(find.text('2 / 4'), findsNothing);
    await tester.tap(_key('next_activity'));
    await tester.pumpAndSettle();
    expect(find.text('Resuelve un nuevo escenario'), findsWidgets);
    // El motivo lo redactó el planificador (sin puntajes).
    expect(find.textContaining('Pondrás a prueba tu idea'), findsOneWidget);
    expect(_key('ml_goto_mastery'), findsNothing);
    await tester.ensureVisible(_key('he_field'));
    await tester.enterText(_key('he_field'), 'Con complejidad 7 se separan antes');
    await tester.pump();
    await tester.tap(_key('he_save'));
    await tester.pumpAndSettle();
    expect(api.events.any((e) => e['event_type'] == 'hypothesisSubmitted'), isTrue);
    expect(tester.widget<ButtonStyleButton>(_key('ml_goto_mastery')).onPressed, isNotNull);
  });

  testWidgets('postest: tutor en pausa y controles fijados por la variante', (tester) async {
    await _pump(tester, stage: FakeStage.posttest);
    expect(find.text('Tutor en pausa'), findsOneWidget);
    expect(find.text('Variante fijada por el servidor'), findsOneWidget);
    expect(_key('ml_save_run'), findsNothing);
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
