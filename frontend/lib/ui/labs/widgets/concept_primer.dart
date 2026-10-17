// Microlección del objetivo antes del reto (Sprint 1): concepto siempre
// visible + ejemplo resuelto colapsable para avanzados.
// Extraído de features/ml_lab_page.dart sin cambios; lo usan los 4 labs.
import 'package:flutter/material.dart';

import '../../core/widgets/chrome.dart';

class ConceptPrimer extends StatelessWidget {
  final Map<String, dynamic> objective;
  const ConceptPrimer({super.key, required this.objective});
  @override
  Widget build(BuildContext context) {
    final steps =
        (objective['worked_example_steps'] as List?)?.cast<String>() ?? [];
    return SectionCard(
      icon: Icons.menu_book_outlined,
      title: 'El concepto en 1 minuto',
      children: [
        Text('${objective['title'] ?? ''}',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
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
