import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';

import 'package:cognitiveflow/genui/catalog.dart';

CatalogItemContext _ctx(Map data) => CatalogItemContext(
      data: data,
      id: 'root',
      type: 'test',
      buildChild: (id, [dc]) => const SizedBox(),
      dispatchEvent: (_) {},
      buildContext: MockBuildContext(),
      dataContext: DataContext(InMemoryDataModel(), DataPath.root),
      getComponent: (_) => null,
      getCatalogItem: (_) => null,
      surfaceId: 's',
      reportError: (_, _) {},
    );

// BuildContext mínimo para builders que piden Theme (se reemplaza al pumpear).
class MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('catálogo cubre el subconjunto del backend', () {
    final names = cognitiveFlowCatalog.map((c) => c.name).toSet();
    expect(names, cognitiveFlowWidgets);
  });

  test('exampleData es JSON con root', () {
    for (final item in cognitiveFlowCatalog) {
      for (final ex in item.exampleData) {
        final list = jsonDecode(ex()) as List;
        expect(list.any((c) => (c as Map)['id'] == 'root'), isTrue);
      }
    }
  });

  testWidgets('builders renderizan strings', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              socraticQuestionCard.widgetBuilder(_ctx({
                'title': 'T',
                'question': '¿Qué observas?',
              })),
            ],
          ),
        ),
      ),
    );
    expect(find.text('¿Qué observas?'), findsOneWidget);
    // flutter_animate deja un timer (fadeIn 250ms); drenarlo o el test falla.
    await tester.pump(const Duration(milliseconds: 300));
  });
}
