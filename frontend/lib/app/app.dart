// Bootstrap + CognitiveFlowApp (antes en main.dart).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../../config/routing/router.dart';
import '../../core/auth/auth_state.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/core/themes/cognitive_theme.dart';
import '../../ui/core/widgets/strings.dart';

Future<void> bootstrap() async {
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
