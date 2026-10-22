// Instrumentos del taller: el valor del cuadrante nunca sale de rango y la
// lámina no desborda en móvil. El texto (no la aguja) lleva la información.
import 'package:cognitiveflow/ui/core/widgets/bench_plate.dart';
import 'package:cognitiveflow/ui/core/widgets/dial_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 700}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

void main() {
  testWidgets('el cuadrante recorta el valor y publica su etiqueta',
      (tester) async {
    for (final v in [-2.0, 0.0, 0.37, 4.0, double.nan]) {
      await tester.pumpWidget(_host(DialGauge(
        value: v,
        readout: '1/4',
        semanticLabel: 'Avance: 1 de 4 laboratorios terminados.',
      )));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(tester.takeException(), isNull);
      expect(find.text('1/4'), findsOneWidget);
      expect(find.bySemanticsLabel('Avance: 1 de 4 laboratorios terminados.'),
          findsOneWidget);
    }
  });

  testWidgets('la lámina muestra código y título sin desbordar en móvil',
      (tester) async {
    await tester.pumpWidget(_host(
      BenchPlate(
        code: 'M08-D01',
        title: 'El concepto en 1 minuto',
        note: 'LÁMINA',
        child: const Text('Contenido'),
      ),
      width: 320,
    ));
    await tester.pump();
    expect(find.text('M08-D01'), findsOneWidget);
    expect(find.text('El concepto en 1 minuto'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el sello de dominio es texto, no un icono', (tester) async {
    await tester.pumpWidget(_host(const MasteryStamp(
      text: 'DOMINIO DEMOSTRADO',
    )));
    await tester.pump();
    expect(find.text('DOMINIO DEMOSTRADO'), findsOneWidget);
  });
}
