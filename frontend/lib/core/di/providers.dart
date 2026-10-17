// DI: providers de Data para los ViewModels (MVVM).
// Los repositorios son clases inyectables; aquí viven los defaults.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/instructor_repository.dart';
import '../../data/repositories/lab_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../data/services/api_client.dart';
import '../../utils/storage/drafts.dart';

final apiClientProvider = Provider<ApiClient>((ref) => defaultApiClient);

final authRepositoryProvider = Provider<AuthRepository>(
    (ref) => AuthRepository(api: ref.watch(apiClientProvider)));

final labRepositoryProvider = Provider<LabRepository>(
    (ref) => LabRepository(api: ref.watch(apiClientProvider)));

final progressRepositoryProvider = Provider<ProgressRepository>(
    (ref) => ProgressRepository(api: ref.watch(apiClientProvider)));

final instructorRepositoryProvider = Provider<InstructorRepository>(
    (ref) => InstructorRepository(api: ref.watch(apiClientProvider)));

final sessionRepositoryProvider = Provider<SessionRepository>(
    (ref) => SessionRepository(api: ref.watch(apiClientProvider)));

final draftsRepositoryProvider =
    Provider<DraftsRepository>((ref) => const DraftsRepository());
