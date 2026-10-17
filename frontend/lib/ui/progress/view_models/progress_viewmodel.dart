// ViewModel de progreso (MVVM): agrega labs + estado + evidencias + repasos.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../domain/models/models.dart';

class ProgressData {
  final List<Lab> labs;
  final Map statusMap;
  final Map<String, Map> prog;
  final List recalls;
  const ProgressData({
    required this.labs,
    required this.statusMap,
    required this.prog,
    required this.recalls,
  });
}

class ProgressViewModel extends AsyncNotifier<ProgressData> {
  @override
  Future<ProgressData> build() => load();

  Future<ProgressData> load() async {
    final results = await Future.wait([
      ref.read(labRepositoryProvider).fetchLabs(),
      ref.read(progressRepositoryProvider).fetchLabStatus(),
      ref.read(progressRepositoryProvider).fetchProgress(),
      ref.read(progressRepositoryProvider).fetchRecallDue(),
    ]);
    final prog = {
      for (final p in (results[2] as List))
        (p['lab_template_id'] as String): p as Map
    };
    return ProgressData(
      labs: results[0] as List<Lab>,
      statusMap: results[1] as Map,
      prog: prog,
      recalls: results[3] as List,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(load);
  }

  Future<void> markRecallDone(String id) async {
    try {
      await ref.read(progressRepositoryProvider).markRecallDone(id);
    } catch (_) {}
    await refresh();
  }
}

final progressViewModelProvider =
    AsyncNotifierProvider<ProgressViewModel, ProgressData>(
        ProgressViewModel.new);
