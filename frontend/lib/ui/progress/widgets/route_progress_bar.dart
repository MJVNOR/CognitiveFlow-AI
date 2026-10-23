import 'package:flutter/material.dart';
import '../../core/motion.dart';

/// Barra de avance de la ruta de laboratorios.
///
/// Se llena una sola vez al aparecer —el recorrido ya ganado, no un "cargando"
/// infinito— y si el avance cambia retoma desde su posición actual en lugar de
/// reiniciar. Con movimiento reducido muestra el valor final sin animar.
class RouteProgressBar extends StatefulWidget {
  const RouteProgressBar({
    super.key,
    required this.value,
    required this.label,
    this.steps,
  });

  /// Avance de 0 a 1.
  final double value;

  /// Texto que anuncia el avance al lector de pantalla.
  final String label;

  /// Marcas de misiones reales; null conserva la barra continua de la ruta.
  final int? steps;

  @override
  State<RouteProgressBar> createState() => _RouteProgressBarState();
}

class _RouteProgressBarState extends State<RouteProgressBar>
    with SingleTickerProviderStateMixin {
  static const _height = 16.0;
  static const _sweep = Motion.base;
  static const _retarget = Motion.mission;
  static const _curve = Motion.mechanical;

  late final AnimationController _controller;
  late Animation<double> _fill;
  late double _target;
  bool _closing = false;

  double get _clamped => widget.value.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _target = _clamped;
    _controller = AnimationController(vsync: this, duration: _sweep);
    _fill = Tween<double>(begin: 0, end: _target)
        .animate(CurvedAnimation(parent: _controller, curve: _curve));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant RouteProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _clamped;
    if (next == _target) return;
    _closing = next == 1 && _target < 1;
    _fill = Tween<double>(begin: _fill.value, end: next)
        .animate(CurvedAnimation(parent: _controller, curve: _curve));
    _target = next;
    _controller
      ..duration = _retarget
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percent = (_clamped * 100).round();
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      label: widget.label,
      value: '$percent%',
      child: ExcludeSemantics(
        child: SizedBox(
          height: _height,
          child: Container(
            // El borde define el recorrido completo: sin él la pista clara
            // se pierde sobre el fondo de la página.
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(_height / 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_height / 2),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: cs.surfaceContainerHighest),
                  if (reduce)
                    _track(cs, _clamped, _clamped == 1 ? 1 : 0)
                  else
                    AnimatedBuilder(
                      animation: _fill,
                      builder: (context, _) => _track(cs, _fill.value,
                          _target == 1 ? (_closing ? _controller.value : 1) : 0),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _track(ColorScheme cs, double value, double closing) => Stack(
        fit: StackFit.expand,
        children: [
          _fillBar(cs, value),
          if (widget.steps != null && widget.steps! > 0)
            CustomPaint(
              key: const ValueKey('progress-milestones'),
              painter: _MilestonesPainter(
                steps: widget.steps!,
                value: value,
                closing: closing,
                scheme: cs,
                rtl: Directionality.of(context) == TextDirection.rtl,
              ),
            ),
        ],
      );

  Widget _fillBar(ColorScheme cs, double value) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: DecoratedBox(
            key: const ValueKey('goal-progress-fill'),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(_height / 2),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 2, 3, 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.onPrimary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Pequeñas muescas de un instrumento: cada una corresponde a una misión.
/// El último punto se convierte en check al cerrar el recorrido; un solo ticker.
class _MilestonesPainter extends CustomPainter {
  const _MilestonesPainter({required this.steps, required this.value,
    required this.closing, required this.scheme, required this.rtl});
  final int steps;
  final double value;
  final double closing;
  final ColorScheme scheme;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 16) return;
    final count = steps.clamp(1, 20);
    final paint = Paint()..strokeWidth = 1.2;
    final y = size.height / 2;
    double position(int i) {
      final x = (size.width * i / count).clamp(8.0, size.width - 8);
      return rtl ? size.width - x : x;
    }
    for (var i = 1; i <= count; i++) {
      if (i < count && size.width / count < 12) continue;
      final reached = value + 0.0001 >= i / count;
      paint
        ..style = reached ? PaintingStyle.fill : PaintingStyle.stroke
        ..color = reached ? scheme.onPrimary : scheme.outline;
      canvas.drawCircle(Offset(position(i), y), i == count ? 4.5 : 2, paint);
    }
    if (closing <= 0) return;
    final x = position(count);
    paint
      ..style = PaintingStyle.fill
      ..color = scheme.onPrimary;
    canvas.drawCircle(Offset(x, y), 5.5, paint);
    final check = Path()
      ..moveTo(x - 3, y)
      ..lineTo(x - 0.7, y + 2.2)
      ..lineTo(x + 3.2, y - 2.4);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = scheme.primary;
    final metric = check.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * closing), paint);
  }

  @override
  bool shouldRepaint(_MilestonesPainter old) => old.steps != steps ||
      old.value != value || old.closing != closing || old.scheme != scheme || old.rtl != rtl;
}
