// Misión «Limpia y verifica»: una decisión por fila marcada y la tabla
// resultante con comprobaciones (simulación client-side; no toca datos).
import 'package:flutter/material.dart';

import 'cleaning_preview.dart';
import 'data_missions.dart';

class CleaningBench extends StatelessWidget {
  final List columns;
  final List rows;
  final Set<int> flagged;
  final Map<String, String> cellTypes;
  final Map<String, String> actions;
  final bool readOnly;
  final void Function(int id, String action) onAction;

  const CleaningBench({
    super.key,
    required this.columns,
    required this.rows,
    required this.flagged,
    required this.cellTypes,
    required this.actions,
    required this.onAction,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ids = flagged.toList()..sort();
    final pv = cleanedPreview(rows, flagged, cellTypes, actions);
    final stillF = pv.rows.where((r) => r['unit'] == 'F').length;
    final stillMissing = pv.rows.where((r) => r['pressure'] == null).length;
    final checks = [
      ('Filas finales', '${pv.rows.length} de ${rows.length}'),
      ('Eliminadas', '${pv.removed}'),
      ('Reparadas', '${pv.converted}'),
      ('Temperaturas aún en °F', '$stillF'),
      ('Presiones aún ausentes', '$stillMissing'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Decide qué hacer con cada fila', style: tt.titleMedium),
        const SizedBox(height: 8),
        for (final id in ids)
          Container(
            key: ValueKey('clean_row_$id'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: 'Fila $id  ',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: anomalyTypeLabels[cellTypes['$id']] ?? 'sospechosa',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ])),
                ),
                // Desplazable en móvil: los 4 segmentos no caben en 360 px.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    key: ValueKey('clean_action_$id'),
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      for (final e in cleaningActionLabels.entries)
                        ButtonSegment(value: e.key, label: Text(e.value)),
                    ],
                    selected: {actions['$id'] ?? 'revisar'},
                    onSelectionChanged: readOnly ? null : (s) => onAction(id, s.first),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text('Verificación de la tabla resultante', style: tt.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (k, v) in checks)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(v, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(k, style: tt.bodySmall),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Simulación en tu navegador: no modifica los datos. «Imputar media» usa la '
          'media de todas las presiones registradas, incluidas las extremas.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
