import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/ui/tutor/catalog.dart';
import 'package:cognitiveflow/ui/tutor/tutor_surface.dart';

void main() {
  testWidgets('identidad conserva borrador y reinicia solo para otra actividad', (tester) async {
    Future<void> show(String id) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: TutorSurface(
        intervention: {
          'activity_id': id,
          'widget_type': 'HypothesisEditor',
          'widget_parameters': {'title': 'Mismo tipo y estrategia'},
          'socratic_question': 'Justifica tu hipótesis',
        },
      ))));
      await tester.pumpAndSettle();
    }
    await show('a');
    await tester.enterText(find.byKey(const ValueKey('he_field')), 'Mi borrador');
    await show('a');
    expect(find.text('Mi borrador'), findsOneWidget);
    await show('b');
    expect(find.text('Mi borrador'), findsNothing);
  });

  testWidgets('superficies simultáneas envían a su propia actividad', (tester) async {
    final got = <Map<String, Object?>>[];
    Widget surface(String id) => Expanded(child: TutorSurface(
      key: ValueKey(id),
      intervention: {
        'activity_id': id,
        'widget_type': 'HypothesisEditor',
        'widget_parameters': {'title': id},
        'socratic_question': 'Justifica',
      },
      onEvent: (_, _, payload) => got.add(payload),
    ));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Row(children: [surface('a'), surface('b')]))));
    await tester.pumpAndSettle();
    for (final id in ['a', 'b']) {
      final root = find.byKey(ValueKey(id));
      await tester.enterText(find.descendant(of: root, matching: find.byKey(const ValueKey('he_field'))), 'Razón $id');
      await tester.pump();
      await tester.tap(find.descendant(of: root, matching: find.byKey(const ValueKey('he_save'))));
      await tester.pump();
    }
    expect(got.map((e) => e['activity_id']), ['a', 'b']);
    expect(got.map((e) => e['hypothesis']), ['Razón a', 'Razón b']);
  });

  testWidgets('backlog se consulta como histórico sin controles ficticios', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TutorSurface(intervention: {
      'widget_type': 'SqlQueryWorkbench',
      'widget_parameters': {'title': 'SQL'},
      'socratic_question': 'Consigna histórica',
    }))));
    await tester.pumpAndSettle();
    expect(find.text('Actividad histórica · solo lectura'), findsOneWidget);
    expect(find.text('Consigna histórica'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(cognitiveFlowWidgets.contains('SqlQueryWorkbench'), isFalse);
  });

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

  // E4: todos los del CATALOG backend existen y renderizan su consigna o pregunta.
  for (final name in cognitiveFlowWidgets) {
    testWidgets('$name renderiza su pregunta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TutorSurface(intervention: {
              'widget_type': name,
              'widget_parameters': {'title': 'T', 'parameters': {'instruction': 'consigna $name'}},
              'socratic_question': 'pregunta $name',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const docker = {'ContainerVsVmExplorer', 'ImageContainerLifecycle', 'DockerfileWorkbench', 'PersistenceExperiment', 'DecisionScenarios', 'ConfigAudit', 'CommandComposer'};
      expect(find.text(docker.contains(name) ? 'consigna $name' : 'pregunta $name'), findsOneWidget);
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
    expect(find.textContaining('según los requisitos'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cve_c_0')));
    await tester.pump();
    // Sin botón: cada elección sale al momento; incompleta = selectionChanged.
    expect(got.last[1], 'selectionChanged');
    expect((got.last[2] as Map)['choices'], [0, null, null]);
    await tester.tap(find.byKey(const ValueKey('cve_v_1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cve_c_2')));
    await tester.pump();
    expect(find.byKey(const ValueKey('cve_send')), findsNothing);
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

  testWidgets('D02 separa consigna de pregunta ajena y bloquea predicción tras observar', (tester) async {
    final events = <List>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: TutorSurface(intervention: {
        'widget_type': 'ImageContainerLifecycle',
        'socratic_question': '¿Cómo se ajustan los pesos durante el entrenamiento?',
        'widget_parameters': {'parameters': {
          'instruction': 'Predice y comprueba qué recursos existen.',
          'context': 'Partimos sin imágenes ni contenedores.',
          'stages': ['docker build', 'docker run', 'docker stop', 'docker start'],
          'ask_index': 2,
        }},
      }, onEvent: (w, e, p) => events.add([w, e, p])),
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('pesos'), findsNothing);
    expect(find.text('Predice y comprueba qué recursos existen.'), findsOneWidget);
    final both = find.byKey(const ValueKey('icl_pred_ambos'));
    await tester.tap(both);
    await tester.pump();
    expect(events.last[1], 'selectionChanged');
    expect((events.last[2] as Map)['prediction'], 'ambos');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('icl_next')));
      await tester.pump();
    }
    expect(find.textContaining('Estado observado tras el paso 3'), findsOneWidget);
    expect(find.textContaining('Contenedor: detenido'), findsOneWidget);
    expect(tester.widget<ChoiceChip>(both).onSelected, isNull);
    await tester.tap(find.byKey(const ValueKey('icl_next')));
    await tester.pump();
    expect(find.textContaining('Contenedor: corriendo'), findsOneWidget);
    expect(events.last[1], 'evidenceSelected');
    await tester.tap(find.byKey(const ValueKey('icl_reset')));
    await tester.pump();
    expect(tester.widget<ChoiceChip>(both).selected, isFalse);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('icl_next'))).onPressed, isNull);
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
    await tester.pump(); // cada movimiento se envía solo
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
            g[1] == 'selectionChanged' &&
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

  testWidgets('Docker: el escenario del servidor reemplaza al de ejemplo', (tester) async {
    final got = <List>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TutorSurface(
            intervention: {
              'widget_type': 'ContainerVsVmExplorer',
              'widget_parameters': {
                'title': 'Reto',
                'parameters': {
                  'unit': 'M08-D01-containers',
                  'seed': 4,
                  'scenarios': ['Uno', 'Dos', 'Tres'],
                },
              },
              'socratic_question': 'Clasifica',
            },
            onEvent: (w, e, p) => got.add([w, e, p]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2. Dos'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('cve_c_$i')));
      await tester.pump();
    }
    expect(got.last[1], 'evidenceSelected');
    expect((got.last[2] as Map)['choices'], [0, 0, 0]);
  });

  testWidgets('HypothesisEditor muestra las curvas del escenario nuevo', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TutorSurface(intervention: {
            'widget_type': 'HypothesisEditor',
            'widget_parameters': {
              'title': 'Pon a prueba tu idea',
              'parameters': {
                'complexity': {'min': 1, 'max': 10, 'initial': 9},
                'curve': {
                  'train': [0.6, 0.4, 0.3],
                  'val': [0.6, 0.5, 0.7],
                },
              },
            },
            'socratic_question': '¿Qué cambia con complejidad 9?',
          }),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('he_curve')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Curvas con complejidad 9')), findsOneWidget);
  });
}
