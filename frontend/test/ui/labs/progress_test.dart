import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/domain/models/models.dart';
import 'package:cognitiveflow/ui/academy/view_models/academy_viewmodel.dart';
import 'package:cognitiveflow/ui/labs/widgets/reflection.dart';
import 'package:cognitiveflow/ui/labs/workspace/learning_feedback.dart';
import 'package:cognitiveflow/ui/labs/view_models/lab_session.dart';
import 'package:cognitiveflow/utils/criteria.dart';

/// NextLabButton (MVVM) lee labs del provider: en tests se sirve vacío.
class _EmptyLabs extends LabsListViewModel {
  @override
  Future<List<Lab>> build() async => [];
}

Widget _scoped(Widget child) => ProviderScope(
      overrides: [labsListViewModelProvider.overrideWith(_EmptyLabs.new)],
      child: MaterialApp(home: Scaffold(body: child)),
    );

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
      _scoped(PosttestReflection(lab: lab, labId: 'lab-ml', onUpdate: () {})),
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
      _scoped(PosttestReflection(lab: lab, labId: 'lab-ml', onUpdate: () {})),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Mejora observada'), findsNothing);
    expect(find.textContaining('sin evidencias para comparar'), findsOneWidget);
  });

  testWidgets('feedback redactado por Gemini se muestra; números solo bajo demanda',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LearningFeedbackView(
            evalResult: const {
              'evaluator': 'mock',
              'status': 'evaluated',
              'criteria': [
                {'id': 'exactitud', 'score': 4},
                {'id': 'evidencia', 'score': 1},
              ],
            },
            feedback: const {
              'fortaleza': 'exactitud',
              'brecha': 'evidencia',
              'texto': 'Vas bien en exactitud; cita las curvas.',
              'provider': 'gemini',
            },
            nextExperiment: 'Reto elegido: Compara ambas curvas',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vas bien en exactitud; cita las curvas.'), findsOneWidget);
    expect(find.text('4 / 4'), findsNothing);
  });

  testWidgets('feedback mock sin texto no inventa un resumen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LearningFeedbackView(
            evalResult: const {
              'evaluator': 'mock',
              'status': 'evaluated',
              'criteria': [
                {'id': 'exactitud', 'score': 2},
              ],
            },
            feedback: const {'fortaleza': 'exactitud', 'texto': 'Vas bien en exactitud', 'provider': 'mock'},
            nextExperiment: 'x',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vas bien en exactitud'), findsNothing);
  });
}
