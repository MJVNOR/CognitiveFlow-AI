import 'package:flutter/material.dart';

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
  });

  /// Avance de 0 a 1.
  final double value;

  /// Texto que anuncia el avance al lector de pantalla.
  final String label;

  @override
  State<RouteProgressBar> createState() => _RouteProgressBarState();
}

class _RouteProgressBarState extends State<RouteProgressBar>
    with SingleTickerProviderStateMixin {
  static const _height = 8.0;
  static const _sweep = Duration(milliseconds: 600);
  static const _retarget = Duration(milliseconds: 320);
  static const _curve = Cubic(0.16, 1, 0.3, 1);

  late final AnimationController _controller;
  late Animation<double> _fill;
  late double _target;

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
                    _fillBar(cs, _clamped)
                  else
                    AnimatedBuilder(
                      animation: _fill,
                      builder: (context, _) => _fillBar(cs, _fill.value),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fillBar(ColorScheme cs, double value) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: value,
          heightFactor: 1,
          child: ColoredBox(color: cs.primary),
        ),
      );
}
