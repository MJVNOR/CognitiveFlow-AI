import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('es'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'CognitiveFlow AI'**
  String get appTitle;

  /// No description provided for @loginHint.
  ///
  /// In es, this message translates to:
  /// **'Login demo (s1-s4 estudiante, i1 instructor)'**
  String get loginHint;

  /// No description provided for @loginUserId.
  ///
  /// In es, this message translates to:
  /// **'user_id'**
  String get loginUserId;

  /// No description provided for @loginEnter.
  ///
  /// In es, this message translates to:
  /// **'Entrar'**
  String get loginEnter;

  /// No description provided for @tabAcademy.
  ///
  /// In es, this message translates to:
  /// **'Academia'**
  String get tabAcademy;

  /// No description provided for @tabLabs.
  ///
  /// In es, this message translates to:
  /// **'Lab'**
  String get tabLabs;

  /// No description provided for @tabProgress.
  ///
  /// In es, this message translates to:
  /// **'Progreso'**
  String get tabProgress;

  /// No description provided for @tabInstructor.
  ///
  /// In es, this message translates to:
  /// **'Instructor'**
  String get tabInstructor;

  /// No description provided for @noApi.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión API'**
  String get noApi;

  /// No description provided for @sendAttempt.
  ///
  /// In es, this message translates to:
  /// **'Enviar intento'**
  String get sendAttempt;

  /// No description provided for @deliverPosttest.
  ///
  /// In es, this message translates to:
  /// **'Entregar postest'**
  String get deliverPosttest;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @goPosttest.
  ///
  /// In es, this message translates to:
  /// **'Ir al postest (tabla nueva, sin ayuda)'**
  String get goPosttest;

  /// No description provided for @goPosttestNoAI.
  ///
  /// In es, this message translates to:
  /// **'Ir al postest (sin ayuda de IA)'**
  String get goPosttestNoAI;

  /// No description provided for @chartDataTable.
  ///
  /// In es, this message translates to:
  /// **'Ver datos como tabla'**
  String get chartDataTable;

  /// No description provided for @scrollHint.
  ///
  /// In es, this message translates to:
  /// **'Desliza → para ver todas las columnas'**
  String get scrollHint;

  /// No description provided for @legendTrain.
  ///
  /// In es, this message translates to:
  /// **'Entrenamiento (línea continua)'**
  String get legendTrain;

  /// No description provided for @legendVal.
  ///
  /// In es, this message translates to:
  /// **'Validación (línea discontinua)'**
  String get legendVal;

  /// No description provided for @legendRef.
  ///
  /// In es, this message translates to:
  /// **'Referencia (barra izquierda)'**
  String get legendRef;

  /// No description provided for @legendCur.
  ///
  /// In es, this message translates to:
  /// **'Actual (barra derecha)'**
  String get legendCur;

  /// No description provided for @simulated.
  ///
  /// In es, this message translates to:
  /// **'Curvas sintéticas (simulación)'**
  String get simulated;

  /// No description provided for @routeProgress.
  ///
  /// In es, this message translates to:
  /// **'Avance: {done} de {total} labs terminados'**
  String routeProgress(int done, int total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
