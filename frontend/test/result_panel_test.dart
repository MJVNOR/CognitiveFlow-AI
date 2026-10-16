import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/main.dart';

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
}
