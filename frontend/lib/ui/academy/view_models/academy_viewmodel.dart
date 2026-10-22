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

  /// Estado por unidad Docker ({unidad: active|posttest|done}); vacío si falla.
  final Map dockerUnits;
  const AcademyData({
    required this.modules,
    required this.labs,
    required this.statusMap,
    this.dockerUnits = const {},
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
    final labs = results[1] as List<Lab>;
    Map dockerUnits = const {};
    if (labs.any((l) => l.labType == 'docker')) {
      try {
        dockerUnits = await ref.read(labRepositoryProvider).fetchDockerUnits();
      } catch (_) {} // el temario se muestra igual, sin estado por unidad
    }
    return AcademyData(
      modules: results[0] as List<Module>,
      labs: labs,
      statusMap: results[2] as Map,
      dockerUnits: dockerUnits,
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
