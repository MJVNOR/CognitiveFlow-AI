import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Tokens de color + temas claro/oscuro (trifecta DESIGN.md).
abstract final class CognitiveColors {
  static const blue = Color(0xFF2457C5);
  static const teal = Color(0xFF0F766E);
  static const amber = Color(0xFFA65B00);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F5F9);
  static const ink = Color(0xFF0F172A);
  static const inkSecondary = Color(0xFF475569);
  static const border = Color(0xFFCBD5E1);
  static const blueSoft = Color(0xFFE8EEFF);
  static const tealSoft = Color(0xFFE4F4F0);
  static const amberSoft = Color(0xFFFFF3D6);
  static const error = Color(0xFFB42318);
  static const errorSoft = Color(0xFFFEECEB);
  static const success = Color(0xFF166534);
  static const successSoft = Color(0xFFDCFCE7);
  static const focus = Color(0xFF2457C5);

  // Dark: variantes claras de marca sobre superficies oscuras (WCAG AA).
  // Blanco sobre blue/teal/amber originales pasa en botones, pero como
  // texto/gráfica sobre fondo oscuro no llega a 3:1 → se aclaran.
  static const backgroundDark = Color(0xFF0F172A);
  static const surfaceDark = Color(0xFF1E293B);
  static const surfaceMutedDark = Color(0xFF273549);
  static const inkDark = Color(0xFFF1F5F9);
  static const inkSecondaryDark = Color(0xFFCBD5E1);
  static const borderDark = Color(0xFF334155);
  static const blueDark = Color(0xFF8AA8FF); // 6.36:1 sobre surfaceDark
  static const tealDark = Color(0xFF2DD4BF); // 7.86:1 sobre surfaceDark
  static const amberDark = Color(0xFFFBBF24); // 8.76:1 sobre surfaceDark
  static const blueSoftDark = Color(0xFF1E2F5E);
  static const tealSoftDark = Color(0xFF0B3532);
  static const amberSoftDark = Color(0xFF451A03);
  static const errorDark = Color(0xFFFFB4AB);
  static const errorSoftDark = Color(0xFF5A1510);
  static const successDark = Color(0xFF86EFAC);
  static const successSoftDark = Color(0xFF052E16);
}

ThemeData buildCognitiveLightTheme() {
  const scheme = ColorScheme.light(
    primary: CognitiveColors.blue,
    onPrimary: Colors.white,
    primaryContainer: CognitiveColors.blueSoft,
    onPrimaryContainer: CognitiveColors.blue,
    secondary: CognitiveColors.teal,
    onSecondary: Colors.white,
    secondaryContainer: CognitiveColors.tealSoft,
    onSecondaryContainer: CognitiveColors.teal,
    tertiary: CognitiveColors.amber,
    onTertiary: Colors.white,
    tertiaryContainer: CognitiveColors.amberSoft,
    onTertiaryContainer: CognitiveColors.amber,
    surface: CognitiveColors.surface,
    onSurface: CognitiveColors.ink,
    surfaceContainerHighest: CognitiveColors.surfaceMuted,
    onSurfaceVariant: CognitiveColors.inkSecondary,
    outlineVariant: CognitiveColors.border,
    error: CognitiveColors.error,
    onError: Colors.white,
    errorContainer: CognitiveColors.errorSoft,
    onErrorContainer: CognitiveColors.error,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: CognitiveColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: CognitiveColors.surface,
      foregroundColor: CognitiveColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: TextStyle(
        color: CognitiveColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      shape: Border(
        bottom: BorderSide(color: CognitiveColors.border, width: 1),
      ),
    ),
    cardTheme: CardThemeData(
      color: CognitiveColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CognitiveColors.border),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: CognitiveColors.focus, width: 2),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: CognitiveColors.teal,
      thumbColor: CognitiveColors.teal,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: CognitiveColors.surfaceMuted,
      labelStyle: const TextStyle(color: CognitiveColors.ink),
      side: const BorderSide(color: CognitiveColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerColor: CognitiveColors.border,
  );
}

ThemeData buildCognitiveDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: CognitiveColors.blueDark,
    onPrimary: CognitiveColors.backgroundDark,
    primaryContainer: CognitiveColors.blueSoftDark,
    onPrimaryContainer: CognitiveColors.blueDark,
    secondary: CognitiveColors.tealDark,
    onSecondary: CognitiveColors.backgroundDark,
    secondaryContainer: CognitiveColors.tealSoftDark,
    onSecondaryContainer: CognitiveColors.tealDark,
    tertiary: CognitiveColors.amberDark,
    onTertiary: CognitiveColors.backgroundDark,
    tertiaryContainer: CognitiveColors.amberSoftDark,
    onTertiaryContainer: CognitiveColors.amberDark,
    surface: CognitiveColors.surfaceDark,
    onSurface: CognitiveColors.inkDark,
    surfaceContainerHighest: CognitiveColors.surfaceMutedDark,
    onSurfaceVariant: CognitiveColors.inkSecondaryDark,
    outlineVariant: CognitiveColors.borderDark,
    error: CognitiveColors.errorDark,
    onError: CognitiveColors.backgroundDark,
    errorContainer: CognitiveColors.errorSoftDark,
    onErrorContainer: CognitiveColors.errorDark,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: CognitiveColors.backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: CognitiveColors.surfaceDark,
      foregroundColor: CognitiveColors.inkDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 16,
      titleTextStyle: TextStyle(
        color: CognitiveColors.inkDark,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      shape: Border(
        bottom: BorderSide(color: CognitiveColors.borderDark, width: 1),
      ),
    ),
    cardTheme: CardThemeData(
      color: CognitiveColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CognitiveColors.borderDark),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: CognitiveColors.blueDark, width: 2),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: CognitiveColors.tealDark,
      thumbColor: CognitiveColors.tealDark,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: CognitiveColors.surfaceMutedDark,
      labelStyle: const TextStyle(color: CognitiveColors.inkDark),
      side: const BorderSide(color: CognitiveColors.borderDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerColor: CognitiveColors.borderDark,
  );
}

class ThemeNotifier extends Notifier<ThemeMode> {
  final ThemeMode initial;
  ThemeNotifier([this.initial = ThemeMode.system]);

  @override
  ThemeMode build() => initial;

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', state == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

