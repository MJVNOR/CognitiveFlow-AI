import 'package:cognitiveflow/ui/labs/widgets/concept_figure.dart';
import 'package:cognitiveflow/ui/labs/widgets/concept_primer.dart';
import 'package:cognitiveflow/ui/labs/widgets/lab_figures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 900, Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(
      body: SelectionArea(
        child: SingleChildScrollView(
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('la figura D01 muestra las dos variantes y sus leyendas',
      (tester) async {
    final figure = labFigures['M08-D01-containers']!;
    expect(figure.variants.length, 2);
    await tester.pumpWidget(_host(ConceptFigure(figure: figure)));
    await tester.pump();

    expect(find.text(figure.title), findsOneWidget);
    for (final variant in figure.variants) {
      expect(find.text(variant.caption), findsOneWidget);
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                '${variant.asset}-light.png'),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('en móvil las variantes se apilan sin desbordar', (tester) async {
    final figure = labFigures['M08-D01-containers']!;
    await tester.pumpWidget(_host(ConceptFigure(figure: figure), width: 360));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(figure.variants.last.caption), findsOneWidget);
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('en escritorio las variantes van lado a lado', (tester) async {
    final figure = labFigures['M08-D01-containers']!;
    await tester.pumpWidget(_host(ConceptFigure(figure: figure), width: 700));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Row), findsOneWidget);
  });

  testWidgets('en tema oscuro usa el raster oscuro', (tester) async {
    final figure = labFigures['M08-D01-containers']!;
    await tester.pumpWidget(
        _host(ConceptFigure(figure: figure), brightness: Brightness.dark));
    await tester.pump();
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.endsWith('-dark.png')),
      findsNWidgets(figure.variants.length),
    );
  });

  testWidgets('ConceptPrimer incluye la figura de su objetivo', (tester) async {
    await tester.pumpWidget(_host(ConceptPrimer(objective: {
      'id': 'M08-D01-containers',
      'title': 'Contenedor vs VM',
      'concept_summary': 'Un contenedor comparte el kernel del host.',
      'worked_example_steps': ['Paso uno', 'Paso dos'],
    })));
    await tester.pump();
    expect(find.byType(ConceptFigure), findsOneWidget);
    expect(find.text('Un contenedor comparte el kernel del host.'), findsOneWidget);
  });

  testWidgets('ConceptPrimer sin figura no rompe', (tester) async {
    await tester.pumpWidget(_host(ConceptPrimer(objective: {
      'id': 'M08-D99-inexistente',
      'title': 'Otro',
      'concept_summary': 'Sin figura.',
    })));
    await tester.pump();
    expect(find.byType(ConceptFigure), findsNothing);
    expect(find.text('Sin figura.'), findsOneWidget);
  });

  test('cada figura del mapa tiene su PNG claro y oscuro', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final entry in labFigures.entries) {
      for (final variant in entry.value.variants) {
        for (final theme in ['light', 'dark']) {
          final data = await rootBundle.load('${variant.asset}-$theme.png');
          expect(data.lengthInBytes, greaterThan(1000),
              reason: '${variant.asset}-$theme.png (${entry.key})');
        }
        expect(variant.caption.trim(), isNotEmpty, reason: entry.key);
        expect(variant.alt.trim(), isNotEmpty, reason: entry.key);
      }
    }
  });
}
