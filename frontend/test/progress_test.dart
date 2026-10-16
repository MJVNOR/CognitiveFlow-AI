import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/main.dart';
import 'package:cognitiveflow/session/lab_session.dart';

void main() {
  test('progressLine resume inicial y delta', () {
    expect(progressLine(null, null), isNull);
    expect(progressLine({'a': 2}, null), 'Inicial 2.0/4 · Postest pendiente');
    expect(progressLine(null, {'a': 3}), 'Inicial sin registrar · Postest 3.0/4');
    expect(progressLine({'a': 2, 'b': 2}, {'a': 4, 'b': 2}),
        'Inicial 2.0/4 → Postest 3.0/4 (+1.0)');
    expect(progressLine({'a': 4}, {'a': 1}), 'Inicial 4.0/4 → Postest 1.0/4 (-3.0)');
  });

  testWidgets('reflexión muestra mejora y desafío honestos', (tester) async {
    final lab = LabSession()
      ..done = true
      ..reflectionSummary = {'mejora': 'evidencia', 'desafio': 'causal'};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosttestReflection(lab: lab, labId: 'lab-ml', onUpdate: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mejora observada: Uso de evidencia ✓'), findsOneWidget);
    expect(find.text('Siguiente desafío: Causalidad'), findsOneWidget);
  });

  testWidgets('sin deltas no inventa mejora', (tester) async {
    final lab = LabSession()
      ..done = true
      ..reflectionSummary = {'mejora': null, 'desafio': null};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosttestReflection(lab: lab, labId: 'lab-ml', onUpdate: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Mejora observada'), findsNothing);
    expect(find.textContaining('sin evidencias para comparar'), findsOneWidget);
  });

  testWidgets('feedback con texto muestra tarjeta Tu avance', (tester) async {
    final lab = LabSession()
      ..evalResult = {
        'evaluator': 'gemini',
        'status': 'evaluated',
        'criteria': [
          {'id': 'exactitud', 'score': 4},
        ],
      }
      ..socraticQ = '¿Qué curva?'
      ..feedback = {
        'fortaleza': 'exactitud',
        'brecha': 'evidencia',
        'texto': 'Vas bien en exactitud; cita las curvas.',
        'provider': 'gemini',
      };
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultPanel(lab: lab, onNext: () {}, onRetry: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tu avance'), findsOneWidget);
    expect(find.text('Vas bien en exactitud; cita las curvas.'), findsOneWidget);
  });

  testWidgets('feedback mock sin texto no duplica el resumen', (tester) async {
    final lab = LabSession()
      ..evalResult = {
        'evaluator': 'mock',
        'status': 'evaluated',
        'criteria': [
          {'id': 'exactitud', 'score': 2},
        ],
      }
      ..feedback = {'fortaleza': 'exactitud', 'brecha': null, 'texto': null};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultPanel(lab: lab, onNext: () {}, onRetry: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tu avance'), findsNothing);
  });
}
