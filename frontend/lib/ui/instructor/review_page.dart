import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/instructor/view_models/instructor_viewmodel.dart';
import '../../ui/core/widgets/chrome.dart';

// E5: el instructor solo lee evidencia; la evaluación automática vive en
// el resumen y la matriz. Sin sliders, notas ni guardado (rol readonly).

class SessionReviewPage extends ConsumerWidget {
  final String sessionId;
  const SessionReviewPage({super.key, required this.sessionId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionAttemptsViewModelProvider(sessionId));
    return Scaffold(
      appBar: const DoubleTitleBar(
          title: 'Evidencia de la sesión', backRoute: '/instructor'),
      body: switch (async) {
        AsyncLoading() => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Cargando intentos…'),
              ],
            ),
          ),
        AsyncError(:final error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                      liveRegion: true,
                      child: Text('No se pudieron cargar los intentos: $error',
                          textAlign: TextAlign.center)),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => ref
                        .read(sessionAttemptsViewModelProvider(sessionId)
                            .notifier)
                        .refresh(),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        AsyncData(:final value) => Builder(builder: (context) {
          final attempts = value;
          if (attempts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Sin intentos todavía en esta sesión.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          final n = attempts.length;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    icon: Icons.visibility_outlined,
                    accent: Theme.of(context).colorScheme.tertiary,
                    title: n == 1 ? '1 intento (solo lectura)' : '$n intentos (solo lectura)',
                    children: const [
                      Text('La evaluación automática vive en el resumen y la matriz; aquí solo se lee evidencia.'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final a in attempts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AttemptEvidenceCard(
                        key: ValueKey(a.id),
                        answer: a.answer,
                      ),
                    ),
                  StatusText(''),
                ],
              ),
            ),
          );
        }),
      },
    );
  }
}

/// Evidencia de solo lectura (el instructor no califica ni comenta).
class AttemptEvidenceCard extends StatelessWidget {
  final String answer;
  const AttemptEvidenceCard({super.key, required this.answer});
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Respuesta del estudiante', style: text.labelMedium),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(answer, style: text.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
