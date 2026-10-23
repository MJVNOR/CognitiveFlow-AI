// Escenarios públicos reales, exportados con uv desde app.labs_docker.activity.
// Sin respuestas en el fixture; la verdad permanece en el servidor.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';
import 'package:cognitiveflow/ui/labs/docker/docker_units.dart';
import 'package:cognitiveflow/ui/tutor/tutor_surface.dart';

void main() {
  final cases = jsonDecode(File('test/fixtures/docker_activities.json').readAsStringSync()) as Map;
  for (final unit in dockerUnits) {
    testWidgets('${unit.code}: escenario real completo en móvil con texto 200%', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final activity = cases[unit.id] as Map;
      await tester.pumpWidget(MaterialApp(
        theme: buildCognitiveLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: SelectionArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: TutorSurface(intervention: {
            'widget_type': dockerUnitWidget(unit.id).widget,
            'widget_parameters': {'title': unit.title, 'parameters': activity},
            'socratic_question': 'Pregunta del tutor separada de la consigna',
          }),
        ))),
      ));
      await tester.pumpAndSettle();
      expect(find.text(activity['instruction'] as String), findsOneWidget);
      expect(find.text('Pregunta del tutor separada de la consigna'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
