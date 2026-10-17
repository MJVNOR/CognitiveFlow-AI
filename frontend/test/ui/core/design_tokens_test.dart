import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cognitiveflow/ui/core/themes/cognitive_theme.dart';

// Sprint 5: los pares de DESIGN.md §3 cumplen WCAG AA (calculado, no copiado).
double _lum(Color c) {
  double ch(double v) {
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _ratio(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  test('tokens HEX coinciden con DESIGN.md §3', () {
    expect(CognitiveColors.blue, const Color(0xFF2457C5));
    expect(CognitiveColors.teal, const Color(0xFF0F766E));
    expect(CognitiveColors.amber, const Color(0xFFA65B00));
    expect(CognitiveColors.background, const Color(0xFFF8FAFC));
    expect(CognitiveColors.ink, const Color(0xFF0F172A));
    expect(CognitiveColors.inkSecondary, const Color(0xFF475569));
    expect(CognitiveColors.error, const Color(0xFFB42318));
    expect(CognitiveColors.success, const Color(0xFF166534));
  });

  test('texto normal AA 4.5:1 en tema claro', () {
    expect(_ratio(Colors.white, CognitiveColors.blue), greaterThanOrEqualTo(4.5));
    expect(_ratio(Colors.white, CognitiveColors.teal), greaterThanOrEqualTo(4.5));
    expect(_ratio(Colors.white, CognitiveColors.amber), greaterThanOrEqualTo(4.5));
    expect(_ratio(CognitiveColors.ink, Colors.white), greaterThanOrEqualTo(4.5));
    expect(_ratio(CognitiveColors.inkSecondary, Colors.white), greaterThanOrEqualTo(4.5));
    expect(_ratio(Colors.white, CognitiveColors.error), greaterThanOrEqualTo(4.5));
    expect(_ratio(Colors.white, CognitiveColors.success), greaterThanOrEqualTo(4.5));
  });

  test('tema oscuro mantiene contraste útil', () {
    expect(_ratio(CognitiveColors.blueDark, CognitiveColors.surfaceDark),
        greaterThanOrEqualTo(3.0));
    expect(_ratio(CognitiveColors.inkDark, CognitiveColors.surfaceDark),
        greaterThanOrEqualTo(4.5));
    expect(_ratio(CognitiveColors.inkSecondaryDark, CognitiveColors.surfaceDark),
        greaterThanOrEqualTo(4.5));
  });
}
