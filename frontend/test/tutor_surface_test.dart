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
  testWidgets('EvidenceComparison emite selección y argumento', (tester) async {    final got = <List>[];
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

  // PR-07 P5: exploradores emiten selección y justificación.
  testWidgets('DataTableExplorer valida filas y emite hallazgo', (tester) async {
    final got = <List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(
            intervention: {
              'widget_type': 'DataTableExplorer',
              'widget_parameters': {
                'title': 'T',
                'parameters': {'n_rows': 30},
              },
              'socratic_question': '¿Qué filas?',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('dte_flags')), '999');
    await tester.pump();
    expect(find.textContaining('Ids 0..29'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('dte_flags')), '3, 7');
    await tester.enterText(
        find.byKey(const ValueKey('dte_argument')), 'duplicado y outlier');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dte_send')));
    await tester.pump();
    expect(
        got.any((g) =>
            g[0] == 'DataTableExplorer' &&
            g[1] == 'evidenceSelected' &&
            (g[2] as Map)['flags'].join(',') == '3,7'),
        isTrue);
    expect(got.any((g) => g[1] == 'argumentSubmitted'), isTrue);
  });

  testWidgets('DriftDistributionExplorer emite feature y diagnóstico',
      (tester) async {
    final got = <List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(
            intervention: {
              'widget_type': 'DriftDistributionExplorer',
              'widget_parameters': {
                'title': 'T',
                'parameters': {
                  'features': ['temp', 'pressure']
                },
              },
              'socratic_question': '¿Qué cambió?',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dde_feat_temp')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('dde_argument')), 'deriva en temp');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dde_send')));
    await tester.pump();
    expect(
        got.any((g) =>
            g[0] == 'DriftDistributionExplorer' &&
            g[1] == 'evidenceSelected' &&
            (g[2] as Map)['feature'] == 'temp'),
        isTrue);
    expect(got.any((g) => g[1] == 'argumentSubmitted'), isTrue);
  });

  // Sprint 3: widgets Docker MVP emiten evidencia real.
  testWidgets('ContainerVsVmExplorer clasifica y emite', (tester) async {
    final got = <List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(
            intervention: {
              'widget_type': 'ContainerVsVmExplorer',
              'widget_parameters': {'title': 'T'},
              'socratic_question': '¿Contenedor o VM?',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('¿Contenedor o VM?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cve_c_0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cve_v_1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cve_c_2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cve_send')));
    await tester.pump();
    expect(
        got.any((g) =>
            g[0] == 'ContainerVsVmExplorer' &&
            g[1] == 'evidenceSelected' &&
            (g[2] as Map)['choices'].join(',') == '0,1,0'),
        isTrue);
  });

  testWidgets('ImageContainerLifecycle completa el ciclo', (tester) async {
    final got = <List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(
            intervention: {
              'widget_type': 'ImageContainerLifecycle',
              'widget_parameters': {'title': 'T'},
              'socratic_question': 'Avanza el ciclo',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('icl_next')));
      await tester.pump();
    }
    expect(
        got.any((g) =>
            g[0] == 'ImageContainerLifecycle' &&
            g[1] == 'evidenceSelected' &&
            (g[2] as Map)['completed'] == true),
        isTrue);
  });

  testWidgets('DockerfileWorkbench reordena y emite', (tester) async {
    final got = <List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(
            intervention: {
              'widget_type': 'DockerfileWorkbench',
              'widget_parameters': {'title': 'T'},
              'socratic_question': 'Ordena',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dw_up_1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dw_send')));
    await tester.pump();
    expect(
        got.any((g) =>
            g[0] == 'DockerfileWorkbench' &&
            g[1] == 'evidenceSelected' &&
            ((g[2] as Map)['order'] as List).length == 4),
        isTrue);
  });

  testWidgets('PersistenceExperiment predice y observa', (tester) async {
    final got = <List>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(
            intervention: {
              'widget_type': 'PersistenceExperiment',
              'widget_parameters': {'title': 'T'},
              'socratic_question': '¿Sobrevive?',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pe_mount_1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pe_pred_survive')));
    await tester.pump();
    expect(
        got.any((g) =>
            g[0] == 'PersistenceExperiment' &&
            g[1] == 'predictionSubmitted' &&
            (g[2] as Map)['predicted'] == true),
        isTrue);
    await tester.tap(find.byKey(const ValueKey('pe_write')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pe_recreate')));
    await tester.pump();
    expect(find.textContaining('sobrevivió'), findsOneWidget);
    expect(
        got.any((g) =>
            g[0] == 'PersistenceExperiment' &&
            g[1] == 'evidenceSelected' &&
            (g[2] as Map)['observed'] == true &&
            (g[2] as Map)['match'] == true),
        isTrue);
  });

  test('interventionToComponent: forma A2UI estable por widget', () {
    for (final name in cognitiveFlowWidgets) {
      final c = interventionToComponent({
        'widget_type': name,
        'widget_parameters': {'title': 'T'},
        'socratic_question': 'q',
      });
      expect(c['id'], 'root');
      expect(c['component'], name);
    }
    final unknown = interventionToComponent({
      'widget_type': 'NoExiste',
      'widget_parameters': {'title': 'T'},
      'socratic_question': 'q',
    });
    expect(unknown['component'], 'SocraticQuestionCard');
  });
}
