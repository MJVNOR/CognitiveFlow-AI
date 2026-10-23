// Tutor contextual (columna derecha / panel plegable). Antes de evaluar:
// orientación, hipótesis, evidencia y pistas graduadas. Después: pregunta
// socrática. Nunca duplica la actividad central ni muestra puntuaciones.
import 'package:flutter/material.dart';

import '../../core/motion.dart';

class TutorEvidence {
  final String label;
  final String detail;
  const TutorEvidence(this.label, this.detail);
}

class ContextualTutorPanel extends StatelessWidget {
  final String guidance;
  final String? hypothesis;
  final List<String> hints;
  final int hintsShown;

  /// null = sin pistas en esta misión.
  final VoidCallback? onHint;

  /// null = esta misión no produce evidencia (sin sección).
  final List<TutorEvidence>? evidence;
  final String? question;
  final String? questionWhy;
  final List<Map<String, dynamic>> history;

  /// Postest: el tutor se calla (sin pistas, sin pregunta, sin feedback).
  final bool locked;

  const ContextualTutorPanel({
    super.key,
    required this.guidance,
    this.hypothesis,
    this.hints = const [],
    this.hintsShown = 0,
    this.onHint,
    this.evidence = const [],
    this.question,
    this.questionWhy,
    this.history = const [],
    this.locked = false,
  });

  /// El backend antepone «Promedio X.X:» para el log del instructor; al
  /// estudiante no se le muestra puntuación antes de pedir detalle.
  String get _why =>
      (questionWhy ?? '').replaceFirst(RegExp(r'^Promedio [\d.,]+:\s*'), '');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (locked) {
      return _Section(
        icon: Icons.lock_outline,
        color: cs.onSurfaceVariant,
        title: 'Tutor en pausa',
        child: const Text(
          'Esta prueba se resuelve sin ayuda: sin pistas, sin preguntas y sin '
          'evaluación hasta que entregues. Así medimos lo que ya dominas.',
        ),
      );
    }
    final shown = hintsShown.clamp(0, hints.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          icon: Icons.explore_outlined,
          color: cs.primary,
          title: 'En este paso',
          child: Text(guidance, style: tt.bodyMedium?.copyWith(height: 1.45)),
        ).enterNote(context, ValueKey('guide-$guidance')),
        if (question != null && question!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('tutor_question'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.tertiary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      size: 18,
                      color: cs.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pregunta del tutor',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  question!,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: cs.onTertiaryContainer,
                  ),
                ),
                if (_why.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Por qué este reto: $_why',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                ],
              ],
            ),
          ).enterNote(context, ValueKey('q-$question')),
        ],
        if (hypothesis != null && hypothesis!.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            icon: Icons.lightbulb_outline,
            color: cs.tertiary,
            title: 'Tu hipótesis',
            child: Text(
              '«${hypothesis!.trim()}»',
              style: tt.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
        if (evidence case final evidence?) ...[
          const SizedBox(height: 16),
          _Section(
            icon: Icons.push_pin_outlined,
            color: cs.secondary,
            title: 'Evidencia seleccionada',
            child: evidence.isEmpty
                ? Text(
                    'Todavía no has seleccionado evidencia.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in evidence)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.flag, size: 14, color: cs.secondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${e.label}  ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(text: e.detail),
                                    ],
                                  ),
                                  style: tt.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
        if (hints.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            icon: Icons.tips_and_updates_outlined,
            color: cs.tertiary,
            title: 'Pistas',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < shown; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${i + 1}. ${hints[i]}',
                      style: tt.bodyMedium?.copyWith(height: 1.4),
                    ).enterNote(context, ValueKey('hint-$i-${hints[i]}')),
                  ),
                if (shown < hints.length && onHint != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('tutor_hint'),
                      onPressed: onHint,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      icon: const Icon(
                        Icons.tips_and_updates_outlined,
                        size: 18,
                      ),
                      label: Text(
                        shown == 0
                            ? 'Pedir una pista'
                            : 'Otra pista (${shown + 1} de ${hints.length})',
                      ),
                    ),
                  ),
                if (shown == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Pedir ayuda no resta: queda registrada para entender tu proceso.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            key: const ValueKey('tutor_history'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Preguntas anteriores (${history.length})',
              style: tt.titleSmall,
            ),
            children: [
              for (final h in history)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline, size: 16),
                  title: Text(
                    '${h['question']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
