// Chrome compartido: StatusText, DoubleTitleBar, SectionCard, ParamSlider.
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Anuncia errores/estados a lectores de pantalla (WCAG 4.1.3).
class StatusText extends StatelessWidget {
  final String status;
  const StatusText(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(status),
      ),
    );
  }
}

/// Segunda fila de la doble barra (diseño como en imagen): título de la
/// vista bajo la AppBar global de marca. No es una AppBar Material más,
/// sino el segundo nivel intencional: misma superficie, solo borde inferior,
/// tipografía un paso menor que la marca y retroceso opcional.
class DoubleTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? backRoute;
  final bool posttest;
  const DoubleTitleBar(
      {super.key, required this.title, this.backRoute, this.posttest = false});

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      padding: EdgeInsets.only(left: backRoute != null ? 4 : 16, right: 16),
      child: Row(
        children: [
          if (backRoute != null)
            IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go(backRoute!),
            ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (posttest)
            Chip(
              avatar: const Icon(Icons.lock_outline, size: 14),
              label: const Text('Postest', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
            ),
        ],
      ),
    );
  }
}

/// Sección reutilizable del ciclo predecir→experimentar→justificar.
/// Un título con icono + cuerpo; el color semántico llega por [accent].
class SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? accent;
  final Widget? trailing;
  final List<Widget> children;
  const SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.accent,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = accent ?? cs.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: ac),
                const SizedBox(width: 8),
                Expanded(
                  child: AutoSizeText(title,
                      maxLines: 1,
                      minFontSize: 12,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: ac)),
                ),
                if (trailing case final Widget t) t,
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Slider de parámetro de laboratorio con etiqueta, valor y ayuda.
/// Teal por defecto (experimentación, DESIGN.md §3); postest usa neutral.
class ParamSlider extends StatelessWidget {
  final String label;
  final String value;
  final String? help;
  final double current;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  const ParamSlider({
    super.key,
    required this.label,
    required this.value,
    required this.current,
    required this.min,
    required this.max,
    required this.divisions,
    this.help,
    this.onChanged,
    this.onChangeEnd,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Chip(
              label: Text(value, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        Slider(
          value: current,
          min: min,
          max: max,
          divisions: divisions,
          label: value,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        if (help != null)
          Text(help!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
