import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/main.dart';

void main() {
  testWidgets('login y luego tabs con go_router', (tester) async {
    apiToken = null;
    apiRole = null;
    authRefresh.value++;
    router.go('/login');
    await tester.pumpWidget(const CognitiveFlowApp());
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsOneWidget);

    apiToken = 'test-token';
    apiRole = 'student';
    authRefresh.value++;
    router.go('/academy');
    await tester.pumpWidget(const CognitiveFlowApp());
    await tester.pumpAndSettle();
    expect(find.text('Academia'), findsOneWidget);
    expect(find.text('Instructor'), findsOneWidget);
    apiToken = null;
    apiRole = null;
  });
}
