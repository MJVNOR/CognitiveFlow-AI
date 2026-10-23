// ViewModels de instructor (MVVM, solo lectura).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../domain/models/models.dart';

class InstructorData {
  final List<Student> students;
  final Map<String, String> labTitles;
  final Map<String, Map> matrix;

  /// Telemetría del planificador GenUI por tipo de lab (vacío si no cargó).
  final Map<String, dynamic> plannerStats;
  const InstructorData({
    required this.students,
    required this.labTitles,
    required this.matrix,
    this.plannerStats = const {},
  });
}

class InstructorViewModel extends AsyncNotifier<InstructorData> {
  @override
  Future<InstructorData> build() => load();

  Future<InstructorData> load() async {
    final results = await Future.wait<dynamic>([
      ref.read(instructorRepositoryProvider).fetchStudents(),
      ref.read(labRepositoryProvider).fetchLabs(),
      ref.read(instructorRepositoryProvider).fetchMatrix(),
    ]);
    Map<String, dynamic> planner = const {};
    try {
      planner = await ref.read(instructorRepositoryProvider).fetchPlannerStats();
    } catch (_) {} // el panel funciona igual sin la telemetría
    return InstructorData(
      students: results[0] as List<Student>,
      labTitles: {for (final l in (results[1] as List<Lab>)) l.id: l.title},
      matrix: {
        for (final m in (results[2] as List))
          (m['student_id'] as String): m as Map
      },
      plannerStats: planner,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(load);
  }
}

final instructorViewModelProvider =
    AsyncNotifierProvider<InstructorViewModel, InstructorData>(
        InstructorViewModel.new);

class StudentSessionsViewModel extends AsyncNotifier<List<SessionInfo>> {
  StudentSessionsViewModel(this.studentId);
  final String studentId;

  @override
  Future<List<SessionInfo>> build() =>
      ref.read(instructorRepositoryProvider).fetchSessions(studentId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(instructorRepositoryProvider).fetchSessions(studentId));
  }
}

final studentSessionsViewModelProvider = AsyncNotifierProvider.family<
    StudentSessionsViewModel, List<SessionInfo>, String>(
  (studentId) => StudentSessionsViewModel(studentId),
);

class SessionAttemptsViewModel extends AsyncNotifier<List<Attempt>> {
  SessionAttemptsViewModel(this.sessionId);
  final String sessionId;

  @override
  Future<List<Attempt>> build() =>
      ref.read(instructorRepositoryProvider).fetchAttempts(sessionId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(instructorRepositoryProvider).fetchAttempts(sessionId));
  }
}

final sessionAttemptsViewModelProvider = AsyncNotifierProvider.family<
    SessionAttemptsViewModel, List<Attempt>, String>(
  (sessionId) => SessionAttemptsViewModel(sessionId),
);
