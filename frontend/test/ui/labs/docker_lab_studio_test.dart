// Docker Academy en el Learning Studio: la unidad llega por la ruta (temario),
// una sesión = una unidad, una CTA por misión y reto GenUI central.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';
import 'package:cognitiveflow/ui/labs/docker_lab_page.dart';
import 'package:cognitiveflow/ui/labs/docker/docker_units.dart';
import 'package:cognitiveflow/ui/labs/view_models/lab_session_viewmodel.dart';

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
    bool failActivity = false,
    Size size = const Size(1440, 900),
    double textScale = 1,
    Map<String, Object> prefs = const {},
    // Por defecto los prerrequisitos de D02/D04/D07 están completados.
    Map<String, dynamic> units = const {
      'M08-D01-containers': 'done',
      'M08-D02-lifecycle': 'done',
    }}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeDataLabApi(stage, _dockerIntervention)
    ..dockerUnits = units
    ..failDockerActivity = failActivity
    ..dockerSessionUnit = unit ?? 'M08-D01-containers';
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: buildCognitiveLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: DockerLabPage(labId: 'lab-docker', title: 'Docker Academy', unit: unit),
    ),
  ));
  await tester.pumpAndSettle();
  return api;
}

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  testWidgets('D02: respuesta escrita antes de simular explica el bloqueo y se habilita al terminar', (tester) async {
    await _pump(tester, unit: 'M08-D02-lifecycle');
    await tester.tap(_key('docker_cta_learn'));
    await tester.pumpAndSettle();
    await tester.tap(_key('icl_pred_imagen'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('docker_justification'), 'Mi explicación ya está escrita');
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(_key('docker_send')).onPressed, isNull);
    expect(find.text('Predicción comprobada'), findsOneWidget);
    expect(find.text('Bien resuelto'), findsNothing);
    expect(find.textContaining('Falta pulsar «Ejecutar…»'), findsOneWidget);
    expect(find.text('Comandos ejecutados: 0 de 4.'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(_key('icl_next'));
      await tester.tap(_key('icl_next'));
      await tester.pumpAndSettle();
      expect(tester.widget<ButtonStyleButton>(_key('docker_send')).onPressed,
          i < 3 ? isNull : isNotNull);
    }
    expect(find.text('Mi explicación ya está escrita'), findsOneWidget);
    await tester.ensureVisible(_key('icl_reset'));
    await tester.tap(_key('icl_reset'));
    await tester.pumpAndSettle();
    expect(tester.widget<ButtonStyleButton>(_key('docker_send')).onPressed, isNull);
    expect(find.text('Mi explicación ya está escrita'), findsOneWidget);
    expect(find.text('Predicción comprobada'), findsNothing);
    expect(find.text('Comandos ejecutados: 0 de 4.'), findsOneWidget);
  });

  testWidgets('las cuatro pistas largas se leen en móvil al 200% sin desbordar', (tester) async {
    await _pump(tester, unit: 'M08-D01-containers', stage: FakeStage.intervention,
        size: const Size(390, 844), textScale: 2);
    await tester.ensureVisible(find.text('Tutor'));
    await tester.tap(find.text('Tutor'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(_key('tutor_hint'));
      await tester.tap(_key('tutor_hint'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.textContaining('Ejemplo distinto: en una app Go'), findsOneWidget);
    expect(_key('tutor_hint'), findsNothing);
  });

  testWidgets('pistas del reto D04 desde D01: graduales, telemetría correcta y contexto nuevo independiente', (tester) async {
    final api = await _pump(tester, unit: 'M08-D01-containers', stage: FakeStage.intervention);
    final hints = dockerHintsFor('M08-D04-dockerfile', 'nuevo');
    for (var i = 0; i < hints.length; i++) {
      expect(find.textContaining(hints[i]), findsNothing);
      await tester.ensureVisible(_key('tutor_hint'));
      await tester.tap(_key('tutor_hint'));
      await tester.pumpAndSettle();
      expect(find.textContaining(hints[i]), findsOneWidget);
      final event = api.events.last;
      expect(event['widget_type'], 'DockerfileWorkbench');
      expect(event['event_type'], 'hintRequested');
      expect((event['payload'] as Map)['unit'], 'M08-D04-dockerfile');
      expect((event['payload'] as Map)['level'], i + 1);
    }
    expect(_key('tutor_hint'), findsNothing);
    expect(find.textContaining(dockerHintsFor('M08-D01-containers', 'nuevo').first), findsNothing);

    final container = ProviderScope.containerOf(tester.element(find.byType(DockerLabPage)));
    final provider = labSessionProvider('lab-docker');
    container.read(provider).intervention = {
      ..._dockerIntervention,
      'widget_parameters': {
        'title': 'Otra variante',
        'parameters': {'unit': 'M08-D04-dockerfile', 'seed': 81},
      },
    };
    container.read(provider.notifier).touch();
    await tester.pumpAndSettle();
    expect(find.textContaining(hints.first), findsNothing);
    expect(_key('tutor_hint'), findsOneWidget);
    await tester.ensureVisible(_key('tutor_hint'));
    await tester.tap(_key('tutor_hint'));
    await tester.pumpAndSettle();
    expect((api.events.last['payload'] as Map)['level'], 1);
  });

  testWidgets('la prueba D02 no muestra pistas ni preguntas del tutor', (tester) async {
    await _pump(tester, unit: 'M08-D02-lifecycle', stage: FakeStage.posttest);
    expect(_key('tutor_hint'), findsNothing);
    expect(_key('tutor_question'), findsNothing);
    expect(find.text('Tutor en pausa'), findsOneWidget);
  });

  testWidgets('sin escenario del servidor no se inventa uno: reintento conserva respuesta', (tester) async {
    final api = await _pump(tester, unit: 'M08-D02-lifecycle', failActivity: true, prefs: {
      'draft:lab-docker:unit': 'M08-D02-lifecycle',
      'draft:lab-docker:mission_max': '1',
      'draft:lab-docker:justification': 'Mi explicación guardada',
    });
    expect(_key('docker_activity_retry'), findsOneWidget);
    expect(_key('icl_next'), findsNothing);
    expect(find.text('Mi explicación guardada'), findsOneWidget);
    api.failDockerActivity = false;
    await tester.tap(_key('docker_activity_retry'));
    await tester.pumpAndSettle();
    expect(_key('icl_next'), findsOneWidget);
    expect(find.text('Mi explicación guardada'), findsOneWidget);
  });
  testWidgets('la unidad viene del temario: sin chips de unidad, aprender → experimentar',
      (tester) async {
    final api = await _pump(tester, unit: 'M08-D02-lifecycle');
    expect(find.text('Imagen, contenedor y ciclo de vida'), findsWidgets);
    expect(find.text('Unidad D02'), findsOneWidget);
    expect(find.byKey(const ValueKey('docker_unit_M08-D01-containers')), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(_key('docker_cta_learn'));
    await tester.pumpAndSettle();
    expect(find.text('Experimenta y justifica'), findsWidgets);
    expect(tester.widget<ButtonStyleButton>(_key('docker_send')).onPressed, isNull);
    // El escenario llega del servidor: primero se predice, luego se simula.
    expect(find.textContaining('tras el paso 4 («docker rm»)'), findsOneWidget);
    await tester.ensureVisible(_key('icl_pred_imagen'));
    await tester.tap(_key('icl_pred_imagen'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(_key('icl_next'));
      await tester.pumpAndSettle();
    }
    expect(api.events.last['widget_type'], 'ImageContainerLifecycle');
    expect((api.events.last['payload'] as Map)['prediction'], 'imagen');
    // Decidir no basta: la justificación va ahí mismo, bajo el experimento.
    expect(tester.widget<ButtonStyleButton>(_key('docker_send')).onPressed, isNull);
    await tester.enterText(_key('docker_justification'), 'rm borra el contenedor, la imagen queda');
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(_key('docker_send')).onPressed, isNotNull);
  });

  testWidgets('un borrador de D01 no reemplaza la unidad D04 de la ruta', (tester) async {
    await _pump(tester, unit: 'M08-D04-dockerfile', prefs: {
      'draft:lab-docker:unit': 'M08-D01-containers',
      'draft:lab-docker:mission_max': '1',
    });
    expect(_key('docker_unit_in_progress'), findsNothing);
    expect(find.text('Dockerfile y capas'), findsWidgets);
    expect(find.text('1/5 misiones'), findsNothing);
    expect(find.text('0/5 misiones'), findsOneWidget);
  });

  testWidgets('unidad terminada reabre el cierre con cinco misiones completas', (tester) async {
    await _pump(tester, unit: 'M08-D01-containers', stage: FakeStage.done);
    expect(find.text('5/5 misiones'), findsOneWidget);
    expect(find.text('Sesión cerrada. Gracias por tu reflexión.'), findsOneWidget);
    expect(_key('docker_begin_posttest'), findsNothing);
    expect(_key('docker_to_academy'), findsOneWidget);
  });

  testWidgets('experimento + justificación → evaluar → reto central → dominio tras responder', (tester) async {
    final api = await _pump(tester, unit: 'M08-D01-containers', prefs: {
      'draft:lab-docker:unit': 'M08-D01-containers',
      'draft:lab-docker:mission_max': '2',
      'draft:lab-docker:interacted': '1',
      'draft:lab-docker:justification': 'El kernel compartido aísla procesos; uso contenedor',
    });
    expect(find.text('Experimenta y justifica'), findsWidgets);
    expect(find.text('Justifica tu decisión'), findsOneWidget); // en la misma misión
    await tester.ensureVisible(_key('docker_send'));
    await tester.tap(_key('docker_send'));
    await tester.pumpAndSettle();
    expect(api.posts, containsAllInOrder(['/sessions/sess-1/attempts', '/sessions/sess-1/evaluate']));
    expect(find.text('Revisa tu evaluación'), findsWidgets);
    expect(find.text('Qué hiciste bien'), findsOneWidget);
    await tester.tap(_key('next_activity'));
    await tester.pumpAndSettle();
    expect(find.text('Resuelve un nuevo escenario'), findsWidgets);
    expect(_key('docker_goto_mastery'), findsNothing);
    await tester.ensureVisible(_key('dw_up_1'));
    await tester.tap(_key('dw_up_1')); // el reto se entrega al reordenar
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

  testWidgets('unidad con prerrequisito pendiente: bloqueada y con atajo a la previa',
      (tester) async {
    await _pump(tester, unit: 'M08-D04-dockerfile', units: const {'M08-D01-containers': 'done'});
    expect(_key('docker_unit_locked'), findsOneWidget);
    expect(find.text('Unidad D04 bloqueada'), findsOneWidget);
    expect(find.text('Ir a D02'), findsOneWidget);
    expect(_key('docker_cta_learn'), findsNothing);
  });

  testWidgets('unidad nueva D03: casos del servidor como comandos, decidir y continuar',
      (tester) async {
    final api = await _pump(tester, unit: 'M08-D03-cli', units: const {
      'M08-D01-containers': 'done',
      'M08-D02-lifecycle': 'done',
    });
    expect(find.text('Comandos de Docker (CLI)'), findsWidgets);
    await tester.tap(_key('docker_cta_learn'));
    await tester.pumpAndSettle();
    expect(find.text('\$ docker logs api'), findsOneWidget); // terminal: opciones como comandos
    expect(_key('ds_send'), findsNothing); // sin botón: se corrige al elegir
    await tester.ensureVisible(_key('ds_0_1'));
    await tester.tap(_key('ds_0_1'));
    await tester.pumpAndSettle();
    expect(api.events.last['event_type'], 'selectionChanged');
    await tester.tap(_key('ds_1_0'));
    await tester.pumpAndSettle();
    final ev = api.events.last;
    expect(ev['event_type'], 'evidenceSelected');
    expect(ev['widget_type'], 'DecisionScenarios');
    expect((ev['payload'] as Map)['choices'], [1, 0]);
    expect((ev['payload'] as Map)['unit'], 'M08-D03-cli');
    // El lab dice al momento qué caso revisar (sin revelar la respuesta).
    expect(find.text('Revisa tu respuesta'), findsOneWidget);
    expect(find.textContaining('caso 2'), findsOneWidget);
    await tester.enterText(_key('docker_justification'), 'logs muestra el error; ps lista lo que corre');
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(_key('docker_send')).onPressed, isNotNull);
  });
}
