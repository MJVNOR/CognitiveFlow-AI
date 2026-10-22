// Sistema de movimiento "taller": mecánico, amortiguado, sin rebote.
// Un solo lugar para duraciones y curvas; `at()` respeta movimiento reducido.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

abstract final class Motion {
  /// Cambio de estado pequeño (lámpara, aguja, borde, selección de dato).
  static const quick = Duration(milliseconds: 140);

  /// Aparición de contenido dentro de una fase (anotación, pista, panel).
  static const base = Duration(milliseconds: 220);

  /// Cambio de misión / nuevo widget central (220–300 ms).
  static const mission = Duration(milliseconds: 260);

  /// Carga de un banco / cambio de instrumento.
  static const stage = Duration(milliseconds: 320);

  /// Escalón entre bloques de feedback (4 bloques ≤ 450 ms en total).
  static const stagger = Duration(milliseconds: 70);

  /// Amortiguado: llega y se asienta. Sin overshoot (nada de bounce).
  static const mechanical = Cubic(0.2, 0.7, 0.3, 1);

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Duración efectiva: cero cuando el sistema pide reducir movimiento.
  static Duration at(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  static Curve curveOf(BuildContext context) =>
      reduced(context) ? Curves.linear : mechanical;
}

/// Entradas con flutter_animate. Animan una vez por [key] (no en cada
/// rebuild) y con movimiento reducido devuelven el hijo tal cual.
extension MotionEntrances on Widget {
  /// Misión / fase nueva: fade + slideY corto.
  Widget enterMission(BuildContext context, Key key) =>
      _play(context, key, (a) => a
          .fadeIn(duration: Motion.mission, curve: Motion.mechanical)
          .slideY(begin: 0.02, end: 0, duration: Motion.mission, curve: Motion.mechanical));

  /// Anotación / pista / panel: fade + scale 0.98→1.
  Widget enterNote(BuildContext context, Key key, {Duration delay = Duration.zero}) =>
      _play(context, key, (a) => a
          .fadeIn(delay: delay, duration: Motion.base, curve: Motion.mechanical)
          .scale(
              delay: delay,
              begin: const Offset(0.98, 0.98),
              end: const Offset(1, 1),
              duration: Motion.base,
              curve: Motion.mechanical));

  /// Confirmación breve (misión completada, evidencia guardada).
  Widget enterCheck(BuildContext context, Key key) =>
      _play(context, key, (a) => a
          .fadeIn(duration: Motion.quick)
          .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              duration: Motion.base,
              curve: Motion.mechanical));

  Widget _play(BuildContext context, Key key,
      Animate Function(Animate a) effects) {
    if (Motion.reduced(context)) return KeyedSubtree(key: key, child: this);
    return effects(animate(key: key));
  }
}
