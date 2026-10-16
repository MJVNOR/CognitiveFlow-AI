import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'genui/tutor_surface.dart';

const apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

// ponytail: copy centralizado (ES ahora, i18n después); no añadir intl hasta que se pida.
abstract final class Strings {
  static const appTitle = 'CognitiveFlow AI';
  static const loginHint = 'Login demo (s1-s4 estudiante, i1 instructor)';
  static const loginUserId = 'user_id';
  static const loginEnter = 'Entrar';
  static const tabAcademy = 'Academia';
  static const tabLabs = 'Lab';
  static const tabProgress = 'Progreso';
  static const tabInstructor = 'Instructor';
  static const noApi = 'Sin conexión API';
  static const sendAttempt = 'Enviar intento';
  static const deliverPosttest = 'Entregar postest';
  static const retry = 'Reintentar';
  static const goPosttest = 'Ir al postest (tabla nueva, sin ayuda)';
  static const goPosttestNoAI = 'Ir al postest (sin ayuda de IA)';
  static const chartDataTable = 'Ver datos como tabla';
  static const scrollHint = 'Desliza → para ver todas las columnas';
  static const legendTrain = 'Entrenamiento (línea continua)';
  static const legendVal = 'Validación (línea discontinua)';
  static const legendRef = 'Referencia (barra izquierda)';
  static const legendCur = 'Actual (barra derecha)';
  static const simulated = 'Curvas sintéticas (simulación)';
}

String? apiToken;
String? apiRole; // student|instructor (lo dice /auth/login y /auth/me)
String? apiUserId;

/// Tema claro/oscuro (DESIGN.md §3: no invertir mecánicamente).
/// Persistido en SharedPreferences ('themeMode': light|dark|system).
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

Future<void> _restoreTheme() async {
  final prefs = await SharedPreferences.getInstance();
  themeModeNotifier.value = switch (prefs.getString('themeMode')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

Future<void> toggleTheme() async {
  final next = themeModeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  themeModeNotifier.value = next;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('themeMode', next == ThemeMode.dark ? 'dark' : 'light');
}

/// Notifica a GoRouter cuando cambia el estado de auth (login/logout).
final authRefresh = ValueNotifier<int>(0);

Map<String, String> _headers([bool json = false]) => {
      if (apiToken != null) 'Authorization': 'Bearer $apiToken',
      if (json) 'Content-Type': 'application/json',
    };

// Anuncia errores/estados a lectores de pantalla (WCAG 4.1.3).
class StatusText extends StatelessWidget {
  final String status;
  const StatusText(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(status),
      ),
    );
  }
}

Future<void> _persistAuth(String token, String userId, String role) async {
  apiToken = token;
  apiUserId = userId;
  apiRole = role;
  authRefresh.value++;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('apiToken', token);
  await prefs.setString('apiUserId', userId);
  await prefs.setString('apiRole', role);
}

Future<void> _restoreAuth() async {
  final prefs = await SharedPreferences.getInstance();
  apiToken = prefs.getString('apiToken');
  apiUserId = prefs.getString('apiUserId');
  apiRole = prefs.getString('apiRole');
}

Future<void> _clearAuth() async {
  apiToken = null;
  apiUserId = null;
  apiRole = null;
  authRefresh.value++;
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('apiToken');
  await prefs.remove('apiUserId');
  await prefs.remove('apiRole');
}

Future<void> main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  await _restoreAuth();
  await _restoreTheme();
  runApp(const CognitiveFlowApp());
}

final router = GoRouter(
  initialLocation: '/academy',
  refreshListenable: authRefresh,
  redirect: (context, state) {
    final logged = apiToken != null;
    final loggingIn = state.matchedLocation == '/login';
    if (!logged && !loggingIn) return '/login';
    if (logged && loggingIn) return '/academy';
    // Guardia de rol: instructor/* solo para instructor.
    if (state.matchedLocation.startsWith('/instructor') && apiRole == 'student') {
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

abstract final class CognitiveColors {
  static const blue = Color(0xFF2457C5);
  static const teal = Color(0xFF0F766E);
  static const amber = Color(0xFFA65B00);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const ink = Color(0xFF0F172A);
  static const inkSecondary = Color(0xFF475569);
  static const border = Color(0xFFCBD5E1);
  static const blueSoft = Color(0xFFE8EEFF);
  static const tealSoft = Color(0xFFE4F4F0);
  static const amberSoft = Color(0xFFFFF3D6);
  static const error = Color(0xFFB42318);
  static const errorSoft = Color(0xFFFEECEB);
  static const success = Color(0xFF166534);
  static const successSoft = Color(0xFFDCFCE7);
  static const focus = Color(0xFF2457C5);

  // Dark: variantes claras de marca sobre superficies oscuras (WCAG AA).
  // Blanco sobre blue/teal/amber originales pasa en botones, pero como
  // texto/gráfica sobre fondo oscuro no llega a 3:1 → se aclaran.
  static const backgroundDark = Color(0xFF0F172A);
  static const surfaceDark = Color(0xFF1E293B);
  static const surfaceMutedDark = Color(0xFF273549);
  static const inkDark = Color(0xFFF1F5F9);
  static const inkSecondaryDark = Color(0xFFCBD5E1);
  static const borderDark = Color(0xFF334155);
  static const blueDark = Color(0xFF8AA8FF); // 6.36:1 sobre surfaceDark
  static const tealDark = Color(0xFF2DD4BF); // 7.86:1 sobre surfaceDark
  static const amberDark = Color(0xFFFBBF24); // 8.76:1 sobre surfaceDark
  static const blueSoftDark = Color(0xFF1E2F5E);
  static const tealSoftDark = Color(0xFF0B3532);
  static const amberSoftDark = Color(0xFF451A03);
  static const errorDark = Color(0xFFFFB4AB);
  static const errorSoftDark = Color(0xFF5A1510);
  static const successDark = Color(0xFF86EFAC);
  static const successSoftDark = Color(0xFF052E16);
}

ThemeData buildCognitiveLightTheme() {
  const scheme = ColorScheme.light(
    primary: CognitiveColors.blue,
    onPrimary: Colors.white,
    primaryContainer: CognitiveColors.blueSoft,
    onPrimaryContainer: CognitiveColors.blue,
    secondary: CognitiveColors.teal,
    onSecondary: Colors.white,
    secondaryContainer: CognitiveColors.tealSoft,
    onSecondaryContainer: CognitiveColors.teal,
    tertiary: CognitiveColors.amber,
    onTertiary: Colors.white,
    tertiaryContainer: CognitiveColors.amberSoft,
    onTertiaryContainer: CognitiveColors.amber,
    surface: CognitiveColors.surface,
    onSurface: CognitiveColors.ink,
    surfaceContainerHighest: CognitiveColors.surfaceMuted,
    onSurfaceVariant: CognitiveColors.inkSecondary,
    outlineVariant: CognitiveColors.border,
    error: CognitiveColors.error,
    onError: Colors.white,
    errorContainer: CognitiveColors.errorSoft,
    onErrorContainer: CognitiveColors.error,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: CognitiveColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: CognitiveColors.surface,
      foregroundColor: CognitiveColors.ink,
    ),
    cardTheme: CardThemeData(
      color: CognitiveColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CognitiveColors.border),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: CognitiveColors.focus, width: 2),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: CognitiveColors.teal,
      thumbColor: CognitiveColors.teal,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: CognitiveColors.surfaceMuted,
      labelStyle: const TextStyle(color: CognitiveColors.ink),
      side: const BorderSide(color: CognitiveColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerColor: CognitiveColors.border,
  );
}

ThemeData buildCognitiveDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: CognitiveColors.blueDark,
    onPrimary: CognitiveColors.backgroundDark,
    primaryContainer: CognitiveColors.blueSoftDark,
    onPrimaryContainer: CognitiveColors.blueDark,
    secondary: CognitiveColors.tealDark,
    onSecondary: CognitiveColors.backgroundDark,
    secondaryContainer: CognitiveColors.tealSoftDark,
    onSecondaryContainer: CognitiveColors.tealDark,
    tertiary: CognitiveColors.amberDark,
    onTertiary: CognitiveColors.backgroundDark,
    tertiaryContainer: CognitiveColors.amberSoftDark,
    onTertiaryContainer: CognitiveColors.amberDark,
    surface: CognitiveColors.surfaceDark,
    onSurface: CognitiveColors.inkDark,
    surfaceContainerHighest: CognitiveColors.surfaceMutedDark,
    onSurfaceVariant: CognitiveColors.inkSecondaryDark,
    outlineVariant: CognitiveColors.borderDark,
    error: CognitiveColors.errorDark,
    onError: CognitiveColors.backgroundDark,
    errorContainer: CognitiveColors.errorSoftDark,
    onErrorContainer: CognitiveColors.errorDark,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: CognitiveColors.backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: CognitiveColors.surfaceDark,
      foregroundColor: CognitiveColors.inkDark,
    ),
    cardTheme: CardThemeData(
      color: CognitiveColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CognitiveColors.borderDark),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: CognitiveColors.blueDark, width: 2),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: CognitiveColors.tealDark,
      thumbColor: CognitiveColors.tealDark,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: CognitiveColors.surfaceMutedDark,
      labelStyle: const TextStyle(color: CognitiveColors.inkDark),
      side: const BorderSide(color: CognitiveColors.borderDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerColor: CognitiveColors.borderDark,
  );
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (c, mode, _) {
        final dark = mode == ThemeMode.dark ||
            (mode == ThemeMode.system &&
                MediaQuery.platformBrightnessOf(c) == Brightness.dark);
        return IconButton(
          key: const ValueKey('theme_toggle'),
          tooltip: dark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
          icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
          onPressed: toggleTheme,
        );
      },
    );
  }
}

class CognitiveFlowApp extends StatelessWidget {
  const CognitiveFlowApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (c, mode, _) => MaterialApp.router(
        title: Strings.appTitle,
        theme: buildCognitiveLightTheme(),
        darkTheme: buildCognitiveDarkTheme(),
        themeMode: mode,
        routerConfig: router,
      ),
    );
  }
}

// REGLA: todo texto visible es seleccionable. SelectionArea va DENTRO de las
// rutas (bajo el Overlay del Navigator); en MaterialApp.builder revienta
// (No Overlay widget found) porque corre por encima del Navigator.

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  final userId = TextEditingController(text: 's1');
  String status = '';

  Future<void> _login() async {
    try {
      final r = await http.post(
        Uri.parse('$apiBase/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId.text.trim()}),
      );
      if (r.statusCode != 200) throw Exception('${r.statusCode} usuario desconocido');
      final body = jsonDecode(r.body) as Map;
      await _persistAuth(
        body['token'] as String,
        (body['user_id'] ?? userId.text.trim()) as String,
        (body['role'] ?? 'student') as String,
      );
      if (mounted) router.go('/academy');
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(Strings.loginHint),
                TextField(controller: userId, decoration: const InputDecoration(labelText: Strings.loginUserId), onSubmitted: (_) => _login()),
                const SizedBox(height: 12),
                FilledButton(onPressed: _login, child: const Text(Strings.loginEnter)),
                StatusText(status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _shellTabs = ['/academy', '/labs', '/progress', '/instructor'];

class Shell extends StatelessWidget {
  final String location;
  final Widget child;
  const Shell({super.key, required this.location, required this.child});

  int get _index {
    if (location.startsWith('/labs')) return 1;
    if (location.startsWith('/progress')) return 2;
    if (location.startsWith('/instructor')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        void go(int i) => router.go(_shellTabs[i]);
        final rail = NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: go,
          labelType: NavigationRailLabelType.all,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.school), label: Text(Strings.tabAcademy)),
            NavigationRailDestination(icon: Icon(Icons.science), label: Text(Strings.tabLabs)),
            NavigationRailDestination(icon: Icon(Icons.trending_up), label: Text(Strings.tabProgress)),
            NavigationRailDestination(icon: Icon(Icons.person), label: Text(Strings.tabInstructor)),
          ],
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ThemeToggleButton(),
                    IconButton(
                      tooltip: 'Salir',
                      icon: const Icon(Icons.logout),
                      onPressed: () async {
                        await _clearAuth();
                        router.go('/login');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text(Strings.appTitle),
            actions: [
              const ThemeToggleButton(),
              if (!wide)
                IconButton(
                  tooltip: 'Salir',
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await _clearAuth();
                    router.go('/login');
                  },
                ),
            ],
          ),
          body: wide
              ? Row(children: [rail, const VerticalDivider(width: 1), Expanded(child: child)])
              : child,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: go,
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.school), label: Strings.tabAcademy),
                    NavigationDestination(icon: Icon(Icons.science), label: Strings.tabLabs),
                    NavigationDestination(icon: Icon(Icons.trending_up), label: Strings.tabProgress),
                    NavigationDestination(icon: Icon(Icons.person), label: Strings.tabInstructor),
                  ],
                ),
        );
      },
    );
  }
}

Future<List<dynamic>> fetchJson(String path) async {
  final r = await http.get(Uri.parse('$apiBase$path'), headers: _headers());
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as List;
}

Future<Map<String, dynamic>> fetchMap(String path) async {
  final r = await http.get(Uri.parse('$apiBase$path'), headers: _headers());
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
  final r = await http.post(
    Uri.parse('$apiBase$path'),
    headers: _headers(true),
    body: jsonEncode(body),
  );
  if (r.statusCode != 200) throw Exception('${r.statusCode} $path');
  return jsonDecode(r.body) as Map<String, dynamic>;
}

class AcademyPage extends StatefulWidget {
  const AcademyPage({super.key});
  @override
  State<AcademyPage> createState() => _AcademyState();
}

String _labStatusLabel(String? status) => switch (status) {
      'active' => 'En curso',
      'posttest' => 'En postest',
      'done' => 'Completado',
      _ => 'No iniciado',
    };

class _AcademyState extends State<AcademyPage> {
  // ponytail: un solo Future.wait; tres GET en paralelo, un solo spinner.
  late final _future =
      Future.wait([fetchJson('/modules'), fetchJson('/labs'), fetchMap('/me/lab-status')]);

  void _goLab(Map l) => router.go(
        '/labs/${l['id']}',
        extra: {'lab_type': l['lab_type'], 'title': l['title']},
      );

  Widget _labCard(Map l, Map statusMap) {
    final st = statusMap[l['id']] as String?;
    return Card(
      child: ListTile(
        title: Text(l['title']),
        subtitle: Text('${l['description'] ?? ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              avatar: Icon(
                switch (st) {
                  'active' => Icons.play_arrow,
                  'posttest' => Icons.lock_outline,
                  'done' => Icons.check_circle,
                  _ => Icons.circle_outlined,
                },
                size: 14,
              ),
              label: Text(_labStatusLabel(st),
                  style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _goLab(l),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Semantics(
              liveRegion: true,
              child: Text('${Strings.noApi}: ${s.error}'),
            ),
          );
        }
        final modules = s.data![0] as List;
        final labs = s.data![1] as List;
        final statusMap = s.data![2] as Map;
        final orphans = [for (final l in labs) if ((l['module_id'] ?? '') == '') l];
        // Objetivo actual: lo en curso primero, si no lo siguiente sin iniciar.
        Map? current;
        for (final l in labs) {
          if (statusMap[l['id']] == 'active' || statusMap[l['id']] == 'posttest') {
            current = l as Map;
            break;
          }
        }
        current ??= [for (final l in labs) if ((statusMap[l['id']] as String?) == null) l]
            .firstOrNull as Map?;
        final cur = current;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (cur != null) ...[
              SectionCard(
                icon: Icons.track_changes,
                title: 'Tu objetivo actual',
                trailing: Chip(
                  label: Text(_labStatusLabel(statusMap[cur['id']] as String?),
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
                children: [
                  Text('${cur['title']}',
                      style: Theme.of(context).textTheme.titleSmall),
                  if ('${cur['description'] ?? ''}'.isNotEmpty)
                    Text('${cur['description']}'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _goLab(cur),
                    child: const Text('Continuar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            for (final m in modules) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Semantics(
                    header: true,
                    child: Text('${m['title']}',
                        style: Theme.of(context).textTheme.titleMedium)),
              ),
              for (final l in labs)
                if (l['module_id'] == m['id']) _labCard(l, statusMap),
            ],
            if (orphans.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Semantics(
                    header: true,
                    child: Text('Otros',
                        style: Theme.of(context).textTheme.titleMedium)),
              ),
              for (final l in orphans) _labCard(l, statusMap),
            ],
          ],
        );
      },
    );
  }
}

class LabsPage extends StatefulWidget {
  const LabsPage({super.key});
  @override
  State<LabsPage> createState() => _LabsState();
}

class _LabsState extends State<LabsPage> {
  late final _future = fetchJson('/labs');
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Semantics(
              liveRegion: true,
              child: Text('${Strings.noApi}: ${s.error}'),
            ),
          );
        }
        final labs = s.data!;
        return ListView(
          children: [
            for (final l in labs)
              ListTile(
                title: Text(l['title']),
                subtitle: Text(l['lab_type']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => router.go(
                  '/labs/${l['id']}',
                  extra: {'lab_type': l['lab_type'], 'title': l['title']},
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Ciclo compartido de un lab: sesión → intento → evaluar → intervenir → postest.
/// La página envuelve cada llamada en setState (esta clase no notifica sola).
class LabSession {
  String? sessionId;
  String? attemptId;
  Map<String, dynamic>? evalResult;
  String socraticQ = '';
  Map? intervention;
  String status = '';
  bool evaluating = false;
  bool nextBusy = false;
  String? evalError;
  String? nextError;
  bool posttestMode = false;
  bool posttestSent = false;
  bool done = false;

  /// 0 explorar, 1 evaluar, 2 intervenir, 3 postest.
  int get step => (posttestMode || posttestSent || done)
      ? 3
      : intervention != null
          ? 2
          : evalResult != null
              ? 1
              : 0;

  Future<void> init(String labId) async {
    try {
      // ponytail: student_id derived server-side from token (main.py:159); don't send it.
      final s = await postJson('/sessions', {'lab_template_id': labId});
      sessionId = s['id'] as String;
    } catch (e) {
      status = 'Error API: $e';
    }
  }

  Future<void> send(Map<String, dynamic> body, {required bool posttest}) async {
    final path = posttest ? 'posttest' : 'attempts';
    final a = await postJson('/sessions/$sessionId/$path', body);
    attemptId = a['id'] as String;
  }

  /// evaluate y socratic en try separados: si la pregunta falla, la
  /// evaluación se conserva y se puede reintentar solo la pregunta.
  Future<void> evaluate() async {
    evalError = null;
    try {
      evalResult =
          await postJson('/sessions/$sessionId/evaluate', {'attempt_id': attemptId});
    } catch (e) {
      evalError = 'No se pudo evaluar: $e';
      return;
    }
    try {
      final sq =
          await postJson('/sessions/$sessionId/socratic', {'attempt_id': attemptId});
      socraticQ = (sq['question'] ?? '') as String;
    } catch (e) {
      evalError = 'Evaluado ✓, pero la pregunta no llegó: $e';
    }
  }

  Future<void> next() async {
    nextError = null;
    try {
      intervention = await postJson(
          '/sessions/$sessionId/next-intervention', {'attempt_id': attemptId});
    } catch (e) {
      nextError = 'No llegó la actividad: $e';
    }
  }

  Future<void> reflect(String text) async {
    await postJson('/sessions/$sessionId/reflection', {'text': text});
    done = true;
  }
}

const labStepLabels = ['Explorar', 'Evaluar', 'Intervenir', 'Postest'];

/// Pasos del lab (misma cabecera en los 3 labs: así se blendean).
class LabSteps extends StatelessWidget {
  final int current;
  const LabSteps({super.key, required this.current});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < labStepLabels.length; i++) ...[
          if (i > 0) SizedBox(width: 16, child: Divider(color: cs.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  i <= current ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: i <= current ? cs.primary : cs.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  labStepLabels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == current ? FontWeight.bold : null,
                    color: i <= current ? null : cs.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Cabecera común: objetivo del lab + pasos. Va arriba del contenido propio.
class LabHeader extends StatelessWidget {
  final String objective;
  final int step;
  const LabHeader({super.key, required this.objective, required this.step});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(objective, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        LabSteps(current: step),
        const Divider(),
      ],
    );
  }
}

/// Sección reutilizable del ciclo predecir→experimentar→justificar.
/// Un título con icono + cuerpo; el color semántico llega por [accent].
class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? accent;
  final Widget? trailing;
  final List<Widget> children;
  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.accent,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = accent ?? cs.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: ac),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: ac)),
                ),
                if (trailing case final Widget t) t,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Slider de parámetro de laboratorio con etiqueta, valor y ayuda.
/// Teal por defecto (experimentación, DESIGN.md §3); postest usa neutral.
class ParamSlider extends StatelessWidget {
  final String label;
  final String value;
  final String? help;
  final double current;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  const ParamSlider({
    super.key,
    required this.label,
    required this.value,
    required this.current,
    required this.min,
    required this.max,
    required this.divisions,
    this.help,
    this.onChanged,
    this.onChangeEnd,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Chip(
              label: Text(value, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        Slider(
          value: current,
          min: min,
          max: max,
          divisions: divisions,
          label: value,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        if (help != null)
          Text(help!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Botón al siguiente lab de la ruta (por order_index). Nada que enlazar → texto.
class NextLabButton extends StatefulWidget {
  final String labId;
  const NextLabButton(this.labId, {super.key});
  @override
  State<NextLabButton> createState() => _NextLabButtonState();
}

class _NextLabButtonState extends State<NextLabButton> {
  late final _future = fetchJson('/labs');
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, s) {
        if (!s.hasData) return const SizedBox.shrink();
        final labs = s.data!;
        final i = labs.indexWhere((l) => l['id'] == widget.labId);
        if (i < 0 || i + 1 >= labs.length) {
          return const Text('Último lab de la ruta ✓');
        }
        final n = labs[i + 1];
        return FilledButton.tonal(
          onPressed: () => router.go(
            '/labs/${n['id']}',
            extra: {'lab_type': n['lab_type'], 'title': n['title']},
          ),
          child: Text('Siguiente lab: ${n['title']}'),
        );
      },
    );
  }
}

/// Reflexión de cierre + done + enlace al siguiente lab (postest unificado).
class PosttestReflection extends StatefulWidget {
  final LabSession lab;
  final String labId;
  final VoidCallback onUpdate;
  const PosttestReflection(
      {super.key, required this.lab, required this.labId, required this.onUpdate});
  @override
  State<PosttestReflection> createState() => _PosttestReflectionState();
}

class _PosttestReflectionState extends State<PosttestReflection> {
  final reflection = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    reflection.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => busy = true);
    try {
      await widget.lab.reflect(reflection.text);
    } catch (e) {
      widget.lab.status = 'Error: $e';
    }
    setState(() => busy = false);
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lab.done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: reflection,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reflexión: ¿qué aprendiste?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : _send,
            child: const Text('Enviar reflexión y cerrar'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sesión cerrada. Gracias por tu reflexión.'),
        const SizedBox(height: 8),
        NextLabButton(widget.labId),
      ],
    );
  }
}

/// Panel compartido: evaluación + socrática + siguiente intervención GenUI.
/// Siempre visible tras el primer envío, con estados (nunca vacío silencioso).
class ResultPanel extends StatelessWidget {
  final LabSession lab;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  const ResultPanel({
    super.key,
    required this.lab,
    required this.onNext,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lab.evaluating)
          const Row(
            children: [
              SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Evaluando…'),
            ],
          ),
        if (lab.evalError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(lab.evalError!, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
        ],
        if (lab.evalResult != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                label: Text(
                  'Evaluación: ${lab.evalResult!['evaluator']}',
                  style: const TextStyle(fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
              ),
              for (final c in (lab.evalResult!['criteria'] as List))
                Chip(
                  avatar: Icon(
                    (c['score'] as num) >= 2
                        ? Icons.check_circle
                        : Icons.error_outline,
                    size: 16,
                  ),
                  label: Text('${c['id']} · ${c['score']}',
                      style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Evidencia orientativa, revisable por tu instructor.',
            style: TextStyle(fontSize: 12),
          ),
        ],
        if (lab.socraticQ.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              border: Border.all(color: cs.tertiary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline,
                        size: 16, color: cs.onTertiaryContainer),
                    const SizedBox(width: 6),
                    Text('¿Qué evidencia respalda tu hipótesis?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onTertiaryContainer)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Tutor: ${lab.socraticQ}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: lab.nextBusy ? null : onNext,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const SizedBox(
                width: double.infinity,
                child: Text('Siguiente actividad', textAlign: TextAlign.center)),
          ),
          const Text('La evaluación es evidencia; la actividad sigue con el tutor.',
              style: TextStyle(fontSize: 12)),
        ] else if (lab.evalResult != null && !lab.evaluating && lab.evalError == null) ...[
          const SizedBox(height: 8),
          FilledButton.tonal(
              onPressed: null, child: const Text('Siguiente actividad')),
          const Text('Esperando la pregunta del tutor…',
              style: TextStyle(fontSize: 12)),
        ],
        if (lab.nextBusy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Trayendo actividad…'),
              ],
            ),
          ),
        if (lab.nextError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(lab.nextError!, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(onPressed: onNext, child: const Text(Strings.retry)),
        ],
        if (lab.intervention != null) ...[
          const SizedBox(height: 8),
          TutorSurface(intervention: lab.intervention!),
        ],
      ],
    );
  }
}

// G1: tabla sintética, marcar anomalías, justificar, postest con tabla nueva.
class DataLabPage extends StatefulWidget {
  final String labId;
  final String title;
  const DataLabPage({super.key, required this.labId, required this.title});
  @override
  State<DataLabPage> createState() => _DataLabState();
}

class _DataLabState extends State<DataLabPage> {
  final lab = LabSession();
  List columns = [];
  List rows = [];
  final flagged = <int>{};
  final justification = TextEditingController();

  int get seed => lab.posttestMode ? 99 : 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await lab.init(widget.labId);
    if (lab.sessionId == null) {
      setState(() {});
      return;
    }
    await _loadTable();
  }

  Future<void> _loadTable() async {
    try {
      final ds = await fetchMap('/labs/${widget.labId}/dataset?seed=$seed');
      setState(() {
        columns = ds['columns'] as List;
        rows = ds['rows'] as List;
        flagged.clear();
      });
    } catch (e) {
      setState(() => lab.status = 'Error tabla: $e');
    }
  }

  Future<void> _send() async {
    if (lab.sessionId == null || lab.evaluating) return;
    if (justification.text.trim().isEmpty) {
      setState(() => lab.status = 'La justificación es obligatoria');
      return;
    }
    setState(() {
      lab.evaluating = true;
      lab.status = '';
    });
    try {
      await lab.send({
        'seed': seed,
        'flags': flagged.toList(),
        'answer_text': justification.text,
      }, posttest: lab.posttestMode);
      setState(() {
        lab.evaluating = false;
        if (lab.posttestMode) {
          lab.posttestSent = true;
          lab.status = 'Postest entregado (sin ayuda)';
        } else {
          lab.status = 'Guardado ✓';
        }
      });
      if (!lab.posttestMode) {
        await lab.evaluate();
        setState(() {});
      }
    } catch (e) {
      setState(() {
        lab.evaluating = false;
        lab.status = 'Error envío: $e';
      });
    }
  }

  Future<void> _retry() async {
    setState(() => lab.evaluating = true);
    await lab.evaluate();
    setState(() => lab.evaluating = false);
  }

  Future<void> _next() async {
    setState(() => lab.nextBusy = true);
    await lab.next();
    setState(() => lab.nextBusy = false);
  }

  final scrollCtrl = ScrollController();
  final hCtrl = ScrollController();

  @override
  void dispose() {
    justification.dispose();
    scrollCtrl.dispose();
    hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(lab.posttestMode ? '${widget.title} (postest)' : widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(16),
            controller: scrollCtrl,
            children: [
              LabHeader(
                objective: lab.posttestMode
                    ? 'Tabla nueva, sin ayuda. Marca anomalías y justifica.'
                    : 'Marca las filas con anomalías y justifica tu plan de limpieza.',
                step: lab.step,
              ),
              const SizedBox(height: 8),
              const Text(Strings.scrollHint, style: TextStyle(fontSize: 12)),
              if (columns.isEmpty && lab.status.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (columns.isNotEmpty)
              Scrollbar(
                controller: hCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: hCtrl,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: true,
                    // ponytail: filas ≥44px (WCAG 2.5.8).
                    dataRowMinHeight: 44,
                    columns: [for (final c in columns) DataColumn(label: Text('$c'))],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          selected: flagged.contains(r['id']),
                          onSelectChanged: (_) => setState(() {
                            flagged.contains(r['id'])
                                ? flagged.remove(r['id'])
                                : flagged.add(r['id'] as int);
                          }),
                          cells: [for (final c in columns) DataCell(Text('${r['$c'] ?? '—'}'))],
                        ),
                    ],
                  ),
                ),
              ),
          TextField(
            controller: justification,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Justificación y plan de limpieza *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: lab.evaluating ? null : _send,
            child: Text(lab.posttestMode ? Strings.deliverPosttest : Strings.sendAttempt),
          ),
          if (!lab.posttestMode)
            TextButton(
              onPressed: lab.sessionId == null
                  ? null
                  : () => setState(() {
                        lab.posttestMode = true;
                        lab.evalResult = null;
                        lab.intervention = null;
                        lab.socraticQ = '';
                        _loadTable();
                      }),
              child: const Text(Strings.goPosttest),
            ),
          if (!lab.posttestMode)
            ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
          if (lab.posttestMode && lab.posttestSent)
            PosttestReflection(
                lab: lab, labId: widget.labId, onUpdate: () => setState(() {})),
          StatusText(lab.status),
            ],
          ),
        ),
      ),
    );
  }
}

class LabDetailPage extends StatefulWidget {
  final String labId;
  final String title;
  const LabDetailPage({super.key, required this.labId, required this.title});
  @override
  State<LabDetailPage> createState() => _LabDetailState();
}

class _LabDetailState extends State<LabDetailPage> {
  final lab = LabSession();
  double complexity = 5;
  double noise = 20;
  final hypo = TextEditingController();
  Map<String, dynamic>? curve;

  int get seed => lab.posttestMode ? 99 : 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await lab.init(widget.labId);
    if (lab.sessionId == null) {
      setState(() {});
      return;
    }
    await _loadCurve();
  }

  Future<void> _loadCurve() async {
    try {
      final c = await fetchMap(
        '/labs/${widget.labId}/curve?complexity=${complexity.round()}&noise_pct=${noise.round()}&seed=$seed',
      );
      setState(() => curve = c);
    } catch (e) {
      setState(() => lab.status = 'Error curva: $e');
    }
  }

  Future<void> _send() async {
    if (lab.sessionId == null || lab.evaluating) return;
    if (hypo.text.trim().isEmpty) {
      setState(() => lab.status =
          lab.posttestMode ? 'El diagnóstico es obligatorio' : 'La hipótesis es obligatoria');
      return;
    }
    setState(() {
      lab.evaluating = true;
      lab.status = '';
    });
    try {
      await lab.send({
        'complexity': complexity.round(),
        'noise_pct': noise.round(),
        'seed': seed,
        'answer_text': hypo.text,
      }, posttest: lab.posttestMode);
      setState(() {
        lab.evaluating = false;
        if (lab.posttestMode) {
          lab.posttestSent = true;
          lab.status = 'Postest entregado (sin ayuda de IA)';
        } else {
          lab.status = 'Guardado ✓ (simulación, sin IA)';
        }
      });
      if (!lab.posttestMode) {
        await lab.evaluate();
        setState(() {});
      }
    } catch (e) {
      setState(() {
        lab.evaluating = false;
        lab.status = 'Error envío: $e';
      });
    }
  }

  Future<void> _retry() async {
    setState(() => lab.evaluating = true);
    await lab.evaluate();
    setState(() => lab.evaluating = false);
  }

  Future<void> _next() async {
    setState(() => lab.nextBusy = true);
    await lab.next();
    setState(() => lab.nextBusy = false);
  }

  @override
  void dispose() {
    hypo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final train = (curve?['train'] as List?)?.cast<num>() ?? [];
    final val = (curve?['val'] as List?)?.cast<num>() ?? [];
    final sent = lab.posttestSent;
    final cs = Theme.of(context).colorScheme;
    final experimentAccent =
        lab.posttestMode ? null : cs.secondary;
    final controls = [
      LabHeader(
        objective: lab.posttestMode
            ? 'Variante nueva. Sin pistas ni tutor hasta entregar.'
            : 'Predice el efecto de la complejidad y justifica por qué',
        step: lab.step,
      ),
      const SizedBox(height: 12),
      if (lab.posttestMode)
        Card(
          color: cs.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Modo postest — sin pistas, sin tutor, sin evaluación hasta entregar.',
                  ),
                ),
              ],
            ),
          ),
        ),
      if (lab.posttestMode) const SizedBox(height: 12),
      SectionCard(
        icon: Icons.science,
        title: '1 · Experimenta con las curvas',
        accent: experimentAccent,
        trailing: curve?['simulated'] == true
            ? const Chip(
                label: Text(Strings.simulated,
                    style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              )
            : null,
        children: [
          AccessibleCurveChart(
            train: train,
            val: val,
            height: 220,
            label: lab.posttestMode ? 'Curvas del postest' : 'Curvas de pérdida',
          ),
          const SizedBox(height: 12),
          ParamSlider(
            label: 'Complejidad del modelo',
            value: '${complexity.round()} / 10',
            help: 'Sube la complejidad y mira cuándo la validación se despega.',
            current: complexity,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: sent ? null : (v) => setState(() => complexity = v),
            onChangeEnd: sent ? null : (_) => _loadCurve(),
          ),
          ParamSlider(
            label: 'Ruido en los datos',
            value: '${noise.round()} %',
            help: 'Más ruido → ambas curvas más altas e inestables.',
            current: noise,
            min: 0,
            max: 50,
            divisions: 10,
            onChanged: sent ? null : (v) => setState(() => noise = v),
            onChangeEnd: sent ? null : (_) => _loadCurve(),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SectionCard(
        icon: Icons.edit_note,
        title: '2 · Predice y justifica',
        accent: lab.posttestMode ? null : cs.tertiary,
        children: [
          TextField(
            controller: hypo,
            maxLines: 4,
            minLines: 3,
            enabled: !sent,
            decoration: InputDecoration(
              labelText: lab.posttestMode
                  ? 'Tu diagnóstico y justificación *'
                  : 'Hipótesis / justificación (obligatoria)',
              helperText: lab.posttestMode
                  ? 'Cita ambas curvas y tu decisión.'
                  : 'Predice qué pasa al subir la complejidad y cita las dos curvas.',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!sent)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                onPressed: lab.evaluating ? null : _send,
                child: Text(lab.posttestMode
                    ? Strings.deliverPosttest
                    : Strings.sendAttempt),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
    ];
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!lab.posttestMode)
          TextButton(
            onPressed: lab.sessionId == null
                ? null
                : () => setState(() {
                      lab.posttestMode = true;
                      lab.evalResult = null;
                      lab.intervention = null;
                      lab.socraticQ = '';
                      _loadCurve();
                    }),
            child: const Text(Strings.goPosttestNoAI),
          ),
        if (!lab.posttestMode &&
            (lab.evalResult != null ||
                lab.evaluating ||
                lab.evalError != null ||
                lab.intervention != null))
          SectionCard(
            icon: Icons.fact_check,
            title: '3 · Evidencia y siguiente paso',
            children: [
              ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
            ],
          ),
        if (!lab.posttestMode &&
            lab.evalResult == null &&
            !lab.evaluating &&
            lab.evalError == null &&
            lab.intervention == null)
          ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
        if (lab.posttestMode && sent)
          PosttestReflection(
              lab: lab, labId: widget.labId, onUpdate: () => setState(() {})),
        StatusText(lab.status),
      ],
    );
    return Scaffold(
      appBar: AppBar(
          title: Text(lab.posttestMode ? '${widget.title} (postest)' : widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1024) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ListView(padding: const EdgeInsets.all(16), children: controls)),
                    SizedBox(
                      width: (constraints.maxWidth * 0.35).clamp(320.0, 420.0),
                      child: ListView(padding: const EdgeInsets.all(16), children: [result]),
                    ),
                  ],
                );
              }
              return ListView(padding: const EdgeInsets.all(16), children: [...controls, result]);
            },
          ),
        ),
      ),
    );
  }
}

/// Curva de entrenamiento (continua) vs validación (discontinua).
/// Colores desde el tema — nunca hard-coded — para modo claro/oscuro y
/// diferenciación por estilo además de color (WCAG 1.4.1).
class CurvePainter extends StatelessWidget {
  final List<num> train;
  final List<num> val;
  final Color trainColor;
  final Color valColor;
  const CurvePainter(this.train, this.val,
      {super.key, required this.trainColor, required this.valColor});

  List<FlSpot> _spots(List<num> ys) => [
        for (var i = 0; i < ys.length; i++)
          FlSpot(i.toDouble(), ys[i].toDouble().clamp(0, 1)),
      ];

  @override
  Widget build(BuildContext context) {
    if (train.isEmpty && val.isEmpty) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 5,
              getTitlesWidget: (v, _) => Text(
                'e${v.toInt()}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          if (train.isNotEmpty)
            LineChartBarData(
              spots: _spots(train),
              isCurved: false,
              color: trainColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          if (val.isNotEmpty)
            LineChartBarData(
              spots: _spots(val),
              isCurved: false,
              color: valColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
        ],
      ),
    );
  }
}

/// Gráfico de curvas con alternativa textual (WCAG 1.1.1) y leyenda sin
/// nombres de color.
// ponytail: sin animaciones propias; solo transiciones M3 por defecto
// (ExpansionTile, navegación), ninguna bloquea tareas ni transmite
// información solo por movimiento.
class AccessibleCurveChart extends StatelessWidget {
  final List<num> train;
  final List<num> val;
  final String label;
  final double height;
  const AccessibleCurveChart({super.key, required this.train, required this.val, required this.label, this.height = 180});

  String _summary(List<num> ys) {
    if (ys.isEmpty) return 'sin datos';
    final min = ys.reduce((a, b) => a < b ? a : b);
    final max = ys.reduce((a, b) => a > b ? a : b);
    return '${ys.length} puntos, mín ${min.toStringAsFixed(2)}, máx ${max.toStringAsFixed(2)}, '
        'último ${ys.last.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$label. Entrenamiento: ${_summary(train)}. Validación: ${_summary(val)}.',
          child: SizedBox(
            height: height,
            child: CurvePainter(train, val, trainColor: cs.primary, valColor: cs.tertiary),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 24, height: 3, color: cs.primary),
              const SizedBox(width: 6),
              const Text(Strings.legendTrain, style: TextStyle(fontSize: 12)),
            ]),
            // ponytail: muestra discontinua = redundancia no-cromática (WCAG 1.4.1);
            // la curva real ya usa dashArray [6,4].
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 24,
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Container(width: 6, height: 3, color: cs.tertiary),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(Strings.legendVal, style: TextStyle(fontSize: 12)),
            ]),
          ],
        ),
        ExpansionTile(
          title: const Text(Strings.chartDataTable, style: TextStyle(fontSize: 13)),
          tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 44,
                columns: const [
                  DataColumn(label: Text('i')),
                  DataColumn(label: Text('entrenamiento')),
                  DataColumn(label: Text('validación')),
                ],
                rows: [
                  for (var i = 0; i < train.length; i++)
                    DataRow(cells: [
                      DataCell(Text('$i')),
                      DataCell(Text(train[i].toStringAsFixed(3))),
                      DataCell(Text(i < val.length ? val[i].toStringAsFixed(3) : '—')),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// E5: instructor revisa intentos con rúbrica propia (0-4 por criterio).
// ponytail: StudentSessionsPage eliminada; el diálogo de InstructorPage va
// directo a /instructor/session/:sid (una pantalla menos, mismo flujo).

const reviewCriteria = ['exactitud', 'evidencia', 'causal', 'alternativas', 'metacognicion'];

class SessionReviewPage extends StatefulWidget {
  final String sessionId;
  const SessionReviewPage({super.key, required this.sessionId});
  @override
  State<SessionReviewPage> createState() => _ReviewState();
}

class _ReviewState extends State<SessionReviewPage> {
  String status = '';
  late final _future = fetchJson('/sessions/${widget.sessionId}/attempts');

  Future<void> _send(String attemptId, Map<String, double> scores, String notes) async {
    try {
      await postJson('/instructor/attempts/$attemptId/reviews', {
        'rubric_scores': {for (final e in scores.entries) e.key: e.value.round()},
        'notes': notes,
      });
      setState(() => status = 'Revisión guardada ✓');
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar intentos')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return Center(
              child: Semantics(liveRegion: true, child: Text('Error: ${s.error}')),
            );
          }
          final attempts = s.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final a in attempts)
                AttemptReviewCard(
                  key: ValueKey(a['id']),
                  answer: '${a['answer']}',
                  onSave: (scores, notes) => _send(a['id'], scores, notes),
                ),
              StatusText(status),
            ],
          );
        },
      ),
    );
  }
}

// ponytail: per-attempt state; shared map+controller contaminated grades across cards.
class AttemptReviewCard extends StatefulWidget {
  final String answer;
  final void Function(Map<String, double> scores, String notes) onSave;
  const AttemptReviewCard({super.key, required this.answer, required this.onSave});
  @override
  State<AttemptReviewCard> createState() => _AttemptReviewCardState();
}

class _AttemptReviewCardState extends State<AttemptReviewCard> {
  late Map<String, double> scores;
  late TextEditingController notes;
  @override
  void initState() {
    super.initState();
    scores = {for (final c in reviewCriteria) c: 2.0};
    notes = TextEditingController();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.answer, style: const TextStyle(fontSize: 13)),
            for (final crit in reviewCriteria)
              Row(
                children: [
                  SizedBox(width: 110, child: Text(crit, style: const TextStyle(fontSize: 12))),
                  Expanded(
                    child: Slider(
                      value: scores[crit]!, min: 0, max: 4, divisions: 4,
                      label: '${scores[crit]!.round()}',
                      onChanged: (v) => setState(() => scores[crit] = v),
                    ),
                  ),
                  SizedBox(
                      width: 16,
                      child: Text('${scores[crit]!.round()}',
                          style: const TextStyle(fontSize: 12))),
                ],
              ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder()),
            ),
            FilledButton(
              onPressed: () => widget.onSave(scores, notes.text),
              child: const Text('Guardar revisión'),
            ),
          ],
        ),
      ),
    );
  }
}

// G2: referencia vs actual + serie con cambio; diagnosticar deriva y decidir acción.
class MonitorLabPage extends StatefulWidget {
  final String labId;
  final String title;
  const MonitorLabPage({super.key, required this.labId, required this.title});
  @override
  State<MonitorLabPage> createState() => _MonitorState();
}

class _MonitorState extends State<MonitorLabPage> {
  final lab = LabSession();
  String feature = 'temp';
  double changepoint = 90;
  final answer = TextEditingController();
  Map<String, dynamic>? dist;

  int get seed => lab.posttestMode ? 99 : 1;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await lab.init(widget.labId);
    if (lab.sessionId == null) {
      setState(() {});
      return;
    }
    await _load();
  }

  Future<void> _load() async {
    try {
      final d = await fetchMap('/labs/${widget.labId}/distributions?seed=$seed');
      setState(() => dist = d);
    } catch (e) {
      setState(() => lab.status = 'Error datos: $e');
    }
  }

  Future<void> _send() async {
    if (lab.sessionId == null || lab.evaluating) return;
    if (answer.text.trim().isEmpty) {
      setState(() => lab.status = 'La hipótesis es obligatoria');
      return;
    }
    setState(() {
      lab.evaluating = true;
      lab.status = '';
    });
    try {
      await lab.send({
        'seed': seed,
        'extra': {'feature': feature, 'changepoint': changepoint.round()},
        'answer_text': answer.text,
      }, posttest: lab.posttestMode);
      setState(() {
        lab.evaluating = false;
        if (lab.posttestMode) {
          lab.posttestSent = true;
          lab.status = 'Postest entregado (sin ayuda)';
        } else {
          lab.status = 'Guardado ✓';
        }
      });
      if (!lab.posttestMode) {
        await lab.evaluate();
        setState(() {});
      }
    } catch (e) {
      setState(() {
        lab.evaluating = false;
        lab.status = 'Error envío: $e';
      });
    }
  }

  Future<void> _retry() async {
    setState(() => lab.evaluating = true);
    await lab.evaluate();
    setState(() => lab.evaluating = false);
  }

  Future<void> _next() async {
    setState(() => lab.nextBusy = true);
    await lab.next();
    setState(() => lab.nextBusy = false);
  }

  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feats = (dist?['features'] as Map?) ?? {};
    final sel = (feats[feature] as Map?) ?? {};
    final ref = (sel['ref'] as List?)?.cast<num>() ?? [];
    final cur = (sel['cur'] as List?)?.cast<num>() ?? [];
    final series = (dist?['series'] as List?)?.cast<num>() ?? [];
    final controls = [
      LabHeader(
        objective: lab.posttestMode
            ? 'Distribución nueva, sin ayuda. ¿Deriva? ¿Reentrenar o monitorear?'
            : '¿Qué feature deriva? Compara referencia vs actual y ubica el cambio.',
        step: lab.step,
      ),
      Semantics(
        label: '¿Qué feature deriva?',
        child: DropdownButton<String>(
          value: feats.containsKey(feature) ? feature : (feats.keys.firstOrNull as String? ?? feature),
          hint: const Text('¿Qué feature deriva?'),
          items: [
            for (final k in feats.keys.cast<String>())
              DropdownMenuItem(value: k, child: Text(k)),
            if (feats.isEmpty)
              DropdownMenuItem(value: feature, child: Text(feature)),
          ],
          onChanged: (v) => setState(() => feature = v ?? feature),
        ),
      ),
      AccessibleHistChart(ref: ref, cur: cur, label: 'Distribución $feature'),
      AccessibleCurveChart(train: series, val: const [], label: 'Serie temporal'),
      Text('Punto de cambio: t=${changepoint.round()}',
          style: const TextStyle(fontSize: 12)),
      Slider(
        value: changepoint, min: 0, max: 179, divisions: 179,
        label: 'Cambio en t=${changepoint.round()}',
        onChanged: (v) => setState(() => changepoint = v),
      ),
      TextField(
        controller: answer, maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Hipótesis de deriva y decisión *',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: lab.evaluating ? null : _send,
        child: Text(lab.posttestMode ? Strings.deliverPosttest : Strings.sendAttempt),
      ),
    ];
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!lab.posttestMode)
          TextButton(
            onPressed: lab.sessionId == null
                ? null
                : () => setState(() {
                      lab.posttestMode = true;
                      lab.evalResult = null;
                      lab.intervention = null;
                      lab.socraticQ = '';
                      _load();
                    }),
            child: const Text(Strings.goPosttest),
          ),
        if (!lab.posttestMode)
          ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
        if (lab.posttestMode && lab.posttestSent)
          PosttestReflection(
              lab: lab, labId: widget.labId, onUpdate: () => setState(() {})),
        StatusText(lab.status),
      ],
    );
    return Scaffold(
      appBar: AppBar(
          title: Text(lab.posttestMode ? '${widget.title} (postest)' : widget.title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1024) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: ListView(padding: const EdgeInsets.all(16), children: controls)),
                    SizedBox(
                      width: (constraints.maxWidth * 0.35).clamp(320.0, 420.0),
                      child: ListView(padding: const EdgeInsets.all(16), children: [result]),
                    ),
                  ],
                );
              }
              return ListView(padding: const EdgeInsets.all(16), children: [...controls, result]);
            },
          ),
        ),
      ),
    );
  }
}

class HistPainter extends StatelessWidget {
  final List<num> ref;
  final List<num> cur;
  final Color refColor;
  final Color curColor;
  const HistPainter(this.ref, this.cur,
      {super.key, required this.refColor, required this.curColor});

  @override
  Widget build(BuildContext context) {
    if (ref.isEmpty) return const SizedBox.shrink();
    final maxV = [...ref, ...cur].fold<double>(1, (a, b) => a > b.toDouble() ? a : b.toDouble());
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        barGroups: [
          for (var i = 0; i < ref.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: ref[i].toDouble(), color: refColor, width: 6),
                BarChartRodData(
                  toY: i < cur.length ? cur[i].toDouble() : 0,
                  color: curColor,
                  width: 6,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Histograma referencia vs actual con alternativa textual y leyenda por
/// posición (izquierda/derecha), no por color.
class AccessibleHistChart extends StatelessWidget {
  final List<num> ref;
  final List<num> cur;
  final String label;
  const AccessibleHistChart({super.key, required this.ref, required this.cur, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$label. ${ref.length} barras. Referencia suma '
              '${ref.fold<num>(0, (a, b) => a + b).toStringAsFixed(2)}, '
              'actual ${cur.fold<num>(0, (a, b) => a + b).toStringAsFixed(2)}.',
          child: SizedBox(
            height: 120,
            child: HistPainter(ref, cur, refColor: cs.primary, curColor: cs.secondary),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 12, color: cs.primary),
              const SizedBox(width: 6),
              const Text(Strings.legendRef, style: TextStyle(fontSize: 12)),
            ]),
            // ponytail: actual hueco vs referencia sólida = distinción por forma,
            // no solo color (WCAG 1.4.1); texto ya dice izquierda/derecha.
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.secondary, width: 2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(Strings.legendCur, style: TextStyle(fontSize: 12)),
            ]),
          ],
        ),
        ExpansionTile(
          title: const Text(Strings.chartDataTable, style: TextStyle(fontSize: 13)),
          tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 44,
                columns: const [
                  DataColumn(label: Text('bin')),
                  DataColumn(label: Text('referencia')),
                  DataColumn(label: Text('actual')),
                ],
                rows: [
                  for (var i = 0; i < ref.length; i++)
                    DataRow(cells: [
                      DataCell(Text('$i')),
                      DataCell(Text(ref[i].toStringAsFixed(3))),
                      DataCell(Text(i < cur.length ? cur[i].toStringAsFixed(3) : '—')),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ProgressPage extends StatelessWidget {  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Progreso por evidencias (siguiente slice)'));
  }
}

class InstructorPage extends StatefulWidget {
  const InstructorPage({super.key});
  @override
  State<InstructorPage> createState() => _InstructorState();
}

class _InstructorState extends State<InstructorPage> {
  late final _future = fetchJson('/instructor/students');
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: Semantics(
              liveRegion: true,
              child: Text('${Strings.noApi}: ${s.error}'),
            ),
          );
        }
        final students = s.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              icon: Icons.groups,
              title: '${students.length} estudiantes',
              children: const [
                Text('Toca un estudiante para ver sus sesiones y revisar.'),
              ],
            ),
            const SizedBox(height: 12),
            for (final st in students)
              Card(
                child: ExpansionTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(st['display_name']),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _SessionsDialog(studentId: '${st['id']}'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

// ponytail: future hoisted to dialog state so rebuilds don't refetch.
class _SessionsDialog extends StatefulWidget {
  final String studentId;
  const _SessionsDialog({required this.studentId});
  @override
  State<_SessionsDialog> createState() => _SessionsDialogState();
}

class _SessionsDialogState extends State<_SessionsDialog> {
  late final _future = fetchJson('/instructor/students/${widget.studentId}/sessions');
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c2, s2) {
        if (!s2.hasData) return const LinearProgressIndicator();
        final sessions = s2.data!;
        if (sessions.isEmpty) return const Text('Sin sesiones');
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final se in sessions)
                ListTile(
                  dense: true,
                  title: Text('${se['lab_template_id']} · ${se['status']}'),
                  onTap: () {
                    Navigator.pop(context);
                    router.go('/instructor/session/${se['id']}');
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
