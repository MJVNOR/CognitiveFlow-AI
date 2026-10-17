import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_state.dart';
import '../../data/repositories/auth_repository.dart';
import '../../ui/core/widgets/chrome.dart';
import '../../ui/core/widgets/strings.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginPage> {
  final userId = TextEditingController(text: 's1');
  String status = '';
  bool busy = false;

  @override
  void dispose() {
    userId.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = userId.text.trim();
    if (id.isEmpty) {
      setState(() => status = 'Escribe tu user_id demo (p. ej. s1).');
      return;
    }
    if (busy) return;
    setState(() {
      busy = true;
      status = '';
    });
    try {
      final creds = await login(id);
      await ref.read(authProvider.notifier).login(
            creds.token,
            creds.userId,
            creds.role,
          );
      if (mounted) context.go('/academy');
    } catch (e) {
      final msg = '$e';
      setState(() => status = msg.contains('usuario desconocido')
          ? 'No se pudo entrar: usuario desconocido (usa s1-s4 o i1).'
          : 'No se pudo entrar: sin conexión con la API. Reintenta.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: const Text(Strings.appTitle,
              maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Strings.loginHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('login_user'),
                      controller: userId,
                      enabled: !busy,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: Strings.loginUserId),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('login_submit'),
                      onPressed: busy ? null : _login,
                      child: busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(Strings.loginEnter),
                    ),
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, size: 20, color: scheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: StatusText(status),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

