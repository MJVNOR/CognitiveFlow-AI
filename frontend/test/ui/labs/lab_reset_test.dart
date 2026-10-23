// Reiniciar un laboratorio: confirmación, el servidor archiva, se borran los
// borradores locales y se vuelve a la academia para empezar desde cero.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cognitiveflow/core/di/providers.dart';
import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';
import 'package:cognitiveflow/ui/labs/data_lab_page.dart';

import 'fake_data_lab_api.dart';

void main() {
  testWidgets('reiniciar: confirma, archiva en el servidor, borra borradores y vuelve',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'draft:lab-data:hypothesis': 'mi hipótesis',
      'draft:lab-data:mission_max': '2',
      'draft:lab-ml:hypo': 'otro lab: no se toca',
    });
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeDataLabApi();
    final router = GoRouter(initialLocation: '/labs/lab-data', routes: [
      GoRoute(path: '/academy', builder: (c, s) => const Scaffold(body: Text('Academia'))),
      GoRoute(
          path: '/labs/lab-data',
          builder: (c, s) =>
              const Scaffold(body: DataLabPage(labId: 'lab-data', title: 'Data Detective'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(api)],
      child: MaterialApp.router(theme: buildCognitiveLightTheme(), routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('lab_reset')));
    await tester.pumpAndSettle();
    // Cancelar no hace nada.
    await tester.tap(find.byKey(const ValueKey('reset_cancel')));
    await tester.pumpAndSettle();
    expect(api.posts.where((p) => p.endsWith('/reset')), isEmpty);

    await tester.tap(find.byKey(const ValueKey('lab_reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reset_confirm')));
    await tester.pumpAndSettle();
    expect(api.posts, contains('/me/labs/lab-data/reset'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('draft:lab-data:')), isEmpty);
    expect(prefs.getString('draft:lab-ml:hypo'), 'otro lab: no se toca');
    expect(find.text('Academia'), findsOneWidget);
    expect(find.text('Laboratorio reiniciado: empieza desde cero.'), findsOneWidget);
  });
}
