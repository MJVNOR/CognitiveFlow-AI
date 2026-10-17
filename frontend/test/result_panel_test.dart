import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/widgets/cards.dart';
import 'package:cognitiveflow/features/ml_lab_page.dart';
import 'package:cognitiveflow/features/data_lab_page.dart';
import 'package:cognitiveflow/session/lab_session.dart';

void main() {
  test('criterionLabel traduce ids Jev', () {
    expect(criterionLabel('exactitud'), 'Exactitud conceptual');
    expect(criterionLabel('evidencia'), 'Uso de evidencia');
    expect(criterionLabel('causal'), 'Causalidad');
    expect(criterionLabel('alternativas'), 'Alternativas');
    expect(criterionLabel('metacognicion'), 'Revisión');
    expect(criterionLabel('otro'), 'otro');
  });

  testWidgets('pending muestra motivo y reintento, sin nota', (tester) async {
    final lab = LabSession()
      ..evalResult = {
        'evaluator': 'jev',
        'status': 'pending',
        'reason': 'Jev 429: transitorio, reintentable',
        'criteria': [],
      };
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultPanel(lab: lab, onNext: () {}, onRetry: () => retried = true),
        ),
      ),
    );
    // flutter_animate deja un timer (fadeIn 250ms); drenarlo o el test falla.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Evaluación Jev pendiente'), findsOneWidget);
    expect(find.textContaining('No es una nota'), findsOneWidget);
    await tester.tap(find.text(Strings.retry));
    expect(retried, isTrue);
  });

  testWidgets('evaluado muestra fortaleza y etiquetas humanas', (tester) async {
    final lab = LabSession()
      ..evalResult = {
        'evaluator': 'jev',
        'status': 'evaluated',
        'criteria': [
          {'id': 'exactitud', 'score': 4},
          {'id': 'evidencia', 'score': 0},
        ],
      };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultPanel(lab: lab, onNext: () {}, onRetry: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Evaluación Jev'), findsOneWidget);
    expect(find.text('Exactitud conceptual · 4'), findsOneWidget);
    expect(
        find.text('Fortaleza: Exactitud conceptual · A trabajar: Uso de evidencia'),
        findsOneWidget);
    expect(find.textContaining('exactitud ·'), findsNothing);
  });

  testWidgets('historial del tutor colapsable con proveedor', (tester) async {
    final lab = LabSession()
      ..evalResult = {
        'evaluator': 'mock',
        'status': 'evaluated',
        'criteria': [
          {'id': 'exactitud', 'score': 2},
        ],
      }
      ..tutorHistory = [
        {'question': '¿Qué curva?', 'provider': 'mock'},
        {'question': '¿Y el ruido?', 'provider': 'gemini'},
      ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultPanel(lab: lab, onNext: () {}, onRetry: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Preguntas del tutor (2)'), findsOneWidget);
    expect(find.text('¿Qué curva?'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tutor_history')));
    await tester.pump();
    expect(find.text('¿Qué curva?'), findsOneWidget);
    expect(find.text('¿Y el ruido?'), findsOneWidget);
  });

  testWidgets('sin historial no hay panel', (tester) async {
    final lab = LabSession()
      ..evalResult = {
        'evaluator': 'mock',
        'status': 'evaluated',
        'criteria': [
          {'id': 'exactitud', 'score': 2},
        ],
      };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultPanel(lab: lab, onNext: () {}, onRetry: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('tutor_history')), findsNothing);
  });

  test('pasos con lenguaje de estudiante, sin jerga de orquestador', () {
    expect(labStepLabels, hasLength(4));
    for (final l in labStepLabels) {
      expect(['Explorar', 'Evaluar', 'Intervenir', 'Postest'], isNot(contains(l)));
    }
  });

  testWidgets('siguiente actividad con título real de la intervención', (tester) async {
    final lab = LabSession()
      ..socraticQ = '¿Qué curva cambió?'
      ..intervention = {
        'widget_type': 'EvidenceComparison',
        'widget_parameters': {'title': 'Compara ambas curvas'},
      };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultPanel(lab: lab, onNext: () {}, onRetry: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Continuar: Compara ambas curvas'), findsOneWidget);
    expect(find.text('Siguiente actividad'), findsNothing);
  });

  testWidgets('ConceptPrimer muestra concepto y ejemplo colapsable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConceptPrimer(objective: const {
            'title': 'T',
            'concept_summary': 'resumen',
            'worked_example_steps': ['paso 1', 'paso 2'],
          }),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('El concepto en 1 minuto'), findsOneWidget);
    expect(find.text('resumen'), findsOneWidget);
    expect(find.text('paso 1'), findsNothing);
    await tester.tap(find.text('Ver ejemplo resuelto'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('paso 1'), findsOneWidget);
  });

  test('cleanedPreview simula convertir, imputar y eliminar', () {
    final rows = [
      {'id': 0, 'temp': 20.0, 'unit': 'C', 'pressure': 101.0},
      {'id': 7, 'temp': 77.0, 'unit': 'F', 'pressure': 101.0},
      {'id': 3, 'temp': 20.0, 'unit': 'C', 'pressure': null},
      {'id': 9, 'temp': 21.0, 'unit': 'C', 'pressure': 102.0},
    ];
    final pv = cleanedPreview(rows, {7, 3, 9}, const {},
        const {'7': 'convertir', '3': 'imputar', '9': 'eliminar'});
    expect(pv.removed, 1);
    expect(pv.converted, 2);
    expect(pv.rows.length, 3);
    final r7 = pv.rows.firstWhere((m) => m['id'] == 7);
    expect(r7['unit'], 'C*');
    expect((r7['temp'] as num).toStringAsFixed(1), '25.0');
    final r3 = pv.rows.firstWhere((m) => m['id'] == 3);
    expect(r3['pressure'], isNotNull);
    // filas no marcadas pasan intactas
    expect(pv.rows.any((m) => m['id'] == 0), isTrue);
  });

  testWidgets('AccessibleCurveChart muestra corrida guardada', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccessibleCurveChart(
            train: [0.5, 0.4],
            val: [0.5, 0.6],
            val2: [0.5, 0.55],
            label: 'Curvas',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Corrida guardada (línea punteada)'), findsOneWidget);
  });

  test('sessionMeta resume ruta y ayudas en lenguaje estudiante', () {
    final lab = LabSession()
      ..level = 'needs_foundation'
      ..assistance = {'hints': 1, 'socratic': 0, 'interventions': 2};
    expect(sessionMeta(lab), 'Ruta: base guiada · Ayudas usadas: 3');
    expect(sessionMeta(LabSession()), isNull);
    expect(sessionMeta(LabSession()..level = 'pending'), isNull);
    expect(levelLabel('autonomous_challenge'), 'desafío autónomo');
  });
}
