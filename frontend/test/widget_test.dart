import 'package:flutter_test/flutter_test.dart';
import 'package:cognitiveflow/main.dart';

void main() {
  testWidgets('login primero, luego 4 tabs', (tester) async {
    apiToken = null;
    await tester.pumpWidget(const CognitiveFlowApp());
    expect(find.text('Entrar'), findsOneWidget);

    apiToken = 'test-token';
    await tester.pumpWidget(const CognitiveFlowApp());
    expect(find.text('Academia'), findsOneWidget);
    expect(find.text('Instructor'), findsOneWidget);
    apiToken = null;
  });
}
