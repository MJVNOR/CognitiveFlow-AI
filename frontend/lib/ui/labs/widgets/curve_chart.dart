// Charts accesibles compartidos (ML + Monitoring). Extraído de ml_lab_page sin cambios.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/strings.dart';

final _num2 = NumberFormat('0.00', 'es');

/// Curva de entrenamiento (continua) vs validación (discontinua).
/// Colores desde el tema — nunca hard-coded — para modo claro/oscuro y
/// diferenciación por estilo además de color (WCAG 1.4.1).
class CurvePainter extends StatelessWidget {
  final List<num> train;
  final List<num> val;
  final Color trainColor;
  final Color valColor;
  final double labelInterval;
  final List<num>? val2;
  final Color? savedColor;

  /// Rango del eje Y (por defecto 0–1: pérdidas) y prefijo del eje X.
  final double minY;
  final double maxY;
  final String xPrefix;

  /// Marca vertical opcional (p. ej. el punto de cambio elegido).
  final double? markerX;
  const CurvePainter(this.train, this.val,
      {super.key,
      required this.trainColor,
      required this.valColor,
      this.labelInterval = 5,
      this.val2,
      this.savedColor,
      this.minY = 0,
      this.maxY = 1,
      this.xPrefix = 'e',
      this.markerX});

  List<FlSpot> _spots(List<num> ys) => [
        for (var i = 0; i < ys.length; i++)
          FlSpot(i.toDouble(), ys[i].toDouble().clamp(minY, maxY)),
      ];

  @override
  Widget build(BuildContext context) {
    if (train.isEmpty && val.isEmpty) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        extraLinesData: markerX == null
            ? null
            : ExtraLinesData(verticalLines: [
                VerticalLine(x: markerX!, color: valColor, strokeWidth: 2, dashArray: [4, 4]),
              ]),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Theme.of(context).colorScheme.outlineVariant,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              // Los extremos fuera del intervalo se encimarían con la marca vecina.
              getTitlesWidget: (v, meta) => (v == meta.max || v == meta.min) &&
                      (v / meta.appliedInterval - (v / meta.appliedInterval).round()).abs() > 1e-6
                  ? const SizedBox.shrink()
                  : Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: labelInterval,
              getTitlesWidget: (v, _) => Text(
                '$xPrefix${v.toInt()}',
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [
          if (train.isNotEmpty)
            LineChartBarData(
              spots: _spots(train),
              isCurved: false,
              color: trainColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          if (val.isNotEmpty)
            LineChartBarData(
              spots: _spots(val),
              isCurved: false,
              color: valColor,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
          if (val2 != null && val2!.isNotEmpty && savedColor != null)
            LineChartBarData(
              spots: _spots(val2!),
              isCurved: false,
              color: savedColor!,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [2, 4],
            ),
        ],
      ),
    );
  }
}

/// Gráfico de curvas con alternativa textual (WCAG 1.1.1) y leyenda sin
/// nombres de color.
// ponytail: sin animaciones propias; solo transiciones M3 por defecto
// (ExpansionTile, navegación), ninguna bloquea tareas ni transmite
// información solo por movimiento.
class AccessibleCurveChart extends StatelessWidget {
  final List<num> train;
  final List<num> val;
  final String label;
  final double height;
  final double labelInterval;
  final List<num>? val2;
  const AccessibleCurveChart({super.key, required this.train, required this.val, required this.label, this.height = 180, this.labelInterval = 5, this.val2});

  String _summary(List<num> ys) {
    if (ys.isEmpty) return 'sin datos';
    final min = ys.reduce((a, b) => a < b ? a : b);
    final max = ys.reduce((a, b) => a > b ? a : b);
    return '${ys.length} puntos, mín ${_num2.format(min)}, máx ${_num2.format(max)}, '
        'último ${_num2.format(ys.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$label. Entrenamiento: ${_summary(train)}. Validación: ${_summary(val)}.',
          child: SizedBox(
            height: height,
            child: CurvePainter(train, val,
                trainColor: cs.primary,
                valColor: cs.tertiary,
                labelInterval: labelInterval,
                val2: val2,
                savedColor: cs.outline),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 24, height: 3, color: cs.primary),
              const SizedBox(width: 6),
              const Flexible(child: Text(Strings.legendTrain, style: TextStyle(fontSize: 12))),
            ]),
            // ponytail: muestra discontinua = redundancia no-cromática (WCAG 1.4.1);
            // la curva real ya usa dashArray [6,4].
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 24,
                child: Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Container(width: 6, height: 3, color: cs.tertiary),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Flexible(child: Text(Strings.legendVal, style: TextStyle(fontSize: 12))),
            ]),
            if (val2 != null && val2!.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 30,
                  child: Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        Container(width: 4, height: 3, color: cs.outline),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text('Corrida guardada (línea punteada)', style: TextStyle(fontSize: 12)),
                ),
              ]),
          ],
        ),
        ExpansionTile(
          title: const Text(Strings.chartDataTable, style: TextStyle(fontSize: 13)),
          tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 44,
                columns: const [
                  DataColumn(label: Text('i')),
                  DataColumn(label: Text('entrenamiento')),
                  DataColumn(label: Text('validación')),
                ],
                rows: [
                  for (var i = 0; i < train.length; i++)
                    DataRow(cells: [
                      DataCell(Text('$i')),
                      DataCell(Text(train[i].toStringAsFixed(3))),
                      DataCell(Text(i < val.length ? val[i].toStringAsFixed(3) : '—')),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Serie temporal de un sensor (unidades reales, no 0–1) con el punto de
/// cambio elegido marcado y alternativa textual + tabla.
class AccessibleSeriesChart extends StatelessWidget {
  final List<num> series;
  final String label;
  final int? marker;
  final double height;
  const AccessibleSeriesChart(
      {super.key, required this.series, required this.label, this.marker, this.height = 200});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (series.isEmpty) return const SizedBox.shrink();
    final lo = series.reduce((a, b) => a < b ? a : b).toDouble();
    final hi = series.reduce((a, b) => a > b ? a : b).toDouble();
    final pad = ((hi - lo) * 0.1).clamp(0.5, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$label: ${series.length} lecturas entre ${_num2.format(lo)} y '
              '${_num2.format(hi)}${marker == null ? '' : '; punto de cambio marcado en t=$marker'}.',
          child: SizedBox(
            height: height,
            child: CurvePainter(series, const [],
                trainColor: cs.primary,
                valColor: cs.tertiary,
                labelInterval: 30,
                minY: (lo - pad).floorToDouble(),
                maxY: (hi + pad).ceilToDouble(),
                xPrefix: 't',
                markerX: marker?.toDouble()),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 16, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 24, height: 3, color: cs.primary),
            const SizedBox(width: 6),
            const Flexible(child: Text('Lectura del sensor', style: TextStyle(fontSize: 12))),
          ]),
          if (marker != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 3, height: 14, color: cs.tertiary),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Punto de cambio (t=$marker, línea vertical)',
                    style: const TextStyle(fontSize: 12)),
              ),
            ]),
        ]),
        ExpansionTile(
          title: const Text(Strings.chartDataTable, style: TextStyle(fontSize: 13)),
          tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 44,
                columns: const [DataColumn(label: Text('t')), DataColumn(label: Text('lectura'))],
                rows: [
                  for (var i = 0; i < series.length; i++)
                    DataRow(cells: [
                      DataCell(Text('$i')),
                      DataCell(Text(series[i].toStringAsFixed(1))),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

