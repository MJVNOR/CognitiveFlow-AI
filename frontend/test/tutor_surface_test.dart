import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/genui/catalog.dart';
import 'package:cognitiveflow/genui/tutor_surface.dart';

void main() {
  tearDown(() => TutorEvents.emit = null);
  testWidgets('intervención se renderiza vía Surface GenUI', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(intervention: {
            'widget_type': 'SocraticQuestionCard',
            'widget_parameters': {'title': 'T'},
            'socratic_question': '¿Qué observas en validación?',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Qué observas en validación?'), findsOneWidget);
  });

  // E4: los 12 del CATALOG backend existen y renderizan su pregunta.
  for (final name in cognitiveFlowWidgets) {
    testWidgets('$name renderiza su pregunta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutorSurface(intervention: {
              'widget_type': name,
              'widget_parameters': {'title': 'T'},
              'socratic_question': 'pregunta $name',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('pregunta $name'), findsOneWidget);
    });
  }

  // PR-02 P1.5: los widgets emiten eventos hacia el backend.
  testWidgets('EvidenceComparison emite selección y argumento', (tester) async {
    final got = <List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(
            intervention: {
              'widget_type': 'EvidenceComparison',
              'widget_parameters': {'title': 'T'},
              'socratic_question': '¿Qué curva?',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ec_val')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('ec_argument')), 'la validación se despega');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ec_send')));
    await tester.pump();
    expect(
        got.any((g) =>
            g[0] == 'EvidenceComparison' &&
            g[1] == 'evidenceSelected' &&
            (g[2] as Map)['selection'] == 'val'),
        isTrue);
    expect(
        got.any((g) =>
            g[0] == 'EvidenceComparison' && g[1] == 'argumentSubmitted'),
        isTrue);
  });

  testWidgets('HypothesisEditor emite hipótesis con revisión', (tester) async {
    final got = <List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(
            intervention: {
              'widget_type': 'HypothesisEditor',
              'widget_parameters': {'title': 'T'},
              'socratic_question': 'hipo inicial',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('he_field')), 'sobreajuste por complejidad');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('he_save')));
    await tester.pump();
    expect(got.length, 1);
    expect(got[0][1], 'hypothesisSubmitted');
    expect((got[0][2] as Map)['revision'], 1);
  });

  testWidgets('LearningCurveSimulator emite predicción', (tester) async {
    final got = <List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(
            intervention: {
              'widget_type': 'LearningCurveSimulator',
              'widget_parameters': {
                'title': 'T',
                'parameters': {
                  'complexity': {'min': 1, 'max': 10, 'initial': 7},
                  'noise_pct': {'min': 0, 'max': 50, 'initial': 20},
                },
              },
              'socratic_question': 'predice',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lcs_send')));
    await tester.pump();
    expect(
        got.any((g) =>
            g[0] == 'LearningCurveSimulator' &&
            g[1] == 'predictionSubmitted' &&
            (g[2] as Map)['complexity'] == 7),
        isTrue);
  });

  // PR-02 P1.6: widget desconocido → fallback accesible, sin crash.
  testWidgets('widget desconocido usa fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(intervention: {
            'widget_type': 'NoExiste',
            'widget_parameters': {'title': 'T'},
            'socratic_question': 'hola',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Actividad no disponible'), findsOneWidget);
    expect(find.text('hola'), findsOneWidget);
  });
}
