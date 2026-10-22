// Figura isométrica del concepto: una o varias variantes comparables, con su
// leyenda como texto (seleccionable, traducible) y descripción para lector.
// El raster se genera con `node figures/shoot.mjs` (clear/oscuro).
// El dibujo va sobre papel de plano; la leyenda queda en superficie limpia.
import 'package:flutter/material.dart';

import '../../core/widgets/bench_plate.dart';
import 'lab_figures.dart';

// El recorte generado respira dentro de su caja (602x365): se acota la altura
// para que el experimento no quede bajo el pliegue en pantallas de 768 px.
const double _figureMaxHeight = 232;

class ConceptFigure extends StatelessWidget {
  final LabFigure figure;
  const ConceptFigure({super.key, required this.figure});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(figure.title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560 && figure.variants.length > 1;
            final tiles = [
              for (final variant in figure.variants)
                _VariantTile(variant: variant, dark: dark),
            ];
            if (!wide) return Column(children: tiles);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: tiles[i]),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _VariantTile extends StatelessWidget {
  final LabFigureVariant variant;
  final bool dark;
  const _VariantTile({required this.variant, required this.dark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DraftPaper(
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            height: _figureMaxHeight,
            width: double.infinity,
            child: Image.asset(
              '${variant.asset}-${dark ? 'dark' : 'light'}.webp',
              fit: BoxFit.contain,
              semanticLabel: variant.alt,
              excludeFromSemantics: false,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          variant.caption,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
