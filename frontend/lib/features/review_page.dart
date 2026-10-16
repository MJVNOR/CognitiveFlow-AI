import 'package:flutter/material.dart';

import '../models/models.dart';
import '../session/lab_session.dart';
import '../widgets/cards.dart';
import '../widgets/theme.dart';

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
  late Future<List<Attempt>> _future;
  @override
  void initState() {
    super.initState();
    _future = fetchAttempts(widget.sessionId);
  }

  void _retry() => setState(() => _future = fetchAttempts(widget.sessionId));

  Future<void> _send(String attemptId, Map<String, double> scores, String notes) async {
    try {
      await postJson('/instructor/attempts/$attemptId/reviews', {
        'rubric_scores': {for (final e in scores.entries) e.key: e.value.round()},
        'notes': notes,
      });
      setState(() => status = 'Revisión guardada');
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DoubleTitleBar(
          title: 'Revisar intentos', backRoute: '/instructor'),
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
                    icon: Icons.rate_review_outlined,
                    accent: Theme.of(c).colorScheme.tertiary,
                    title: n == 1 ? '1 intento por revisar' : '$n intentos por revisar',
                    children: const [
                      Text('Valora cada criterio de 0 a 4 y guarda la revisión.'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final a in attempts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AttemptReviewCard(
                        key: ValueKey(a.id),
                        answer: a.answer,
                        onSave: (scores, notes) => _send(a.id, scores, notes),
                      ),
                    ),
                  StatusText(status),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ponytail: per-attempt state; shared map+controller contaminated grades across cards.
class AttemptReviewCard extends StatefulWidget {
  final String answer;
  final Future<void> Function(Map<String, double> scores, String notes) onSave;
  const AttemptReviewCard({super.key, required this.answer, required this.onSave});
  @override
  State<AttemptReviewCard> createState() => _AttemptReviewCardState();
}

class _AttemptReviewCardState extends State<AttemptReviewCard> {
  late Map<String, double> scores;
  late TextEditingController notes;
  bool _saving = false;
  bool _saved = false;
  String? _error;
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saved = false;
      _error = null;
    });
    try {
      await widget.onSave(scores, notes.text);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
              child: Text(widget.answer, style: text.bodyMedium),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('Rúbrica (0–4 por criterio)', style: text.labelMedium),
            const SizedBox(height: 8),
            for (final crit in reviewCriteria)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(criterionLabel(crit),
                                style: text.bodyMedium)),
                        Chip(
                          label: Text('${scores[crit]!.round()}',
                              style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    Slider(
                      value: scores[crit]!, min: 0, max: 4, divisions: 4,
                      label: '${criterionLabel(crit)}: ${scores[crit]!.round()} de 4',
                      onChanged: (v) => setState(() {
                        scores[crit] = v;
                        _saved = false;
                      }),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notas', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando…' : 'Guardar revisión'),
                  ),
                ),
                if (_saved) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle,
                      size: 18, color: CognitiveColors.success),
                  const SizedBox(width: 4),
                  Text('Guardada', style: text.bodySmall),
                ],
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: text.bodySmall?.copyWith(color: cs.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

