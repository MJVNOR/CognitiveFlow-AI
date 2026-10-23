import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/main.dart';
import 'package:cognitiveflow/core/auth/auth_state.dart';

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

  testWidgets('estudiante: sin barra lateral ni acceso al panel del instructor',
      (tester) async {
    await _pump(
      tester,
      const AuthState(token: 'test-token', userId: 's1', role: 'student'),
    );
    // La Academia es el punto de partida: no hay pestañas Lab/Progreso.
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const ValueKey('nav_home')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav_instructor')), findsNothing);
    expect(find.byKey(const ValueKey('nav_logout')), findsOneWidget);
  });

  testWidgets('instructor: acceso directo a su panel desde la barra superior',
      (tester) async {
    await _pump(
      tester,
      const AuthState(token: 'test-token', userId: 'i1', role: 'instructor'),
    );
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const ValueKey('nav_instructor')), findsOneWidget);
  });
}
