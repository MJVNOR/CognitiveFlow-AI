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
  const CurvePainter(this.train, this.val,
      {super.key,
      required this.trainColor,
      required this.valColor,
      this.labelInterval = 5,
      this.val2,
      this.savedColor});

  List<FlSpot> _spots(List<num> ys) => [
        for (var i = 0; i < ys.length; i++)
          FlSpot(i.toDouble(), ys[i].toDouble().clamp(0, 1)),
      ];

  @override
  Widget build(BuildContext context) {
    if (train.isEmpty && val.isEmpty) return const SizedBox.shrink();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 1,
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
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: labelInterval,
              getTitlesWidget: (v, _) => Text(
                'e${v.toInt()}',
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
              const Text(Strings.legendTrain, style: TextStyle(fontSize: 12)),
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
              const Text(Strings.legendVal, style: TextStyle(fontSize: 12)),
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
                const Text('Corrida guardada (línea punteada)',
                    style: TextStyle(fontSize: 12)),
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

