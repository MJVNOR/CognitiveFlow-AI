// Router recreado al cambiar auth (sin refreshListenable: el watch basta).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_state.dart';
import '../../ui/academy/academy_page.dart';
import '../../ui/labs/data_lab_page.dart';
import '../../ui/labs/docker_lab_page.dart';
import '../../ui/instructor/instructor_page.dart';
import '../../ui/auth/login_page.dart';
import '../../ui/labs/ml_lab_page.dart';
import '../../ui/labs/monitor_lab_page.dart';
import '../../ui/progress/progress_page.dart';
import '../../ui/instructor/review_page.dart';
import '../../ui/core/shell.dart';

/// Router recreado al cambiar auth (sin refreshListenable: el watch basta).
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  return GoRouter(
    initialLocation: '/academy',
    redirect: (context, state) {
      final loggingIn = state.matchedLocation == '/login';
      if (auth == null && !loggingIn) return '/login';
      if (auth != null && loggingIn) return '/academy';
      // Guardia de rol: instructor/* solo para instructor.
      if (state.matchedLocation.startsWith('/instructor') &&
          (auth?.isStudent ?? false)) {
        return '/academy';
      }
      return null;
    },
    routes: [
    GoRoute(path: '/login', builder: (c, s) => const SelectionArea(child: LoginPage())),
    ShellRoute(
      builder: (c, s, child) => SelectionArea(child: Shell(location: s.matchedLocation, child: child)),
      routes: [
        GoRoute(path: '/academy', builder: (c, s) => const AcademyPage()),
        GoRoute(path: '/labs', builder: (c, s) => const LabsPage()),
        GoRoute(
          path: '/labs/:labId',
          builder: (c, s) {
            final extra = s.extra as Map? ?? {};
            final title = (extra['title'] ?? s.pathParameters['labId']!) as String;
            return switch (extra['lab_type']) {
              'data_detective' => DataLabPage(labId: s.pathParameters['labId']!, title: title),
              'model_monitoring' =>
                MonitorLabPage(labId: s.pathParameters['labId']!, title: title),
              'docker' => DockerLabPage(labId: s.pathParameters['labId']!, title: title),
              _ => LabDetailPage(labId: s.pathParameters['labId']!, title: title),
            };
          },
        ),
        GoRoute(path: '/progress', builder: (c, s) => const ProgressPage()),
        GoRoute(path: '/instructor', builder: (c, s) => const InstructorPage()),
        GoRoute(
          path: '/instructor/session/:sid',
          builder: (c, s) => SessionReviewPage(sessionId: s.pathParameters['sid']!),
        ),
      ],
    ),
    ],
  );
});
