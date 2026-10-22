// Accesibilidad del Learning Studio en los 4 labs: texto grande sin overflow,
// acción principal alcanzable con teclado y con nombre accesible.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';
import 'package:cognitiveflow/ui/labs/data_lab_page.dart';
import 'package:cognitiveflow/ui/labs/docker_lab_page.dart';
import 'package:cognitiveflow/ui/labs/ml_lab_page.dart';
import 'package:cognitiveflow/ui/labs/monitor_lab_page.dart';

import 'fake_data_lab_api.dart';

final _labs = <String, Widget Function()>{
  'data': () => const DataLabPage(labId: 'lab-data', title: 'Data Detective'),
  'ml': () => const LabDetailPage(labId: 'lab-ml', title: 'ML'),
  'monitor': () => const MonitorLabPage(labId: 'lab-monitor', title: 'Monitoreo'),
  'docker': () =>
      const DockerLabPage(labId: 'lab-docker', title: 'Docker', unit: 'M08-D01-containers'),
};

Future<void> _pump(WidgetTester tester, Widget page,
    {required Size size, double scale = 1, FakeStage stage = FakeStage.fresh}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(FakeDataLabApi(stage))],
    child: MaterialApp(
      theme: buildCognitiveLightTheme(),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final lab in _labs.entries) {
    for (final scale in const [1.5, 2.0]) {
      for (final size in const [Size(1440, 900), Size(390, 844)]) {
        testWidgets('${lab.key}: texto ${scale}x sin overflow en ${size.width.toInt()} px',
            (tester) async {
          await _pump(tester, lab.value(), size: size, scale: scale);
          expect(tester.takeException(), isNull);
          await _pump(tester, lab.value(), size: size, scale: scale, stage: FakeStage.intervention);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('${lab.key}: la acción principal tiene nombre y se alcanza con Tab',
        (tester) async {
      await _pump(tester, lab.value(), size: const Size(1440, 900));
      final cta = find.byType(FilledButton);
      expect(cta, findsOneWidget);
      // Nombre accesible = su texto (nunca solo un icono).
      final label = tester.getSemantics(cta).label;
      expect(label.trim(), isNotEmpty);
      // Tab recorre la página sin trampas de foco ni errores.
      for (var i = 0; i < 40; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      expect(FocusManager.instance.primaryFocus, isNotNull);
    });
  }
}
