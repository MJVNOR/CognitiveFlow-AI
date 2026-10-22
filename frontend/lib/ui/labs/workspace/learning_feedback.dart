// Feedback descriptivo tras la evaluación: qué hiciste bien, qué evidencia
// falta, qué volver a investigar y qué experimento sigue. Las puntuaciones
// Jev/mock existen, pero solo dentro de «Detalle de la rúbrica».
import 'package:flutter/material.dart';

import '../../../utils/criteria.dart' show criterionLabel;
import '../../core/motion.dart';

class LearningFeedbackView extends StatelessWidget {
  final Map<String, dynamic> evalResult;

  /// Feedback del backend `{fortaleza, brecha, texto, provider}`. Sus ids
  /// mandan (coherencia entre bloques); `texto` solo si lo redactó Gemini,
  /// porque el mock solo repite fortaleza y brecha.
  final Map? feedback;

  /// Evidencia concreta del lab (p. ej. «Clasificaste bien la fila 25»).
  final String? strengthEvidence;
  final String? gapEvidence;
  final String? revisit;
  final String nextExperiment;
  final VoidCallback? onRetry;

  const LearningFeedbackView({
    super.key,
    required this.evalResult,
    required this.nextExperiment,
    this.feedback,
    this.strengthEvidence,
    this.gapEvidence,
    this.revisit,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final r = evalResult;
    final isJev = r['evaluator'] == 'jev';
    if (r['status'] == 'pending') {
      return _Block(
        icon: Icons.hourglass_empty,
        color: cs.onSurfaceVariant,
        title: isJev ? 'Evaluación Jev pendiente' : 'Evaluación pendiente',
        body: 'El evaluador no devolvió diagnóstico'
            '${r['reason'] != null ? ' (${r['reason']})' : ''}. '
            'No es una nota: tu intento está guardado.',
        trailing: onRetry == null
            ? null
            : TextButton(onPressed: onRetry, child: const Text('Reintentar evaluación')),
      );
    }
    final crits = [for (final c in (r['criteria'] as List? ?? const [])) Map.of(c as Map)]
      ..sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));
    final best = feedback?['fortaleza'] ?? (crits.isEmpty ? null : crits.first['id']);
    final worst = feedback?['brecha'] ?? (crits.length > 1 ? crits.last['id'] : null);
    final gemini = feedback?['provider'] == 'gemini' ? '${feedback?['texto'] ?? ''}' : '';
    final blocks = <Widget>[
      _Block(
        icon: Icons.check_circle_outline,
        color: cs.primary,
        title: 'Qué hiciste bien',
        body: [
          if (best != null) criterionLabel('$best'),
          ?strengthEvidence,
          if (gemini.isNotEmpty) gemini,
        ].join('. '),
      ),
      _Block(
        icon: Icons.search,
        color: cs.secondary,
        title: 'Qué evidencia falta',
        body: [
          if (worst != null) 'A reforzar: ${criterionLabel('$worst')}',
          ?gapEvidence,
        ].join('. '),
      ),
      if (revisit != null && revisit!.isNotEmpty)
        _Block(
          icon: Icons.help_outline,
          color: cs.tertiary,
          title: 'Qué volver a investigar',
          body: revisit!,
        ),
      _Block(
        icon: Icons.auto_awesome_outlined,
        color: cs.primary,
        title: 'Tu siguiente experimento',
        body: nextExperiment,
      ),
    ];
    return Column(
      key: const ValueKey('learning_feedback'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: blocks[i].enterNote(context, ValueKey('fb-$i-${r['attempt_id']}'),
                delay: Motion.stagger * i),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const ValueKey('rubric_detail'),
            tilePadding: EdgeInsets.zero,
            title: Text('Detalle de la rúbrica', style: tt.titleSmall),
            subtitle: Text(
              '${isJev ? 'Evaluación Jev' : 'Evaluación simulada (mock)'}'
              '${r['rubric_version'] != null ? ' · ${r['rubric_version']}' : ''}',
              style: tt.bodySmall,
            ),
            children: [
              for (final c in crits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon((c['score'] as num) >= 2 ? Icons.check : Icons.remove,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(child: Text(criterionLabel('${c['id']}'))),
                    Text('${c['score']} / 4',
                        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                    'Evidencia orientativa, no una nota de dominio. '
                    'El dominio se demuestra en la prueba sin ayuda.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? trailing;
  const _Block({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body.isEmpty ? '—' : body, style: const TextStyle(height: 1.4)),
                ?trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
