// Etiquetas humanas para criterios Jev + línea inicial→postest.
// Extraído de ui/labs/view_models/lab_session.dart sin cambios (P2.4, P4.2).
// Nunca solo `id · score`; null si no comparable.

// P2.4: etiquetas humanas para criterios Jev — nunca solo `id · score`.
const criterionLabels = {
  'exactitud': 'Exactitud conceptual',
  'evidencia': 'Uso de evidencia',
  'causal': 'Causalidad',
  'alternativas': 'Alternativas',
  'metacognicion': 'Revisión',
};

String criterionLabel(String id) => criterionLabels[id] ?? id;

// P4.2: línea inicial→postest desde mapas {criterio: score 0-4}; null si no comparable.
String? progressLine(Map? base, Map? post) {
  double? avg(Map? m) {
    if (m == null || m.isEmpty) return null;
    var t = 0.0;
    for (final v in m.values) {
      t += (v as num).toDouble();
    }
    return t / m.length;
  }

  final b = avg(base);
  final p = avg(post);
  String f(double v) => v.toStringAsFixed(1);
  if (b == null && p == null) return null;
  if (b == null) return 'Inicial sin registrar · Postest ${f(p!)}/4';
  if (p == null) return 'Inicial ${f(b)}/4 · Postest pendiente';
  final d = p - b;
  return 'Inicial ${f(b)}/4 → Postest ${f(p)}/4 (${d >= 0 ? '+' : ''}${f(d)})';
}
