// Microlección del objetivo antes del reto (Sprint 1): concepto siempre
// visible + ejemplo resuelto colapsable para avanzados. Si el objetivo tiene
// figura isométrica (`labFigures`), va entre el título y el resumen.
import 'package:flutter/material.dart';

import '../../core/widgets/chrome.dart';
import 'concept_figure.dart';
import 'lab_figures.dart';

class ConceptPrimer extends StatelessWidget {
  final Map<String, dynamic> objective;
  const ConceptPrimer({super.key, required this.objective});
  @override
  Widget build(BuildContext context) {
    final steps =
        (objective['worked_example_steps'] as List?)?.cast<String>() ?? [];
    final figure = labFigures[objective['id'] as String?];
    return SectionCard(
      icon: Icons.menu_book_outlined,
      title: 'El concepto en 1 minuto',
      children: [
        Text('${objective['title'] ?? ''}',
            style: Theme.of(context).textTheme.titleSmall),
        if (figure != null) ...[
          const SizedBox(height: 10),
          ConceptFigure(figure: figure),
        ],
        const SizedBox(height: 6),
        Text('${objective['concept_summary'] ?? ''}'),
        if (steps.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Ver ejemplo resuelto',
                style: TextStyle(fontSize: 13)),
            children: [
              for (var i = 0; i < steps.length; i++)
                ListTile(
                  dense: true,
                  leading: Text('${i + 1}.'),
                  title:
                      Text(steps[i], style: const TextStyle(fontSize: 13)),
                ),
            ],
          ),
      ],
    );
  }
}
