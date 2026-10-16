import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'features/academy_page.dart';
import 'features/data_lab_page.dart';
import 'features/instructor_page.dart';
import 'features/login_page.dart';
import 'features/ml_lab_page.dart';
import 'features/monitor_lab_page.dart';
import 'features/progress_page.dart';
import 'features/review_page.dart';
import 'l10n/app_localizations.dart';
import 'state/app_state.dart';
import 'widgets/cards.dart';
import 'widgets/theme.dart';

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
    final isInstructor = ref.watch(authProvider)?.isStudent == false;
    final tabs = isInstructor ? _shellTabs : _shellTabs.sublist(0, 3);
    final sel = _index >= tabs.length ? 0 : _index;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        void go(int i) => context.go(tabs[i]);
        final cs = Theme.of(context).colorScheme;
        final rail = NavigationRail(
          selectedIndex: sel,
          onDestinationSelected: go,
          labelType: NavigationRailLabelType.all,
          useIndicator: true,
          backgroundColor: cs.surface,
          indicatorColor: cs.primaryContainer,
          selectedIconTheme: IconThemeData(color: cs.onPrimaryContainer, size: 24),
          unselectedIconTheme: IconThemeData(color: cs.onSurfaceVariant, size: 24),
          selectedLabelTextStyle: TextStyle(
            color: cs.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelTextStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          destinations: [
            const NavigationRailDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: Text(Strings.tabAcademy),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.science_outlined),
              selectedIcon: Icon(Icons.science),
              label: Text(Strings.tabLabs),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.trending_up),
              selectedIcon: Icon(Icons.trending_up),
              label: Text(Strings.tabProgress),
            ),
            if (isInstructor)
              const NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text(Strings.tabInstructor),
              ),
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
            title: const Text(
              Strings.appTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              const ThemeToggleButton(),
              if (!wide)
                IconButton(
                  key: const ValueKey('nav_logout_narrow'),
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
                  selectedIndex: sel,
                  onDestinationSelected: go,
                  destinations: [
                    const NavigationDestination(icon: Icon(Icons.school), label: Strings.tabAcademy),
                    const NavigationDestination(icon: Icon(Icons.science), label: Strings.tabLabs),
                    const NavigationDestination(icon: Icon(Icons.trending_up), label: Strings.tabProgress),
                    if (isInstructor)
                      const NavigationDestination(icon: Icon(Icons.person), label: Strings.tabInstructor),
                  ],
                ),
        );
      },
    );
  }
}

