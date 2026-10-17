// Panel compartido: evaluación + socrática + siguiente intervención GenUI.
import 'package:flutter/material.dart';

import '../../core/widgets/strings.dart';
import '../../tutor/tutor_surface.dart';
import '../../../utils/criteria.dart' show criterionLabel;
import '../view_models/lab_session.dart';

//// Panel compartido: evaluación + socrática + siguiente intervención GenUI.
/// Siempre visible tras el primer envío, con estados (nunca vacío silencioso).
class ResultPanel extends StatelessWidget {
  final LabSession lab;
  final VoidCallback onNext;
  final VoidCallback onRetry;

  /// Eventos GenUI → backend (los emite el ViewModel de la página).
  final Future<void> Function(
      String widgetType, String eventType, Map<String, Object?> payload)? onEvent;
  const ResultPanel({
    super.key,
    required this.lab,
    required this.onNext,
    required this.onRetry,
    this.onEvent,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // P1: estado vacío diseñado — reserva el espacio en desktop antes del envío.
    if (!lab.evaluating &&
        lab.evalError == null &&
        lab.evalResult == null &&
        lab.intervention == null &&
        lab.socraticQ.isEmpty &&
        lab.tutorHistory.isEmpty &&
        lab.nextError == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Aquí verás tu evidencia y el siguiente paso.',
              style: TextStyle(fontSize: 12)),
          SizedBox(height: 4),
          Text('Envía tu intento para empezar.',
              style: TextStyle(fontSize: 12)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lab.evaluating)
          const Row(
            children: [
              SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Evaluando…'),
            ],
          ),
        if (lab.evalError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(lab.evalError!, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
        ],
        if (lab.evalResult != null) ...[
          Builder(builder: (context) {
            final r = lab.evalResult!;
            final isJev = r['evaluator'] == 'jev';
            if (r['status'] == 'pending') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(
                      isJev ? 'Evaluación Jev pendiente' : 'Evaluación pendiente',
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jev no devolvió diagnóstico'
                    '${r['reason'] != null ? ': ${r['reason']}' : ''}. '
                    'No es una nota; tu intento está guardado.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
                ],
              );
            }
            final crits = (r['criteria'] as List).cast<Map>();
            crits.sort((a, b) =>
                ((b['score'] as num)).compareTo((a['score'] as num)));
            final summary = crits.isEmpty
                ? null
                : 'Fortaleza: ${criterionLabel('${crits.first['id']}')}'
                    '${crits.length > 1 ? ' · A trabajar: ${criterionLabel('${crits.last['id']}')}' : ''}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Chip(
                      label: Text(
                        isJev ? 'Evaluación Jev' : 'Evaluación simulada',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    for (final c in crits)
                      Chip(
                        avatar: Icon(
                          (c['score'] as num) >= 2
                              ? Icons.check_circle
                              : Icons.error_outline,
                          size: 16,
                        ),
                        label: Text(
                            '${criterionLabel('${c['id']}')} · ${c['score']}',
                            style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (summary != null)
                  Text(summary, style: const TextStyle(fontSize: 12)),
                const Text(
                  'Evidencia orientativa, revisable por tu instructor.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            );
          }),
        ],
        if (lab.socraticQ.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer,
              border: Border.all(color: cs.tertiary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.help_outline,
                        size: 16, color: cs.onTertiaryContainer),
                    const SizedBox(width: 6),
                    Text('¿Qué evidencia respalda tu hipótesis?',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: cs.onTertiaryContainer)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Tutor: ${lab.socraticQ}',
                    style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
        // PR-06: feedback compuesto (solo con texto Gemini; en mock manda el resumen).
        if ((lab.feedback?['texto'] as String?)?.isNotEmpty == true)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.feedback_outlined, size: 16, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('Tu avance',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: cs.primary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${lab.feedback!['texto']}',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (lab.tutorHistory.isNotEmpty)
          ExpansionTile(
            key: const ValueKey('tutor_history'),
            title: Text(
                'Preguntas del tutor (${lab.tutorHistory.length})'),
            children: [
              for (final h in lab.tutorHistory)
                ListTile(
                  dense: true,
                  leading: Icon(
                      h['provider'] == 'gemini'
                          ? Icons.smart_toy_outlined
                          : Icons.help_outline,
                      size: 16),
                  title: Text('${h['question']}',
                      style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
        if (lab.socraticQ.isNotEmpty || lab.tutorHistory.isNotEmpty) ...[
          Builder(builder: (context) {
            // Título accionable desde la intervención real, nunca «Siguiente actividad» a secas.
            final spec = lab.intervention?['widget_parameters'];
            final ivTitle = spec is Map ? '${spec['title'] ?? ''}' : '';
            final ivReason = '${lab.intervention?['reason'] ?? ''}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.tonal(
                  key: const ValueKey('next_activity'),
                  onPressed: lab.nextBusy ? null : onNext,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: SizedBox(
                      width: double.infinity,
                      child: Text(
                          ivTitle.isNotEmpty ? 'Continuar: $ivTitle' : 'Ver mi siguiente actividad',
                          textAlign: TextAlign.center)),
                ),
                if (ivReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Por qué: $ivReason',
                        style: const TextStyle(fontSize: 12)),
                  ),
              ],
            );
          }),
          const Text('La evaluación es evidencia; la actividad sigue con el tutor.',
              style: TextStyle(fontSize: 12)),
        ] else if (lab.evalResult != null &&
            lab.evalResult!['status'] != 'pending' &&
            !lab.evaluating &&
            lab.evalError == null) ...[
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 8),
              Text('Esperando la pregunta del tutor…',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
          TextButton(onPressed: onRetry, child: const Text(Strings.retry)),
        ],
        if (lab.nextBusy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Trayendo actividad…'),
              ],
            ),
          ),
        if (lab.nextError != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(lab.nextError!, style: const TextStyle(fontSize: 12)),
          ),
          TextButton(onPressed: onNext, child: const Text(Strings.retry)),
        ],
        if (lab.intervention != null) ...[
          const SizedBox(height: 8),
          TutorSurface(
            intervention: lab.intervention!,
            onEvent: (wt, et, payload) async {
              try {
                await onEvent?.call(wt, et, payload);
              } catch (_) {}
            },
          ),
        ],
      ],
    );
  }
}
