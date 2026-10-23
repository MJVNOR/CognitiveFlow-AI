import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/ui/tutor/catalog.dart';
import 'package:cognitiveflow/ui/tutor/tutor_surface.dart';

/// Widgets compartidos por varias unidades Docker: la unidad la trae el
/// servidor en los parámetros, no el tipo de widget.
void main() {
  final events = <(String, String, Map<String, Object?>)>[];

  /// Igual que el servidor: `widget_parameters = {title, parameters: {...}}`.
  Future<void> show(WidgetTester tester, String widget, String title,
      Map<String, Object?> params) async {
    events.clear();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: TutorSurface(
      intervention: {
        'activity_id': 'act-1',
        'widget_type': widget,
        'widget_parameters': {'title': title, 'parameters': params},
        'socratic_question': 'Justifica tu decisión',
      },
      onEvent: (w, e, p) => events.add((w, e, p)),
    )))));
    await tester.pumpAndSettle();
  }

  testWidgets('ConfigAudit marca varios elementos y cada cambio es la evidencia',
      (tester) async {
    await show(tester, 'ConfigAudit', 'Marca todo lo que aplica', {
      'subject': 'Dockerfile de la API',
      'items': ['ENV API_KEY=abc123', 'FROM python:3.12-slim', 'sin USER: corre como root'],
    });
    expect(find.text('Dockerfile de la API'), findsOneWidget);
    expect(find.text('1. ENV API_KEY=abc123'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ca_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ca_2')));
    await tester.pump();
    // Sin botón de envío: cada cambio manda la selección completa.
    expect(events.map((e) => e.$2), ['evidenceSelected', 'evidenceSelected']);
    expect(events.last.$3['marked'], [0, 2]);
    await tester.tap(find.byKey(const ValueKey('ca_0'))); // desmarcar
    await tester.pump();
    expect(events.last.$3['marked'], [2]);
  });

  testWidgets('CommandComposer arma el comando y entrega al completar las ranuras',
      (tester) async {
    await show(tester, 'CommandComposer', 'Arma el comando', {
      'prefix': 'docker run -d',
      'slots': [
        {'label': 'red', 'options': ['--network app-net', '--network host']},
        {'label': 'publicación', 'options': ['(sin esa opción)', '-p 8000:8000']},
      ],
    });
    expect(find.text('red'), findsOneWidget);
    expect(find.text('\$ docker run -d'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cc_0_0')));
    await tester.pump();
    expect(events.single.$2, 'selectionChanged'); // incompleta: se corrige, no entrega
    expect(find.text('\$ docker run -d --network app-net'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cc_1_0')));
    await tester.pump();
    expect(events.last.$2, 'evidenceSelected');
    expect(events.last.$3['slots'], [0, 0]);
    // La opción entre paréntesis no se concatena al comando.
    expect(find.text('\$ docker run -d --network app-net'), findsOneWidget);
  });

  testWidgets('ImageContainerLifecycle usa los estados del servidor cuando vienen',
      (tester) async {
    await show(tester, 'ImageContainerLifecycle', 'Predice y comprueba', {
      'context': 'Red bridge por defecto.',
      'stages': ['docker run -d --name api app', 'worker: curl http://api:8000'],
      'states': ['api corriendo, sin red propia', null],
      'ask_index': 1,
      'ask_stage': 'worker: curl http://api:8000',
      'options': ['responde 200', 'falla: el nombre no se resuelve'],
    });
    expect(find.textContaining('¿qué pasa en el paso 2'), findsOneWidget);
    expect(find.text('falla: el nombre no se resuelve'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('icl_pred_falla: el nombre no se resuelve')));
    await tester.pump();
    expect(events.last.$3['prediction'], 'falla: el nombre no se resuelve');
    await tester.tap(find.byKey(const ValueKey('icl_next')));
    await tester.pumpAndSettle();
    expect(find.textContaining('api corriendo, sin red propia'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('icl_next')));
    await tester.pumpAndSettle();
    // El estado del paso predicho no viaja: lo explica la corrección del servidor.
    expect(find.textContaining('compara con la corrección'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('los widgets compartidos caben en 390 px con texto ${scale}x',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final (widget, params) in [
        ('ConfigAudit', {
          'subject': 'docker run -d --privileged -v /var/run/docker.sock:/var/run/docker.sock',
          'items': ['--privileged', 'montar el socket de un daemon rootful del host'],
        }),
        ('CommandComposer', {
          'prefix': 'docker run -d',
          'slots': [
            {'label': 'secreto', 'options': ['-v ./secrets/db:/run/secrets/db:ro',
                                             '-e DB_PASSWORD=1234']},
          ],
        }),
      ]) {
        events.clear();
        await tester.pumpWidget(MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TutorSurface(intervention: {
            'activity_id': 'act-$widget',
            'widget_type': widget,
            'widget_parameters': {'title': 'T', 'parameters': params},
            'socratic_question': 'Justifica',
          }))),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$widget con texto ${scale}x');
      }
    });
  }

  testWidgets('los dos widgets nuevos están en el catálogo activo', (tester) async {
    expect(cognitiveFlowWidgets.containsAll({'ConfigAudit', 'CommandComposer'}), isTrue);
    expect(cognitiveFlowCatalog.map((c) => c.name),
        containsAll(<String>['ConfigAudit', 'CommandComposer']));
  });

  tearDown(() => TutorEvents.emit = null);
}
