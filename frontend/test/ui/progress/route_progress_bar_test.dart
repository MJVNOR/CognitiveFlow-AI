import 'package:cognitiveflow/ui/progress/widgets/route_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: child)),
      ),
    );

double _fillFactor(WidgetTester tester) => tester
    .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
    .widthFactor!;

void main() {
  testWidgets('llena hasta el avance y anuncia el porcentaje final',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const RouteProgressBar(value: 0.5, label: 'Avance: 2 de 4')),
    );
    expect(_fillFactor(tester), 0);
    await tester.pumpAndSettle();
    expect(_fillFactor(tester), closeTo(0.5, 0.001));

    final semantics = tester.getSemantics(find.byType(RouteProgressBar));
    expect(semantics.label, contains('Avance'));
    expect(semantics.value, '50%');
  });

  testWidgets('reajusta sin reiniciar cuando cambia el avance',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const RouteProgressBar(value: 0.25, label: 'Avance')),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _wrap(const RouteProgressBar(value: 0.75, label: 'Avance')),
    );
    expect(_fillFactor(tester), closeTo(0.25, 0.001));
    await tester.pumpAndSettle();
    expect(_fillFactor(tester), closeTo(0.75, 0.001));
  });

  testWidgets('con movimiento reducido muestra el valor sin animar',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const RouteProgressBar(value: 0.5, label: 'Avance'),
        disableAnimations: true,
      ),
    );
    expect(_fillFactor(tester), closeTo(0.5, 0.001));
  });
}
