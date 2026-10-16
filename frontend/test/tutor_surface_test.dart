import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/genui/catalog.dart';
import 'package:cognitiveflow/genui/tutor_surface.dart';

void main() {
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
}
