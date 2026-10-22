// Helpers de cabecera de labs (la cabecera en sí es StudioHeader).
import '../view_models/lab_session.dart';

/// Sprint 4: lenguaje de la ruta diagnosticada (nunca etiqueta de inteligencia).
String levelLabel(String level) => switch (level) {
      'needs_foundation' => 'base guiada',
      'guided_practice' => 'práctica guiada',
      'autonomous_challenge' => 'desafío autónomo',
      _ => 'diagnóstico pendiente',
    };

/// Línea de nivel + ayuda usada para la cabecera (null si aún no hay diagnóstico).
String? sessionMeta(LabSession lab) {
  if (lab.level == null || lab.level == 'pending') return null;
  final a = lab.assistance;
  final helps = a == null ? 0 : (a['hints'] ?? 0) + (a['interventions'] ?? 0);
  return 'Ruta: ${levelLabel(lab.level!)} · Ayudas usadas: $helps';
}
