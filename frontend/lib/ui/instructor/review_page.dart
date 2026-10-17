import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../../data/repositories/instructor_repository.dart' show fetchAttempts;
import '../../ui/core/widgets/chrome.dart';

// E5: el instructor solo lee evidencia; la evaluación automática vive en
// el resumen y la matriz. Sin sliders, notas ni guardado (rol readonly).

class SessionReviewPage extends StatefulWidget {
  final String sessionId;
  const SessionReviewPage({super.key, required this.sessionId});
  @override
  State<SessionReviewPage> createState() => _ReviewState();
}

class _ReviewState extends State<SessionReviewPage> {
  late Future<List<Attempt>> _future;
  @override
  void initState() {
    super.initState();
    _future = fetchAttempts(widget.sessionId);
  }

  void _retry() => setState(() => _future = fetchAttempts(widget.sessionId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DoubleTitleBar(
          title: 'Evidencia de la sesión', backRoute: '/instructor'),
      body: FutureBuilder<List<Attempt>>(
        future: _future,
        builder: (c, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Cargando intentos…'),
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
                    Semantics(
                        liveRegion: true,
                        child: Text('No se pudieron cargar los intentos: ${s.error}',
                            textAlign: TextAlign.center)),
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
          final attempts = s.data!;
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
                    accent: Theme.of(c).colorScheme.tertiary,
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
        },
      ),
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
