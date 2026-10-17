// ViewModels de academia (MVVM): cargan módulos/labs/estado vía repos.
// Las Views solo observan el AsyncValue y llaman a refresh().
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/repositories/lab_repository.dart';
import '../../../domain/models/models.dart';

class AcademyData {
  final List<Module> modules;
  final List<Lab> labs;
  final Map statusMap;
  const AcademyData({
    required this.modules,
    required this.labs,
    required this.statusMap,
  });
}

class AcademyViewModel extends AsyncNotifier<AcademyData> {
  @override
  Future<AcademyData> build() => load();

  Future<AcademyData> load() async {
    final results = await Future.wait([
      ref.read(labRepositoryProvider).fetchModules(),
      ref.read(labRepositoryProvider).fetchLabs(),
      ref.read(progressRepositoryProvider).fetchLabStatus(),
    ]);
    return AcademyData(
      modules: results[0] as List<Module>,
      labs: results[1] as List<Lab>,
      statusMap: results[2] as Map,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(load);
  }
}

final academyViewModelProvider =
    AsyncNotifierProvider<AcademyViewModel, AcademyData>(AcademyViewModel.new);

class LabsListViewModel extends AsyncNotifier<List<Lab>> {
  LabRepository get _repo => ref.read(labRepositoryProvider);

  @override
  Future<List<Lab>> build() => _repo.fetchLabs();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.fetchLabs());
  }
}

final labsListViewModelProvider =
    AsyncNotifierProvider<LabsListViewModel, List<Lab>>(LabsListViewModel.new);
