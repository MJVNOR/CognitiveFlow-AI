import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'view_models/login_viewmodel.dart';
import '../core/widgets/chrome.dart';
import '../core/widgets/strings.dart';

/// View de login (MVVM): solo muestra [LoginUiState] y llama a [LoginViewModel].
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  @override
  ConsumerState<LoginPage> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginPage> {
  final userId = TextEditingController(text: 's1');

  @override
  void dispose() {
    userId.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final creds =
        await ref.read(loginViewModelProvider.notifier).login(userId.text);
    if (creds != null && mounted) context.go('/academy');
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(loginViewModelProvider);
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
                      enabled: !ui.busy,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: Strings.loginUserId),
                      onSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('login_submit'),
                      onPressed: ui.busy ? null : _login,
                      child: ui.busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(Strings.loginEnter),
                    ),
                    if (ui.status.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline, size: 20, color: scheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: StatusText(ui.status),
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
