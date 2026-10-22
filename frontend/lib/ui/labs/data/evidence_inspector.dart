// Inspector de una fila: valores con unidad, contexto de proceso, comparación
// con la mediana y (según misión) clasificación. No sugiere el tipo correcto;
// el veredicto solo aparece después de evaluar.
import 'package:flutter/material.dart';

import '../../core/motion.dart';
import 'data_missions.dart';

enum InspectorMode { explore, classify, readonly }

class EvidenceInspector extends StatelessWidget {
  final Map row;
  final List rows;
  final InspectorMode mode;
  final String? type;

  /// Tras evaluar: la clasificación coincide (true) / no (false).
  final bool? verdict;
  final ValueChanged<String> onType;
  final VoidCallback onClose;

  const EvidenceInspector({
    super.key,
    required this.row,
    required this.rows,
    required this.mode,
    required this.onType,
    required this.onClose,
    this.type,
    this.verdict,
  });

  double? _median(String col) {
    final v = [for (final r in rows) r[col]].whereType<num>().map((e) => e.toDouble()).toList()
      ..sort();
    if (v.isEmpty) return null;
    final m = v.length ~/ 2;
    return v.length.isOdd ? v[m] : (v[m - 1] + v[m]) / 2;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final id = row['id'];
    String unitOf(String c) => switch (c) {
          'temp' => ' °${row['unit'] ?? '?'}',
          'pressure' => ' kPa',
          _ => '',
        };
    Widget value(String label, String c) {
      final v = row[c];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 104, child: Text(label, style: tt.bodySmall)),
          Expanded(
            child: v == null
                ? Text('— valor ausente',
                    style: TextStyle(fontStyle: FontStyle.italic, color: cs.onSurfaceVariant))
                : Text('$v${unitOf(c)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ]),
      );
    }

    Widget compare(String label, String c) {
      final v = row[c];
      final med = _median(c);
      if (v is! num || med == null) {
        return Text('$label: sin valor para comparar',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant));
      }
      final d = v - med;
      return Text(
        '$label ${v.toStringAsFixed(1)} vs mediana ${med.toStringAsFixed(1)} '
        '(${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)})',
        style: tt.bodySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      );
    }

    return Container(
      key: ValueKey('inspector_$id'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Icon(Icons.manage_search, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Fila $id · Línea ${row['line']}',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            IconButton(
              key: const ValueKey('inspector_close'),
              tooltip: 'Cerrar inspector',
              icon: const Icon(Icons.close),
              onPressed: onClose,
            ),
          ]),
          const SizedBox(height: 4),
          value('Temperatura (T1)', 'temp'),
          value('Unidad', 'unit'),
          value('Presión (P1)', 'pressure'),
          value('Línea', 'line'),
          const Divider(height: 20),
          Text('Proceso', style: tt.labelLarge),
          const SizedBox(height: 2),
          Text(
            'La pieza $id pasó por la línea ${row['line']}; T1 midió su temperatura y '
            'P1 su presión antes de escribirse en el registro.',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 10),
          Text('Comparar con el resto', style: tt.labelLarge),
          const SizedBox(height: 2),
          compare('Temperatura', 'temp'),
          compare('Presión', 'pressure'),
          const SizedBox(height: 12),
          if (mode == InspectorMode.explore)
            Text('En la misión «Detecta anomalías» podrás marcar esta fila.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          if (mode == InspectorMode.classify) ...[
            Text('¿Qué observas en esta fila?', style: tt.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in anomalyTypeLabels.entries)
                  ChoiceChip(
                    key: ValueKey('inspector_type_${e.key}'),
                    label: Text(e.value),
                    selected: (type ?? 'sin_anomalia') == e.key,
                    onSelected: (_) => onType(e.key),
                  ),
              ],
            ),
          ],
          if (mode == InspectorMode.readonly && type != null)
            Row(children: [
              Icon(Icons.flag, size: 16, color: cs.secondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Tu clasificación: ${anomalyTypeLabels[type] ?? type}'
                    '${verdict == null ? '' : verdict! ? ' · coincide' : ' · no coincide: vuelve a investigar'}'),
              ),
              if (verdict != null)
                Icon(verdict! ? Icons.check_circle : Icons.error_outline,
                        size: 18, color: verdict! ? cs.primary : cs.error)
                    .enterCheck(context, ValueKey('verdict-$id-$verdict')),
            ]),
        ],
      ),
    );
  }
}
