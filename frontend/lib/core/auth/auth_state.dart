// Auth global con Riverpod. Lo local de labs sigue en setState.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/services/api_client.dart';

/// Lee prefs antes del runApp (evita flash logged-out → login).
Future<({AuthState? auth, ThemeMode theme})> loadInitialState() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('apiToken');
  final userId = prefs.getString('apiUserId');
  final role = prefs.getString('apiRole');
  defaultApiClient.setToken(token);
  final auth = token == null
      ? null
      : AuthState(
          token: token,
          userId: userId ?? '',
          role: role ?? 'student',
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
    defaultApiClient.setToken(token);
    state = AuthState(token: token, userId: userId, role: role);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiToken', token);
    await prefs.setString('apiUserId', userId);
    await prefs.setString('apiRole', role);
  }

  Future<void> logout() async {
    defaultApiClient.setToken(null);
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiToken');
    await prefs.remove('apiUserId');
    await prefs.remove('apiRole');
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState?>(AuthNotifier.new);
