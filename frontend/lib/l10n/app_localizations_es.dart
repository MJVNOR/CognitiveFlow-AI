// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'CognitiveFlow AI';

  @override
  String get loginHint => 'Login demo (s1-s4 estudiante, i1 instructor)';

  @override
  String get loginUserId => 'user_id';

  @override
  String get loginEnter => 'Entrar';

  @override
  String get tabAcademy => 'Academia';

  @override
  String get tabLabs => 'Lab';

  @override
  String get tabProgress => 'Progreso';

  @override
  String get tabInstructor => 'Instructor';

  @override
  String get noApi => 'Sin conexión API';

  @override
  String get sendAttempt => 'Enviar intento';

  @override
  String get deliverPosttest => 'Entregar postest';

  @override
  String get retry => 'Reintentar';

  @override
  String get goPosttest => 'Ir al postest (tabla nueva, sin ayuda)';

  @override
  String get goPosttestNoAI => 'Ir al postest (sin ayuda de IA)';

  @override
  String get chartDataTable => 'Ver datos como tabla';

  @override
  String get scrollHint => 'Desliza → para ver todas las columnas';

  @override
  String get legendTrain => 'Entrenamiento (línea continua)';

  @override
  String get legendVal => 'Validación (línea discontinua)';

  @override
  String get legendRef => 'Referencia (barra izquierda)';

  @override
  String get legendCur => 'Actual (barra derecha)';

  @override
  String get simulated => 'Curvas sintéticas (simulación)';

  @override
  String routeProgress(int done, int total) {
    return 'Avance: $done de $total labs terminados';
  }
}
