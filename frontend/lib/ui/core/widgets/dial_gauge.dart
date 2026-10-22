// Cuadrante de taller: la aguja es el estado, el número es el texto.
// Se puede leer sin color (el valor va escrito) y el lector de pantalla
// recibe una frase completa; la aguja solo refuerza.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';

class DialGauge extends StatelessWidget {
  /// Progreso 0..1. Fuera de rango se recorta (nunca aguja imposible).
  final double value;
  final String readout;
  final String semanticLabel;
  final double size;
  final Color? accent;
  final Color? track;
  const DialGauge({
    super.key,
    required this.value,
    required this.readout,
    required this.semanticLabel,
    this.size = 96,
    this.accent,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = accent ?? cs.primary;
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: v),
            duration: Motion.at(context, const Duration(milliseconds: 900)),
            curve: Motion.curveOf(context),
            builder: (context, animated, _) => Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _GaugePainter(
                    value: animated,
                    accent: ac,
                    track: track ?? cs.outlineVariant.withValues(alpha: 0.8),
                    ticks: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.52,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        readout,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: size * 0.26,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Aguja abierta abajo (150° → 390°): el hueco inferior aloja la lectura.
const double _start = 5 * math.pi / 6;
const double _sweep = 4 * math.pi / 3;

class _GaugePainter extends CustomPainter {
  final double value;
  final Color accent;
  final Color track;
  final Color ticks;
  const _GaugePainter({
    required this.value,
    required this.accent,
    required this.track,
    required this.ticks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final stroke = size.shortestSide * 0.05;
    // La escala sobresale del arco: se reserva su sitio para no recortarla.
    final r = size.shortestSide / 2 - stroke * 2.4;
    final rect = Rect.fromCircle(center: c, radius: r);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweep, false, base);

    if (value > 0) {
      final live = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = accent;
      canvas.drawArc(rect, _start, _sweep * value, false, live);
    }

    // Marcas de escala: se leen como instrumento, no como adorno.
    final tickPaint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = ticks;
    for (var i = 0; i <= 10; i++) {
      final a = _start + _sweep * i / 10;
      final dir = Offset(math.cos(a), math.sin(a));
      final long = i % 5 == 0;
      canvas.drawLine(
        c + dir * (r + stroke * 0.5),
        c + dir * (r + stroke * (long ? 1.35 : 0.95)),
        tickPaint,
      );
    }

    // Índice corto sobre el aro: nunca cruza la lectura central.
    final a = _start + _sweep * value;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      c + dir * (r * 0.58),
      c + dir * (r * 0.86),
      Paint()
        ..strokeWidth = math.max(2.2, size.shortestSide * 0.03)
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
    canvas.drawCircle(
      c + dir * (r * 0.86),
      math.max(1.4, size.shortestSide * 0.016),
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value ||
      old.accent != accent ||
      old.track != track ||
      old.ticks != ticks;
}
