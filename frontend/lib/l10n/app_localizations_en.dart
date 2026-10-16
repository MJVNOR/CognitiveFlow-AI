// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CognitiveFlow AI';

  @override
  String get loginHint => 'Demo login (s1-s4 student, i1 instructor)';

  @override
  String get loginUserId => 'user_id';

  @override
  String get loginEnter => 'Sign in';

  @override
  String get tabAcademy => 'Academy';

  @override
  String get tabLabs => 'Lab';

  @override
  String get tabProgress => 'Progress';

  @override
  String get tabInstructor => 'Instructor';

  @override
  String get noApi => 'No API connection';

  @override
  String get sendAttempt => 'Submit attempt';

  @override
  String get deliverPosttest => 'Submit posttest';

  @override
  String get retry => 'Retry';

  @override
  String get goPosttest => 'Go to posttest (new table, no help)';

  @override
  String get goPosttestNoAI => 'Go to posttest (no AI help)';

  @override
  String get chartDataTable => 'View data as table';

  @override
  String get scrollHint => 'Swipe → to see all columns';

  @override
  String get legendTrain => 'Training (solid line)';

  @override
  String get legendVal => 'Validation (dashed line)';

  @override
  String get legendRef => 'Reference (left bar)';

  @override
  String get legendCur => 'Current (right bar)';

  @override
  String get simulated => 'Synthetic curves (simulation)';

  @override
  String routeProgress(int done, int total) {
    return 'Progress: $done of $total labs finished';
  }
}
