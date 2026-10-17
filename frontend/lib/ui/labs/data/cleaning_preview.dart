// Vista previa de limpieza (simulación client-side, no modifica datos).
// Extraído de features/data_lab_page.dart sin cambios; lo usa el test.
/// Sprint 3: vista previa de limpieza (simulación client-side, no modifica datos).
({List<Map<String, Object?>> rows, int removed, int converted}) cleanedPreview(
    List rows,
    Set<int> flagged,
    Map<String, String> types,
    Map<String, String> actions) {
  final pressures = [
    for (final r in rows) (r as Map)['pressure']
  ].whereType<num>();
  final mean = pressures.isEmpty
      ? null
      : pressures.reduce((a, b) => a + b) / pressures.length;
  final out = <Map<String, Object?>>[];
  var removed = 0;
  var converted = 0;
  for (final r in rows) {
    final m = Map<String, Object?>.from(r as Map);
    final id = int.tryParse('${m['id']}');
    if (id == null || !flagged.contains(id)) {
      out.add(m);
      continue;
    }
    final action = actions['$id'] ?? 'revisar';
    if (action == 'eliminar') {
      removed++;
      continue;
    }
    if (action == 'convertir' && m['unit'] == 'F' && m['temp'] is num) {
      m['temp'] =
          double.parse((((m['temp'] as num) - 32) * 5 / 9).toStringAsFixed(1));
      m['unit'] = 'C*';
      converted++;
    } else if (action == 'imputar' && m['pressure'] == null && mean != null) {
      m['pressure'] = double.parse(mean.toStringAsFixed(1));
      converted++;
    }
    out.add(m);
  }
  return (rows: out, removed: removed, converted: converted);
}
