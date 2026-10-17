// ViewModel de login (MVVM): UI state inmutable + comando login.
// La View solo observa y llama; el repo hace el fetch.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/di/providers.dart';
import '../../../data/repositories/auth_repository.dart';

class LoginUiState {
  final bool busy;
  final String status;
  const LoginUiState({this.busy = false, this.status = ''});

  LoginUiState copyWith({bool? busy, String? status}) =>
      LoginUiState(busy: busy ?? this.busy, status: status ?? this.status);
}

class LoginViewModel extends Notifier<LoginUiState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  LoginUiState build() => const LoginUiState();

  /// Retorna true si entró (la View navega y setea auth).
  Future<Credentials?> login(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(status: 'Escribe tu user_id demo (p. ej. s1).');
      return null;
    }
    if (state.busy) return null;
    state = state.copyWith(busy: true, status: '');
    try {
      final creds = await _repo.login(trimmed);
      await ref.read(authProvider.notifier).login(creds.token, creds.userId, creds.role);
      state = state.copyWith(busy: false);
      return creds;
    } catch (e) {
      final msg = '$e';
      state = state.copyWith(
        busy: false,
        status: msg.contains('usuario desconocido')
            ? 'No se pudo entrar: usuario desconocido (usa s1-s4 o i1).'
            : 'No se pudo entrar: sin conexión con la API. Reintenta.',
      );
      return null;
    }
  }
}

final loginViewModelProvider =
    NotifierProvider<LoginViewModel, LoginUiState>(LoginViewModel.new);
