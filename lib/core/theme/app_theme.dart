import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_colors.dart';
import 'app_tokens.dart';
import '../utils/page_transitions.dart';

class AppTheme {
  // Preset notifier for broadcasting theme accent changes
  static final ValueNotifier<AppColorSchemePreset> presetNotifier =
      ValueNotifier<AppColorSchemePreset>(getSavedPreset());

  static AppColorSchemePreset get currentPreset => presetNotifier.value;

  /// Safely reads the persisted preset from Hive settings box
  static AppColorSchemePreset getSavedPreset() {
    if (!Hive.isBoxOpen('settings')) {
      return AppColorSchemePreset.monochrome;
    }
    final saved = Hive.box('settings').get(
      'color_scheme_preset',
      defaultValue: 'monochrome',
    );
    return AppColorSchemePreset.fromString(saved?.toString());
  }

  /// Sets the active preset and persists to Hive settings box
  static void setPreset(AppColorSchemePreset preset) {
    presetNotifier.value = preset;
    if (Hive.isBoxOpen('settings')) {
      Hive.box('settings').put('color_scheme_preset', preset.name);
    }
  }

  // Legacy compile-time color aliases preserved for backward compatibility (Native Black & White defaults)
  static const Color primary = Color(0xFFFFFFFF);
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0A);
  static const Color surfaceLight = Color(0xFF141414);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textFaded = Color(0xFF71717A);

  // Gradients
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x26FFFFFF), // 15% white
      Color(0x0AFFFFFF), // 4% white
    ],
  );

  static LinearGradient get accentGradient {
    final p = currentPreset.palette;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        p.darkPrimary,
        p.darkSecondary,
      ],
    );
  }

  /// Expressive Dark Theme (Material 3 Expressive base with Native Black & White default)
  static ThemeData buildDarkTheme([AppColorSchemePreset? preset]) {
    final p = (preset ?? currentPreset).palette;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: p.darkPrimary,
      scaffoldBackgroundColor: p.darkBackground,
      dividerColor: p.darkBorder,
      fontFamily: 'Roboto',
      extensions: [AppTokens.fromPreset(p.preset, isDark: true)],
      colorScheme: ColorScheme.dark(
        primary: p.darkPrimary,
        onPrimary: p.darkOnPrimary,
        secondary: p.darkSecondary,
        surface: p.darkSurface,
        error: AppColors.error,
      ),
      cardTheme: CardThemeData(
        color: p.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: p.darkBorder, width: 1.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: p.darkTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: p.darkTextPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.darkSurface,
        selectedItemColor: p.darkPrimary,
        unselectedItemColor: p.darkTextSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.darkPrimary,
          foregroundColor: p.darkOnPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.darkTextPrimary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: p.darkBorder, width: 1.0),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SpringSlideFadePageTransitionsBuilder(),
          TargetPlatform.iOS: SpringSlideFadePageTransitionsBuilder(),
          TargetPlatform.windows: SpringSlideFadePageTransitionsBuilder(),
          TargetPlatform.macOS: SpringSlideFadePageTransitionsBuilder(),
          TargetPlatform.linux: SpringSlideFadePageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Expressive Light Theme (Material 3 Expressive base with Native Black & White default)
  static ThemeData buildLightTheme([AppColorSchemePreset? preset]) {
    final p = (preset ?? currentPreset).palette;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: p.lightPrimary,
      scaffoldBackgroundColor: p.lightBackground,
      dividerColor: p.lightBorder,
      fontFamily: 'Roboto',
      extensions: [AppTokens.fromPreset(p.preset, isDark: false)],
      colorScheme: ColorScheme.light(
        primary: p.lightPrimary,
        onPrimary: p.lightOnPrimary,
        secondary: p.lightSecondary,
        surface: p.lightSurface,
        error: AppColors.error,
      ),
      cardTheme: CardThemeData(
        color: p.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: p.lightBorder, width: 1.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: p.lightTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: p.lightTextPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.lightSurface,
        selectedItemColor: p.lightPrimary,
        unselectedItemColor: p.lightTextSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.lightPrimary,
          foregroundColor: p.lightOnPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.lightTextPrimary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: p.lightBorder, width: 1.0),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SpringSlideFadePageTransitionsBuilder(),
          TargetPlatform.iOS: SpringSlideFadePageTransitionsBuilder(),
          TargetPlatform.windows: SpringSlideFadePageTransitionsBuilder(),
          TargetPlatform.macOS: SpringSlideFadePageTransitionsBuilder(),
          TargetPlatform.linux: SpringSlideFadePageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme => buildDarkTheme();
  static ThemeData get lightTheme => buildLightTheme();
}

