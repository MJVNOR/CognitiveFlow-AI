// Escena de la línea de inspección: dos cintas (líneas A/B) con una pieza por
// fila, sensores T1/P1 y el cable hacia el registro (la tabla). Las formas se
// pintan; textos y puntos interactivos son widgets (seleccionables, con foco
// y Semantics). La escena no marca anomalías: solo refleja lo que el
// estudiante selecciona o marcó.
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../core/motion.dart';

class InspectionScene extends StatelessWidget {
  final List rows;
  final String? focusSensor;
  final String? focusLine;
  final int? selectedRow;
  final Set<int> flagged;
  final ValueChanged<String?> onSensor;
  final ValueChanged<String?> onLine;
  final ValueChanged<int> onRow;

  const InspectionScene({
    super.key,
    required this.rows,
    required this.flagged,
    required this.onSensor,
    required this.onLine,
    required this.onRow,
    this.focusSensor,
    this.focusLine,
    this.selectedRow,
  });

  Map? get _selected {
    for (final r in rows) {
      if (r['id'] == selectedRow) return r as Map;
    }
    return null;
  }

  String _reading(String sensor) {
    final r = _selected;
    if (r == null) return sensor == 'temp' ? 'Temperatura' : 'Presión';
    final v = r[sensor];
    if (v == null) return '— sin lectura';
    return sensor == 'temp' ? '$v °${r['unit']}' : '$v kPa';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final g = _SceneGeometry(c.maxWidth, c.maxWidth < 560 ? 220 : 250, rows);
      Widget sensor(String key, String code, IconData icon, double x) {
        final on = focusSensor == key;
        return Positioned(
          left: x - g.sensorW / 2,
          top: g.headTop,
          width: g.sensorW,
          child: Semantics(
            button: true,
            toggled: on,
            label: 'Sensor $code, ${key == 'temp' ? 'temperatura' : 'presión'}. '
                'Lectura: ${_reading(key)}',
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('scene_sensor_$key'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSensor(on ? null : key),
                child: AnimatedContainer(
                  duration: Motion.at(context, Motion.quick),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: on ? cs.secondary : cs.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.secondary, width: on ? 2 : 1.2),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 18, color: on ? cs.onSecondary : cs.secondary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(code,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: on ? cs.onSecondary : cs.secondary)),
                          Text(_reading(key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  color: on ? cs.onSecondary : cs.onSurface)),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        );
      }

      Widget station(String line, double y) {
        final on = focusLine == line;
        return Positioned(
          left: 0,
          top: y - 20,
          width: g.left - 6,
          height: 40,
          child: Semantics(
            button: true,
            toggled: on,
            label: 'Línea $line: resaltar sus piezas en la tabla',
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('scene_line_$line'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => onLine(on ? null : line),
                child: AnimatedContainer(
                  duration: Motion.at(context, Motion.quick),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: on ? cs.primaryContainer : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: on ? cs.primary : cs.outlineVariant, width: on ? 2 : 1),
                  ),
                  child: Text('Línea $line',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: on ? cs.onPrimaryContainer : cs.onSurface)),
                ),
              ),
            ),
          ),
        );
      }

      return SizedBox(
        height: g.h,
        child: Stack(children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              key: ValueKey('$focusSensor|$focusLine|$selectedRow'),
              tween: Tween(begin: 0, end: 1),
              duration: Motion.at(context, Motion.quick),
              builder: (context, t, _) => CustomPaint(
                painter: _ScenePainter(
                  g: g,
                  cs: cs,
                  t: t,
                  focusSensor: focusSensor,
                  focusLine: focusLine,
                  selectedRow: selectedRow,
                  flagged: {...flagged}, // copia: el set del padre es mutable
                ),
              ),
            ),
          ),
          // Registro: destino del cable de los sensores (la tabla de abajo).
          Positioned(
            left: g.logX,
            top: g.headTop,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.table_rows_outlined, size: 18, color: cs.primary),
                Text('Registro',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text('${rows.length} filas',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ),
                  Icon(Icons.arrow_downward, size: 12, color: cs.onSurfaceVariant),
                ]),
              ]),
            ),
          ),
          sensor('temp', 'T1', Icons.thermostat, g.tempX),
          sensor('pressure', 'P1', Icons.speed, g.pressX),
          station('A', g.beltY['A']!),
          station('B', g.beltY['B']!),
          for (final p in g.items.entries)
            Positioned(
              left: p.value.dx - g.itemHit / 2,
              top: p.value.dy - 14,
              width: g.itemHit,
              height: 28,
              child: Semantics(
                button: true,
                selected: p.key == selectedRow,
                label: 'Pieza ${p.key}',
                excludeSemantics: true,
                child: GestureDetector(
                  key: ValueKey('scene_item_${p.key}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onRow(p.key),
                ),
              ),
            ),
          Positioned(
            left: g.left,
            right: 0,
            bottom: 0,
            child: Semantics(
              liveRegion: true,
              child: Text(
                selectedRow == null
                    ? 'Toca un sensor, una línea o una pieza'
                    : 'Pieza $selectedRow seleccionada: su fila y su inspector están en el registro, abajo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: selectedRow == null ? null : FontWeight.w600,
                    color: selectedRow == null ? cs.onSurfaceVariant : cs.primary),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

/// Geometría compartida por el pintor y los puntos interactivos.
/// Sensores lado a lado sobre las cintas (nunca se solapan) y registro a la
/// derecha con ancho fijo; las piezas se reparten según las filas de cada línea.
class _SceneGeometry {
  final double w, h;
  late final double left = (w * 0.13).clamp(64.0, 110.0);
  late final double logW = w < 560 ? 76 : 120;
  late final double logX = w - logW;
  late final double beltEnd = logX - 12;
  late final double sensorW = ((beltEnd - left - 8) / 2).clamp(0.0, 150.0);
  late final double tempX = left + (beltEnd - left) * 0.25;
  late final double pressX = left + (beltEnd - left) * 0.75;
  final double headTop = 8;
  final double headBottom = 52;
  late final Map<String, double> beltY = {'A': h * 0.52, 'B': h * 0.78};
  final items = <int, Offset>{};
  double itemSize = 14;
  double itemHit = 20;

  _SceneGeometry(this.w, this.h, List rows) {
    var minStep = double.infinity;
    for (final line in ['A', 'B']) {
      final ids = [for (final r in rows) if (r['line'] == line) r['id'] as int];
      if (ids.isEmpty) continue;
      // Margen de 24 px: las piezas no pisan los rodillos de los extremos.
      final step = (beltEnd - left - 48) / ids.length;
      if (step < minStep) minStep = step;
      for (var i = 0; i < ids.length; i++) {
        items[ids[i]] = Offset(left + 24 + step * (i + 0.5), beltY[line]!);
      }
    }
    if (minStep.isFinite) {
      itemSize = (minStep - 4).clamp(6.0, 16.0);
      itemHit = minStep.clamp(10.0, 28.0);
    }
  }
}

class _ScenePainter extends CustomPainter {
  final _SceneGeometry g;
  final ColorScheme cs;
  final double t;
  final String? focusSensor;
  final String? focusLine;
  final int? selectedRow;
  final Set<int> flagged;
  _ScenePainter({
    required this.g,
    required this.cs,
    required this.t,
    required this.focusSensor,
    required this.focusLine,
    required this.selectedRow,
    required this.flagged,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final belt = Paint()..color = cs.surfaceContainerHigh;
    final edge = Paint()
      ..color = cs.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    // Cintas con rodillos.
    for (final y in g.beltY.values) {
      final r = RRect.fromLTRBR(g.left, y - 12, g.beltEnd, y + 12, const Radius.circular(12));
      canvas.drawRRect(r, belt);
      canvas.drawRRect(r, edge);
      for (final x in [g.left + 12, g.beltEnd - 12]) {
        canvas.drawCircle(Offset(x, y), 7, Paint()..color = cs.surface);
        canvas.drawCircle(Offset(x, y), 7, edge);
      }
    }
    // Haces de los sensores (bajan sobre ambas cintas) y cable al registro.
    for (final (key, x) in [('temp', g.tempX), ('pressure', g.pressX)]) {
      final on = focusSensor == key;
      final beam = Paint()
        ..color = Color.lerp(cs.outlineVariant, cs.secondary, on ? t : 0)!
        ..strokeWidth = on ? 2.5 : 1.2;
      _dashed(canvas, Offset(x, g.headBottom), Offset(x, g.beltY['B']! + 14), beam);
      final cable = Paint()
        ..color = Color.lerp(cs.outlineVariant, cs.secondary, on ? t : 0)!
        ..strokeWidth = on ? 2.5 : 1.4
        ..style = PaintingStyle.stroke;
      final y = g.headBottom + 10.0 + (key == 'temp' ? 0 : 8);
      canvas.drawPath(
          Path()
            ..moveTo(x, g.headBottom)
            ..lineTo(x, y)
            ..lineTo(g.logX, y),
          cable);
    }
    // Una pieza por fila. Selección = relleno azul + anillo; marca del
    // estudiante = banderín teal. Línea fuera de foco = atenuada.
    for (final e in g.items.entries) {
      final id = e.key;
      final row = e.value;
      final dim = focusLine != null && (row.dy - g.beltY[focusLine]!).abs() > 1;
      final sel = id == selectedRow;
      final s = g.itemSize;
      final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: row, width: s, height: s), const Radius.circular(3));
      final base = cs.secondaryContainer.withValues(alpha: dim ? 0.35 : 1);
      canvas.drawRRect(rect, Paint()..color = sel ? Color.lerp(base, cs.primary, t)! : base);
      canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = sel ? 2 : 1
            ..color = (sel ? cs.primary : cs.secondary).withValues(alpha: dim ? 0.35 : 1));
      if (sel) {
        canvas.drawCircle(
            row,
            s * 0.9 * (0.8 + 0.2 * t),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..color = cs.primary);
      }
      if (flagged.contains(id)) {
        final top = Offset(row.dx + s / 2 - 1, row.dy - s / 2 - 9);
        canvas.drawLine(top, top + const Offset(0, 9), Paint()..color = cs.secondary..strokeWidth = 1.4);
        canvas.drawPath(
            Path()
              ..moveTo(top.dx, top.dy)
              ..lineTo(top.dx + 6, top.dy + 2.5)
              ..lineTo(top.dx, top.dy + 5)
              ..close(),
            Paint()..color = cs.secondary);
      }
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint p) {
    const dash = 5.0, gap = 4.0;
    final len = (b - a).distance;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += dash + gap) {
      canvas.drawLine(a + dir * d, a + dir * (d + dash).clamp(0, len), p);
    }
  }

  @override
  bool shouldRepaint(_ScenePainter o) =>
      o.t != t ||
      o.focusSensor != focusSensor ||
      o.focusLine != focusLine ||
      o.selectedRow != selectedRow ||
      !setEquals(o.flagged, flagged) ||
      o.g.w != g.w ||
      o.cs != cs;
}

