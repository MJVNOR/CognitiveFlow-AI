// Reflexión de cierre + botón al siguiente lab.
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../utils/criteria.dart' show criterionLabel;
import '../../academy/view_models/academy_viewmodel.dart';
import '../view_models/lab_session_viewmodel.dart';

/// Botón al siguiente lab de la ruta (por order_index). Nada que enlazar → texto.
class NextLabButton extends ConsumerWidget {
  final String labId;
  const NextLabButton(this.labId, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(labsListViewModelProvider);
    return switch (async) {
      AsyncData(:final value) => Builder(builder: (context) {
        final labs = value;
        final i = labs.indexWhere((l) => l.id == labId);
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
      }),
      _ => const SizedBox.shrink(),
    };
  }
}

/// Reflexión de cierre + done + enlace al siguiente lab (postest unificado).
/// MVVM: el envío y errores van al ViewModel del lab ([labId]).
class PosttestReflection extends ConsumerStatefulWidget {
  final LabSession lab;
  final String labId;
  final VoidCallback onUpdate;
  const PosttestReflection(
      {super.key,
      required this.lab,
      required this.labId,
      required this.onUpdate});
  @override
  ConsumerState<PosttestReflection> createState() => _PosttestReflectionState();
}

class _PosttestReflectionState extends ConsumerState<PosttestReflection> {
  final reflection = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    reflection.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final vm = ref.read(labSessionProvider(widget.labId).notifier);
    setState(() => busy = true);
    try {
      await vm.reflect(reflection.text);
    } catch (e) {
      vm.setStatus('Error: $e');
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
