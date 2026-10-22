// Explorador del dataset: encabezado fijo con distribución por columna,
// orden, filtro por línea y filas seleccionables. Ausentes = «—» + texto;
// marcas del estudiante = banderín + texto (nunca solo color). Antes de la
// evaluación no hay veredictos: solo lo que el estudiante marcó.
import 'package:flutter/material.dart';

import '../../core/motion.dart';
import 'data_missions.dart';

class DatasetExplorer extends StatefulWidget {
  final List columns;
  final List rows;
  final Set<int> flagged;
  final Map<String, String> cellTypes;
  final int? selectedRow;
  final Set<String> focusColumns;
  final String? focusLine;

  /// Tras evaluar: fila → la clasificación coincide (true) o no (false).
  final Map<String, bool>? verdicts;
  final ValueChanged<int> onSelectRow;
  final ValueChanged<String> onColumn;
  final ValueChanged<String?> onLine;

  const DatasetExplorer({
    super.key,
    required this.columns,
    required this.rows,
    required this.flagged,
    required this.cellTypes,
    required this.onSelectRow,
    required this.onColumn,
    required this.onLine,
    this.selectedRow,
    this.focusColumns = const {},
    this.focusLine,
    this.verdicts,
  });

  @override
  State<DatasetExplorer> createState() => _DatasetExplorerState();
}

const _baseWidths = {'id': 56.0, 'temp': 104.0, 'unit': 80.0, 'pressure': 112.0, 'line': 72.0};
const _statusW = 52.0;
const _rowH = 44.0;

class _DatasetExplorerState extends State<DatasetExplorer> {
  String? sortCol;
  bool asc = false;
  bool onlyFlagged = false;
  final hCtrl = ScrollController();
  final vCtrl = ScrollController();

  @override
  void dispose() {
    hCtrl.dispose();
    vCtrl.dispose();
    super.dispose();
  }

  List<Map> get _visible {
    final out = [
      for (final r in widget.rows)
        if (!onlyFlagged || widget.flagged.contains(r['id'])) r as Map,
    ];
    final c = sortCol;
    if (c != null) {
      // Ausentes siempre al final: ordenar no debe esconderlos ni inventar valor.
      out.sort((a, b) {
        final x = a[c], y = b[c];
        if (x == null && y == null) return 0;
        if (x == null) return 1;
        if (y == null) return -1;
        final r = x is num && y is num ? x.compareTo(y) : '$x'.compareTo('$y');
        return asc ? r : -r;
      });
    }
    return out;
  }

  void _sort(String c) => setState(() {
        if (sortCol == c) {
          asc = !asc;
        } else {
          sortCol = c;
          asc = false;
        }
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cols = [for (final c in widget.columns) '$c'];
    final rows = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String?>(
              key: const ValueKey('dataset_line_filter'),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: null, label: Text('Todas')),
                ButtonSegment(value: 'A', label: Text('Línea A')),
                ButtonSegment(value: 'B', label: Text('Línea B')),
              ],
              selected: {widget.focusLine},
              onSelectionChanged: (s) => widget.onLine(s.first),
            ),
            FilterChip(
              key: const ValueKey('dataset_only_flagged'),
              label: Text('Solo marcadas (${widget.flagged.length})'),
              selected: onlyFlagged,
              onSelected: widget.flagged.isEmpty && !onlyFlagged
                  ? null
                  : (v) => setState(() => onlyFlagged = v),
            ),
            if (sortCol != null)
              Text('Ordenado por $sortCol ${asc ? '↑' : '↓'}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final minW = _statusW + _baseWidths.values.fold(0.0, (a, b) => a + b);
          final scale = (c.maxWidth / minW).clamp(1.0, 1.8);
          double w(String col) => (_baseWidths[col] ?? 80) * scale;
          final tableW = _statusW + cols.fold(0.0, (a, col) => a + w(col));
          final bodyH = (c.maxWidth < 600 ? 7 : 9) * _rowH;
          final table = SizedBox(
            width: tableW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  cols: cols,
                  width: w,
                  rows: widget.rows,
                  selectedRow: widget.selectedRow,
                  focusColumns: widget.focusColumns,
                  sortCol: sortCol,
                  asc: asc,
                  onSort: _sort,
                  onColumn: widget.onColumn,
                ),
                SizedBox(
                  height: bodyH,
                  child: rows.isEmpty
                      ? Center(
                          child: Text('Sin filas con este filtro.',
                              style: TextStyle(color: cs.onSurfaceVariant)))
                      : Scrollbar(
                          controller: vCtrl,
                          thumbVisibility: true,
                          child: ListView.builder(
                            controller: vCtrl,
                            itemExtent: _rowH,
                            itemCount: rows.length,
                            itemBuilder: (context, i) => _Row(
                              row: rows[i],
                              cols: cols,
                              width: w,
                              selected: rows[i]['id'] == widget.selectedRow,
                              flagged: widget.flagged.contains(rows[i]['id']),
                              type: widget.cellTypes['${rows[i]['id']}'],
                              verdict: widget.verdicts?['${rows[i]['id']}'],
                              dim: widget.focusLine != null &&
                                  rows[i]['line'] != widget.focusLine,
                              focusColumns: widget.focusColumns,
                              onTap: () => widget.onSelectRow(rows[i]['id'] as int),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: tableW <= c.maxWidth
                ? table
                : Scrollbar(
                    controller: hCtrl,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: hCtrl,
                      scrollDirection: Axis.horizontal,
                      child: table,
                    ),
                  ),
          );
        }),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final List<String> cols;
  final double Function(String) width;
  final List rows;
  final int? selectedRow;
  final Set<String> focusColumns;
  final String? sortCol;
  final bool asc;
  final ValueChanged<String> onSort;
  final ValueChanged<String> onColumn;
  const _Header({
    required this.cols,
    required this.width,
    required this.rows,
    required this.selectedRow,
    required this.focusColumns,
    required this.sortCol,
    required this.asc,
    required this.onSort,
    required this.onColumn,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Map? sel;
    for (final r in rows) {
      if (r['id'] == selectedRow) sel = r as Map;
    }
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _statusW,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 12, 0, 0),
              child: Tooltip(
                message: 'Tu marca sobre la fila',
                child: Icon(Icons.flag_outlined, size: 16, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          for (final c in cols) _headerCell(context, c, sel),
        ],
      ),
    );
  }

  Widget _headerCell(BuildContext context, String c, Map? sel) {
    final cs = Theme.of(context).colorScheme;
    final focus = focusColumns.contains(c);
    final values = [for (final r in rows) r[c]];
    final nums = values.whereType<num>().map((e) => e.toDouble()).toList();
    final missing = values.where((v) => v == null).length;
    final numeric = nums.length > values.length ~/ 2 && c != 'id';
    final sensor = sensorForColumn(c);
    return AnimatedContainer(
      duration: Motion.at(context, Motion.quick),
      width: width(c),
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: focus ? cs.secondaryContainer : null,
        border: Border(
            bottom: BorderSide(color: focus ? cs.secondary : Colors.transparent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
              child: Tooltip(
                message: columnInfo[c] ?? c,
                child: Semantics(
                  button: true,
                  selected: focus,
                  label: 'Columna $c. ${columnInfo[c] ?? ''}',
                  excludeSemantics: true,
                  child: InkWell(
                    key: ValueKey('dataset_col_$c'),
                    onTap: () => onColumn(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        if (sensor != null) ...[
                          Icon(sensor == 'temp' ? Icons.thermostat : Icons.speed,
                              size: 14, color: cs.secondary),
                          const SizedBox(width: 2),
                        ],
                        Flexible(
                          child: Text(c,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                key: ValueKey('dataset_sort_$c'),
                padding: EdgeInsets.zero,
                iconSize: 16,
                tooltip: 'Ordenar por $c',
                icon: Icon(sortCol == c
                    ? (asc ? Icons.arrow_upward : Icons.arrow_downward)
                    : Icons.unfold_more),
                onPressed: () => onSort(c),
              ),
            ),
          ]),
          if (numeric)
            Tooltip(
              message: 'Distribución de ${nums.length} valores registrados'
                  '${sel != null ? '; la marca azul es la fila ${sel['id']}' : ''}',
              child: SizedBox(
                height: 22,
                width: double.infinity,
                child: CustomPaint(
                  painter: _HistPainter(
                    nums,
                    sel?[c] is num ? (sel![c] as num).toDouble() : null,
                    bar: cs.secondary.withValues(alpha: 0.55),
                    mark: cs.primary,
                  ),
                ),
              ),
            ),
          Text(
            missing > 0 ? '$missing ausentes' : (numeric ? '${_fmt(nums.reduce((a, b) => a < b ? a : b))}–${_fmt(nums.reduce((a, b) => a > b ? a : b))}' : ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _fmt(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

class _Row extends StatelessWidget {
  final Map row;
  final List<String> cols;
  final double Function(String) width;
  final bool selected;
  final bool flagged;
  final String? type;
  final bool? verdict;
  final bool dim;
  final Set<String> focusColumns;
  final VoidCallback onTap;
  const _Row({
    required this.row,
    required this.cols,
    required this.width,
    required this.selected,
    required this.flagged,
    required this.type,
    required this.verdict,
    required this.dim,
    required this.focusColumns,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final id = row['id'];
    final typeLabel = type == null ? null : anomalyTypeLabels[type];
    final status = Row(mainAxisSize: MainAxisSize.min, children: [
      if (flagged) Icon(Icons.flag, size: 16, color: cs.secondary),
      if (verdict == true) Icon(Icons.check_circle, size: 16, color: cs.primary),
      if (verdict == false) Icon(Icons.error_outline, size: 16, color: cs.error),
    ]);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Fila $id, línea ${row['line']}'
          '${flagged ? ', marcada como ${typeLabel ?? 'sospechosa'}' : ''}'
          '${verdict == null ? '' : verdict! ? ', clasificación coincide' : ', clasificación no coincide'}',
      child: AnimatedOpacity(
        duration: Motion.at(context, Motion.quick),
        opacity: dim ? 0.45 : 1,
        child: Material(
          color: selected ? cs.primaryContainer.withValues(alpha: 0.6) : cs.surface,
          child: InkWell(
            key: ValueKey('datarow_$id'),
            onTap: onTap,
            child: AnimatedContainer(
              duration: Motion.at(context, Motion.quick),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: selected ? cs.primary : (flagged ? cs.secondary : Colors.transparent),
                      width: 3),
                  bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
                ),
              ),
              child: Row(children: [
                SizedBox(
                  width: _statusW - 3,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Tooltip(
                      message: [
                        if (flagged) 'Marcaste: ${typeLabel ?? 'sospechosa'}',
                        if (verdict == true) 'Tu clasificación coincide',
                        if (verdict == false) 'Tu clasificación no coincide: vuelve a investigar',
                      ].join('\n'),
                      child: status,
                    ),
                  ),
                ),
                for (final c in cols) _cell(context, c),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, String c) {
    final cs = Theme.of(context).colorScheme;
    final v = row[c];
    final focus = focusColumns.contains(c);
    final missing = v == null;
    final text = missing
        ? Text.rich(
            TextSpan(children: [
              const TextSpan(text: '—  '),
              TextSpan(
                  text: 'ausente',
                  style: TextStyle(fontStyle: FontStyle.italic, color: cs.onSurfaceVariant, fontSize: 12)),
            ]),
            semanticsLabel: 'valor ausente',
          )
        : Text('$v',
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]));
    return Tooltip(
      message: missing ? '$c: valor ausente' : '$c = $v. ${columnInfo[c] ?? ''}',
      waitDuration: const Duration(milliseconds: 500),
      child: AnimatedContainer(
        key: ValueKey('datacell_${row['id']}_$c'),
        duration: Motion.at(context, Motion.quick),
        width: width(c),
        height: _rowH - 1,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: focus ? cs.secondaryContainer.withValues(alpha: 0.45) : null,
        child: text,
      ),
    );
  }
}

class _HistPainter extends CustomPainter {
  final List<double> values;
  final double? markAt;
  final Color bar;
  final Color mark;
  _HistPainter(this.values, this.markAt, {required this.bar, required this.mark});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final lo = values.reduce((a, b) => a < b ? a : b);
    final hi = values.reduce((a, b) => a > b ? a : b);
    const bins = 16;
    final span = hi - lo == 0 ? 1 : hi - lo;
    final counts = List.filled(bins, 0);
    for (final v in values) {
      counts[((v - lo) / span * (bins - 1)).round()]++;
    }
    final maxC = counts.reduce((a, b) => a > b ? a : b);
    final bw = size.width / bins;
    final p = Paint()..color = bar;
    for (var i = 0; i < bins; i++) {
      if (counts[i] == 0) continue;
      // Altura mínima visible: un valor aislado (extremo) no desaparece.
      final hgt = (counts[i] / maxC * (size.height - 2)).clamp(3.0, size.height);
      canvas.drawRect(Rect.fromLTWH(i * bw + 0.5, size.height - hgt, bw - 1, hgt), p);
    }
    final m = markAt;
    if (m != null) {
      final x = ((m - lo) / span).clamp(0.0, 1.0) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), Paint()
        ..color = mark
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_HistPainter o) => o.markAt != markAt || o.values.length != values.length || o.bar != bar;
}
