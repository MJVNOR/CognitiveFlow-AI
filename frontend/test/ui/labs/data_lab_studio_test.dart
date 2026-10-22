// Data Detective en el Learning Studio: una CTA por misión, sin notas ni
// postest prematuros, ciclo completo con reto GenUI central y layouts sin
// overflow. API simulada (sin red).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';
import 'package:cognitiveflow/ui/labs/data/data_missions.dart';
import 'package:cognitiveflow/ui/labs/data_lab_page.dart';
import 'package:cognitiveflow/ui/labs/view_models/lab_session.dart';
import 'package:cognitiveflow/ui/labs/workspace/mission_navigation.dart';

import 'fake_data_lab_api.dart';

Future<FakeDataLabApi> _pump(WidgetTester tester,
    {FakeStage stage = FakeStage.fresh,
    Size size = const Size(1440, 900),
    Map<String, Object> prefs = const {},
    bool reduceMotion = false}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeDataLabApi(stage);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: buildCognitiveLightTheme(),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: const DataLabPage(labId: 'lab-data', title: 'Data Detective'),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  group('estado de misiones (puro)', () {
    test('sesión nueva: solo la primera misión; postest bloqueado', () {
      final v = dataMissionViews(LabSession(), localMax: 0, scenarioDone: false, selected: 0);
      expect(v.first.status, MissionStatus.current);
      expect(v.skip(1).every((m) => m.status == MissionStatus.locked), isTrue);
      expect(v[missionMastery].navigable, isFalse);
    });

    test('el postest solo se abre si el servidor lo autoriza', () {
      final lab = LabSession()
        ..attemptId = 'a'
        ..intervention = {'widget_type': 'DataTableExplorer'};
      expect(
          dataMissionViews(lab, localMax: 3, scenarioDone: true, selected: 4)[missionMastery]
              .navigable,
          isFalse);
      lab.canEnterPosttest = true;
      expect(
          dataMissionViews(lab, localMax: 3, scenarioDone: true, selected: 4)[missionMastery]
              .navigable,
          isTrue);
    });

    test('en postest la práctica queda cerrada', () {
      final lab = LabSession()
        ..attemptId = 'a'
        ..posttestMode = true;
      final v = dataMissionViews(lab, localMax: 3, scenarioDone: true, selected: 5);
      expect([for (final m in v) m.navigable], [false, false, false, false, false, true]);
      expect(dataDefaultMission(lab, 0), missionMastery);
    });
  });

  testWidgets('inicio: una sola CTA, sin puntuaciones ni enlace al postest', (tester) async {
    await _pump(tester);
    expect(find.text('Explora los datos'), findsWidgets);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(find.textContaining('/ 4'), findsNothing);
    expect(_key('go_posttest'), findsNothing);
    expect(find.textContaining('Ir al postest'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'Misión 6: Demuestra dominio, Bloqueada')), findsOneWidget);
  });

  testWidgets('sensor ↔ columna y escena → fila con inspector', (tester) async {
    await _pump(tester);
    await tester.tap(_key('scene_sensor_temp'));
    await tester.pumpAndSettle();
    expect(find.textContaining('columnas de T1'), findsOneWidget);
    await tester.tap(_key('scene_item_7'));
    await tester.pumpAndSettle();
    expect(_key('inspector_7'), findsOneWidget);
    expect(find.descendant(of: _key('inspector_7'), matching: find.text('69.6 °F')), findsOneWidget);
    // Explorar no clasifica: aún no hay botones de tipo.
    expect(_key('inspector_type_unit'), findsNothing);
  });

  testWidgets('hipótesis → detectar → clasificar alimenta la evidencia del tutor',
      (tester) async {
    final api = await _pump(tester);
    await tester.enterText(_key('data_hypothesis'), 'Unidades mezcladas');
    await tester.pump();
    await tester.tap(_key('data_cta_hypothesis'));
    await tester.pumpAndSettle();
    expect(find.text('Detecta anomalías'), findsWidgets);
    await tester.tap(_key('scene_item_25'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_key('inspector_type_outlier'));
    await tester.tap(_key('inspector_type_outlier'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fila 25', findRichText: true), findsWidgets); // evidencia en el tutor
    expect(find.textContaining('Registrar hallazgos (1)'), findsOneWidget);
    expect(api.events.any((e) => e['event_type'] == 'evidenceSelected'), isTrue);
  });

  testWidgets('ciclo completo: evaluar → feedback → reto GenUI central → prueba',
      (tester) async {
    final api = await _pump(tester, prefs: {
      'draft:lab-data:hypothesis': 'Hay unidades mezcladas',
      'draft:lab-data:mission_max': '3',
      'draft:lab-data:flagged': '7,25',
      'draft:lab-data:cellmap': '{"types":{"7":"outlier","25":"outlier"},"actions":{}}',
      'draft:lab-data:justification': 'La fila 25 tiene presión imposible',
    });
    expect(find.text('Limpia y verifica'), findsWidgets);
    await tester.tap(_key('data_send'));
    await tester.pumpAndSettle();
    expect(api.posts, containsAllInOrder(['/sessions/sess-1/attempts', '/sessions/sess-1/evaluate']));
    expect(find.text('Qué hiciste bien'), findsOneWidget);
    expect(find.text('Qué evidencia falta'), findsOneWidget);
    // Números de la rúbrica solo bajo demanda.
    expect(find.text('2 / 4'), findsNothing);
    await tester.ensureVisible(_key('rubric_detail'));
    await tester.tap(_key('rubric_detail'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 4'), findsWidgets);

    await tester.tap(_key('next_activity'));
    await tester.pumpAndSettle();
    expect(find.text('Resuelve un nuevo escenario'), findsWidgets);
    // El motivo explica el reto sin exponer el promedio numérico.
    expect(find.textContaining('faltan anomalías'), findsOneWidget);
    expect(find.textContaining('Promedio'), findsNothing);
    // Antes de responder, la CTA es la del widget (no hay barra competidora).
    expect(_key('data_goto_mastery'), findsNothing);
    await tester.ensureVisible(_key('dte_row_7'));
    await tester.tap(_key('dte_row_7'));
    await tester.enterText(_key('dte_argument'), 'La 7 está en °F, la 25 es imposible');
    await tester.pump();
    await tester.ensureVisible(_key('dte_send'));
    await tester.tap(_key('dte_send'));
    await tester.pumpAndSettle();
    expect(api.events.any((e) => e['event_type'] == 'argumentSubmitted'), isTrue);
    // La corrección del servidor señala qué revisar sin revelar el tipo.
    expect(_key('scenario_check'), findsOneWidget);
    expect(find.textContaining('Vuelve a mirar: fila 2, fila 17'), findsOneWidget);
    final cta = tester.widget<ButtonStyleButton>(_key('data_goto_mastery'));
    expect(cta.onPressed, isNotNull);
  });

  testWidgets('reanudar intento evaluado: evidencia y pregunta vuelven del servidor',
      (tester) async {
    await _pump(tester, stage: FakeStage.evaluated);
    expect(find.text('Limpia y verifica'), findsWidgets);
    expect(find.textContaining('Fila 25', findRichText: true), findsWidgets);
    expect(_key('tutor_question'), findsOneWidget);
    expect(find.text('Qué volver a investigar'), findsOneWidget);
  });

  testWidgets('postest: tutor en pausa, sin pistas', (tester) async {
    await _pump(tester, stage: FakeStage.posttest);
    expect(find.text('Tutor en pausa'), findsOneWidget);
    expect(_key('tutor_hint'), findsNothing);
    expect(find.text('Entregar prueba'), findsOneWidget);
  });

  for (final size in const [Size(1440, 900), Size(1100, 800), Size(820, 1180), Size(390, 844)]) {
    testWidgets('sin overflow en ${size.width.toInt()}×${size.height.toInt()}', (tester) async {
      await _pump(tester, size: size, stage: FakeStage.evaluated);
      expect(tester.takeException(), isNull);
      await _pump(tester, size: size, stage: FakeStage.intervention);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('movimiento reducido: el contenido aparece sin animar', (tester) async {
    await _pump(tester, reduceMotion: true);
    await tester.tap(_key('scene_item_7'));
    await tester.pump();
    expect(_key('inspector_7'), findsOneWidget);
    expect(find.descendant(of: _key('inspector_7'), matching: find.text('69.6 °F')), findsOneWidget);
  });
}
