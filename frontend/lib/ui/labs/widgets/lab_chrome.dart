// Cabecera común de labs: pasos + LabHeader + helpers.
import 'package:flutter/material.dart';

import '../view_models/lab_session.dart';

/// Pasos del lab (misma cabecera en los 3 labs: así se blendean).
class LabSteps extends StatelessWidget {
  final int current;
  const LabSteps({super.key, required this.current});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < labStepLabels.length; i++) ...[
          if (i > 0) SizedBox(width: 16, child: Divider(color: cs.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              selected: i == current,
              label: '${labStepLabels[i]}${i == current ? ', paso actual' : i < current ? ', completado' : ''}',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    i < current
                        ? Icons.check_circle
                        : i == current
                            ? Icons.radio_button_checked
                            : Icons.circle_outlined,
                    size: 16,
                    color: i <= current ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    labStepLabels[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == current ? FontWeight.bold : null,
                      color: i <= current ? null : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Miga Ruta > Módulo > Unidad derivada del objetivo (sin hardcodear textos).
String? labCrumb(List<Map<String, dynamic>>? objectives) {
  if (objectives == null || objectives.isEmpty) return null;
  final parts = '${objectives.first['id']}'.split('-');
  if (parts.length >= 2) return 'Módulo ${parts[0]} · Unidad ${parts[1]}';
  return 'Unidad ${objectives.first['id']}';
}

/// Sprint 4: lenguaje de la ruta diagnosticada (nunca etiqueta de inteligencia).
String levelLabel(String level) => switch (level) {
      'needs_foundation' => 'base guiada',
      'guided_practice' => 'práctica guiada',
      'autonomous_challenge' => 'desafío autónomo',
      _ => 'diagnóstico pendiente',
    };

/// Línea de nivel + ayuda usada para la cabecera (null si aún no hay diagnóstico).
String? sessionMeta(LabSession lab) {
  if (lab.level == null || lab.level == 'pending') return null;
  final a = lab.assistance;
  final helps = a == null ? 0 : (a['hints'] ?? 0) + (a['interventions'] ?? 0);
  return 'Ruta: ${levelLabel(lab.level!)} · Ayudas usadas: $helps';
}

/// Cabecera común: objetivo del lab + pasos. Va arriba del contenido propio.
class LabHeader extends StatelessWidget {
  final String objective;
  final int step;
  final String? crumb;
  final String? meta;
  const LabHeader(
      {super.key, required this.objective, required this.step, this.crumb, this.meta});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (crumb != null)
          Text(crumb!, style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
        if (crumb != null) const SizedBox(height: 2),
        Text(objective, style: Theme.of(context).textTheme.titleMedium),
        if (meta != null) ...[
          const SizedBox(height: 2),
          Text(meta!, style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 8),
        LabSteps(current: step),
        const Divider(),
      ],
    );
  }
}

/// Ciclo compartido de un lab: sesión → intento → evaluar → intervenir → postest.
const labStepLabels = ['Aprende el concepto', 'Prueba tu hipótesis', 'Explica lo que observaste', 'Aplica sin ayuda'];

