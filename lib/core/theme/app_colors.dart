import 'package:flutter/material.dart';

/// Available color scheme presets for the application.
enum AppColorSchemePreset {
  monochrome,
  obsidianEmerald,
  cobaltPulse,
  solarAmber,
  crimsonEditorial,
  violetNebula;

  static AppColorSchemePreset fromString(String? value) {
    if (value == null) return AppColorSchemePreset.monochrome;
    return AppColorSchemePreset.values.firstWhere(
      (preset) => preset.name.toLowerCase() == value.toLowerCase(),
      orElse: () => AppColorSchemePreset.monochrome,
    );
  }

  String get displayName {
    switch (this) {
      case AppColorSchemePreset.monochrome:
        return 'Monochrome B&W';
      case AppColorSchemePreset.obsidianEmerald:
        return 'Obsidian Emerald';
      case AppColorSchemePreset.cobaltPulse:
        return 'Cobalt Pulse';
      case AppColorSchemePreset.solarAmber:
        return 'Solar Amber';
      case AppColorSchemePreset.crimsonEditorial:
        return 'Crimson Editorial';
      case AppColorSchemePreset.violetNebula:
        return 'Violet Nebula';
    }
  }

  Color get swatchColor {
    switch (this) {
      case AppColorSchemePreset.monochrome:
        return const Color(0xFFFFFFFF);
      case AppColorSchemePreset.obsidianEmerald:
        return const Color(0xFF10B981);
      case AppColorSchemePreset.cobaltPulse:
        return const Color(0xFF3B82F6);
      case AppColorSchemePreset.solarAmber:
        return const Color(0xFFF59E0B);
      case AppColorSchemePreset.crimsonEditorial:
        return const Color(0xFFF43F5E);
      case AppColorSchemePreset.violetNebula:
        return const Color(0xFF8B5CF6);
    }
  }

  PresetPalette get palette => PresetPalette.forPreset(this);
}

/// Immutable color palette specification for dark and light modes of a preset.
class PresetPalette {
  final AppColorSchemePreset preset;
  final Color darkBackground;
  final Color darkSurface;
  final Color darkSurfaceElevated;
  final Color darkBorder;
  final Color darkPrimary;
  final Color darkOnPrimary;
  final Color darkSecondary;
  final Color darkTextPrimary;
  final Color darkTextSecondary;

  final Color lightBackground;
  final Color lightSurface;
  final Color lightSurfaceElevated;
  final Color lightBorder;
  final Color lightPrimary;
  final Color lightOnPrimary;
  final Color lightSecondary;
  final Color lightTextPrimary;
  final Color lightTextSecondary;

  const PresetPalette({
    required this.preset,
    required this.darkBackground,
    required this.darkSurface,
    required this.darkSurfaceElevated,
    required this.darkBorder,
    required this.darkPrimary,
    required this.darkOnPrimary,
    required this.darkSecondary,
    required this.darkTextPrimary,
    required this.darkTextSecondary,
    required this.lightBackground,
    required this.lightSurface,
    required this.lightSurfaceElevated,
    required this.lightBorder,
    required this.lightPrimary,
    required this.lightOnPrimary,
    required this.lightSecondary,
    required this.lightTextPrimary,
    required this.lightTextSecondary,
  });

  static PresetPalette forPreset(AppColorSchemePreset preset) {
    // High-contrast neutral bases per AGENTS.md Task 1
    const darkBg = Color(0xFF000000);
    const darkSurf = Color(0xFF0A0A0A);
    const darkSurfElevated = Color(0xFF141414);
    const darkBrd = Color(0xFF262626);
    const darkTxtPrimary = Color(0xFFFFFFFF);
    const darkTxtSecondary = Color(0xFF8E8E93);

    const lightBg = Color(0xFFFFFFFF);
    const lightSurf = Color(0xFFF4F4F5);
    const lightSurfElevated = Color(0xFFFFFFFF);
    const lightBrd = Color(0xFFE4E4E7);
    const lightTxtPrimary = Color(0xFF000000);
    const lightTxtSecondary = Color(0xFF71717A);

    switch (preset) {
      case AppColorSchemePreset.monochrome:
        return const PresetPalette(
          preset: AppColorSchemePreset.monochrome,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFFFFFFFF),
          darkOnPrimary: Color(0xFF000000),
          darkSecondary: Color(0xFFA1A1AA),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFF000000),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightSecondary: Color(0xFF52525B),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );

      case AppColorSchemePreset.obsidianEmerald:
        return const PresetPalette(
          preset: AppColorSchemePreset.obsidianEmerald,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFF10B981),
          darkOnPrimary: Color(0xFF000000),
          darkSecondary: Color(0xFF34D399),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFF059669),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightSecondary: Color(0xFF10B981),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );

      case AppColorSchemePreset.cobaltPulse:
        return const PresetPalette(
          preset: AppColorSchemePreset.cobaltPulse,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFF3B82F6),
          darkOnPrimary: Color(0xFFFFFFFF),
          darkSecondary: Color(0xFF60A5FA),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFF2563EB),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightSecondary: Color(0xFF3B82F6),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );

      case AppColorSchemePreset.solarAmber:
        return const PresetPalette(
          preset: AppColorSchemePreset.solarAmber,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFFF59E0B),
          darkOnPrimary: Color(0xFF000000),
          darkSecondary: Color(0xFFFBBF24),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFFD97706),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightSecondary: Color(0xFFF59E0B),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );

      case AppColorSchemePreset.crimsonEditorial:
        return const PresetPalette(
          preset: AppColorSchemePreset.crimsonEditorial,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFFF43F5E),
          darkOnPrimary: Color(0xFFFFFFFF),
          darkSecondary: Color(0xFFFB7185),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFFE11D48),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightSecondary: Color(0xFFF43F5E),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );

      case AppColorSchemePreset.violetNebula:
        return const PresetPalette(
          preset: AppColorSchemePreset.violetNebula,
          darkBackground: darkBg,
          darkSurface: darkSurf,
          darkSurfaceElevated: darkSurfElevated,
          darkBorder: darkBrd,
          darkPrimary: Color(0xFF8B5CF6),
          darkOnPrimary: Color(0xFFFFFFFF),
          darkSecondary: Color(0xFFA78BFA),
          darkTextPrimary: darkTxtPrimary,
          darkTextSecondary: darkTxtSecondary,
          lightBackground: lightBg,
          lightSurface: lightSurf,
          lightSurfaceElevated: lightSurfElevated,
          lightBorder: lightBrd,
          lightPrimary: Color(0xFF7C3AED),
          lightOnPrimary: Color(0xFFFFFFFF),
          lightSecondary: Color(0xFF8B5CF6),
          lightTextPrimary: lightTxtPrimary,
          lightTextSecondary: lightTxtSecondary,
        );
    }
  }
}

class AppColors {
  // Static references maintaining backward compatibility with Native B&W defaults
  static const Color primary = Color(0xFFFFFFFF);
  static const Color primaryDark = Color(0xFFA1A1AA);
  static const Color tealAccent = Color(0xFF10B981);

  // Surfaces
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0A);
  static const Color surfaceLight = Color(0xFF141414);
  static const Color surfaceRaised = Color(0xFF141414);
  static const Color surfaceGlass = Color(0x14FFFFFF);

  // Typography
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF71717A);

  // Semantic Status
  static const Color error = Color(0xFFF43F5E);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);

  // Category Colors
  static const Color health = Color(0xFFF43F5E);
  static const Color productivity = Color(0xFFFFFFFF);
  static const Color learning = Color(0xFF3B82F6);
  static const Color fitness = Color(0xFF10B981);
  static const Color hobby = Color(0xFF8B5CF6);

  // Crisp Border
  static const Color glassBorder = Color(0xFF262626);
  static const Color primaryGlow = Color(0x1AFFFFFF);
}


