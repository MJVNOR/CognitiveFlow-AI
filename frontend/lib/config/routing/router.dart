// Router recreado al cambiar auth (sin refreshListenable: el watch basta).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_state.dart';
import '../../domain/models/models.dart';
import '../../ui/academy/academy_page.dart';
import '../../ui/academy/view_models/academy_viewmodel.dart';
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
          builder: (c, s) => LabRoute(
            labId: s.pathParameters['labId']!,
            extra: s.extra as Map? ?? const {},
            unit: s.uri.queryParameters['unit'],
          ),
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

/// Ruta de lab: `extra` es el atajo desde academia/progreso; en deep link
/// no lo hay, así que tipo y título salen del servidor.
class LabRoute extends ConsumerWidget {
  const LabRoute({super.key, required this.labId, this.extra = const {}, this.unit});
  final String labId;
  final Map extra;

  /// Unidad del temario (Docker Academy): `/labs/lab-docker?unit=M08-D02-lifecycle`.
  final String? unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labsListViewModelProvider);
    final labs = switch (state) {
      AsyncData(:final value) => value,
      _ => null,
    };
    Lab? lab;
    for (final l in labs ?? const <Lab>[]) {
      if (l.id == labId) {
        lab = l;
        break;
      }
    }
    final type = extra['lab_type'] as String? ?? lab?.labType;
    final title = (extra['title'] ?? lab?.title ?? labId) as String;
    if (type == null && state is AsyncLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return switch (type) {
      'data_detective' => DataLabPage(labId: labId, title: title),
      'model_monitoring' => MonitorLabPage(labId: labId, title: title),
      'docker' => DockerLabPage(labId: labId, title: title, unit: unit),
      _ => LabDetailPage(labId: labId, title: title),
    };
  }
}
