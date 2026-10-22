import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/ui/tutor/tutor_surface.dart';
import 'package:cognitiveflow/ui/labs/widgets/concept_primer.dart';
import 'package:cognitiveflow/ui/labs/widgets/hist_chart.dart';
import 'package:cognitiveflow/ui/core/widgets/chrome.dart';
import 'package:cognitiveflow/ui/labs/workspace/learning_studio.dart';

// Sprint 5: accesibilidad, teclado, responsive y densidad (pantallas similares
// a screenshots, sin red).
void main() {
  testWidgets('viewport angosto no desborda concepto ni cabecera', (tester) async {
    tester.view.physicalSize = const Size(380, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const StudioHeader(
                crumbs: [('Academia', null), ('Módulo M03', null), ('Curvas', null)],
                title: 'Objetivo largo de prueba para móvil',
                missionLabel: 'Misión 1 de 5 · Predice antes de experimentar',
                done: 1,
                total: 5,
              ),
              ConceptPrimer(objective: const {
                'title': 'Título del concepto con texto suficiente',
                'concept_summary': 'Resumen con varias palabras para forzar el ajuste.',
                'worked_example_steps': ['paso 1', 'paso 2'],
              }),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('zoom de texto 1.3x no oculta la acción principal', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: MaterialApp(
          home: Scaffold(
            body: TutorSurface(intervention: {
              'widget_type': 'EvidenceComparison',
              'widget_parameters': {'title': 'T'},
              'socratic_question': '¿Qué curva?',
            }),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('¿Qué curva?'), findsOneWidget);
  });

  testWidgets('teclado: Tab mueve el foco entre campos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(intervention: {
            'widget_type': 'DataTableExplorer',
            'widget_parameters': {
              'title': 'T',
              'parameters': {'n_rows': 30},
            },
            'socratic_question': '¿Qué filas?',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dte_flags')));
    await tester.pump();
    tester.testTextInput.enterText('3');
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    tester.testTextInput.enterText('duplicado');
    await tester.pump();
    expect(find.text('duplicado'), findsOneWidget);
    expect(find.text('3duplicado'), findsNothing);
  });

  testWidgets('tablas de datos con filas táctiles 44px', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccessibleHistChart(
            ref: [1, 2, 3],
            cur: [1, 2, 3],
            bins: [40.0, 45.0, 50.0],
            label: 'H',
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ver datos como tabla'));
    await tester.pump(const Duration(milliseconds: 300));
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.dataRowMinHeight, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cabecera de vista anuncia encabezado a lector de pantalla',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DoubleTitleBar(title: 'ML Experiment Lab', backRoute: '/labs'),
        ),
      ),
    );
    expect(
        tester.getSemantics(find.text('ML Experiment Lab')),
        matchesSemantics(
            label: 'ML Experiment Lab', isHeader: true, hasTapAction: false));
  });

  testWidgets('botón principal mide al menos 44px de alto', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorSurface(intervention: {
            'widget_type': 'EvidenceComparison',
            'widget_parameters': {'title': 'T'},
            'socratic_question': '¿Qué curva?',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ec_val')));
    await tester.pump();
    await tester.enterText(
        find.byKey(const ValueKey('ec_argument')), 'la validación se despega');
    await tester.pump();
    final size = tester.getSize(find.byKey(const ValueKey('ec_send')));
    expect(size.height, greaterThanOrEqualTo(44));
  });
}
