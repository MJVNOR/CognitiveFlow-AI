import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/main.dart';
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
}
