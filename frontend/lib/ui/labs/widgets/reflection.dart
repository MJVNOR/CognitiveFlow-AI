// Reflexión de cierre + botón al siguiente lab.
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/lab_repository.dart' show fetchLabs;
import '../../../domain/models/models.dart';
import '../../../utils/criteria.dart' show criterionLabel;
import '../view_models/lab_session.dart';

/// Botón al siguiente lab de la ruta (por order_index). Nada que enlazar → texto.
class NextLabButton extends StatefulWidget {
  final String labId;
  const NextLabButton(this.labId, {super.key});
  @override
  State<NextLabButton> createState() => _NextLabButtonState();
}

class _NextLabButtonState extends State<NextLabButton> {
  late final _future = fetchLabs();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Lab>>(
      future: _future,
      builder: (c, s) {
        if (!s.hasData) return const SizedBox.shrink();
        final labs = s.data!;
        final i = labs.indexWhere((l) => l.id == widget.labId);
        if (i < 0 || i + 1 >= labs.length) {
          return const Text('Último lab de la ruta ✓');
        }
        final n = labs[i + 1];
        return FilledButton.tonal(
          key: const ValueKey('next_lab'),
          onPressed: () => context.go(
            '/labs/${n.id}',
            extra: {'lab_type': n.labType, 'title': n.title},
          ),
          child: AutoSizeText('Siguiente lab: ${n.title}',
              maxLines: 1, minFontSize: 12),
        );
      },
    );
  }
}

/// Reflexión de cierre + done + enlace al siguiente lab (postest unificado).
class PosttestReflection extends StatefulWidget {
  final LabSession lab;
  final String labId;
  final VoidCallback onUpdate;
  const PosttestReflection(
      {super.key, required this.lab, required this.labId, required this.onUpdate});
  @override
  State<PosttestReflection> createState() => _PosttestReflectionState();
}

class _PosttestReflectionState extends State<PosttestReflection> {
  final reflection = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    reflection.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => busy = true);
    try {
      await widget.lab.reflect(reflection.text);
    } catch (e) {
      widget.lab.status = 'Error: $e';
    }
    setState(() => busy = false);
    widget.onUpdate();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lab.done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('reflection_text'),
            controller: reflection,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reflexión: ¿qué aprendiste?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('reflection_send'),
            onPressed: busy ? null : _send,
            child: const Text('Enviar reflexión y cerrar'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sesión cerrada. Gracias por tu reflexión.'),
        // P4.5: pico-fin honesto desde deltas reales; sin halago automático.
        if (widget.lab.reflectionSummary != null)
          Builder(builder: (context) {
            final s = widget.lab.reflectionSummary!;
            final mejora = s['mejora'];
            final desafio = s['desafio'];
            if (mejora == null && desafio == null) {
              return const Text(
                  'Todavía sin evidencias para comparar; sigue practicando.',
                  style: TextStyle(fontSize: 13));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mejora != null)
                  Text('Mejora observada: ${criterionLabel('$mejora')} ✓',
                      style: const TextStyle(fontSize: 13)),
                if (desafio != null)
                  Text('Siguiente desafío: ${criterionLabel('$desafio')}',
                      style: const TextStyle(fontSize: 13)),
              ],
            );
          }),
        const SizedBox(height: 8),
        NextLabButton(widget.labId),
      ],
    );
  }
}
