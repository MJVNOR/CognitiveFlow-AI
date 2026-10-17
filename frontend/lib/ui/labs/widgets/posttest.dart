// Postest: banner + confirmación + labels de estado.
import 'package:flutter/material.dart';

import '../view_models/lab_session.dart';

/// Aviso de bloqueo de postest, idéntico en los 3 labs.
class PosttestBanner extends StatelessWidget {
  const PosttestBanner({super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Modo postest — sin pistas, sin tutor, sin evaluación hasta entregar.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// P1: el postest es irreversible (bloquea eval/tutor, fija variante del
// servidor). Confirmación única compartida por los 3 labs.
Future<void> confirmEnterPosttest(BuildContext context, LabSession lab,
    void Function(void Function()) setState, Future<void> Function() reload,
    [void Function()? onVariant]) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('¿Entrar al postest?'),
      content: const Text(
          'Se bloquea la evaluación y el tutor, y cambia a una variante nueva. '
          'Tu intento actual queda guardado. No podrás volver.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Seguir practicando')),
        FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Ir al postest')),
      ],
    ),
  );
  if (ok == true) await enterPosttest(lab, setState, reload, onVariant);
}

String labStatusLabel(String? status) => switch (status) {
      'active' => 'En curso',
      'posttest' => 'Postest sin ayuda',
      'done' => 'Completado',
      _ => 'No iniciado',
    };
