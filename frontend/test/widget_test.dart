import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/main.dart';
import 'package:cognitiveflow/state/app_state.dart';

Future<void> _pump(WidgetTester tester, AuthState? auth) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => AuthNotifier(auth)),
      ],
      child: const CognitiveFlowApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin auth muestra login', (tester) async {
    await _pump(tester, null);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('estudiante no ve tab Instructor', (tester) async {
    await _pump(
      tester,
      const AuthState(token: 'test-token', userId: 's1', role: 'student'),
    );
    expect(find.text('Academia'), findsOneWidget);
    expect(find.text('Instructor'), findsNothing);
  });

  testWidgets('instructor sí ve tab Instructor', (tester) async {
    await _pump(
      tester,
      const AuthState(token: 'test-token', userId: 'i1', role: 'instructor'),
    );
    expect(find.text('Academia'), findsOneWidget);
    expect(find.text('Instructor'), findsOneWidget);
  });
}
