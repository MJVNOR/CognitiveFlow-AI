// Microlección del objetivo antes del reto: concepto, ejemplo resuelto (casos
// con su decisión y su porqué) y errores comunes, todo a la vista: el tutor y
// el experimento remiten a ellos. Si el objetivo tiene figura isométrica
// (`labFigures`), va entre el título y el resumen.
import 'package:flutter/material.dart';

import '../../core/widgets/bench_plate.dart';
import 'concept_figure.dart';
import 'lab_figures.dart';

class ConceptPrimer extends StatelessWidget {
  final Map<String, dynamic> objective;
  const ConceptPrimer({super.key, required this.objective});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tt = theme.textTheme;
    final steps =
        (objective['worked_example_steps'] as List?)?.cast<String>() ?? [];
    final errors = (objective['misconceptions'] as List?)?.cast<String>() ?? [];
    final figure = labFigures[objective['id'] as String?];
    // Código legible («Unidad D01»), nunca el id interno del objetivo.
    final unit = RegExp(r'D\d\d').firstMatch('${objective['id'] ?? ''}')?.group(0);
    Widget heading(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(t, style: tt.titleSmall),
        );
    return BenchPlate(
      code: unit == null ? 'Concepto' : 'Unidad $unit',
      title: 'El concepto en 1 minuto',
      accent: theme.colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${objective['title'] ?? ''}', style: tt.titleSmall),
          if (figure != null) ...[
            const SizedBox(height: 10),
            ConceptFigure(figure: figure),
          ],
          const SizedBox(height: 6),
          Text('${objective['concept_summary'] ?? ''}'),
          if (steps.isNotEmpty) ...[
            heading('Ejemplo resuelto: así se decide'),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 24, child: Text('${i + 1}.', style: tt.bodyMedium)),
                  Expanded(child: Text(steps[i], style: tt.bodyMedium)),
                ]),
              ),
          ],
          if (errors.isNotEmpty) ...[
            heading('Errores comunes (el experimento los pone a prueba)'),
            for (final e in errors)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.close, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Falso: «$e»', style: tt.bodyMedium)),
                ]),
              ),
          ],
        ],
      ),
    );
  }
}
