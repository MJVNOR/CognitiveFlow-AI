// Estado global con Riverpod (auth + theme). Lo local de labs sigue en setState.
// ponytail: globals api* solo como semilla pre-runApp + lectura HTTP;
// toda mutación pasa por AuthNotifier (un solo punto). Upgrade: pasar token
// vía ref a los fetch helpers y borrar los globals.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

String? apiToken;
String? apiRole; // student|instructor (lo dice /auth/login y /auth/me)
String? apiUserId;

/// Lee prefs antes del runApp (evita flash logged-out → login).
Future<({AuthState? auth, ThemeMode theme})> loadInitialState() async {
  final prefs = await SharedPreferences.getInstance();
  apiToken = prefs.getString('apiToken');
  apiUserId = prefs.getString('apiUserId');
  apiRole = prefs.getString('apiRole');
  final auth = apiToken == null
      ? null
      : AuthState(
          token: apiToken!,
          userId: apiUserId ?? '',
          role: apiRole ?? 'student',
        );
  final theme = switch (prefs.getString('themeMode')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  return (auth: auth, theme: theme);
}

@immutable
class AuthState {
  final String token;
  final String userId;
  final String role;
  const AuthState({required this.token, required this.userId, required this.role});
  bool get isStudent => role == 'student';
}

class AuthNotifier extends Notifier<AuthState?> {
  final AuthState? initial;
  AuthNotifier([this.initial]);

  @override
  AuthState? build() => initial;

  Future<void> login(String token, String userId, String role) async {
    apiToken = token;
    apiUserId = userId;
    apiRole = role;
    state = AuthState(token: token, userId: userId, role: role);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiToken', token);
    await prefs.setString('apiUserId', userId);
    await prefs.setString('apiRole', role);
  }

  Future<void> logout() async {
    apiToken = null;
    apiUserId = null;
    apiRole = null;
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiToken');
    await prefs.remove('apiUserId');
    await prefs.remove('apiRole');
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState?>(AuthNotifier.new);

class ThemeNotifier extends Notifier<ThemeMode> {
  final ThemeMode initial;
  ThemeNotifier([this.initial = ThemeMode.system]);

  @override
  ThemeMode build() => initial;

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', state == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

// Borradores por lab (sobreviven a salir del lab; se limpian al cerrar sesión).
// ponytail: SharedPreferences directo, sin provider (I/O puntual, no estado
// reactivo). Techo: una instancia por llamada; cachear si hay >20 campos.
String _draftKey(String labId, String field) => 'draft:$labId:$field';

Future<String?> loadDraft(String labId, String field) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_draftKey(labId, field));
}

Future<void> saveDraft(String labId, String field, String value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_draftKey(labId, field), value);
}

Future<void> clearDrafts(String labId, List<String> fields) async {
  final prefs = await SharedPreferences.getInstance();
  for (final f in fields) {
    await prefs.remove(_draftKey(labId, f));
  }
}
