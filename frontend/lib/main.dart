import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:marionette_flutter/marionette_flutter.dart';

import 'genui/tutor_surface.dart';
import 'l10n/app_localizations.dart';
import 'models/models.dart';
import 'state/app_state.dart';

// Formato numérico/cadenas vía intl + ARB (l10n/app_*.arb); Strings queda
// como fallback ES hasta migrar cada pantalla a AppLocalizations.of.
final _num2 = NumberFormat('0.00', 'es');
final _int = NumberFormat.decimalPattern('es');

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

/// Lleva la vista al estado tras evaluar/avanzar: el resultado aparece
/// bajo el fold y si no el usuario no lo ve (ni Marionette lo alcanza).
void scrollToStatus(GlobalKey key) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 250));
    }
  });
}

Future<void> main() async {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  final initial = await loadInitialState();
  runApp(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => AuthNotifier(initial.auth)),
        themeModeProvider.overrideWith(() => ThemeNotifier(initial.theme)),
      ],
      child: const CognitiveFlowApp(),
    ),
  );
}

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
});

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

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final dark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return IconButton(
      key: const ValueKey('theme_toggle'),
      tooltip: dark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
      icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
      onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}

class CognitiveFlowApp extends ConsumerWidget {
  const CognitiveFlowApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: Strings.appTitle,
      theme: buildCognitiveLightTheme(),
      darkTheme: buildCognitiveDarkTheme(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

// REGLA: todo texto visible es seleccionable. SelectionArea va DENTRO de las
// rutas (bajo el Overlay del Navigator); en MaterialApp.builder revienta
// (No Overlay widget found) porque corre por encima del Navigator.

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginPage> {
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
      await ref.read(authProvider.notifier).login(
            body['token'] as String,
            (body['user_id'] ?? userId.text.trim()) as String,
            (body['role'] ?? 'student') as String,
          );
      if (mounted) context.go('/academy');
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

class Shell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        void go(int i) => context.go(_shellTabs[i]);
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
                child: IconButton(
                  key: const ValueKey('nav_logout'),
                  tooltip: 'Salir',
                  icon: const Icon(Icons.logout),
                  onPressed: logout,
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
                  onPressed: logout,
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

// P1.5: id único por evento (reintento seguro vía dedup en backend).
int _eventSeq = 0;
String newEventId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_eventSeq++}';

Future<List<Module>> fetchModules() async => parseModules(await fetchJson('/modules'));
Future<List<Lab>> fetchLabs() async => parseLabs(await fetchJson('/labs'));
Future<List<Student>> fetchStudents() async =>
    parseStudents(await fetchJson('/instructor/students'));
Future<List<SessionInfo>> fetchSessions(String studentId) async =>
    parseSessions(await fetchJson('/instructor/students/$studentId/sessions'));
Future<List<Attempt>> fetchAttempts(String sessionId) async =>
    parseAttempts(await fetchJson('/sessions/$sessionId/attempts'));

class AcademyPage extends StatefulWidget {
  const AcademyPage({super.key});
  @override
  State<AcademyPage> createState() => _AcademyState();
}

String labStatusLabel(String? status) => switch (status) {
      'active' => 'En curso',
      'posttest' => 'En postest',
      'done' => 'Completado',
      _ => 'No iniciado',
    };

class _AcademyState extends State<AcademyPage> {
  // ponytail: un solo Future.wait; tres GET en paralelo, un solo spinner.
  late Future<List<dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future =
        Future.wait([fetchModules(), fetchLabs(), fetchMap('/me/lab-status')]);
  }

  void _retry() => setState(() {
        _future = Future.wait(
            [fetchModules(), fetchLabs(), fetchMap('/me/lab-status')]);
      });

  void _goLab(BuildContext context, Lab l) => context.go(
        '/labs/${l.id}',
        extra: {'lab_type': l.labType, 'title': l.title},
      );

  (IconData, Color, Color, Color) _statusStyle(
      String? st, ColorScheme cs) {
    // icon, iconColor, chipBg, chipFg — redundancia icono+texto (DESIGN.md §4).
    return switch (st) {
      'done' => (
          Icons.check_circle,
          const Color(0xFF166534),
          const Color(0xFFDCFCE7),
          const Color(0xFF166534),
        ),
      'active' => (
          Icons.play_arrow,
          cs.primary,
          cs.primaryContainer,
          cs.onPrimaryContainer,
        ),
      'posttest' => (
          Icons.lock_outline,
          cs.tertiary,
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
        ),
      _ => (Icons.circle_outlined, cs.outline, cs.surfaceContainerHighest,
          cs.onSurfaceVariant),
    };
  }

  Widget _labCard(BuildContext context, Lab l, Map statusMap) {
    final st = statusMap[l.id] as String?;
    final cs = Theme.of(context).colorScheme;
    final (icon, iconColor, chipBg, chipFg) = _statusStyle(st, cs);
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: st == null ? iconColor : chipFg),
        ),
        title: Text(l.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: l.description.isEmpty
            ? null
            : Text(l.description,
                maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(
              backgroundColor: chipBg,
              label: Text(labStatusLabel(st),
                  style: TextStyle(fontSize: 11, color: chipFg)),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
        onTap: () => _goLab(context, l),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _future,
      builder: (c, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Cargando academia…'),
              ],
            ),
          );
        }
        if (s.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text('${Strings.noApi}: ${s.error}',
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _retry,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final modules = s.data![0] as List<Module>;
        final labs = s.data![1] as List<Lab>;
        final statusMap = s.data![2] as Map;
        final orphans = [for (final l in labs) if (l.moduleId == '') l];
        if (labs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.school_outlined, size: 40),
                  const SizedBox(height: 12),
                  Text('Sin laboratorios todavía',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      'Vuelve más tarde o avisa a tu instructor si esperabas contenido aquí.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          );
        }
        // Objetivo actual: lo en curso primero, si no lo siguiente sin iniciar.
        Lab? current;
        for (final l in labs) {
          if (statusMap[l.id] == 'active' || statusMap[l.id] == 'posttest') {
            current = l;
            break;
          }
        }
        current ??= [for (final l in labs) if ((statusMap[l.id] as String?) == null) l]
            .firstOrNull;
        final cur = current;
        int doneCount(Iterable<Lab> ls) =>
            ls.where((l) => statusMap[l.id] == 'done').length;
        Widget moduleHeader(Module m, int total, int done) => Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                        header: true,
                        child: Text(m.title,
                            style: Theme.of(context).textTheme.titleMedium)),
                  ),
                  if (total > 0)
                    Text('$done/$total',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                ],
              ),
            );
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (cur != null) ...[
                  SectionCard(
                    icon: Icons.track_changes,
                    title: 'Tu objetivo actual',
                    trailing: Chip(
                      label: Text(
                          labStatusLabel(statusMap[cur.id] as String?),
                          style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    ),
                    children: [
                      Text(cur.title,
                          style: Theme.of(context).textTheme.titleSmall),
                      if (cur.description.isNotEmpty)
                        Text(cur.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: () => _goLab(context, cur),
                            child: const Text('Continuar'),
                          ),
                          TextButton(
                            onPressed: () => context.go('/progress'),
                            child: const Text('Ver progreso'),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 4),
                ],
                for (final m in modules) ...[
                  Builder(builder: (context) {
                    final mls = [
                      for (final l in labs)
                        if (l.moduleId == m.id) l
                    ];
                    if (mls.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        moduleHeader(m, mls.length, doneCount(mls)),
                        for (final l in mls) _labCard(context, l, statusMap),
                      ],
                    );
                  }),
                ],
                if (orphans.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 4),
                    child: Semantics(
                        header: true,
                        child: Text('Otros',
                            style:
                                Theme.of(context).textTheme.titleMedium)),
                  ),
                  for (final l in orphans) _labCard(context, l, statusMap),
                ],
              ],
            ),
          ),
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
  late final _future = fetchLabs();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Lab>>(
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
                title: AutoSizeText(l.title,
                    maxLines: 1, minFontSize: 12),
                subtitle: Text(l.labType),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(
                  '/labs/${l.id}',
                  extra: {'lab_type': l.labType, 'title': l.title},
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
  // P3.3: historial de preguntas del tutor por sesión (GET tutor-history).
  List<Map<String, dynamic>> tutorHistory = [];

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
    try {
      final h = await fetchJson('/sessions/$sessionId/tutor-history');
      tutorHistory = h.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
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
    final r = await postJson('/sessions/$sessionId/reflection', {'text': text});
    reflectionSummary = (r['summary'] as Map?)?.map((k, v) => MapEntry('$k', v));
    done = true;
  }

  // P4.1: el servidor fija la variante del postest; el cliente la aplica.
  Map<String, dynamic>? posttestVariant;
  Map<String, dynamic>? reflectionSummary;

  Future<bool> beginPosttest() async {
    try {
      final r = await postJson('/sessions/$sessionId/posttest', {'answer_text': ''});
      posttestVariant = r;
      return true;
    } catch (e) {
      status = 'No se pudo iniciar el postest: $e';
      return false;
    }
  }

  int variantSeed(int fallback) => (posttestVariant?['seed'] as num?)?.toInt() ?? fallback;
}

const labStepLabels = ['Explorar', 'Evaluar', 'Intervenir', 'Postest'];

// P4.1: entrada al postest con variante del servidor (igual en los 3 labs).
// beginPosttest es idempotente: doble toque no duplica nada.
Future<void> enterPosttest(LabSession lab, void Function(void Function()) setState,
    Future<void> Function() reload,
    [void Function()? onVariant]) async {
  if (await lab.beginPosttest()) {
    setState(() {
      lab.posttestMode = true;
      lab.evalResult = null;
      lab.intervention = null;
      lab.socraticQ = '';
      onVariant?.call();
    });
    await reload();
  } else {
    setState(() {});
  }
}

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
                  child: AutoSizeText(title,
                      maxLines: 1,
                      minFontSize: 12,
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
  late final _future = fetchLabs();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Lab>>(
      future: _future,
      builder: (c, s) {
        if (!s.hasData) return const SizedBox.shrink();
        final labs = s.data!;
        final i = labs.indexWhere((l) => l.id == widget.labId);
        if (i < 0 || i + 1 >= labs.length) {
          return const Text('Último lab de la ruta ✓');
        }
        final n = labs[i + 1];
        return FilledButton.tonal(
          key: const ValueKey('next_lab'),
          onPressed: () => context.go(
            '/labs/${n.id}',
            extra: {'lab_type': n.labType, 'title': n.title},
          ),
          child: AutoSizeText('Siguiente lab: ${n.title}',
              maxLines: 1, minFontSize: 12),
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
            key: const ValueKey('reflection_text'),
            controller: reflection,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reflexión: ¿qué aprendiste?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('reflection_send'),
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
        // P4.5: pico-fin honesto desde deltas reales; sin halago automático.
        if (widget.lab.reflectionSummary != null)
          Builder(builder: (context) {
            final s = widget.lab.reflectionSummary!;
            final mejora = s['mejora'];
            final desafio = s['desafio'];
            if (mejora == null && desafio == null) {
              return const Text(
                  'Aún sin evidencias comparables; sigue practicando.',
                  style: TextStyle(fontSize: 13));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mejora != null)
                  Text('Mejora observada: ${criterionLabel('$mejora')} ✓',
                      style: const TextStyle(fontSize: 13)),
                if (desafio != null)
                  Text('Siguiente desafío: ${criterionLabel('$desafio')}',
                      style: const TextStyle(fontSize: 13)),
              ],
            );
          }),
        const SizedBox(height: 8),
        NextLabButton(widget.labId),
      ],
    );
  }
}

/// P2.4: etiquetas humanas para criterios Jev — nunca solo `id · score`.
const criterionLabels = {
  'exactitud': 'Exactitud conceptual',
  'evidencia': 'Uso de evidencia',
  'causal': 'Causalidad',
  'alternativas': 'Alternativas',
  'metacognicion': 'Revisión',
};

String criterionLabel(String id) => criterionLabels[id] ?? id;

// P4.2: línea base→postest desde mapas {criterio: score}; null si no comparable.
String? progressLine(Map? base, Map? post) {
  double? avg(Map? m) {
    if (m == null || m.isEmpty) return null;
    var t = 0.0;
    for (final v in m.values) {
      t += (v as num).toDouble();
    }
    return t / m.length;
  }

  final b = avg(base);
  final p = avg(post);
  String f(double v) => v.toStringAsFixed(1);
  if (b == null && p == null) return null;
  if (b == null) return 'Postest ${f(p!)} (sin base)';
  if (p == null) return 'Base ${f(b)} (sin postest)';
  final d = p - b;
  return 'Base ${f(b)} → Postest ${f(p)} (${d >= 0 ? '+' : ''}${f(d)})';
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
          ).animate().fadeIn(duration: 200.ms).shimmer(duration: 1200.ms),
        if (lab.evalError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(lab.evalError!, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
        ],
        if (lab.evalResult != null) ...[
          Builder(builder: (context) {
            final r = lab.evalResult!;
            final isJev = r['evaluator'] == 'jev';
            if (r['status'] == 'pending') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(
                      isJev ? 'Evaluación Jev pendiente' : 'Evaluación pendiente',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jev no devolvió diagnóstico'
                    '${r['reason'] != null ? ': ${r['reason']}' : ''}. '
                    'No es una nota; tu intento está guardado.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
                ],
              ).animate().fadeIn(duration: 250.ms);
            }
            final crits = (r['criteria'] as List).cast<Map>();
            crits.sort((a, b) =>
                ((b['score'] as num)).compareTo((a['score'] as num)));
            final summary = crits.isEmpty
                ? null
                : 'Fortaleza: ${criterionLabel('${crits.first['id']}')}'
                    '${crits.length > 1 ? ' · A trabajar: ${criterionLabel('${crits.last['id']}')}' : ''}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        isJev ? 'Evaluación Jev' : 'Evaluación simulada',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    for (final c in crits)
                      Chip(
                        avatar: Icon(
                          (c['score'] as num) >= 2
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 16,
                        ),
                        label: Text(
                            '${criterionLabel('${c['id']}')} · ${c['score']}',
                            style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ).animate().fadeIn(duration: 250.ms),
                const SizedBox(height: 4),
                if (summary != null)
                  Text(summary, style: const TextStyle(fontSize: 12)),
                const Text(
                  'Evidencia orientativa, revisable por tu instructor.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            );
          }),
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
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
        ],
        if (lab.tutorHistory.isNotEmpty)
          ExpansionTile(
            key: const ValueKey('tutor_history'),
            title: Text(
                'Preguntas del tutor (${lab.tutorHistory.length})'),
            children: [
              for (final h in lab.tutorHistory)
                ListTile(
                  dense: true,
                  leading: Icon(
                      h['provider'] == 'gemini'
                          ? Icons.smart_toy_outlined
                          : Icons.help_outline,
                      size: 16),
                  title: Text('${h['question']}',
                      style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        if (lab.socraticQ.isNotEmpty || lab.tutorHistory.isNotEmpty) ...[
          FilledButton.tonal(
            key: const ValueKey('next_activity'),
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
          ).animate().fadeIn(duration: 200.ms).shimmer(duration: 1200.ms),
        if (lab.nextError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(lab.nextError!, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(onPressed: onNext, child: const Text(Strings.retry)),
        ],
        if (lab.intervention != null) ...[
          const SizedBox(height: 8),
          TutorSurface(
            intervention: lab.intervention!,
            onEvent: (wt, et, payload) async {
              final sid = lab.sessionId;
              if (sid == null) return;
              try {
                await postJson('/sessions/$sid/events', {
                  'client_event_id': newEventId(),
                  'widget_type': wt,
                  'event_type': et,
                  'payload': payload,
                });
              } catch (_) {}
            },
          ),
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
  final statusKey = GlobalKey();
  List columns = [];
  List rows = [];
  final flagged = <int>{};
  final justification = TextEditingController();

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;

  @override
  void initState() {
    super.initState();
    justification.addListener(
        () => saveDraft(widget.labId, 'justification', justification.text));
    _init();
  }

  Future<void> _init() async {
    await lab.init(widget.labId);
    if (lab.sessionId == null) {
      setState(() {});
      return;
    }
    await _loadTable();
    // Borrador previo (si salió del lab sin entregar).
    final f = await loadDraft(widget.labId, 'flagged');
    final j = await loadDraft(widget.labId, 'justification');
    if (!mounted) return;
    setState(() {
      if (f != null && f.isNotEmpty) {
        flagged.addAll(
            [for (final p in f.split(',')) int.tryParse(p)].whereType<int>());
      }
      if (j != null) justification.text = j;
    });
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
                          key: ValueKey('datarow_${r['id']}'),
                          selected: flagged.contains(r['id']),
                          onSelectChanged: (_) {
                            setState(() {
                              flagged.contains(r['id'])
                                  ? flagged.remove(r['id'])
                                  : flagged.add(r['id'] as int);
                            });
                            saveDraft(widget.labId, 'flagged',
                                flagged.map((e) => '$e').join(','));
                          },
                          // ponytail: key en la celda (con RenderBox) para taps exactos;
                          // la key en DataRow no resuelve centro útil en web.
                          cells: [
                            for (final c in columns)
                              DataCell(Text('${r['$c'] ?? '—'}',
                                  key: ValueKey('datacell_${r['id']}_$c'))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          TextField(
            key: const ValueKey('data_justification'),
            controller: justification,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Justificación y plan de limpieza *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('data_send'),
            onPressed: lab.evaluating ? null : _send,
            child: Text(lab.posttestMode ? Strings.deliverPosttest : Strings.sendAttempt),
          ),
          if (!lab.posttestMode)
            TextButton(
              key: const ValueKey('go_posttest'),
              onPressed: lab.sessionId == null
                  ? null
                  : () => enterPosttest(lab, setState, _loadTable),
              child: const Text(Strings.goPosttest),
            ),
          if (!lab.posttestMode)
            ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
          if (lab.posttestMode && lab.posttestSent)
            PosttestReflection(
                lab: lab,
                labId: widget.labId,
                onUpdate: () {
                  if (lab.done) {
                    clearDrafts(widget.labId, const ['flagged', 'justification']);
                  }
                  setState(() {});
                }),
          StatusText(lab.status, key: statusKey),
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
  final statusKey = GlobalKey();
  double complexity = 5;
  double noise = 20;
  final hypo = TextEditingController();
  Map<String, dynamic>? curve;

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;

  @override
  void initState() {
    super.initState();
    hypo.addListener(() => saveDraft(widget.labId, 'hypo', hypo.text));
    _init();
  }

  Future<void> _init() async {
    await lab.init(widget.labId);
    if (lab.sessionId == null) {
      setState(() {});
      return;
    }
    await _loadCurve();
    final cx = await loadDraft(widget.labId, 'complexity');
    final nz = await loadDraft(widget.labId, 'noise');
    final h = await loadDraft(widget.labId, 'hypo');
    if (!mounted) return;
    setState(() {
      if (cx != null) complexity = double.tryParse(cx) ?? complexity;
      if (nz != null) noise = double.tryParse(nz) ?? noise;
      if (h != null) hypo.text = h;
    });
    if (cx != null || nz != null) await _loadCurve();
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
    // P4.1: variante fijada por el servidor; en postest no se toca.
    final locked = sent || lab.posttestMode;
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
          // P4.1: variante fijada por el servidor; en postest no se toca.
          ParamSlider(
            label: 'Complejidad del modelo',
            value: '${complexity.round()} / 10',
            help: 'Sube la complejidad y mira cuándo la validación se despega.',
            current: complexity,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: locked ? null : (v) => setState(() => complexity = v),
            onChangeEnd: locked
                ? null
                : (_) {
                    _loadCurve();
                    saveDraft(widget.labId, 'complexity', '$complexity');
                  },
          ),
          ParamSlider(
            label: 'Ruido en los datos',
            value: '${noise.round()} %',
            help: 'Más ruido → ambas curvas más altas e inestables.',
            current: noise,
            min: 0,
            max: 50,
            divisions: 10,
            onChanged: locked ? null : (v) => setState(() => noise = v),
            onChangeEnd: locked
                ? null
                : (_) {
                    _loadCurve();
                    saveDraft(widget.labId, 'noise', '$noise');
                  },
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
            key: const ValueKey('ml_hypo'),
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
                key: const ValueKey('ml_send'),
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
            key: const ValueKey('go_posttest'),
            onPressed: lab.sessionId == null
                ? null
                : () => enterPosttest(lab, setState, _loadCurve, () {
                      final v = lab.posttestVariant;
                      if (v != null) {
                        complexity = (v['complexity'] as num).toDouble();
                        noise = (v['noise_pct'] as num).toDouble();
                      }
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
              lab: lab,
              labId: widget.labId,
              onUpdate: () {
                if (lab.done) {
                  clearDrafts(widget.labId, const ['complexity', 'noise', 'hypo']);
                }
                setState(() {});
              }),
        StatusText(lab.status, key: statusKey),
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
    return '${ys.length} puntos, mín ${_num2.format(min)}, máx ${_num2.format(max)}, '
        'último ${_num2.format(ys.last)}';
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
  late final _future = fetchAttempts(widget.sessionId);

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
      body: FutureBuilder<List<Attempt>>(
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
                  key: ValueKey(a.id),
                  answer: a.answer,
                  onSave: (scores, notes) => _send(a.id, scores, notes),
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
  final statusKey = GlobalKey();
  String feature = 'temp';
  double changepoint = 90;
  final answer = TextEditingController();
  Map<String, dynamic>? dist;

  int get seed => lab.posttestMode ? lab.variantSeed(99) : 1;

  @override
  void initState() {
    super.initState();
    answer.addListener(() => saveDraft(widget.labId, 'answer', answer.text));
    _init();
  }

  Future<void> _init() async {
    await lab.init(widget.labId);
    if (lab.sessionId == null) {
      setState(() {});
      return;
    }
    await _load();
    final ft = await loadDraft(widget.labId, 'feature');
    final cp = await loadDraft(widget.labId, 'changepoint');
    final an = await loadDraft(widget.labId, 'answer');
    if (!mounted) return;
    setState(() {
      if (ft != null && ft.isNotEmpty) feature = ft;
      if (cp != null) changepoint = double.tryParse(cp) ?? changepoint;
      if (an != null) answer.text = an;
    });
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
          onChanged: (v) {
            setState(() => feature = v ?? feature);
            saveDraft(widget.labId, 'feature', feature);
          },
        ),
      ),
      AccessibleHistChart(ref: ref, cur: cur, label: 'Distribución $feature'),
      AccessibleCurveChart(train: series, val: const [], label: 'Serie temporal'),
      Text('Punto de cambio: t=${changepoint.round()}',
          style: const TextStyle(fontSize: 12)),
      Slider(
        value: changepoint, min: 0, max: 179, divisions: 179,
        label: 'Cambio en t=${changepoint.round()}',
        onChanged: (v) {
          setState(() => changepoint = v);
          saveDraft(widget.labId, 'changepoint', '$changepoint');
        },
      ),
      TextField(
        key: const ValueKey('monitor_answer'),
        controller: answer, maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Hipótesis de deriva y decisión *',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        key: const ValueKey('monitor_send'),
        onPressed: lab.evaluating ? null : _send,
        child: Text(lab.posttestMode ? Strings.deliverPosttest : Strings.sendAttempt),
      ),
    ];
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!lab.posttestMode)
          TextButton(
            key: const ValueKey('go_posttest'),
            onPressed: lab.sessionId == null
                ? null
                : () => enterPosttest(lab, setState, _load),
            child: const Text(Strings.goPosttest),
          ),
        if (!lab.posttestMode)
          ResultPanel(lab: lab, onNext: _next, onRetry: _retry),
        if (lab.posttestMode && lab.posttestSent)
          PosttestReflection(
              lab: lab,
              labId: widget.labId,
              onUpdate: () {
                if (lab.done) {
                  clearDrafts(widget.labId, const ['feature', 'changepoint', 'answer']);
                }
                setState(() {});
              }),
        StatusText(lab.status, key: statusKey),
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

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});
  @override
  State<ProgressPage> createState() => _ProgressState();
}

class _ProgressState extends State<ProgressPage> {
  // ponytail: mismo Future.wait que Academia + GET /me/progress medido.
  late final _future =
      Future.wait([fetchLabs(), fetchMap('/me/lab-status'), fetchMap('/me/progress')]);

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
        final labs = s.data![0] as List<Lab>;
        final statusMap = s.data![1] as Map;
        final prog = {
          for (final p in (s.data![2] as List)) (p['lab_template_id'] as String): p as Map
        };
        final done =
            [for (final l in labs) if (statusMap[l.id] == 'done') l].length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
                AppLocalizations.of(context)?.routeProgress(
                      done,
                      labs.length,
                    ) ??
                    'Ruta: ${_int.format(done)} de ${_int.format(labs.length)} labs completados',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: labs.isEmpty ? 0 : done / labs.length),
            const SizedBox(height: 16),
            for (final l in labs)
              Card(
                child: ExpansionTile(
                  leading: Icon(
                    switch (statusMap[l.id]) {
                      'done' => Icons.check_circle,
                      'posttest' => Icons.lock_outline,
                      'active' => Icons.play_arrow,
                      _ => Icons.circle_outlined,
                    },
                  ),
                  title: AutoSizeText(l.title,
                      maxLines: 1, minFontSize: 12),
                  subtitle: Text([
                    labStatusLabel(statusMap[l.id] as String?),
                    progressLine((prog[l.id]?['baseline']) as Map?,
                            (prog[l.id]?['posttest']) as Map?) ??
                        'Sin evidencias comparables',
                  ].join(' · ')),
                  children: [
                    if ((prog[l.id]?['baseline'] as Map?)?.isNotEmpty == true ||
                        (prog[l.id]?['posttest'] as Map?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final cid in {
                              ...((prog[l.id]?['baseline'] as Map?)?.keys ?? []),
                              ...((prog[l.id]?['posttest'] as Map?)?.keys ?? []),
                            })
                              Chip(
                                label: Text(
                                    '${criterionLabel('$cid')}: '
                                    '${(prog[l.id]?['baseline'] as Map?)?[cid] ?? '—'}'
                                    '→${(prog[l.id]?['posttest'] as Map?)?[cid] ?? '—'}',
                                    style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                      ),
                    ListTile(
                      dense: true,
                      trailing: const Icon(Icons.chevron_right),
                      title: const Text('Abrir laboratorio',
                          style: TextStyle(fontSize: 13)),
                      onTap: () => context.go(
                        '/labs/${l.id}',
                        extra: {'lab_type': l.labType, 'title': l.title},
                      ),
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

class InstructorPage extends StatefulWidget {
  const InstructorPage({super.key});
  @override
  State<InstructorPage> createState() => _InstructorState();
}

class _InstructorState extends State<InstructorPage> {
  late final _future =
      Future.wait([fetchStudents(), fetchLabs(), fetchMap('/instructor/matrix')]);
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
        final students = s.data![0] as List<Student>;
        final labTitles = {
          for (final l in (s.data![1] as List<Lab>)) l.id: l.title
        };
        final matrix = {
          for (final m in (s.data![2] as List)) (m['student_id'] as String): m as Map
        };
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
                  title: AutoSizeText(st.displayName,
                      maxLines: 1, minFontSize: 12),
                  children: [
                    if (matrix[st.id] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: _MatrixCard(
                            labTitles: labTitles,
                            labs: (matrix[st.id]!['labs'] as Map).cast<String, Map>()),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _SessionsDialog(studentId: st.id),
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

// P4.4: matriz por alumno — baseline→postest por lab, sin promediar personas.
class _MatrixCard extends StatelessWidget {
  final Map<String, String> labTitles;
  final Map<String, Map> labs;
  const _MatrixCard({required this.labTitles, required this.labs});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in labs.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                    child: Text(labTitles[e.key] ?? e.key,
                        style: const TextStyle(fontSize: 13))),
                Text(
                    progressLine(e.value['baseline'] as Map?,
                            e.value['posttest'] as Map?) ??
                        'Sin evidencias',
                    style: const TextStyle(fontSize: 12)),
                if (e.value['pending_review'] == true) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.mark_email_unread_outlined, size: 16),
                ],
              ],
            ),
          ),
      ],
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
  late final _future = fetchSessions(widget.studentId);
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SessionInfo>>(
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
                  title: Text('${se.labTemplateId} · ${se.status}'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/instructor/session/${se.id}');
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
