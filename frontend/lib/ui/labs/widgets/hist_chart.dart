// Histograma referencia vs actual con alternativa textual.
// Extraído de features/monitor_lab_page.dart sin cambios.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/widgets/strings.dart';

class HistPainter extends StatelessWidget {
  final List<num> ref;
  final List<num> cur;
  final List<num> bins;
  final Color refColor;
  final Color curColor;
  const HistPainter(this.ref, this.cur,
      {super.key, required this.refColor, required this.curColor, this.bins = const []});

  @override
  Widget build(BuildContext context) {
    if (ref.isEmpty) return const SizedBox.shrink();
    final maxV = [...ref, ...cur].fold<double>(1, (a, b) => a > b.toDouble() ? a : b.toDouble());
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxV,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: bins.isNotEmpty,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 2,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= bins.length || i.isOdd) {
                  return const SizedBox.shrink();
                }
                return Text(bins[i].toStringAsFixed(0),
                    style: const TextStyle(fontSize: 9));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: true),
        barGroups: [
          for (var i = 0; i < ref.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(toY: ref[i].toDouble(), color: refColor, width: 6),
                BarChartRodData(
                  toY: i < cur.length ? cur[i].toDouble() : 0,
                  color: curColor,
                  width: 6,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Histograma referencia vs actual con alternativa textual y leyenda por
/// posición (izquierda/derecha), no por color.
class AccessibleHistChart extends StatelessWidget {
  final List<num> ref;
  final List<num> cur;
  final List<num> bins;
  final String label;
  final bool showTable;
  const AccessibleHistChart(
      {super.key,
      required this.ref,
      required this.cur,
      required this.label,
      this.bins = const [],
      this.showTable = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$label. ${ref.length} barras. Referencia suma '
              '${ref.fold<num>(0, (a, b) => a + b).toStringAsFixed(2)}, '
              'actual ${cur.fold<num>(0, (a, b) => a + b).toStringAsFixed(2)}.',
          child: SizedBox(
            height: 120,
            child: HistPainter(ref, cur,
              refColor: cs.primary, curColor: cs.secondary, bins: bins),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 12, color: cs.primary),
              const SizedBox(width: 6),
              const Text(Strings.legendRef, style: TextStyle(fontSize: 12)),
            ]),
            // ponytail: actual hueco vs referencia sólida = distinción por forma,
            // no solo color (WCAG 1.4.1); texto ya dice izquierda/derecha.
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  border: Border.all(color: cs.secondary, width: 2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(Strings.legendCur, style: TextStyle(fontSize: 12)),
            ]),
          ],
        ),
        if (showTable)
          ExpansionTile(
            title: const Text(Strings.chartDataTable,
                style: TextStyle(fontSize: 13)),
            tilePadding: EdgeInsets.zero,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                dataRowMinHeight: 44,
                columns: [
                  const DataColumn(label: Text('bin')),
                  if (bins.isNotEmpty)
                    const DataColumn(label: Text('centro')),
                  const DataColumn(label: Text('referencia')),
                  const DataColumn(label: Text('actual')),
                ],
                rows: [
                  for (var i = 0; i < ref.length; i++)
                    DataRow(cells: [
                      DataCell(Text('$i')),
                      if (bins.isNotEmpty)
                        DataCell(Text(i < bins.length
                            ? bins[i].toStringAsFixed(1)
                            : '—')),
                      DataCell(Text(ref[i].toStringAsFixed(3))),
                      DataCell(Text(i < cur.length ? cur[i].toStringAsFixed(3) : '—')),
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
