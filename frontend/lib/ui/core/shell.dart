// Shell de navegación + toggle de tema (antes en main.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../ui/core/themes/cognitive_theme.dart';
import '../../ui/core/widgets/strings.dart';

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

/// Marco de la app: solo una barra superior. La Academia es el punto de
/// partida (labs y progreso viven ahí); sin barra lateral ni inferior.
class Shell extends ConsumerWidget {
  final String location;
  final Widget child;
  const Shell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> logout() async {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }

    final auth = ref.watch(authProvider);
    final isInstructor = auth?.isStudent == false;
    final home = isInstructor ? '/instructor' : '/academy';
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: Semantics(
          link: true,
          label: 'Ir al inicio',
          child: InkWell(
            key: const ValueKey('nav_home'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => context.go(home),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.hub_outlined, color: cs.primary),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(Strings.appTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          if (isInstructor)
            IconButton(
              key: const ValueKey('nav_instructor'),
              tooltip: 'Panel de seguimiento',
              icon: Icon(location.startsWith('/instructor') ? Icons.person : Icons.person_outline),
              onPressed: () => context.go('/instructor'),
            ),
          if (auth != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: auth.isStudent ? 'Estudiante ${auth.userId}' : 'Instructor ${auth.userId}',
                child: CircleAvatar(
                  key: const ValueKey('nav_profile'),
                  radius: 16,
                  backgroundColor: cs.primaryContainer,
                  child: Text(auth.userId.toUpperCase(),
                      style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer)),
                ),
              ),
            ),
          const ThemeToggleButton(),
          IconButton(
            key: const ValueKey('nav_logout'),
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: child,
    );
  }
}
