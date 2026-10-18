import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_tokens.dart';
import 'expressive_tokens.dart';
import '../utils/page_transitions.dart';

class AppTheme {
  // Legacy color aliases preserved for backward compatibility
  static const Color primary = AppColors.primary;
  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color surfaceLight = AppColors.surfaceLight;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;
  static const Color textFaded = AppColors.textTertiary;

  // Gradients
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x26FFFFFF), // 15% white
      Color(0x0AFFFFFF), // 4% white
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.primary,
      AppColors.primaryDark,
    ],
  );

  /// Expressive Dark Theme (Material 3 Expressive base)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppTokens.dark.accent,
      scaffoldBackgroundColor: AppTokens.dark.background,
      fontFamily: 'Roboto',
      extensions: const [AppTokens.dark],
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x12FFFFFF), width: 1.0),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
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
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: Color(0x18FFFFFF), width: 1.0),
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

  /// Expressive Light Theme (Material 3 Expressive base)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppTokens.light.accent,
      scaffoldBackgroundColor: AppTokens.light.background,
      fontFamily: 'Roboto',
      extensions: const [AppTokens.light],
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF111827),
        surface: Color(0xFFFFFFFF),
        error: AppColors.error,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFFFFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ExpressiveTokens.borderL,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
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
}
