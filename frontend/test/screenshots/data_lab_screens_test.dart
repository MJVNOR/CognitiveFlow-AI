// Capturas PNG de Data Detective (desktop/tablet/móvil) con fuentes reales.
// Solo corre a demanda:
//   flutter test test/screenshots --dart-define=SHOTS=<dir absoluto>
// Sin SHOTS se salta (no ensucia `flutter test`).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';
import 'package:cognitiveflow/ui/labs/data_lab_page.dart';

import '../ui/labs/fake_data_lab_api.dart';

const _dir = String.fromEnvironment('SHOTS');

Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final fonts = '$sdk/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular', 'roboto-medium', 'roboto-bold', 'roboto-italic']) {
    roboto.addFont(File('$fonts/$f.ttf').readAsBytes().then(ByteData.sublistView));
  }
  await roboto.load();
  // Estilos sin familia (p. ej. chipTheme) usan la fuente por defecto del test.
  final fallback = FontLoader('FlutterTest')
    ..addFont(File('$fonts/roboto-regular.ttf').readAsBytes().then(ByteData.sublistView));
  await fallback.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(File('$fonts/materialicons-regular.otf')
        .readAsBytes()
        .then(ByteData.sublistView));
  await icons.load();
}

Future<void> _shot(WidgetTester tester, String name, Size size,
    {FakeStage stage = FakeStage.fresh,
    Future<void> Function(WidgetTester)? act,
    Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final key = GlobalKey();
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(FakeDataLabApi(stage))],
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildCognitiveLightTheme(),
        home: const DataLabPage(labId: 'lab-data', title: 'Data Detective'),
      ),
    ),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 400));
  }
  if (act != null) await act(tester);
  // Dos pumps: flutter_animate arranca en el frame siguiente al cambio de key.
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await boundary.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
  await tester.pumpWidget(const SizedBox());
}

void main() {
  final skip = _dir.isEmpty;
  setUpAll(() async {
    if (!skip) await _loadFonts();
  });
  tearDown(() {});

  testWidgets('capturas Data Detective', (tester) async {
    addTearDown(tester.view.reset);
    await _shot(tester, 'desktop_fresh', const Size(1440, 900));
    await _shot(tester, 'tablet_fresh', const Size(900, 1100));
    await _shot(tester, 'mobile_fresh', const Size(390, 844));
    await _shot(tester, 'desktop_inspect', const Size(1440, 900), act: (t) async {
      await t.tap(find.byKey(const ValueKey('scene_sensor_temp')));
      await t.pump(const Duration(milliseconds: 300));
      await t.ensureVisible(find.byKey(const ValueKey('datarow_7')));
      await t.tap(find.byKey(const ValueKey('datarow_7')));
      await t.pump(const Duration(milliseconds: 300));
    });
    await _shot(tester, 'desktop_detect', const Size(1440, 900),
        prefs: {
          'draft:lab-data:hypothesis': 'Puede haber unidades mezcladas y lecturas imposibles',
          'draft:lab-data:mission_max': '1',
          'draft:lab-data:flagged': '7',
          'draft:lab-data:cellmap': '{"types":{"7":"unit"},"actions":{}}',
        }, act: (t) async {
      await t.tap(find.byKey(const ValueKey('scene_item_25')));
      await t.pump(const Duration(milliseconds: 300));
      await t.ensureVisible(find.byKey(const ValueKey('inspector_type_outlier')));
      await t.tap(find.byKey(const ValueKey('inspector_type_outlier')));
      await t.pump(const Duration(milliseconds: 300));
      await t.ensureVisible(find.byKey(const ValueKey('inspector_25')));
    });
    await _shot(tester, 'mobile_detect', const Size(390, 844),
        prefs: {
          'draft:lab-data:hypothesis': 'Unidades mezcladas',
          'draft:lab-data:mission_max': '1',
        }, act: (t) async {
      await t.tap(find.byKey(const ValueKey('tutor_fold')));
      await t.pump(const Duration(milliseconds: 400));
    });
    await _shot(tester, 'desktop_evaluated', const Size(1440, 900),
        stage: FakeStage.evaluated);
    await _shot(tester, 'desktop_intervention', const Size(1440, 900),
        stage: FakeStage.intervention);
    await _shot(tester, 'desktop_posttest', const Size(1440, 900),
        stage: FakeStage.posttest);
  }, skip: skip);
}
