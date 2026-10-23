import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/ui/labs/widgets/lab_chrome.dart';
import 'package:cognitiveflow/ui/labs/widgets/concept_primer.dart';
import 'package:cognitiveflow/ui/labs/widgets/curve_chart.dart';
import 'package:cognitiveflow/ui/labs/data/cleaning_preview.dart';
import 'package:cognitiveflow/ui/labs/docker/docker_units.dart';
import 'package:cognitiveflow/ui/labs/view_models/lab_session.dart';
import 'package:cognitiveflow/utils/criteria.dart';

void main() {
  test('criterionLabel traduce ids Jev', () {
    expect(criterionLabel('exactitud'), 'Exactitud conceptual');
    expect(criterionLabel('evidencia'), 'Uso de evidencia');
    expect(criterionLabel('causal'), 'Causalidad');
    expect(criterionLabel('alternativas'), 'Alternativas');
    expect(criterionLabel('metacognicion'), 'Revisión');
    expect(criterionLabel('otro'), 'otro');
  });

  test('criterionExplained dice qué pide el criterio, no solo su nombre', () {
    expect(criterionExplained('alternativas'),
        'Alternativas (decir qué harías en otro caso, o qué opción descartaste y por qué)');
    expect(criterionExplained('metacognicion'), contains('tu predicción inicial'));
    expect(criterionExplained('otro'), 'otro'); // id desconocido: sin inventar significado
  });

  testWidgets('ConceptPrimer muestra concepto, ejemplo resuelto y errores comunes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConceptPrimer(objective: const {
            'title': 'T',
            'concept_summary': 'resumen',
            'worked_example_steps': ['paso 1', 'paso 2'],
            'misconceptions': ['mito'],
          }),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('El concepto en 1 minuto'), findsOneWidget);
    expect(find.text('resumen'), findsOneWidget);
    // A la vista: el tutor y el experimento remiten a ellos.
    expect(find.text('paso 1'), findsOneWidget);
    expect(find.text('Falso: «mito»'), findsOneWidget);
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

  test('dockerUnitWidget cubre las 4 unidades MVP', () {
    expect(dockerUnitWidget('M08-D01-containers').widget, 'ContainerVsVmExplorer');
    expect(dockerUnitWidget('M08-D02-lifecycle').widget, 'ImageContainerLifecycle');
    expect(dockerUnitWidget('M08-D04-dockerfile').widget, 'DockerfileWorkbench');
    expect(dockerUnitWidget('M08-D07-persistence').widget, 'PersistenceExperiment');
    expect(dockerUnitWidget('otra').widget, 'SocraticQuestionCard');
  });
}
