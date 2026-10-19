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

  // Static aliases
  static const Color primary = AppColors.darkPrimary;
  static const Color background = AppColors.darkSurface;
  static const Color surface = AppColors.darkSurfaceContainer;
  static const Color surfaceLight = AppColors.darkSurfaceContainerHigh;
  static const Color textPrimary = AppColors.darkOnSurface;
  static const Color textSecondary = AppColors.darkOnSurfaceVariant;
  static const Color textFaded = Color(0xFF71717A);

  // Solid accent gradient
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

  /// Expressive Dark Theme (Material 3 Expressive base)
  static ThemeData buildDarkTheme([AppColorSchemePreset? preset]) {
    final p = (preset ?? currentPreset).palette;

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: p.darkPrimary,
      onPrimary: p.darkOnPrimary,
      primaryContainer: p.darkPrimaryContainer,
      onPrimaryContainer: p.darkOnPrimaryContainer,
      secondary: p.darkSecondary,
      onSecondary: const Color(0xFF1F3244),
      secondaryContainer: const Color(0xFF324655),
      onSecondaryContainer: const Color(0xFFCEE5F6),
      tertiary: const Color(0xFFFFB784),
      onTertiary: const Color(0xFF4F2500),
      tertiaryContainer: const Color(0xFF5C3B1E),
      onTertiaryContainer: const Color(0xFFFFDCC2),
      error: const Color(0xFFFFB4AB),
      onError: const Color(0xFF690005),
      errorContainer: const Color(0xFF93000A),
      onErrorContainer: const Color(0xFFFFDAD6),
      surface: p.darkBackground,
      onSurface: p.darkTextPrimary,
      onSurfaceVariant: p.darkTextSecondary,
      outline: const Color(0xFF454E56),
      outlineVariant: p.darkBorder,
      surfaceContainerLowest: const Color(0xFF090B0D),
      surfaceContainerLow: const Color(0xFF15191C),
      surfaceContainer: p.darkSurface,
      surfaceContainerHigh: p.darkSurfaceElevated,
      surfaceContainerHighest: const Color(0xFF2F363C),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: p.darkPrimary,
      scaffoldBackgroundColor: p.darkBackground,
      dividerColor: p.darkBorder,
      fontFamily: 'Roboto',
      extensions: [AppTokens.fromPreset(p.preset, isDark: true)],
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        color: p.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
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
        backgroundColor: p.darkSurfaceElevated,
        selectedItemColor: p.darkPrimary,
        unselectedItemColor: p.darkTextSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.darkPrimary,
          foregroundColor: p.darkOnPrimary,
          elevation: 0,
          minimumSize: const Size(48, 52),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
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
            borderRadius: BorderRadius.circular(14),
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
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.darkPrimary,
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.darkPrimary,
        foregroundColor: p.darkOnPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2F363C),
        selectedColor: p.darkPrimaryContainer,
        labelStyle:
            TextStyle(color: p.darkTextPrimary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(
            color: p.darkOnPrimaryContainer, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        side: BorderSide(color: p.darkBorder, width: 1.0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2F363C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF454E56), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.darkBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.darkPrimary, width: 1.5),
        ),
        labelStyle: TextStyle(color: p.darkTextSecondary),
        hintStyle: TextStyle(color: p.darkTextSecondary),
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

  /// Expressive Light Theme (Material 3 Expressive base)
  static ThemeData buildLightTheme([AppColorSchemePreset? preset]) {
    final p = (preset ?? currentPreset).palette;

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: p.lightPrimary,
      onPrimary: p.lightOnPrimary,
      primaryContainer: p.lightPrimaryContainer,
      onPrimaryContainer: p.lightOnPrimaryContainer,
      secondary: p.lightSecondary,
      onSecondary: const Color(0xFF0D1E2A),
      secondaryContainer: const Color(0xFFCFE6F7),
      onSecondaryContainer: const Color(0xFF0D1E2A),
      tertiary: const Color(0xFF8B5000),
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: const Color(0xFFFFDCC2),
      onTertiaryContainer: const Color(0xFF2E1500),
      error: const Color(0xFFBA1A1A),
      onError: const Color(0xFFFFFFFF),
      errorContainer: const Color(0xFFFFDAD6),
      onErrorContainer: const Color(0xFF410002),
      surface: p.lightBackground,
      onSurface: p.lightTextPrimary,
      onSurfaceVariant: p.lightTextSecondary,
      outline: const Color(0xFF72787E),
      outlineVariant: p.lightBorder,
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF1F4F8),
      surfaceContainer: p.lightSurface,
      surfaceContainerHigh: p.lightSurfaceElevated,
      surfaceContainerHighest: const Color(0xFFDCE1E8),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: p.lightPrimary,
      scaffoldBackgroundColor: p.lightBackground,
      dividerColor: p.lightBorder,
      fontFamily: 'Roboto',
      extensions: [AppTokens.fromPreset(p.preset, isDark: false)],
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        color: p.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
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
        backgroundColor: p.lightSurfaceElevated,
        selectedItemColor: p.lightPrimary,
        unselectedItemColor: p.lightTextSecondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.lightPrimary,
          foregroundColor: p.lightOnPrimary,
          elevation: 0,
          minimumSize: const Size(48, 52),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
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
            borderRadius: BorderRadius.circular(14),
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
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.lightPrimary,
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.lightPrimary,
        foregroundColor: p.lightOnPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFDCE1E8),
        selectedColor: p.lightPrimaryContainer,
        labelStyle:
            TextStyle(color: p.lightTextPrimary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(
            color: p.lightOnPrimaryContainer, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        side: BorderSide(color: p.lightBorder, width: 1.0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFDCE1E8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF72787E), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.lightBorder, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.lightPrimary, width: 1.5),
        ),
        labelStyle: TextStyle(color: p.lightTextSecondary),
        hintStyle: TextStyle(color: p.lightTextSecondary),
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

