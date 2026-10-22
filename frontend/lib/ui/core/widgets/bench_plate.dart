// Piezas del taller: lámina de plano, lámpara de estado, rótulo y sello.
// Todo texto va en widgets (seleccionable); el trazo solo refuerza lo que el
// texto ya dice. El papel milimetrado es opt-in: solo donde hay un dibujo.
import 'package:flutter/material.dart';

import '../motion.dart';

/// Lámina técnica: banda de rótulo + cuerpo. Envuelve figuras isométricas,
/// registros o listas de puestos; `paper` añade papel milimetrado y esquinas.
class BenchPlate extends StatelessWidget {
  final String code;
  final String? title;
  final String? note;
  final Widget child;
  final EdgeInsets padding;
  final Color? accent;
  final Color? tint;
  const BenchPlate({
    super.key,
    required this.code,
    required this.child,
    this.title,
    this.note,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.accent,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = accent ?? cs.primary;
    final label = TextStyle(
      fontSize: 10,
      height: 1.2,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w600,
      color: cs.onSurfaceVariant,
    );
    return Material(
      color: tint ?? cs.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Container(width: 3, height: 12, color: ac),
                const SizedBox(width: 8),
                Text(code, style: label),
                if (title != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: label.copyWith(
                        color: cs.onSurface,
                        letterSpacing: 0.2,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (note != null)
                  Text(note!, style: label.copyWith(letterSpacing: 0.6)),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Papel milimetrado + esquinas de plano para un dibujo. Estático: no compite
/// con el contenido ni cambia entre temas.
class DraftPaper extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? tint;
  const DraftPaper({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: tint ?? cs.surfaceContainerHighest.withValues(alpha: 0.55),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PaperPainter(
                  line: cs.outlineVariant.withValues(alpha: 0.55),
                  tick: cs.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Papel milimetrado + esquinas de plano (pintado).
class _PaperPainter extends CustomPainter {
  final Color line;
  final Color tick;
  const _PaperPainter({required this.line, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..strokeWidth = 1
      ..color = line.withValues(alpha: 0.5);
    for (var x = 24.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 24.0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final corner = Paint()
      ..strokeWidth = 1.2
      ..color = tick;
    const inset = 6.0;
    const len = 10.0;
    void cornerTick(Offset p, double dx, double dy) {
      canvas.drawLine(p, p + Offset(dx * len, 0), corner);
      canvas.drawLine(p, p + Offset(0, dy * len), corner);
    }

    cornerTick(const Offset(inset, inset), 1, 1);
    cornerTick(Offset(size.width - inset, inset), -1, 1);
    cornerTick(Offset(inset, size.height - inset), 1, -1);
    cornerTick(Offset(size.width - inset, size.height - inset), -1, -1);
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.line != line || old.tick != tick;
}

/// Lámpara de estado: refuerza el texto que siempre va al lado.
class StatusLamp extends StatelessWidget {
  final Color color;
  final bool lit;
  final double size;
  const StatusLamp({
    super.key,
    required this.color,
    this.lit = true,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: Motion.at(context, Motion.quick),
        curve: Motion.curveOf(context),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: lit ? color : Colors.transparent,
          border: Border.all(
            color: lit ? color : cs.onSurfaceVariant.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: lit
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: size * 0.9,
                    spreadRadius: size * 0.15,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

/// Rótulo de estado en seco (sin relleno): el texto manda, el color acompaña.
class PlateTag extends StatelessWidget {
  final String text;
  final Color color;
  const PlateTag({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11,
          height: 1.2,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Sello de dominio (solo cuando el servidor lo declara demostrado).
class MasteryStamp extends StatelessWidget {
  final String text;
  final Color? color;
  const MasteryStamp({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: c, width: 1.5),
          color: c.withValues(alpha: 0.07),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            height: 1.2,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: c,
          ),
        ),
      ),
    );
  }
}
